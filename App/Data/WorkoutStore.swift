import Foundation
import Combine
import SwiftUI
import CoreLocation
import os

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var workoutTypes: [WorkoutType] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published var workouts: [WorkoutSession] = []
    @Published var gymLocations: [GymLocation] = []
    @Published var timerPresets: [TimerPreset] = [
        .init(name: "60s", seconds: 60),
        .init(name: "90s", seconds: 90),
        .init(name: "2m", seconds: 120)
    ]
    @Published var healthExportStatus: HealthExportStatus = .init(lastExportedAt: nil, workoutsExported: 0)
    @Published var activeTimers: [RestTimer] = []

    let themeManager = ThemeManager()

    private let fileURL: URL
    private var saveTask: Task<Void, Never>? = nil
    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(subsystem: "WorkoutApp", category: "WorkoutStore")

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documents.appendingPathComponent("workout-data.json")
    }

    func start() async {
        load()
        observeAutosave()
        syncFromUbiquitousStore()
    }

    func startWorkout(type: WorkoutType, at date: Date = .now, gym: GymLocation? = nil) {
        var session = WorkoutSession(type: type, startTime: date, gymLocation: gym)
        session.createdAt = date
        session.updatedAt = date
        workouts.insert(session, at: 0)
    }

    func addWorkoutType(name: String) {
        let type = WorkoutType(name: name)
        workoutTypes.append(type)
    }

    func addExercise(name: String, type: WorkoutType) {
        let exercise = Exercise(name: name, workoutTypeID: type.id)
        exercises.append(exercise)
    }

    func addSet(to sessionID: UUID, exerciseID: UUID, weight: Double, reps: Int, customFields: [String: String] = [:]) {
        guard let workoutIndex = workouts.firstIndex(where: { $0.id == sessionID }),
              let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.exercise.id == exerciseID }) else { return }
        let set = SetEntry(weight: weight, reps: reps, customFields: customFields)
        workouts[workoutIndex].exercises[exerciseIndex].sets.append(set)
        workouts[workoutIndex].updatedAt = .now
    }

    func addExerciseToWorkout(_ sessionID: UUID, exercise: Exercise) {
        guard let workoutIndex = workouts.firstIndex(where: { $0.id == sessionID }) else { return }
        let entry = ExerciseEntry(exercise: exercise, sets: [])
        workouts[workoutIndex].exercises.append(entry)
        workouts[workoutIndex].updatedAt = .now
    }

    func updateSet(sessionID: UUID, exerciseID: UUID, setID: UUID, weight: Double, reps: Int, rpe: Double?, notes: String?, customFields: [String: String]) {
        guard let workoutIndex = workouts.firstIndex(where: { $0.id == sessionID }),
              let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.exercise.id == exerciseID }),
              let setIndex = workouts[workoutIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].weight = weight
        workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].reps = reps
        workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].rpe = rpe
        workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].notes = notes
        workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].customFields = customFields
        workouts[workoutIndex].updatedAt = .now
    }

    func closeWorkout(id: UUID, endTime: Date = .now, notes: String = "") {
        guard let idx = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[idx].endTime = endTime
        workouts[idx].isOngoing = false
        workouts[idx].notes = notes
        workouts[idx].updatedAt = .now
    }

    func deleteWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    func exportCSV() -> URL? {
        let header = "Date,Type,Exercise,Set,Weight,Reps,Notes"\n"
        var rows: [String] = [header]
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        for workout in workouts {
            for exercise in workout.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    let row = "\(formatter.string(from: workout.startTime)),\(workout.type.name),\(exercise.exercise.name),\(index + 1),\(set.weight),\(set.reps),\(set.notes ?? "")"
                    rows.append(row)
                }
            }
        }
        let csv = rows.joined(separator: "\n")
        let url = fileURL.deletingLastPathComponent().appendingPathComponent("workouts.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("CSV export failed: \(error.localizedDescription)")
            return nil
        }
    }

    func markExportedToHealth(count: Int) {
        healthExportStatus.lastExportedAt = .now
        healthExportStatus.workoutsExported += count
    }

    func addGymLocation(label: String, address: String, coordinate: CLLocationCoordinate2D, radius: Double = 100) {
        let location = GymLocation(label: label, address: address, latitude: coordinate.latitude, longitude: coordinate.longitude, radius: radius)
        gymLocations.append(location)
    }

    func updateTheme(_ preference: ThemePreference) {
        themeManager.preference = preference
    }

    func addTimer(label: String, duration: TimeInterval) {
        let timer = RestTimer(label: label, duration: duration, expiresAt: .now.addingTimeInterval(duration))
        activeTimers.append(timer)
    }

    func removeExpiredTimers() {
        let now = Date()
        activeTimers.removeAll { $0.expiresAt < now }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            self.workoutTypes = decoded.types
            self.exercises = decoded.exercises
            self.workouts = decoded.workouts
            self.gymLocations = decoded.gymLocations
            self.healthExportStatus = decoded.healthExportStatus
            self.timerPresets = decoded.timerPresets
        } catch {
            seedDefaults()
        }
    }

    func observeAutosave() {
        Publishers.CombineLatest4($workouts, $gymLocations, $workoutTypes, $exercises)
            .combineLatest($timerPresets)
        $workouts
            .combineLatest($gymLocations, $workoutTypes, $exercises, $timerPresets)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    func syncFromUbiquitousStore() {
        let ubiquitousStore = NSUbiquitousKeyValueStore.default
        ubiquitousStore.synchronize()
        if let data = ubiquitousStore.data(forKey: "workoutPayload") {
            do {
                let payload = try JSONDecoder().decode(Payload.self, from: data)
                self.workoutTypes = payload.types
                self.exercises = payload.exercises
                self.workouts = payload.workouts
                self.gymLocations = payload.gymLocations
                self.healthExportStatus = payload.healthExportStatus
                self.timerPresets = payload.timerPresets
            } catch {
                logger.error("iCloud decode failed: \(error.localizedDescription)")
            }
        }
    }

    func save() {
        saveTask?.cancel()
        saveTask = Task { [types = workoutTypes, workouts = workouts, exercises = exercises, gyms = gymLocations, health = healthExportStatus, timers = timerPresets] in
            let payload = Payload(types: types, exercises: exercises, workouts: workouts, gymLocations: gyms, healthExportStatus: health, timerPresets: timers)
            do {
                let data = try JSONEncoder().encode(payload)
                try data.write(to: fileURL, options: .atomic)
                NSUbiquitousKeyValueStore.default.set(data, forKey: "workoutPayload")
                NSUbiquitousKeyValueStore.default.synchronize()
            } catch {
                logger.error("Save failed: \(error.localizedDescription)")
            }
        }
    }

    func quickAddSets(sessionID: UUID, exerciseID: UUID, template: SetEntry, count: Int) {
        guard let workoutIndex = workouts.firstIndex(where: { $0.id == sessionID }),
              let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.exercise.id == exerciseID }) else { return }
        for _ in 0..<count {
            workouts[workoutIndex].exercises[exerciseIndex].sets.append(template)
        }
        workouts[workoutIndex].updatedAt = .now
    }

    func addCustomField(to sessionID: UUID, key: String, value: String) {
        guard let idx = workouts.firstIndex(where: { $0.id == sessionID }) else { return }
        workouts[idx].notes += "\n\(key): \(value)"
        workouts[idx].updatedAt = .now
    }

    func streakCount() -> Int {
        let calendar = Calendar.current
        let sorted = workouts.sorted { $0.startTime > $1.startTime }
        guard let latest = sorted.first else { return 0 }
        var streak = 1
        var currentDate = calendar.startOfDay(for: latest.startTime)
        for workout in sorted.dropFirst() {
            let date = calendar.startOfDay(for: workout.startTime)
            if calendar.isDate(date, inSameDayAs: currentDate.addingTimeInterval(-86400)) {
                streak += 1
                currentDate = date
            } else if date < currentDate.addingTimeInterval(-86400) {
                break
            }
        }
        return streak
    }

    func workoutsLast(days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return workouts.filter { $0.startTime >= cutoff }.count
    }

    func pr(for exerciseID: UUID) -> Double? {
        workouts.flatMap { $0.exercises }
            .filter { $0.exercise.id == exerciseID }
            .flatMap { $0.sets }
            .map { $0.weight }
            .max()
    }

    func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        max(weight / (1.0278 - 0.0278 * Double(reps)), weight)
    }

    func prMap() -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for exercise in exercises {
            if let best = pr(for: exercise.id) {
                result[exercise.id] = best
            }
        }
        return result
    }

    func averageDurationMinutes() -> Double {
        let durations = workouts.compactMap { workout -> Double? in
            guard let end = workout.endTime else { return nil }
            return end.timeIntervalSince(workout.startTime) / 60
        }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    func snapshotMetrics() -> MetricSnapshot {
        MetricSnapshot(
            date: .now,
            workoutsThisWeek: workoutsLast(days: 7),
            workoutsThisMonth: workoutsLast(days: 30),
            streakDays: streakCount(),
            prMap: prMap(),
            averageDurationMinutes: averageDurationMinutes()
        )
    }

    private func seedDefaults() {
        let defaultTypes = ["Chest", "Arms", "Legs", "Core", "Cardio", "HIIT"].map { WorkoutType(name: $0) }
        self.workoutTypes = defaultTypes
        self.exercises = [
            Exercise(name: "Bench Press", workoutTypeID: defaultTypes[0].id, defaultWeight: 45, defaultReps: 8),
            Exercise(name: "Squat", workoutTypeID: defaultTypes[2].id, defaultWeight: 95, defaultReps: 8),
            Exercise(name: "Deadlift", workoutTypeID: defaultTypes[2].id, defaultWeight: 135, defaultReps: 5)
        ]
        self.workouts = []
        self.gymLocations = []
    }
}

private extension WorkoutStore {
    struct Payload: Codable {
        var types: [WorkoutType]
        var exercises: [Exercise]
        var workouts: [WorkoutSession]
        var gymLocations: [GymLocation]
        var healthExportStatus: HealthExportStatus
        var timerPresets: [TimerPreset]
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("themePreference") var preference: ThemePreference = .system {
        didSet { objectWillChange.send() }
    }

    var preferredColorScheme: ColorScheme? {
        preference.colorScheme
    }
}

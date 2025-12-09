import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showNewWorkoutSheet = false
    @State private var selectedType: WorkoutType?

    var body: some View {
        List {
            if let ongoing = store.workouts.first(where: { $0.isOngoing }) {
                Section("Ongoing") {
                    NavigationLink(value: ongoing.id) {
                        VStack(alignment: .leading) {
                            Text(ongoing.type.name)
                                .font(.headline)
                            Text("Started at \(ongoing.startTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Start a workout") {
                ForEach(store.workoutTypes) { type in
                    Button {
                        selectedType = type
                        store.startWorkout(type: type)
                    } label: {
                        Label(type.name, systemImage: "play.circle")
                    }
                }
                Button {
                    showNewWorkoutSheet = true
                } label: {
                    Label("Create new type", systemImage: "plus")
                }
            }

            Section("Past workouts") {
                ForEach(store.workouts.filter { !$0.isOngoing }) { workout in
                    NavigationLink(value: workout.id) {
                        VStack(alignment: .leading) {
                            Text(workout.type.name)
                            HStack {
                                Text(workout.startTime, style: .date)
                                Text(workout.startTime, style: .time)
                                if let duration = workoutDuration(workout) {
                                    Text("• \(duration, format: .number.precision(.fractionLength(0..1))) min")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let session = store.workouts.first(where: { $0.id == id }) {
                WorkoutSessionView(session: session)
            }
        }
        .sheet(isPresented: $showNewWorkoutSheet) {
            AddWorkoutTypeView(isPresented: $showNewWorkoutSheet)
                .presentationDetents([.medium])
        }
        .navigationTitle("Workout")
    }

    private func workoutDuration(_ session: WorkoutSession) -> Double? {
        guard let end = session.endTime else { return nil }
        return end.timeIntervalSince(session.startTime) / 60
    }
}

struct AddWorkoutTypeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Binding var isPresented: Bool
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Type name", text: $name)
            }
            .navigationTitle("New workout type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addWorkoutType(name: name)
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

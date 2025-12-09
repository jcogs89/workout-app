import Foundation
import SwiftUI
import CoreLocation

struct WorkoutType: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String
}

struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String
    var workoutTypeID: UUID
    var defaultWeight: Double? = nil
    var defaultReps: Int? = nil
}

struct SetEntry: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var weight: Double
    var reps: Int
    var rpe: Double? = nil
    var notes: String? = nil
    var customFields: [String: String] = [:]
}

struct ExerciseEntry: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var exercise: Exercise
    var sets: [SetEntry]
    var customFields: [String: String] = [:]
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var type: WorkoutType
    var exercises: [ExerciseEntry] = []
    var startTime: Date = .init()
    var endTime: Date? = nil
    var isOngoing: Bool = true
    var gymLocation: GymLocation? = nil
    var notes: String = ""
    var createdAt: Date = .init()
    var updatedAt: Date = .init()
}

struct GymLocation: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var label: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 100
}

struct MetricSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var date: Date
    var workoutsThisWeek: Int
    var workoutsThisMonth: Int
    var streakDays: Int
    var prMap: [UUID: Double] // Exercise.id -> best weight
    var averageDurationMinutes: Double
}

struct TimerPreset: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var name: String
    var seconds: Int
}

struct RestTimer: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var label: String
    var duration: TimeInterval
    var expiresAt: Date
}

struct HealthExportStatus: Codable, Hashable {
    var lastExportedAt: Date?
    var workoutsExported: Int
}

enum ThemePreference: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

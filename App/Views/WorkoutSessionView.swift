import SwiftUI

struct WorkoutSessionView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State var session: WorkoutSession
    @State private var showAddExercise = false
    @State private var quickAddCount: Int = 1
    @State private var setTemplate = SetEntry(weight: 45, reps: 8)
    @State private var showTimerSheet = false

    var body: some View {
        List {
            Section {
                DatePicker("Start", selection: Binding(get: { session.startTime }, set: { session.startTime = $0 }), displayedComponents: [.date, .hourAndMinute])
                if let end = session.endTime {
                    DatePicker("End", selection: Binding(get: { end }, set: { session.endTime = $0 }), displayedComponents: [.date, .hourAndMinute])
                } else {
                    Button("End workout now") {
                        store.closeWorkout(id: session.id, endTime: .now)
                        session.endTime = .now
                        session.isOngoing = false
                    }
                }
                if let gym = session.gymLocation {
                    Label(gym.label, systemImage: "mappin.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Exercises") {
                ForEach(session.exercises) { entry in
                    ExerciseEntryView(entry: entry, sessionID: session.id)
                }
                Button {
                    showAddExercise = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
            }

            Section("Quick add sets") {
                Stepper("Sets: \(quickAddCount)", value: $quickAddCount, in: 1...10)
                HStack {
                    TextField("Weight", value: $setTemplate.weight, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Reps", value: $setTemplate.reps, format: .number)
                        .keyboardType(.numberPad)
                    Spacer()
                    Button("Apply to last exercise") {
                        guard let last = session.exercises.last else { return }
                        store.quickAddSets(sessionID: session.id, exerciseID: last.exercise.id, template: setTemplate, count: quickAddCount)
                        session = store.workouts.first(where: { $0.id == session.id }) ?? session
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section("Timers") {
                ForEach(store.activeTimers) { timer in
                    Label("\(timer.label)", systemImage: "timer")
                    Text(timer.expiresAt, style: .timer)
                        .foregroundStyle(.secondary)
                }
                Button("Add rest timer") { showTimerSheet = true }
            }
        }
        .onReceive(store.$workouts) { workouts in
            if let updated = workouts.first(where: { $0.id == session.id }) {
                session = updated
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseView(session: session)
        }
        .sheet(isPresented: $showTimerSheet) {
            AddTimerView(isPresented: $showTimerSheet)
        }
        .navigationTitle(session.type.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.closeWorkout(id: session.id, endTime: session.endTime ?? .now, notes: session.notes)
                }
                Button(role: .destructive) {
                    store.deleteWorkout(id: session.id)
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

struct ExerciseEntryView: View {
    @EnvironmentObject private var store: WorkoutStore
    var entry: ExerciseEntry
    var sessionID: UUID
    @State private var showSetEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.exercise.name)
                    .font(.headline)
                Spacer()
                Button("Add set") {
                    showSetEditor = true
                }
            }
            ForEach(entry.sets) { set in
                HStack {
                    Text("\(set.weight, format: .number) lb")
                    Text("x \(set.reps)")
                    if let rpe = set.rpe { Text("RPE \(rpe, format: .number.precision(.fractionLength(0..1)))") }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { showSetEditor = true }
            }
        }
        .sheet(isPresented: $showSetEditor) {
            SetEditorView(sessionID: sessionID, entry: entry)
        }
    }
}

struct SetEditorView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var entry: ExerciseEntry
    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var rpe: Double? = nil
    @State private var notes: String = ""
    @State private var customFields: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Set") {
                    TextField("Weight", value: $weight, format: .number)
                    TextField("Reps", value: $reps, format: .number)
                    TextField("RPE (optional)", value: Binding(get: { rpe ?? 0 }, set: { rpe = $0 }), format: .number)
                    TextField("Notes", text: $notes)
                }
                Section("Custom fields") {
                    ForEach(Array(customFields.keys), id: \.self) { key in
                        TextField(key, text: Binding(get: { customFields[key] ?? "" }, set: { customFields[key] = $0 }))
                    }
                    Button("Add field") {
                        customFields["Field \(customFields.count + 1)"] = ""
                    }
                }
            }
            .onAppear {
                if let last = entry.sets.last {
                    weight = last.weight
                    reps = last.reps
                    rpe = last.rpe
                    notes = last.notes ?? ""
                    customFields = last.customFields
                }
            }
            .navigationTitle("Edit set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateSet(sessionID: sessionID, exerciseID: entry.exercise.id, setID: entry.sets.last?.id ?? UUID(), weight: weight, reps: reps, rpe: rpe, notes: notes, customFields: customFields)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddExerciseView: View {
    @EnvironmentObject private var store: WorkoutStore
    var session: WorkoutSession
    @State private var search: String = ""
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Pick exercise") {
                    ForEach(filteredExercises) { exercise in
                        Button(exercise.name) {
                            store.addExerciseToWorkout(session.id, exercise: exercise)
                        }
                    }
                }
                Section("Add new exercise") {
                    TextField("Name", text: $newName)
                    Button("Add to type \(session.type.name)") {
                        store.addExercise(name: newName, type: session.type)
                        if let exercise = store.exercises.last {
                            store.addExerciseToWorkout(session.id, exercise: exercise)
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add exercise")
        }
    }

    private var filteredExercises: [Exercise] {
        store.exercises.filter { $0.workoutTypeID == session.type.id && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }
}

struct AddTimerView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Binding var isPresented: Bool
    @State private var duration: Double = 60
    @State private var label: String = "Rest"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label)
                Slider(value: $duration, in: 10...600, step: 10) {
                    Text("Duration")
                }
                Text("\(Int(duration)) seconds")
            }
            .navigationTitle("Add timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        store.addTimer(label: label, duration: duration)
                        isPresented = false
                    }
                }
            }
        }
    }
}

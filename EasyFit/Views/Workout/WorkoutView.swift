import SwiftUI

struct WorkoutView: View {
    @StateObject private var vm = WorkoutViewModel.preview()
    @State private var showAddPlan = false
    @State private var editingPlan: WorkoutPlan? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if vm.plans.isEmpty {
                        EmptyWorkoutState { showAddPlan = true }
                    } else {
                        ForEach(vm.plans) { plan in
                            WorkoutPlanCard(
                                plan: plan,
                                onToggle: { exerciseId in
                                    vm.toggleExercise(planId: plan.id, exerciseId: exerciseId)
                                },
                                onEdit: { editingPlan = plan },
                                onDelete: { vm.deletePlan(plan) }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPlan = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddEditPlanView { newPlan in
                    vm.addPlan(newPlan)
                }
            }
            .sheet(item: $editingPlan) { plan in
                AddEditPlanView(existingPlan: plan) { updated in
                    vm.updatePlan(updated)
                }
            }
        }
    }
}

// MARK: - Empty state

struct EmptyWorkoutState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No workout plans yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Build your weekly schedule by adding a plan for each training day.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onAdd) {
                Label("Add first plan", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Plan card

struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    let onToggle: (UUID) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var isToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let mapped  = weekday == 1 ? 7 : weekday - 1
        return plan.weekday.rawValue == mapped
    }
    var allDone: Bool { plan.exercises.allSatisfy(\.isCompleted) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(isToday ? "Today" : allDone ? "Done" : plan.weekday.short)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(isToday ? Color.primary : allDone ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
                    .foregroundStyle(isToday ? Color(uiColor: .systemBackground) : allDone ? .green : .secondary)
                    .clipShape(Capsule())

                Menu {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }

            Divider()

            ForEach(plan.exercises) { exercise in
                HStack(spacing: 10) {
                    Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(exercise.isCompleted ? .green : .secondary)
                        .onTapGesture { onToggle(exercise.id) }
                    Text(exercise.name)
                        .font(.system(size: 14))
                        .foregroundStyle(exercise.isCompleted ? .secondary : .primary)
                        .strikethrough(exercise.isCompleted, color: .secondary)
                    Spacer()
                    Text("\(exercise.sets)×\(exercise.reps)  \(exercise.displayWeight)")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isToday ? Color.primary : .clear, lineWidth: 1.5))
    }
}

// MARK: - Add / Edit plan sheet

struct AddEditPlanView: View {
    @Environment(\.dismiss) private var dismiss

    let existingPlan: WorkoutPlan?
    let onSave: (WorkoutPlan) -> Void

    @State private var name: String
    @State private var weekday: Weekday
    @State private var exercises: [Exercise]
    @State private var showAddExercise = false

    init(existingPlan: WorkoutPlan? = nil, onSave: @escaping (WorkoutPlan) -> Void) {
        self.existingPlan = existingPlan
        self.onSave = onSave
        _name      = State(initialValue: existingPlan?.name ?? "")
        _weekday   = State(initialValue: existingPlan?.weekday ?? .monday)
        _exercises = State(initialValue: existingPlan?.exercises ?? [])
    }

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan details") {
                    TextField("e.g. Push Day, Leg Day…", text: $name)

                    Picker("Day", selection: $weekday) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Text(day.short).tag(day)
                        }
                    }
                }

                Section {
                    ForEach(exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                    .onDelete { indices in
                        exercises.remove(atOffsets: indices)
                    }
                    .onMove { from, to in
                        exercises.move(fromOffsets: from, toOffset: to)
                    }

                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if !exercises.isEmpty {
                            EditButton()
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            .navigationTitle(existingPlan == nil ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let plan = WorkoutPlan(
                            id: existingPlan?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            weekday: weekday,
                            exercises: exercises
                        )
                        onSave(plan)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView { exercise in
                    exercises.append(exercise)
                }
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.system(size: 14))
                Text("\(exercise.sets) sets × \(exercise.reps) reps  \(exercise.displayWeight)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add exercise sheet

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Exercise) -> Void

    @State private var name    = ""
    @State private var sets    = "3"
    @State private var reps    = "10"
    @State private var weight  = ""
    @State private var unit: WeightUnit = .lbs
    @State private var isBodyweight = false

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(sets) != nil && Int(reps) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("e.g. Bench Press, Squat…", text: $name)
                }

                Section("Volume") {
                    HStack {
                        Text("Sets")
                        Spacer()
                        TextField("3", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("10", text: $reps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Weight") {
                    Toggle("Bodyweight", isOn: $isBodyweight)

                    if !isBodyweight {
                        HStack {
                            TextField("e.g. 135", text: $weight)
                                .keyboardType(.decimalPad)
                            Picker("Unit", selection: $unit) {
                                Text("lb").tag(WeightUnit.lbs)
                                Text("kg").tag(WeightUnit.kg)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let exercise = Exercise(
                            name:   name.trimmingCharacters(in: .whitespaces),
                            sets:   Int(sets)  ?? 3,
                            reps:   Int(reps)  ?? 10,
                            weight: isBodyweight ? nil : Double(weight),
                            unit:   unit
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview { WorkoutView() }

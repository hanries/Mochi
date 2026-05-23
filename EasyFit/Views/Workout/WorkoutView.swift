import SwiftUI
import SwiftData

// MARK: - Main Workout View

struct WorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutPlan.weekdayRaw) private var plans: [WorkoutPlan]

    @State private var showAddPlan  = false
    @State private var editingPlan: WorkoutPlan? = nil
    @State private var selectedDay: Weekday = Self.todayWeekday()

    static func todayWeekday() -> Weekday {
        let w = Calendar.current.component(.weekday, from: .now)
        return Weekday(rawValue: w == 1 ? 7 : w - 1) ?? .monday
    }

    var plansForSelectedDay: [WorkoutPlan] {
        plans.filter { $0.weekdayRaw == selectedDay.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekdayPicker(selected: $selectedDay, plans: plans)
                    .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 12) {
                        if plansForSelectedDay.isEmpty {
                            EmptyDayState(day: selectedDay) { showAddPlan = true }
                        } else {
                            ForEach(plansForSelectedDay) { plan in
                                WorkoutPlanCard(
                                    plan: plan,
                                    onToggle: { exId in
                                        plan.exercises.first { $0.id == exId }?.isCompleted.toggle()
                                    },
                                    onEdit:   { editingPlan = plan },
                                    onDelete: { context.delete(plan) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddPlan = true } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddEditPlanView(defaultDay: selectedDay) { name, days, exercises in
                    // Create one WorkoutPlan per selected day
                    for day in days {
                        let plan = WorkoutPlan(name: name, weekday: day)
                        context.insert(plan)
                        for (i, ex) in exercises.enumerated() {
                            let copy = Exercise(
                                name: ex.name, sets: ex.sets, reps: ex.reps,
                                weight: ex.weight, unit: ex.unit, order: i
                            )
                            context.insert(copy)
                            plan.exercises.append(copy)
                        }
                    }
                }
            }
            .sheet(item: $editingPlan) { plan in
                AddEditPlanView(existingPlan: plan) { name, days, exercises in
                    plan.name    = name
                    plan.weekday = days.first ?? plan.weekday
                    for ex in plan.exercises { context.delete(ex) }
                    plan.exercises = []
                    for (i, ex) in exercises.enumerated() {
                        ex.order = i
                        context.insert(ex)
                        plan.exercises.append(ex)
                    }
                }
            }
        }
    }
}

// MARK: - Weekday Picker (7 buttons)

struct WeekdayPicker: View {
    @Binding var selected: Weekday
    let plans: [WorkoutPlan]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let hasPlans = plans.contains { $0.weekdayRaw == day.rawValue }
                let isToday  = day.rawValue == (Calendar.current.component(.weekday, from: .now) == 1 ? 7 : Calendar.current.component(.weekday, from: .now) - 1)
                let isSelected = selected == day

                Button { selected = day } label: {
                    VStack(spacing: 4) {
                        Text(day.short.prefix(1))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : isToday ? .primary : .secondary)

                        Text("\(dayNumber(for: day))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)

                        Circle()
                            .fill(isSelected ? Color(uiColor: .systemBackground).opacity(0.6) : hasPlans ? Color.primary : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.primary : isToday ? Color.primary.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func dayNumber(for day: Weekday) -> Int {
        let cal     = Calendar.current
        let today   = cal.startOfDay(for: .now)
        let todayWD = cal.component(.weekday, from: today)
        let mapped  = todayWD == 1 ? 7 : todayWD - 1
        let offset  = day.rawValue - mapped
        let target  = cal.date(byAdding: .day, value: offset, to: today)!
        return cal.component(.day, from: target)
    }
}

// MARK: - Empty day state

struct EmptyDayState: View {
    let day: Weekday
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No workouts on \(day.short)")
                .font(.system(size: 17, weight: .semibold))
            Text("Add a plan to schedule exercises for this day.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onAdd) {
                Label("Add workout", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Plan Card

struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    let onToggle: (UUID) -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var allDone: Bool { !plan.exercises.isEmpty && plan.exercises.allSatisfy(\.isCompleted) }
    var sortedExercises: [Exercise] { plan.exercises.sorted { $0.order < $1.order } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.name).font(.system(size: 15, weight: .semibold))
                Spacer()
                if allDone {
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                Menu {
                    Button { onEdit() }   label: { Label("Edit",   systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }

            if !sortedExercises.isEmpty { Divider() }

            ForEach(sortedExercises) { exercise in
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
    }
}

// MARK: - Add / Edit Plan Sheet

struct AddEditPlanView: View {
    @Environment(\.dismiss) private var dismiss

    let existingPlan: WorkoutPlan?
    let defaultDay:   Weekday
    let onSave: (String, Set<Weekday>, [Exercise]) -> Void

    @State private var name:           String
    @State private var selectedDays:   Set<Weekday>
    @State private var exercises:      [Exercise]
    @State private var showAddExercise = false

    init(existingPlan: WorkoutPlan? = nil, defaultDay: Weekday = .monday,
         onSave: @escaping (String, Set<Weekday>, [Exercise]) -> Void) {
        self.existingPlan = existingPlan
        self.defaultDay   = defaultDay
        self.onSave       = onSave
        _name         = State(initialValue: existingPlan?.name ?? "")
        _selectedDays = State(initialValue: existingPlan.map { [$0.weekday] } ?? [defaultDay])
        _exercises    = State(initialValue: existingPlan?.exercises.sorted { $0.order < $1.order } ?? [])
    }

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan name") {
                    TextField("e.g. Push Day, Leg Day…", text: $name)
                }

                Section {
                    DayPickerGrid(selectedDays: $selectedDays, isEditMode: existingPlan != nil)
                } header: {
                    Text("Training days")
                } footer: {
                    if existingPlan == nil {
                        Text("This plan will be added to each selected day.")
                            .font(.system(size: 12))
                    }
                }

                Section {
                    ForEach(exercises) { ex in ExerciseRow(exercise: ex) }
                        .onDelete { exercises.remove(atOffsets: $0) }
                        .onMove  { exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button { showAddExercise = true } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        if !exercises.isEmpty { EditButton().font(.system(size: 12)) }
                    }
                }
            }
            .navigationTitle(existingPlan == nil ? "New Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), selectedDays, exercises)
                        dismiss()
                    }
                    .disabled(!isValid).fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView { exercises.append($0) }
            }
        }
    }
}

// MARK: - Day Picker Grid (7 toggleable day buttons)

struct DayPickerGrid: View {
    @Binding var selectedDays: Set<Weekday>
    let isEditMode: Bool          // in edit mode, only allow 1 day

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    let isOn = selectedDays.contains(day)
                    Button {
                        if isEditMode {
                            selectedDays = [day]
                        } else {
                            if isOn { selectedDays.remove(day) }
                            else    { selectedDays.insert(day) }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.short.prefix(1))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isOn ? Color(uiColor: .systemBackground) : .secondary)
                            Text(day.short.dropFirst())
                                .font(.system(size: 10))
                                .foregroundStyle(isOn ? Color(uiColor: .systemBackground).opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? Color.primary : Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Subviews

private struct ExerciseRow: View {
    let exercise: Exercise
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name).font(.system(size: 14))
            Text("\(exercise.sets) sets × \(exercise.reps) reps  \(exercise.displayWeight)")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Exercise) -> Void

    @State private var name         = ""
    @State private var sets         = "3"
    @State private var reps         = "10"
    @State private var weight       = ""
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
                        Text("Sets"); Spacer()
                        TextField("3", text: $sets).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(width: 60)
                    }
                    HStack {
                        Text("Reps"); Spacer()
                        TextField("10", text: $reps).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(width: 60)
                    }
                }
                Section("Weight") {
                    Toggle("Bodyweight", isOn: $isBodyweight)
                    if !isBodyweight {
                        HStack {
                            TextField("e.g. 135", text: $weight).keyboardType(.decimalPad)
                            Picker("Unit", selection: $unit) {
                                Text("lb").tag(WeightUnit.lbs)
                                Text("kg").tag(WeightUnit.kg)
                            }
                            .pickerStyle(.segmented).frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onSave(Exercise(
                            name:   name.trimmingCharacters(in: .whitespaces),
                            sets:   Int(sets)  ?? 3,
                            reps:   Int(reps)  ?? 10,
                            weight: isBodyweight ? nil : Double(weight),
                            unit:   unit
                        ))
                        dismiss()
                    }
                    .disabled(!isValid).fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    WorkoutView()
        .modelContainer(for: [WorkoutPlan.self, Exercise.self], inMemory: true)
}

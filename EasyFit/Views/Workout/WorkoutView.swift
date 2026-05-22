import SwiftUI

struct WorkoutView: View {
    @StateObject private var vm = WorkoutViewModel.preview()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.plans) { plan in
                        WorkoutPlanCard(plan: plan) { exerciseId in
                            vm.toggleExercise(planId: plan.id, exerciseId: exerciseId)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.showAddExercise = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    let onToggle: (UUID) -> Void

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

#Preview { WorkoutView() }

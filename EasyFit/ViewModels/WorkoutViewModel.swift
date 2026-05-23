import Foundation
import Combine

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var plans:           [WorkoutPlan] = []
    @Published var showAddExercise: Bool          = false

    var todayPlan: WorkoutPlan? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let mapped  = weekday == 1 ? 7 : weekday - 1
        return plans.first { $0.weekday.rawValue == mapped }
    }

    func addPlan(_ plan: WorkoutPlan)    { plans.append(plan) }
    func deletePlan(_ plan: WorkoutPlan) { plans.removeAll { $0.id == plan.id } }

    func updatePlan(_ plan: WorkoutPlan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[i] = plan
    }

    func toggleExercise(planId: UUID, exerciseId: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planId }),
              let ei = plans[pi].exercises.firstIndex(where: { $0.id == exerciseId })
        else { return }
        plans[pi].exercises[ei].isCompleted.toggle()
    }

    static func preview() -> WorkoutViewModel {
        let vm = WorkoutViewModel()
        vm.plans = [
            WorkoutPlan(name: "Push Day", weekday: .monday, exercises: [
                Exercise(name: "Bench press",    sets: 4, reps: 8,  weight: 185, isCompleted: true),
                Exercise(name: "Shoulder press", sets: 3, reps: 10, weight: 115, isCompleted: true),
                Exercise(name: "Tricep dips",    sets: 3, reps: 12,              isCompleted: true),
            ]),
            WorkoutPlan(name: "Pull Day", weekday: .friday, exercises: [
                Exercise(name: "Deadlift",   sets: 4, reps: 5,  weight: 275),
                Exercise(name: "Pull-ups",   sets: 4, reps: 8),
                Exercise(name: "Cable rows", sets: 3, reps: 12, weight: 120),
                Exercise(name: "Face pulls", sets: 3, reps: 15, weight: 60),
            ]),
            WorkoutPlan(name: "Leg Day", weekday: .saturday, exercises: [
                Exercise(name: "Squat",             sets: 4, reps: 6,  weight: 225),
                Exercise(name: "Romanian deadlift", sets: 3, reps: 10, weight: 185),
            ]),
        ]
        return vm
    }
}

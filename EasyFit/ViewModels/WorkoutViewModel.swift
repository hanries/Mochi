import Foundation
import SwiftData
import Combine

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var showAddExercise: Bool = false

    var todayPlan: WorkoutPlan? = nil

    func refreshTodayPlan(from plans: [WorkoutPlan]) -> WorkoutPlan? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let mapped  = weekday == 1 ? 7 : weekday - 1
        return plans.first { $0.weekdayRaw == mapped }
    }
}

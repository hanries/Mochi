import Foundation
import SwiftData
import Combine

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var goal: DailyNutritionGoal = .current
    @Published var selectedDate: Date = .now

    // Called by the view passing in SwiftData query results
    func todayEntries(from all: [FoodEntry]) -> [FoodEntry] {
        all.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    func entries(for meal: MealType, from all: [FoodEntry]) -> [FoodEntry] {
        todayEntries(from: all).filter { $0.mealType == meal }
    }

    func totalCalories(from all: [FoodEntry]) -> Int {
        todayEntries(from: all).reduce(0) { $0 + $1.calories }
    }
    func totalProtein(from all: [FoodEntry]) -> Double {
        todayEntries(from: all).reduce(0) { $0 + $1.protein }
    }
    func totalCarbs(from all: [FoodEntry]) -> Double {
        todayEntries(from: all).reduce(0) { $0 + $1.carbs }
    }
    func totalFat(from all: [FoodEntry]) -> Double {
        todayEntries(from: all).reduce(0) { $0 + $1.fat }
    }
    func mealCalories(for meal: MealType, from all: [FoodEntry]) -> Int {
        entries(for: meal, from: all).reduce(0) { $0 + $1.calories }
    }

    func saveGoal() {
        DailyNutritionGoal.current = goal
    }
}

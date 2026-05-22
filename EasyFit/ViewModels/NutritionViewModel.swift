import Foundation
import Combine

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var entries: [FoodEntry] = []
    @Published var goal    = DailyNutritionGoal()
    @Published var selectedDate: Date = .now

    var todayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var totalCalories: Int    { todayEntries.reduce(0) { $0 + $1.calories } }
    var totalProtein:  Double { todayEntries.reduce(0) { $0 + $1.protein  } }
    var totalCarbs:    Double { todayEntries.reduce(0) { $0 + $1.carbs    } }
    var totalFat:      Double { todayEntries.reduce(0) { $0 + $1.fat      } }

    var remainingCalories: Int    { goal.calories - totalCalories }
    var calorieProgress:   Double { min(Double(totalCalories) / Double(goal.calories), 1.0) }

    func entries(for meal: MealType) -> [FoodEntry] {
        todayEntries.filter { $0.mealType == meal }
    }

    func mealCalories(for meal: MealType) -> Int {
        entries(for: meal).reduce(0) { $0 + $1.calories }
    }

    func addEntry(_ entry: FoodEntry)    { entries.append(entry) }
    func deleteEntry(_ entry: FoodEntry) { entries.removeAll { $0.id == entry.id } }

    static func preview() -> NutritionViewModel {
        let vm = NutritionViewModel()
        vm.entries = [
            FoodEntry(name: "Scrambled eggs",      calories: 280, protein: 21, carbs: 2,  fat: 20, servingSize: "3 eggs",  mealType: .breakfast),
            FoodEntry(name: "Avocado toast",        calories: 240, protein: 5,  carbs: 28, fat: 14, servingSize: "1 slice", mealType: .breakfast),
            FoodEntry(name: "Grilled chicken bowl", calories: 620, protein: 52, carbs: 58, fat: 18, servingSize: "400g",    mealType: .lunch),
        ]
        return vm
    }
}

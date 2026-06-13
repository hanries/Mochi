import Foundation
import SwiftData
import UIKit
// MARK: - Nutrition

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String
    var mealTypeRaw: String
    var date: Date
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        servingSize: String = "1 serving",
        mealType: MealType,
        date: Date = .now,
        isCustom: Bool = false
    ) {
        self.id          = id
        self.name        = name
        self.calories    = calories
        self.protein     = protein
        self.carbs       = carbs
        self.fat         = fat
        self.servingSize = servingSize
        self.mealTypeRaw = mealType.rawValue
        self.date        = date
        self.isCustom    = isCustom
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .breakfast }
        set { mealTypeRaw = newValue.rawValue }
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"
}

// MARK: - Nutrition Goal (UserDefaults — single record, not a collection)

struct DailyNutritionGoal: Codable {
    var calories: Int    = 2100
    var protein:  Double = 160
    var carbs:    Double = 200
    var fat:      Double = 65

    init(calories: Int = 2100, protein: Double = 160, carbs: Double = 200, fat: Double = 65) {
        self.calories = calories
        self.protein  = protein
        self.carbs    = carbs
        self.fat      = fat
    }

    static var current: DailyNutritionGoal {
        get {
            guard let data = UserDefaults.standard.data(forKey: "nutritionGoal"),
                  let goal = try? JSONDecoder().decode(DailyNutritionGoal.self, from: data)
            else { return DailyNutritionGoal() }
            return goal
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "nutritionGoal")
        }
    }
}

// MARK: - Workout

@Model
final class WorkoutPlan {
    var id: UUID
    var name: String
    var weekdayRaw: Int
    @Relationship(deleteRule: .cascade) var exercises: [Exercise]

    init(id: UUID = UUID(), name: String, weekday: Weekday, exercises: [Exercise] = []) {
        self.id          = id
        self.name        = name
        self.weekdayRaw  = weekday.rawValue
        self.exercises   = exercises
    }

    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double?
    var unitRaw: String
    var isCompleted: Bool
    var order: Int

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: Int,
        weight: Double? = nil,
        unit: WeightUnit = .lbs,
        isCompleted: Bool = false,
        order: Int = 0
    ) {
        self.id          = id
        self.name        = name
        self.sets        = sets
        self.reps        = reps
        self.weight      = weight
        self.unitRaw     = unit.rawValue
        self.isCompleted = isCompleted
        self.order       = order
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .lbs }
        set { unitRaw = newValue.rawValue }
    }

    var displayWeight: String {
        if let w = weight { return "\(Int(w)) \(unit.rawValue)" }
        return "BW"
    }
}

enum WeightUnit: String, Codable {
    case lbs = "lb"
    case kg  = "kg"
}

enum Weekday: Int, Codable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var short: String {
        switch self {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
        }
    }

    var full: String {
        switch self {
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        case .sunday:    return "Sunday"
        }
    }
}

// MARK: - Progress

@Model
final class BodyWeightEntry {
    var id: UUID
    var weight: Double
    var unitRaw: String
    var date: Date

    init(id: UUID = UUID(), weight: Double, unit: WeightUnit = .lbs, date: Date = .now) {
        self.id      = id
        self.weight  = weight
        self.unitRaw = unit.rawValue
        self.date    = date
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .lbs }
        set { unitRaw = newValue.rawValue }
    }
}

// MARK: - Journal

@Model
final class JournalEntry {
    var id:       UUID
    var date:     Date
    var note:     String
    var imageData: Data?   // stored locally, never synced

    init(id: UUID = UUID(), date: Date = .now, note: String = "", imageData: Data? = nil) {
        self.id        = id
        self.date      = date
        self.note      = note
        self.imageData = imageData
    }

    var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}

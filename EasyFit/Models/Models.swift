import Foundation

// MARK: - Nutrition

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var calories: Int
    var protein: Double    // grams
    var carbs: Double      // grams
    var fat: Double        // grams
    var servingSize: String
    var mealType: MealType
    var date: Date

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingSize: String,
        mealType: MealType,
        date: Date = .now
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.mealType = mealType
        self.date = date
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"
}

struct DailyNutritionGoal: Codable {
    var calories: Int  = 2100
    var protein: Double = 160   // grams
    var carbs: Double   = 200   // grams
    var fat: Double     = 65    // grams
}

// MARK: - Workout

struct WorkoutPlan: Identifiable, Codable {
    let id: UUID
    var name: String          // e.g. "Push Day"
    var weekday: Weekday
    var exercises: [Exercise]

    init(id: UUID = UUID(), name: String, weekday: Weekday, exercises: [Exercise]) {
        self.id = id
        self.name = name
        self.weekday = weekday
        self.exercises = exercises
    }
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double?        // nil = bodyweight
    var unit: WeightUnit
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: Int,
        weight: Double? = nil,
        unit: WeightUnit = .lbs,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.isCompleted = isCompleted
    }

    var displayWeight: String {
        if let w = weight {
            return "\(Int(w)) \(unit.rawValue)"
        }
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
}

// MARK: - Progress

struct BodyWeightEntry: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var unit: WeightUnit
    var date: Date

    init(id: UUID = UUID(), weight: Double, unit: WeightUnit = .lbs, date: Date = .now) {
        self.id = id
        self.weight = weight
        self.unit = unit
        self.date = date
    }
}

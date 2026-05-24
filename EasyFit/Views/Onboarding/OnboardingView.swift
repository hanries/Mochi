import SwiftUI

// MARK: - Main Onboarding Container

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0

    // Page 1 — Name
    @State private var name = ""

    // Page 2 — Goal
    @State private var selectedGoal: FitnessGoal = .loseWeight

    // Page 3 — Body stats
    @State private var age:           String        = ""
    @State private var bodyWeight:    String        = ""
    @State private var heightCm:      String        = ""
    @State private var heightUnit:    HeightUnit    = .cm
    @State private var gender:        Gender        = .male
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var weightUnit:    WeightUnit    = .lbs

    // Page 4 — Calculated macros (editable)
    @State private var calories = "2100"
    @State private var protein  = "160"
    @State private var carbs    = "200"
    @State private var fat      = "65"

    let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                NamePage(name: $name).tag(0)
                GoalPage(selectedGoal: $selectedGoal).tag(1)
                StatsPage(
                    age: $age, bodyWeight: $bodyWeight,
                    heightCm: $heightCm, heightUnit: $heightUnit,
                    gender: $gender, activityLevel: $activityLevel,
                    weightUnit: $weightUnit
                ).tag(2)
                MacroResultPage(
                    goal: selectedGoal,
                    calories: $calories, protein: $protein,
                    carbs: $carbs, fat: $fat
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            .onChange(of: currentPage) { _, _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            // Bottom controls — always visible below scroll content
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                Button(action: advance) {
                    Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canAdvance ? Color.primary : Color.secondary.opacity(0.3))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canAdvance)
                .padding(.horizontal, 24)

                if currentPage < totalPages - 1 {
                    Button("Skip for now") {
                        if currentPage == 2 { applyCalculatedMacros() }
                        withAnimation { currentPage += 1 }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                } else {
                    // Placeholder to keep height consistent on last page
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 36)
            .background(Color(uiColor: .systemBackground))
        }
        .ignoresSafeArea(edges: .top)
    }

    private var canAdvance: Bool {
        switch currentPage {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2:
            let heightOk = heightUnit.toCm(heightCm) != nil
            return Int(age) != nil && Double(bodyWeight) != nil && heightOk
        case 3:
            return Int(calories) != nil && Double(protein) != nil
                && Double(carbs) != nil && Double(fat) != nil
        default: return true
        }
    }

    private func advance() {
        if currentPage == 2 { applyCalculatedMacros() }
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            saveAndFinish()
        }
    }

    private func applyCalculatedMacros() {
        guard let ageVal    = Int(age),
              let weightVal = Double(bodyWeight),
              let heightVal = heightUnit.toCm(heightCm)
        else { return }

        let weightKg = weightUnit == .lbs ? weightVal * 0.453592 : weightVal
        let macros   = MacroCalculator.calculate(
            age: ageVal, weightKg: weightKg, heightCm: heightVal,
            gender: gender, activityLevel: activityLevel, goal: selectedGoal
        )
        calories = "\(macros.calories)"
        protein  = "\(Int(macros.protein))"
        carbs    = "\(Int(macros.carbs))"
        fat      = "\(Int(macros.fat))"
    }

    private func saveAndFinish() {
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespaces), forKey: "userName")
        UserDefaults.standard.set(weightUnit.rawValue, forKey: "preferredWeightUnit")
        UserDefaults.standard.set(gender.rawValue, forKey: "userGender")
        if let a = Int(age) { UserDefaults.standard.set(a, forKey: "userAge") }

        var goal = DailyNutritionGoal()
        goal.calories = Int(calories)   ?? 2100
        goal.protein  = Double(protein) ?? 160
        goal.carbs    = Double(carbs)   ?? 200
        goal.fat      = Double(fat)     ?? 65
        DailyNutritionGoal.current = goal

        hasCompletedOnboarding = true
    }
}

// MARK: - Macro Calculator (Mifflin-St Jeor)

enum MacroCalculator {
    static func calculate(
        age: Int, weightKg: Double, heightCm: Double,
        gender: Gender, activityLevel: ActivityLevel, goal: FitnessGoal
    ) -> DailyNutritionGoal {
        let bmr: Double
        switch gender {
        case .male:
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        case .female:
            bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        case .other:
            let male   = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
            let female = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
            bmr = (male + female) / 2
        }

        let tdee = bmr * activityLevel.multiplier
        let targetCalories: Double
        switch goal {
        case .loseWeight:    targetCalories = tdee - 500
        case .buildMuscle:   targetCalories = tdee + 300
        case .maintain:      targetCalories = tdee
        case .improveHealth: targetCalories = tdee - 100
        }

        let kcal     = max(1200, targetCalories)
        let proteinG = weightKg * 2.0
        let fatG     = (kcal * 0.25) / 9
        let carbsG   = (kcal - (proteinG * 4) - (fatG * 9)) / 4

        return DailyNutritionGoal(
            calories: Int(kcal.rounded()),
            protein:  (proteinG * 10).rounded() / 10,
            carbs:    max(0, (carbsG * 10).rounded() / 10),
            fat:      (fatG * 10).rounded() / 10
        )
    }
}

// MARK: - Enums

enum Gender: String, CaseIterable {
    case male = "Male", female = "Female", other = "Other"
}

enum ActivityLevel: String, CaseIterable {
    case sedentary        = "Sedentary"
    case lightlyActive    = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive       = "Very Active"
    case extraActive      = "Extra Active"

    var multiplier: Double {
        switch self {
        case .sedentary:        return 1.2
        case .lightlyActive:    return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive:       return 1.725
        case .extraActive:      return 1.9
        }
    }
    var description: String {
        switch self {
        case .sedentary:        return "Little or no exercise"
        case .lightlyActive:    return "Light exercise 1–3 days/week"
        case .moderatelyActive: return "Moderate exercise 3–5 days/week"
        case .veryActive:       return "Hard exercise 6–7 days/week"
        case .extraActive:      return "Very hard exercise or physical job"
        }
    }
    var emoji: String {
        switch self {
        case .sedentary:        return "🛋️"
        case .lightlyActive:    return "🚶"
        case .moderatelyActive: return "🏃"
        case .veryActive:       return "⚡"
        case .extraActive:      return "🔥"
        }
    }
}

enum FitnessGoal: String, CaseIterable {
    case loseWeight    = "Lose Weight"
    case buildMuscle   = "Build Muscle"
    case maintain      = "Maintain"
    case improveHealth = "Improve Health"

    var emoji: String {
        switch self {
        case .loseWeight:    return "🔥"
        case .buildMuscle:   return "💪"
        case .maintain:      return "⚖️"
        case .improveHealth: return "❤️"
        }
    }
    var description: String {
        switch self {
        case .loseWeight:    return "Burn fat with a calorie deficit"
        case .buildMuscle:   return "Gain strength with a calorie surplus"
        case .maintain:      return "Keep your current weight"
        case .improveHealth: return "Focus on balanced nutrition"
        }
    }
}

enum HeightUnit: String, CaseIterable {
    case cm   = "cm"
    case ftIn = "ft / in"

    func toCm(_ raw: String) -> Double? {
        switch self {
        case .cm:
            return Double(raw)
        case .ftIn:
            // stored internally as "feet:inches"
            let parts = raw.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return (parts[0] * 12 + parts[1]) * 2.54
        }
    }
}

// MARK: - Page 1: Name

private struct NamePage: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("👋").font(.system(size: 64))
                VStack(spacing: 8) {
                    Text("Welcome to EasyFit")
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("Let's personalize your experience.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                TextField("Your first name", text: $name)
                    .font(.system(size: 17))
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)
                    .focused($focused)
            }
            Spacer()
            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: - Page 2: Goal

private struct GoalPage: View {
    @Binding var selectedGoal: FitnessGoal

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("What's your goal?")
                        .font(.system(size: 30, weight: .bold))
                    Text("This shapes your calorie and macro targets.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                VStack(spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        GoalCard(goal: goal, isSelected: selectedGoal == goal) {
                            selectedGoal = goal
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }
}

private struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(goal.emoji)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(goal.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .primary : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2))
            )
        }
    }
}

// MARK: - Page 3: Body Stats

private struct StatsPage: View {
    @Binding var age:           String
    @Binding var bodyWeight:    String
    @Binding var heightCm:      String
    @Binding var heightUnit:    HeightUnit
    @Binding var gender:        Gender
    @Binding var activityLevel: ActivityLevel
    @Binding var weightUnit:    WeightUnit

    var weightPlaceholder: String { weightUnit == .lbs ? "e.g. 175" : "e.g. 80" }
    var weightLabel: String       { weightUnit == .lbs ? "lb" : "kg" }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 60)

                VStack(spacing: 8) {
                    Text("About you")
                        .font(.system(size: 30, weight: .bold))
                    Text("We use this to calculate your personal calorie and macro targets.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Gender
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Gender")
                    HStack(spacing: 10) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            SelectChip(label: g.rawValue, isSelected: gender == g) { gender = g }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Measurements
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Measurements")
                    VStack(spacing: 10) {
                        StatInputRow(label: "Age", unit: "yrs", placeholder: "e.g. 22", value: $age)

                        // Weight + unit toggle
                        HStack(spacing: 10) {
                            StatInputRow(label: "Weight", unit: weightLabel, placeholder: weightPlaceholder, value: $bodyWeight)
                            HStack(spacing: 0) {
                                ForEach([WeightUnit.lbs, WeightUnit.kg], id: \.self) { u in
                                    Button {
                                        weightUnit = u
                                        bodyWeight = ""
                                    } label: {
                                        Text(u.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(weightUnit == u ? Color.primary : Color.clear)
                                            .foregroundStyle(weightUnit == u ? Color(uiColor: .systemBackground) : .secondary)
                                    }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(width: 90)
                        }

                        HeightInputSection(heightCm: $heightCm, heightUnit: $heightUnit)
                    }
                }
                .padding(.horizontal, 24)

                // Activity level
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Activity Level")
                    VStack(spacing: 8) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            ActivityCard(level: level, isSelected: activityLevel == level) {
                                activityLevel = level
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Page 4: Macro Result

private struct MacroResultPage: View {
    let goal: FitnessGoal
    @Binding var calories: String
    @Binding var protein:  String
    @Binding var carbs:    String
    @Binding var fat:      String

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 60)

                VStack(spacing: 8) {
                    Text("Your targets 🎯")
                        .font(.system(size: 30, weight: .bold))
                    Text("Calculated based on your stats and goal. Feel free to adjust.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 0) {
                    MacroResultRow(label: "Calories", value: $calories, unit: "kcal", color: .primary,                              keyboardType: .numberPad)
                    Divider().padding(.leading, 16)
                    MacroResultRow(label: "Protein",  value: $protein,  unit: "g",    color: Color(red: 0.3, green: 0.71, blue: 0.67), keyboardType: .decimalPad)
                    Divider().padding(.leading, 16)
                    MacroResultRow(label: "Carbs",    value: $carbs,    unit: "g",    color: Color(red: 1.0, green: 0.72, blue: 0.3),  keyboardType: .decimalPad)
                    Divider().padding(.leading, 16)
                    MacroResultRow(label: "Fat",      value: $fat,      unit: "g",    color: Color(red: 0.9, green: 0.35, blue: 0.35), keyboardType: .decimalPad)
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Text("These targets are based on the Mifflin-St Jeor equation — the gold standard used by dietitians.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Shared subviews

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

private struct SelectChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(isSelected ? Color.primary : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct StatInputRow: View {
    let label: String
    let unit: String
    let placeholder: String
    @Binding var value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 15, weight: .medium))
            Spacer()
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 80)
            Text(unit)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActivityCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(level.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                    Text(level.description).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .primary : Color.secondary.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2))
            )
        }
    }
}

private struct MacroResultRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    let color: Color
    let keyboardType: UIKeyboardType
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 4, height: 20)
                Text(label).font(.system(size: 15, weight: .medium))
            }
            Spacer()
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 70)
                Text(unit).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Height Input Section

private struct HeightInputSection: View {
    @Binding var heightCm:   String
    @Binding var heightUnit: HeightUnit

    @State private var feet:   String = ""
    @State private var inches: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Unit toggle row
            HStack {
                Text("Height").font(.system(size: 15, weight: .medium))
                Spacer()
                HStack(spacing: 0) {
                    ForEach(HeightUnit.allCases, id: \.self) { u in
                        Button {
                            heightUnit = u
                            feet = ""; inches = ""; heightCm = ""
                        } label: {
                            Text(u.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(heightUnit == u ? Color.primary : Color.clear)
                                .foregroundStyle(heightUnit == u ? Color(uiColor: .systemBackground) : .secondary)
                        }
                    }
                }
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if heightUnit == .cm {
                StatInputRow(label: "Height", unit: "cm", placeholder: "e.g. 178", value: $heightCm)
            } else {
                HStack(spacing: 10) {
                    HStack {
                        TextField("0", text: $feet)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44)
                            .onChange(of: feet)   { _, _ in sync() }
                        Text("ft").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack {
                        TextField("0", text: $inches)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44)
                            .onChange(of: inches) { _, _ in sync() }
                        Text("in").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // Store as "feet:inches" so HeightUnit.toCm() can parse it
    private func sync() {
        let f = Double(feet) ?? 0
        let i = Double(inches) ?? 0
        heightCm = (f > 0 || i > 0) ? "\(feet):\(inches)" : ""
    }
}

#Preview { OnboardingView() }

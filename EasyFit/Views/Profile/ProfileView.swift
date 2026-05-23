import SwiftUI

struct ProfileView: View {
    @AppStorage("userName")            private var userName       = ""
    @AppStorage("userAge")             private var userAge        = 0
    @AppStorage("userGender")          private var userGender     = Gender.male.rawValue
    @AppStorage("preferredWeightUnit") private var weightUnitRaw  = WeightUnit.lbs.rawValue

    @State private var goal: DailyNutritionGoal = .current

    // Editable fields
    @State private var editAge:       String = ""
    @State private var editWeight:    String = ""
    @State private var editHeight:    String = ""
    @State private var editGender:    Gender = .male
    @State private var editActivity:  ActivityLevel = .moderatelyActive
    @State private var editUnit:      WeightUnit = .lbs
    @State private var editGoal:      FitnessGoal = .maintain

    @State private var showingEdit    = false
    @State private var calculatedMacros: DailyNutritionGoal? = nil

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Avatar + name
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .frame(width: 80, height: 80)
                            Text(userName.prefix(1).uppercased())
                                .font(.system(size: 32, weight: .bold))
                        }
                        Text(userName.isEmpty ? "Your Profile" : userName)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .padding(.top, 8)

                    // Current macro targets
                    ProfileCard(title: "Daily Targets") {
                        MacroTargetRow(label: "Calories", value: "\(goal.calories) kcal", color: .primary)
                        Divider()
                        MacroTargetRow(label: "Protein",  value: "\(Int(goal.protein))g",  color: Color(red: 0.3, green: 0.71, blue: 0.67))
                        Divider()
                        MacroTargetRow(label: "Carbs",    value: "\(Int(goal.carbs))g",    color: Color(red: 1.0, green: 0.72, blue: 0.3))
                        Divider()
                        MacroTargetRow(label: "Fat",      value: "\(Int(goal.fat))g",      color: Color(red: 0.9, green: 0.35, blue: 0.35))
                    }

                    // Recalculate button
                    Button {
                        prepareEdit()
                        showingEdit = true
                    } label: {
                        Label("Update stats & recalculate", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Reset onboarding (dev helper)
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Text("Reset onboarding")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingEdit) {
                EditStatsView(
                    age:          $editAge,
                    bodyWeight:   $editWeight,
                    height:       $editHeight,
                    gender:       $editGender,
                    activityLevel: $editActivity,
                    weightUnit:   $editUnit,
                    fitnessGoal:  $editGoal
                ) {
                    applyRecalculation()
                }
            }
            .onAppear { goal = .current }
        }
    }

    private func prepareEdit() {
        editAge      = userAge > 0 ? "\(userAge)" : ""
        editGender   = Gender(rawValue: userGender) ?? .male
        editUnit     = WeightUnit(rawValue: weightUnitRaw) ?? .lbs
        editGoal     = .maintain
        editWeight   = ""
        editHeight   = ""
        editActivity = .moderatelyActive
    }

    private func applyRecalculation() {
        guard let ageVal    = Int(editAge),
              let weightVal = Double(editWeight),
              let heightVal = Double(editHeight)
        else { return }

        let weightKg = editUnit == .lbs ? weightVal * 0.453592 : weightVal

        var newGoal = MacroCalculator.calculate(
            age:           ageVal,
            weightKg:      weightKg,
            heightCm:      heightVal,
            gender:        editGender,
            activityLevel: editActivity,
            goal:          editGoal
        )
        DailyNutritionGoal.current = newGoal
        goal = newGoal

        UserDefaults.standard.set(ageVal, forKey: "userAge")
        UserDefaults.standard.set(editGender.rawValue, forKey: "userGender")
        UserDefaults.standard.set(editUnit.rawValue, forKey: "preferredWeightUnit")
    }
}

// MARK: - Edit Stats Sheet

struct EditStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var age:           String
    @Binding var bodyWeight:    String
    @Binding var height:        String
    @Binding var gender:        Gender
    @Binding var activityLevel: ActivityLevel
    @Binding var weightUnit:    WeightUnit
    @Binding var fitnessGoal:   FitnessGoal
    let onSave: () -> Void

    var canSave: Bool { Int(age) != nil && Double(bodyWeight) != nil && Double(height) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("yrs", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Body") {
                    Picker("Unit", selection: $weightUnit) {
                        Text("lb").tag(WeightUnit.lbs)
                        Text("kg").tag(WeightUnit.kg)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField(weightUnit == .lbs ? "lb" : "kg", text: $bodyWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }

                Section("Goal") {
                    Picker("Goal", selection: $fitnessGoal) {
                        ForEach(FitnessGoal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Activity") {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        HStack {
                            Text(level.emoji)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.rawValue).font(.system(size: 14, weight: .medium))
                                Text(level.description).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if activityLevel == level {
                                Image(systemName: "checkmark").foregroundStyle(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { activityLevel = level }
                    }
                }
            }
            .navigationTitle("Update Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Recalculate") {
                        onSave()
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Subviews

private struct ProfileCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            content()
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct MacroTargetRow: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 18)
                Text(label).font(.system(size: 15))
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview { ProfileView() }

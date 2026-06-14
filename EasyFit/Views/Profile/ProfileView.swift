import SwiftUI

struct ProfileView: View {
    @AppStorage("userName")            private var userName      = ""
    @AppStorage("userAge")             private var userAge       = 0
    @AppStorage("userGender")          private var userGender    = Gender.male.rawValue
    @AppStorage("preferredWeightUnit") private var weightUnitRaw = WeightUnit.lbs.rawValue

    @State private var goal: DailyNutritionGoal = .current

    @State private var editAge:      String        = ""
    @State private var editWeight:   String        = ""
    @State private var editHeight:   String        = ""
    @State private var editGender:   Gender        = .male
    @State private var editActivity: ActivityLevel = .moderatelyActive
    @State private var editUnit:     WeightUnit    = .lbs
    @State private var editGoal:     FitnessGoal   = .maintain

    @State private var showingEdit = false

    @StateObject private var notifications = MochiNotificationService.shared
    @EnvironmentObject private var paywall: PaywallCoordinator
    @EnvironmentObject private var mochi:   MochiViewModel
    @ObservedObject private var premium = PremiumStore.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Mochi header (his live, consistency-driven expression)
                Section {
                    VStack(spacing: 12) {
                        MochiView(state: mochi.state, size: 120)
                        VStack(spacing: 6) {
                            Text(userName.isEmpty ? "Set your name" : userName)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(MochiTheme.textPrimary)
                            Text(editGoal.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MochiTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(MochiTheme.surfaceAlt)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MochiTheme.Spacing.sm)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // MARK: - Daily targets
                Section("Daily Targets") {
                    LabeledContent("Calories") { valueText("\(goal.calories) kcal") }
                    LabeledContent("Protein")  { valueText("\(Int(goal.protein)) g") }
                    LabeledContent("Carbs")    { valueText("\(Int(goal.carbs)) g") }
                    LabeledContent("Fat")      { valueText("\(Int(goal.fat)) g") }
                }
                .listRowBackground(MochiTheme.surfaceAlt)

                Section {
                    Button {
                        prepareEdit()
                        showingEdit = true
                    } label: {
                        Label("Update Stats & Recalculate", systemImage: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(MochiTheme.primary)
                    }
                }
                .listRowBackground(MochiTheme.surfaceAlt)

                // MARK: - Profile details
                Section("Profile") {
                    LabeledContent("Gender")      { valueText(userGender.capitalized) }
                    LabeledContent("Age")         { valueText(userAge > 0 ? "\(userAge)" : "—") }
                    LabeledContent("Weight Unit") { valueText(weightUnitRaw.uppercased()) }
                    LabeledContent("Activity Level") { valueText(editActivity.rawValue) }
                    LabeledContent("Fitness Goal")   { valueText(editGoal.rawValue) }
                }
                .listRowBackground(MochiTheme.surfaceAlt)

                // MARK: - Premium
                Section("Premium") {
                    Button {
                        if !premium.isPremium { paywall.presentPaywall(.profile) }
                    } label: {
                        LabeledContent {
                            Text(premium.isPremium ? "Active ✓" : "Unlimited scans")
                                .foregroundStyle(premium.isPremium ? MochiTheme.success : MochiTheme.textSecondary)
                        } label: {
                            Label("Mochi Premium", systemImage: "sparkles")
                                .foregroundStyle(MochiTheme.textPrimary)
                        }
                    }
                }
                .listRowBackground(MochiTheme.surfaceAlt)

                // MARK: - Notifications
                Section("Notifications") {
                    Button {
                        Task {
                            if notifications.isDenied {
                                // Permission lives in system Settings once denied
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    await UIApplication.shared.open(url)
                                }
                            } else if !notifications.isAuthorized {
                                if await notifications.requestPermission() {
                                    notifications.reschedule(loggedToday: false)
                                }
                            }
                        }
                    } label: {
                        LabeledContent {
                            Text(notifications.isAuthorized ? "Once a day"
                                 : notifications.isDenied ? "Enable in Settings" : "Off")
                                .foregroundStyle(MochiTheme.textSecondary)
                        } label: {
                            Label("Mochi Check-ins", systemImage: "bell.fill")
                                .foregroundStyle(MochiTheme.textPrimary)
                        }
                    }
                }
                .listRowBackground(MochiTheme.surfaceAlt)

                #if DEBUG
                // Debug-only: simulate premium for testing the gates
                Section("Debug") {
                    Toggle(isOn: Binding(
                        get: { PremiumStore.shared.debugSimulatePremium },
                        set: { PremiumStore.shared.debugSimulatePremium = $0 }
                    )) {
                        Label("Simulate Premium", systemImage: "hammer.fill")
                            .foregroundStyle(MochiTheme.textPrimary)
                    }
                    .tint(MochiTheme.primary)
                }
                .listRowBackground(MochiTheme.surfaceAlt)
                #endif

                // MARK: - Account
                Section("Account") {
                    Button(role: .destructive) {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                }
                .listRowBackground(MochiTheme.surfaceAlt)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MochiTheme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEdit) {
                EditStatsView(
                    age:           $editAge,
                    bodyWeight:    $editWeight,
                    height:        $editHeight,
                    gender:        $editGender,
                    activityLevel: $editActivity,
                    weightUnit:    $editUnit,
                    fitnessGoal:   $editGoal
                ) {
                    applyRecalculation()
                }
            }
            .onAppear {
                goal         = .current
                editGoal     = .maintain
                editActivity = .moderatelyActive
                editUnit     = WeightUnit(rawValue: weightUnitRaw) ?? .lbs
                editGender   = Gender(rawValue: userGender) ?? .male
            }
            .task { await notifications.refreshAuthorizationStatus() }
        }
    }

    private func valueText(_ s: String) -> some View {
        Text(s).foregroundStyle(MochiTheme.textSecondary)
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
        let newGoal  = MacroCalculator.calculate(
            age:           ageVal,
            weightKg:      weightKg,
            heightCm:      heightVal,
            gender:        editGender,
            activityLevel: editActivity,
            goal:          editGoal
        )
        DailyNutritionGoal.current = newGoal
        goal = newGoal
        UserDefaults.standard.set(ageVal,              forKey: "userAge")
        UserDefaults.standard.set(editGender.rawValue, forKey: "userGender")
        UserDefaults.standard.set(editUnit.rawValue,   forKey: "preferredWeightUnit")
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
                        Text("Age"); Spacer()
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
                        Text("Weight"); Spacer()
                        TextField(weightUnit == .lbs ? "lb" : "kg", text: $bodyWeight)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Height"); Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("cm").foregroundStyle(MochiTheme.textSecondary)
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
                                Text(level.description).font(.system(size: 12)).foregroundStyle(MochiTheme.textSecondary)
                            }
                            Spacer()
                            if activityLevel == level {
                                Image(systemName: "checkmark").foregroundStyle(MochiTheme.primary)
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
                    Button("Recalculate") { onSave(); dismiss() }
                        .disabled(!canSave).fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(MochiViewModel())
        .environmentObject(PaywallCoordinator())
}

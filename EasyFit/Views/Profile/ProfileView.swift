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
    @ObservedObject private var premium = PremiumStore.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var initials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return userName.prefix(2).uppercased().isEmpty ? "?" : userName.prefix(2).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Header
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [MochiTheme.surface, MochiTheme.background],
                            startPoint: .top,
                            endPoint:   .bottom
                        )
                        .ignoresSafeArea(edges: .top)

                        VStack(spacing: 14) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [MochiTheme.warning, MochiTheme.primary],
                                            startPoint: .topLeading,
                                            endPoint:   .bottomTrailing
                                        )
                                    )
                                    .frame(width: 88, height: 88)
                                    .shadow(color: MochiTheme.primary.opacity(0.35), radius: 16, x: 0, y: 8)
                                Text(initials)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(MochiTheme.surfaceAlt)
                            }

                            // Name + goal badge
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

                            // Quick stat chips
                            HStack(spacing: 10) {
                                StatChip(value: userGender.capitalized,                      label: "Gender")
                                StatChip(value: userAge > 0 ? "\(userAge)" : "—",            label: "Age")
                                StatChip(value: weightUnitRaw.uppercased(),                   label: "Unit")
                            }
                            .padding(.bottom, 24)
                        }
                        .padding(.top, 20)
                    }
                    .frame(minHeight: 300)

                    // MARK: - Body
                    VStack(spacing: 20) {

                        // Daily targets
                        VStack(alignment: .leading, spacing: 16) {
                            SectionLabel("Daily Targets")

                            // Calorie hero row
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(MochiTheme.primary.opacity(0.15), lineWidth: 6)
                                    Circle()
                                        .trim(from: 0, to: 1)
                                        .stroke(
                                            LinearGradient(
                                                colors: [MochiTheme.primary, MochiTheme.warning],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 0) {
                                        Text("\(goal.calories)")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundStyle(MochiTheme.textPrimary)
                                        Text("kcal")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(MochiTheme.textSecondary)
                                    }
                                }
                                .frame(width: 68, height: 68)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calorie Goal")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(MochiTheme.textSecondary)
                                    Text("\(goal.calories) kcal / day")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(MochiTheme.textPrimary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            // Macro trio
                            HStack(spacing: 10) {
                                MacroBlock(label: "Protein", value: Int(goal.protein),
                                           color: MochiTheme.success, icon: "p.circle.fill")
                                MacroBlock(label: "Carbs",   value: Int(goal.carbs),
                                           color: MochiTheme.warning, icon: "c.circle.fill")
                                MacroBlock(label: "Fat",     value: Int(goal.fat),
                                           color: MochiTheme.accent,  icon: "f.circle.fill")
                            }
                        }
                        .padding(.horizontal)

                        // Update button
                        Button {
                            prepareEdit()
                            showingEdit = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Update Stats & Recalculate")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(MochiTheme.primary)
                            .foregroundStyle(MochiTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
                        }
                        .padding(.horizontal)

                        // Settings rows
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Settings")
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                SettingsRow(icon: "figure.walk",   iconColor: MochiTheme.success,  label: "Activity Level") {
                                    Text(editActivity.rawValue).font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                                }
                                Divider().padding(.leading, 52)
                                SettingsRow(icon: "target",        iconColor: MochiTheme.primary, label: "Fitness Goal") {
                                    Text(editGoal.rawValue).font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                                }
                                Divider().padding(.leading, 52)
                                SettingsRow(icon: "scalemass.fill", iconColor: MochiTheme.accent,  label: "Weight Unit") {
                                    Text(weightUnitRaw.uppercased()).font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                                }
                                Divider().padding(.leading, 52)
                                Button {
                                    if !premium.isPremium {
                                        paywall.presentPaywall(.profile)
                                    }
                                } label: {
                                    SettingsRow(icon: "sparkles", iconColor: MochiTheme.primary, label: "EasyFit Premium") {
                                        Text(premium.isPremium ? "Active ✓" : "Unlimited scans")
                                            .font(.system(size: 13))
                                            .foregroundStyle(premium.isPremium ? MochiTheme.success : MochiTheme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 52)
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
                                    SettingsRow(icon: "bell.fill", iconColor: MochiTheme.warning, label: "Mochi Check-ins") {
                                        Text(notifications.isAuthorized ? "Once a day"
                                             : notifications.isDenied ? "Enable in Settings" : "Off")
                                            .font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }

                        #if DEBUG
                        // Debug-only: simulate premium for testing the gates
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Debug")
                                .padding(.horizontal)

                            Toggle(isOn: Binding(
                                get: { PremiumStore.shared.debugSimulatePremium },
                                set: { PremiumStore.shared.debugSimulatePremium = $0 }
                            )) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(MochiTheme.textSecondary)
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "hammer.fill")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(MochiTheme.surfaceAlt)
                                    }
                                    Text("Simulate Premium").font(.system(size: 15))
                                }
                            }
                            .tint(MochiTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                        #endif

                        // Account
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Account")
                                .padding(.horizontal)

                            Button {
                                hasCompletedOnboarding = false
                            } label: {
                                SettingsRow(icon: "arrow.counterclockwise", iconColor: MochiTheme.danger, label: "Reset Onboarding") {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(MochiTheme.textSecondary.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
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

// MARK: - Subviews

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MochiTheme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

private struct StatChip: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(MochiTheme.textPrimary)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(MochiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MacroBlock: View {
    let label: String
    let value: Int
    let color: Color
    let icon:  String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)g").font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label).font(.system(size: 11)).foregroundStyle(MochiTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon:      String
    let iconColor: Color
    let label:     String
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(iconColor).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
            }
            Text(label).font(.system(size: 15))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview { ProfileView() }

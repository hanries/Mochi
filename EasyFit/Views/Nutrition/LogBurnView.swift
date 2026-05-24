import SwiftUI

struct LogBurnView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var healthKit: HealthKitService

    @State private var kcalText     = ""
    @State private var activityName = ""
    @State private var isSaving     = false
    @State private var errorMsg:  String? = nil
    @State private var showSuccess  = false

    let onManualLog: (Int) -> Void   // fallback when HealthKit not authorized

    private let quickActivities: [(name: String, met: Double, emoji: String)] = [
        ("Running",       9.8,  "🏃"),
        ("Cycling",       7.5,  "🚴"),
        ("Swimming",      8.0,  "🏊"),
        ("Weight lifting",5.0,  "🏋️"),
        ("Walking",       3.5,  "🚶"),
        ("HIIT",          10.0, "⚡"),
        ("Yoga",          2.5,  "🧘"),
        ("Basketball",    8.0,  "🏀"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // HealthKit status banner
                    if healthKit.isAvailable {
                        HealthKitBanner(
                            isAuthorized: healthKit.isAuthorized,
                            activeCalories: healthKit.activeCalories,
                            restingCalories: healthKit.restingCalories
                        ) {
                            Task { await healthKit.requestAuthorization() }
                        }
                    }

                    // Manual entry
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Log Manually")

                        VStack(spacing: 10) {
                            HStack {
                                TextField("Activity (optional)", text: $activityName)
                                    .font(.system(size: 15))
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            HStack {
                                Text("Calories burned")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                TextField("0", text: $kcalText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 70)
                                Text("kcal")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let err = errorMsg {
                            Text(err).font(.system(size: 13)).foregroundStyle(.red)
                        }

                        Button {
                            save()
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(Color(uiColor: .systemBackground))
                                } else {
                                    Text(healthKit.isAuthorized ? "Save to Health & Log" : "Log Calories")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Int(kcalText) ?? 0 > 0 ? Color.primary : Color.secondary.opacity(0.3))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled((Int(kcalText) ?? 0) <= 0 || isSaving)
                    }
                    .padding(.horizontal)

                    // Quick pick activities
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Quick Pick")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(quickActivities, id: \.name) { activity in
                                ActivityQuickCard(activity: activity) { kcal in
                                    kcalText = "\(kcal)"
                                    activityName = activity.name
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Burned Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .alert("Saved!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Calories logged successfully.")
            }
        }
    }

    private func save() {
        guard let kcal = Int(kcalText), kcal > 0 else { return }
        isSaving  = true
        errorMsg  = nil

        Task {
            if healthKit.isAuthorized {
                do {
                    try await healthKit.logBurnedCalories(Double(kcal))
                } catch {
                    await MainActor.run { errorMsg = "Couldn't save to Apple Health." }
                }
            }
            // Always log locally regardless
            await MainActor.run {
                onManualLog(kcal)
                isSaving    = false
                showSuccess = true
            }
        }
    }
}

// MARK: - HealthKit banner

private struct HealthKitBanner: View {
    let isAuthorized:    Bool
    let activeCalories:  Int
    let restingCalories: Int
    let onConnect:       () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isAuthorized {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health Connected")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Active: \(activeCalories) kcal  •  Resting: \(restingCalories) kcal today")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            } else {
                Button(action: onConnect) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Apple Health")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Auto-sync burned calories from your Apple Watch or iPhone")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Quick activity card

private struct ActivityQuickCard: View {
    let activity: (name: String, met: Double, emoji: String)
    let onSelect: (Int) -> Void

    // Estimate for 70kg person, 30 minutes: kcal = MET × weight(kg) × time(hr)
    var estimatedKcal: Int { Int(activity.met * 70 * 0.5) }

    var body: some View {
        Button {
            onSelect(estimatedKcal)
        } label: {
            HStack(spacing: 10) {
                Text(activity.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("~\(estimatedKcal) kcal / 30 min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct SectionHeader: View {
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

#Preview {
    LogBurnView(healthKit: HealthKitService.shared) { _ in }
}

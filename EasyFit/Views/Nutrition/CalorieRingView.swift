import SwiftUI

struct CalorieRingView: View {
    let consumed:  Int
    let goal:      Int
    let burned:    Int
    let onLogBurn: () -> Void

    // Remaining is purely goal - consumed
    // burned is informational only — already factored into goal via activity multiplier
    var remaining: Int    { max(goal - consumed, 0) }
    var progress:  Double { min(Double(consumed) / Double(max(goal, 1)), 1.0) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1.0 ? Color.red : Color.primary,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: progress)

                    VStack(spacing: 2) {
                        Text("\(consumed)")
                            .font(.system(size: 22, weight: .semibold))
                        Text("of \(goal) kcal")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Consumed",  value: "\(consumed) kcal", color: .primary)
                    StatRow(label: "Remaining", value: "\(remaining) kcal", color: remaining == 0 ? .red : .primary)

                    // Burned — informational only
                    Button(action: onLogBurn) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Burned")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text(burned > 0 ? "\(burned) kcal" : "Log activity")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(burned > 0 ? .orange : .secondary)
                                Image(systemName: "flame")
                                    .font(.system(size: 12))
                                    .foregroundStyle(burned > 0 ? .orange : .secondary)
                            }
                        }
                    }
                }
            }

            // Info note
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Activity burn is already factored into your calorie goal.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .medium)).foregroundStyle(color)
        }
    }
}

#Preview {
    CalorieRingView(consumed: 1420, goal: 2100, burned: 340) {}
}

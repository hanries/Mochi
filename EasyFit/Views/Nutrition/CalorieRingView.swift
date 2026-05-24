import SwiftUI

struct CalorieRingView: View {
    let consumed:  Int
    let goal:      Int
    let burned:    Int
    let onLogBurn: () -> Void

    // Net = consumed - burned (what actually matters for the goal)
    var net: Int      { max(consumed - burned, 0) }
    var remaining: Int { max(goal - consumed + burned, 0) }
    var progress: Double { min(Double(consumed) / Double(max(goal + burned, 1)), 1.0) }

    var body: some View {
        HStack(spacing: 28) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 12)
                // Burned arc (red, underneath)
                if burned > 0 {
                    Circle()
                        .trim(from: 0, to: min(Double(burned) / Double(max(goal, 1)), 1.0))
                        .stroke(Color.red.opacity(0.25), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                // Consumed arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
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
                StatRow(label: "Remaining", value: "\(remaining) kcal", color: .primary)

                // Burned row — tappable to log manually
                Button(action: onLogBurn) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Burned")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(burned > 0 ? "−\(burned) kcal" : "Log burn")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(burned > 0 ? .red : .secondary)
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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

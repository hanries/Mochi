import SwiftUI

struct CalorieRingView: View {
    let consumed: Int
    let goal: Int
    let burned: Int

    var progress: Double { min(Double(consumed) / Double(goal), 1.0) }

    var body: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
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

            VStack(alignment: .leading, spacing: 14) {
                StatRow(label: "Consumed",  value: "\(consumed) kcal", color: .primary)
                StatRow(label: "Remaining", value: "\(max(goal - consumed, 0)) kcal", color: .primary)
                StatRow(label: "Burned",    value: "−\(burned) kcal",  color: .red)
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
    CalorieRingView(consumed: 1420, goal: 2100, burned: 340)
}

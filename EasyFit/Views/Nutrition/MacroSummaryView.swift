import SwiftUI

struct MacroSummaryView: View {
    let protein: Double;     let proteinGoal: Double
    let carbs: Double;       let carbsGoal: Double
    let fat: Double;         let fatGoal: Double

    var body: some View {
        HStack(spacing: 10) {
            MacroCard(label: "Protein", value: protein, goal: proteinGoal, color: Color(red: 0.3, green: 0.71, blue: 0.67))
            MacroCard(label: "Carbs",   value: carbs,   goal: carbsGoal,   color: Color(red: 1.0,  green: 0.72, blue: 0.3))
            MacroCard(label: "Fat",     value: fat,     goal: fatGoal,     color: Color(red: 0.9,  green: 0.35, blue: 0.35))
        }
        .padding(.horizontal)
    }
}

private struct MacroCard: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color

    var progress: Double { min(value / goal, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("\(Int(value))g")
                .font(.system(size: 18, weight: .semibold))
            Text("/ \(Int(goal))g")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    MacroSummaryView(protein: 112, proteinGoal: 160, carbs: 148, carbsGoal: 200, fat: 38, fatGoal: 65)
}

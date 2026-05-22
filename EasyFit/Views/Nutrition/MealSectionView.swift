import SwiftUI

struct MealSectionView: View {
    let meal: MealType
    let entries: [FoodEntry]
    let totalCalories: Int
    let onAdd: () -> Void
    let onDelete: (FoodEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(meal.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(totalCalories > 0 ? "\(totalCalories) kcal" : "—")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    FoodRow(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { onDelete(entry) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    Divider().padding(.leading, 56)
                }

                Button(action: onAdd) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                        Text("Add food")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

private struct FoodRow: View {
    let entry: FoodEntry

    var emoji: String {
        switch entry.mealType {
        case .breakfast: return "🥚"
        case .lunch:     return "🍗"
        case .dinner:    return "🥗"
        case .snack:     return "🍎"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.system(size: 14))
                Text(entry.servingSize).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.calories)")
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

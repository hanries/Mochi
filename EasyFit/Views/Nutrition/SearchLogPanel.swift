import SwiftUI
import SwiftData

// MARK: - "More ways to log" panel
//
// Presented from the Home tab. Routes to database search or manual entry;
// both insert the entry and fire Mochi's meal-logged moment.

struct SearchLogPanel: View {
    let activeMeal: MealType
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject           private var mochi: MochiViewModel
    @State private var showSearch = false
    @State private var showManual = false

    var body: some View {
        NavigationStack {
            ZStack {
                MochiTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: MochiTheme.Spacing.sm) {
                        Text("Add food")
                            .font(MochiTheme.largeTitle)
                            .foregroundStyle(MochiTheme.textPrimary)
                        Text("Logging to \(activeMeal.rawValue.lowercased())")
                            .font(MochiTheme.caption)
                            .foregroundStyle(MochiTheme.textSecondary)
                    }
                    .padding(.horizontal, MochiTheme.Spacing.xl)
                    .padding(.top, MochiTheme.Spacing.xxl)
                    .padding(.bottom, MochiTheme.Spacing.xl)

                    VStack(spacing: MochiTheme.Spacing.md) {
                        SearchPanelRow(icon: "magnifyingglass", label: "Search food database",
                                       sublabel: "Millions of foods",
                                       color: MochiTheme.primary) { showSearch = true }
                        SearchPanelRow(icon: "square.and.pencil", label: "Enter manually",
                                       sublabel: "Quick custom entry",
                                       color: MochiTheme.success) { showManual = true }
                        SearchPanelRow(icon: "book.closed.fill", label: "Create a recipe",
                                       sublabel: "Build & save your own meal",
                                       color: MochiTheme.accent) { showManual = true }
                    }
                    .padding(.horizontal, MochiTheme.Spacing.xl)
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSearch) {
            FoodSearchView(mealType: activeMeal) { entry in
                context.insert(entry)
                mochi.mealLogged()
                dismiss()
            }
        }
        .sheet(isPresented: $showManual) {
            AddFoodView(mealType: activeMeal) { entry in
                context.insert(entry)
                mochi.mealLogged()
                dismiss()
            }
        }
    }
}

private struct SearchPanelRow: View {
    let icon: String; let label: String; let sublabel: String
    let color: Color; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MochiTheme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(MochiTheme.textPrimary)
                    Text(sublabel)
                        .font(MochiTheme.caption)
                        .foregroundStyle(MochiTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(MochiTheme.textSecondary)
            }
            .padding(MochiTheme.Spacing.lg)
            .background(MochiTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
        }
    }
}

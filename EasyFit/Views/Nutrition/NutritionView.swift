import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @AppStorage("userName") private var userName = ""
    @StateObject private var vm         = NutritionViewModel()
    @StateObject private var healthKit  = HealthKitService.shared
    @State private var showCamera       = false
    @State private var showSearch       = false
    @State private var showManual       = false
    @State private var showLogBurn      = false
    @State private var manualBurned     = 0
    @State private var activeMeal: MealType = .breakfast

    var totalBurned: Int {
        healthKit.isAuthorized ? healthKit.totalBurnedToday : manualBurned
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CalorieRingView(
                        consumed: vm.totalCalories(from: allEntries),
                        goal:     vm.goal.calories,
                        burned:   totalBurned
                    ) {
                        showLogBurn = true
                    }

                    MacroSummaryView(
                        protein:     vm.totalProtein(from: allEntries), proteinGoal: vm.goal.protein,
                        carbs:       vm.totalCarbs(from: allEntries),   carbsGoal:   vm.goal.carbs,
                        fat:         vm.totalFat(from: allEntries),     fatGoal:     vm.goal.fat
                    )

                    HStack(spacing: 10) {
                        ActionButton(icon: "camera.fill",       label: "Scan")   { showCamera = true }
                        ActionButton(icon: "magnifyingglass",   label: "Search") { activeMeal = .breakfast; showSearch = true }
                        ActionButton(icon: "square.and.pencil", label: "Manual") { activeMeal = .breakfast; showManual = true }
                    }
                    .padding(.horizontal)

                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSectionView(
                            meal:          meal,
                            entries:       vm.entries(for: meal, from: allEntries),
                            totalCalories: vm.mealCalories(for: meal, from: allEntries)
                        ) {
                            activeMeal = meal; showSearch = true
                        } onDelete: { entry in
                            context.delete(entry)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(userName.isEmpty ? "Nutrition" : "Hi, \(userName) 👋")
            .navigationBarTitleDisplayMode(.large)
            .task { await healthKit.fetchTodayCalories() }
            .sheet(isPresented: $showCamera) {
                FoodCameraView { result in
                    context.insert(FoodEntry(
                        name: result.name, calories: result.calories,
                        protein: result.protein, carbs: result.carbs, fat: result.fat,
                        servingSize: result.servingSize, mealType: activeMeal
                    ))
                }
            }
            .sheet(isPresented: $showSearch) {
                FoodSearchView(mealType: activeMeal) { entry in context.insert(entry) }
            }
            .sheet(isPresented: $showManual) {
                AddFoodView(mealType: activeMeal) { entry in context.insert(entry) }
            }
            .sheet(isPresented: $showLogBurn) {
                LogBurnView(healthKit: healthKit) { kcal in
                    manualBurned += kcal
                }
            }
        }
    }
}

private struct ActionButton: View {
    let icon: String; let label: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    NutritionView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}

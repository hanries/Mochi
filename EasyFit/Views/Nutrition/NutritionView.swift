import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @AppStorage("userName") private var userName = ""
    @StateObject private var vm       = NutritionViewModel()
    @State private var showCamera     = false
    @State private var showAddFood    = false
    @State private var activeMeal: MealType = .breakfast

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CalorieRingView(
                        consumed: vm.totalCalories(from: allEntries),
                        goal:     vm.goal.calories,
                        burned:   0
                    )

                    MacroSummaryView(
                        protein:     vm.totalProtein(from: allEntries), proteinGoal: vm.goal.protein,
                        carbs:       vm.totalCarbs(from: allEntries),   carbsGoal:   vm.goal.carbs,
                        fat:         vm.totalFat(from: allEntries),     fatGoal:     vm.goal.fat
                    )

                    Button { showCamera = true } label: {
                        Label("Scan food with camera", systemImage: "camera.fill")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSectionView(
                            meal:          meal,
                            entries:       vm.entries(for: meal, from: allEntries),
                            totalCalories: vm.mealCalories(for: meal, from: allEntries)
                        ) {
                            activeMeal = meal
                            showAddFood = true
                        } onDelete: { entry in
                            context.delete(entry)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(userName.isEmpty ? "Nutrition" : "Hi, \(userName) 👋")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCamera) {
                FoodCameraView { result in
                    let entry = FoodEntry(
                        name:        result.name,
                        calories:    result.calories,
                        protein:     result.protein,
                        carbs:       result.carbs,
                        fat:         result.fat,
                        servingSize: result.servingSize,
                        mealType:    activeMeal
                    )
                    context.insert(entry)
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(mealType: activeMeal) { entry in
                    context.insert(entry)
                }
            }
        }
    }
}

#Preview {
    NutritionView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}

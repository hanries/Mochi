import SwiftUI

struct NutritionView: View {
    @StateObject private var vm = NutritionViewModel.preview()
    @State private var showCamera    = false
    @State private var showAddFood   = false
    @State private var activeMeal: MealType = .breakfast

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CalorieRingView(
                        consumed: vm.totalCalories,
                        goal: vm.goal.calories,
                        burned: 340
                    )

                    MacroSummaryView(
                        protein: vm.totalProtein, proteinGoal: vm.goal.protein,
                        carbs:   vm.totalCarbs,   carbsGoal:   vm.goal.carbs,
                        fat:     vm.totalFat,     fatGoal:     vm.goal.fat
                    )

                    // Camera scan CTA
                    Button {
                        showCamera = true
                    } label: {
                        Label("Scan food with camera", systemImage: "camera.fill")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Meal sections
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSectionView(
                            meal: meal,
                            entries: vm.entries(for: meal),
                            totalCalories: vm.mealCalories(for: meal)
                        ) {
                            activeMeal = meal
                            showAddFood = true
                        } onDelete: { entry in
                            vm.deleteEntry(entry)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCamera) {
                FoodCameraView { result in
                    let entry = FoodEntry(
                        name: result.name,
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        servingSize: result.servingSize,
                        mealType: activeMeal
                    )
                    vm.addEntry(entry)
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(mealType: activeMeal) { entry in
                    vm.addEntry(entry)
                }
            }
        }
    }
}

#Preview {
    NutritionView()
}

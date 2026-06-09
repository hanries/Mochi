import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @StateObject private var vm        = NutritionViewModel()
    @StateObject private var healthKit = HealthKitService.shared
    @AppStorage("userName") private var userName = ""

    @State private var showSearch    = false
    @State private var showManual    = false
    @State private var showCamera    = false
    @State private var showLogBurn   = false
    @State private var editingEntry: FoodEntry? = nil
    @State private var activeMeal:   MealType   = .breakfast
    @State private var mochiScale:   CGFloat    = 0.8
    @State private var mochiOpacity: Double     = 0

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userName.isEmpty ? "" : ", \(userName)"
        switch hour {
        case 0..<12:  return "Good morning\(name)!"
        case 12..<17: return "Good afternoon\(name)!"
        case 17..<21: return "Good evening\(name)!"
        default:      return "Hey\(name)!"
        }
    }

    var hamsterState: HamsterState {
        let consumed = vm.totalCalories(from: allEntries)
        let goal     = vm.goal.calories
        let progress = Double(consumed) / Double(max(goal, 1))
        let hour     = Calendar.current.component(.hour, from: .now)
        if consumed == 0 && hour >= 19 { return .sad      }
        if consumed == 0               { return .sleeping }
        if progress >= 1.0             { return .excited  }
        if progress >= 0.8             { return .focused  }
        if consumed > 0                { return .happy    }
        return .idle
    }

    var calorieProgress: Double {
        min(Double(vm.totalCalories(from: allEntries)) / Double(max(vm.goal.calories, 1)), 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Mochi Full-Screen Hero
                    GeometryReader { geo in
                        ZStack {
                            // Warm background fills full screen
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.93, blue: 0.72),
                                    Color(uiColor: .systemBackground)
                                ],
                                startPoint: .top,
                                endPoint:   .bottom
                            )
                            .frame(width: geo.size.width, height: geo.size.height)

                            VStack(spacing: 0) {
                                Spacer()

                                // Greeting
                                Text(greeting)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .padding(.bottom, 8)

                                // Mochi — center stage, interactive
                                InteractiveMochiView(state: hamsterState, size: 200)
                                    .scaleEffect(mochiScale)
                                    .opacity(mochiOpacity)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hamsterState)
                                    .onAppear {
                                        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                                            mochiScale   = 1.0
                                            mochiOpacity = 1.0
                                        }
                                    }

                                // Message bubble
                                HStack(spacing: 8) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(hamsterState.message)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(.horizontal, 32)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .animation(.easeInOut(duration: 0.4), value: hamsterState)

                                // Calorie progress bar
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("\(vm.totalCalories(from: allEntries)) kcal")
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        Text("Goal: \(vm.goal.calories)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.secondary.opacity(0.15))
                                                .frame(height: 10)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        colors: calorieProgress >= 1.0
                                                            ? [.red, .orange]
                                                            : [Color(red: 1.0, green: 0.7, blue: 0.2),
                                                               Color(red: 1.0, green: 0.5, blue: 0.1)],
                                                        startPoint: .leading,
                                                        endPoint:   .trailing
                                                    )
                                                )
                                                .frame(width: barGeo.size.width * calorieProgress, height: 10)
                                                .animation(.spring(response: 0.6), value: calorieProgress)
                                        }
                                    }
                                    .frame(height: 10)
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 20)

                                // Quick actions
                                HStack(spacing: 10) {
                                    HomeActionButton(icon: "camera.fill",       label: "Scan")   { showCamera = true }
                                    HomeActionButton(icon: "magnifyingglass",   label: "Search") { activeMeal = .lunch; showSearch = true }
                                    HomeActionButton(icon: "square.and.pencil", label: "Manual") { activeMeal = .lunch; showManual = true }
                                    HomeActionButton(icon: "flame",             label: "Burn")   { showLogBurn = true }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                                Spacer()

                                // Scroll hint anchored to bottom
                                VStack(spacing: 4) {
                                    Text("scroll to manage meals")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.bottom, 28)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height)

                    // MARK: - Meals section
                    VStack(spacing: 16) {
                        // Macro summary
                        HStack(spacing: 8) {
                            MacroCard(label: "Protein",
                                      value: vm.totalProtein(from: allEntries),
                                      goal:  vm.goal.protein,
                                      color: Color(red: 0.3, green: 0.71, blue: 0.67))
                            MacroCard(label: "Carbs",
                                      value: vm.totalCarbs(from: allEntries),
                                      goal:  vm.goal.carbs,
                                      color: Color(red: 1.0, green: 0.72, blue: 0.3))
                            MacroCard(label: "Fat",
                                      value: vm.totalFat(from: allEntries),
                                      goal:  vm.goal.fat,
                                      color: Color(red: 0.9, green: 0.35, blue: 0.35))
                        }
                        .padding(.horizontal)

                        // Meal sections
                        ForEach(MealType.allCases, id: \.self) { meal in
                            MealSectionView(
                                meal:          meal,
                                entries:       vm.entries(for: meal, from: allEntries),
                                totalCalories: vm.mealCalories(for: meal, from: allEntries),
                                isEditable:    true
                            ) {
                                activeMeal = meal
                                showSearch = true
                            } onDelete: { entry in
                                context.delete(entry)
                            } onEdit: { entry in
                                editingEntry = entry
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .task { await healthKit.fetchTodayCalories() }
            .sheet(isPresented: $showSearch) {
                FoodSearchView(mealType: activeMeal) { entry in context.insert(entry) }
            }
            .sheet(isPresented: $showManual) {
                AddFoodView(mealType: activeMeal) { entry in context.insert(entry) }
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry, onSave: { _ in }, onDelete: { e in context.delete(e) })
            }
            .sheet(isPresented: $showLogBurn) {
                LogBurnView(healthKit: healthKit) { _ in }
            }
            .fullScreenCover(isPresented: $showCamera) {
                FoodCameraView(
                    onResult: { result in
                        context.insert(FoodEntry(
                            name: result.name, calories: result.calories,
                            protein: result.protein, carbs: result.carbs, fat: result.fat,
                            servingSize: result.servingSize, mealType: activeMeal
                        ))
                    },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Macro Card

private struct MacroCard: View {
    let label: String
    let value: Double
    let goal:  Double
    let color: Color

    var progress: Double { min(value / max(goal, 1), 1.0) }

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

// MARK: - Home Action Button

private struct HomeActionButton: View {
    let icon:   String
    let label:  String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}

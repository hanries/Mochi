import SwiftUI
import SwiftData

struct MochiDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse)   private var allEntries:  [FoodEntry]
    @Query(sort: \WorkoutPlan.weekdayRaw)             private var plans:       [WorkoutPlan]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights:  [BodyWeightEntry]

    @AppStorage("userName") private var userName = ""
    @StateObject private var vm       = NutritionViewModel()
    @StateObject private var healthKit = HealthKitService.shared

    @State private var showSearch  = false
    @State private var showManual  = false
    @State private var showCamera  = false
    @State private var showWorkout = false
    @State private var cardOffset: CGFloat = 40
    @State private var cardOpacity: Double = 0

    // MARK: - Computed

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userName.isEmpty ? "" : ", \(userName)"
        switch hour {
        case 0..<12:  return "Good morning\(name)! 🌅"
        case 12..<17: return "Good afternoon\(name)! ☀️"
        case 17..<21: return "Good evening\(name)! 🌆"
        default:      return "Hey\(name)! 🌙"
        }
    }

    var todayCalories: Int    { vm.totalCalories(from: allEntries) }
    var todayProtein:  Double { vm.totalProtein(from: allEntries)  }
    var calorieGoal:   Int    { vm.goal.calories                   }

    var calorieProgress: Double {
        min(Double(todayCalories) / Double(max(calorieGoal, 1)), 1.0)
    }

    var todayWorkoutPlan: WorkoutPlan? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        let mapped  = weekday == 1 ? 7 : weekday - 1
        return plans.first { $0.weekdayRaw == mapped }
    }

    var workoutDone: Bool {
        todayWorkoutPlan?.exercises.allSatisfy(\.isCompleted) ?? false
    }

    var hamsterState: HamsterState {
        let hour     = Calendar.current.component(.hour, from: .now)
        let progress = calorieProgress
        if todayCalories == 0 && hour >= 19 { return .sad      }
        if todayCalories == 0               { return .sleeping }
        if progress >= 1.0                  { return .excited  }
        if progress >= 0.8                  { return .focused  }
        if todayCalories > 0                { return .happy    }
        return .idle
    }

    var primaryAction: (label: String, icon: String, action: () -> Void) {
        let hour = Calendar.current.component(.hour, from: .now)
        if todayCalories == 0 {
            return ("Log breakfast", "fork.knife", { showSearch = true })
        } else if todayWorkoutPlan != nil && !workoutDone {
            return ("Start workout", "dumbbell", { showWorkout = true })
        } else if hour < 12 {
            return ("Log breakfast", "fork.knife", { showSearch = true })
        } else if hour < 15 {
            return ("Log lunch", "fork.knife", { showSearch = true })
        } else {
            return ("Log dinner", "fork.knife", { showSearch = true })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Mochi Hero Section
                    ZStack(alignment: .bottom) {
                        // Background gradient
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.92, blue: 0.7).opacity(0.6),
                                Color(uiColor: .systemBackground)
                            ],
                            startPoint: .top,
                            endPoint:   .bottom
                        )
                        .frame(height: 340)
                        .ignoresSafeArea(edges: .top)

                        VStack(spacing: 8) {
                            // Greeting
                            Text(greeting)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)

                            // Mochi
                            HamsterView(state: hamsterState, size: 150)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hamsterState)

                            // State message
                            Text(hamsterState.message)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .animation(.easeInOut(duration: 0.4), value: hamsterState)
                        }
                        .padding(.bottom, 20)
                    }

                    // MARK: - Cards
                    VStack(spacing: 16) {

                        // Calorie card
                        DashboardCard {
                            HStack(alignment: .center, spacing: 16) {
                                // Ring
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.12), lineWidth: 8)
                                    Circle()
                                        .trim(from: 0, to: calorieProgress)
                                        .stroke(
                                            calorieProgress >= 1.0 ? Color.red : Color.orange,
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring(response: 0.6), value: calorieProgress)
                                    VStack(spacing: 1) {
                                        Text("\(Int(calorieProgress * 100))%")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("done")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 70, height: 70)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Calories")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("\(todayCalories)")
                                            .font(.system(size: 28, weight: .bold))
                                        Text("/ \(calorieGoal) kcal")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    // Macro pills
                                    HStack(spacing: 8) {
                                        MiniMacroPill(label: "P", value: Int(todayProtein), color: Color(red: 0.3, green: 0.71, blue: 0.67))
                                        MiniMacroPill(label: "C", value: Int(vm.totalCarbs(from: allEntries)), color: Color(red: 1.0, green: 0.72, blue: 0.3))
                                        MiniMacroPill(label: "F", value: Int(vm.totalFat(from: allEntries)), color: Color(red: 0.9, green: 0.35, blue: 0.35))
                                    }
                                }
                                Spacer()
                            }
                        }

                        // Workout card
                        DashboardCard {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(workoutDone ? Color.green.opacity(0.15) : Color.primary.opacity(0.08))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: workoutDone ? "checkmark" : "dumbbell")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(workoutDone ? .green : .primary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today's Workout")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    if let plan = todayWorkoutPlan {
                                        Text(plan.name)
                                            .font(.system(size: 18, weight: .bold))
                                        Text(workoutDone ? "Completed ✓" : "\(plan.exercises.filter { !$0.isCompleted }.count) exercises left")
                                            .font(.system(size: 13))
                                            .foregroundStyle(workoutDone ? .green : .secondary)
                                    } else {
                                        Text("Rest day")
                                            .font(.system(size: 18, weight: .bold))
                                        Text("No workout scheduled")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if todayWorkoutPlan != nil && !workoutDone {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onTapGesture {
                            if todayWorkoutPlan != nil { showWorkout = true }
                        }

                        // Weight card
                        if let latest = weights.first {
                            DashboardCard {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "scalemass")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.blue)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Body Weight")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.1f %@", latest.weight, latest.unit.rawValue))
                                            .font(.system(size: 22, weight: .bold))
                                        Text(latest.date.formatted(.relative(presentation: .named)))
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }

                        // Primary action button
                        Button(action: primaryAction.action) {
                            HStack(spacing: 10) {
                                Image(systemName: primaryAction.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(primaryAction.label)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Quick log buttons
                        HStack(spacing: 10) {
                            QuickButton(icon: "camera.fill", label: "Scan") { showCamera = true }
                            QuickButton(icon: "magnifyingglass", label: "Search") { showSearch = true }
                            QuickButton(icon: "square.and.pencil", label: "Manual") { showManual = true }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .offset(y: cardOffset)
                    .opacity(cardOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                            cardOffset  = 0
                            cardOpacity = 1
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task { await healthKit.fetchTodayCalories() }
            .sheet(isPresented: $showSearch) {
                FoodSearchView(mealType: .lunch) { entry in context.insert(entry) }
            }
            .sheet(isPresented: $showManual) {
                AddFoodView(mealType: .lunch) { entry in context.insert(entry) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                FoodCameraView(
                    onResult: { result in
                        context.insert(FoodEntry(
                            name: result.name, calories: result.calories,
                            protein: result.protein, carbs: result.carbs, fat: result.fat,
                            servingSize: result.servingSize, mealType: .lunch
                        ))
                    },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Dashboard Card

struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Mini Macro Pill

private struct MiniMacroPill: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)g")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Quick Button

private struct QuickButton: View {
    let icon:   String
    let label:  String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    MochiDashboardView()
        .modelContainer(for: [FoodEntry.self, WorkoutPlan.self, BodyWeightEntry.self], inMemory: true)
}

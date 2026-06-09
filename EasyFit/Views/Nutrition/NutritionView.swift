import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @AppStorage("userName") private var userName = ""
    @StateObject private var vm        = NutritionViewModel()
    @StateObject private var healthKit = HealthKitService.shared

    @State private var showCamera     = false
    @State private var showSearch     = false
    @State private var showManual     = false
    @State private var showLogBurn    = false
    @State private var showDatePicker = false
    @State private var editingEntry:  FoodEntry? = nil
    @State private var manualBurned   = 0
    @State private var activeMeal:    MealType = .breakfast

    var isToday: Bool { Calendar.current.isDateInToday(vm.selectedDate) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            // Date row
                            HStack {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: vm.selectedDate)!
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Button { showDatePicker = true } label: {
                                    Text(isToday ? "Today, \(vm.selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
                                         : vm.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: vm.selectedDate)!
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isToday ? Theme.textTertiary : Theme.textSecondary)
                                }
                                .disabled(isToday)

                                Spacer()

                                // Camera shortcut
                                if isToday {
                                    Button { showCamera = true } label: {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.textSecondary)
                                            .frame(width: 36, height: 36)
                                            .background(Theme.card)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                            // Big title
                            Text("MEALS")
                                .font(.system(size: 52, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                        }

                        // MARK: - Calorie + Macro summary
                        DarkCalorieSummary(
                            consumed: vm.totalCalories(from: allEntries),
                            goal:     vm.goal.calories,
                            burned:   healthKit.isAuthorized ? healthKit.totalBurnedToday : manualBurned,
                            protein:  vm.totalProtein(from: allEntries), proteinGoal: vm.goal.protein,
                            carbs:    vm.totalCarbs(from: allEntries),   carbsGoal:   vm.goal.carbs,
                            fat:      vm.totalFat(from: allEntries),     fatGoal:     vm.goal.fat,
                            onLogBurn: { if isToday { showLogBurn = true } }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // MARK: - Meal filter pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(MealType.allCases, id: \.self) { meal in
                                    MealPill(
                                        label:      meal.rawValue,
                                        calories:   vm.mealCalories(for: meal, from: allEntries),
                                        isSelected: activeMeal == meal
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            activeMeal = meal
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 24)

                        // MARK: - Food entries for active meal
                        let mealEntries = vm.entries(for: activeMeal, from: allEntries)

                        VStack(spacing: 12) {
                            if mealEntries.isEmpty {
                                EmptyMealCard(meal: activeMeal, isToday: isToday) {
                                    showSearch = true
                                }
                            } else {
                                ForEach(mealEntries) { entry in
                                    DarkFoodCard(entry: entry, isEditable: isToday) {
                                        editingEntry = entry
                                    } onDelete: {
                                        context.delete(entry)
                                    }
                                }
                            }

                            if isToday {
                                // Add food row
                                Button {
                                    showSearch = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Theme.teal)
                                            .frame(width: 36, height: 36)
                                            .background(Theme.tealDim)
                                            .clipShape(Circle())
                                        Text("Add food to \(activeMeal.rawValue.lowercased())")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Theme.textSecondary)
                                        Spacer()
                                    }
                                    .padding(14)
                                    .darkCard()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 100) // space for FAB
                    }
                }

                // MARK: - FAB row (Scan / Search / Manual)
                if isToday {
                    HStack(spacing: 12) {
                        FABButton(icon: "camera.fill", label: "Scan") { showCamera = true }
                        FABButton(icon: "magnifyingglass", label: "Search", accent: true) { showSearch = true }
                        FABButton(icon: "square.and.pencil", label: "Manual") { showManual = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Theme.bg.opacity(0), Theme.bg],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false),
                        alignment: .top
                    )
                }
            }
            .navigationBarHidden(true)
            .task { await healthKit.fetchTodayCalories() }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $vm.selectedDate)
                    .preferredColorScheme(.dark)
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
            .sheet(isPresented: $showSearch) {
                FoodSearchView(mealType: activeMeal) { entry in context.insert(entry) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showManual) {
                AddFoodView(mealType: activeMeal) { entry in context.insert(entry) }
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry, onSave: { _ in }, onDelete: { e in context.delete(e) })
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showLogBurn) {
                LogBurnView(healthKit: healthKit) { kcal in manualBurned += kcal }
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Dark Calorie + Macro Summary

private struct DarkCalorieSummary: View {
    let consumed: Int; let goal: Int; let burned: Int
    let protein: Double; let proteinGoal: Double
    let carbs: Double;   let carbsGoal: Double
    let fat: Double;     let fatGoal: Double
    let onLogBurn: () -> Void

    var progress: Double { min(Double(consumed) / Double(max(goal, 1)), 1.0) }
    var remaining: Int   { max(goal - consumed, 0) }

    var body: some View {
        VStack(spacing: 14) {
            // Calorie row
            HStack(spacing: 16) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Theme.teal.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1.0 ? Color.red : Theme.teal,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: progress)
                    VStack(spacing: 1) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("done")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(consumed)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("/ \(goal) kcal")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 16) {
                        CalStat(label: "Left",  value: "\(remaining)", color: remaining == 0 ? .red : Theme.teal)
                        Button(action: onLogBurn) {
                            CalStat(label: "Burned", value: burned > 0 ? "\(burned)" : "—", color: Theme.textSecondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
            .darkCard()

            // Macro row
            HStack(spacing: 10) {
                DarkMacroPill(label: "Protein", value: Int(protein), goal: Int(proteinGoal),
                              color: Color(red: 0.3, green: 0.71, blue: 0.67))
                DarkMacroPill(label: "Carbs",   value: Int(carbs),   goal: Int(carbsGoal),
                              color: Color(red: 1.0, green: 0.72, blue: 0.3))
                DarkMacroPill(label: "Fat",     value: Int(fat),     goal: Int(fatGoal),
                              color: Color(red: 0.9, green: 0.35, blue: 0.35))
            }
        }
    }
}

private struct CalStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
    }
}

private struct DarkMacroPill: View {
    let label: String; let value: Int; let goal: Int; let color: Color
    var progress: Double { goal > 0 ? min(Double(value) / Double(goal), 1.0) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text("\(value)g").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("/ \(goal)g").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .darkCard(cornerRadius: 14)
    }
}

// MARK: - Meal Filter Pill

private struct MealPill: View {
    let label:      String
    let calories:   Int
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                if calories > 0 {
                    Text("\(calories) kcal")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.teal : Theme.card)
            .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Dark Food Card

struct DarkFoodCard: View {
    let entry:      FoodEntry
    let isEditable: Bool
    let onEdit:     () -> Void
    let onDelete:   () -> Void

    var emoji: String {
        switch entry.mealType {
        case .breakfast: return "🥚"
        case .lunch:     return "🍗"
        case .dinner:    return "🥗"
        case .snack:     return "🍎"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 54, height: 54)
                .background(Theme.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(entry.calories) kcal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.teal)
                    Text("·")
                        .foregroundStyle(Theme.textTertiary)
                    Text(entry.servingSize)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Macro chips
            VStack(alignment: .trailing, spacing: 3) {
                MiniChip(label: "P", value: Int(entry.protein), color: Color(red: 0.3, green: 0.71, blue: 0.67))
                MiniChip(label: "C", value: Int(entry.carbs),   color: Color(red: 1.0, green: 0.72, blue: 0.3))
                MiniChip(label: "F", value: Int(entry.fat),     color: Color(red: 0.9, green: 0.35, blue: 0.35))
            }
        }
        .padding(14)
        .darkCard()
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { if isEditable { onEdit() } }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isEditable {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }
}

private struct MiniChip: View {
    let label: String; let value: Int; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text("\(value)g").font(.system(size: 9)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Empty Meal Card

private struct EmptyMealCard: View {
    let meal: MealType; let isToday: Bool; let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textTertiary)
            Text("Nothing logged for \(meal.rawValue.lowercased()) yet")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if isToday {
                Button(action: onAdd) {
                    Text("Add food")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.teal)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .darkCard()
    }
}

// MARK: - FAB Button

private struct FABButton: View {
    let icon:   String
    let label:  String
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accent ? Theme.teal : Theme.card)
            .foregroundStyle(accent ? Color.black : Theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Date picker sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    var body: some View {
        NavigationStack {
            DatePicker("Select date", selection: $selectedDate, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NutritionView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
        .preferredColorScheme(.dark)
}

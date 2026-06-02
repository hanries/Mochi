import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @AppStorage("userName") private var userName = ""
    @StateObject private var vm        = NutritionViewModel()
    @StateObject private var healthKit = HealthKitService.shared
    @State private var showCamera      = false
    @State private var showSearch      = false
    @State private var showManual      = false
    @State private var showLogBurn     = false
    @State private var showDatePicker  = false
    @State private var editingEntry:   FoodEntry? = nil
    @State private var manualBurned    = 0
    @State private var activeMeal:     MealType = .breakfast

    var isToday: Bool { Calendar.current.isDateInToday(vm.selectedDate) }

    var navTitle: String {
        if isToday { return userName.isEmpty ? "Nutrition" : "Hi, \(userName) 👋" }
        return vm.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DateNavigationBar(selectedDate: $vm.selectedDate, showDatePicker: $showDatePicker)

                ScrollView {
                    VStack(spacing: 24) {
                        CalorieRingView(
                            consumed: vm.totalCalories(from: allEntries),
                            goal:     vm.goal.calories,
                            burned:   healthKit.isAuthorized ? healthKit.totalBurnedToday : manualBurned
                        ) {
                            if isToday { showLogBurn = true }
                        }

                        MacroSummaryView(
                            protein:     vm.totalProtein(from: allEntries), proteinGoal: vm.goal.protein,
                            carbs:       vm.totalCarbs(from: allEntries),   carbsGoal:   vm.goal.carbs,
                            fat:         vm.totalFat(from: allEntries),     fatGoal:     vm.goal.fat
                        )

                        if isToday {
                            HStack(spacing: 10) {
                                ActionButton(icon: "camera.fill",       label: "Scan")   { showCamera = true }
                                ActionButton(icon: "magnifyingglass",   label: "Search") { activeMeal = .breakfast; showSearch = true }
                                ActionButton(icon: "square.and.pencil", label: "Manual") { activeMeal = .breakfast; showManual = true }
                            }
                            .padding(.horizontal)
                        }

                        ForEach(MealType.allCases, id: \.self) { meal in
                            MealSectionView(
                                meal:          meal,
                                entries:       vm.entries(for: meal, from: allEntries),
                                totalCalories: vm.mealCalories(for: meal, from: allEntries),
                                isEditable:    isToday
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
                    .padding(.vertical)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDatePicker.toggle() } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                if !isToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today") {
                            withAnimation { vm.selectedDate = .now }
                        }
                        .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .task { await healthKit.fetchTodayCalories() }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $vm.selectedDate)
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
            }
            .sheet(isPresented: $showManual) {
                AddFoodView(mealType: activeMeal) { entry in context.insert(entry) }
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(
                    entry: entry,
                    onSave: { _ in },       // SwiftData auto-saves @Model mutations
                    onDelete: { e in context.delete(e) }
                )
            }
            .sheet(isPresented: $showLogBurn) {
                LogBurnView(healthKit: healthKit) { kcal in manualBurned += kcal }
            }
        }
    }
}

// MARK: - Date navigation bar

struct DateNavigationBar: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    private let cal = Calendar.current
    var isToday: Bool { cal.isDateInToday(selectedDate) }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button { showDatePicker = true } label: {
                VStack(spacing: 2) {
                    Text(isToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isToday ? .primary : .secondary)
                    Text(selectedDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isToday ? Color.secondary.opacity(0.3) : .primary)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 8)
        .background(Color(uiColor: .systemBackground))
        Divider()
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

// MARK: - Action button

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

import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let onAdd: (FoodEntry) -> Void

    @State private var query        = ""
    @State private var results:     [FoodSearchResult] = []
    @State private var isSearching  = false
    @State private var errorMessage: String? = nil
    @State private var selected:    FoodSearchResult? = nil
    @State private var searchTask:  Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search foods…", text: $query)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { runSearch() }
                        .onChange(of: query) { _, newVal in
                            searchTask?.cancel()
                            if newVal.isEmpty {
                                results = []
                                errorMessage = nil
                            } else {
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run { runSearch() }
                                }
                            }
                        }
                    if !query.isEmpty {
                        Button { query = ""; results = []; errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                if isSearching {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            errorMessage = nil
                            runSearch()
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.primary)
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(32)
                    Spacer()
                } else if results.isEmpty && !query.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("No results for '\(query)'")
                            .font(.system(size: 15, weight: .medium))
                        Text("Try a different spelling or add it manually.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("Search the food database")
                            .font(.system(size: 16, weight: .medium))
                        Text("Powered by USDA FoodData Central\nMillions of verified foods")
                            .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List(results) { food in
                        FoodResultRow(food: food)
                            .contentShape(Rectangle())
                            .onTapGesture { selected = food }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        // Trigger manual add — caller handles this
                    } label: {
                        Label("Manual", systemImage: "square.and.pencil")
                            .font(.system(size: 14))
                    }
                }
            }
            .sheet(item: $selected) { food in
                FoodDetailSheet(food: food, mealType: mealType) { entry in
                    onAdd(entry)
                    dismiss()
                }
            }
        }
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching  = true
        errorMessage = nil
        Task {
            do {
                let r = try await FoodSearchService.shared.search(query: query)
                await MainActor.run {
                    results    = r
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't reach the food database. Check your connection."
                    isSearching  = false
                }
            }
        }
    }
}

// MARK: - Result row

private struct FoodResultRow: View {
    let food: FoodSearchResult

    var body: some View {
        HStack(spacing: 12) {
            // Calorie badge
            VStack(spacing: 1) {
                Text("\(food.calories)")
                    .font(.system(size: 15, weight: .bold))
                Text("kcal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    MacroPill(label: "P", value: food.protein, color: Color(red: 0.3, green: 0.71, blue: 0.67))
                    MacroPill(label: "C", value: food.carbs,   color: Color(red: 1.0, green: 0.72, blue: 0.3))
                    MacroPill(label: "F", value: food.fat,     color: Color(red: 0.9, green: 0.35, blue: 0.35))
                    Text(food.servingSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(String(format: "%.0fg", value)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Food detail / confirm sheet

struct FoodDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let food: FoodSearchResult
    let mealType: MealType
    let onAdd: (FoodEntry) -> Void

    @State private var selectedMeal: MealType
    @State private var servings: String = "1"

    init(food: FoodSearchResult, mealType: MealType, onAdd: @escaping (FoodEntry) -> Void) {
        self.food     = food
        self.mealType = mealType
        self.onAdd    = onAdd
        _selectedMeal = State(initialValue: mealType)
    }

    var multiplier: Double { Double(servings) ?? 1.0 }

    var scaledCalories: Int    { Int((Double(food.calories) * multiplier).rounded()) }
    var scaledProtein:  Double { (food.protein * multiplier * 10).rounded() / 10 }
    var scaledCarbs:    Double { (food.carbs   * multiplier * 10).rounded() / 10 }
    var scaledFat:      Double { (food.fat     * multiplier * 10).rounded() / 10 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)
                        if let brand = food.brand, !brand.isEmpty {
                            Text(food.brand ?? "")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // Calorie + macros
                    VStack(spacing: 0) {
                        HStack {
                            Text("Calories")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text("\(scaledCalories) kcal")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Protein", value: scaledProtein,
                                    color: Color(red: 0.3, green: 0.71, blue: 0.67))
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Carbs",   value: scaledCarbs,
                                    color: Color(red: 1.0, green: 0.72, blue: 0.3))
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Fat",     value: scaledFat,
                                    color: Color(red: 0.9, green: 0.35, blue: 0.35))
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Servings + meal picker
                    VStack(spacing: 0) {
                        HStack {
                            Text("Servings")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            HStack(spacing: 0) {
                                Button {
                                    let v = (Double(servings) ?? 1) - 0.5
                                    if v > 0 {
                                        servings = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
                                    }
                                } label: {
                                    Image(systemName: "minus").frame(width: 36, height: 36)
                                }
                                TextField("1", text: $servings)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 44)
                                Button {
                                    let v = (Double(servings) ?? 1) + 0.5
                                    servings = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
                                } label: {
                                    Image(systemName: "plus").frame(width: 36, height: 36)
                                }
                            }
                            .foregroundStyle(.primary)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Serving size")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text(food.servingSize)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Meal")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Picker("Meal", selection: $selectedMeal) {
                                ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 4)
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Add button
                    Button {
                        onAdd(FoodEntry(
                            name:        food.name,
                            calories:    scaledCalories,
                            protein:     scaledProtein,
                            carbs:       scaledCarbs,
                            fat:         scaledFat,
                            servingSize: "\(servings) × \(food.servingSize)",
                            mealType:    selectedMeal
                        ))
                    } label: {
                        Text("Add to \(selectedMeal.rawValue)")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct NutrientRow: View {
    let label: String
    let value: Double
    let color: Color
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4, height: 18)
                Text(label).font(.system(size: 15, weight: .medium))
            }
            Spacer()
            Text(String(format: "%.1fg", value))
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

#Preview {
    FoodSearchView(mealType: .lunch) { _ in }
}

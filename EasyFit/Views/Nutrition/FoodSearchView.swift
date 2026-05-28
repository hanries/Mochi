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

    private var recentFoods: [String] {
        SearchHistoryService.shared.history
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key.capitalized }
    }

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
                            } else if newVal.count >= 2 {
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
                                .padding(.horizontal, 20).padding(.vertical, 10)
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
                    // Empty state — show recent foods
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !recentFoods.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Recent")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                        .padding(.horizontal, 16)

                                    FlowLayout(spacing: 8) {
                                        ForEach(recentFoods, id: \.self) { food in
                                            Button {
                                                query = food
                                                runSearch()
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .font(.system(size: 11))
                                                    Text(food)
                                                        .font(.system(size: 13, weight: .medium))
                                                }
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(Color(uiColor: .secondarySystemBackground))
                                                .foregroundStyle(.primary)
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40)).foregroundStyle(.secondary)
                                Text("Search the food database")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Powered by Edamam\nMillions of foods and branded products")
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, recentFoods.isEmpty ? 80 : 20)
                        }
                        .padding(.top, 16)
                    }

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
            }
            .sheet(item: $selected) { food in
                FoodDetailSheet(food: food, mealType: mealType) { entry in
                    // Record to history
                    SearchHistoryService.shared.record(foodName: food.name)
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
                await MainActor.run { results = r; isSearching = false }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't reach the food database. Check your connection."
                    isSearching  = false
                }
            }
        }
    }
}

// MARK: - Flow layout for recent chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, size.height); x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height); x += size.width + spacing
        }
    }
}

// MARK: - Result row

private struct FoodResultRow: View {
    let food: FoodSearchResult

    var body: some View {
        HStack(spacing: 12) {
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
                HStack(spacing: 6) {
                    Text(food.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                    // Show clock icon if previously logged
                    if SearchHistoryService.shared.score(for: food.name) > 0 {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                if let brand = food.brandName, !brand.isEmpty {
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
    let label: String; let value: Double; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(String(format: "%.0fg", value)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Nutrient row

private struct NutrientRow: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4, height: 18)
                Text(label).font(.system(size: 15, weight: .medium))
            }
            Spacer()
            Text(String(format: "%.1fg", value)).font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Food detail sheet

struct FoodDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let food:     FoodSearchResult
    let mealType: MealType
    let onAdd:    (FoodEntry) -> Void

    @State private var selectedMeal:    MealType
    @State private var quantity:        String = "1"
    @State private var selectedServing: ServingOption

    init(food: FoodSearchResult, mealType: MealType, onAdd: @escaping (FoodEntry) -> Void) {
        self.food     = food
        self.mealType = mealType
        self.onAdd    = onAdd
        _selectedMeal    = State(initialValue: mealType)
        _selectedServing = State(initialValue: food.defaultServing)
    }

    var qty: Double { Double(quantity) ?? 1.0 }
    var scaledCalories: Int    { Int((food.caloriesPer100g * selectedServing.weightGrams * qty / 100).rounded()) }
    var scaledProtein:  Double { round1dp(food.proteinPer100g * selectedServing.weightGrams * qty / 100) }
    var scaledCarbs:    Double { round1dp(food.carbsPer100g   * selectedServing.weightGrams * qty / 100) }
    var scaledFat:      Double { round1dp(food.fatPer100g     * selectedServing.weightGrams * qty / 100) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)
                        if let brand = food.brandName, !brand.isEmpty {
                            Text(brand).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // Serving unit chips
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Serving unit")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(food.servingOptions) { option in
                                    let isSelected = selectedServing.id == option.id
                                    Button {
                                        selectedServing = option; quantity = "1"
                                    } label: {
                                        Text(option.label)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(isSelected ? Color.primary : Color(uiColor: .tertiarySystemBackground))
                                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Quantity stepper
                    HStack {
                        Text("Quantity").font(.system(size: 15, weight: .medium))
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                let v = (Double(quantity) ?? 1) - 0.5
                                if v > 0 { quantity = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)" }
                            } label: { Image(systemName: "minus").frame(width: 36, height: 36) }
                            TextField("1", text: $quantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44)
                            Button {
                                let v = (Double(quantity) ?? 1) + 0.5
                                quantity = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
                            } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                        }
                        .foregroundStyle(.primary)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Nutrition facts
                    VStack(spacing: 0) {
                        HStack {
                            Text("Calories").font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text("\(scaledCalories) kcal").font(.system(size: 17, weight: .bold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Protein", value: scaledProtein, color: Color(red: 0.3, green: 0.71, blue: 0.67))
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Carbs",   value: scaledCarbs,   color: Color(red: 1.0, green: 0.72, blue: 0.3))
                        Divider().padding(.leading, 16)
                        NutrientRow(label: "Fat",     value: scaledFat,     color: Color(red: 0.9, green: 0.35, blue: 0.35))
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // Meal picker
                    HStack {
                        Text("Meal").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("Meal", selection: $selectedMeal) {
                            ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
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
                            servingSize: "\(quantity) × \(selectedServing.label)",
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

    private func round1dp(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

#Preview {
    FoodSearchView(mealType: .lunch) { _ in }
}

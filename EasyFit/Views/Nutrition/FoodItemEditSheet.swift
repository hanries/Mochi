import SwiftUI

// MARK: - Editable food draft
//
// A value-type stand-in for one food, used both for unsaved scan items
// and for editing an already-saved FoodEntry. Value semantics keep the
// scan-result totals recompute trivial — mutate the array, SwiftUI
// re-derives the sums.

struct FoodItemDraft: Identifiable, Equatable {
    var id: UUID = UUID()
    var name:        String
    var servingSize: String
    var calories:    Int
    var protein:     Double
    var carbs:       Double
    var fat:         Double
    // Non-nil → saved-entry mode: the sheet shows a meal picker.
    var mealType:    MealType? = nil
    // AI confidence for an unedited scan item; nil for user-added/edited rows.
    var confidence:  Double? = nil

    init(
        id: UUID = UUID(),
        name: String,
        servingSize: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        mealType: MealType? = nil,
        confidence: Double? = nil
    ) {
        self.id          = id
        self.name        = name
        self.servingSize = servingSize
        self.calories    = calories
        self.protein     = protein
        self.carbs       = carbs
        self.fat         = fat
        self.mealType    = mealType
        self.confidence  = confidence
    }

    init(item: FoodScanItem) {
        self.init(
            name: item.name, servingSize: item.servingSize, calories: item.calories,
            protein: item.protein, carbs: item.carbs, fat: item.fat,
            confidence: item.confidence
        )
    }

    init(entry: FoodEntry) {
        self.init(
            id: entry.id, name: entry.name, servingSize: entry.servingSize,
            calories: entry.calories, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, mealType: entry.mealType
        )
    }

    static func empty() -> FoodItemDraft {
        FoodItemDraft(name: "", servingSize: "1 serving", calories: 0, protein: 0, carbs: 0, fat: 0)
    }
}

// MARK: - Unified edit sheet

// Edits one food. Correcting the name searches the live nutrition
// database so a fixed label becomes real data; portion and serving are
// adjustable; nutrition recomputes from whichever basis is active. This
// sheet never logs or celebrates — the caller owns persistence.

struct FoodItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: FoodItemDraft
    var startInSearch: Bool = false
    var allowDelete:   Bool = true
    let onSave:   (FoodItemDraft) -> Void
    var onDelete: (() -> Void)? = nil

    // The nutrition source: fixed values (AI / saved entry) scaled by
    // quantity, or a database food scaled by serving weight × quantity.
    private enum NutritionBasis {
        case fixed(cal: Double, p: Double, c: Double, f: Double)
        case database(food: FoodSearchResult, serving: ServingOption)
    }

    @State private var name:     String
    @State private var quantity: Double = 1
    @State private var mealType: MealType
    private let showMealPicker: Bool

    @State private var basis: NutritionBasis
    // Serving picker state for the .fixed basis (string-based).
    @State private var selectedServing: String
    @State private var customServing:   String
    @State private var showCustom:      Bool = false

    // Live search
    @State private var results:     [FoodSearchResult] = []
    @State private var isSearching  = false
    @State private var searchTask:  Task<Void, Never>? = nil
    @State private var suppressNextSearch = false
    @FocusState private var nameFocused: Bool

    init(
        draft: FoodItemDraft,
        startInSearch: Bool = false,
        allowDelete: Bool = true,
        onSave: @escaping (FoodItemDraft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialDraft  = draft
        self.startInSearch = startInSearch
        self.allowDelete   = allowDelete
        self.onSave        = onSave
        self.onDelete      = onDelete

        _name     = State(initialValue: draft.name)
        _mealType = State(initialValue: draft.mealType ?? .lunch)
        showMealPicker = draft.mealType != nil
        _basis = State(initialValue: .fixed(
            cal: Double(draft.calories), p: draft.protein, c: draft.carbs, f: draft.fat
        ))
        _selectedServing = State(initialValue: draft.servingSize)
        _customServing   = State(initialValue: draft.servingSize)
    }

    // MARK: Scaled nutrition (live)

    private var scaledCalories: Int {
        switch basis {
        case let .fixed(cal, _, _, _):
            return Int((cal * quantity).rounded())
        case let .database(food, serving):
            return Int((food.caloriesPer100g * serving.weightGrams * quantity / 100).rounded())
        }
    }
    private var scaledProtein: Double {
        switch basis {
        case let .fixed(_, p, _, _):           return round1(p * quantity)
        case let .database(food, serving):     return round1(food.proteinPer100g * serving.weightGrams * quantity / 100)
        }
    }
    private var scaledCarbs: Double {
        switch basis {
        case let .fixed(_, _, c, _):           return round1(c * quantity)
        case let .database(food, serving):     return round1(food.carbsPer100g * serving.weightGrams * quantity / 100)
        }
    }
    private var scaledFat: Double {
        switch basis {
        case let .fixed(_, _, _, f):           return round1(f * quantity)
        case let .database(food, serving):     return round1(food.fatPer100g * serving.weightGrams * quantity / 100)
        }
    }

    private var displayServingLabel: String {
        switch basis {
        case .fixed:                  return showCustom ? customServing : selectedServing
        case let .database(_, s):     return s.label
        }
    }

    private var qtyString: String {
        quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(quantity))" : String(format: "%.1f", quantity)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && scaledCalories > 0
    }

    private var fixedServingUnits: [String] {
        var units = [initialDraft.servingSize]
        for e in ["1 serving", "0.5 serving", "2 servings", "100g", "200g"] {
            if !units.contains(e) { units.append(e) }
        }
        return units
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Food name + live search
                Section("Food") {
                    TextField("Name", text: $name)
                        .focused($nameFocused)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newVal in
                            handleNameChange(newVal)
                        }

                    if nameFocused && (isSearching || !results.isEmpty) {
                        if isSearching && results.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Searching the food database…")
                                    .font(MochiTheme.caption)
                                    .foregroundStyle(MochiTheme.textSecondary)
                            }
                        }
                        ForEach(results.prefix(5)) { food in
                            Button { pick(food) } label: {
                                SearchSuggestionRow(food: food)
                            }
                            .buttonStyle(.plain)
                        }
                        if !results.isEmpty {
                            Button("Keep my own values") {
                                results = []
                                nameFocused = false
                            }
                            .font(MochiTheme.caption)
                            .foregroundStyle(MochiTheme.textSecondary)
                        }
                    }

                    if showMealPicker {
                        Picker("Meal", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }

                // MARK: Serving + quantity
                Section("Serving") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if quantity > 0.5 { quantity = round1(quantity - 0.5) }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(quantity > 0.5 ? MochiTheme.textPrimary : MochiTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            Text(qtyString)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minWidth: 32)
                                .multilineTextAlignment(.center)
                            Button {
                                quantity = round1(quantity + 0.5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(MochiTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    switch basis {
                    case .fixed:
                        Picker("Serving size", selection: $selectedServing) {
                            ForEach(fixedServingUnits, id: \.self) { Text($0).tag($0) }
                            Text("Custom…").tag("Custom…")
                        }
                        .onChange(of: selectedServing) { _, val in showCustom = (val == "Custom…") }
                        if showCustom {
                            TextField("e.g. 1 cup, 30g", text: $customServing)
                        }
                    case let .database(food, serving):
                        Picker("Serving size", selection: Binding(
                            get: { serving.id },
                            set: { newID in
                                if let opt = food.servingOptions.first(where: { $0.id == newID }) {
                                    basis = .database(food: food, serving: opt)
                                    quantity = 1
                                }
                            }
                        )) {
                            ForEach(food.servingOptions) { Text($0.label).tag($0.id) }
                        }
                    }
                }

                // MARK: Scaled nutrition (read-only)
                Section("Nutrition (scaled)") {
                    NutritionInfoRow(label: "Calories", value: "\(scaledCalories) kcal")
                    NutritionInfoRow(label: "Protein",  value: String(format: "%.1fg", scaledProtein))
                    NutritionInfoRow(label: "Carbs",    value: String(format: "%.1fg", scaledCarbs))
                    NutritionInfoRow(label: "Fat",      value: String(format: "%.1fg", scaledFat))
                }

                if allowDelete, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Item", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(startInSearch ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if startInSearch { nameFocused = true }
            }
        }
    }

    // MARK: Actions

    private func handleNameChange(_ newVal: String) {
        // Skip the search triggered by programmatically setting the name
        // when a suggestion is picked.
        if suppressNextSearch { suppressNextSearch = false; return }
        searchTask?.cancel()
        let trimmed = newVal.trimmingCharacters(in: .whitespaces)
        guard nameFocused, trimmed.count >= 2 else {
            results = []; isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let r = try await FoodSearch.provider.search(query: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run { results = r; isSearching = false }
            } catch {
                await MainActor.run { results = []; isSearching = false }
            }
        }
    }

    private func pick(_ food: FoodSearchResult) {
        suppressNextSearch = true
        name = food.name
        basis = .database(food: food, serving: food.defaultServing)
        quantity = 1
        results = []
        isSearching = false
        nameFocused = false
        SearchHistoryService.shared.record(foodName: food.name)
    }

    private func save() {
        let label = displayServingLabel
        let serving = quantity == 1 ? label : "\(qtyString) × \(label)"
        let out = FoodItemDraft(
            id: initialDraft.id,
            name: name.trimmingCharacters(in: .whitespaces),
            servingSize: serving,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            mealType: showMealPicker ? mealType : nil
        )
        onSave(out)
        dismiss()
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

// MARK: - Pieces

private struct SearchSuggestionRow: View {
    let food: FoodSearchResult
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("\(food.calories)").font(.system(size: 14, weight: .bold)).foregroundStyle(MochiTheme.textPrimary)
                Text("kcal").font(.system(size: 9)).foregroundStyle(MochiTheme.textSecondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MochiTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    SuggestionMacro(label: "P", value: food.protein, color: MochiTheme.success)
                    SuggestionMacro(label: "C", value: food.carbs,   color: MochiTheme.warning)
                    SuggestionMacro(label: "F", value: food.fat,     color: MochiTheme.accent)
                    Text(food.servingSize).font(.system(size: 11)).foregroundStyle(MochiTheme.textSecondary.opacity(0.7))
                }
            }
            Spacer()
            Image(systemName: "arrow.up.left").font(.system(size: 12)).foregroundStyle(MochiTheme.textSecondary.opacity(0.6))
        }
        .contentShape(Rectangle())
    }
}

private struct SuggestionMacro: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(String(format: "%.0fg", value)).font(.system(size: 10)).foregroundStyle(MochiTheme.textSecondary)
        }
    }
}

struct NutritionInfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(MochiTheme.textSecondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

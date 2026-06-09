import SwiftUI

// MealSectionView is no longer used directly — NutritionView uses DarkFoodCard inline.
// This file retains EditFoodEntryView and the shared EditFoodEntry sheet.

// MARK: - Edit Food Entry Sheet

struct EditFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let entry:    FoodEntry
    let onSave:   (FoodEntry) -> Void
    let onDelete: (FoodEntry) -> Void

    @State private var name:            String
    @State private var mealType:        MealType
    @State private var quantity:        Double
    @State private var selectedServing: String
    @State private var customServing:   String
    @State private var showCustom:      Bool = false

    private let baseCal:     Double
    private let baseProtein: Double
    private let baseCarbs:   Double
    private let baseFat:     Double

    init(entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void, onDelete: @escaping (FoodEntry) -> Void) {
        self.entry    = entry
        self.onSave   = onSave
        self.onDelete = onDelete
        _name            = State(initialValue: entry.name)
        _mealType        = State(initialValue: entry.mealType)
        _quantity        = State(initialValue: 1.0)
        _selectedServing = State(initialValue: entry.servingSize)
        _customServing   = State(initialValue: entry.servingSize)
        baseCal     = Double(entry.calories)
        baseProtein = entry.protein
        baseCarbs   = entry.carbs
        baseFat     = entry.fat
    }

    var scaledCalories: Int    { Int((baseCal     * quantity).rounded()) }
    var scaledProtein:  Double { (baseProtein * quantity * 10).rounded() / 10 }
    var scaledCarbs:    Double { (baseCarbs   * quantity * 10).rounded() / 10 }
    var scaledFat:      Double { (baseFat     * quantity * 10).rounded() / 10 }
    var displayServing: String { showCustom ? customServing : selectedServing }

    private var servingUnits: [String] {
        var units = [entry.servingSize]
        for e in ["1 serving", "0.5 serving", "2 servings", "100g", "200g"] {
            if !units.contains(e) { units.append(e) }
        }
        return units
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Serving") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if quantity > 0.5 { quantity = ((quantity - 0.5) * 10).rounded() / 10 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(quantity > 0.5 ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                            Text(quantity.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(quantity))" : String(format: "%.1f", quantity))
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minWidth: 32)
                                .multilineTextAlignment(.center)
                            Button {
                                quantity = ((quantity + 0.5) * 10).rounded() / 10
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Picker("Serving size", selection: $selectedServing) {
                        ForEach(servingUnits, id: \.self) { Text($0).tag($0) }
                        Text("Custom…").tag("Custom…")
                    }
                    .onChange(of: selectedServing) { _, val in showCustom = (val == "Custom…") }
                    if showCustom {
                        TextField("e.g. 1 cup, 30g", text: $customServing)
                    }
                }
                Section("Nutrition (scaled)") {
                    NutritionInfoRow(label: "Calories", value: "\(scaledCalories) kcal")
                    NutritionInfoRow(label: "Protein",  value: String(format: "%.1fg", scaledProtein))
                    NutritionInfoRow(label: "Carbs",    value: String(format: "%.1fg", scaledCarbs))
                    NutritionInfoRow(label: "Fat",      value: String(format: "%.1fg", scaledFat))
                }
                Section {
                    Button(role: .destructive) {
                        onDelete(entry); dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Entry", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let qtyStr = quantity.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(quantity))" : String(format: "%.1f", quantity)
                        entry.name        = name.trimmingCharacters(in: .whitespaces)
                        entry.calories    = scaledCalories
                        entry.protein     = scaledProtein
                        entry.carbs       = scaledCarbs
                        entry.fat         = scaledFat
                        entry.servingSize = quantity == 1 ? displayServing : "\(qtyStr) × \(displayServing)"
                        entry.mealType    = mealType
                        onSave(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct NutritionInfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

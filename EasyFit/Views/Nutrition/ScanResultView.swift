import SwiftUI
import UIKit

// MARK: - Scan result editor
//
// Shows every detected food as an editable row. The happy path stays one
// tap — if the scan is right, "Add to <meal>" logs all items at once.
// Editing is always available, never required: tap a row to correct the
// name (with live database search), portion, or serving, or remove it;
// "Add item" appends something the AI missed. Totals recompute live.

struct ScanResultView: View {
    let image: UIImage
    let initialItems: [FoodScanItem]
    let onSave:   ([FoodEntry]) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var items: [FoodItemDraft]
    @State private var mealType: MealType
    @State private var editingItem: FoodItemDraft? = nil
    @State private var addingItem = false

    init(
        image: UIImage,
        initialItems: [FoodScanItem],
        suggestedMeal: MealType = .lunch,
        onSave: @escaping ([FoodEntry]) -> Void,
        onRetake: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image = image
        self.initialItems = initialItems
        self.onSave = onSave
        self.onRetake = onRetake
        self.onCancel = onCancel
        _items = State(initialValue: initialItems.map { FoodItemDraft(item: $0) })
        _mealType = State(initialValue: suggestedMeal)
    }

    private var totalCalories: Int    { items.reduce(0) { $0 + $1.calories } }
    private var totalProtein:  Double { items.reduce(0) { $0 + $1.protein } }
    private var totalCarbs:    Double { items.reduce(0) { $0 + $1.carbs } }
    private var totalFat:      Double { items.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    totalsCard

                    // Item rows
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            Button { editingItem = item } label: {
                                ScanItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                        addItemRow
                    }
                    .padding(.horizontal)

                    mealCard

                    VStack(spacing: 10) {
                        Button { commit() } label: {
                            Text(items.count > 1 ? "Add \(items.count) items to \(mealType.rawValue)" : "Add to \(mealType.rawValue)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(items.isEmpty ? MochiTheme.surface : MochiTheme.primary)
                                .foregroundStyle(items.isEmpty ? MochiTheme.textSecondary : MochiTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: MochiTheme.buttonRadius))
                        }
                        .disabled(items.isEmpty)

                        Button { onRetake() } label: {
                            Text("Retake")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(MochiTheme.surfaceAlt)
                                .foregroundStyle(MochiTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: MochiTheme.buttonRadius))
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 24)
                }
            }
            .background(MochiTheme.background)
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onCancel() } }
            }
            .sheet(item: $editingItem) { item in
                FoodItemEditSheet(
                    draft: item,
                    onSave: { updated in
                        if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                            withAnimation(.easeOut(duration: 0.2)) { items[idx] = updated }
                        }
                    },
                    onDelete: {
                        withAnimation(.easeOut(duration: 0.2)) { items.removeAll { $0.id == item.id } }
                    }
                )
            }
            .sheet(isPresented: $addingItem) {
                FoodItemEditSheet(
                    draft: .empty(),
                    startInSearch: true,
                    allowDelete: false,
                    onSave: { newItem in
                        withAnimation(.easeOut(duration: 0.2)) { items.append(newItem) }
                    }
                )
            }
        }
    }

    // MARK: Pieces

    private var totalsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Total").font(.system(size: 15, weight: .medium)).foregroundStyle(MochiTheme.textSecondary)
                Spacer()
                Text("\(totalCalories)").font(.system(size: 26, weight: .bold)).foregroundStyle(MochiTheme.textPrimary)
                Text("kcal").font(.system(size: 12)).foregroundStyle(MochiTheme.textSecondary)
            }
            .padding(16)
            Divider().padding(.horizontal)
            HStack(spacing: 0) {
                MacroCell(label: "Protein", value: totalProtein, color: MochiTheme.success)
                Divider().frame(height: 40)
                MacroCell(label: "Carbs",   value: totalCarbs,   color: MochiTheme.warning)
                Divider().frame(height: 40)
                MacroCell(label: "Fat",     value: totalFat,     color: MochiTheme.accent)
            }
            .padding(.vertical, 8)
        }
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
        .padding(.horizontal)
        .animation(.easeOut(duration: 0.25), value: totalCalories)
    }

    private var addItemRow: some View {
        Button { addingItem = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MochiTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(MochiTheme.primary.opacity(0.15))
                    .clipShape(Circle())
                Text("Add an item")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MochiTheme.textSecondary)
                Spacer()
            }
            .padding(14)
            .background(MochiTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private var mealCard: some View {
        HStack {
            Text("Meal").font(.system(size: 15, weight: .medium))
            Spacer()
            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
        .padding(.horizontal)
    }

    private func commit() {
        let entries = items.map { d in
            FoodEntry(
                name: d.name, calories: d.calories,
                protein: d.protein, carbs: d.carbs, fat: d.fat,
                servingSize: d.servingSize, mealType: mealType
            )
        }
        onSave(entries)
    }
}

// MARK: - Item row

private struct ScanItemRow: View {
    let item: FoodItemDraft
    private var lowConfidence: Bool { item.calories > 0 && false }  // confidence lives on FoodScanItem; drafts drop it once edited

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.isEmpty ? "Untitled" : item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MochiTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(item.calories) kcal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MochiTheme.primary)
                    Text("·").foregroundStyle(MochiTheme.textSecondary)
                    Text(item.servingSize)
                        .font(.system(size: 13))
                        .foregroundStyle(MochiTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                ItemMiniChip(label: "P", value: Int(item.protein), color: MochiTheme.success)
                ItemMiniChip(label: "C", value: Int(item.carbs),   color: MochiTheme.warning)
                ItemMiniChip(label: "F", value: Int(item.fat),     color: MochiTheme.accent)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(MochiTheme.textSecondary.opacity(0.6))
        }
        .padding(14)
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
    }
}

private struct ItemMiniChip: View {
    let label: String; let value: Int; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text("\(value)g").font(.system(size: 9)).foregroundStyle(MochiTheme.textSecondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct MacroCell: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fg", value)).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            Text(label).font(.system(size: 11)).foregroundStyle(MochiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}

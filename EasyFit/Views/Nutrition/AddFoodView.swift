import SwiftUI

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let onSave: (FoodEntry) -> Void

    @State private var name        = ""
    @State private var calories    = ""
    @State private var protein     = ""
    @State private var carbs       = ""
    @State private var fat         = ""
    @State private var servingSize = ""

    var isValid: Bool {
        !name.isEmpty && Int(calories) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Serving size (e.g. 200g)", text: $servingSize)
                }
                Section("Calories") {
                    TextField("kcal", text: $calories)
                        .keyboardType(.numberPad)
                }
                Section("Macros (optional)") {
                    HStack {
                        Text("Protein"); Spacer()
                        TextField("g", text: $protein).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Carbs"); Spacer()
                        TextField("g", text: $carbs).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Fat"); Spacer()
                        TextField("g", text: $fat).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
            }
            .navigationTitle(mealType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let entry = FoodEntry(
                            name:        name,
                            calories:    Int(calories) ?? 0,
                            protein:     Double(protein) ?? 0,
                            carbs:       Double(carbs)   ?? 0,
                            fat:         Double(fat)     ?? 0,
                            servingSize: servingSize.isEmpty ? "1 serving" : servingSize,
                            mealType:    mealType,
                            isCustom:    true
                        )
                        SearchHistoryService.shared.record(foodName: name)
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    AddFoodView(mealType: .lunch) { _ in }
}

import SwiftUI
import Charts

struct FitProgressView: View {
    @StateObject private var vm = FitProgressViewModel.preview()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Body weight card
                    ProgressCard(title: "Body Weight") {
                        if let latest = vm.latestWeight {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", latest.weight))
                                    .font(.system(size: 32, weight: .semibold))
                                Text(latest.unit.rawValue)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let delta = vm.weightThisMonth {
                                    Text(String(format: "%+.1f lb this month", delta))
                                        .font(.system(size: 13))
                                        .foregroundStyle(delta < 0 ? .green : .red)
                                }
                            }
                        }

                        if #available(iOS 16.0, *) {
                            Chart(vm.last7DaysEntries) { entry in
                                LineMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Weight", entry.weight)
                                )
                                .interpolationMethod(.catmullRom)
                                PointMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Weight", entry.weight)
                                )
                            }
                            .frame(height: 120)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                }
                            }
                        }
                    }

                    // Log weight button
                    Button {
                        vm.showAddWeight = true
                    } label: {
                        Label("Log weight", systemImage: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $vm.showAddWeight) {
                AddWeightView { entry in
                    vm.addWeight(entry)
                }
            }
        }
    }
}

struct ProgressCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AddWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    let onSave: (BodyWeightEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Body weight") {
                    TextField("e.g. 174.5", text: $weightText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let w = Double(weightText) {
                            onSave(BodyWeightEntry(weight: w))
                        }
                        dismiss()
                    }
                    .disabled(Double(weightText) == nil)
                }
            }
        }
    }
}

#Preview { FitProgressView() }

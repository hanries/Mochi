import SwiftUI
import SwiftData

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse)        private var allEntries:  [FoodEntry]
    @Query(sort: \BodyWeightEntry.date, order: .reverse)  private var weightEntries: [BodyWeightEntry]

    @StateObject private var vm         = NutritionViewModel()
    @StateObject private var progressVm = FitProgressViewModel()
    @State private var showAddWeight    = false
    @State private var selectedMonth    = Date.now

    private let cal = Calendar.current

    // MARK: - Streak

    var currentStreak: Int { progressVm.currentStreak(from: weightEntries) }
    var longestStreak: Int { progressVm.longestStreak(from: weightEntries) }

    // MARK: - Calendar data

    private var daysInMonth: [Date?] {
        let start        = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth))!
        let range        = cal.range(of: .day, in: .month, for: start)!
        let firstWeekday = cal.component(.weekday, from: start) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            days.append(cal.date(byAdding: .day, value: day - 1, to: start))
        }
        return days
    }

    private let weekdaySymbols = ["S","M","T","W","T","F","S"]
    private let calColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    func caloriesForDate(_ date: Date) -> Int {
        allEntries
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.calories }
    }

    func goalMetForDate(_ date: Date) -> Bool {
        caloriesForDate(date) >= vm.goal.calories
    }

    // MARK: - Weight chart

    var last30DaysWeight: [BodyWeightEntry] {
        progressVm.last30Days(from: weightEntries)
    }

    var weightDelta: Double? {
        progressVm.weightDelta(from: weightEntries)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Streak
                    HStack(spacing: 0) {
                        StreakCell(
                            value:    currentStreak,
                            label:    "day streak",
                            icon:     "flame.fill",
                            iconColor: currentStreak >= 3 ? .orange : .secondary
                        )
                        Divider().frame(height: 60)
                        StreakCell(
                            value:    longestStreak,
                            label:    "best streak",
                            icon:     "trophy.fill",
                            iconColor: .yellow
                        )
                    }
                    .padding(.vertical, 16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // MARK: - Calorie Calendar
                    VStack(alignment: .leading, spacing: 14) {
                        // Month nav
                        HStack {
                            Button {
                                selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth)!
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Button {
                                if !cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month) {
                                    selectedMonth = cal.date(byAdding: .month, value: 1, to: selectedMonth)!
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(
                                        cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
                                        ? Color.secondary.opacity(0.3) : Color.primary
                                    )
                            }
                            .disabled(cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month))
                        }

                        // Weekday headers
                        HStack(spacing: 0) {
                            ForEach(weekdaySymbols.indices, id: \.self) { i in
                                Text(weekdaySymbols[i])
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Day grid
                        LazyVGrid(columns: calColumns, spacing: 8) {
                            ForEach(daysInMonth.indices, id: \.self) { i in
                                if let date = daysInMonth[i] {
                                    CalendarDayCell(
                                        date:        date,
                                        calories:    caloriesForDate(date),
                                        goalMet:     goalMetForDate(date),
                                        isToday:     cal.isDateInToday(date),
                                        isFuture:    date > .now,
                                        calorieGoal: vm.goal.calories
                                    )
                                } else {
                                    Color.clear.frame(height: 40)
                                }
                            }
                        }

                        // Legend
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.6, blue: 0.0))
                                    .frame(width: 10, height: 10)
                                Text("Goal met").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                Text("Logged").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // MARK: - Weight Progress
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Body Weight")
                                    .font(.system(size: 15, weight: .semibold))
                                if let delta = weightDelta {
                                    Text(String(format: "%+.1f lb this month", delta))
                                        .font(.system(size: 12))
                                        .foregroundStyle(delta <= 0 ? .green : .red)
                                }
                            }
                            Spacer()
                            if let latest = weightEntries.first {
                                Text(String(format: "%.1f %@", latest.weight, latest.unit.rawValue))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            Button {
                                showAddWeight = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.primary)
                            }
                        }

                        if last30DaysWeight.isEmpty {
                            Text("Log your weight to see progress")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 30)
                        } else {
                            LineGraph(
                                entries: last30DaysWeight,
                                minW:    (last30DaysWeight.map(\.weight).min() ?? 170) - 2,
                                maxW:    (last30DaysWeight.map(\.weight).max() ?? 180) + 2
                            )
                            .frame(height: 120)

                            if last30DaysWeight.count > 1 {
                                HStack {
                                    Text(last30DaysWeight.first!.date,
                                         format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(last30DaysWeight.last!.date,
                                         format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddWeight) {
                AddWeightView { entry in context.insert(entry) }
            }
        }
    }
}

// MARK: - Streak Cell

private struct StreakCell: View {
    let value:     Int
    let label:     String
    let icon:      String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .padding(.top, 6)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Day Cell (Apple Fitness style)

private struct CalendarDayCell: View {
    let date:        Date
    let calories:    Int
    let goalMet:     Bool
    let isToday:     Bool
    let isFuture:    Bool
    let calorieGoal: Int

    private var day: Int { Calendar.current.component(.day, from: date) }

    private var progress: Double {
        guard calorieGoal > 0, calories > 0 else { return 0 }
        return min(Double(calories) / Double(calorieGoal), 1.0)
    }

    var body: some View {
        ZStack {
            // Full ring when goal met (Apple Fitness style)
            if goalMet {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.7, blue: 0.0),
                                     Color(red: 1.0, green: 0.45, blue: 0.0)],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.orange.opacity(0.4), radius: 4, x: 0, y: 2)
            } else if calories > 0 {
                // Partial ring for partial logging
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 1.0, green: 0.6, blue: 0.0),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
            } else if isToday {
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
            }

            Text("\(day)")
                .font(.system(size: 13, weight: goalMet || isToday ? .bold : .regular))
                .foregroundStyle(
                    goalMet ? .white :
                    isFuture ? Color.secondary.opacity(0.3) :
                    .primary
                )
        }
        .frame(height: 40)
    }
}

// MARK: - Add Weight Sheet (reused from FitProgressView)

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
                        if let w = Double(weightText) { onSave(BodyWeightEntry(weight: w)) }
                        dismiss()
                    }
                    .disabled(Double(weightText) == nil).fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: [FoodEntry.self, BodyWeightEntry.self], inMemory: true)
}

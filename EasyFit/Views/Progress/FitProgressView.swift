import SwiftUI
import SwiftData

struct FitProgressView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date) private var allEntries: [BodyWeightEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]

    @StateObject private var vm = FitProgressViewModel()
    @State private var showAddJournal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StreakCard(
                        streak:        vm.currentStreak(from: allEntries),
                        longestStreak: vm.longestStreak(from: allEntries)
                    )
                    LogCalendarView(loggedDates: vm.loggedDates(from: allEntries))
                    WeightGraphCard(
                        entries: vm.last30Days(from: allEntries),
                        delta:   vm.weightDelta(from: allEntries)
                    )

                    JournalCalendarView(
                        journalEntries: journalEntries,
                        onAddEntry:     { showAddJournal = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.showAddWeight = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $vm.showAddWeight) {
                AddWeightView { entry in
                    context.insert(entry)
                }
            }
            .sheet(isPresented: $showAddJournal) {
                AddJournalEntryView()
            }
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let streak: Int
    let longestStreak: Int

    var flameColor: Color {
        streak >= 7 ? .orange : streak >= 3 ? Color(red: 1, green: 0.6, blue: 0.2) : .secondary
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(flameColor)
                        .padding(.top, 8)
                }
                Text("day streak")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 60)

            VStack(spacing: 6) {
                Text("\(longestStreak)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("best streak")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Log Calendar

struct LogCalendarView: View {
    let loggedDates: Set<DateComponents>

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["S","M","T","W","T","F","S"]

    private var currentMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
    }
    private var daysInMonth: [Date?] {
        let range        = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstWeekday = calendar.component(.weekday, from: currentMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: currentMonth))
        }
        return days
    }
    private var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    func isLogged(_ date: Date) -> Bool {
        loggedDates.contains(calendar.dateComponents([.year, .month, .day], from: date))
    }
    func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(monthTitle).font(.system(size: 15, weight: .semibold))

            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth.indices, id: \.self) { i in
                    CalendarDayCell(
                        date:     daysInMonth[i],
                        isLogged: daysInMonth[i].map { isLogged($0) } ?? false,
                        isToday:  daysInMonth[i].map { isToday($0)  } ?? false,
                        day:      daysInMonth[i].map { calendar.component(.day, from: $0) } ?? 0
                    )
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct CalendarDayCell: View {
    let date: Date?
    let isLogged: Bool
    let isToday: Bool
    let day: Int

    var body: some View {
        if date != nil {
            ZStack {
                Circle()
                    .fill(isLogged ? Color.primary : isToday ? Color.primary.opacity(0.08) : Color.clear)
                Text("\(day)")
                    .font(.system(size: 13, weight: isLogged || isToday ? .semibold : .regular))
                    .foregroundStyle(isLogged ? Color(uiColor: .systemBackground) : .primary)
            }
            .frame(height: 34)
        } else {
            Color.clear.frame(height: 34)
        }
    }
}

// MARK: - Weight Graph Card

struct WeightGraphCard: View {
    let entries: [BodyWeightEntry]
    let delta: Double?

    private var minW: Double { (entries.map(\.weight).min() ?? 170) - 2 }
    private var maxW: Double { (entries.map(\.weight).max() ?? 180) + 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight").font(.system(size: 15, weight: .semibold))
                    if let d = delta {
                        Text(String(format: "%+.1f lb this month", d))
                            .font(.system(size: 12))
                            .foregroundStyle(d <= 0 ? .green : .red)
                    }
                }
                Spacer()
                if let latest = entries.last?.weight {
                    Text(String(format: "%.1f lb", latest))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }

            if entries.isEmpty {
                Text("Log your weight to see the graph")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                LineGraph(entries: entries, minW: minW, maxW: maxW)
                    .frame(height: 120)
            }

            if entries.count > 1 {
                HStack {
                    Text(entries.first!.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text(entries.last!.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Line Graph

struct LineGraph: View {
    let entries: [BodyWeightEntry]
    let minW: Double
    let maxW: Double

    var body: some View {
        GeometryReader { geo in
            LineGraphCanvas(entries: entries, minW: minW, maxW: maxW, size: geo.size)
        }
    }
}

private struct LineGraphCanvas: View {
    let entries: [BodyWeightEntry]
    let minW: Double
    let maxW: Double
    let size: CGSize

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var range: Double { maxW - minW }

    private func xPos(for i: Int) -> CGFloat {
        entries.count < 2 ? w / 2 : CGFloat(i) / CGFloat(entries.count - 1) * w
    }
    private func yPos(for weight: Double) -> CGFloat {
        h - CGFloat((weight - minW) / range) * h
    }
    private var points: [CGPoint] {
        entries.indices.map { CGPoint(x: xPos(for: $0), y: yPos(for: entries[$0].weight)) }
    }
    private var gridLineYs: [CGFloat] {
        (0..<4).map { h * CGFloat($0) / 3 }
    }

    var body: some View {
        ZStack {
            ForEach(gridLineYs.indices, id: \.self) { i in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: gridLineYs[i]))
                    p.addLine(to: CGPoint(x: w, y: gridLineYs[i]))
                }
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            }
            if points.count > 1 {
                Path { p in
                    p.move(to: CGPoint(x: points[0].x, y: h))
                    p.addLine(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: points.last!.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            if points.count > 1 {
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let last = points.last {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
                    .position(last)
            }
        }
    }
}

// MARK: - Add Weight Sheet

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
    FitProgressView()
        .modelContainer(for: BodyWeightEntry.self, inMemory: true)
}

import SwiftUI
import SwiftData

struct LogView: View {
    @State private var selectedSegment: LogSegment = .progress

    enum LogSegment: String, CaseIterable {
        case progress = "Progress"
        case journal  = "Photo Journal"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MochiTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: MochiTheme.Spacing.sm) {
                        Text("Log")
                            .font(MochiTheme.largeTitle)
                            .foregroundStyle(MochiTheme.textPrimary)

                        // Segmented picker
                        HStack(spacing: 8) {
                            ForEach(LogSegment.allCases, id: \.self) { seg in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedSegment = seg
                                    }
                                } label: {
                                    Text(seg.rawValue)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 9)
                                        .background(selectedSegment == seg ? MochiTheme.primary : MochiTheme.surface)
                                        .foregroundStyle(selectedSegment == seg ? MochiTheme.surfaceAlt : MochiTheme.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    // Content swap
                    switch selectedSegment {
                    case .progress: ProgressContent()
                    case .journal:  JournalContent()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Progress segment

private struct ProgressContent: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var mochi: MochiViewModel
    @Query(sort: \BodyWeightEntry.date) private var allEntries: [BodyWeightEntry]
    @StateObject private var vm = FitProgressViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Prominent weight-logging entry point
                Button {
                    vm.showAddWeight = true
                } label: {
                    HStack(spacing: MochiTheme.Spacing.lg) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MochiTheme.primary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(MochiTheme.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log weight")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(MochiTheme.textPrimary)
                            Text("A quick check-in — takes two seconds")
                                .font(MochiTheme.caption)
                                .foregroundStyle(MochiTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(MochiTheme.primary)
                    }
                    .padding(MochiTheme.Spacing.lg)
                    .mochiCard()
                }
                .buttonStyle(.plain)

                StreakCard(
                    streak:        vm.currentStreak(from: allEntries),
                    longestStreak: vm.longestStreak(from: allEntries)
                )
                LogCalendarView(loggedDates: vm.loggedDates(from: allEntries))
                WeightGraphCard(
                    entries: vm.last30Days(from: allEntries),
                    delta:   vm.weightDelta(from: allEntries)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
                mochi.weightLogged()   // valueless by design — golden rule
            }
        }
    }
}

// MARK: - Journal segment

private struct JournalContent: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var mochi: MochiViewModel
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var showCamera     = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var selectedMonth  = Date.now

    /// yyyy-MM-dd of the day the prompt was dismissed; hides it until tomorrow.
    @AppStorage("journalPromptDismissedDay") private var promptDismissedDay = ""

    private let cal     = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S","M","T","W","T","F","S"]

    private var monthEntries: [JournalEntry] {
        entries.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

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

    func entriesForDate(_ date: Date) -> [JournalEntry] {
        entries.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var hasPhotoToday: Bool {
        entries.contains { cal.isDateInToday($0.date) }
    }

    private var todayKey: String {
        Date.now.formatted(.iso8601.year().month().day())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // Daily prompt — once per day at most, celebrates consistency
                // only (never appearance, body, progress, or results).
                if hasPhotoToday {
                    HStack(spacing: MochiTheme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MochiTheme.success)
                        Text("Photo added today")
                            .font(MochiTheme.caption)
                            .foregroundStyle(MochiTheme.textSecondary)
                        Spacer()
                        Button { showCamera = true } label: {
                            Label("Add another", systemImage: "plus")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(MochiTheme.primary)
                        }
                    }
                    .padding(.horizontal, MochiTheme.Spacing.lg)
                    .padding(.vertical, MochiTheme.Spacing.md)
                    .mochiCard(cornerRadius: 14)
                    .padding(.horizontal)
                } else if promptDismissedDay != todayKey {
                    HStack(spacing: MochiTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: MochiTheme.Spacing.xs) {
                            Text("You showed up today — want to add a photo?")
                                .font(MochiTheme.body)
                                .foregroundStyle(MochiTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button { showCamera = true } label: {
                                Label("Take a photo", systemImage: "camera.fill")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MochiTheme.primary)
                            }
                        }
                        Spacer()
                        Button { promptDismissedDay = todayKey } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MochiTheme.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(MochiTheme.surface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Dismiss for today")
                    }
                    .padding(MochiTheme.Spacing.lg)
                    .mochiCard()
                    .padding(.horizontal)
                }

                // Month navigator
                HStack {
                    Button {
                        selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth)!
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(MochiTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button {
                        selectedMonth = cal.date(byAdding: .month, value: 1, to: selectedMonth)!
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(MochiTheme.surface)
                            .clipShape(Circle())
                    }
                    .disabled(cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month))
                    .opacity(cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month) ? 0.3 : 1)
                }
                .padding(.horizontal)

                // Calendar grid
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        ForEach(weekdaySymbols.indices, id: \.self) { i in
                            Text(weekdaySymbols[i])
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(MochiTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(daysInMonth.indices, id: \.self) { i in
                            if let date = daysInMonth[i] {
                                JournalDayCell(
                                    date:    date,
                                    entries: entriesForDate(date),
                                    isToday: cal.isDateInToday(date)
                                )
                                .onTapGesture {
                                    if let entry = entriesForDate(date).first {
                                        selectedEntry = entry
                                    }
                                }
                            } else {
                                Color.clear.frame(height: 50)
                            }
                        }
                    }
                }
                .padding(16)
                .mochiCard()
                .padding(.horizontal)

                // Entry count
                if !monthEntries.isEmpty {
                    HStack {
                        Text("\(monthEntries.count) entr\(monthEntries.count == 1 ? "y" : "ies") this month")
                            .font(.system(size: 13))
                            .foregroundStyle(MochiTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Photo grid
                if !entries.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 3
                    ) {
                        // Always-present add tile — log as many photos a day as you like.
                        Button { showCamera = true } label: {
                            ZStack {
                                Rectangle().fill(MochiTheme.surface)
                                VStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 26, weight: .semibold))
                                    Text("Add").font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(MochiTheme.primary)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        ForEach(entries) { entry in
                            JournalGridCell(entry: entry)
                                .onTapGesture { selectedEntry = entry }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(MochiTheme.textSecondary)
                        Text("No photos yet")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(MochiTheme.textPrimary)
                        Text("Add a photo when you feel like it — a little memory of showing up today.")
                            .font(.system(size: 14))
                            .foregroundStyle(MochiTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 60)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCamera = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            JournalCameraView(
                onSave: { images, note in
                    let entry = JournalEntry(
                        date:       .now,
                        note:       note,
                        imageDatas: images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                    )
                    context.insert(entry)
                    mochi.photoLogged()   // Mochi jumps for joy you checked in
                },
                onDismiss: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack { JournalDetailView(entry: entry) }
        }
    }
}

#Preview {
    LogView()
        .modelContainer(for: [BodyWeightEntry.self, JournalEntry.self], inMemory: true)
}

import SwiftUI
import SwiftData
import Combine

// MARK: - Mochi's home: the app's main screen
//
// Mochi front and center in a calm habitat; the calorie/macro summary is a
// compact secondary card. Mochi's mood comes from MochiViewModel and is
// driven by engagement only.

struct MochiHomeView: View {
    // Hidden while the guided tour is leading (its own Mochi stands in), so
    // there's never two Mochis; revealed at the tour's closing hand-off.
    var hideCharacter: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var mochi: MochiViewModel
    @EnvironmentObject private var paywall: PaywallCoordinator
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var weightEntries: [BodyWeightEntry]
    @StateObject private var vm = NutritionViewModel()
    @AppStorage("userName") private var userName = ""
    @AppStorage("pendingFirstLog") private var pendingFirstLog = false

    @State private var showFoodCamera  = false
    @State private var showNutrition   = false
    @State private var showSearchPanel = false

    // Dialogue bubble — persistent; re-rolled on state change, tap, or moment
    @State private var bubbleLine: String = ""

    // Post-log moment bookkeeping
    @State private var momentClearTask: Task<Void, Never>? = nil

    // First-log walkthrough hint
    @State private var hintPulse = false

    // Habitat day/night
    @State private var isNightHabitat = false

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var activeMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    var body: some View {
        ZStack(alignment: .top) {
            MochiTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Scene flexes to fill all space above the fixed bottom
                // stack; the room is bottom-anchored so the rug stays
                // visible at every height.
                habitatArea

                // Primary action — fixed 24pt below the scene's fade
                Button {
                    if paywall.requestScan() { showFoodCamera = true }
                } label: {
                    HStack(spacing: MochiTheme.Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Feed Mochi · log a meal")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(MochiTheme.surfaceAlt)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MochiTheme.Spacing.lg)
                    .background(MochiTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: MochiTheme.buttonRadius))
                }
                .scaleEffect(hintPulse ? 1.04 : 1.0)
                .animation(
                    pendingFirstLog
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: hintPulse
                )
                .padding(.horizontal, MochiTheme.Spacing.xl)
                .padding(.top, MochiTheme.Spacing.xl)

                // Quota counter — interface voice, calm, free tier only
                if let counter = paywall.remainingScansText {
                    Text(counter)
                        .font(MochiTheme.caption)
                        .foregroundStyle(MochiTheme.textSecondary)
                        .padding(.top, MochiTheme.Spacing.sm)
                }

                Button {
                    showSearchPanel = true
                } label: {
                    HStack(spacing: MochiTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                        Text("More ways to log")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(MochiTheme.primary)
                    .padding(.horizontal, MochiTheme.Spacing.lg)
                    .padding(.vertical, MochiTheme.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(MochiTheme.surfaceAlt)
                            .overlay(
                                Capsule().strokeBorder(MochiTheme.primary.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .padding(.top, MochiTheme.Spacing.sm)

                CompactCalorieCard(
                    consumed: vm.totalCalories(from: allEntries),
                    goal:     vm.goal.calories,
                    protein:  vm.totalProtein(from: allEntries),
                    carbs:    vm.totalCarbs(from: allEntries),
                    fat:      vm.totalFat(from: allEntries)
                )
                .padding(.horizontal, MochiTheme.Spacing.xl)
                .padding(.bottom, MochiTheme.Spacing.lg)
                .onTapGesture { showNutrition = true }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            mochi.refresh(entries: allEntries, weightLogDates: weightEntries.map(\.date))
            refreshHabitat(animated: false)
            if let moment = mochi.moment {
                // A moment fired on another tab redirected us Home — play it,
                // since onChange won't fire for a value set before we appeared.
                playMoment(moment)
            } else if pendingFirstLog {
                hintPulse = true
                showBubble("I can't wait to see your first meal! 🐹")
            } else if bubbleLine.isEmpty {
                bubbleLine = mochi.dialogueLine()
            }
        }
        .onChange(of: mochi.state) { _, _ in
            showBubble(mochi.dialogueLine())
            refreshHabitat()
        }
        .onChange(of: allEntries) { _, entries in
            mochi.refresh(entries: entries, weightLogDates: weightEntries.map(\.date))
            if pendingFirstLog && !entries.isEmpty {
                pendingFirstLog = false
                hintPulse = false
            }
        }
        .onChange(of: mochi.moment) { _, moment in
            guard let moment else { return }
            playMoment(moment)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                mochi.refresh(entries: allEntries, weightLogDates: weightEntries.map(\.date))
                refreshHabitat()
            }
        }
        .onReceive(refreshTimer) { _ in
            mochi.refresh(entries: allEntries, weightLogDates: weightEntries.map(\.date))
            refreshHabitat()
        }
        .fullScreenCover(isPresented: $showFoodCamera) {
            FoodCameraView(
                suggestedMeal: activeMeal,
                onSave: { entries in
                    entries.forEach { context.insert($0) }
                    mochi.mealLogged()   // one celebration per save, not per item
                },
                onDismiss: { showFoodCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNutrition) {
            NutritionView()
                        }
        .sheet(isPresented: $showSearchPanel) {
            SearchLogPanel(activeMeal: activeMeal)
                        }
    }

    // MARK: - Habitat scene

    /// Mochi's width as a fraction of screen width.
    private let mochiWidthRatio: CGFloat = 0.62

    private var habitatArea: some View {
        GeometryReader { geo in
            let width      = geo.size.width
            let height     = geo.size.height
            let topInset   = geo.safeAreaInsets.top
            let mochiSize  = width * mochiWidthRatio
            // Derived from the habitat image's own geometry so his feet
            // land on the rug at every device size.
            let rugCenterY = MochiHabitatScene.rugCenterY(sceneWidth: width, sceneHeight: height)

            ZStack(alignment: .topTrailing) {
                MochiHabitatScene(isNight: isNightHabitat)

                // Mochi seated on the rug, shadow under his feet
                if !hideCharacter {
                    MochiView(state: mochi.state,
                              moment: mochi.moment,
                              size: mochiSize,
                              showShadow: true) { reaction in
                        // Match the bubble to the reaction Mochi just played.
                        if let reaction {
                            showBubble(MochiDialogue.line(for: reaction))
                        } else {
                            showBubble(mochi.dialogueLine())
                        }
                    }
                    .position(x: width / 2, y: rugCenterY - mochiSize / 2)

                    // Speech bubble above his head — always present, clamped
                    // below the status bar on small screens.
                    if !bubbleLine.isEmpty {
                        MochiSpeechBubble(text: bubbleLine)
                            .id(bubbleLine)
                            .position(x: width / 2,
                                      y: max(topInset + 40, rugCenterY - mochiSize - 36))
                            .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                    }
                }

            // Streak chip floats top-right of the scene
            if mochi.streak >= 1 {
                HStack(spacing: MochiTheme.Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MochiTheme.warning)
                    Text("\(mochi.streak) day\(mochi.streak == 1 ? "" : "s")")
                        .font(MochiTheme.caption)
                        .foregroundStyle(MochiTheme.textPrimary)
                }
                .padding(.horizontal, MochiTheme.Spacing.md)
                .padding(.vertical, MochiTheme.Spacing.sm)
                .background(MochiTheme.surfaceAlt)
                .clipShape(Capsule())
                .padding(.top, topInset + MochiTheme.Spacing.sm)
                .padding(.trailing, MochiTheme.Spacing.lg)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(mochi.streak) day streak")
                }
            }
            .frame(width: width, height: height)
        }
    }

    private func showBubble(_ line: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbleLine = line
        }
    }

    /// Show a moment's line, then clear the moment and return to a normal
    /// dialogue line after it plays. Called from both onChange and onAppear
    /// (the latter covers moments fired on another tab that redirect Home).
    private func playMoment(_ moment: MochiMoment) {
        showBubble(moment.line)
        momentClearTask?.cancel()
        momentClearTask = Task {
            try? await Task.sleep(for: .seconds(MochiMotion.default.momentDuration))
            guard !Task.isCancelled else { return }
            mochi.moment = nil
            showBubble(mochi.dialogueLine())
        }
    }

    /// Night room between 19:00 and 06:30 local time, or whenever Mochi is
    /// sleepy. Thresholds live in MochiMotion.
    private func refreshHabitat(now: Date = .now, animated: Bool = true) {
        let motion = MochiMotion.default
        let cal = Calendar.current
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let inNightWindow = minutes >= motion.habitatNightStartMinutes
                         || minutes < motion.habitatDayStartMinutes
        let night = mochi.state == .sleepy || inNightWindow

        guard night != isNightHabitat else { return }
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: motion.habitatCrossfade)) {
                isNightHabitat = night
            }
        } else {
            isNightHabitat = night
        }
    }
}

// MARK: - Speech bubble

private struct MochiSpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(MochiTheme.body)
                .foregroundStyle(MochiTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MochiTheme.Spacing.lg)
                .padding(.vertical, MochiTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(MochiTheme.surfaceAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(MochiTheme.textSecondary.opacity(0.25), lineWidth: 1)
                        )
                )

            BubbleTail()
                .fill(MochiTheme.surfaceAlt)
                .frame(width: 14, height: 8)
        }
        .padding(.horizontal, MochiTheme.Spacing.xxl)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Compact calorie / macro summary

private struct CompactCalorieCard: View {
    let consumed: Int
    let goal: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    private var progress: Double {
        min(Double(consumed) / Double(max(goal, 1)), 1.0)
    }

    var body: some View {
        VStack(spacing: MochiTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(consumed)")
                    .font(MochiTheme.title)
                    .foregroundStyle(MochiTheme.textPrimary)
                Text("/ \(goal) kcal")
                    .font(MochiTheme.caption)
                    .foregroundStyle(MochiTheme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MochiTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MochiTheme.surface)
                    Capsule()
                        .fill(MochiTheme.primary)
                        .frame(width: max(geo.size.width * progress, 6))
                }
            }
            .frame(height: 6)

            HStack(spacing: MochiTheme.Spacing.lg) {
                MacroDot(label: "P", value: protein, color: MochiTheme.success)
                MacroDot(label: "C", value: carbs,   color: MochiTheme.warning)
                MacroDot(label: "F", value: fat,     color: MochiTheme.accent)
                Spacer()
            }
        }
        .padding(MochiTheme.Spacing.lg)
        .background(MochiTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: MochiTheme.cardRadius))
        .contentShape(Rectangle())
    }
}

private struct MacroDot: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: MochiTheme.Spacing.xs) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(Int(value))g")
                .font(MochiTheme.caption)
                .foregroundStyle(MochiTheme.textSecondary)
        }
    }
}

#Preview {
    MochiHomeView()
        .environmentObject(MochiViewModel())
        .modelContainer(for: [FoodEntry.self], inMemory: true)
        }

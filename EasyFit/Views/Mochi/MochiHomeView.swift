import SwiftUI
import SwiftData
import Combine

// MARK: - Mochi's home: the app's main screen
//
// Mochi front and center in a calm habitat; the calorie/macro summary is a
// compact secondary card. Mochi's mood comes from MochiViewModel and is
// driven by engagement only.

struct MochiHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var mochi: MochiViewModel
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
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

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var activeMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    /// Habitat scene takes the top ~55% of the screen (plus the status bar
    /// area it extends under).
    private let sceneHeightRatio: CGFloat = 0.55

    var body: some View {
        GeometryReader { geo in
            let sceneHeight = geo.size.height * sceneHeightRatio + geo.safeAreaInsets.top

            ZStack(alignment: .top) {
                MochiTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    sceneArea(width: geo.size.width,
                              height: sceneHeight,
                              topInset: geo.safeAreaInsets.top)

                    Spacer(minLength: MochiTheme.Spacing.lg)

                    // Primary action
                Button {
                    showFoodCamera = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Log a meal")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.teal)
                    .clipShape(Capsule())
                }
                .scaleEffect(hintPulse ? 1.04 : 1.0)
                .animation(
                    pendingFirstLog
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: hintPulse
                )
                .padding(.horizontal, 24)

                Button {
                    showSearchPanel = true
                } label: {
                    Text("More ways to log")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 12)
                }

                    CompactCalorieCard(
                        consumed: vm.totalCalories(from: allEntries),
                        goal:     vm.goal.calories,
                        protein:  vm.totalProtein(from: allEntries),
                        carbs:    vm.totalCarbs(from: allEntries),
                        fat:      vm.totalFat(from: allEntries)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .onTapGesture { showNutrition = true }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .onAppear {
            mochi.refresh(entries: allEntries)
            if pendingFirstLog {
                hintPulse = true
                showBubble("I can't wait to see your first meal! 🐹")
            } else if bubbleLine.isEmpty {
                bubbleLine = mochi.dialogueLine()
            }
        }
        .onChange(of: mochi.state) { _, _ in
            showBubble(mochi.dialogueLine())
        }
        .onChange(of: allEntries) { _, entries in
            mochi.refresh(entries: entries)
            if pendingFirstLog && !entries.isEmpty {
                pendingFirstLog = false
                hintPulse = false
            }
        }
        .onChange(of: mochi.moment) { _, moment in
            guard let moment else { return }
            showBubble(moment.line)
            momentClearTask?.cancel()
            momentClearTask = Task {
                try? await Task.sleep(for: .seconds(MochiMotion.default.momentDuration))
                guard !Task.isCancelled else { return }
                mochi.moment = nil
                showBubble(mochi.dialogueLine())
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { mochi.refresh(entries: allEntries) }
        }
        .onReceive(refreshTimer) { _ in mochi.refresh(entries: allEntries) }
        .fullScreenCover(isPresented: $showFoodCamera) {
            FoodCameraView(
                onResult: { result in
                    context.insert(FoodEntry(
                        name: result.name, calories: result.calories,
                        protein: result.protein, carbs: result.carbs, fat: result.fat,
                        servingSize: result.servingSize, mealType: activeMeal
                    ))
                    mochi.mealLogged()
                },
                onDismiss: { showFoodCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNutrition) {
            NutritionView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showSearchPanel) {
            SearchLogPanel(activeMeal: activeMeal)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Habitat scene

    /// Mochi's feet rest at the vertical center of the rug, which occupies
    /// the lower third of the room illustration.
    private let rugCenterRatio: CGFloat = 0.83
    /// Mochi's width as a fraction of screen width.
    private let mochiWidthRatio: CGFloat = 0.48

    private func sceneArea(width: CGFloat, height: CGFloat, topInset: CGFloat) -> some View {
        let mochiSize  = width * mochiWidthRatio
        let rugCenterY = height * rugCenterRatio

        return ZStack(alignment: .topTrailing) {
            MochiHabitatScene()

            // Mochi seated on the rug, shadow under his feet
            MochiView(state: mochi.state,
                      moment: mochi.moment,
                      size: mochiSize,
                      showShadow: true) {
                showBubble(mochi.dialogueLine())
            }
            .position(x: width / 2, y: rugCenterY - mochiSize / 2)

            // Speech bubble above his head — always present
            if !bubbleLine.isEmpty {
                MochiSpeechBubble(text: bubbleLine)
                    .id(bubbleLine)
                    .position(x: width / 2, y: rugCenterY - mochiSize - 36)
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
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
        .frame(height: height)
    }

    private func showBubble(_ line: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbleLine = line
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
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(consumed)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("/ \(goal) kcal")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardAlt)
                    Capsule()
                        .fill(Theme.teal)
                        .frame(width: max(geo.size.width * progress, 6))
                }
            }
            .frame(height: 6)

            HStack(spacing: 16) {
                MacroDot(label: "P", value: protein, color: Color(red: 0.3, green: 0.71, blue: 0.67))
                MacroDot(label: "C", value: carbs,   color: Color(red: 1.0, green: 0.72, blue: 0.3))
                MacroDot(label: "F", value: fat,     color: Color(red: 0.9, green: 0.35, blue: 0.35))
                Spacer()
            }
        }
        .padding(16)
        .darkCard()
        .contentShape(Rectangle())
    }
}

private struct MacroDot: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(Int(value))g")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    MochiHomeView()
        .environmentObject(MochiViewModel())
        .modelContainer(for: [FoodEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}

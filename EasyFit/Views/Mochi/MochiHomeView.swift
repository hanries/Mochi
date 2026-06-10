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

    @State private var showFoodCamera  = false
    @State private var showNutrition   = false
    @State private var showSearchPanel = false

    // Tap reaction
    @State private var mochiBounce: CGFloat = 1.0
    @State private var bubbleLine: String? = nil
    @State private var bubbleTask: Task<Void, Never>? = nil

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var activeMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userName.isEmpty ? "" : ", \(userName)"
        switch hour {
        case 0..<12:  return "Good morning\(name)"
        case 12..<17: return "Good afternoon\(name)"
        case 17..<21: return "Good evening\(name)"
        default:      return "Hey\(name)"
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Greeting
                Text(greeting)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                habitat

                Spacer()

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
        }
        .onAppear { mochi.refresh(entries: allEntries) }
        .onChange(of: allEntries) { _, entries in mochi.refresh(entries: entries) }
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

    // MARK: - Habitat

    private var habitat: some View {
        VStack(spacing: 0) {
            // Speech bubble (fixed slot so Mochi doesn't shift)
            ZStack {
                if let line = bubbleLine {
                    MochiSpeechBubble(text: line)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                }
            }
            .frame(height: 64)
            .padding(.bottom, 8)

            ZStack {
                // Soft warm glow behind Mochi
                Circle()
                    .fill(MochiAssetProvider.tint(for: mochi.state).opacity(0.12))
                    .frame(width: 240, height: 240)
                    .blur(radius: 30)

                // Ground
                Ellipse()
                    .fill(Theme.cardAlt)
                    .frame(width: 220, height: 56)
                    .offset(y: 88)

                MochiAssetProvider.mochiView(for: mochi.state, size: 170)
                    .scaleEffect(mochiBounce)
                    .onTapGesture { reactToTap() }

                // Streak badge lives with Mochi
                if mochi.streak >= 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(mochi.streak)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.3))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.card)
                    .clipShape(Capsule())
                    .offset(x: 86, y: -72)
                }
            }
            .frame(height: 240)
        }
    }

    private func reactToTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) {
            mochiBounce = 1.18
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                mochiBounce = 1.0
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bubbleLine = mochi.dialogueLine()
        }
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(mochi.config.dialogueDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { bubbleLine = nil }
        }
    }
}

// MARK: - Speech bubble

private struct MochiSpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            BubbleTail()
                .fill(Theme.card)
                .frame(width: 14, height: 8)
        }
        .padding(.horizontal, 32)
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

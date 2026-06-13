import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mochi: MochiViewModel
    @EnvironmentObject var paywall: PaywallCoordinator
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("hasSeenIntroPaywall") private var hasSeenIntroPaywall = false
    @AppStorage("pendingFirstLog") private var pendingFirstLog = false

    @State private var showManualEntryFallback = false

    private let motion = MochiMotion.default

    private var currentMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch appState.selectedTab {
        case .home:    MochiHomeView()
        case .log:     LogView()
        case .workout: WorkoutView()
        case .profile: ProfileView()
        }
    }

    var body: some View {
        selectedTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(appState.selectedTab)
            // A calm cross-fade — no positional slide, so switching feels
            // settled rather than shaky.
            .transition(.opacity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MochiTabBar(selected: $appState.selectedTab)
            }
        // A food log lands the user back home, where Mochi plays the moment.
        // Check-ins (e.g. weight logs) never hijack the current tab.
        .onChange(of: mochi.moment) { _, moment in
            if let moment, moment.kind != .checkIn {
                if reduceMotion {
                    appState.selectedTab = .home
                } else {
                    withAnimation(.easeInOut(duration: motion.tabContentResponse)) {
                        appState.selectedTab = .home
                    }
                }
            }
        }
        // The single paywall presentation point.
        .sheet(item: $paywall.paywallContext) { paywallContext in
            PaywallView(
                context: paywallContext,
                onManualEntry: paywallContext == .scanCap
                    ? { showManualEntryFallback = true }
                    : nil
            )
        }
        // The capped-user escape: manual logging is always one tap away.
        .sheet(isPresented: $showManualEntryFallback) {
            AddFoodView(mealType: currentMeal) { entry in
                context.insert(entry)
                mochi.mealLogged()
            }
        }
        // One soft show for brand-new users only (pendingFirstLog is set by
        // onboarding); plainly closable, never repeated, never on app open.
        .onAppear {
            if pendingFirstLog && !hasSeenIntroPaywall {
                // Only mark it seen if it actually presented — a cooldown
                // suppression shouldn't burn the one-time intro show.
                if paywall.presentPaywall(.onboarding) {
                    hasSeenIntroPaywall = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(MochiViewModel())
        .preferredColorScheme(.dark)
}

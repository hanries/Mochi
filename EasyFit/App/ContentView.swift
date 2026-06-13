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
    // Direction the incoming tab slides from — set in the same transaction as
    // the selection change so the first transition already has it right.
    @State private var slideEdge: Edge = .trailing

    private let motion = MochiMotion.default

    private var currentMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    // Tab bar drives selection through this so we can capture slide direction
    // (old → new index) before the value actually changes.
    private var tabSelection: Binding<AppState.Tab> {
        Binding(
            get: { appState.selectedTab },
            set: { newTab in
                slideEdge = newTab.rawValue >= appState.selectedTab.rawValue ? .trailing : .leading
                appState.selectedTab = newTab
            }
        )
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
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .move(edge: slideEdge).combined(with: .opacity),
                        removal: .opacity)
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MochiTabBar(selected: tabSelection)
            }
        // A food log lands the user back home, where Mochi plays the moment.
        // Check-ins (e.g. weight logs) never hijack the current tab.
        .onChange(of: mochi.moment) { _, moment in
            if let moment, moment.kind != .checkIn {
                slideEdge = .leading   // home is the leftmost tab
                if reduceMotion {
                    appState.selectedTab = .home
                } else {
                    withAnimation(.spring(response: motion.tabContentResponse,
                                          dampingFraction: motion.tabContentDamping)) {
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

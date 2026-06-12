import SwiftUI
import UIKit
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mochi: MochiViewModel
    @EnvironmentObject var paywall: PaywallCoordinator
    @Environment(\.modelContext) private var context

    @AppStorage("hasSeenIntroPaywall") private var hasSeenIntroPaywall = false
    @AppStorage("pendingFirstLog") private var pendingFirstLog = false

    @State private var showManualEntryFallback = false

    private var currentMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    init() {
        // Tab bar: surface background, textSecondary unselected items;
        // the selected state comes from .tint below.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MochiTheme.surface)
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(MochiTheme.textSecondary)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(MochiTheme.textSecondary)]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            MochiHomeView()
                .tabItem { Label("Home", systemImage: "pawprint.fill") }
                .tag(AppState.Tab.home)

            LogView()
                .tabItem { Label("Log", systemImage: "chart.bar.fill") }
                .tag(AppState.Tab.log)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell") }
                .tag(AppState.Tab.workout)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppState.Tab.profile)
        }
        .tint(MochiTheme.primary)
        // A food log lands the user back home, where Mochi plays the moment.
        // Check-ins (e.g. weight logs) never hijack the current tab.
        .onChange(of: mochi.moment) { _, moment in
            if let moment, moment.kind != .checkIn {
                appState.selectedTab = .home
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
                hasSeenIntroPaywall = true
                paywall.presentPaywall(.onboarding)
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

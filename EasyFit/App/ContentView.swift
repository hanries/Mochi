import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mochi: MochiViewModel

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
        .onChange(of: mochi.moment) { _, moment in
            if moment != nil { appState.selectedTab = .home }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(MochiViewModel())
        .preferredColorScheme(.dark)
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mochi: MochiViewModel

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
        .tint(Theme.teal)
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

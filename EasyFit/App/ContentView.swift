import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var mochi: MochiViewModel

    var body: some View {
        ZStack {
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

            if let event = mochi.celebration {
                MochiCelebrationView(
                    event: event,
                    state: mochi.streak >= mochi.config.ecstaticStreak ? .ecstatic : .happy,
                    duration: mochi.config.celebrationDuration,
                    onDone: { mochi.celebration = nil }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: mochi.celebration)
        .onChange(of: mochi.celebration) { _, event in
            if event != nil { appState.selectedTab = .home }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(MochiViewModel())
        .preferredColorScheme(.dark)
}

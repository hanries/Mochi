import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CameraHomeView()
                .tabItem { Label("Home", systemImage: "camera.fill") }
                .tag(AppState.Tab.camera)

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
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

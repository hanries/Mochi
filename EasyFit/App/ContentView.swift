import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
                .tag(AppState.Tab.nutrition)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell") }
                .tag(AppState.Tab.workout)

            FitProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppState.Tab.progress)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppState.Tab.profile)
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

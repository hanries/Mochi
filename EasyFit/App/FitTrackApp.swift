import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [FoodEntry.self, WorkoutPlan.self, Exercise.self, BodyWeightEntry.self])
    }
}

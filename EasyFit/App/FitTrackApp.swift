import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var mochi = MochiViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(mochi)
                    .preferredColorScheme(.dark)
            } else {
                OnboardingView()
                    .environmentObject(mochi)
                    .preferredColorScheme(.dark)
            }
        }
        .modelContainer(for: [FoodEntry.self, WorkoutPlan.self, Exercise.self, BodyWeightEntry.self, JournalEntry.self])
    }
}

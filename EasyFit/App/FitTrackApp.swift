import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(for: [FoodEntry.self, WorkoutPlan.self, Exercise.self, BodyWeightEntry.self])
    }
}

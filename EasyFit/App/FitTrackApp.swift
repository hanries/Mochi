import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    init() {
        print("=== Config Check ===")
        print("Edamam App ID: \(Config.edamamAppId.isEmpty ? "MISSING" : "✅ loaded (\(Config.edamamAppId.prefix(4))...)")")
        print("Edamam App Key: \(Config.edamamAppKey.isEmpty ? "MISSING" : "✅ loaded (\(Config.edamamAppKey.prefix(4))...)")")
        print("Anthropic Key: \(Config.anthropicAPIKey.isEmpty ? "MISSING" : "✅ loaded (\(Config.anthropicAPIKey.prefix(7))...)")")
        print("===================")
    }
    
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

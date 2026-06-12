import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var mochi = MochiViewModel()
    @StateObject private var paywall = PaywallCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(mochi)
                        .environmentObject(paywall)
                        .preferredColorScheme(.light)
                } else {
                    OnboardingView()
                        .environmentObject(mochi)
                        .environmentObject(paywall)
                        .preferredColorScheme(.light)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    let logged = mochi.loggedToday
                    Task {
                        await MochiNotificationService.shared.refreshAuthorizationStatus()
                        MochiNotificationService.shared.reschedule(loggedToday: logged)
                    }
                }
            }
        }
        .modelContainer(for: [FoodEntry.self, WorkoutPlan.self, Exercise.self, BodyWeightEntry.self, JournalEntry.self])
    }
}

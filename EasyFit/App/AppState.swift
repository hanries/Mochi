import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home

    // Flip to true (e.g. from a debug button) to replay the guided tour.
    // ContentView watches this and re-presents the walkthrough.
    @Published var replayTour = false

    enum Tab: Int, CaseIterable {
        case home, log, workout, profile
    }
}

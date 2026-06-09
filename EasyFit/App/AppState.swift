import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home

    enum Tab {
        case home, log, workout, profile
    }
}

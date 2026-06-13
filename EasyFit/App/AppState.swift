import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home

    enum Tab: Int, CaseIterable {
        case home, log, workout, profile
    }
}

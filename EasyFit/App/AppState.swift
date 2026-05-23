import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .nutrition

    enum Tab {
        case nutrition, workout, progress, profile
    }
}

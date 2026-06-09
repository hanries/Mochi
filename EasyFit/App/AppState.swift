import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .camera

    enum Tab {
        case camera, log, workout, profile
    }
}

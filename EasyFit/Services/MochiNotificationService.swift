import Foundation
import Combine
import UserNotifications

// MARK: - Daily check-in notification in Mochi's voice
//
// One pending request with a fixed identifier, cancel-and-rescheduled on
// every app background and after every log — structurally caps delivery
// at one per day. Copy comes from MochiDialogue.notifications: gentle,
// never guilt-based, never referencing calories.

@MainActor
final class MochiNotificationService: ObservableObject {
    static let shared = MochiNotificationService()

    @Published var isAuthorized = false
    @Published var isDenied = false

    private let identifier = "mochi.daily"

    private init() {}

    func refreshAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
        isAuthorized = status == .authorized
        isDenied = status == .denied
    }

    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        isAuthorized = granted
        isDenied = !granted
        return granted
    }

    /// Replaces the single pending check-in. If today's meal is already
    /// logged (or today's slot has passed), the check-in moves to tomorrow.
    func reschedule(loggedToday: Bool, config: MochiConfig = .default) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Mochi"
        content.body = MochiDialogue.notificationLine()
        content.sound = .default

        let cal = Calendar.current
        var fireDate = cal.date(
            bySettingHour: config.notificationHour, minute: 0, second: 0, of: .now)!
        if loggedToday || fireDate <= .now {
            fireDate = cal.date(byAdding: .day, value: 1, to: fireDate)!
        }

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

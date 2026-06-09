import Foundation

// MARK: - All Mochi behavior thresholds live here

struct MochiConfig {
    /// Hour of day (24h) after which Mochi gets sleepy if nothing was logged yet.
    var eveningHour: Int = 19

    /// Hours since the last log before Mochi starts missing you.
    var missingYouHours: Double = 24

    /// Streak length (consecutive logged days) that unlocks ecstatic moments.
    var ecstaticStreak: Int = 3

    /// How long the post-log celebration overlay stays on screen.
    var celebrationDuration: TimeInterval = 1.8

    /// How long Mochi's tap-dialogue speech bubble stays visible.
    var dialogueDuration: TimeInterval = 3.0

    /// Hour of day (24h) for the single daily check-in notification.
    var notificationHour: Int = 12

    static let `default` = MochiConfig()
}

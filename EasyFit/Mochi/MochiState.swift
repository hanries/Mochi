import Foundation

// MARK: - Mochi's emotional states

enum MochiState: String, CaseIterable {
    case ecstatic
    case happy
    case content
    case sleepy
    case missingYou
}

// MARK: - Pure state engine
//
// Mochi's state is derived only from engagement: when meals were logged and
// the current streak. Calorie or macro amounts are never an input — Mochi
// rewards the habit of tracking and never judges what was eaten.

enum MochiStateEngine {

    static func computeState(
        lastLog: Date?,
        loggedToday: Bool,
        streak: Int,
        now: Date = .now,
        config: MochiConfig = .default
    ) -> MochiState {
        // Brand-new user: welcoming, never guilt.
        guard let lastLog else { return .content }

        if loggedToday {
            return streak >= config.ecstaticStreak ? .ecstatic : .happy
        }

        let hoursSinceLastLog = now.timeIntervalSince(lastLog) / 3600
        if hoursSinceLastLog >= config.missingYouHours {
            return .missingYou
        }

        if Calendar.current.component(.hour, from: now) >= config.eveningHour {
            return .sleepy
        }

        return .content
    }

    /// Consecutive days with at least one log, counting backward.
    /// Grace rule: an empty today doesn't break yesterday's streak —
    /// counting starts from today if logged today, otherwise from yesterday.
    static func mealStreak(entryDates: [Date], now: Date = .now) -> Int {
        let cal = Calendar.current
        let logged = Set(entryDates.map { cal.startOfDay(for: $0) })
        guard !logged.isEmpty else { return 0 }

        let today = cal.startOfDay(for: now)
        var checking = logged.contains(today)
            ? today
            : cal.date(byAdding: .day, value: -1, to: today)!

        var streak = 0
        while logged.contains(checking) {
            streak += 1
            checking = cal.date(byAdding: .day, value: -1, to: checking)!
        }
        return streak
    }
}

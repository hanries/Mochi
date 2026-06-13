import Foundation

// MARK: - Mochi's emotional states
//
// Expression roadmap (engagement-only — never a reaction to food/weight/goals).
// Asset naming: `mochi_<state>` for the base frame, `mochi_<state>_blink` for
// the eyes-shut blink frame of open-eyed states; moments use `mochi_<moment>`.
//
//   State         Trigger                                  Art status
//   ──────────────────────────────────────────────────────────────────────────
//   content       brand-new user; daytime, logged          TODO: open-eyed
//                 recently but not yet today               `mochi_content` +
//                 (awake/calm)                             `mochi_content_blink`
//                                                          (currently reuses the
//                                                          happy frames)
//   happy         logged today, streak < ecstatic          have happy + _blink
//   ecstatic      logged today, streak ≥ ecstaticStreak    have base; TODO add
//                                                          `mochi_ecstatic_blink`
//   sleepy        evening, nothing logged yet              have base; blinks
//                                                          slowly via the freed
//                                                          eyes-shut frame; TODO
//                                                          optional sleepy redraw
//                                                          without baked-in "zzz"
//   missingYou    24h+ since any log                        have missing + _blink
//   eating        moment — every successful food log        have `mochi_eating`
//
// Proposed additive states (need buy-in + art before wiring):
//   greeting (moment)  first foreground of the day          `mochi_greeting`
//   proud              streak milestone beyond ecstatic      `mochi_proud` + _blink

enum MochiState: String, CaseIterable {
    case ecstatic
    case happy
    case content
    case sleepy
    case missingYou

    /// For VoiceOver: "Mochi, your companion, is <description>".
    var accessibilityDescription: String {
        switch self {
        case .ecstatic:   return "ecstatic"
        case .happy:      return "happy"
        case .content:    return "content"
        case .sleepy:     return "getting sleepy"
        case .missingYou: return "missing you"
        }
    }
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

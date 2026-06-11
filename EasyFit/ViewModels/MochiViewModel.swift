import Foundation
import Combine

@MainActor
final class MochiViewModel: ObservableObject {
    @Published private(set) var state: MochiState = .content
    @Published private(set) var streak: Int = 0
    @Published private(set) var loggedToday = false
    @Published var moment: MochiMoment? = nil

    let config: MochiConfig = .default

    private var recentLines: [String] = []

    // Recomputes state + streak from engagement data only.
    // Views pass in their @Query results; calorie values are never read.
    func refresh(entries: [FoodEntry], now: Date = .now) {
        let dates = entries.map(\.date)
        streak = MochiStateEngine.mealStreak(entryDates: dates, now: now)
        loggedToday = dates.contains { Calendar.current.isDate($0, inSameDayAs: now) }
        state = MochiStateEngine.computeState(
            lastLog: dates.max(),
            loggedToday: loggedToday,
            streak: streak,
            now: now,
            config: config
        )
    }

    /// Call after any successful food log. State itself refreshes via @Query.
    /// Every log earns an eating moment; the first log of a day whose
    /// resulting streak reaches the ecstatic threshold earns a milestone.
    func mealLogged() {
        let newStreak = loggedToday ? streak : streak + 1
        let kind: MochiMoment.Kind =
            (!loggedToday && newStreak >= config.ecstaticStreak) ? .ecstatic : .eating
        moment = MochiMoment(kind: kind, line: MochiDialogue.celebrationLine())
        loggedToday = true
        MochiNotificationService.shared.reschedule(loggedToday: true, config: config)
    }

    /// A warm line for Mochi's current mood, avoiding recent repeats.
    func dialogueLine() -> String {
        let line = MochiDialogue.line(for: state, excluding: recentLines)
        recentLines.append(line)
        if recentLines.count > 3 { recentLines.removeFirst() }
        return line
    }
}

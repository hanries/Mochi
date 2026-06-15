import Foundation
import Combine

@MainActor
final class MochiViewModel: ObservableObject {
    // Open-eyed, awake fallback shown the instant the view appears, before
    // @Query engagement data resolves. Never default to a closed-eye look.
    @Published private(set) var state: MochiState = .happy
    @Published private(set) var streak: Int = 0
    @Published private(set) var loggedToday = false
    @Published var moment: MochiMoment? = nil

    let config: MochiConfig = .default

    private var recentLines: [String] = []

    // Recomputes state + streak from engagement data only.
    // Views pass in their @Query results; calorie and weight VALUES are
    // never read — weight logging contributes dates alone.
    func refresh(entries: [FoodEntry], weightLogDates: [Date] = [], now: Date = .now) {
        let mealDates = entries.map(\.date)
        // Streak rewards the food-logging habit specifically.
        streak = MochiStateEngine.mealStreak(entryDates: mealDates, now: now)
        // "Logged something today" / last-engagement include any check-in.
        let engagementDates = mealDates + weightLogDates
        loggedToday = engagementDates.contains { Calendar.current.isDate($0, inSameDayAs: now) }
        state = MochiStateEngine.computeState(
            lastLog: engagementDates.max(),
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

    /// Call after a weight log. Deliberately takes NO value — the engine
    /// is structurally unable to react to the number or its direction. Mochi
    /// jumps for joy that you showed up, never about the number.
    func weightLogged() {
        moment = MochiMoment(kind: .cheer, line: MochiDialogue.checkInLine())
        loggedToday = true
        MochiNotificationService.shared.reschedule(loggedToday: true, config: config)
    }

    /// Call after a photo-journal log. Like weight, it carries no value —
    /// Mochi just jumps because you checked in.
    func photoLogged() {
        moment = MochiMoment(kind: .cheer, line: MochiDialogue.checkInLine())
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

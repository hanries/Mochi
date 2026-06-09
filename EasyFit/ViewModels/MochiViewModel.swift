import Foundation
import Combine

struct CelebrationEvent: Identifiable, Equatable {
    let id = UUID()
    let line: String
}

@MainActor
final class MochiViewModel: ObservableObject {
    @Published private(set) var state: MochiState = .content
    @Published private(set) var streak: Int = 0
    @Published var celebration: CelebrationEvent? = nil

    let config: MochiConfig = .default

    private var recentLines: [String] = []

    // Recomputes state + streak from engagement data only.
    // Views pass in their @Query results; calorie values are never read.
    func refresh(entries: [FoodEntry], now: Date = .now) {
        let dates = entries.map(\.date)
        streak = MochiStateEngine.mealStreak(entryDates: dates, now: now)
        state = MochiStateEngine.computeState(
            lastLog: dates.max(),
            loggedToday: dates.contains { Calendar.current.isDate($0, inSameDayAs: now) },
            streak: streak,
            now: now,
            config: config
        )
    }

    /// Call after any successful food log. State itself refreshes via @Query.
    func mealLogged() {
        celebration = CelebrationEvent(line: MochiDialogue.celebrationLine())
    }

    /// A warm line for Mochi's current mood, avoiding recent repeats.
    func dialogueLine() -> String {
        let line = MochiDialogue.line(for: state, excluding: recentLines)
        recentLines.append(line)
        if recentLines.count > 3 { recentLines.removeFirst() }
        return line
    }
}

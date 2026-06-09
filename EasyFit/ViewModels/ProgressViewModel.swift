import Foundation
import Combine

@MainActor
final class FitProgressViewModel: ObservableObject {
    @Published var showAddWeight = false

    // MARK: - Streak (based on weight logging days)

    func loggedDates(from entries: [BodyWeightEntry]) -> Set<DateComponents> {
        Set(entries.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0.date)
        })
    }

    func currentStreak(from entries: [BodyWeightEntry]) -> Int {
        let logged = loggedDates(from: entries)
        var streak = 0
        var checking = Date.now
        let cal = Calendar.current
        while true {
            let comps = cal.dateComponents([.year, .month, .day], from: checking)
            if logged.contains(comps) {
                streak  += 1
                checking = cal.date(byAdding: .day, value: -1, to: checking)!
            } else { break }
        }
        return streak
    }

    func longestStreak(from entries: [BodyWeightEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        let cal    = Calendar.current
        let sorted = entries.map { cal.startOfDay(for: $0.date) }.sorted()
        var longest = 1, current = 1
        for i in 1..<sorted.count {
            let diff = cal.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if diff == 1     { current += 1; longest = max(longest, current) }
            else if diff > 1 { current = 1 }
        }
        return longest
    }

    // MARK: - Weight helpers

    func last30Days(from entries: [BodyWeightEntry]) -> [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func weightDelta(from entries: [BodyWeightEntry]) -> Double? {
        let start = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now))!
        let month = entries.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard let first = month.first, let last = month.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }
}

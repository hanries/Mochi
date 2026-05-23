import Foundation
import Combine

@MainActor
final class FitProgressViewModel: ObservableObject {
    @Published var weightEntries: [BodyWeightEntry] = []
    @Published var showAddWeight = false

    // MARK: - Logged dates (any day with a weight entry)

    var loggedDates: Set<DateComponents> {
        Set(weightEntries.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0.date)
        })
    }

    // MARK: - Streak

    var currentStreak: Int {
        var streak = 0
        var checking = Date.now
        let cal = Calendar.current
        while true {
            let comps = cal.dateComponents([.year, .month, .day], from: checking)
            if loggedDates.contains(comps) {
                streak += 1
                checking = cal.date(byAdding: .day, value: -1, to: checking)!
            } else {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        guard !weightEntries.isEmpty else { return 0 }
        let cal = Calendar.current
        let sorted = weightEntries
            .map { cal.startOfDay(for: $0.date) }
            .sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let diff = cal.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Graph data

    var latestWeight: BodyWeightEntry? {
        weightEntries.sorted { $0.date > $1.date }.first
    }

    var weightThisMonth: Double? {
        let start = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        )!
        let monthEntries = weightEntries.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard let first = monthEntries.first, let last = monthEntries.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }

    var last30DaysEntries: [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return weightEntries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    // MARK: - Actions

    func addWeight(_ entry: BodyWeightEntry) {
        weightEntries.append(entry)
    }

    // MARK: - Preview

    static func preview() -> FitProgressViewModel {
        let vm  = FitProgressViewModel()
        let cal = Calendar.current
        // Simulate 9 consecutive days of logging
        vm.weightEntries = (0..<9).map { i in
            let date = cal.date(byAdding: .day, value: -i, to: .now)!
            return BodyWeightEntry(weight: 174.0 - Double(i) * 0.15 + Double.random(in: -0.3...0.3), date: date)
        }
        return vm
    }
}

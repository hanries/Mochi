import Foundation
import Combine

@MainActor
final class FitProgressViewModel: ObservableObject {
    @Published var weightEntries: [BodyWeightEntry] = []
    @Published var showAddWeight = false

    var latestWeight: BodyWeightEntry? {
        weightEntries.sorted { $0.date > $1.date }.first
    }

    var weightThisMonth: Double? {
        let start = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        )!
        let monthEntries = weightEntries
            .filter { $0.date >= start }
            .sorted { $0.date < $1.date }
        guard let first = monthEntries.first,
              let last  = monthEntries.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }

    var last7DaysEntries: [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return weightEntries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    func addWeight(_ entry: BodyWeightEntry) {
        weightEntries.append(entry)
    }

    static func preview() -> FitProgressViewModel {
        let vm  = FitProgressViewModel()
        let cal = Calendar.current
        vm.weightEntries = (0..<14).map { i in
            let date = cal.date(byAdding: .day, value: -i, to: .now)!
            return BodyWeightEntry(weight: 174.0 + Double.random(in: -1...1), date: date)
        }
        return vm
    }
}

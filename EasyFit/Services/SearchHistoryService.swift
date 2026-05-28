import Foundation

// Persists food names the user has previously logged, used to boost search ranking

final class SearchHistoryService {
    static let shared = SearchHistoryService()

    private let key = "food_search_history"
    private let maxEntries = 100

    // foodName → log count
    private(set) var history: [String: Int] = [:]

    init() { load() }

    func record(foodName: String) {
        let k = foodName.lowercased().trimmingCharacters(in: .whitespaces)
        history[k, default: 0] += 1
        save()
    }

    func score(for foodName: String) -> Int {
        let k = foodName.lowercased().trimmingCharacters(in: .whitespaces)
        return history[k] ?? 0
    }

    private func save() {
        UserDefaults.standard.set(history, forKey: key)
    }

    private func load() {
        history = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }
}

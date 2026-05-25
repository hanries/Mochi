import Foundation

// MARK: - Search result model

struct FoodSearchResult: Identifiable {
    let id: String
    let name: String
    let brand: String?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: String
}

// MARK: - Food Search Service (Edamam Food Database API)
// Sign up free at: developer.edamam.com → Food Database API
// Add to Config.xcconfig:
//   EDAMAM_APP_ID  = your_app_id
//   EDAMAM_APP_KEY = your_app_key

final class FoodSearchService {
    static let shared = FoodSearchService()

    private let appId  = "e0b226da"
    private let appKey = "e780633c293c93e5811bc6e7b69d7c88"
    private let baseURL   = "https://api.edamam.com/api/food-database/v2/parser"
    private let maxRetries = 2
    private var cache: [String: [FoodSearchResult]] = [:]

    func search(query: String) async throws -> [FoodSearchResult] {
        let key = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return [] }
        if let cached = cache[key] { return cached }

        let results = try await withRetry(maxAttempts: maxRetries) {
            try await self.fetchEdamam(query: query)
        }

        cache[key] = results
        return results
    }

    // MARK: - Edamam fetch

    private func fetchEdamam(query: String) async throws -> [FoodSearchResult] {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            URLQueryItem(name: "app_id",      value: appId),
            URLQueryItem(name: "app_key",     value: appKey),
            URLQueryItem(name: "ingr",        value: query),
            URLQueryItem(name: "nutrition-type", value: "logging"),
        ]

        var request = URLRequest(url: comps.url!, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SearchError.noResponse }
        switch http.statusCode {
        case 200:           break
        case 401, 403:      throw SearchError.unauthorized
        case 429:           throw SearchError.rateLimited
        case 500, 503:      throw SearchError.serverError
        default:
            throw SearchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(EdamamResponse.self, from: data)

        var results = [FoodSearchResult]()

        // Parsed ingredient (exact match for whole foods like "2 eggs")
        if let parsed = decoded.parsed {
            for item in parsed {
                if let r = parseHint(item.food) { results.append(r) }
            }
        }

        // Hints (search suggestions — branded + whole foods)
        if let hints = decoded.hints {
            for hint in hints {
                if let r = parseHint(hint.food) { results.append(r) }
            }
        }

        // Deduplicate by name
        var seen = Set<String>()
        var deduped = [FoodSearchResult]()
        for r in results {
            let k = r.name.lowercased()
            if !seen.contains(k) { seen.insert(k); deduped.append(r) }
        }

        return deduped
    }

    // MARK: - Parse

    private func parseHint(_ food: EdamamFood?) -> FoodSearchResult? {
        guard let food = food,
              let label = food.label, !label.isEmpty else { return nil }

        let nutrients = food.nutrients
        let cal = nutrients?.ENERC_KCAL ?? 0
        guard cal > 0 else { return nil }

        // Edamam nutrients are per 100g — find a sensible serving
        let serving: String
        if let measures = food.measures, let first = measures.first(where: {
            $0.label != "Gram" && $0.label != "Ounce"
        }) {
            serving = first.label ?? "1 serving"
        } else {
            serving = "100g"
        }

        return FoodSearchResult(
            id:          food.foodId ?? UUID().uuidString,
            name:        label.capitalized,
            brand:       food.brand,
            calories:    Int(cal.rounded()),
            protein:     round10(nutrients?.PROCNT ?? 0),
            carbs:       round10(nutrients?.CHOCDF ?? 0),
            fat:         round10(nutrients?.FAT    ?? 0),
            servingSize: serving
        )
    }

    private func round10(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    // MARK: - Retry

    private func withRetry<T>(maxAttempts: Int, _ op: () async throws -> T) async throws -> T {
        var last: Error?
        for attempt in 1...maxAttempts {
            do { return try await op() }
            catch SearchError.rateLimited  { throw SearchError.rateLimited  }
            catch SearchError.unauthorized { throw SearchError.unauthorized }
            catch {
                last = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(0.8 * Double(attempt) * 1_000_000_000))
                }
            }
        }
        throw last ?? SearchError.noResponse
    }
}

// MARK: - Errors

enum SearchError: LocalizedError {
    case noResponse, badStatus(Int), rateLimited, serverError, unauthorized
    var errorDescription: String? {
        switch self {
        case .noResponse:       return "No response from server. Check your connection."
        case .badStatus(let c): return "Server error \(c). Try again."
        case .rateLimited:      return "Too many requests — wait a moment and try again."
        case .serverError:      return "Food database temporarily unavailable. Try again."
        case .unauthorized:     return "Invalid Edamam API credentials. Check your keys in Config.xcconfig."
        }
    }
}

// MARK: - Edamam response shapes

private struct EdamamResponse: Decodable {
    let parsed: [EdamamParsed]?
    let hints:  [EdamamHint]?
}

private struct EdamamParsed: Decodable { let food: EdamamFood? }
private struct EdamamHint:   Decodable { let food: EdamamFood? }

private struct EdamamFood: Decodable {
    let foodId:    String?
    let label:     String?
    let brand:     String?
    let nutrients: EdamamNutrients?
    let measures:  [EdamamMeasure]?
}

private struct EdamamNutrients: Decodable {
    let ENERC_KCAL: Double?   // calories
    let PROCNT:     Double?   // protein
    let CHOCDF:     Double?   // carbs
    let FAT:        Double?   // fat
}

private struct EdamamMeasure: Decodable {
    let label: String?
    let weight: Double?
}

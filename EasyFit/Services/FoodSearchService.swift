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

// MARK: - Food Search Service (USDA FoodData Central)

final class FoodSearchService {
    static let shared = FoodSearchService()

    private var apiKey: String { Config.usdaAPIKey }
    private let baseURL  = "https://api.nal.usda.gov/fdc/v1"
    private let maxRetries = 3

    // In-memory cache
    private var cache: [String: [FoodSearchResult]] = [:]

    func search(query: String) async throws -> [FoodSearchResult] {
        let key = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return [] }
        if let cached = cache[key] { return cached }

        let results = try await withRetry(maxAttempts: maxRetries) {
            try await self.fetchFromUSDA(query: query, key: key)
        }

        cache[key] = results
        return results
    }

    private func fetchFromUSDA(query: String, key: String) async throws -> [FoodSearchResult] {
        var comps = URLComponents(string: "\(baseURL)/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query",     value: query),
            URLQueryItem(name: "api_key",   value: apiKey),
            URLQueryItem(name: "pageSize",  value: "25"),
            URLQueryItem(name: "dataType",  value: "Branded,SR Legacy,Survey (FNDDS)"),
            URLQueryItem(name: "sortBy",    value: "dataType.keyword"),
            URLQueryItem(name: "sortOrder", value: "asc"),
        ]

        var request = URLRequest(url: comps.url!, timeoutInterval: 12)
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SearchError.noResponse }
        switch http.statusCode {
        case 200:        break
        case 429:        throw SearchError.rateLimited
        case 500, 503:   throw SearchError.serverError
        default:         throw SearchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        let results = decoded.foods.compactMap { parse($0) }

        return results.sorted { a, b in
            let aMatch = a.name.lowercased().hasPrefix(key)
            let bMatch = b.name.lowercased().hasPrefix(key)
            if aMatch != bMatch { return aMatch }
            return a.name.count < b.name.count
        }
    }

    // MARK: - Retry helper

    private func withRetry<T>(
        maxAttempts: Int,
        delay: TimeInterval = 1.0,
        _ operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch SearchError.rateLimited {
                throw SearchError.rateLimited   // don't retry rate limits
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let backoff = UInt64(delay * Double(attempt) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: backoff)
                }
            }
        }
        throw lastError ?? SearchError.noResponse
    }

    // MARK: - Parse

    private func parse(_ food: USDAFood) -> FoodSearchResult? {
        guard let name = food.description, !name.isEmpty else { return nil }

        func nutrient(_ id: Int) -> Double {
            food.foodNutrients?.first { $0.nutrientId == id }?.value ?? 0
        }

        let cal     = nutrient(1008)
        let protein = nutrient(1003)
        let carbs   = nutrient(1005)
        let fat     = nutrient(1004)

        guard cal > 0 else { return nil }

        let serving: String
        if let qty = food.servingSize, let unit = food.servingSizeUnit {
            serving = "\(Int(qty))\(unit)"
        } else {
            serving = "100g"
        }

        let brand = food.brandOwner?.isEmpty == false ? food.brandOwner : food.brandName

        return FoodSearchResult(
            id:          "\(food.fdcId ?? 0)",
            name:        name.capitalized,
            brand:       brand,
            calories:    Int(cal.rounded()),
            protein:     (protein * 10).rounded() / 10,
            carbs:       (carbs   * 10).rounded() / 10,
            fat:         (fat     * 10).rounded() / 10,
            servingSize: serving
        )
    }
}

// MARK: - Errors

enum SearchError: LocalizedError {
    case noResponse
    case badStatus(Int)
    case rateLimited
    case serverError

    var errorDescription: String? {
        switch self {
        case .noResponse:    return "No response from server. Check your connection."
        case .badStatus(let c): return "Server returned error \(c). Try again."
        case .rateLimited:   return "Too many requests — wait a moment and try again."
        case .serverError:   return "The food database is temporarily unavailable. Try again in a few seconds."
        }
    }
}

// MARK: - USDA response shapes

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let fdcId:           Int?
    let description:     String?
    let brandOwner:      String?
    let brandName:       String?
    let servingSize:     Double?
    let servingSizeUnit: String?
    let foodNutrients:   [USDANutrient]?
}

private struct USDANutrient: Decodable {
    let nutrientId: Int?
    let value:      Double?
}

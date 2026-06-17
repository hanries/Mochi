import Foundation

// MARK: - Serving option

struct ServingOption: Identifiable {
    let id: String
    let label: String
    let weightGrams: Double  // how many grams this serving weighs
}

// MARK: - Search result model

struct FoodSearchResult: Identifiable {
    let id: String
    let name: String
    let brandName: String?
    // All nutrients are per 100g from Edamam
    let caloriesPer100g: Double
    let proteinPer100g:  Double
    let carbsPer100g:    Double
    let fatPer100g:      Double
    // Available serving options
    let servingOptions:  [ServingOption]
    // Default serving
    let defaultServing:  ServingOption

    // Convenience for list display (based on default serving)
    var calories: Int    { Int((caloriesPer100g * defaultServing.weightGrams / 100).rounded()) }
    var protein:  Double { (proteinPer100g  * defaultServing.weightGrams / 100 * 10).rounded() / 10 }
    var carbs:    Double { (carbsPer100g    * defaultServing.weightGrams / 100 * 10).rounded() / 10 }
    var fat:      Double { (fatPer100g      * defaultServing.weightGrams / 100 * 10).rounded() / 10 }
    var servingSize: String { defaultServing.label }
}

// MARK: - Edamam food provider

final class EdamamFoodProvider: FoodProvider {
    let providerID = "edamam"

    // From Config.xcconfig (gitignored) — no longer hardcoded in source.
    // NOTE: these still ship inside the app's Info.plist; a server-side proxy
    // is the real fix. Rotate the old hardcoded key that's in git history.
    private let appId  = Config.edamamAppId
    private let appKey = Config.edamamAppKey
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

    // MARK: - Fetch

    private func fetchEdamam(query: String) async throws -> [FoodSearchResult] {
        let url: URL
        let proxy = Config.proxyBaseURL
        if !proxy.isEmpty {
            // Proxy adds the Edamam keys server-side; the app sends only the query.
            let base = proxy.hasSuffix("/") ? String(proxy.dropLast()) : proxy
            var comps = URLComponents(string: "\(base)/foods")!
            comps.queryItems = [URLQueryItem(name: "ingr", value: query)]
            url = comps.url!
        } else {
            var comps = URLComponents(string: baseURL)!
            comps.queryItems = [
                URLQueryItem(name: "app_id",         value: appId),
                URLQueryItem(name: "app_key",        value: appKey),
                URLQueryItem(name: "ingr",           value: query),
                URLQueryItem(name: "nutrition-type", value: "logging"),
            ]
            url = comps.url!
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SearchError.noResponse }
        switch http.statusCode {
        case 200:      break
        case 401, 403: throw SearchError.unauthorized
        case 429:      throw SearchError.rateLimited
        case 500, 503: throw SearchError.serverError
        default:       throw SearchError.badStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(EdamamResponse.self, from: data)

        var results = [FoodSearchResult]()
        var seen    = Set<String>()

        let allHints = decoded.hints ?? []
        let parsed   = decoded.parsed?.map { EdamamHint(food: $0.food, measures: $0.measures) } ?? []

        for hint in parsed + allHints {
            guard let r = parse(hint) else { continue }
            if !seen.contains(r.name.lowercased()) {
                seen.insert(r.name.lowercased())
                results.append(r)
            }
        }

        return rank(results, query: query)
    }

    // MARK: - Ranking

    private func rank(_ results: [FoodSearchResult], query: String) -> [FoodSearchResult] {
        let words = query.lowercased().split(separator: " ").map { String($0) }
        return results.sorted { score($0, query: query, words: words) > score($1, query: query, words: words) }
    }

    private func score(_ r: FoodSearchResult, query: String, words: [String]) -> Int {
        let name = r.name.lowercased()
        var s = 0
        if name == query                                    { s += 100 }
        if name.hasPrefix(query)                            { s += 70  }
        if words.allSatisfy({ name.contains($0) })          { s += 50  }
        if let first = words.first, name.hasPrefix(first)  { s += 30  }
        let nameWords = name.components(separatedBy: " ")
        for word in words where nameWords.contains(word)    { s += 25  }
        if r.brandName == nil                               { s += 40  }
        if name.contains(",")                               { s -= 30  }
        s -= min(name.count, 30)
        if name.count > 40                                  { s -= 20  }
        let extraWords = nameWords.filter { !words.contains($0) }.count
        if extraWords == 0                                  { s += 20  }
        if extraWords <= 1                                  { s += 10  }
        // Boost previously logged foods — max +80 so history can surface familiar foods
        let historyCount = SearchHistoryService.shared.score(for: r.name)
        s += min(historyCount * 20, 80)
        return s
    }

    // MARK: - Parse

    private func parse(_ hint: EdamamHint) -> FoodSearchResult? {
        guard let food   = hint.food,
              let label  = food.label, !label.isEmpty,
              let nutrients = food.nutrients else { return nil }

        let cal = nutrients.ENERC_KCAL ?? 0
        guard cal > 0 else { return nil }

        // Build serving options from measures, excluding Gram/Ounce/Pound/Kilogram
        let unitMeasures = hint.measures?.filter { m in
            let l = m.label ?? ""
            return !["Gram", "Ounce", "Pound", "Kilogram", "Liter", "Milliliter"].contains(l)
                && (m.weight ?? 0) > 0
        } ?? []

        var options = unitMeasures.map { m in
            ServingOption(
                id:           m.uri ?? m.label ?? UUID().uuidString,
                label:        m.label ?? "Serving",
                weightGrams:  m.weight ?? 100
            )
        }

        // Always add a 100g option as fallback
        options.append(ServingOption(id: "100g", label: "100g", weightGrams: 100))

        // Pick default: prefer Whole > Serving > first option
        let default_ = options.first { $0.label == "Whole" }
            ?? options.first { $0.label == "Serving" }
            ?? options.first
            ?? ServingOption(id: "100g", label: "100g", weightGrams: 100)

        return FoodSearchResult(
            id:              food.foodId ?? UUID().uuidString,
            name:            label.capitalized,
            brandName:       food.brand,
            caloriesPer100g: cal,
            proteinPer100g:  nutrients.PROCNT ?? 0,
            carbsPer100g:    nutrients.CHOCDF ?? 0,
            fatPer100g:      nutrients.FAT    ?? 0,
            servingOptions:  options,
            defaultServing:  default_
        )
    }

    // MARK: - Retry

    private func withRetry<T>(maxAttempts: Int, _ op: () async throws -> T) async throws -> T {
        var last: Error?
        for attempt in 1...maxAttempts {
            do { return try await op() }
            catch SearchError.rateLimited, SearchError.unauthorized { throw last ?? SearchError.noResponse }
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
        case .unauthorized:     return "Invalid API credentials."
        }
    }
}

// MARK: - Edamam response shapes

private struct EdamamResponse: Decodable {
    let parsed: [EdamamParsed]?
    let hints:  [EdamamHint]?
}

private struct EdamamParsed: Decodable {
    let food:     EdamamFood?
    let measures: [EdamamMeasure]?
}

struct EdamamHint: Decodable {
    let food:     EdamamFood?
    let measures: [EdamamMeasure]?
}

struct EdamamFood: Decodable {
    let foodId:    String?
    let label:     String?
    let brand:     String?
    let nutrients: EdamamNutrients?
}

struct EdamamNutrients: Decodable {
    let ENERC_KCAL: Double?
    let PROCNT:     Double?
    let CHOCDF:     Double?
    let FAT:        Double?
}

struct EdamamMeasure: Decodable {
    let uri:    String?
    let label:  String?
    let weight: Double?
}

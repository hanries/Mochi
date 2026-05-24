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

    var displayName: String { name }
    var displayBrand: String { brand ?? "" }
}

// MARK: - Open Food Facts API service

final class FoodSearchService {
    static let shared = FoodSearchService()

    private let baseURL = "https://world.openfoodfacts.org/cgi/search.pl"

    func search(query: String) async throws -> [FoodSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "search_terms",   value: query),
            URLQueryItem(name: "search_simple",  value: "1"),
            URLQueryItem(name: "action",         value: "process"),
            URLQueryItem(name: "json",           value: "1"),
            URLQueryItem(name: "page_size",      value: "25"),
            URLQueryItem(name: "fields",         value: "id,product_name,brands,nutriments,serving_size,serving_quantity")
        ]

        let request = URLRequest(url: components.url!, timeoutInterval: 10)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(OFFResponse.self, from: data)

        return response.products.compactMap { parse($0) }
    }

    private func parse(_ p: OFFProduct) -> FoodSearchResult? {
        guard let name = p.product_name, !name.isEmpty else { return nil }

        let n = p.nutriments
        // OFF nutriments are per 100g by default; use _serving variants if available
        let cal     = n?.energy_kcal_serving ?? n?.energy_kcal_100g ?? 0
        let protein = n?.proteins_serving    ?? n?.proteins_100g    ?? 0
        let carbs   = n?.carbohydrates_serving ?? n?.carbohydrates_100g ?? 0
        let fat     = n?.fat_serving         ?? n?.fat_100g         ?? 0

        // Skip entries with no nutritional data
        guard cal > 0 else { return nil }

        let serving = p.serving_size ?? "100g"

        return FoodSearchResult(
            id:          p.id ?? UUID().uuidString,
            name:        name.capitalized,
            brand:       p.brands.flatMap { $0.isEmpty ? nil : $0 },
            calories:    Int(cal.rounded()),
            protein:     (protein * 10).rounded() / 10,
            carbs:       (carbs   * 10).rounded() / 10,
            fat:         (fat     * 10).rounded() / 10,
            servingSize: serving
        )
    }
}

// MARK: - Decodable response shapes

private struct OFFResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProduct: Decodable {
    let id:           String?
    let product_name: String?
    let brands:       String?
    let serving_size: String?
    let serving_quantity: Double?
    let nutriments:   OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case product_name, brands, serving_size, serving_quantity, nutriments
    }
}

private struct OFFNutriments: Decodable {
    let energy_kcal_100g:        Double?
    let energy_kcal_serving:     Double?
    let proteins_100g:           Double?
    let proteins_serving:        Double?
    let carbohydrates_100g:      Double?
    let carbohydrates_serving:   Double?
    let fat_100g:                Double?
    let fat_serving:             Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g        = "energy-kcal_100g"
        case energy_kcal_serving     = "energy-kcal_serving"
        case proteins_100g           = "proteins_100g"
        case proteins_serving        = "proteins_serving"
        case carbohydrates_100g      = "carbohydrates_100g"
        case carbohydrates_serving   = "carbohydrates_serving"
        case fat_100g                = "fat_100g"
        case fat_serving             = "fat_serving"
    }
}

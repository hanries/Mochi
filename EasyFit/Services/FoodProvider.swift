import Foundation

// MARK: - Food provider abstraction
//
// The app searches food through this contract, never through a concrete
// service. Swapping the data source (USDA, another API, an on-device DB)
// is a one-line change to `FoodSearch.provider` below — no UI touches.

protocol FoodProvider {
    /// Short identifier stamped onto logged entries for provenance, e.g. "edamam".
    var providerID: String { get }

    func search(query: String) async throws -> [FoodSearchResult]

    /// Future: resolve a scanned barcode. Optional — providers that don't
    /// support it inherit the no-op default below.
    func lookup(barcode: String) async throws -> FoodSearchResult?
}

extension FoodProvider {
    func lookup(barcode: String) async throws -> FoodSearchResult? { nil }
}

// MARK: - Active provider (the single swappable seam)

enum FoodSearch {
    static let provider: any FoodProvider = EdamamFoodProvider()
}

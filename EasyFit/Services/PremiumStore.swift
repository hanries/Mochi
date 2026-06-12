import Foundation
import Combine
import StoreKit

// MARK: - StoreKit 2 entitlements
//
// Single source of truth for premium status. Offline grace: the last
// known entitlement is cached in UserDefaults and trusted until StoreKit
// answers. Premium gates only the AI scan quota — everything else in the
// app is free forever, and Mochi never knows about any of this.

@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    static let monthlyID = "mochi.premium.monthly"
    static let yearlyID  = "mochi.premium.yearly"
    static let allProductIDs: Set<String> = [monthlyID, yearlyID]

    @Published private(set) var isPremium: Bool
    @Published private(set) var products: [Product] = []

    private var entitledFromStore: Bool
    private var updatesTask: Task<Void, Never>? = nil
    private let cacheKey = "cachedPremiumEntitlement"

    private init() {
        let cached = UserDefaults.standard.bool(forKey: cacheKey)
        entitledFromStore = cached
        isPremium = cached
        refreshPremiumFlag()

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    // MARK: Products

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: Self.allProductIDs) else { return }
        // Yearly first — it's the visually preferred plan on the paywall.
        products = loaded.sorted { $0.id == Self.yearlyID && $1.id != Self.yearlyID }
    }

    // MARK: Purchase / restore

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if let transaction = try? verification.payloadValue {
                await transaction.finish()
            }
            await refreshEntitlement()
            return isPremium
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: Entitlement

    func refreshEntitlement() async {
        var entitled = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue,
               Self.allProductIDs.contains(transaction.productID) {
                entitled = true
            }
        }
        entitledFromStore = entitled
        UserDefaults.standard.set(entitled, forKey: cacheKey)
        refreshPremiumFlag()
    }

    // MARK: Debug override

    #if DEBUG
    var debugSimulatePremium: Bool {
        get { UserDefaults.standard.bool(forKey: "debugSimulatePremium") }
        set {
            UserDefaults.standard.set(newValue, forKey: "debugSimulatePremium")
            refreshPremiumFlag()
        }
    }
    #endif

    private func refreshPremiumFlag() {
        #if DEBUG
        isPremium = entitledFromStore || debugSimulatePremium
        #else
        isPremium = entitledFromStore
        #endif
    }
}

import Foundation
import Combine
import StoreKit

// MARK: - StoreKit 2 entitlements
//
// Single source of truth for premium status. Offline grace: the last
// known entitlement is cached in UserDefaults and trusted until StoreKit
// answers. Premium gates only the AI scan quota — everything else in the
// app is free forever, and Mochi never knows about any of this.

// The state of the StoreKit product fetch. The paywall renders a skeleton
// while .loading, the priced plans when .loaded, and a Retry affordance on
// .failed — purchase is impossible unless .loaded, so a price is always
// visible before checkout.
enum ProductLoadState: Equatable {
    case idle, loading, loaded, failed
}

@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    // MARK: App Store Connect checklist (before TestFlight / release)
    //
    // 1. Create BOTH auto-renewable subscriptions in App Store Connect with
    //    product IDs EXACTLY matching monthlyID / yearlyID below, in one
    //    subscription group ("Mochi Premium").
    // 2. Attach the 7-day free-trial introductory offer to the YEARLY
    //    product only (monthly has no intro offer).
    // 3. Sign the Paid Applications agreement and complete banking & tax in
    //    Agreements, Tax, and Banking — products come back EMPTY until this
    //    is done, which surfaces here as the .failed state.
    // 4. Newly created or edited products can take ~24h to propagate to
    //    sandbox and production.
    // 5. Local testing uses Products.storekit (scheme ▸ Run ▸ Options ▸
    //    StoreKit Configuration). Set it to "None" to exercise the real
    //    sandbox path and the .failed UI.
    static let monthlyID = "mochi.premium.monthly"
    static let yearlyID  = "mochi.premium.yearly"
    static let allProductIDs: Set<String> = [monthlyID, yearlyID]

    @Published private(set) var isPremium: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: ProductLoadState = .idle

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
        guard loadState != .loading else { return }
        loadState = .loading

        #if DEBUG
        // Optional knob to demo the loading skeleton in the simulator.
        if UserDefaults.standard.bool(forKey: "debugSlowProducts") {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
        #endif

        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            // Empty for known IDs means StoreKit couldn't resolve them
            // (no config, products not yet propagated, agreements pending).
            guard !loaded.isEmpty else {
                loadState = .failed
                return
            }
            // Yearly first — it's the visually preferred plan on the paywall.
            products = loaded.sorted { $0.id == Self.yearlyID && $1.id != Self.yearlyID }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func retryLoadProducts() {
        Task { await loadProducts() }
    }

    // MARK: Purchase / restore

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        // Never initiate a purchase unless products loaded with prices —
        // App Review requires a visible price before checkout.
        guard loadState == .loaded else { return false }
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

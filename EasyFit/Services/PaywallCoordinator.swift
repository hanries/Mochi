import Foundation
import Combine

// MARK: - The single paywall gate
//
// Every premium/quota decision flows through here — no view reads
// ScanQuota or PremiumStore.isPremium directly for gating. Quota copy is
// interface voice; Mochi never comments on caps or subscriptions.

enum PaywallContext: Identifiable {
    case scanCap      // hit the free daily scan limit
    case profile      // opened from the Profile row
    case onboarding   // one soft show after onboarding

    var id: Self { self }

    /// Automatic triggers fire without the user asking, so they share a
    /// global 24h cooldown. User-initiated triggers (a tapped scan that's
    /// capped, the Profile row) are exempt and always show.
    var isAutomaticTrigger: Bool {
        switch self {
        case .onboarding:        return true   // future automatic triggers join here
        case .scanCap, .profile: return false
        }
    }
}

@MainActor
final class PaywallCoordinator: ObservableObject {
    @Published var paywallContext: PaywallContext? = nil

    let store = PremiumStore.shared
    private var cancellable: AnyCancellable? = nil

    // Global cooldown for automatic triggers, persisted across launches.
    private static let lastAutoShownKey = "paywallLastAutoShownAt"
    private let automaticCooldown: TimeInterval = 24 * 60 * 60

    init() {
        // Re-publish entitlement changes so counters refresh.
        cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// The one gate for AI scans: true → proceed to the camera.
    /// False → the paywall is being presented (manual entry stays free).
    func requestScan() -> Bool {
        if store.isPremium { return true }
        if ScanQuota.remaining() > 0 { return true }
        paywallContext = .scanCap
        return false
    }

    /// Call once per actual AI scan request (the StoreKit of truth is
    /// FoodCameraView.capture(), the only place the scan service runs).
    func recordScanUsed() {
        guard !store.isPremium else { return }
        ScanQuota.recordScan()
        objectWillChange.send()
    }

    /// Friendly counter for free users; nil when premium (no counter shown).
    var remainingScansText: String? {
        guard !store.isPremium else { return nil }
        return "\(ScanQuota.remaining()) of \(ScanQuota.freeDailyLimit) free scans left today"
    }

    /// True if an automatic paywall may show now (cooldown elapsed).
    var canShowAutomaticPaywall: Bool {
        let last = UserDefaults.standard.double(forKey: Self.lastAutoShownKey)
        return Date.now.timeIntervalSince1970 - last >= automaticCooldown
    }

    /// Present the paywall. Automatic triggers respect the 24h global
    /// cooldown and never show to premium users; user-initiated triggers
    /// always show. Returns whether the paywall was actually presented.
    @discardableResult
    func presentPaywall(_ context: PaywallContext) -> Bool {
        if context.isAutomaticTrigger {
            guard !store.isPremium, canShowAutomaticPaywall else { return false }
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastAutoShownKey)
        }
        paywallContext = context
        return true
    }
}

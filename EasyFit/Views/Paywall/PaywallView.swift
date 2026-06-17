import SwiftUI
import StoreKit

// MARK: - EasyFit Premium paywall
//
// Warm, honest, skippable. Mochi is decoration here — he never begs.
// Prices and the trial badge come from StoreKit, never hardcoded.
// From the scan-cap context, manual entry is one tap away: a capped
// user can always log.

struct PaywallView: View {
    let context: PaywallContext
    var onManualEntry: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PremiumStore.shared

    @State private var selectedProductID = PremiumStore.yearlyID
    @State private var isPurchasing = false
    @State private var purchaseError: String? = nil

    private let termsURL   = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    // Policy source lives at docs/privacy-policy.html. Update this if you host it elsewhere.
    private let privacyURL = URL(string: "https://hanries.github.io/Mochi/privacy-policy.html")!

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MochiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: MochiTheme.Spacing.xl) {
                    MochiView(state: .ecstatic, size: 120)
                        .padding(.top, MochiTheme.Spacing.xxl)

                    VStack(spacing: MochiTheme.Spacing.sm) {
                        Text("Unlimited scans, zero counting")
                            .font(MochiTheme.title)
                            .foregroundStyle(MochiTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        if context == .scanCap {
                            Text("You've used today's 3 free scans.")
                                .font(MochiTheme.caption)
                                .foregroundStyle(MochiTheme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: MochiTheme.Spacing.md) {
                        BenefitRow(text: "Unlimited AI food scans, every day")
                        BenefitRow(text: "Everything free today stays free, forever")
                        BenefitRow(text: "Helps keep Mochi's home warm and growing")
                    }
                    .padding(.horizontal, MochiTheme.Spacing.xl)

                    // Plans + purchase, driven by the load state so a price
                    // is always visible before a purchase can be initiated.
                    switch store.loadState {
                    case .idle, .loading:
                        VStack(spacing: MochiTheme.Spacing.md) {
                            PlanCardSkeleton()
                            PlanCardSkeleton()
                        }
                        .padding(.horizontal, MochiTheme.Spacing.xl)

                        continueButton(enabled: false, caption: nil)

                    case .loaded:
                        VStack(spacing: MochiTheme.Spacing.md) {
                            ForEach(store.products, id: \.id) { product in
                                PlanCard(
                                    product: product,
                                    isSelected: selectedProductID == product.id
                                ) {
                                    selectedProductID = product.id
                                }
                            }
                        }
                        .padding(.horizontal, MochiTheme.Spacing.xl)

                        if let purchaseError {
                            Text(purchaseError)
                                .font(MochiTheme.caption)
                                .foregroundStyle(MochiTheme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, MochiTheme.Spacing.xl)
                        }

                        continueButton(enabled: !isPurchasing, caption: selectedPriceCaption)

                    case .failed:
                        FailedToLoadCard { store.retryLoadProducts() }
                            .padding(.horizontal, MochiTheme.Spacing.xl)
                    }

                    // The capped user is never blocked from logging.
                    if context == .scanCap {
                        Button {
                            dismiss()
                            onManualEntry?()
                        } label: {
                            Text("Or log it manually — always free")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(MochiTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, MochiTheme.Spacing.md)
                                .background(MochiTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: MochiTheme.buttonRadius))
                        }
                        .padding(.horizontal, MochiTheme.Spacing.xl)
                    }

                    Button("Restore Purchases") {
                        Task {
                            await store.restore()
                            if store.isPremium { dismiss() }
                        }
                    }
                    .font(MochiTheme.caption)
                    .foregroundStyle(MochiTheme.textSecondary)

                    HStack(spacing: MochiTheme.Spacing.lg) {
                        Link("Terms of Use", destination: termsURL)
                        Link("Privacy Policy", destination: privacyURL)
                    }
                    .font(MochiTheme.caption)
                    .foregroundStyle(MochiTheme.textSecondary)
                    .padding(.bottom, MochiTheme.Spacing.xxl)
                }
            }

            // Always-visible close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MochiTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(MochiTheme.surface)
                    .clipShape(Circle())
            }
            .padding(MochiTheme.Spacing.lg)
            .accessibilityLabel("Close")
        }
        .task {
            if store.loadState == .idle || store.loadState == .failed {
                await store.loadProducts()
            }
        }
    }

    // The Continue button plus an optional price caption beneath it. The
    // caption restates the selected plan's price and trial terms so the
    // user sees both before checkout.
    @ViewBuilder
    private func continueButton(enabled: Bool, caption: String?) -> some View {
        VStack(spacing: MochiTheme.Spacing.sm) {
            Button {
                purchase()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(MochiTheme.surfaceAlt)
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(MochiTheme.surfaceAlt)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MochiTheme.Spacing.lg)
                .background(enabled ? MochiTheme.primary : MochiTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: MochiTheme.buttonRadius))
            }
            .disabled(!enabled)

            if let caption {
                Text(caption)
                    .font(MochiTheme.caption)
                    .foregroundStyle(MochiTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, MochiTheme.Spacing.xl)
    }

    // Price + terms for the selected plan, straight from StoreKit.
    private var selectedPriceCaption: String? {
        guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return nil }
        let period = product.subscription?.subscriptionPeriod.unit
        let hasTrial = product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        switch period {
        case .year:
            return hasTrial
                ? "7 days free, then \(product.displayPrice) per year"
                : "\(product.displayPrice) per year"
        case .month:
            return "\(product.displayPrice) per month, cancel anytime"
        default:
            return product.displayPrice
        }
    }

    private func purchase() {
        guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        purchaseError = nil
        Task {
            do {
                let success = try await store.purchase(product)
                isPurchasing = false
                if success { dismiss() }
            } catch {
                isPurchasing = false
                purchaseError = "The purchase didn't go through. No worries — nothing was charged."
            }
        }
    }
}

// MARK: - Loading skeleton

private struct PlanCardSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: MochiTheme.cardRadius)
            .fill(MochiTheme.surfaceAlt)
            .frame(height: 66)
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: MochiTheme.Spacing.sm) {
                        Capsule().fill(MochiTheme.surface).frame(width: 120, height: 14)
                        Capsule().fill(MochiTheme.surface).frame(width: 80, height: 11)
                    }
                    Spacer()
                    Circle().fill(MochiTheme.surface).frame(width: 22, height: 22)
                }
                .padding(MochiTheme.Spacing.lg)
            )
            .opacity(pulse ? 0.55 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { if !reduceMotion { pulse = true } }
            .accessibilityLabel("Loading plans")
    }
}

// MARK: - Failed to load

private struct FailedToLoadCard: View {
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: MochiTheme.Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 30))
                .foregroundStyle(MochiTheme.textSecondary)
            Text("Couldn't load the plans — check your connection and try again.")
                .font(MochiTheme.body)
                .foregroundStyle(MochiTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(MochiTheme.surfaceAlt)
                    .padding(.horizontal, MochiTheme.Spacing.xl)
                    .padding(.vertical, MochiTheme.Spacing.md)
                    .background(MochiTheme.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MochiTheme.Spacing.xl)
    }
}

// MARK: - Pieces

private struct BenefitRow: View {
    let text: String
    var body: some View {
        HStack(spacing: MochiTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MochiTheme.success)
            Text(text)
                .font(MochiTheme.body)
                .foregroundStyle(MochiTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    private var periodLabel: String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:  return "per year"
        case .month: return "per month"
        default:     return ""
        }
    }

    private var hasFreeTrial: Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: MochiTheme.Spacing.xs) {
                    HStack(spacing: MochiTheme.Spacing.sm) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(MochiTheme.textPrimary)
                        if hasFreeTrial {
                            Text("7-day free trial")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(MochiTheme.surfaceAlt)
                                .padding(.horizontal, MochiTheme.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(MochiTheme.success)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(product.displayPrice) \(periodLabel)")
                        .font(MochiTheme.caption)
                        .foregroundStyle(MochiTheme.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? MochiTheme.primary : MochiTheme.textSecondary.opacity(0.4))
            }
            .padding(MochiTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: MochiTheme.cardRadius)
                    .fill(MochiTheme.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: MochiTheme.cardRadius)
                            .strokeBorder(isSelected ? MochiTheme.primary : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

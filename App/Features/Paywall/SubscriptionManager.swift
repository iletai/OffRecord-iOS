import StoreKit
import SwiftUI

/// Native StoreKit 2. Two auto-renewable products, the same ids xcconfig/ASC carry:
/// "<bundle id>.pro.monthly" and "<bundle id>.pro.annual". Nothing is cached server-side.
@MainActor
@Observable
final class SubscriptionManager {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Introductory offer is once per Apple ID per group; only the App Store knows the answer.
    private(set) var isEligibleForTrial = false

    private var updates: Task<Void, Never>?

    static var productIDs: [String] {
        let bundle = AppConfiguration.bundleIdentifier
        return ["\(bundle).pro.monthly", "\(bundle).pro.annual"]
    }

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    /// Monthly first, annual second: the two rows the paywall is allowed to render.
    var monthly: Product? { products.first { $0.id.hasSuffix(".pro.monthly") } }
    var annual: Product? { products.first { $0.id.hasSuffix(".pro.annual") } }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            errorMessage = loaded.isEmpty ? String(localized: "paywall.error", defaultValue: "Can't reach the App Store.") : nil
        } catch {
            errorMessage = String(localized: "paywall.error", defaultValue: "Can't reach the App Store.")
        }

        await refreshEntitlement()
        await refreshTrialEligibility()
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = String(localized: "error.generic.body", defaultValue: "The note is still on this iPhone. Try again.")
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.subscriptionGroupID == Store.groupID || transaction.productID.hasPrefix(AppConfiguration.bundleIdentifier) {
                entitled = true
            }
        }
        isPro = entitled
    }

    private func refreshTrialEligibility() async {
        guard let subscription = (monthly ?? annual)?.subscription else {
            isEligibleForTrial = false
            return
        }
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }
}

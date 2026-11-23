import StoreKit
import SwiftUI

/// Apple's paywall: the two subscriptions of the group (monthly, annual) + restore button.
/// No lifetime product exists on ASC for 1.0, so no third row may be rendered.
struct PaywallView: View {
    /// Apple requires the Terms of Use (EULA) and privacy policy to be reachable from the paywall (3.1.2).
    private var termsURL: URL? { AppConfiguration.string("LEGAL_TERMS_URL").flatMap(URL.init(string:)) }
    private var privacyURL: URL? { AppConfiguration.string("LEGAL_PRIVACY_URL").flatMap(URL.init(string:)) }

    @ViewBuilder
    var body: some View {
        let store = SubscriptionStoreView(groupID: Store.groupID)
            .storeButton(.visible, for: .restorePurchases)

        if let termsURL, let privacyURL {
            store
                .subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
                .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
        } else {
            store
        }
    }
}

#Preview {
    PaywallView()
}

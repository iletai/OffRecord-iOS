import StoreKit
import SwiftUI

/// Apple's paywall: the two subscriptions of the group (monthly, annual) + restore button.
/// No lifetime product exists on ASC for 1.0, so no third row may be rendered.
struct PaywallView: View {
    var body: some View {
        SubscriptionStoreView(groupID: Store.groupID)
            .storeButton(.visible, for: .restorePurchases)
    }
}

#Preview {
    PaywallView()
}

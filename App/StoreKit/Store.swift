import StoreKit
import SwiftUI

/// Native StoreKit 2 only (no wrapper). Product ids are "<bundle id of this environment>.pro.*",
/// so Dev/Staging/Prod ASC records never share ids; the subscription group id comes from the xcconfig.
enum Store {
    static let groupID = AppConfiguration.string("SUBSCRIPTION_GROUP_ID") ?? ""
}

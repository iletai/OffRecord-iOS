import SwiftUI

@main
struct OffRecordApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasSubscription = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.isPro, hasSubscription)
                .subscriptionStatusTask(for: Store.groupID) { state in
                    guard case .success(let statuses) = state else { return }
                    hasSubscription = statuses.contains { $0.state == .subscribed || $0.state == .inGracePeriod }
                }
        }
        .modelContainer(for: [Session.self, Segment.self, SessionNote.self])
    }
}

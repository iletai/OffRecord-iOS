import SwiftUI

@main
struct OffRecordApp: App {
    @State private var settings = AppSettings()
    @State private var subscriptions = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(subscriptions)
                .task {
                    // Entitlement and products come from the App Store; nothing is cached elsewhere.
                    await subscriptions.load()
                }
        }
        .modelContainer(for: [Session.self, Segment.self, SessionNote.self])
    }
}

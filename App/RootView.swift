import BaseNavigationStack
import SwiftUI

/// One router per navigation stack; screens read it with `@Environment(AppRouter.self)`.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var router = AppRouter()

    var body: some View {
        BaseNavigationContainer(
            router: router,
            content: { ContentView() },
            destination: { AppRouteView(route: $0) },
            sheet: { AppSheetView(sheet: $0) },
            cover: { AppCoverView(cover: $0) }
        )
        .modifier(AppLockModifier())
        .task {
            // 24-hour audio windows are pruned at launch, before anything reads the library.
            SessionPipeline.pruneExpiredAudio(in: context)
            // Onboarding is the only way in on a fresh install; it ends by showing the paywall.
            if !settings.hasCompletedOnboarding {
                router.cover = .onboarding
            }
        }
    }
}

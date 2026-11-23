import BaseNavigationStack
import SwiftUI

/// Pushed screens. Recipes (tabs, deep links): skill `iletai-libs` references/navigation.md.
enum AppRoute: Hashable, Sendable {
    case session(UUID)
    case settings
}

/// Sheets. Hash by `id` if a payload is not Hashable.
enum AppSheet: Identifiable, Hashable, Sendable {
    case paywall
    case export(UUID)

    var id: String {
        switch self {
        case .paywall: "paywall"
        case .export(let id): "export-\(id.uuidString)"
        }
    }
}

/// Full-screen covers. Recording is the only one that may appear over the library in 1.0.
enum AppCover: Identifiable, Hashable, Sendable {
    case recording(SessionTemplate)

    var id: String {
        switch self {
        case .recording(let template): "recording-\(template.rawValue)"
        }
    }
}

typealias AppRouter = NavigationRouter<AppRoute, AppSheet, AppCover>

struct AppRouteView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .session(let id): SessionDetailView(sessionID: id)
        case .settings: Text("Settings")
        }
    }
}

struct AppSheetView: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .paywall: PaywallView()
        case .export: Text("Export")
        }
    }
}

struct AppCoverView: View {
    let cover: AppCover

    var body: some View {
        switch cover {
        case .recording(let template): RecordingView(template: template)
        }
    }
}

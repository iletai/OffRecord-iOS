import LocalAuthentication
import SwiftUI

/// Locks the library when the app leaves the foreground (Settings → Privacy) and covers the
/// snapshot iOS takes for the app switcher. Biometrics first, device passcode as the fallback.
struct AppLockModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLocked = false
    @State private var leftAt: Date?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked {
                    lockScreen
                } else if settings.hideInSwitcher && scenePhase != .active {
                    switcherCover
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background, .inactive:
                    leftAt = leftAt ?? .now
                    if settings.lockEnabled { isLocked = true }
                case .active:
                    unlockIfAllowed()
                @unknown default:
                    break
                }
            }
            .onAppear {
                if settings.lockEnabled {
                    isLocked = true
                    unlockIfAllowed()
                }
            }
    }

    private var lockScreen: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                Text(String(localized: "lock.title", defaultValue: "OffRecord is locked"))
                    .font(.headline)
                Button(String(localized: "lock.unlock", defaultValue: "Unlock")) {
                    authenticate()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var switcherCover: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .accessibilityHidden(true)
    }

    private func unlockIfAllowed() {
        guard settings.lockEnabled else {
            isLocked = false
            leftAt = nil
            return
        }
        guard isLocked else {
            leftAt = nil
            return
        }
        if settings.lockDelay == .oneMinute, let leftAt, Date.now.timeIntervalSince(leftAt) < 60 {
            isLocked = false
            self.leftAt = nil
            return
        }
        authenticate()
    }

    private func authenticate() {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            isLocked = false
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "lock.reason", defaultValue: "Unlock your session notes")
        ) { success, _ in
            Task { @MainActor in
                isLocked = !success
                if success { leftAt = nil }
            }
        }
    }
}

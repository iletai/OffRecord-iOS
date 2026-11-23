import Foundation
import Observation

/// User defaults that survive launches. Anything that belongs to a session lives in SwiftData instead.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let onboarding = "settings.onboarding.completed"
        static let retention = "settings.recording.retention"
        static let template = "settings.notes.template"
        static let lock = "settings.privacy.lock"
        static let lockDelay = "settings.privacy.lockDelay"
        static let hideInSwitcher = "settings.privacy.hideInSwitcher"
    }

    /// How long the library stays locked after the app leaves the foreground.
    enum LockDelay: String, CaseIterable, Sendable {
        case immediately
        case oneMinute
    }

    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarding) }
    }

    /// Retention default `immediately` (privacy policy §7).
    var audioRetention: AudioRetention {
        didSet { defaults.set(audioRetention.rawValue, forKey: Key.retention) }
    }

    var defaultTemplate: SessionTemplate {
        didSet { defaults.set(defaultTemplate.rawValue, forKey: Key.template) }
    }

    var lockEnabled: Bool {
        didSet { defaults.set(lockEnabled, forKey: Key.lock) }
    }

    var lockDelay: LockDelay {
        didSet { defaults.set(lockDelay.rawValue, forKey: Key.lockDelay) }
    }

    var hideInSwitcher: Bool {
        didSet { defaults.set(hideInSwitcher, forKey: Key.hideInSwitcher) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarding)
        audioRetention = defaults.string(forKey: Key.retention).flatMap(AudioRetention.init(rawValue:)) ?? .immediately
        defaultTemplate = defaults.string(forKey: Key.template).flatMap(SessionTemplate.init(rawValue:)) ?? .soap
        lockEnabled = defaults.bool(forKey: Key.lock)
        lockDelay = defaults.string(forKey: Key.lockDelay).flatMap(LockDelay.init(rawValue:)) ?? .immediately
        hideInSwitcher = defaults.object(forKey: Key.hideInSwitcher) as? Bool ?? true
    }
}

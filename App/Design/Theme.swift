import SwiftUI

/// Colour and metric tokens from docs/design/DESIGN.md, so views never carry raw hex values.
enum Theme {
    static let accent = Color("AccentColor")
    static let recording = Color("RecordingCrimson")
    static let page = Color(uiColor: .systemBackground)
    static let grouped = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)

    enum Metric {
        static let screenMargin: CGFloat = 16
        static let rowPitch: CGFloat = 52
        static let primaryButtonHeight: CGFloat = 50
        static let sectionGap: CGFloat = 24
    }
}

/// "48 min" style duration used in library rows and the session header.
enum DurationText {
    static func short(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        if minutes < 1 { return String(localized: "duration.underMinute", defaultValue: "< 1 min") }
        if minutes < 60 { return String(localized: "duration.minutes", defaultValue: "\(minutes) min") }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0
            ? String(localized: "duration.hours", defaultValue: "\(hours) h")
            : String(localized: "duration.hoursMinutes", defaultValue: "\(hours) h \(rest) min")
    }

    /// 00:00 / 1:02:03 for the recording timer.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

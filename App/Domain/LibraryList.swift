import Foundation

/// A titled block of sessions in the library list.
struct SessionGroup: Identifiable {
    let id: String
    let title: String
    let sessions: [Session]
}

/// Pure grouping/filtering used by the library, kept out of the view so it can be tested.
enum LibraryList {
    /// Newest first, split into Today / Yesterday / older-day blocks with the day's date as the title.
    static func groups(
        from sessions: [Session],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [SessionGroup] {
        let sorted = sessions.sorted { $0.startedAt > $1.startedAt }
        var order: [Date] = []
        var buckets: [Date: [Session]] = [:]

        for session in sorted {
            let day = calendar.startOfDay(for: session.startedAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(session)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "MMM d"

        return order.map { day in
            SessionGroup(
                id: ISO8601DateFormatter().string(from: day),
                title: title(for: day, now: now, calendar: calendar, formatter: formatter),
                sessions: buckets[day] ?? []
            )
        }
    }

    /// nil template = the All chip.
    static func filter(_ sessions: [Session], template: SessionTemplate?) -> [Session] {
        guard let template else { return sessions }
        return sessions.filter { $0.template == template }
    }

    private static func title(for day: Date, now: Date, calendar: Calendar, formatter: DateFormatter) -> String {
        let today = calendar.startOfDay(for: now)
        if day == today { return String(localized: "library.group.today", defaultValue: "Today") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return String(localized: "library.group.yesterday", defaultValue: "Yesterday")
        }
        return formatter.string(from: day)
    }
}

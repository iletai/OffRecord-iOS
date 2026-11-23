import Foundation
import SwiftData
import Testing

@testable import OffRecord

@MainActor
struct LibraryListTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .distantPast
    }

    private func makeSession(_ startedAt: Date, template: SessionTemplate = .soap, duration: TimeInterval = 2_400) -> Session {
        Session(title: "Session", startedAt: startedAt, duration: duration, template: template, status: .ready)
    }

    @Test func groupsByDayWithNewestFirst() {
        let now = date(23, 12)
        let sessions = [
            makeSession(date(23, 9)),
            makeSession(date(23, 11)),
            makeSession(date(22, 15)),
            makeSession(date(19, 8))
        ]

        let groups = LibraryList.groups(from: sessions, now: now, calendar: calendar, locale: Locale(identifier: "en_US"))

        #expect(groups.count == 3)
        #expect(groups[0].title == "Today")
        #expect(groups[0].sessions.map(\.startedAt) == [date(23, 11), date(23, 9)])
        #expect(groups[1].title == "Yesterday")
        #expect(groups[2].title == "Nov 19")
    }

    @Test func emptyInputMakesNoGroups() {
        #expect(LibraryList.groups(from: [], now: date(23, 12), calendar: calendar).isEmpty)
    }

    @Test func filterByTemplateKeepsOnlyThatTemplate() {
        let sessions = [
            makeSession(date(23, 9), template: .soap),
            makeSession(date(23, 10), template: .dap),
            makeSession(date(23, 11), template: .dap)
        ]

        #expect(LibraryList.filter(sessions, template: nil).count == 3)
        #expect(LibraryList.filter(sessions, template: .dap).count == 2)
        #expect(LibraryList.filter(sessions, template: .interview).isEmpty)
    }

    @Test func noteTemplateHasEverySectionEmpty() {
        for template in SessionTemplate.allCases {
            let sections = SessionNote.template(template)
            #expect(sections.count == template.sections.count)
            #expect(sections.allSatisfy { $0.body.isEmpty })
            #expect(sections.map(\.heading) == template.sections)
        }
    }

    @Test func durationTextIsReadable() {
        #expect(DurationText.short(20) == "< 1 min")
        #expect(DurationText.short(30) == "1 min")
        #expect(DurationText.short(2_400) == "40 min")
        #expect(DurationText.short(5_400) == "1 h 30 min")
        #expect(DurationText.short(7_200) == "2 h")
        #expect(DurationText.clock(0) == "00:00")
        #expect(DurationText.clock(3_723) == "1:02:03")
    }
}

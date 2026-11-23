#if DEBUG
import Foundation
import SwiftData

/// Fictional sessions for store screenshots. Runs only with the `-demoSeed` launch argument; compiled out of Release.
enum DemoSeed {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-demoSeed") }

    private struct Entry {
        let title: String
        let template: SessionTemplate
        let daysAgo: Double
        let duration: TimeInterval
        let transcript: [String]
        /// One body per heading of `template`, in order.
        let sections: [String]
    }

    private static let entries = [
        Entry(
            title: "Intake, week 1", template: .soap, daysAgo: 1, duration: 1_800,
            transcript: [
                "Thanks for coming in. What brought you here this week?",
                "Mostly sleep. I wake up around three and can't get back to it.",
                "How long has that been happening?",
                "About two weeks, since the project deadline moved up."
            ],
            sections: [
                "Two weeks of broken sleep, waking around three, tied to a moved deadline.",
                "Calm and engaged. Speech is clear and no safety concerns were raised.",
                "Stress-related sleep disruption. Existing coping skills are stretched.",
                "Nightly wind-down routine. Review the sleep log next session."
            ]
        ),
        Entry(
            title: "Coaching recap", template: .coaching, daysAgo: 3, duration: 2_400,
            transcript: [
                "Last time you wanted to speak up in the Monday meeting. How did it go?",
                "I did, once. Then I didn't follow up and I felt stuck again.",
                "What would a small follow-up look like this week?"
            ],
            sections: [
                "Gaining confidence in team meetings; one clear contribution so far.",
                "Speaking up in the Monday meeting; a follow-up message was the missing step.",
                "Send one written follow-up after each meeting this week."
            ]
        ),
        Entry(
            title: "Candidate interview", template: .interview, daysAgo: 6, duration: 2_700,
            transcript: [
                "Walk me through the migration you led last year.",
                "We moved the billing service in four stages with no downtime.",
                "What was the hardest decision along the way?",
                "Keeping two write paths alive for three weeks. It cost time but it protected customers."
            ],
            sections: [
                "Senior backend role; three years of platform work described.",
                "Clear ownership of a zero-downtime migration; explains trade-offs well.",
                "\"We kept two write paths alive for three weeks.\"",
                "Ask about on-call load and how incidents are reviewed."
            ]
        )
    ]

    /// Fills an empty library and skips onboarding.
    @MainActor
    static func install(into context: ModelContext, settings: AppSettings) {
        guard requested, (try? context.fetchCount(FetchDescriptor<Session>())) == 0 else { return }
        settings.hasCompletedOnboarding = true
        for entry in entries {
            insert(entry, into: context)
        }
    }

    @MainActor
    private static func insert(_ entry: Entry, into context: ModelContext) {
        let session = Session(
            title: entry.title,
            startedAt: .now.addingTimeInterval(-entry.daysAgo * 86_400),
            duration: entry.duration,
            template: entry.template,
            status: .ready
        )
        context.insert(session)
        for (index, text) in entry.transcript.enumerated() {
            context.insert(Segment(index: index, startMS: index * 20_000, text: text, confidence: 0.92, session: session))
        }
        let blocks = zip(entry.template.sections, entry.sections).map { NoteSection(heading: $0, body: $1) }
        context.insert(SessionNote(sections: blocks, session: session))
    }
}
#endif

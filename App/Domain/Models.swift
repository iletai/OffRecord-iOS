import Foundation
import SwiftData

/// One recorded session. Audio, transcript and note are local only: the app never uploads them.
@Model
final class Session {
    var title: String
    var tag: String
    var startedAt: Date
    var duration: TimeInterval
    /// File name inside Application Support/Audio; nil once the recording was deleted.
    var audioFileName: String?
    var templateRaw: String
    var statusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \Segment.session)
    var segments: [Segment] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionNote.session)
    var note: SessionNote?

    init(
        title: String,
        tag: String = "",
        startedAt: Date = .now,
        duration: TimeInterval = 0,
        audioFileName: String? = nil,
        template: SessionTemplate,
        status: SessionStatus = .recording
    ) {
        self.title = title
        self.tag = tag
        self.startedAt = startedAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.templateRaw = template.rawValue
        self.statusRaw = status.rawValue
    }

    var template: SessionTemplate {
        get { SessionTemplate(rawValue: templateRaw) ?? .soap }
        set { templateRaw = newValue.rawValue }
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .ready }
        set { statusRaw = newValue.rawValue }
    }

    var hasAudio: Bool { audioFileName != nil }
}

/// One transcriber output block; `startMS` is the offset inside the session.
@Model
final class Segment {
    var index: Int
    var startMS: Int
    var text: String
    var confidence: Double
    var session: Session?

    init(index: Int, startMS: Int, text: String, confidence: Double = 0, session: Session? = nil) {
        self.index = index
        self.startMS = startMS
        self.text = text
        self.confidence = confidence
        self.session = session
    }
}

/// The structured note for a session. Sections keep the template's order and headings.
@Model
final class SessionNote {
    var createdAt: Date
    var editedAt: Date?
    /// Stored as `[NoteSection]`; SwiftData persists the Codable value.
    var sections: [NoteSection]
    var session: Session?

    init(sections: [NoteSection], session: Session? = nil, createdAt: Date = .now) {
        self.sections = sections
        self.createdAt = createdAt
        self.session = session
    }
}

/// A heading plus editable body text. Empty body = nothing captured (DESIGN.md §4).
struct NoteSection: Codable, Hashable, Sendable {
    var heading: String
    var body: String

    init(heading: String, body: String = "") {
        self.heading = heading
        self.body = body
    }
}

extension SessionNote {
    /// A note with every template section present but empty.
    static func template(_ template: SessionTemplate) -> [NoteSection] {
        template.sections.map { NoteSection(heading: $0) }
    }
}

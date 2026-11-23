import Foundation

/// The four note templates sold in 1.0 (PLAN.md §4). The prompt and sections live in `NoteTemplate`.
enum SessionTemplate: String, CaseIterable, Codable, Sendable, Identifiable {
    case soap
    case dap
    case coaching
    case interview

    var id: String { rawValue }

    /// Filter chip label (strings.md `library.filter.*`).
    var filterLabel: String {
        switch self {
        case .soap: "SOAP"
        case .dap: "DAP"
        case .coaching: "Coaching"
        case .interview: "Interview"
        }
    }

    /// Section headings written into the note, in order.
    var sections: [String] {
        switch self {
        case .soap: ["Subjective", "Objective", "Assessment", "Plan"]
        case .dap: ["Data", "Assessment", "Plan"]
        case .coaching: ["Where the client is", "What we worked on", "Actions"]
        case .interview: ["Context", "Key points", "Quotes", "Follow-ups"]
        }
    }
}

/// What happens to a recording after its note exists. Default is `immediately` (privacy policy §7).
enum AudioRetention: String, CaseIterable, Codable, Sendable {
    case immediately
    case day
    case keep
}

/// Where a session sits in the record → transcribe → note pipeline.
enum SessionStatus: String, Codable, Sendable {
    case recording
    case processing
    case ready
    case failed
}

import Foundation
import FoundationModels

enum NoteDraftingError: LocalizedError, Sendable {
    case unavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Structured notes aren't available on this iPhone. Write the note from the transcript."
        case .failed(let message):
            message
        }
    }
}

/// Drafts the structured note from a transcript with Apple Intelligence, on the device.
/// There is no network fallback: without the on-device model the template stays empty for the user to fill.
enum NoteDrafter {
    static var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            return NoteGenerator.isAvailable
        }
        return false
    }

    static func draft(template: SessionTemplate, transcript: String) async throws -> [NoteSection] {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NoteDraftingError.unavailable }
        guard #available(iOS 26.0, *) else { throw NoteDraftingError.unavailable }

        do {
            let bodies = try await NoteGenerator.draft(sections: template.sections, transcript: trimmed)
            return template.sections.enumerated().map { index, heading in
                NoteSection(heading: heading, body: index < bodies.count ? bodies[index] : "")
            }
        } catch {
            throw NoteDraftingError.failed(error.localizedDescription)
        }
    }
}

@available(iOS 26.0, *)
private enum NoteGenerator {
    /// Four generic slots so one generated type covers all templates (SOAP and Interview use four).
    @Generable
    struct GeneratedNote {
        @Guide(description: "Body text for the first section of the note")
        var section1: String
        @Guide(description: "Body text for the second section of the note")
        var section2: String
        @Guide(description: "Body text for the third section of the note")
        var section3: String
        @Guide(description: "Body text for the fourth section of the note, or an empty string when the template has three sections")
        var section4: String
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func draft(sections: [String], transcript: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: """
            You turn a session transcript into a structured note for the professional who ran the session.
            Use only facts present in the transcript. Never invent quotes, diagnoses, plans or numbers.
            Write in the third person, past tense, plain English. Keep each section under 120 words.
            If a section has no supporting material, return an empty string for it.
            """)

        let prompt = """
            Sections in order: \(sections.joined(separator: " | "))

            Transcript:
            \(transcript)
            """

        let response = try await session.respond(to: prompt, generating: GeneratedNote.self)
        return [response.content.section1, response.content.section2, response.content.section3, response.content.section4]
    }
}

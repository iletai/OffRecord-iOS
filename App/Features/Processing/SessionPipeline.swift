import Foundation
import SwiftData

/// Runs the local pipeline for one session: transcribe the audio, write segments, draft the note,
/// then delete the audio (retention default `immediately`, privacy policy §7). Nothing leaves the device.
@MainActor
enum SessionPipeline {
    struct Outcome {
        var transcribed: Bool
        var noteDrafted: Bool
        var failure: String?
    }

    static func process(session: Session, context: ModelContext, retention: AudioRetention) async -> Outcome {
        session.status = .processing
        try? context.save()

        var outcome = Outcome(transcribed: false, noteDrafted: false, failure: nil)
        var transcript = ""
        var blocks: [TranscriptBlock] = []

        if let name = session.audioFileName, let url = audioURL(named: name) {
            do {
                let words = try await OnDeviceTranscriber().transcribe(url: url)
                blocks = TranscriptGrouping.blocks(from: words)
                transcript = blocks.map(\.text).joined(separator: " ")
                outcome.transcribed = !blocks.isEmpty
                for (index, block) in blocks.enumerated() {
                    context.insert(Segment(index: index, startMS: block.startMS, text: block.text, session: session))
                }
            } catch {
                outcome.failure = error.localizedDescription
            }
        }

        var sections = SessionNote.template(session.template)
        if !transcript.isEmpty {
            do {
                sections = try await NoteDrafter.draft(template: session.template, transcript: transcript)
                outcome.noteDrafted = true
            } catch {
                outcome.failure = outcome.failure ?? error.localizedDescription
            }
        }

        context.insert(SessionNote(sections: sections, session: session))

        // Keep the audio only when transcription failed, so the user still has the recording;
        // otherwise apply the retention the user picked in Settings.
        if outcome.transcribed || transcript.isEmpty == false {
            if retention == .immediately {
                deleteAudio(named: session.audioFileName)
                session.audioFileName = nil
                session.audioExpiresAt = nil
            } else {
                session.audioExpiresAt = retention == .day ? Date.now.addingTimeInterval(24 * 60 * 60) : nil
            }
        }

        session.status = outcome.failure == nil ? .ready : .failed
        try? context.save()
        return outcome
    }

    /// Deletes recordings whose 24-hour window has passed (Settings → Keep audio → 24 hours).
    static func pruneExpiredAudio(in context: ModelContext, now: Date = .now) {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        var changed = false
        for session in sessions {
            guard let expiry = session.audioExpiresAt, expiry <= now else { continue }
            deleteAudio(named: session.audioFileName)
            session.audioFileName = nil
            session.audioExpiresAt = nil
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Removes every recording but keeps notes (Settings → Delete all audio).
    static func deleteAllAudio(in context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        for session in sessions {
            deleteAudio(named: session.audioFileName)
            session.audioFileName = nil
            session.audioExpiresAt = nil
        }
        try? context.save()
    }

    private static func audioURL(named name: String) -> URL? {
        guard let directory = try? SessionRecorder.audioDirectory() else { return nil }
        let url = directory.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func deleteAudio(named name: String?) {
        guard let name, let url = audioURL(named: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

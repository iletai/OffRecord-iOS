import Foundation
import SwiftData
import Testing

@testable import OffRecord

@MainActor
struct SessionPipelineTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Session.self, Segment.self, SessionNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Writes a placeholder file in the real audio directory, so pruning has something to delete.
    private func makeAudioFile() throws -> String {
        let name = "\(UUID().uuidString).m4a"
        let url = try SessionRecorder.audioDirectory().appending(path: name)
        try Data("audio".utf8).write(to: url)
        return name
    }

    @Test func prunesAudioOnceTheDayIsUp() throws {
        let context = try makeContext()
        let name = try makeAudioFile()
        let session = Session(
            title: "Expired",
            audioFileName: name,
            audioExpiresAt: .now.addingTimeInterval(-60),
            template: .soap
        )
        context.insert(session)
        try context.save()

        SessionPipeline.pruneExpiredAudio(in: context)

        #expect(session.audioFileName == nil)
        #expect(session.audioExpiresAt == nil)
        let url = try SessionRecorder.audioDirectory().appending(path: name)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func keepsAudioInsideTheWindow() throws {
        let context = try makeContext()
        let name = try makeAudioFile()
        let directory = try SessionRecorder.audioDirectory()
        defer { try? FileManager.default.removeItem(at: directory.appending(path: name)) }

        let expiry = Date.now.addingTimeInterval(60 * 60)
        let session = Session(title: "Fresh", audioFileName: name, audioExpiresAt: expiry, template: .soap)
        context.insert(session)
        try context.save()

        SessionPipeline.pruneExpiredAudio(in: context)

        #expect(session.audioFileName == name)
        #expect(session.audioExpiresAt == expiry)
    }

    @Test func keepForeverHasNoExpiry() throws {
        let context = try makeContext()
        let name = try makeAudioFile()
        let directory = try SessionRecorder.audioDirectory()
        defer { try? FileManager.default.removeItem(at: directory.appending(path: name)) }

        let session = Session(title: "Kept", audioFileName: name, audioExpiresAt: nil, template: .soap)
        context.insert(session)
        try context.save()

        SessionPipeline.pruneExpiredAudio(in: context)

        #expect(session.audioFileName == name)
    }
}

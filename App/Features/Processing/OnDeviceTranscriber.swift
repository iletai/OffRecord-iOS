import Foundation
import Speech

/// One recognised word with its offset in the recording.
struct TranscribedWord: Sendable, Equatable {
    let startMS: Int
    let durationMS: Int
    let text: String
    let confidence: Double
}

/// A group of words shown as one transcript line with a timestamp.
struct TranscriptBlock: Sendable, Equatable {
    let startMS: Int
    let text: String
}

enum TranscriptionError: LocalizedError, Sendable {
    case notAuthorized
    case onDeviceUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Speech recognition is off. The recording is kept and you can write the note by hand."
        case .onDeviceUnavailable:
            "On-device transcription isn't available here. The recording is kept and you can write the note by hand."
        case .failed(let message):
            message
        }
    }
}

/// Transcribes a recording on the device. `requiresOnDeviceRecognition` is set and there is no
/// network fallback on purpose: docs/store/privacy-policy.md §4 states audio is never uploaded.
actor OnDeviceTranscriber {
    private let locale: Locale

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    func transcribe(url: URL) async throws -> [TranscribedWord] {
        try await Self.requestAuthorization()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.taskHint = .dictation

        let result = ResumeOnce()
        result.task = recognizer.recognitionTask(with: request) { recognition, error in
            if let error {
                result.fail(TranscriptionError.failed(error.localizedDescription))
                return
            }
            guard let recognition, recognition.isFinal else { return }
            let words = recognition.bestTranscription.segments.map { segment in
                TranscribedWord(
                    startMS: Int(segment.timestamp * 1_000),
                    durationMS: Int(segment.duration * 1_000),
                    text: segment.substring,
                    confidence: Double(segment.confidence)
                )
            }
            result.succeed(words)
        }
        return try await result.value()
    }

    private static func requestAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .denied, .restricted:
            throw TranscriptionError.notAuthorized
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard status == .authorized else { throw TranscriptionError.notAuthorized }
        @unknown default:
            throw TranscriptionError.notAuthorized
        }
    }
}

/// Bridges the recognition callback to a single closure result; the callback can fire more than once.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[TranscribedWord], Error>?
    private var outcome: Result<[TranscribedWord], TranscriptionError>?
    /// Keeps the recognition task alive until it finishes; speech stops if it is released.
    var task: SFSpeechRecognitionTask?

    func value() async throws -> [TranscribedWord] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let outcome {
                lock.unlock()
                continuation.resume(with: outcome.mapError { $0 as Error })
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func succeed(_ words: [TranscribedWord]) {
        finish(.success(words))
    }

    func fail(_ error: TranscriptionError) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<[TranscribedWord], TranscriptionError>) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = result
        task = nil
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result.mapError { $0 as Error })
    }
}

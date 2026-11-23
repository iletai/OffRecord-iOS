import AVFoundation
import Foundation
import Observation

/// Records one session to a local file. Nothing is uploaded; the file lives in Application Support/Audio
/// and is deleted by the retention policy once its note exists.
@MainActor
@Observable
final class SessionRecorder {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var startedAt: Date?
    private(set) var level: Double = 0

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    /// Directory the audio files live in; created on first use.
    static func audioDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appending(path: "Audio", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Requests microphone access, then starts writing. Throws when access is denied or the session cannot start.
    func start() async throws {
        guard await Self.requestPermission() else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let url = try Self.audioDirectory().appending(path: "\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()

        self.recorder = recorder
        fileURL = url
        startedAt = .now
        isRecording = true
    }

    /// Updates `level` in 0...1 from the microphone, for the waveform.
    func sample() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = Double(recorder.averagePower(forChannel: 0))
        // -60 dB (silence) ... 0 dB (peak) mapped to 0...1.
        level = max(0, min(1, (power + 60) / 60))
    }

    /// Pauses or resumes the current recording; the elapsed time keeps the parts already captured.
    func togglePause() {
        guard let recorder else { return }
        if recorder.isRecording {
            recorder.pause()
            isPaused = true
        } else {
            recorder.record()
            isPaused = false
        }
    }

    /// Stops and returns the finished file, or nil when nothing was recorded.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let fileURL, let startedAt else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        reset()
        return (fileURL, duration)
    }

    /// Drops the current recording and deletes its file.
    func discard() {
        recorder?.stop()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        reset()
    }

    private func reset() {
        recorder = nil
        fileURL = nil
        startedAt = nil
        isRecording = false
        level = 0
    }

    private static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    enum RecorderError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "OffRecord needs the microphone to record. You can allow it in Settings."
            }
        }
    }
}

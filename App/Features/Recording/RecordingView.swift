import SwiftData
import SwiftUI

/// Full-screen recorder: one timer, one waveform, one stop control (DESIGN.md §4).
/// Stopping keeps the cover on screen while the on-device pipeline runs, then opens the session.
struct RecordingView: View {
    var template: SessionTemplate = .soap

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @State private var recorder = SessionRecorder()
    @State private var startedAt: Date?
    @State private var errorMessage: String?
    @State private var phase: Phase = .recording

    private enum Phase {
        case recording
        case processing
    }

    private let levelTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            if phase == .recording {
                timer
                waveform
                    .padding(.top, 24)
            } else {
                processing
            }
            Spacer(minLength: 0)
            controls
            footer
        }
        .padding(.horizontal, Theme.Metric.screenMargin)
        .background(Theme.page)
        .task { await start() }
        .onDisappear { recorder.discard() }
        .onReceive(levelTimer) { _ in recorder.sample() }
        .interactiveDismissDisabled()
    }

    private var topBar: some View {
        HStack {
            Button(String(localized: "recording.discard", defaultValue: "Discard")) {
                discard()
            }
            .font(.body)
            .foregroundStyle(Theme.secondaryLabel)
            .disabled(phase != .recording)

            Spacer()

            Text(template.filterLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .frame(height: 44)
    }

    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Text(DurationText.clock(elapsed))
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(recorder.isPaused ? Theme.secondaryLabel : Color.primary)
                .accessibilityLabel(String(localized: "recording.elapsed", defaultValue: "Elapsed time"))
        }
    }

    private var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date.now.timeIntervalSince(startedAt)
    }

    private var waveform: some View {
        WaveformView(level: recorder.isPaused ? 0 : recorder.level)
            .frame(height: 48)
            .accessibilityHidden(true)
    }

    private var processing: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "processing.transcribing", defaultValue: "Transcribing on this iPhone"))
                .font(.headline)
            Text(String(localized: "processing.drafting", defaultValue: "Writing the note"))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                recorder.togglePause()
            } label: {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(phase != .recording)
            .accessibilityLabel(recorder.isPaused
                ? String(localized: "recording.resume", defaultValue: "Resume")
                : String(localized: "recording.pause", defaultValue: "Pause"))

            Button(action: stopAndProcess) {
                ZStack {
                    Circle().fill(Theme.recording).frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
            .disabled(phase != .recording)
            .accessibilityLabel(String(localized: "recording.stop", defaultValue: "Stop"))
        }
        .padding(.bottom, 40)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.recording)
                    .multilineTextAlignment(.center)
            } else if phase == .recording {
                Label {
                    Text(recorder.isPaused
                        ? String(localized: "recording.statusPaused", defaultValue: "Paused · audio stays on this iPhone")
                        : String(localized: "recording.status", defaultValue: "Recording · audio stays on this iPhone"))
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
            } else {
                Text(String(localized: "recording.footer", defaultValue: "Audio is deleted after the note is created"))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private func start() async {
        do {
            try await recorder.start()
            startedAt = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndProcess() {
        guard let finished = recorder.stop(), let startedAt else {
            dismiss()
            return
        }
        let session = Session(
            title: defaultTitle(at: startedAt),
            startedAt: startedAt,
            duration: finished.duration,
            audioFileName: finished.url.lastPathComponent,
            template: template,
            status: .processing
        )
        context.insert(session)
        try? context.save()

        phase = .processing
        Task {
            await SessionPipeline.process(session: session, context: context)
            close(then: session.id)
        }
    }

    private func discard() {
        recorder.discard()
        dismiss()
    }

    private func close(then sessionID: UUID?) {
        router.cover = nil
        if let sessionID {
            router.push(.session(sessionID))
        }
    }

    private func defaultTitle(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return String(localized: "session.defaultTitle", defaultValue: "Session \(formatter.string(from: date))")
    }
}

/// Monochrome bars driven by the microphone level; silence collapses to a hairline.
struct WaveformView: View {
    let level: Double
    private let barCount = 32

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: 2, height: height(index: index, maxHeight: proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(index: Int, maxHeight: CGFloat) -> CGFloat {
        // Distance from the centre makes the middle bars taller, like a real level meter.
        let distance = abs(Double(index) - Double(barCount - 1) / 2) / (Double(barCount) / 2)
        let shape = 1 - distance * 0.7
        return max(1, CGFloat(level * shape) * maxHeight)
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: [Session.self, Segment.self, SessionNote.self], inMemory: true)
}

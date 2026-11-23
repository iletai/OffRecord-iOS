import SwiftUI

/// What a finished recording hands back to the library.
struct RecordingResult {
    let startedAt: Date
    let duration: TimeInterval
    let fileURL: URL
}

/// Full-screen recorder: one timer, one waveform, one stop control (DESIGN.md §4).
struct RecordingView: View {
    var template: SessionTemplate = .soap
    var onFinish: (RecordingResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = SessionRecorder()
    @State private var startedAt: Date?
    @State private var errorMessage: String?

    private let levelTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            timer
            waveform
                .padding(.top, 24)
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
                recorder.discard()
                dismiss()
            }
            .font(.body)
            .foregroundStyle(Theme.secondaryLabel)
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
            .accessibilityLabel(recorder.isPaused
                ? String(localized: "recording.resume", defaultValue: "Resume")
                : String(localized: "recording.pause", defaultValue: "Pause"))

            Button(action: stop) {
                ZStack {
                    Circle().fill(Theme.recording).frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
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
            } else {
                Label {
                    Text(String(
                        localized: "recording.status",
                        defaultValue: recorder.isPaused
                            ? "Paused · audio stays on this iPhone"
                            : "Recording · audio stays on this iPhone"
                    ))
                } icon: {
                    Image(systemName: "lock.shield")
                }
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

    private func stop() {
        guard let finished = recorder.stop(), let startedAt else {
            dismiss()
            return
        }
        onFinish(RecordingResult(startedAt: startedAt, duration: finished.duration, fileURL: finished.url))
        dismiss()
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
    RecordingView { _ in }
}

import AVFoundation
import Speech
import SwiftUI

/// The sample note the onboarding plays: same audio in `Resources/Sample/sample-session.m4a`,
/// written in the SOAP template the app ships. Fixed content, so it can be shown without a device model.
enum SampleSession {
    static let audioName = "sample-session"
    static let duration: TimeInterval = 26

    static let note: [NoteSection] = [
        NoteSection(
            heading: "Subjective",
            body: "Client reports sleep improved to four of seven nights and one panic episode at work this week, down from three. Used the breathing exercise before the team meeting and found it helped. Described the week as calmer overall."
        ),
        NoteSection(
            heading: "Objective",
            body: "Session reviewed the week's sleep and panic log. Client described the breathing exercise without prompting."
        ),
        NoteSection(
            heading: "Assessment",
            body: "Sleep continuity and panic frequency both improved. The coping strategy is being used in the situation it was planned for."
        ),
        NoteSection(
            heading: "Plan",
            body: "Keep the same plan for two weeks. Client continues logging episodes. Next session reviews the thought record."
        )
    ]
}

/// Three steps before the library (screens.md → Onboarding). No skip control; Continue is the only action.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var step = 0
    @State private var hasConsented = false
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            stepBars
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metric.sectionGap) {
                    switch step {
                    case 0: firstStep
                    case 1: secondStep
                    default: thirdStep
                    }
                }
                .padding(.horizontal, Theme.Metric.screenMargin)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            bottomBar
        }
        .background(Theme.page)
        .onDisappear { player?.stop() }
    }

    private var stepBars: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.accent : Theme.separator)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: String(localized: "onboarding.step", defaultValue: "Step %d of 3"), step + 1)))
    }

    private var firstStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "onboarding.one.title", defaultValue: "Nothing leaves this iPhone."))
                .font(.largeTitle.bold())
            Text(String(
                localized: "onboarding.one.body",
                defaultValue: "OffRecord records the session, transcribes it and writes the note on this device. No account, no upload, no server copy."
            ))
            .font(.body)
            .foregroundStyle(Theme.secondaryLabel)
            VStack(alignment: .leading, spacing: 12) {
                row("mic", String(localized: "onboarding.one.row.record", defaultValue: "Records in the room"))
                row("waveform", String(localized: "onboarding.one.row.transcribe", defaultValue: "Transcribes on device"))
                row("internaldrive", String(localized: "onboarding.one.row.store", defaultValue: "Stored on this iPhone"))
            }
            Text(String(localized: "onboarding.one.footer", defaultValue: "The recording is deleted as soon as the note is created."))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    private var secondStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "onboarding.two.title", defaultValue: "What this iPhone can do"))
                .font(.largeTitle.bold())
            capability(
                String(localized: "onboarding.two.row.mic", defaultValue: "Microphone"),
                isOn: AVAudioApplication.shared.recordPermission == .granted
            )
            capability(
                String(localized: "onboarding.two.row.speech", defaultValue: "Speech recognition"),
                isOn: SFSpeechRecognizer.authorizationStatus() == .authorized
            )
            capability(
                String(localized: "onboarding.two.row.notes", defaultValue: "Structured notes"),
                isOn: NoteDrafter.isAvailable
            )
            if !NoteDrafter.isAvailable {
                Text(String(
                    localized: "onboarding.two.capability",
                    defaultValue: "Structured notes aren't available on this iPhone. Transcription still works."
                ))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
            }
        }
    }

    private var thirdStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "onboarding.three.title", defaultValue: "Try it on 30 seconds of audio"))
                .font(.largeTitle.bold())
            Text(String(
                localized: "onboarding.three.body",
                defaultValue: "Play the sample, then look at the note it produced. Nothing is uploaded."
            ))
            .font(.body)
            .foregroundStyle(Theme.secondaryLabel)

            Button {
                toggleSample()
            } label: {
                Label(
                    isPlaying
                        ? String(localized: "onboarding.three.playing", defaultValue: "Playing the sample")
                        : String(localized: "onboarding.three.play", defaultValue: "Play sample"),
                    systemImage: isPlaying ? "stop.fill" : "play.fill"
                )
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Theme.grouped, in: .capsule)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(SampleSession.note, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.heading)
                            .font(.subheadline.weight(.semibold))
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.grouped, in: .rect(cornerRadius: 16))

            Toggle(isOn: $hasConsented) {
                Text(String(
                    localized: "onboarding.three.consent",
                    defaultValue: "I understand the microphone is needed to record a session."
                ))
                .font(.footnote)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                advance()
            } label: {
                Text(isLastStep
                    ? String(localized: "onboarding.three.action", defaultValue: "Start using OffRecord")
                    : String(localized: "common.continue", defaultValue: "Continue"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Metric.primaryButtonHeight)
                .background(Theme.accent.opacity(canAdvance ? 1 : 0.4), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var isLastStep: Bool { step == stepCount - 1 }
    private var canAdvance: Bool { !isLastStep || hasConsented }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text).font(.body)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func capability(_ title: String, isOn: Bool) -> some View {
        HStack {
            Text(title).font(.body)
            Spacer()
            Text(isOn
                ? String(localized: "onboarding.two.value.on", defaultValue: "On")
                : String(localized: "onboarding.two.value.off", defaultValue: "Off"))
            .font(.subheadline)
            .foregroundStyle(isOn ? Theme.accent : Theme.secondaryLabel)
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.separator).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func advance() {
        guard canAdvance else { return }
        if isLastStep {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
        }
    }

    private func finish() {
        player?.stop()
        settings.hasCompletedOnboarding = true
        router.cover = nil
        if !subscriptions.isPro {
            router.sheet = .paywall
        }
    }

    private func toggleSample() {
        if isPlaying {
            player?.stop()
            isPlaying = false
            return
        }
        guard let url = Bundle.main.url(forResource: SampleSession.audioName, withExtension: "m4a") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        isPlaying = true
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(SubscriptionManager())
        .environment(AppRouter())
}

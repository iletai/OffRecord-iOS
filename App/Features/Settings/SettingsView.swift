import LocalAuthentication
import SwiftData
import SwiftUI

/// Five sections in the rendered order (screens.md → Settings). Every row here changes real behaviour.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isErasePresented = false
    @State private var eraseConfirmation = ""
    @State private var storageSize = "—"
    @State private var notice: String?

    var body: some View {
        Form {
            privacySection
            recordingSection
            notesSection
            subscriptionSection
            aboutSection
        }
        .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            storageSize = AudioStorage.sizeText()
            if subscriptions.products.isEmpty {
                await subscriptions.load()
            }
        }
        .alert(
            String(localized: "settings.eraseConfirm.title", defaultValue: "Erase all local data?"),
            isPresented: $isErasePresented
        ) {
            TextField(String(localized: "settings.eraseConfirm.field", defaultValue: "Type ERASE to confirm"), text: $eraseConfirmation)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                eraseConfirmation = ""
            }
            Button(String(localized: "common.delete", defaultValue: "Delete"), role: .destructive) {
                eraseAll()
            }
            .disabled(eraseConfirmation.uppercased() != "ERASE")
        } message: {
            Text(String(
                localized: "settings.eraseConfirm.body",
                defaultValue: "This deletes every session, note and template change on this iPhone. It cannot be undone."
            ))
        }
    }

    // MARK: - Sections

    private var privacySection: some View {
        @Bindable var settings = settings
        return Section {
            Toggle(isOn: $settings.lockEnabled) {
                Label(String(localized: "settings.privacy.faceID", defaultValue: "Unlock with Face ID"), systemImage: "faceid")
            }
            if settings.lockEnabled {
                Picker(String(localized: "settings.privacy.lockWhenLeaving", defaultValue: "Lock when leaving"), selection: $settings.lockDelay) {
                    Text(String(localized: "settings.privacy.lockValue.immediately", defaultValue: "Immediately"))
                        .tag(AppSettings.LockDelay.immediately)
                    Text(String(localized: "settings.privacy.lockValue.oneMinute", defaultValue: "After 1 minute"))
                        .tag(AppSettings.LockDelay.oneMinute)
                }
            }
            Toggle(isOn: $settings.hideInSwitcher) {
                Label(
                    String(localized: "settings.privacy.hideInSwitcher", defaultValue: "Hide content in the app switcher"),
                    systemImage: "rectangle.on.rectangle.slash"
                )
            }
            Button(role: .destructive) {
                eraseConfirmation = ""
                isErasePresented = true
            } label: {
                Text(String(localized: "settings.privacy.erase", defaultValue: "Erase all local data"))
            }
        } header: {
            Text(String(localized: "settings.privacy.header", defaultValue: "Privacy"))
        } footer: {
            Text(String(
                localized: "settings.privacy.footer",
                defaultValue: "Erasing removes every session and note on this iPhone. There is no cloud copy."
            ))
        }
    }

    private var recordingSection: some View {
        @Bindable var settings = settings
        return Section {
            Picker(String(localized: "settings.recording.keepAudio", defaultValue: "Keep audio"), selection: $settings.audioRetention) {
                Text(String(localized: "settings.recording.keepValue.immediately", defaultValue: "Immediately"))
                    .tag(AudioRetention.immediately)
                Text(String(localized: "settings.recording.keepValue.24h", defaultValue: "24 hours"))
                    .tag(AudioRetention.day)
                Text(String(localized: "settings.recording.keepValue.keep", defaultValue: "Keep"))
                    .tag(AudioRetention.keep)
            }
            LabeledContent(
                String(localized: "settings.recording.maxLength", defaultValue: "Max session length"),
                value: String(localized: "settings.recording.maxLength.value", defaultValue: "90 minutes")
            )
            LabeledContent(
                String(localized: "settings.recording.storage", defaultValue: "Audio storage"),
                value: storageSize
            )
            Button(String(localized: "settings.recording.deleteAllAudio", defaultValue: "Delete all audio"), role: .destructive) {
                SessionPipeline.deleteAllAudio(in: context)
                storageSize = AudioStorage.sizeText()
                notice = String(localized: "settings.recording.deleteAllAudio.done", defaultValue: "All audio deleted. Notes kept.")
            }
        } header: {
            Text(String(localized: "settings.recording.header", defaultValue: "Recording"))
        } footer: {
            if let notice {
                Text(notice)
            }
        }
    }

    private var notesSection: some View {
        @Bindable var settings = settings
        return Section {
            Picker(String(localized: "settings.notes.defaultTemplate", defaultValue: "Default template"), selection: $settings.defaultTemplate) {
                ForEach(SessionTemplate.allCases) { template in
                    Text(template.filterLabel).tag(template)
                }
            }
        } header: {
            Text(String(localized: "settings.notes.header", defaultValue: "Notes"))
        } footer: {
            Text(String(
                localized: "settings.notes.footer",
                defaultValue: "Templates run on this iPhone. No text is sent anywhere."
            ))
        }
    }

    private var subscriptionSection: some View {
        Section {
            LabeledContent(
                String(localized: "settings.subscription.currentPlan", defaultValue: "Current plan"),
                value: subscriptions.isPro
                    ? String(localized: "settings.subscription.planValue", defaultValue: "Pro, annual")
                    : String(localized: "settings.subscription.planValue.free", defaultValue: "Free")
            )
            if subscriptions.isPro {
                Link(
                    String(localized: "settings.subscription.manage", defaultValue: "Manage"),
                    destination: URL(string: "https://apps.apple.com/account/subscriptions") ?? URL(filePath: "/")
                )
            } else {
                Button(String(localized: "paywall.title", defaultValue: "OffRecord Pro")) {
                    dismiss()
                    router.sheet = .paywall
                }
            }
            Button(String(localized: "settings.subscription.restore", defaultValue: "Restore purchases")) {
                Task {
                    _ = await subscriptions.restore()
                    notice = subscriptions.isPro
                        ? String(localized: "paywall.restored", defaultValue: "Purchases restored.")
                        : subscriptions.errorMessage
                }
            }
        } header: {
            Text(String(localized: "settings.subscription.header", defaultValue: "Subscription"))
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(
                String(localized: "settings.about.version", defaultValue: "Version"),
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
            if let terms = AppConfiguration.string("LEGAL_TERMS_URL").flatMap(URL.init(string:)) {
                Link(String(localized: "common.terms", defaultValue: "Terms of use"), destination: terms)
            }
            if let privacy = AppConfiguration.string("LEGAL_PRIVACY_URL").flatMap(URL.init(string:)) {
                Link(String(localized: "common.privacyPolicy", defaultValue: "Privacy policy"), destination: privacy)
            }
        } header: {
            Text(String(localized: "settings.about.header", defaultValue: "About"))
        }
    }

    // MARK: - Erase

    private func eraseAll() {
        SessionPipeline.deleteAllAudio(in: context)
        try? context.delete(model: Segment.self)
        try? context.delete(model: SessionNote.self)
        try? context.delete(model: Session.self)
        try? context.save()

        eraseConfirmation = ""
        settings.audioRetention = .immediately
        settings.defaultTemplate = .soap
        settings.lockEnabled = false
        settings.hideInSwitcher = true
        settings.hasCompletedOnboarding = false

        storageSize = AudioStorage.sizeText()
        router.path.removeAll()
        router.cover = .onboarding
    }
}

/// Size of every file in Application Support/Audio, for the Recording section.
@MainActor
enum AudioStorage {
    static func sizeText() -> String {
        guard let directory = try? SessionRecorder.audioDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.fileSizeKey]
              )
        else { return "0 MB" }

        let bytes = files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
        guard bytes > 0 else { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

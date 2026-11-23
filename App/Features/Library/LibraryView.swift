import SwiftData
import SwiftUI

/// Root screen: every session on this iPhone, newest first, with the record action pinned to the bottom.
struct LibraryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionManager.self) private var subscriptions
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    @State private var filter: SessionTemplate?

    private var visibleSessions: [Session] {
        LibraryList.filter(sessions, template: filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                filterBar
                content
            }
            .padding(.bottom, Theme.Metric.sectionGap)
        }
        .background(Theme.page)
        .safeAreaInset(edge: .bottom) { recordButton }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "library.title", defaultValue: "Sessions"))
                    .font(.largeTitle.bold())
                Text(String(localized: "library.subtitle", defaultValue: "Stored on this iPhone only"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            Spacer(minLength: 8)
            Button {
                router.push(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: .circle)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "settings.title", defaultValue: "Settings"))
        }
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: String(localized: "library.filter.all", defaultValue: "All"), template: nil)
                ForEach(SessionTemplate.allCases) { template in
                    chip(title: template.filterLabel, template: template)
                }
            }
            .padding(.horizontal, Theme.Metric.screenMargin)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func chip(title: String, template: SessionTemplate?) -> some View {
        let selected = filter == template
        return Button {
            filter = template
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.page : Theme.secondaryLabel)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(selected ? Theme.accent : Color(uiColor: .secondarySystemBackground), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if sessions.isEmpty {
            emptyState
        } else {
            let groups = LibraryList.groups(from: visibleSessions)
            if groups.isEmpty {
                Text(String(localized: "library.filter.empty", defaultValue: "No sessions with this template yet."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        sectionHeader(group.title)
                        ForEach(group.sessions) { session in
                            SessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture { router.push(.session(session.id)) }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondaryLabel)
            .padding(.horizontal, Theme.Metric.screenMargin)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "library.empty.title", defaultValue: "No sessions yet"))
                .font(.title3.weight(.semibold))
            Text(String(
                localized: "library.empty.body",
                defaultValue: "Record a session and the note is written on this iPhone. The audio is deleted as soon as the note is created."
            ))
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: 280, alignment: .leading)
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.top, 48)
    }

    private var recordButton: some View {
        Button {
            // Recording a new session needs Pro (store description → Pricing); the paywall explains why.
            if subscriptions.isPro {
                router.cover = .recording(filter ?? settings.defaultTemplate)
            } else {
                router.sheet = .paywall
            }
        } label: {
            Label(
                String(localized: "library.newSession", defaultValue: "New session"),
                systemImage: subscriptions.isPro ? "mic.fill" : "lock.fill"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Metric.primaryButtonHeight)
            .background(Theme.accent, in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

/// Row for one session: template + duration + what happened to the audio.
struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.tertiaryLabel)
        }
        .padding(.horizontal, Theme.Metric.screenMargin)
        .frame(minHeight: Theme.Metric.rowPitch)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
                .padding(.leading, Theme.Metric.screenMargin)
        }
        .accessibilityElement(children: .combine)
    }

    private var metadata: String {
        let audio = session.hasAudio
            ? String(localized: "library.row.audioKept", defaultValue: "Audio kept 24h")
            : String(localized: "library.row.audioDeleted", defaultValue: "Audio deleted")
        return "\(session.template.filterLabel) · \(DurationText.short(session.duration)) · \(audio)"
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(SubscriptionManager())
        .modelContainer(for: [Session.self, Segment.self, SessionNote.self], inMemory: true)
}

import SwiftData
import SwiftUI

/// One session: the note and the transcript, one control apart (screens.md → Session detail).
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var sessions: [Session]

    @State private var segment: Segment = .note
    @State private var drafts: [NoteSection] = []
    @State private var loadedNoteID: PersistentIdentifier?
    @FocusState private var focusedSection: Int?

    private let sessionID: UUID

    private enum Segment: Hashable {
        case note
        case transcript
    }

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionID })
    }

    private var session: Session? { sessions.first }

    var body: some View {
        Group {
            if let session {
                content(for: session)
            } else {
                ContentUnavailableView(
                    String(localized: "session.title", defaultValue: "Session"),
                    systemImage: "doc.text",
                    description: Text(String(localized: "session.missing", defaultValue: "This session is no longer on this iPhone."))
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let session else { return }
                    persistNote()
                    router.sheet = .export(session.id)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(session == nil)
                .accessibilityLabel(String(localized: "session.action.share", defaultValue: "Share or export"))
            }
        }
        .onDisappear { persistNote() }
    }

    private func content(for session: Session) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metric.sectionGap) {
                header(session)
                switch segment {
                case .note: noteBody(session)
                case .transcript: transcriptBody(session)
                }
            }
            .padding(.horizontal, Theme.Metric.screenMargin)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .top) { picker }
        .scrollDismissesKeyboard(.interactively)
    }

    private var picker: some View {
        Picker("", selection: $segment) {
            Text(String(localized: "session.segment.note", defaultValue: "Note")).tag(Segment.note)
            Text(String(localized: "session.segment.transcript", defaultValue: "Transcript")).tag(Segment.transcript)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Metric.screenMargin)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func header(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.title2.bold())
            Text(meta(session))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func noteBody(_ session: Session) -> some View {
        if let note = session.note {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(drafts.enumerated()), id: \.offset) { index, section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.headline)
                        TextEditor(text: binding(for: index))
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .focused($focusedSection, equals: index)
                            .frame(minHeight: 76)
                            .padding(8)
                            .background(Theme.grouped, in: .rect(cornerRadius: 12))
                            .accessibilityLabel(Text(section.heading))
                    }
                }
            }
            .onAppear { load(note) }
            .onChange(of: focusedSection) { _, newValue in
                if newValue == nil { persistNote() }
            }
        } else {
            emptyBody
        }
    }

    @ViewBuilder
    private func transcriptBody(_ session: Session) -> some View {
        let blocks = session.segments.sorted { $0.index < $1.index }
        if blocks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                emptyBody
                Text(String(
                    localized: "transcription.unavailable.body",
                    defaultValue: "On-device speech recognition does not cover this language on this iPhone. OffRecord does not send audio to Apple to get around that: your recording is kept and the note is yours to write."
                ))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryLabel)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(TranscriptGrouping.timestamp(block.startMS))
                            .font(.monospaced(.footnote)())
                            .foregroundStyle(Theme.tertiaryLabel)
                        Text(block.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var emptyBody: some View {
        Text(String(localized: "session.emptySection", defaultValue: "No content captured for this session."))
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryLabel)
    }

    private func meta(_ session: Session) -> String {
        let words = TranscriptGrouping.wordCount(transcriptBlocks(for: session))
        let audio = session.hasAudio
            ? String(localized: "library.row.audioKept", defaultValue: "Audio kept 24h")
            : String(localized: "library.row.audioDeleted", defaultValue: "Audio deleted")
        return "\(session.template.filterLabel) · \(words) words · \(audio)"
    }

    private func transcriptBlocks(for session: Session) -> [TranscriptBlock] {
        session.segments.sorted { $0.index < $1.index }.map {
            TranscriptBlock(startMS: $0.startMS, text: $0.text)
        }
    }

    // MARK: - Editing

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { drafts.indices.contains(index) ? drafts[index].body : "" },
            set: { newValue in
                guard drafts.indices.contains(index) else { return }
                drafts[index].body = newValue
            }
        )
    }

    private func load(_ note: SessionNote) {
        guard loadedNoteID != note.persistentModelID else { return }
        loadedNoteID = note.persistentModelID
        drafts = note.sections
    }

    /// Writes the edited sections back and stamps the edit time; called when a section loses focus.
    private func persistNote() {
        guard let note = session?.note else { return }
        guard drafts != note.sections else { return }
        note.sections = drafts
        note.editedAt = .now
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionID: UUID())
    }
    .environment(AppRouter())
    .modelContainer(for: [Session.self, Segment.self, SessionNote.self], inMemory: true)
}

import CoreText
import SwiftData
import SwiftUI
import UIKit

/// Export one note as PDF, Markdown or plain text (screens.md → Export sheet).
struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [Session]

    @State private var format: Format = .pdf
    @State private var includeTranscript = false
    @State private var exported: URL?
    @State private var errorMessage: String?

    private let sessionID: UUID

    enum Format: String, CaseIterable, Identifiable {
        case pdf
        case markdown
        case text

        var id: String { rawValue }

        var label: String {
            switch self {
            case .pdf: String(localized: "export.format.pdf", defaultValue: "PDF")
            case .markdown: String(localized: "export.format.markdown", defaultValue: "Markdown")
            case .text: String(localized: "export.format.text", defaultValue: "Plain text")
            }
        }
    }

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionID })
    }

    private var session: Session? { sessions.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $format) {
                        ForEach(Format.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(String(localized: "export.title", defaultValue: "Export")))

                    if !(session?.segments.isEmpty ?? true) {
                        Toggle(String(localized: "export.includeTranscript", defaultValue: "Include transcript"), isOn: $includeTranscript)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.recording)
                    }
                }

                Section {
                    if let exported {
                        ShareLink(item: exported) {
                            Label(
                                String(localized: "export.share", defaultValue: "Share the file"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    } else {
                        Button(String(localized: "export.create", defaultValue: "Create file")) {
                            createFile()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "export.title", defaultValue: "Export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close", defaultValue: "Close")) { dismiss() }
                }
            }
        }
    }

    private func createFile() {
        guard let session else { return }
        do {
            exported = try Exporter.file(for: session, format: format, includeTranscript: includeTranscript)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "export.error", defaultValue: "Couldn't create the PDF.")
            exported = nil
        }
    }
}

/// Builds the three export formats. Files go to the temporary directory; the share sheet decides where next.
enum Exporter {
    static func file(for session: Session, format: ExportSheet.Format, includeTranscript: Bool) throws -> URL {
        let title = "\(session.title) — \(dateText(session.startedAt))"
        let body = bodyText(session, includeTranscript: includeTranscript)
        let stem = sanitized(session.title)
        let directory = FileManager.default.temporaryDirectory

        switch format {
        case .text:
            let url = directory.appending(path: "\(stem).txt")
            try "\(title)\n\n\(body)".write(to: url, atomically: true, encoding: .utf8)
            return url
        case .markdown:
            let url = directory.appending(path: "\(stem).md")
            let markdown = "# \(title)\n\n\(markdownBody(session, includeTranscript: includeTranscript))"
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        case .pdf:
            let url = directory.appending(path: "\(stem).pdf")
            try pdf(title: title, body: body, to: url)
            return url
        }
    }

    private static func bodyText(_ session: Session, includeTranscript: Bool) -> String {
        let sections = session.note?.sections ?? SessionNote.template(session.template)
        var lines = sections.map { "\($0.heading)\n\($0.body)" }
        if includeTranscript {
            let transcript = session.segments.sorted { $0.index < $1.index }
                .map { "[\(TranscriptGrouping.timestamp($0.startMS))] \($0.text)" }
                .joined(separator: "\n")
            if !transcript.isEmpty {
                lines.append("Transcript\n\(transcript)")
            }
        }
        return lines.joined(separator: "\n\n")
    }

    private static func markdownBody(_ session: Session, includeTranscript: Bool) -> String {
        let sections = session.note?.sections ?? SessionNote.template(session.template)
        var parts = sections.map { "## \($0.heading)\n\n\($0.body)" }
        if includeTranscript {
            let transcript = session.segments.sorted { $0.index < $1.index }
                .map { "- `\(TranscriptGrouping.timestamp($0.startMS))` \($0.text)" }
                .joined(separator: "\n")
            if !transcript.isEmpty {
                parts.append("## Transcript\n\n\(transcript)")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    private static func pdf(title: String, body: String, to url: URL) throws {
        let pageSize = CGSize(width: 595, height: 842)
        let margin: CGFloat = 56
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let heading = NSAttributedString(
            string: title + "\n\n",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black]
        )
        let text = NSMutableAttributedString(attributedString: heading)
        text.append(NSAttributedString(
            string: body,
            attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]
        ))

        try renderer.writePDF(to: url) { context in
            let framesetter = CTFramesetterCreateWithAttributedString(text)
            var location = 0

            while location < text.length {
                context.beginPage()
                let bounds = CGRect(
                    x: margin,
                    y: margin,
                    width: pageSize.width - margin * 2,
                    height: pageSize.height - margin * 2
                )
                let path = CGPath(rect: bounds, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRangeMake(location, 0),
                    path,
                    nil
                )
                CTFrameDraw(frame, context.cgContext)
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { break }
                location += visible.length
            }
        }
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func sanitized(_ title: String) -> String {
        let allowed = title.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let name = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? "session" : name
    }
}

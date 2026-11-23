import Foundation

/// Turns recognised words into transcript lines. Pure so it can be tested without a recording.
enum TranscriptGrouping {
    /// Splits on a pause longer than `maxGapMS` or when a line already reads as a sentence.
    static func blocks(from words: [TranscribedWord], maxGapMS: Int = 1_200, maxChars: Int = 220) -> [TranscriptBlock] {
        var blocks: [TranscriptBlock] = []
        var current: [TranscribedWord] = []

        func flush() {
            guard let first = current.first else { return }
            blocks.append(TranscriptBlock(startMS: first.startMS, text: current.map(\.text).joined(separator: " ")))
            current = []
        }

        for word in words {
            if let last = current.last {
                let gap = word.startMS - (last.startMS + last.durationMS)
                let length = current.reduce(0) { $0 + $1.text.count + 1 }
                let endsSentence = last.text.hasSuffix(".") || last.text.hasSuffix("?") || last.text.hasSuffix("!")
                if gap > maxGapMS || length > maxChars || (endsSentence && current.count >= 6) {
                    flush()
                }
            }
            current.append(word)
        }
        flush()
        return blocks
    }

    /// Timestamp shown next to a transcript line: 00:12 / 1:02:03.
    static func timestamp(_ milliseconds: Int) -> String {
        let total = max(0, milliseconds / 1_000)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// Words in a transcript, for the session meta line.
    static func wordCount(_ blocks: [TranscriptBlock]) -> Int {
        blocks.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }
}

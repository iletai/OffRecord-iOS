import Foundation
import Testing

@testable import OffRecord

struct TranscriptGroupingTests {
    private func word(_ text: String, start: Int, duration: Int = 300) -> TranscribedWord {
        TranscribedWord(startMS: start, durationMS: duration, text: text, confidence: 0.9)
    }

    @Test func splitsOnLongPause() {
        let words = [
            word("Hello", start: 0),
            word("there", start: 400),
            word("Again", start: 3_000)
        ]

        let blocks = TranscriptGrouping.blocks(from: words, maxGapMS: 1_200)

        #expect(blocks.count == 2)
        #expect(blocks[0] == TranscriptBlock(startMS: 0, text: "Hello there"))
        #expect(blocks[1] == TranscriptBlock(startMS: 3_000, text: "Again"))
    }

    @Test func keepsShortPausesInOneBlock() {
        let words = (0..<4).map { word("word\($0)", start: $0 * 500) }

        let blocks = TranscriptGrouping.blocks(from: words, maxGapMS: 1_200)

        #expect(blocks.count == 1)
        #expect(blocks[0].text == "word0 word1 word2 word3")
    }

    @Test func splitsSentenceOnceItIsLongEnough() {
        let words = [
            word("One", start: 0),
            word("two", start: 400),
            word("three", start: 800),
            word("four", start: 1_200),
            word("five", start: 1_600),
            word("six.", start: 2_000),
            word("Seven", start: 2_400)
        ]

        let blocks = TranscriptGrouping.blocks(from: words, maxGapMS: 5_000)

        #expect(blocks.count == 2)
        #expect(blocks[0].text == "One two three four five six.")
        #expect(blocks[1].text == "Seven")
    }

    @Test func timestampsReadAsClockTime() {
        #expect(TranscriptGrouping.timestamp(0) == "00:00")
        #expect(TranscriptGrouping.timestamp(12_000) == "00:12")
        #expect(TranscriptGrouping.timestamp(3_723_000) == "1:02:03")
    }

    @Test func wordCountCountsAcrossBlocks() {
        let blocks = [
            TranscriptBlock(startMS: 0, text: "One two three"),
            TranscriptBlock(startMS: 5_000, text: "four")
        ]

        #expect(TranscriptGrouping.wordCount(blocks) == 4)
        #expect(TranscriptGrouping.wordCount([]) == 0)
    }

    @Test func emptyWordsMakeNoBlocks() {
        #expect(TranscriptGrouping.blocks(from: []).isEmpty)
    }
}

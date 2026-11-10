import Foundation
import KugouLyricsCore

struct LRCParserTests {
    func parsesMetadataMultipleTimestampsAndFractions() throws {
        let document = try LRCParser.parse("""
        [ti:Song]
        [ar:Artist]
        [offset:+500]
        [00:01.00][00:03.250]Same line
        [00:05.5]Half second
        """)

        try expectEqual(document.title, "Song")
        try expectEqual(document.artist, "Artist")
        try expectEqual(document.offset, 0.5, accuracy: 0.001)
        try expectEqual(document.lines, [
            LyricLine(start: 1, text: "Same line"),
            LyricLine(start: 3.25, text: "Same line"),
            LyricLine(start: 5.5, text: "Half second")
        ])
        try expectNil(document.lineIndex(at: 1.49))
        try expectEqual(document.lineIndex(at: 1.5), 0)
    }

    func skipsMalformedLinesAndEmptyText() throws {
        let document = try LRCParser.parse("not a lyric\n[00:01.00]\n[00:02.00]Valid")
        try expectEqual(document.lines, [LyricLine(start: 2, text: "Valid")])
    }

    func rejectsTextWithoutTimedLyrics() throws {
        try expectThrows({ _ = try LRCParser.parse("[ti:Only metadata]") }) {
            try expectEqual($0 as? LRCParserError, .noTimedLines)
        }
    }
}

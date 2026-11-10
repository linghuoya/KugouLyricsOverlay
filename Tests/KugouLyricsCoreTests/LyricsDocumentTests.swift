import Foundation
import KugouLyricsCore

struct LyricsColorPresetTests {
    func restoresSavedSelectionAndDefaultsToWhite() throws {
        try expectEqual(LyricsColorPreset(storedValue: "yellow"), .yellow)
        try expectEqual(LyricsColorPreset(storedValue: "cyan"), .cyan)
        try expectEqual(LyricsColorPreset(storedValue: "orange"), .orange)
        try expectEqual(LyricsColorPreset(storedValue: "invalid"), .white)
        try expectEqual(LyricsColorPreset(storedValue: nil), .white)
    }
}

struct LyricsDocumentTests {
    private let document = LyricsDocument(lines: [
        LyricLine(start: 1, text: "One"),
        LyricLine(start: 2, text: "Two"),
        LyricLine(start: 4, text: "Three")
    ])

    func lineIndexHandlesIntroBoundariesAndTail() throws {
        try expectNil(document.lineIndex(at: 0.99))
        try expectEqual(document.lineIndex(at: 1), 0)
        try expectEqual(document.lineIndex(at: 2.1), 1)
        try expectEqual(document.lineIndex(at: 100), 2)
    }

    func positiveOffsetDelaysLyrics() throws {
        let document = LyricsDocument(lines: [LyricLine(start: 1, text: "One")], offset: 0.5)
        try expectNil(document.lineIndex(at: 1.49))
        try expectEqual(document.lineIndex(at: 1.5), 0)
    }
}

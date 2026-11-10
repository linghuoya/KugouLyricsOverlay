import Foundation
import KugouLyricsCore

struct LyricsWindowTests {
    private let document = LyricsDocument(lines: (0..<5).map {
        LyricLine(start: Double($0 + 1), text: "Line \($0 + 1)")
    })

    func buildsThreeAndFiveLineWindows() throws {
        let three = document.window(at: 2.1, count: 3)
        try expectEqual(three.map(\.text), ["Line 1", "Line 2", "Line 3"])
        try expectEqual(three.map(\.isCurrent), [false, true, false])

        let five = document.window(at: 3.1, count: 5)
        try expectEqual(five.map(\.text), ["Line 1", "Line 2", "Line 3", "Line 4", "Line 5"])
        try expectEqual(five.map(\.isCurrent), [false, false, true, false, false])
    }

    func padsBoundariesAndLeavesIntroEmpty() throws {
        let first = document.window(at: 1, count: 3)
        try expectEqual(first.map(\.text), ["", "Line 1", "Line 2"])
        try expectEqual(first.map(\.isCurrent), [false, true, false])
        try expect(document.window(at: 0, count: 5).isEmpty, "Intro should not show a lyric window")
    }

    func tracksCurrentWordUsingLineRelativeTimingAndOffset() throws {
        let document = LyricsDocument(lines: [
            LyricLine(start: 10, duration: 2, text: "大雨", words: [
                LyricWord(start: 0.1, duration: 0.3, text: "大"),
                LyricWord(start: 0.4, duration: 0.5, text: "雨")
            ])
        ], offset: 0.2)

        try expectEqual(document.window(at: 10.25, count: 1).first?.activeWordIndex, nil)
        try expectEqual(document.window(at: 10.3, count: 1).first?.activeWordIndex, 0)
        try expectEqual(document.window(at: 10.5, count: 1).first?.activeWordIndex, 0)
        try expectEqual(document.window(at: 10.6, count: 1).first?.activeWordIndex, 1)
        try expectEqual(document.window(at: 11.5, count: 1).first?.activeWordIndex, 1)
        try expectEqual(document.window(at: 10.25, count: 1).first?.wordPosition, nil)
        try expectEqual(document.window(at: 10.3, count: 1).first?.wordPosition, 0, accuracy: 0.001)
        try expectEqual(document.window(at: 10.45, count: 1).first?.wordPosition, 0.5, accuracy: 0.001)
        try expectEqual(document.window(at: 10.6, count: 1).first?.wordPosition, 1, accuracy: 0.001)
        try expectEqual(document.window(at: 11.5, count: 1).first?.wordPosition, 1, accuracy: 0.001)
    }

    func groupsContinuousWordsForWaveMotion() throws {
        let text = "hello world"
        let words = text.enumerated().map { index, character in
            LyricWord(start: Double(index) * 0.25, duration: 0.25, text: String(character))
        }
        let document = LyricsDocument(lines: [
            LyricLine(start: 0, text: text, words: words)
        ])

        let firstWord = document.window(at: 0, count: 1).first
        try expectEqual(firstWord?.phraseRanges, [0..<5, 6..<11])
        try expectEqual(firstWord?.activePhraseRange, 0..<5)
        try expectEqual(firstWord?.highlightedWordRange, 0..<1)
        try expectEqual(firstWord?.phrasePosition, 0, accuracy: 0.001)
        try expectEqual(firstWord?.activeWordIndex, 0)

        let sameWord = document.window(at: 0.75, count: 1).first
        try expectEqual(sameWord?.phraseRanges, [0..<5, 6..<11])
        try expectEqual(sameWord?.activePhraseRange, 0..<5)
        try expectEqual(sameWord?.highlightedWordRange, 0..<4)
        try expectEqual(sameWord?.phrasePosition, 0.6, accuracy: 0.001)
        try expectEqual(sameWord?.activeWordIndex, 3)

        let gapAfterFirstWord = document.window(at: 1.3, count: 1).first
        try expectEqual(gapAfterFirstWord?.activePhraseRange, 0..<5)
        try expectEqual(gapAfterFirstWord?.highlightedWordRange, 0..<5)
        try expectNil(gapAfterFirstWord?.phrasePosition)

        let secondWord = document.window(at: 1.55, count: 1).first
        try expectEqual(secondWord?.activePhraseRange, 6..<11)
        try expectEqual(secondWord?.highlightedWordRange, 6..<7)
        try expectEqual(secondWord?.phrasePosition, 1.04, accuracy: 0.001)
        try expectEqual(secondWord?.activeWordIndex, 6)

        let waitingForNextLine = document.window(at: 3, count: 1).first
        try expectEqual(waitingForNextLine?.activePhraseRange, 6..<11)
        try expectEqual(waitingForNextLine?.highlightedWordRange, 6..<11)
        try expectNil(waitingForNextLine?.phrasePosition)
        try expectEqual(waitingForNextLine?.activeWordIndex, 10)
    }

    func tracksCurrentLineProgressFromStartToEnd() throws {
        let timed = LyricsDocument(lines: [
            LyricLine(start: 10, duration: 2, text: "当前句")
        ], offset: 0.2)

        try expectEqual(timed.window(at: 10.2, count: 1).first?.progress, 0, accuracy: 0.001)
        try expectEqual(timed.window(at: 11.2, count: 1).first?.progress, 0.5, accuracy: 0.001)
        try expectEqual(timed.window(at: 12.2, count: 1).first?.progress, 1, accuracy: 0.001)

        let inferred = LyricsDocument(lines: [
            LyricLine(start: 1, text: "第一句"),
            LyricLine(start: 3, text: "第二句")
        ])
        let window = inferred.window(at: 2, count: 3)
        try expectEqual(window[1].progress, 0.5, accuracy: 0.001)
        try expectEqual(window[2].progress, nil)
    }
}

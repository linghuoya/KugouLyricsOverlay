import Foundation
import NaturalLanguage

public struct LyricWindowLine: Equatable, Sendable {
    public let text: String
    public let isCurrent: Bool
    public let words: [LyricWord]
    public let activeWordIndex: Int?
    public let wordPosition: Double?
    public let phraseRanges: [Range<Int>]
    public let phrasePosition: Double?
    public let progress: Double?

    public var activePhraseRange: Range<Int>? {
        guard let activeWordIndex else { return nil }
        return phraseRanges.last { $0.lowerBound <= activeWordIndex }
    }

    public var highlightedWordRange: Range<Int>? {
        guard let activePhraseRange, let activeWordIndex else { return nil }
        let upperBound = min(activeWordIndex + 1, activePhraseRange.upperBound)
        return activePhraseRange.lowerBound..<upperBound
    }

    public init(
        text: String,
        isCurrent: Bool,
        words: [LyricWord] = [],
        activeWordIndex: Int? = nil,
        wordPosition: Double? = nil,
        phraseRanges: [Range<Int>] = [],
        phrasePosition: Double? = nil,
        progress: Double? = nil
    ) {
        self.text = text
        self.isCurrent = isCurrent
        self.words = words
        self.activeWordIndex = activeWordIndex
        self.wordPosition = wordPosition
        self.phraseRanges = phraseRanges
        self.phrasePosition = phrasePosition
        self.progress = progress
    }
}

public extension LyricsDocument {
    func window(at time: TimeInterval, count: Int) -> [LyricWindowLine] {
        guard count > 0, let currentIndex = lineIndex(at: time) else { return [] }
        let half = count / 2
        let firstIndex = currentIndex - half
        return (0..<count).map { lineOffset in
            let index = firstIndex + lineOffset
            guard lines.indices.contains(index) else {
                return LyricWindowLine(text: "", isCurrent: false)
            }
            let line = lines[index]
            let activeWordIndex: Int?
            let wordPosition: Double?
            let phraseRanges: [Range<Int>]
            let phrasePosition: Double?
            let progress: Double?
            if index == currentIndex {
                let elapsed = time - offset - line.start
                activeWordIndex = line.words.lastIndex(where: { $0.start <= elapsed })
                if let activeWordIndex {
                    let nextWordIndex = activeWordIndex + 1
                    if nextWordIndex < line.words.count {
                        let currentWordStart = line.words[activeWordIndex].start
                        let nextWordStart = line.words[nextWordIndex].start
                        let interval = nextWordStart - currentWordStart
                        let fraction = interval > 0 ? min(max((elapsed - currentWordStart) / interval, 0), 1) : 0
                        wordPosition = Double(activeWordIndex) + fraction
                    } else {
                        wordPosition = Double(activeWordIndex)
                    }
                } else {
                    wordPosition = nil
                }
                phraseRanges = lyricPhraseRanges(for: line.words)
                if let activePhraseIndex = phraseRanges.lastIndex(where: {
                    line.words[$0.lowerBound].start <= elapsed
                }) {
                    let range = phraseRanges[activePhraseIndex]
                    let firstWord = line.words[range.lowerBound]
                    let lastWord = line.words[range.upperBound - 1]
                    let phraseEnd = lastWord.start + lastWord.duration
                    let interval = phraseEnd - firstWord.start
                    if interval > 0, elapsed < phraseEnd {
                        let fraction = min(max((elapsed - firstWord.start) / interval, 0), 1)
                        phrasePosition = Double(activePhraseIndex) + fraction
                    } else {
                        phrasePosition = nil
                    }
                } else {
                    phrasePosition = nil
                }
                let explicitEnd = line.duration.flatMap { $0 > 0 ? line.start + $0 : nil }
                let wordEnd = line.words.last.map { line.start + $0.start + $0.duration }
                let nextStart = index + 1 < lines.count ? lines[index + 1].start : nil
                let end = explicitEnd ?? wordEnd ?? nextStart ?? duration
                if let end, end > line.start {
                    progress = min(max(elapsed / (end - line.start), 0), 1)
                } else {
                    progress = nil
                }
            } else {
                activeWordIndex = nil
                wordPosition = nil
                phraseRanges = []
                phrasePosition = nil
                progress = nil
            }
            return LyricWindowLine(
                text: line.text,
                isCurrent: index == currentIndex,
                words: line.words,
                activeWordIndex: activeWordIndex,
                wordPosition: wordPosition,
                phraseRanges: phraseRanges,
                phrasePosition: phrasePosition,
                progress: progress
            )
        }
    }
}

private func lyricPhraseRanges(for words: [LyricWord]) -> [Range<Int>] {
    guard !words.isEmpty else { return [] }
    let text = words.map(\.text).joined()
    var offsets = [0]
    offsets.reserveCapacity(words.count + 1)
    for word in words {
        offsets.append(offsets[offsets.count - 1] + word.text.utf16.count)
    }

    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    var ranges: [Range<Int>] = []
    for tokenRange in tokenizer.tokens(for: text.startIndex..<text.endIndex) {
        let token = text[tokenRange]
        guard token.contains(where: { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }) else {
            continue
        }
        let lowerOffset = tokenRange.lowerBound.utf16Offset(in: text)
        let upperOffset = tokenRange.upperBound.utf16Offset(in: text)
        guard let first = words.indices.first(where: { offsets[$0 + 1] > lowerOffset }),
              let last = words.indices.last(where: { offsets[$0] < upperOffset }),
              first <= last else {
            continue
        }
        if let previous = ranges.last, first < previous.upperBound {
            ranges[ranges.count - 1] = previous.lowerBound..<max(previous.upperBound, last + 1)
        } else {
            ranges.append(first..<(last + 1))
        }
    }
    return ranges.isEmpty ? words.indices.map { $0..<($0 + 1) } : ranges
}

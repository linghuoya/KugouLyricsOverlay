import Foundation

public enum LRCParserError: Error, Equatable, Sendable {
    case noTimedLines
}

public enum LRCParser {
    private static let timestampExpression = try! NSRegularExpression(
        pattern: #"^\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?\]"#
    )

    public static func parse(_ text: String) throws -> LyricsDocument {
        var title: String?
        var artist: String?
        var offset = 0.0
        var lines: [LyricLine] = []

        for rawLine in text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let value = metadataValue("ti", in: line) { title = value }
            if let value = metadataValue("ar", in: line) { artist = value }
            if let value = metadataValue("offset", in: line), let milliseconds = Double(value) {
                offset = milliseconds / 1000
            }

            var remainder = Substring(line)
            var timestamps: [TimeInterval] = []
            while !remainder.isEmpty {
                let source = String(remainder)
                let range = NSRange(source.startIndex..., in: source)
                guard let match = timestampExpression.firstMatch(in: source, range: range),
                      match.range.location == 0,
                      let wholeRange = Range(match.range, in: source),
                      let minutes = capture(1, in: match, source: source).flatMap(Double.init),
                      let seconds = capture(2, in: match, source: source).flatMap(Double.init) else {
                    break
                }
                var timestamp = minutes * 60 + seconds
                if let fraction = capture(3, in: match, source: source) {
                    timestamp += Double("0." + fraction) ?? 0
                }
                timestamps.append(timestamp)
                remainder = source[wholeRange.upperBound...]
            }

            let lyric = remainder.trimmingCharacters(in: .whitespaces)
            guard !lyric.isEmpty else { continue }
            lines.append(contentsOf: timestamps.map { LyricLine(start: $0, text: lyric) })
        }

        guard !lines.isEmpty else { throw LRCParserError.noTimedLines }
        return LyricsDocument(lines: lines, offset: offset, title: title, artist: artist)
    }

    private static func metadataValue(_ key: String, in line: String) -> String? {
        let prefix = "[\(key):"
        guard line.hasPrefix(prefix), line.last == "]" else { return nil }
        return String(line.dropFirst(prefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
    }

    private static func capture(_ index: Int, in match: NSTextCheckingResult, source: String) -> String? {
        guard let range = Range(match.range(at: index), in: source) else { return nil }
        return String(source[range])
    }
}

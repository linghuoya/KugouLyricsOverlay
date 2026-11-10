import Foundation

public enum KRCParserError: Error, Equatable, Sendable {
    case invalidHeader
    case invalidCompressedData
    case invalidText
    case noTimedLines
}

public enum KRCParser {
    private static let macKey: [UInt8] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
    private static let lineExpression = try! NSRegularExpression(pattern: #"^\[(\d+),(\d+)\](.*)$"#)
    private static let wordTimingExpression = try! NSRegularExpression(pattern: #"<[^>]*>"#)
    private static let wordTimingCaptureExpression = try! NSRegularExpression(pattern: #"<(\d+),(\d+),\d+>"#)

    public static func parse(_ data: Data) throws -> LyricsDocument {
        guard data.count > 4, data.prefix(4).elementsEqual(Data("krc1".utf8)) else {
            throw KRCParserError.invalidHeader
        }
        let decrypted = Data(data.dropFirst(4).enumerated().map { index, byte in
            byte ^ macKey[index % macKey.count]
        })
        var compressed = decrypted
        if decrypted.count >= 6 {
            let cmf = decrypted[decrypted.startIndex]
            let flg = decrypted[decrypted.index(after: decrypted.startIndex)]
            let header = (UInt16(cmf) << 8) | UInt16(flg)
            if cmf & 0x0F == 8, header % 31 == 0, flg & 0x20 == 0 {
                compressed = Data(decrypted.dropFirst(2).dropLast(4))
            }
        }
        let inflated: Data
        do {
            inflated = try (compressed as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw KRCParserError.invalidCompressedData
        }
        guard let text = String(data: inflated, encoding: .utf8) else {
            throw KRCParserError.invalidText
        }
        return try parseDecoded(text)
    }

    private static func parseDecoded(_ text: String) throws -> LyricsDocument {
        var title: String?
        var artist: String?
        var duration: TimeInterval?
        var offset = 0.0
        var lines: [LyricLine] = []

        for rawLine in text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let value = metadataValue("ti", in: line) { title = value }
            if let value = metadataValue("ar", in: line) { artist = value }
            if let value = metadataValue("total", in: line), let milliseconds = Double(value) {
                duration = milliseconds / 1000
            }
            if let value = metadataValue("offset", in: line), let milliseconds = Double(value) {
                offset = milliseconds / 1000
            }

            let range = NSRange(line.startIndex..., in: line)
            guard let match = lineExpression.firstMatch(in: line, range: range),
                  let start = capture(1, in: match, source: line).flatMap(Double.init),
                  let lineDuration = capture(2, in: match, source: line).flatMap(Double.init),
                  let lyric = capture(3, in: match, source: line) else {
                continue
            }
            let words = parseWords(in: lyric)
            let plainText: String
            if words.isEmpty {
                plainText = wordTimingExpression.stringByReplacingMatches(
                    in: lyric,
                    range: NSRange(lyric.startIndex..., in: lyric),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespaces)
            } else {
                plainText = words.map(\.text).joined().trimmingCharacters(in: .whitespaces)
            }
            guard !plainText.isEmpty else { continue }
            lines.append(LyricLine(
                start: start / 1000,
                duration: lineDuration / 1000,
                text: plainText,
                words: words
            ))
        }

        guard !lines.isEmpty else { throw KRCParserError.noTimedLines }
        return LyricsDocument(lines: lines, offset: offset, title: title, artist: artist, duration: duration)
    }

    private static func parseWords(in lyric: String) -> [LyricWord] {
        let matches = wordTimingCaptureExpression.matches(
            in: lyric,
            range: NSRange(lyric.startIndex..., in: lyric)
        )
        return matches.enumerated().compactMap { index, match in
            guard let start = capture(1, in: match, source: lyric).flatMap(Double.init),
                  let duration = capture(2, in: match, source: lyric).flatMap(Double.init) else {
                return nil
            }
            let textStart = match.range.upperBound
            let textEnd = index + 1 < matches.count ? matches[index + 1].range.location : NSMaxRange(NSRange(lyric.startIndex..., in: lyric))
            guard textStart <= textEnd,
                  let range = Range(NSRange(location: textStart, length: textEnd - textStart), in: lyric) else {
                return nil
            }
            let text = String(lyric[range])
            guard !text.isEmpty else { return nil }
            return LyricWord(start: start / 1000, duration: duration / 1000, text: text)
        }
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

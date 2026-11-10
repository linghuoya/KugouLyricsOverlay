import Foundation

public enum LyricsColorPreset: String, CaseIterable, Sendable {
    case white
    case yellow
    case cyan
    case orange

    public init(storedValue: String?) {
        self = storedValue.flatMap(LyricsColorPreset.init(rawValue:)) ?? .white
    }

    public var title: String {
        switch self {
        case .white: "白色"
        case .yellow: "黄色"
        case .cyan: "青色"
        case .orange: "橙色"
        }
    }
}

public struct Track: Hashable, Sendable {
    public let title: String
    public let artist: String
    public let duration: TimeInterval?

    public init(title: String, artist: String, duration: TimeInterval? = nil) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        self.duration = duration
    }

    public var identity: String {
        TrackMatcher.normalize(title) + "|" + TrackMatcher.normalize(artist)
    }
}

public struct LyricWord: Hashable, Sendable {
    public let start: TimeInterval
    public let duration: TimeInterval
    public let text: String

    public init(start: TimeInterval, duration: TimeInterval, text: String) {
        self.start = start
        self.duration = duration
        self.text = text
    }
}

public struct LyricLine: Hashable, Sendable {
    public let start: TimeInterval
    public let duration: TimeInterval?
    public let text: String
    public let words: [LyricWord]

    public init(start: TimeInterval, duration: TimeInterval? = nil, text: String, words: [LyricWord] = []) {
        self.start = start
        self.duration = duration
        self.text = text
        self.words = words
    }
}

public struct LyricsDocument: Equatable, Sendable {
    public let lines: [LyricLine]
    public let offset: TimeInterval
    public let title: String?
    public let artist: String?
    public let duration: TimeInterval?

    public init(
        lines: [LyricLine],
        offset: TimeInterval = 0,
        title: String? = nil,
        artist: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.lines = lines.enumerated().sorted { left, right in
            if left.element.start == right.element.start {
                return left.offset < right.offset
            }
            return left.element.start < right.element.start
        }.map(\.element)
        self.offset = offset
        self.title = title
        self.artist = artist
        self.duration = duration
    }

    public func lineIndex(at time: TimeInterval) -> Int? {
        guard time.isFinite, !lines.isEmpty else { return nil }
        let adjustedTime = time - offset
        guard adjustedTime >= lines[0].start else { return nil }

        var lowerBound = 0
        var upperBound = lines.count
        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if lines[middle].start <= adjustedTime {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }
        return lowerBound - 1
    }
}

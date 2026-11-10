import Foundation

public struct KugouAXEntry: Equatable, Sendable {
    public let role: String
    public let identifier: String?
    public let text: String

    public init(role: String, identifier: String? = nil, text: String) {
        self.role = role
        self.identifier = identifier
        self.text = text
    }
}

public struct KugouPlaybackState: Equatable, Sendable {
    public let track: Track
    public let progress: TimeInterval
    public let duration: TimeInterval

    public init(track: Track, progress: TimeInterval, duration: TimeInterval) {
        self.track = track
        self.progress = progress
        self.duration = duration
    }
}

public enum KugouAXSnapshotParser {
    public static func parse(_ entries: [KugouAXEntry]) -> KugouPlaybackState? {
        guard let elapsedText = entries.first(where: {
            $0.identifier == "listen_playView_playedTime_Label"
        })?.text,
        let durationText = entries.first(where: {
            $0.identifier == "listen_playView_fullTime_Label"
        })?.text,
        let progress = parseClock(elapsedText),
        let duration = parseClock(durationText),
        duration > 0,
        let track = parseTrack(entries) else {
            return nil
        }
        return KugouPlaybackState(
            track: Track(title: track.title, artist: track.artist, duration: duration),
            progress: progress,
            duration: duration
        )
    }

    private static func parseTrack(_ entries: [KugouAXEntry]) -> (title: String, artist: String)? {
        var pairs: [(title: String, artist: String)] = []
        for index in 0..<max(0, entries.count - 1) {
            let current = entries[index]
            let next = entries[index + 1]
            guard current.role == "AXButton", next.role == "AXButton" else { continue }
            let title = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = next.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isUsableTrackText(title), isUsableTrackText(artist) else { continue }
            pairs.append((title, artist))
        }

        if let repeated = pairs.last(where: { candidate in
            pairs.filter({ $0 == candidate }).count > 1
        }) {
            return repeated
        }
        if let corroborated = pairs.last(where: { pair in
            entries.contains { entry in
                entry.role == "AXStaticText" && entry.text.contains(pair.title) && entry.text.contains(pair.artist)
            }
        }) {
            return corroborated
        }
        if let pair = pairs.last { return pair }

        for entry in entries where entry.role == "AXStaticText" {
            var text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicatedParts = text.components(separatedBy: ", ")
            if duplicatedParts.count >= 2, duplicatedParts[0] == duplicatedParts[1] {
                text = duplicatedParts[0]
            }
            let parts = text.components(separatedBy: " - ")
            guard parts.count >= 2 else { continue }
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            if isUsableTrackText(title), isUsableTrackText(artist) {
                return (title, artist)
            }
        }
        return nil
    }

    private static func isUsableTrackText(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 160 && !text.contains("\n") && parseClock(text) == nil
    }

    private static func parseClock(_ text: String) -> TimeInterval? {
        let components = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard components.count == 2 || components.count == 3,
              let seconds = Double(components.last!), seconds >= 0, seconds < 60 else {
            return nil
        }
        var total = seconds
        if components.count == 2 {
            guard let minutes = Double(components[0]), minutes >= 0 else { return nil }
            total += minutes * 60
        } else {
            guard let minutes = Double(components[1]), minutes >= 0, minutes < 60,
                  let hours = Double(components[0]), hours >= 0 else { return nil }
            total += minutes * 60 + hours * 3600
        }
        return total
    }
}

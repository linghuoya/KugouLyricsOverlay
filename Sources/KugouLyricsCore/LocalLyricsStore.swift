import Foundation

public enum LyricsFileLoaderError: Error, Equatable, Sendable {
    case unsupportedExtension
    case invalidUTF8
}

public enum LyricsFileLoader {
    public static func load(from url: URL) throws -> LyricsDocument {
        let data = try Data(contentsOf: url)
        switch url.pathExtension.lowercased() {
        case "krc":
            return try KRCParser.parse(data)
        case "lrc":
            guard let text = String(data: data, encoding: .utf8) else {
                throw LyricsFileLoaderError.invalidUTF8
            }
            return try LRCParser.parse(text)
        default:
            throw LyricsFileLoaderError.unsupportedExtension
        }
    }
}

public struct LocalLyricsStore: Sendable {
    public let directory: URL

    public init(directory: URL = LocalLyricsStore.defaultKuGouDirectory) {
        self.directory = directory
    }

    public static var defaultKuGouDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Containers/com.kugou.mac.Music/Data/Library/Application Support/com.kugou.mac.Music/Caches/kgLyric",
            isDirectory: true
        )
    }

    public func find(for track: Track) -> LyricsDocument? {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var bestScore = 79
        var bestDocument: LyricsDocument?
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard ["krc", "lrc"].contains(url.pathExtension.lowercased()),
                  let document = try? LyricsFileLoader.load(from: url) else { continue }

            var title = document.title
            var artist = document.artist
            if title?.isEmpty != false || artist?.isEmpty != false {
                let filename = TrackMatcher.normalize(url.deletingPathExtension().lastPathComponent)
                if filename.contains(TrackMatcher.normalize(track.title)),
                   filename.contains(TrackMatcher.normalize(track.artist)) {
                    if title?.isEmpty != false { title = track.title }
                    if artist?.isEmpty != false { artist = track.artist }
                }
            }
            guard let title, let artist else { continue }
            var score = TrackMatcher.matchScore(
                for: track,
                candidateTitle: title,
                candidateArtist: artist,
                candidateDuration: document.duration
            )
            if !TrackMatcher.isAcceptableScore(score) {
                let filename = TrackMatcher.normalize(url.deletingPathExtension().lastPathComponent)
                if filename.contains(TrackMatcher.normalize(track.title)),
                   filename.contains(TrackMatcher.normalize(track.artist)) {
                    score = TrackMatcher.matchScore(
                        for: track,
                        candidateTitle: track.title,
                        candidateArtist: track.artist,
                        candidateDuration: document.duration
                    )
                }
            }
            if TrackMatcher.isAcceptableScore(score), score > bestScore {
                bestScore = score
                bestDocument = document
            }
        }
        return bestDocument
    }
}

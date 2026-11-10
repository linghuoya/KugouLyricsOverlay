import Foundation
import KugouLyricsCore

struct TrackMatcherTests {
    private let track = Track(title: "下雪哈尔滨 (Live)", artist: "高进", duration: 279)

    func acceptsNormalizedMetadataAndDuration() throws {
        let score = TrackMatcher.matchScore(
            for: track,
            candidateTitle: "下雪哈尔滨（Live）",
            candidateArtist: "高进",
            candidateDuration: 280
        )
        try expectEqual(score, 100)
    }

    func normalizesArtistSeparators() throws {
        let track = Track(title: "周旋", artist: "王以太/艾热AIR", duration: 200)
        let score = TrackMatcher.matchScore(
            for: track,
            candidateTitle: "周旋",
            candidateArtist: "王以太、艾热AIR",
            candidateDuration: 200
        )
        try expectEqual(score, 100)
    }

    func rejectsWrongArtistOrDuration() throws {
        try expectEqual(TrackMatcher.matchScore(for: track, candidateTitle: track.title, candidateArtist: "别人", candidateDuration: 279), 0)
        try expectEqual(TrackMatcher.matchScore(for: track, candidateTitle: track.title, candidateArtist: track.artist, candidateDuration: 100), 0)
        try expectEqual(TrackMatcher.matchScore(for: track, candidateTitle: "另一首歌", candidateArtist: track.artist, candidateDuration: 279), 0)
    }
}

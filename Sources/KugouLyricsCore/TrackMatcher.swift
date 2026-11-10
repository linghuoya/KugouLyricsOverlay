import Foundation

public enum TrackMatcher {
    public static func normalize(_ value: String) -> String {
        let normalized = value.precomposedStringWithCompatibilityMapping.lowercased()
        return String(String.UnicodeScalarView(normalized.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }))
    }

    public static func matchScore(
        for track: Track,
        candidateTitle: String,
        candidateArtist: String,
        candidateDuration: TimeInterval?
    ) -> Int {
        let title = normalize(track.title)
        guard !title.isEmpty, title == normalize(candidateTitle) else { return 0 }

        let artist = normalize(track.artist)
        let candidate = normalize(candidateArtist)
        let artistScore: Int
        if !artist.isEmpty, artist == candidate {
            artistScore = 30
        } else if !artist.isEmpty, !candidate.isEmpty,
                  min(artist.count, candidate.count) >= 2,
                  artist.contains(candidate) || candidate.contains(artist) {
            artistScore = 20
        } else {
            return 0
        }

        var durationScore = 0
        if let expectedDuration = track.duration, expectedDuration > 0,
           let candidateDuration, candidateDuration > 0 {
            let difference = abs(expectedDuration - candidateDuration)
            if difference <= 3 {
                durationScore = 10
            } else if difference <= 8 {
                durationScore = 5
            } else {
                return 0
            }
        }
        return 60 + artistScore + durationScore
    }

    public static func isAcceptableScore(_ score: Int) -> Bool {
        score >= 80
    }
}

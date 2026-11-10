import Foundation

public struct MediaRemotePlayback: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let duration: TimeInterval?
    public let elapsedTime: TimeInterval
    public let timestamp: Date
    public let playbackRate: Double
    public let sourceProcessIdentifier: Int32?

    public init(
        title: String,
        artist: String,
        duration: TimeInterval?,
        elapsedTime: TimeInterval,
        timestamp: Date,
        playbackRate: Double,
        sourceProcessIdentifier: Int32? = nil
    ) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.sourceProcessIdentifier = sourceProcessIdentifier
    }

    func withSourceProcessIdentifier(_ processIdentifier: Int32?) -> MediaRemotePlayback {
        MediaRemotePlayback(
            title: title,
            artist: artist,
            duration: duration,
            elapsedTime: elapsedTime,
            timestamp: timestamp,
            playbackRate: playbackRate,
            sourceProcessIdentifier: processIdentifier
        )
    }

    public func progress(at date: Date) -> TimeInterval? {
        guard elapsedTime.isFinite, elapsedTime >= 0,
              playbackRate.isFinite, playbackRate >= 0 else {
            return nil
        }
        let elapsedSinceTimestamp = date.timeIntervalSince(timestamp)
        guard elapsedSinceTimestamp.isFinite, elapsedSinceTimestamp >= -1 else {
            return nil
        }
        let progress = elapsedTime + max(0, elapsedSinceTimestamp) * playbackRate
        return progress.isFinite ? progress : nil
    }
}

public enum MediaRemoteProgressResolver {
    public static func resolve(
        ax: KugouPlaybackState,
        remote: MediaRemotePlayback?,
        at date: Date
    ) -> KugouPlaybackState {
        guard let remote, let progress = remote.progress(at: date) else { return ax }
        let score = TrackMatcher.matchScore(
            for: ax.track,
            candidateTitle: remote.title,
            candidateArtist: remote.artist,
            candidateDuration: remote.duration
        )
        guard TrackMatcher.isAcceptableScore(score),
              progress >= 0,
              progress <= ax.duration + 1 else {
            return ax
        }
        return KugouPlaybackState(
            track: ax.track,
            progress: min(progress, ax.duration),
            duration: ax.duration
        )
    }

    public static func resolve(
        remote: MediaRemotePlayback?,
        kugouProcessIdentifier: Int32?,
        at date: Date
    ) -> KugouPlaybackState? {
        guard let remote,
              let kugouProcessIdentifier,
              kugouProcessIdentifier > 0,
              remote.sourceProcessIdentifier == kugouProcessIdentifier,
              !TrackMatcher.normalize(remote.title).isEmpty,
              !TrackMatcher.normalize(remote.artist).isEmpty,
              let duration = remote.duration,
              duration.isFinite,
              duration > 0,
              let progress = remote.progress(at: date),
              progress >= 0,
              progress <= duration + 1 else {
            return nil
        }
        return KugouPlaybackState(
            track: Track(title: remote.title, artist: remote.artist, duration: duration),
            progress: min(progress, duration),
            duration: duration
        )
    }
}

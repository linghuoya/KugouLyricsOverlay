import Foundation
import KugouLyricsCore

struct MediaRemotePlaybackTests {
    private let timestamp = Date(timeIntervalSince1970: 1_000)

    func advancesPlayingProgressAndFreezesPausedProgress() throws {
        let playing = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: 300,
            elapsedTime: 2.5,
            timestamp: timestamp,
            playbackRate: 1
        )
        try expectEqual(playing.progress(at: timestamp.addingTimeInterval(5)), 7.5, accuracy: 0.001)

        let paused = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: 300,
            elapsedTime: 2.5,
            timestamp: timestamp,
            playbackRate: 0
        )
        try expectEqual(paused.progress(at: timestamp.addingTimeInterval(5)), 2.5, accuracy: 0.001)
    }

    func replacesStaleAXProgressForTheSameTrack() throws {
        let ax = KugouPlaybackState(
            track: Track(title: "甲乙丙丁 (你我怎么两清)", artist: "李佳薇", duration: 210),
            progress: 14,
            duration: 210
        )
        let remote = MediaRemotePlayback(
            title: "甲乙丙丁 (你我怎么两清)",
            artist: "李佳薇",
            duration: 210.461,
            elapsedTime: 2.978,
            timestamp: timestamp,
            playbackRate: 1
        )

        let resolved = MediaRemoteProgressResolver.resolve(ax: ax, remote: remote, at: timestamp.addingTimeInterval(136))
        try expectEqual(resolved.progress, 138.978, accuracy: 0.001)
        try expectEqual(resolved.track, ax.track)
    }

    func keepsAXForMissingOrMismatchedRemoteData() throws {
        let ax = KugouPlaybackState(
            track: Track(title: "Song", artist: "Artist", duration: 300),
            progress: 42,
            duration: 300
        )
        let otherTrack = MediaRemotePlayback(
            title: "Other",
            artist: "Artist",
            duration: 300,
            elapsedTime: 10,
            timestamp: timestamp,
            playbackRate: 1
        )

        try expectEqual(MediaRemoteProgressResolver.resolve(ax: ax, remote: nil, at: timestamp), ax)
        try expectEqual(MediaRemoteProgressResolver.resolve(ax: ax, remote: otherTrack, at: timestamp), ax)
    }

    func createsStandaloneStateOnlyForKuGou() throws {
        let remote = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: 300,
            elapsedTime: 2.5,
            timestamp: timestamp,
            playbackRate: 1,
            sourceProcessIdentifier: 42
        )

        let state = MediaRemoteProgressResolver.resolve(
            remote: remote,
            kugouProcessIdentifier: 42,
            at: timestamp.addingTimeInterval(5)
        )
        try expectEqual(state?.track, Track(title: "Song", artist: "Artist", duration: 300))
        try expectEqual(state?.progress, 7.5, accuracy: 0.001)
        try expectEqual(state?.duration, 300)
        try expectNil(MediaRemoteProgressResolver.resolve(
            remote: remote,
            kugouProcessIdentifier: 99,
            at: timestamp
        ))
        try expectNil(MediaRemoteProgressResolver.resolve(
            remote: remote,
            kugouProcessIdentifier: nil,
            at: timestamp
        ))
    }

    func rejectsStandaloneStateWithInvalidMetadata() throws {
        let missingDuration = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: nil,
            elapsedTime: 2.5,
            timestamp: timestamp,
            playbackRate: 1,
            sourceProcessIdentifier: 42
        )
        let missingSource = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: 300,
            elapsedTime: 2.5,
            timestamp: timestamp,
            playbackRate: 1
        )

        try expectNil(MediaRemoteProgressResolver.resolve(
            remote: missingDuration,
            kugouProcessIdentifier: 42,
            at: timestamp
        ))
        try expectNil(MediaRemoteProgressResolver.resolve(
            remote: missingSource,
            kugouProcessIdentifier: 42,
            at: timestamp
        ))
    }

    func rejectsRemoteProgressBeyondTheTrackDuration() throws {
        let ax = KugouPlaybackState(
            track: Track(title: "Song", artist: "Artist", duration: 60),
            progress: 20,
            duration: 60
        )
        let stale = MediaRemotePlayback(
            title: "Song",
            artist: "Artist",
            duration: 60,
            elapsedTime: 2,
            timestamp: timestamp,
            playbackRate: 1
        )

        let resolved = MediaRemoteProgressResolver.resolve(ax: ax, remote: stale, at: timestamp.addingTimeInterval(120))
        try expectEqual(resolved, ax)
    }
}

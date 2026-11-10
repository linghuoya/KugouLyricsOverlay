import Foundation
import KugouLyricsCore

struct PlaybackSynchronizerTests {
    private let track = Track(title: "Song", artist: "Artist", duration: 300)

    func waitsForObservedMovementBeforePlaying() throws {
        var synchronizer = PlaybackSynchronizer()
        let initial = synchronizer.update(track: track, rawProgress: 10, at: 0)
        try expectEqual(initial, PlaybackEstimate(progress: 10, isPlaying: false))

        let unchanged = synchronizer.update(track: track, rawProgress: 10, at: 1)
        try expectFalse(unchanged.isPlaying)
    }

    func interpolatesNormalTicksAndDetectsPause() throws {
        var synchronizer = PlaybackSynchronizer()
        _ = synchronizer.update(track: track, rawProgress: 10, at: 0)
        _ = synchronizer.update(track: track, rawProgress: 10, at: 1)
        let tick = synchronizer.update(track: track, rawProgress: 11, at: 2)
        try expectTrue(tick.isPlaying)

        let interpolated = synchronizer.update(track: track, rawProgress: 11, at: 2.5)
        try expectTrue(interpolated.isPlaying)
        try expectGreaterThan(interpolated.progress, 11)
        try expectLessThanOrEqual(interpolated.progress, 11.95)

        let paused = synchronizer.update(track: track, rawProgress: 11, at: 4)
        try expectFalse(paused.isPlaying)
    }

    func seekAndTrackChangeResetEstimate() throws {
        var synchronizer = PlaybackSynchronizer()
        _ = synchronizer.update(track: track, rawProgress: 10, at: 0)
        _ = synchronizer.update(track: track, rawProgress: 11, at: 1)
        let seek = synchronizer.update(track: track, rawProgress: 40, at: 2)
        try expectEqual(seek.progress, 40)

        let otherTrack = Track(title: "Other", artist: "Artist", duration: 200)
        let changed = synchronizer.update(track: otherTrack, rawProgress: 2, at: 3)
        try expectEqual(changed, PlaybackEstimate(progress: 2, isPlaying: false))
    }
}

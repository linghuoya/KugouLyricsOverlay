import Foundation

public struct PlaybackEstimate: Equatable, Sendable {
    public let progress: TimeInterval
    public let isPlaying: Bool

    public init(progress: TimeInterval, isPlaying: Bool) {
        self.progress = progress
        self.isPlaying = isPlaying
    }
}

public struct PlaybackSynchronizer: Sendable {
    private var trackIdentity: String?
    private var lastRawProgress: TimeInterval?
    private var lastObservedAt: TimeInterval?
    private var rawBoundaryAt: TimeInterval?
    private var lastMovementAt = -Double.infinity
    private var estimatedProgress = 0.0

    public init() {}

    public mutating func update(track: Track, rawProgress: TimeInterval, at now: TimeInterval) -> PlaybackEstimate {
        let raw = max(0, rawProgress.isFinite ? rawProgress : 0)
        if trackIdentity != track.identity {
            trackIdentity = track.identity
            lastRawProgress = nil
            lastObservedAt = nil
            rawBoundaryAt = now
            lastMovementAt = -Double.infinity
            estimatedProgress = raw
        }

        if let previousRaw = lastRawProgress {
            let change = raw - previousRaw
            if change > 0, change <= 1.5 {
                rawBoundaryAt = lastObservedAt.map { ($0 + now) / 2 } ?? now
                estimatedProgress = raw
                lastMovementAt = now
            } else if abs(change) > 0.001 {
                rawBoundaryAt = now
                estimatedProgress = raw
                lastMovementAt = now
            }
        } else {
            rawBoundaryAt = now
            estimatedProgress = raw
        }

        lastRawProgress = raw
        lastObservedAt = now
        let elapsed = now - lastMovementAt
        let isPlaying = elapsed >= 0 && elapsed < 1.4
        if isPlaying, let boundary = rawBoundaryAt {
            let fraction = min(max(now - boundary, 0), 0.95)
            estimatedProgress = max(estimatedProgress, raw + fraction)
        } else {
            estimatedProgress = max(raw, min(estimatedProgress, raw + 0.95))
        }
        if let duration = track.duration, duration > 0 {
            estimatedProgress = min(estimatedProgress, duration)
        }
        return PlaybackEstimate(progress: estimatedProgress, isPlaying: isPlaying)
    }
}

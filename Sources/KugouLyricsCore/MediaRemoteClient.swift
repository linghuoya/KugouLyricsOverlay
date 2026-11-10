import CoreFoundation
import Darwin
import Dispatch
import Foundation

public protocol MediaRemoteReading: Sendable {
    func read() async -> MediaRemotePlayback?
}

private typealias NowPlayingInfoFunction = @convention(c) (
    dispatch_queue_t,
    @escaping (CFDictionary?) -> Void
) -> Void

private typealias NowPlayingPIDFunction = @convention(c) (
    dispatch_queue_t,
    @escaping (Int32) -> Void
) -> Void

private final class MediaRemoteContinuationState<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?
    private var didResume = false

    func install(_ continuation: CheckedContinuation<Value, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func resume(with value: Value) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}

public final class MediaRemoteClient: MediaRemoteReading, @unchecked Sendable {
    private let handle: UnsafeMutableRawPointer?
    private let getNowPlayingInfo: UnsafeMutableRawPointer?
    private let getNowPlayingApplicationPID: UnsafeMutableRawPointer?

    public init() {
        handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_LAZY | RTLD_LOCAL
        )
        getNowPlayingInfo = handle.flatMap { dlsym($0, "MRMediaRemoteGetNowPlayingInfo") }
        getNowPlayingApplicationPID = handle.flatMap {
            dlsym($0, "MRMediaRemoteGetNowPlayingApplicationPID")
        }
    }

    public func read() async -> MediaRemotePlayback? {
        async let info = readNowPlayingInfo()
        async let sourcePID = readNowPlayingProcessIdentifier()
        let (playback, processIdentifier) = await (info, sourcePID)
        return playback?.withSourceProcessIdentifier(processIdentifier)
    }

    private func readNowPlayingInfo() async -> MediaRemotePlayback? {
        guard let getNowPlayingInfo else { return nil }
        let state = MediaRemoteContinuationState<MediaRemotePlayback?>()
        return await withCheckedContinuation { continuation in
            state.install(continuation)
            let function = unsafeBitCast(getNowPlayingInfo, to: NowPlayingInfoFunction.self)
            function(DispatchQueue.global(qos: .utility)) { info in
                state.resume(with: Self.parse(info))
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                state.resume(with: nil)
            }
        }
    }

    private func readNowPlayingProcessIdentifier() async -> Int32? {
        guard let getNowPlayingApplicationPID else { return nil }
        let state = MediaRemoteContinuationState<Int32?>()
        return await withCheckedContinuation { continuation in
            state.install(continuation)
            let function = unsafeBitCast(getNowPlayingApplicationPID, to: NowPlayingPIDFunction.self)
            function(DispatchQueue.global(qos: .utility)) { processIdentifier in
                state.resume(with: processIdentifier)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                state.resume(with: nil)
            }
        }
    }

    private static func parse(_ info: CFDictionary?) -> MediaRemotePlayback? {
        guard let info else { return nil }
        let dictionary = info as NSDictionary
        guard let title = dictionary["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
              let artist = dictionary["kMRMediaRemoteNowPlayingInfoArtist"] as? String,
              !title.isEmpty,
              !artist.isEmpty,
              let elapsed = dictionary["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber,
              let timestamp = dictionary["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date,
              let rate = dictionary["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber else {
            return nil
        }
        let duration = dictionary["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber
        return MediaRemotePlayback(
            title: title,
            artist: artist,
            duration: duration?.doubleValue,
            elapsedTime: elapsed.doubleValue,
            timestamp: timestamp,
            playbackRate: rate.doubleValue
        )
    }
}

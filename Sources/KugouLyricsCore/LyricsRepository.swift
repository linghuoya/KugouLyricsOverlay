import Foundation

public enum LyricsSource: Equatable, Sendable {
    case local
    case online
    case manual
}

public struct LoadedLyrics: Equatable, Sendable {
    public let document: LyricsDocument
    public let source: LyricsSource

    public init(document: LyricsDocument, source: LyricsSource) {
        self.document = document
        self.source = source
    }
}

public actor LyricsRepository {
    private let localStore: LocalLyricsStore
    private let remoteClient: LRCLIBClient
    private var cache: [String: LoadedLyrics] = [:]
    private var manualImports: [String: LyricsDocument] = [:]

    public init(
        localStore: LocalLyricsStore = LocalLyricsStore(),
        remoteClient: LRCLIBClient = LRCLIBClient()
    ) {
        self.localStore = localStore
        self.remoteClient = remoteClient
    }

    public func lyrics(for track: Track) async -> LoadedLyrics? {
        let key = track.identity
        if let manual = manualImports[key] {
            return LoadedLyrics(document: manual, source: .manual)
        }
        if let cached = cache[key] { return cached }
        if let local = localStore.find(for: track) {
            let loaded = LoadedLyrics(document: local, source: .local)
            cache[key] = loaded
            return loaded
        }
        if let online = try? await remoteClient.fetch(for: track) {
            let loaded = LoadedLyrics(document: online, source: .online)
            cache[key] = loaded
            return loaded
        }
        return nil
    }

    public func importLRC(_ text: String, for track: Track) throws -> LoadedLyrics {
        let document = try LRCParser.parse(text)
        manualImports[track.identity] = document
        return LoadedLyrics(document: document, source: .manual)
    }

    public func refresh(for track: Track) {
        cache.removeValue(forKey: track.identity)
    }

    public func clearManualImport(for track: Track) {
        manualImports.removeValue(forKey: track.identity)
    }
}

import Foundation
import KugouLyricsCore

struct LyricsRepositoryTests {
    private let track = Track(title: "Song", artist: "Artist", duration: 3)

    func prefersLocalLyrics() async throws {
        try await withAsyncTestDirectory { directory in
            let krc = makeKRCFixture("[ti:Song]\n[ar:Artist]\n[total:3000]\n[1000,500]<0,500,0>Local")
            try krc.write(to: directory.appendingPathComponent("234811088.krc"))
            let client = LRCLIBClient(fetcher: StubHTTPFetcher(
                data: makeLRCLIBResponse(title: "Song", artist: "Artist", duration: 3, lyrics: "[00:01.00]Online"),
                status: 200
            ))
            let repository = LyricsRepository(localStore: LocalLyricsStore(directory: directory), remoteClient: client)
            let loaded = await repository.lyrics(for: track)
            try expectEqual(loaded?.source, .local)
            try expectEqual(loaded?.document.lines.first?.text, "Local")
        }
    }

    func fallsBackToOnlineLyrics() async throws {
        try await withAsyncTestDirectory { directory in
            let client = LRCLIBClient(fetcher: StubHTTPFetcher(
                data: makeLRCLIBResponse(title: "Song", artist: "Artist", duration: 3, lyrics: "[00:01.00]Online"),
                status: 200
            ))
            let repository = LyricsRepository(localStore: LocalLyricsStore(directory: directory), remoteClient: client)
            let loaded = await repository.lyrics(for: track)
            try expectEqual(loaded?.source, .online)
            try expectEqual(loaded?.document.lines.first?.text, "Online")
        }
    }

    func manualImportOverridesCachedSource() async throws {
        try await withAsyncTestDirectory { directory in
            let client = LRCLIBClient(fetcher: StubHTTPFetcher(
                data: makeLRCLIBResponse(title: "Song", artist: "Artist", duration: 3, lyrics: "[00:01.00]Online"),
                status: 200
            ))
            let repository = LyricsRepository(localStore: LocalLyricsStore(directory: directory), remoteClient: client)
            _ = await repository.lyrics(for: track)
            _ = try await repository.importLRC("[00:02.00]Manual", for: track)
            let loaded = await repository.lyrics(for: track)
            try expectEqual(loaded?.source, .manual)
            try expectEqual(loaded?.document.lines.first?.text, "Manual")
        }
    }
}

func withAsyncTestDirectory(_ body: (URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("KugouLyricsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try await body(directory)
}

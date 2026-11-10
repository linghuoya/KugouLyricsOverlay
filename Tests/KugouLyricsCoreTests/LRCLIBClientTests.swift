import Foundation
import KugouLyricsCore

struct StubHTTPFetcher: HTTPDataFetching {
    let data: Data
    let status: Int

    func data(from url: URL) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

struct LRCLIBClientTests {
    private let track = Track(title: "Song", artist: "Artist", duration: 3)

    func returnsMatchedSyncedLyrics() async throws {
        let client = LRCLIBClient(fetcher: StubHTTPFetcher(
            data: makeLRCLIBResponse(title: "Song", artist: "Artist", duration: 3, lyrics: "[00:01.00]Online"),
            status: 200
        ))
        let document = try await client.fetch(for: track)
        try expectEqual(document?.lines.first?.text, "Online")
    }

    func rejectsMismatchedTrack() async throws {
        let client = LRCLIBClient(fetcher: StubHTTPFetcher(
            data: makeLRCLIBResponse(title: "Song", artist: "Other", duration: 3, lyrics: "[00:01.00]Wrong"),
            status: 200
        ))
        let document = try await client.fetch(for: track)
        try expectNil(document)
    }

    func returnsNilForNotFoundOrPlainLyrics() async throws {
        let missing = LRCLIBClient(fetcher: StubHTTPFetcher(data: Data(), status: 404))
        let missingDocument = try await missing.fetch(for: track)
        try expectNil(missingDocument)
        let plain = LRCLIBClient(fetcher: StubHTTPFetcher(
            data: makeLRCLIBResponse(title: "Song", artist: "Artist", duration: 3, lyrics: nil),
            status: 200
        ))
        let plainDocument = try await plain.fetch(for: track)
        try expectNil(plainDocument)
    }
}

func makeLRCLIBResponse(title: String, artist: String, duration: Double, lyrics: String?) -> Data {
    var object: [String: Any] = [
        "trackName": title,
        "artistName": artist,
        "duration": duration,
        "plainLyrics": "Plain"
    ]
    if let lyrics { object["syncedLyrics"] = lyrics }
    return try! JSONSerialization.data(withJSONObject: object)
}

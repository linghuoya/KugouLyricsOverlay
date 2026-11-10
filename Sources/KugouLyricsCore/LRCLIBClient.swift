import Foundation

public protocol HTTPDataFetching: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetching {}

public enum LRCLIBError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
}

public struct LRCLIBClient: Sendable {
    private let fetcher: any HTTPDataFetching
    private let baseURL: URL

    public init(
        fetcher: any HTTPDataFetching = URLSession.shared,
        baseURL: URL = URL(string: "https://lrclib.net")!
    ) {
        self.fetcher = fetcher
        self.baseURL = baseURL
    }

    public func fetch(for track: Track) async throws -> LyricsDocument? {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/get"),
            resolvingAgainstBaseURL: false
        ) else { throw LRCLIBError.invalidURL }
        var query = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]
        if let duration = track.duration, duration > 0 {
            query.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components.queryItems = query
        guard let url = components.url else { throw LRCLIBError.invalidURL }

        let (data, response) = try await fetcher.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw LRCLIBError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw LRCLIBError.httpStatus(http.statusCode) }

        let result = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
        guard let syncedLyrics = result.syncedLyrics, !syncedLyrics.isEmpty else { return nil }
        let score = TrackMatcher.matchScore(
            for: track,
            candidateTitle: result.trackName,
            candidateArtist: result.artistName,
            candidateDuration: result.duration
        )
        guard TrackMatcher.isAcceptableScore(score) else { return nil }
        return try? LRCParser.parse(syncedLyrics)
    }
}

private struct LRCLIBResponse: Decodable {
    let trackName: String
    let artistName: String
    let duration: TimeInterval
    let syncedLyrics: String?
}

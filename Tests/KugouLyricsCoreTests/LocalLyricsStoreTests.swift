import Foundation
import KugouLyricsCore

struct LocalLyricsStoreTests {
    private let track = Track(title: "Song", artist: "Artist", duration: 3)

    func findsMatchingKRCFromMetadata() throws {
        try withTestDirectory { directory in
            let krc = makeKRCFixture("[ti:Song]\n[ar:Artist]\n[total:3000]\n[1000,500]<0,500,0>Local")
            try krc.write(to: directory.appendingPathComponent("234811088.krc"))
            let store = LocalLyricsStore(directory: directory)
            let document = store.find(for: track)
            try expectEqual(document?.lines.first?.text, "Local")
        }
    }

    func rejectsWrongArtistAndUsesFilenameFallback() throws {
        try withTestDirectory { directory in
            let wrong = makeKRCFixture("[ti:Song]\n[ar:Other]\n[total:3000]\n[1000,500]<0,500,0>Wrong")
            try wrong.write(to: directory.appendingPathComponent("wrong.krc"))
            let lrc = "[00:01.00]Filename match"
            try lrc.write(to: directory.appendingPathComponent("Artist - Song_hash.lrc"), atomically: true, encoding: .utf8)
            let store = LocalLyricsStore(directory: directory)
            let document = store.find(for: track)
            try expectEqual(document?.lines.first?.text, "Filename match")
        }
    }

    func usesMatchingFilenameWhenEmbeddedTitleHasDifferentVersion() throws {
        try withTestDirectory { directory in
            let krc = makeKRCFixture("[ti:大雨还在下 (抖音烟嗓完整版)]\n[ar:王梦露]\n[1092,1894]<0,193,0>窗")
            let filename = "王梦露 - 大雨还在下 (烟嗓版)_44992b4353a2541420238984499658a8.krc"
            try krc.write(to: directory.appendingPathComponent(filename))
            let store = LocalLyricsStore(directory: directory)
            let track = Track(title: "大雨还在下 (烟嗓版)", artist: "王梦露", duration: 256.13)
            let document = store.find(for: track)
            try expectEqual(document?.lines.first?.text, "窗")
        }
    }
}

func withTestDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("KugouLyricsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

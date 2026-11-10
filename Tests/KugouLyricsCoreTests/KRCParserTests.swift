import Compression
import Foundation
import KugouLyricsCore

struct KRCParserTests {
    func decryptsMacKRCAndPreservesWordTiming() throws {
        let text = "\u{FEFF}[ti:Song]\r\n[ar:Artist]\r\n[total:3000]\r\n[offset:250]\r\n[1000,900]<0,300,0>Hello <300,600,0>world\r\n[2000,500]<0,500,0>Next"
        let document = try KRCParser.parse(makeKRCFixture(text))

        try expectEqual(document.title, "Song")
        try expectEqual(document.artist, "Artist")
        try expectEqual(document.duration, 3, accuracy: 0.001)
        try expectEqual(document.offset, 0.25, accuracy: 0.001)
        try expectEqual(document.lines, [
            LyricLine(start: 1, duration: 0.9, text: "Hello world", words: [
                LyricWord(start: 0, duration: 0.3, text: "Hello "),
                LyricWord(start: 0.3, duration: 0.6, text: "world")
            ]),
            LyricLine(start: 2, duration: 0.5, text: "Next", words: [
                LyricWord(start: 0, duration: 0.5, text: "Next")
            ])
        ])
    }

    func decryptsZlibWrappedMacKRC() throws {
        let text = "[ti:]\r\n[ar:]\r\n[0,738]<0,738,0>九月的风停在九月底"
        let document = try KRCParser.parse(makeKRCFixture(text, zlibWrapped: true))

        try expectEqual(document.lines.map(\.text), ["九月的风停在九月底"])
    }

    func rejectsInvalidHeaderAndCompressedData() throws {
        try expectThrows({ _ = try KRCParser.parse(Data("nope".utf8)) }) {
            try expectEqual($0 as? KRCParserError, .invalidHeader)
        }
        try expectThrows({ _ = try KRCParser.parse(Data("krc1broken".utf8)) }) {
            try expectEqual($0 as? KRCParserError, .invalidCompressedData)
        }
    }
}

func makeKRCFixture(_ text: String, zlibWrapped: Bool = false) -> Data {
    let source = Data(text.utf8)
    var compressed = Data(count: max(1024, source.count * 2))
    let count = compressed.withUnsafeMutableBytes { destination in
        source.withUnsafeBytes { input in
            compression_encode_buffer(
                destination.bindMemory(to: UInt8.self).baseAddress!, destination.count,
                input.bindMemory(to: UInt8.self).baseAddress!, input.count,
                nil, COMPRESSION_ZLIB
            )
        }
    }
    precondition(count > 0)
    compressed.count = count
    if zlibWrapped {
        var wrapped = Data([0x78, 0x9c])
        wrapped.append(compressed)
        var checksum = adler32(source).bigEndian
        withUnsafeBytes(of: &checksum) { wrapped.append(contentsOf: $0) }
        compressed = wrapped
    }
    let key: [UInt8] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
    let encrypted = Data(compressed.enumerated().map { index, byte in byte ^ key[index % key.count] })
    return Data("krc1".utf8) + encrypted
}

private func adler32(_ data: Data) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0
    for byte in data {
        a = (a + UInt32(byte)) % 65_521
        b = (b + a) % 65_521
    }
    return (b << 16) | a
}

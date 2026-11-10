// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KugouLyricsOverlay",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KugouLyricsCore", targets: ["KugouLyricsCore"]),
        .executable(name: "KugouLyricsOverlay", targets: ["KugouLyricsOverlay"]),
        .executable(name: "KugouLyricsCoreTests", targets: ["KugouLyricsCoreTests"])
    ],
    targets: [
        .target(name: "KugouLyricsCore"),
        .executableTarget(name: "KugouLyricsOverlay", dependencies: ["KugouLyricsCore"]),
        .executableTarget(
            name: "KugouLyricsCoreTests",
            dependencies: ["KugouLyricsCore"],
            path: "Tests/KugouLyricsCoreTests"
        )
    ]
)

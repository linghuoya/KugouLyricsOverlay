import Foundation
import KugouLyricsCore

struct KugouAXSnapshotParserTests {
    func parsesCurrentKuGouButtonsAndIdentifiedTimeLabels() throws {
        let entries = [
            KugouAXEntry(role: "AXButton", text: "下雪哈尔滨 (Live)"),
            KugouAXEntry(role: "AXButton", text: "高进"),
            KugouAXEntry(role: "AXButton", text: "下雪哈尔滨 (Live)"),
            KugouAXEntry(role: "AXButton", text: "高进"),
            KugouAXEntry(role: "AXStaticText", identifier: "listen_playView_playedTime_Label", text: "03:15"),
            KugouAXEntry(role: "AXStaticText", identifier: "listen_playView_fullTime_Label", text: "04:39")
        ]

        let state = KugouAXSnapshotParser.parse(entries)
        try expectEqual(state?.track, Track(title: "下雪哈尔滨 (Live)", artist: "高进", duration: 279))
        try expectEqual(state?.progress, 195)
        try expectEqual(state?.duration, 279)
    }

    func fallsBackToCombinedStaticTitle() throws {
        let entries = [
            KugouAXEntry(role: "AXStaticText", text: "王以太/艾热AIR - 周旋"),
            KugouAXEntry(role: "AXStaticText", identifier: "listen_playView_playedTime_Label", text: "01:02"),
            KugouAXEntry(role: "AXStaticText", identifier: "listen_playView_fullTime_Label", text: "03:04")
        ]

        let state = KugouAXSnapshotParser.parse(entries)
        try expectEqual(state?.track.title, "周旋")
        try expectEqual(state?.track.artist, "王以太/艾热AIR")
        try expectEqual(state?.progress, 62)
    }

    func rejectsMissingDuration() throws {
        let entries = [KugouAXEntry(role: "AXStaticText", identifier: "listen_playView_playedTime_Label", text: "01:02")]
        try expectNil(KugouAXSnapshotParser.parse(entries))
    }
}

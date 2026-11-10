import AppKit
import Foundation
import KugouLyricsCore
import UniformTypeIdentifiers

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var document: LyricsDocument?
    @Published private(set) var source: LyricsSource?
    @Published private(set) var estimate = PlaybackEstimate(progress: 0, isPlaying: false)
    @Published private(set) var status = "等待酷狗播放信息"
    @Published private(set) var needsPermission = false

    @Published var lineCount: Int {
        didSet { UserDefaults.standard.set(lineCount, forKey: "overlayLineCount") }
    }
    @Published var opacity: Double {
        didSet { UserDefaults.standard.set(opacity, forKey: "overlayOpacity") }
    }
    @Published var colorPreset: LyricsColorPreset {
        didSet { UserDefaults.standard.set(colorPreset.rawValue, forKey: "overlayLyricsColor") }
    }

    private let reader: KugouAccessibilityReader
    private let repository: LyricsRepository
    private let mediaRemote: any MediaRemoteReading
    private var synchronizer = PlaybackSynchronizer()
    private var latestState: KugouPlaybackState?
    private var loopTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var requestID = UUID()
    private var lastReadAt = -Double.infinity

    init(
        reader: KugouAccessibilityReader = KugouAccessibilityReader(),
        repository: LyricsRepository = LyricsRepository(),
        mediaRemote: any MediaRemoteReading = MediaRemoteClient()
    ) {
        self.reader = reader
        self.repository = repository
        self.mediaRemote = mediaRemote
        let storedLines = UserDefaults.standard.integer(forKey: "overlayLineCount")
        lineCount = storedLines == 3 ? 3 : 5
        let storedOpacity = UserDefaults.standard.double(forKey: "overlayOpacity")
        opacity = storedOpacity == 0 ? 0.8 : min(max(storedOpacity, 0.3), 1)
        colorPreset = LyricsColorPreset(storedValue: UserDefaults.standard.string(forKey: "overlayLyricsColor"))
    }

    func start() {
        guard loopTask == nil else { return }
        if !KugouAccessibilityReader.isTrusted {
            needsPermission = true
            status = "需要辅助功能权限"
            KugouAccessibilityReader.requestPermission()
        }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        lyricsTask?.cancel()
    }

    func openAccessibilitySettings() {
        KugouAccessibilityReader.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func reloadLyrics() {
        guard let track else { return }
        lyricsTask?.cancel()
        requestID = UUID()
        document = nil
        source = nil
        status = "正在重新获取歌词…"
        lyricsTask = Task { [weak self, repository] in
            await repository.refresh(for: track)
            guard let self, !Task.isCancelled, self.track?.identity == track.identity else { return }
            self.loadLyrics(for: track)
        }
    }

    func importLRC() {
        guard let track else {
            status = "请先在酷狗中播放歌曲"
            return
        }
        let panel = NSOpenPanel()
        panel.title = "导入 LRC 同步歌词"
        panel.allowedContentTypes = [UTType(filenameExtension: "lrc") ?? .plainText]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            status = "正在导入歌词…"
            lyricsTask = Task { [weak self, repository] in
                do {
                    let loaded = try await repository.importLRC(text, for: track)
                    guard let self, self.track?.identity == track.identity else { return }
                    self.document = loaded.document
                    self.source = loaded.source
                    self.status = ""
                } catch {
                    self?.status = "导入失败：没有有效的 LRC 时间轴"
                }
            }
        } catch {
            status = "无法读取所选文件"
        }
    }

    private func refresh() async {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastReadAt >= 1 {
            lastReadAt = now
            let result = await Task.detached(priority: .userInitiated) { [reader] in
                reader.read()
            }.value
            if case .available(let axState) = result {
                let remote = await mediaRemote.read()
                apply(.available(MediaRemoteProgressResolver.resolve(
                    ax: axState,
                    remote: remote,
                    at: Date()
                )))
            } else if case .noPlaybackInfo = result {
                let remote = await mediaRemote.read()
                let kugouPID = NSRunningApplication.runningApplications(
                    withBundleIdentifier: "com.kugou.mac.Music"
                ).first?.processIdentifier
                if let state = MediaRemoteProgressResolver.resolve(
                    remote: remote,
                    kugouProcessIdentifier: kugouPID,
                    at: Date()
                ) {
                    apply(.available(state))
                } else {
                    apply(result)
                }
            } else {
                apply(result)
            }
        }
        if let state = latestState {
            estimate = synchronizer.update(track: state.track, rawProgress: state.progress, at: now)
        }
    }

    private func apply(_ result: KugouReadResult) {
        switch result {
        case .permissionRequired:
            needsPermission = true
            clearPlayback(message: "需要辅助功能权限")
        case .notRunning:
            needsPermission = false
            clearPlayback(message: "酷狗音乐未运行")
        case .noPlaybackInfo:
            needsPermission = false
            clearPlayback(message: "等待酷狗播放信息")
        case .available(let state):
            needsPermission = false
            latestState = state
            if track?.identity != state.track.identity {
                track = state.track
                document = nil
                source = nil
                status = "正在查找歌词…"
                loadLyrics(for: state.track)
            } else {
                track = state.track
            }
        }
    }

    private func clearPlayback(message: String) {
        latestState = nil
        track = nil
        document = nil
        source = nil
        estimate = PlaybackEstimate(progress: 0, isPlaying: false)
        status = message
        requestID = UUID()
        lyricsTask?.cancel()
    }

    private func loadLyrics(for track: Track) {
        let request = UUID()
        requestID = request
        lyricsTask?.cancel()
        lyricsTask = Task { [weak self, repository] in
            let loaded = await repository.lyrics(for: track)
            guard let self, !Task.isCancelled,
                  self.requestID == request,
                  self.track?.identity == track.identity else { return }
            self.document = loaded?.document
            self.source = loaded?.source
            self.status = loaded == nil ? "未找到同步歌词，可右键导入 LRC" : ""
        }
    }
}

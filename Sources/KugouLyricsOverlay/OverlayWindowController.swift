import AppKit
import Combine
import KugouLyricsCore
import SwiftUI

@MainActor
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayHostingView: NSHostingView<OverlayView> {
    var overlayMenu: NSMenu?

    override func rightMouseDown(with event: NSEvent) {
        guard let overlayMenu else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(overlayMenu, with: event, for: self)
    }
}

@MainActor
final class OverlayWindowController: NSObject {
    private let model: OverlayViewModel
    private let panel: OverlayPanel
    private let contextMenu = NSMenu()
    private let opacityMenu = NSMenu(title: "透明度")
    private let opacityMenuItem = NSMenuItem(title: "透明度", action: nil, keyEquivalent: "")
    private let colorMenu = NSMenu(title: "歌词颜色")
    private let colorMenuItem = NSMenuItem(title: "歌词颜色", action: nil, keyEquivalent: "")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var cancellables: Set<AnyCancellable> = []

    init(model: OverlayViewModel) {
        self.model = model
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 222),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        configureMenu()
        statusItem.button?.image = NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "酷狗歌词"
        )
        statusItem.button?.toolTip = "酷狗歌词"
        statusItem.button?.setAccessibilityLabel("酷狗歌词")
        statusItem.button?.setAccessibilityIdentifier("lyricsStatusItem")
        statusItem.menu = contextMenu
        let hostingView = OverlayHostingView(rootView: OverlayView(model: model))
        hostingView.overlayMenu = contextMenu
        panel.contentView = hostingView

        model.$lineCount.sink { [weak self] _ in
            self?.resize()
            self?.updateMenuState()
        }.store(in: &cancellables)
        model.$opacity.sink { [weak self] value in
            self?.panel.alphaValue = value
            self?.updateMenuState()
        }.store(in: &cancellables)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        resize()
        restorePosition()
        panel.orderFrontRegardless()
    }

    private func configureMenu() {
        contextMenu.addItem(makeMenuItem(title: "三行歌词", action: #selector(selectLineCount(_:)), tag: 3))
        contextMenu.addItem(makeMenuItem(title: "五行歌词", action: #selector(selectLineCount(_:)), tag: 5))
        opacityMenuItem.submenu = opacityMenu
        contextMenu.addItem(opacityMenuItem)
        for value in [40, 60, 80, 100] {
            opacityMenu.addItem(makeMenuItem(title: "\(value)%", action: #selector(selectOpacity(_:)), tag: value))
        }
        colorMenuItem.submenu = colorMenu
        contextMenu.addItem(colorMenuItem)
        for preset in LyricsColorPreset.allCases {
            let item = makeMenuItem(title: preset.title, action: #selector(selectColor(_:)))
            item.representedObject = preset.rawValue
            colorMenu.addItem(item)
        }
        contextMenu.addItem(.separator())
        contextMenu.addItem(makeMenuItem(title: "重新获取歌词", action: #selector(reloadLyrics(_:))))
        contextMenu.addItem(makeMenuItem(title: "导入 LRC…", action: #selector(importLRC(_:))))
        contextMenu.addItem(.separator())
        contextMenu.addItem(makeMenuItem(title: "退出", action: #selector(quitApplication(_:))))
        updateMenuState()
    }

    private func makeMenuItem(title: String, action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag
        return item
    }

    private func updateMenuState() {
        for item in contextMenu.items where item.tag == 3 || item.tag == 5 {
            item.state = item.tag == model.lineCount ? .on : .off
        }
        let opacity = Int((model.opacity * 100).rounded())
        opacityMenuItem.title = "透明度 \(opacity)%"
        for item in opacityMenu.items {
            item.state = item.tag == opacity ? .on : .off
        }
        colorMenuItem.title = "歌词颜色 \(model.colorPreset.title)"
        for item in colorMenu.items {
            item.state = item.representedObject as? String == model.colorPreset.rawValue ? .on : .off
        }
    }

    @objc private func selectLineCount(_ sender: NSMenuItem) {
        model.lineCount = sender.tag
    }

    @objc private func selectOpacity(_ sender: NSMenuItem) {
        model.opacity = Double(sender.tag) / 100
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        model.colorPreset = LyricsColorPreset(storedValue: sender.representedObject as? String)
        updateMenuState()
    }

    @objc private func reloadLyrics(_ sender: NSMenuItem) {
        model.reloadLyrics()
    }

    @objc private func importLRC(_ sender: NSMenuItem) {
        model.importLRC()
    }

    @objc private func quitApplication(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func resize() {
        let size = NSSize(width: 760, height: model.lineCount == 3 ? 146 : 222)
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "overlayOriginX") != nil,
           defaults.object(forKey: "overlayOriginY") != nil {
            let origin = NSPoint(
                x: defaults.double(forKey: "overlayOriginX"),
                y: defaults.double(forKey: "overlayOriginY")
            )
            let candidate = NSRect(origin: origin, size: panel.frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(candidate) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + 80
        ))
    }

    @objc private func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "overlayOriginX")
        UserDefaults.standard.set(origin.y, forKey: "overlayOriginY")
    }
}

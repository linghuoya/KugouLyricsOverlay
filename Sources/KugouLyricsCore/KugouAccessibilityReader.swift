import AppKit
import ApplicationServices

public enum KugouReadResult: Sendable {
    case permissionRequired
    case notRunning
    case noPlaybackInfo
    case available(KugouPlaybackState)
}

public struct KugouAccessibilityReader: Sendable {
    public init() {}

    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestPermission() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public func read() -> KugouReadResult {
        guard Self.isTrusted else { return .permissionRequired }
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.kugou.mac.Music"
        ).first else {
            return .notRunning
        }

        let root = AXUIElementCreateApplication(application.processIdentifier)
        var entries: [KugouAXEntry] = []
        var visited = 0
        collect(root, entries: &entries, visited: &visited)
        guard let state = KugouAXSnapshotParser.parse(entries) else {
            return .noPlaybackInfo
        }
        return .available(state)
    }

    private func collect(_ element: AXUIElement, entries: inout [KugouAXEntry], visited: inout Int) {
        guard visited < 6_000 else { return }
        visited += 1

        let role = stringAttribute(kAXRoleAttribute, of: element) ?? ""
        if role == "AXStaticText" || role == "AXButton",
           let text = displayText(of: element), !text.isEmpty {
            entries.append(KugouAXEntry(
                role: role,
                identifier: stringAttribute("AXIdentifier", of: element),
                text: text
            ))
        }
        let children = attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
        for child in children {
            collect(child, entries: &entries, visited: &visited)
        }
    }

    private func displayText(of element: AXUIElement) -> String? {
        for name in [kAXDescriptionAttribute, kAXValueAttribute, kAXTitleAttribute] {
            guard let value = stringAttribute(name, of: element)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }
            return value
        }
        return nil
    }

    private func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
        guard let raw = attribute(name, of: element) else { return nil }
        if let value = raw as? String { return value }
        if let value = raw as? NSAttributedString { return value.string }
        return nil
    }

    private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}

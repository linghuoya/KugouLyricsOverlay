import AppKit
import SwiftUI

@main
enum AppMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: OverlayViewModel?
    private var windowController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = OverlayViewModel()
        let windowController = OverlayWindowController(model: model)
        self.model = model
        self.windowController = windowController
        windowController.show()
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.view.frame = NSRect(
                x: 0,
                y: 0,
                width: SettingsLayout.windowMinWidth,
                height: SettingsLayout.windowMinHeight
            )
            let w = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: SettingsLayout.windowMinWidth,
                    height: SettingsLayout.windowMinHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.contentViewController = host
            w.minSize = NSSize(width: SettingsLayout.windowMinWidth, height: SettingsLayout.windowMinHeight)
            w.title = I18n.t("window.settingsTitle")
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshLocalizedTitle() {
        window?.title = I18n.t("window.settingsTitle")
    }
}

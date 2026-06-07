import Cocoa
import Carbon

// MARK: - Overlay Window (borderless, transparent, click-through)

final class FlagOverlayWindow: NSPanel {
    init(size: CGFloat) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = true
        hidesOnDeactivate = false
        isFloatingPanel = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Overlay View (HUD-style rounded rect + flag + label)

final class FlagOverlayView: NSView {
    var flag: String = EnglishLanguageIcon.globe1.symbol
    var langCode: String = "EN"

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.4, dy: 1.4), xRadius: 10, yRadius: 10)
        NSColor(white: 0.12, alpha: 0.88).setFill()
        bg.fill()

        let flagStr = NSAttributedString(string: flag,
                                         attributes: [.font: NSFont.systemFont(ofSize: 24)])
        let fs = flagStr.size()
        flagStr.draw(at: NSPoint(x: (bounds.width - fs.width) / 2,
                                  y: (bounds.height - fs.height) / 2 + 4))

        let labelStr = NSAttributedString(string: langCode, attributes: [
            .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ])
        let ls = labelStr.size()
        labelStr.draw(at: NSPoint(x: (bounds.width - ls.width) / 2, y: 6))
    }
}

// MARK: - FlagOverlay controller

final class FlagOverlay {
    private let windowSize: CGFloat = 48
    private let overlayWindow: FlagOverlayWindow
    private let overlayView: FlagOverlayView
    private var hideTimer: Timer?

    init() {
        overlayWindow = FlagOverlayWindow(size: windowSize)
        overlayView = FlagOverlayView(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize))
        overlayWindow.contentView = overlayView
    }

    // MARK: - Language detection

    func isRussianActive() -> Bool {
        InputSourceLanguage.isRussianActive()
    }

    var currentFlag: String {
        LanguageIconProvider.icon(isRussian: isRussianActive())
    }

    // MARK: - Show

    func show() {
        hideTimer?.invalidate()

        let russian = isRussianActive()
        overlayView.flag = LanguageIconProvider.icon(isRussian: russian)
        overlayView.langCode = russian ? "RU" : "EN"
        overlayView.needsDisplay = true

        let mouse = NSEvent.mouseLocation
        var x = mouse.x + 13
        var y = mouse.y - 7

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main {
            let vis = screen.visibleFrame
            if x + windowSize > vis.maxX { x = mouse.x - windowSize - 7 }
            if y < vis.minY { y = vis.minY }
            if y + windowSize > vis.maxY { y = vis.maxY - windowSize }
        }

        overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
        overlayWindow.alphaValue = 1.0
        overlayWindow.orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                self.overlayWindow.animator().alphaValue = 0.0
            }, completionHandler: {
                self.overlayWindow.orderOut(nil)
            })
        }
    }
}

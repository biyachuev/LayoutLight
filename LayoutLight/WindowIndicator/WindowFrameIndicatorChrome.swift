import Cocoa

final class WindowFrameIndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class WindowFrameIndicatorView: NSView {
    enum RenderMode {
        case frame
        case edge
    }

    var color: NSColor = .white {
        didSet { if oldValue != color { needsDisplay = true } }
    }
    var thickness: CGFloat = 4 {
        didSet { if oldValue != thickness { needsDisplay = true } }
    }
    var renderMode: RenderMode = .frame {
        didSet { needsDisplay = true }
    }
    var edge: WindowFrameIndicatorEdge = .top {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        switch renderMode {
        case .frame:
            drawFrame()
        case .edge:
            drawEdge()
        }
    }

    private func drawFrame() {
        guard bounds.width > thickness, bounds.height > thickness else { return }
        let rect = bounds.insetBy(dx: thickness / 2, dy: thickness / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        color.setStroke()
        path.lineWidth = thickness
        path.stroke()
    }

    private func drawEdge() {
        let thickness = max(1, min(thickness, min(bounds.width, bounds.height)))
        let rect: NSRect
        switch edge {
        case .top:
            rect = NSRect(x: bounds.minX, y: bounds.maxY - thickness, width: bounds.width, height: thickness)
        case .bottom:
            rect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: thickness)
        case .left:
            rect = NSRect(x: bounds.minX, y: bounds.minY, width: thickness, height: bounds.height)
        case .right:
            rect = NSRect(x: bounds.maxX - thickness, y: bounds.minY, width: thickness, height: bounds.height)
        }
        color.setFill()
        rect.fill()
    }
}

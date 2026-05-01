import Cocoa
import CoreGraphics

enum AXScreenMath {
    static func frameInAppKitCoordinates(axMinX: CGFloat,
                                         axTopY: CGFloat,
                                         width: CGFloat,
                                         height: CGFloat,
                                         referencePoint: CGPoint) -> NSRect {
        let pair = screenDisplayPair(containing: referencePoint) ??
                   screenDisplayPair(containing: CGPoint(x: axMinX, y: axTopY)) ??
                   mainScreenDisplayPair()

        guard let pair else {
            let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
            return NSRect(x: axMinX,
                          y: primaryHeight - axTopY - height,
                          width: width,
                          height: height)
        }

        let localX = axMinX - pair.displayBounds.minX
        let localYFromTop = axTopY - pair.displayBounds.minY
        return frameInAppKitCoordinates(localX: localX,
                                        localYFromTop: localYFromTop,
                                        width: width,
                                        height: height,
                                        screenFrame: pair.screen.frame)
    }

    static func frameInAppKitCoordinates(localX: CGFloat,
                                         localYFromTop: CGFloat,
                                         width: CGFloat,
                                         height: CGFloat,
                                         screenFrame: NSRect) -> NSRect {
        NSRect(x: screenFrame.minX + localX,
               y: screenFrame.maxY - localYFromTop - height,
               width: width,
               height: height)
    }

    static func screenFrame(containing point: CGPoint) -> NSRect? {
        NSScreen.screens.first { $0.frame.contains(point) }?.frame
    }

    private static func screenDisplayPair(containing point: CGPoint) -> (screen: NSScreen, displayBounds: CGRect)? {
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen) else { continue }
            let displayBounds = CGDisplayBounds(displayID)
            if displayBounds.contains(point) {
                return (screen, displayBounds)
            }
        }
        return nil
    }

    private static func mainScreenDisplayPair() -> (screen: NSScreen, displayBounds: CGRect)? {
        let mainDisplayID = CGMainDisplayID()
        let mainDisplayBounds = CGDisplayBounds(mainDisplayID)
        if let mainScreen = NSScreen.screens.first(where: { displayID(for: $0) == mainDisplayID }) {
            return (mainScreen, mainDisplayBounds)
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        return (screen, mainDisplayBounds)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}

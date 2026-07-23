import Cocoa
import ApplicationServices

enum WindowFrameGeometry {
    private static let minWindowWidth: CGFloat = 100
    private static let minWindowHeight: CGFloat = 100

    static func focusedWindowFrame() -> NSRect? {
        focusedWindow()?.frame
    }

    static func focusedWindow() -> (element: AXUIElement, frame: NSRect, windowNumber: CGWindowID?)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let focusedWindowRef,
              let focusedWindow = axElement(focusedWindowRef) else {
            return nil
        }

        let number = windowNumber(of: focusedWindow)
        guard let resolved = frame(of: focusedWindow,
                                   ownerPID: app.processIdentifier,
                                   windowNumber: number) else { return nil }
        return (focusedWindow, resolved.frame, resolved.windowNumber)
    }

    private static func frame(of focusedWindow: AXUIElement,
                              ownerPID: pid_t,
                              windowNumber: CGWindowID?) -> (frame: NSRect, windowNumber: CGWindowID?)? {
        if let windowNumber,
            let frame = cgWindowFrame(ownerPID: ownerPID, windowNumber: windowNumber) {
            return (frame, windowNumber)
        }
        if let window = largestCGWindow(ownerPID: ownerPID) {
            return window
        }

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(focusedWindow, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef.flatMap(axValue),
              let sizeValue = sizeRef.flatMap(axValue) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size),
              isUsableWindowSize(size) else {
            return nil
        }

        let frame = AXScreenMath.frameInAppKitCoordinates(
            axMinX: position.x,
            axTopY: position.y,
            width: size.width,
            height: size.height,
            referencePoint: CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        )
        return (frame, nil)
    }

    private static func windowNumber(of focusedWindow: AXUIElement) -> CGWindowID? {
        var numberRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow, "AXWindowNumber" as CFString, &numberRef) == .success,
              let numberRef else {
            return nil
        }
        guard let number = numberRef as? NSNumber else { return nil }
        return CGWindowID(number.uint32Value)
    }

    private static func cgWindowFrame(ownerPID: pid_t, windowNumber: CGWindowID) -> NSRect? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[String: Any]] else {
            return nil
        }

        return windowList.compactMap { info in
            guard (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowNumber,
                  (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID else {
                return nil
            }
            return cgWindowFrame(from: info)
        }.first
    }

    private static func largestCGWindow(ownerPID: pid_t) -> (frame: NSRect, windowNumber: CGWindowID)? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Chromium exposes several layer-0 utility surfaces before its actual
        // browser window. The main window is the largest usable layer-0 window,
        // not necessarily the first one in front-to-back order.
        return windowList.compactMap { info -> (frame: NSRect, windowNumber: CGWindowID)? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let frame = cgWindowFrame(from: info) else {
                return nil
            }
            return (frame, number)
        }.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
    }

    private static func cgWindowFrame(from info: [String: Any]) -> NSRect? {
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
              isUsableWindowSize(bounds.size) else {
            return nil
        }

        return AXScreenMath.frameInAppKitCoordinates(
            axMinX: bounds.minX,
            axTopY: bounds.minY,
            width: bounds.width,
            height: bounds.height,
            referencePoint: CGPoint(x: bounds.midX, y: bounds.midY)
        )
    }

    static func edgeFrame(for edge: WindowFrameIndicatorEdge, thickness: CGFloat, near windowFrame: NSRect) -> NSRect {
        let thickness = max(1, thickness)

        switch edge {
        case .top:
            return NSRect(x: windowFrame.minX, y: windowFrame.maxY - thickness, width: windowFrame.width, height: thickness)
        case .bottom:
            return NSRect(x: windowFrame.minX, y: windowFrame.minY, width: windowFrame.width, height: thickness)
        case .left:
            return NSRect(x: windowFrame.minX, y: windowFrame.minY, width: thickness, height: windowFrame.height)
        case .right:
            return NSRect(x: windowFrame.maxX - thickness, y: windowFrame.minY, width: thickness, height: windowFrame.height)
        }
    }

    static func hasOwnedWindowAbove(ownerPID: pid_t,
                                    mainWindowNumber: CGWindowID,
                                    intersecting indicatorFrame: NSRect) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        // CGWindowList is front-to-back. Only windows encountered before the
        // focused main window can visually cover its indicator.
        for info in windowList {
            guard let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
                continue
            }
            if number == mainWindowNumber { return false }
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID,
                  (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let frame = cgWindowFrame(from: info) else {
                continue
            }
            if frame.intersects(indicatorFrame) { return true }
        }
        return false
    }

    private static func axValue(_ ref: CFTypeRef) -> AXValue? {
        CFGetTypeID(ref) == AXValueGetTypeID() ? (ref as! AXValue) : nil
    }

    private static func axElement(_ ref: CFTypeRef) -> AXUIElement? {
        CFGetTypeID(ref) == AXUIElementGetTypeID() ? (ref as! AXUIElement) : nil
    }

    private static func isUsableWindowSize(_ size: CGSize) -> Bool {
        size.width >= minWindowWidth && size.height >= minWindowHeight
    }
}

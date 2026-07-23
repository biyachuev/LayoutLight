import Cocoa
import ApplicationServices
import OSLog
import Carbon

private let caretLogger = Logger(subsystem: "com.biyachuev.LayoutLight", category: "CaretIndicator")

// MARK: - Indicator window

private final class CaretIndicatorWindow: NSWindow {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 5, height: 18),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CaretIndicatorView: NSView {
    var color: NSColor = .white {
        didSet { if oldValue != color { needsDisplay = true } }
    }
    var shape: CaretShape = .line {
        didSet { if oldValue != shape { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        let minDim = min(bounds.width, bounds.height)
        let drawOutline = minDim >= 3
        let inset: CGFloat = drawOutline ? 0.5 : 0
        let rect = bounds.insetBy(dx: inset, dy: inset)

        let path: NSBezierPath
        switch shape {
        case .dot:
            path = NSBezierPath(ovalIn: rect)
        case .line, .square, .underline:
            let radius = min(rect.width, rect.height) * 0.2
            path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        }
        color.setFill()
        path.fill()
        if drawOutline {
            // Dark outline keeps a white indicator visible on light backgrounds,
            // but skip it for very thin shapes (e.g. 2-px underline) so the
            // outline doesn't swallow the fill.
            NSColor.black.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }
}

// MARK: - WebKit / Chromium AX text-marker attribute names
//
// Not exposed as public Swift constants, but WebKit and Chromium implement them
// as standard parameterized attributes for web content.

private let kAXSelectedTextMarkerRangeAttribute = "AXSelectedTextMarkerRange" as CFString
private let kAXBoundsForTextMarkerRangeAttribute = "AXBoundsForTextMarkerRange" as CFString
private let kAXSelectedTextMarkerRangeChangedNotification = "AXSelectedTextMarkerRangeChanged" as CFString

// MARK: - Type-checked CF bridges

private func asAXValue(_ ref: CFTypeRef) -> AXValue? {
    CFGetTypeID(ref) == AXValueGetTypeID() ? (ref as! AXValue) : nil
}

private func asAXUIElement(_ ref: CFTypeRef) -> AXUIElement? {
    CFGetTypeID(ref) == AXUIElementGetTypeID() ? (ref as! AXUIElement) : nil
}

private struct CaretGeometry {
    var rect: CGRect
    var anchorX: CGFloat
}

// MARK: - Controller

final class CaretIndicator {
    private let window: CaretIndicatorWindow
    private let view: CaretIndicatorView
    private let isRussianActive: () -> Bool
    private var enabled = false
    private var trusted = false
    private var didLogFirstShow = false

    // Frontmost-app tracking
    private var appActivationObserver: NSObjectProtocol?
    private var appTerminationObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var languageSettingsObserver: NSObjectProtocol?
    private var currentPID: pid_t = 0
    private var appElement: AXUIElement?
    private var observer: AXObserver?
    private var focusedElement: AXUIElement?
    private var focusedElementCanResolveCaret = false

    private var trustWatchTimer: Timer?
    private var pollTimer: Timer?
    private var typingPauseTimer: Timer?
    private var languageSwitchRevealTimer: Timer?
    private var languageSwitchRevealUntil: Date?
    private var waitingForTypingPause = false

    init(isRussianActive: @escaping () -> Bool) {
        self.isRussianActive = isRussianActive
        let v = CaretIndicatorView(frame: NSRect(x: 0, y: 0, width: 5, height: 18))
        let w = CaretIndicatorWindow()
        w.contentView = v
        self.window = w
        self.view = v

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .caretSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applySettingsChange()
        }
        languageSettingsObserver = NotificationCenter.default.addObserver(
            forName: .languageIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applySettingsChange()
        }
    }

    deinit {
        stopTrustWatch()
        stopTracking()
        if let s = settingsObserver { NotificationCenter.default.removeObserver(s) }
        if let s = languageSettingsObserver { NotificationCenter.default.removeObserver(s) }
    }

    // MARK: - Public

    var onAccessibilityStateChanged: (() -> Void)?

    var isWaitingForAccessibilityPermission: Bool {
        enabled && !trusted
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func setEnabled(_ on: Bool) {
        if on == enabled { return }
        enabled = on
        if on {
            promptForAccessibility()
            if AXIsProcessTrusted() {
                trusted = true
                startTracking()
                caretLogger.debug("Accessibility already granted")
            } else {
                caretLogger.debug("Waiting for Accessibility")
                startTrustWatch()
            }
        } else {
            stopTrustWatch()
            stopTracking()
            hideIndicator()
            trusted = false
            didLogFirstShow = false
        }
        onAccessibilityStateChanged?()
    }

    func refreshColor() {
        let language = LanguageIndicatorSettingsStore.shared.settings
        let new = (isRussianActive() ? language.colorRU : language.colorEN).nsColor
        if new != view.color {
            view.color = new
            view.needsDisplay = true
        }
    }

    func revealAfterInputSourceChange(duration: TimeInterval = 0.5) {
        guard enabled, trusted else { return }

        languageSwitchRevealTimer?.invalidate()
        languageSwitchRevealUntil = Date().addingTimeInterval(duration)

        syncToFrontmostApp()
        updateIndicator()

        let t = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.languageSwitchRevealTimer = nil
            self.languageSwitchRevealUntil = nil
            if self.waitingForTypingPause {
                self.hideIndicator()
            } else {
                self.updateIndicator()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        languageSwitchRevealTimer = t
    }

    private func applySettingsChange() {
        // Settings changed (shape, dimensions, colors). Re-render at next tick.
        view.shape = CaretSettingsStore.shared.settings.shape
        refreshColor()
        if !CaretSettingsStore.shared.settings.hideWhileTyping {
            clearTypingPauseSuppression()
        }
        syncToFrontmostApp()
        updateIndicator()
    }

    // MARK: - Permission

    private func promptForAccessibility() {
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [prompt: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    private func startTrustWatch() {
        trustWatchTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.trusted = true
                self.stopTrustWatch()
                self.startTracking()
                caretLogger.debug("Accessibility granted")
                self.onAccessibilityStateChanged?()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        trustWatchTimer = t
    }

    private func stopTrustWatch() {
        trustWatchTimer?.invalidate()
        trustWatchTimer = nil
    }

    // MARK: - App tracking

    private func startTracking() {
        let nc = NSWorkspace.shared.notificationCenter
        appActivationObserver = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.attachToApp(pid: app.processIdentifier, bundleId: app.bundleIdentifier)
            }
        }
        appTerminationObserver = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier == self.currentPID else { return }
            self.teardownAppObserver()
            self.hideIndicator()
            if let front = NSWorkspace.shared.frontmostApplication {
                self.attachToApp(pid: front.processIdentifier, bundleId: front.bundleIdentifier)
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            attachToApp(pid: front.processIdentifier, bundleId: front.bundleIdentifier)
        }

        let t = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.pollIndicatorIfNeeded()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func stopTracking() {
        if let obs = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appActivationObserver = nil
        }
        if let obs = appTerminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appTerminationObserver = nil
        }
        teardownAppObserver()
        pollTimer?.invalidate()
        pollTimer = nil
        languageSwitchRevealTimer?.invalidate()
        languageSwitchRevealTimer = nil
        languageSwitchRevealUntil = nil
        clearTypingPauseSuppression()
    }

    private func attachToApp(pid: pid_t, bundleId: String?) {
        if pid == currentPID { return }
        teardownAppObserver()
        currentPID = pid

        let app = AXUIElementCreateApplication(pid)
        appElement = app

        var newObserver: AXObserver?
        let createStatus = AXObserverCreate(pid, Self.axCallback, &newObserver)
        guard createStatus == .success, let obs = newObserver else {
#if DEBUG
            caretLogger.debug("AXObserverCreate rejected for pid=\(pid), bundle=\(bundleId ?? "?", privacy: .private), status=\(String(describing: createStatus), privacy: .public)")
#endif
            updateIndicator()
            return
        }
        observer = obs

        // The app delegate owns CaretIndicator for the whole app lifetime; observers
        // are removed before teardown, so this unretained callback ref stays valid.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        addAXNotification(obs,
                          element: app,
                          notification: kAXFocusedUIElementChangedNotification as CFString,
                          refcon: refcon,
                          context: "app focus")
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(obs),
                           .defaultMode)

#if DEBUG
        caretLogger.debug("Attached to \(bundleId ?? "pid=\(pid)", privacy: .private)")
#endif

        if let focused = copyFocusedUIElement(of: app) {
            attachToFocused(focused)
        } else {
            detachFocused()
        }
        updateIndicator()
    }

    private func teardownAppObserver() {
        detachFocused()
        if let obs = observer, let app = appElement {
            AXObserverRemoveNotification(obs, app, kAXFocusedUIElementChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
        }
        observer = nil
        appElement = nil
        currentPID = 0
    }

    private func attachToFocused(_ element: AXUIElement) {
        detachFocused()
        focusedElement = element
        focusedElementCanResolveCaret = canResolveCaret(in: element)
        guard focusedElementCanResolveCaret else {
            hideIndicator()
            return
        }
        guard let obs = observer else { return }
        // See attachToApp: CaretIndicator outlives the AX observer callbacks.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        addAXNotification(obs,
                          element: element,
                          notification: kAXSelectedTextChangedNotification as CFString,
                          refcon: refcon,
                          context: "selected text")
        addAXNotification(obs,
                          element: element,
                          notification: kAXSelectedTextMarkerRangeChangedNotification,
                          refcon: refcon,
                          context: "text marker range")
        addAXNotification(obs,
                          element: element,
                          notification: kAXValueChangedNotification as CFString,
                          refcon: refcon,
                          context: "value")
    }

    private func addAXNotification(_ observer: AXObserver,
                                   element: AXUIElement,
                                   notification: CFString,
                                   refcon: UnsafeMutableRawPointer,
                                   context: String) {
        let status = AXObserverAddNotification(observer, element, notification, refcon)
#if DEBUG
        if status != .success {
            caretLogger.debug("AXObserverAddNotification failed for \(context, privacy: .public), notification=\(notification as String, privacy: .public), status=\(String(describing: status), privacy: .public)")
        }
#endif
    }

    private func detachFocused() {
        let element = focusedElement
        focusedElement = nil
        focusedElementCanResolveCaret = false
        guard let element else { return }
        if let obs = observer {
            AXObserverRemoveNotification(obs, element, kAXSelectedTextChangedNotification as CFString)
            AXObserverRemoveNotification(obs, element, kAXSelectedTextMarkerRangeChangedNotification)
            AXObserverRemoveNotification(obs, element, kAXValueChangedNotification as CFString)
        }
    }

    // MARK: - AX callback

    private static let axCallback: AXObserverCallback = { _, _, notification, refcon in
        guard let refcon else { return }
        let me = Unmanaged<CaretIndicator>.fromOpaque(refcon).takeUnretainedValue()
        let name = notification as String
        if name == (kAXFocusedUIElementChangedNotification as String) {
            me.clearTypingPauseSuppression()
            if let app = me.appElement, let focused = me.copyFocusedUIElement(of: app) {
                me.attachToFocused(focused)
            } else {
                me.detachFocused()
            }
        } else if me.isTextActivityNotification(name) {
            me.handleTextActivity()
            return
        }
        me.updateIndicator()
    }

    // MARK: - Indicator update

    private func pollIndicatorIfNeeded() {
        guard enabled,
              trusted,
              !waitingForTypingPause else { return }
        syncToFrontmostApp()
        guard focusedElement != nil,
              focusedElementCanResolveCaret else { return }
        updateIndicator()
    }

    private func syncToFrontmostApp() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != currentPID else { return }
        attachToApp(pid: front.processIdentifier, bundleId: front.bundleIdentifier)
    }

    private func updateIndicator() {
        guard !IsSecureEventInputEnabled() else {
            hideIndicator()
            return
        }
        guard enabled, trusted, let element = focusedElement else {
            hideIndicator()
            return
        }
        guard focusedElementCanResolveCaret else {
            hideIndicator()
            return
        }
        guard !waitingForTypingPause || isLanguageSwitchRevealActive else {
            hideIndicator()
            return
        }
        guard !hasNonEmptySelection(in: element) else {
            hideIndicator()
            return
        }
        guard let caret = caretGeometryViaCFRange(element) ?? caretGeometryViaTextMarker(element) else {
            hideIndicator()
            return
        }
        if !didLogFirstShow {
            didLogFirstShow = true
            caretLogger.debug("First caret rect resolved")
        }
        showIndicator(at: caret)
    }

    private func isTextActivityNotification(_ name: String) -> Bool {
        name == (kAXSelectedTextChangedNotification as String) ||
        name == (kAXSelectedTextMarkerRangeChangedNotification as String) ||
        name == (kAXValueChangedNotification as String)
    }

    private func handleTextActivity() {
        let settings = CaretSettingsStore.shared.settings
        guard settings.hideWhileTyping else {
            updateIndicator()
            return
        }

        waitingForTypingPause = true
        if !isLanguageSwitchRevealActive {
            hideIndicator()
        }
        typingPauseTimer?.invalidate()

        let t = Timer(timeInterval: settings.typingResumeDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.typingPauseTimer = nil
            self.waitingForTypingPause = false
            self.updateIndicator()
        }
        RunLoop.main.add(t, forMode: .common)
        typingPauseTimer = t
    }

    private func clearTypingPauseSuppression() {
        typingPauseTimer?.invalidate()
        typingPauseTimer = nil
        waitingForTypingPause = false
    }

    private var isLanguageSwitchRevealActive: Bool {
        guard let until = languageSwitchRevealUntil else { return false }
        if until > Date() { return true }
        languageSwitchRevealUntil = nil
        return false
    }

    private func showIndicator(at caret: CaretGeometry) {
        let s = CaretSettingsStore.shared.settings
        let russianActive = isRussianActive()
        let cfg = s.active
        let language = LanguageIndicatorSettingsStore.shared.settings
        guard russianActive ? language.showForRU : language.showForEN else {
            hideIndicator()
            return
        }

        view.shape = s.shape
        let newColor = (russianActive ? language.colorRU : language.colorEN).nsColor
        if newColor != view.color {
            view.color = newColor
            view.needsDisplay = true
        }

        let w = CGFloat(cfg.width)
        let h = CGFloat(cfg.height)
        let gap = CGFloat(cfg.gap)
        let caretRect = caret.rect

        let screenTopY = verticalScreenTopY(for: s.shape, caretRect: caretRect, height: h, config: cfg)
        let screenLeftX = horizontalScreenLeftX(for: s.shape,
                                                caret: caret,
                                                width: w,
                                                gap: gap)
        let frame = AXScreenMath.frameInAppKitCoordinates(
            axMinX: screenLeftX,
            axTopY: screenTopY,
            width: w,
            height: h,
            referencePoint: CGPoint(x: caretRect.midX, y: caretRect.midY)
        )

        window.setFrame(frame, display: true)
        if !window.isVisible { window.orderFront(nil) }
    }

    private func verticalScreenTopY(for shape: CaretShape,
                                    caretRect: CGRect,
                                    height: CGFloat,
                                    config: CaretShapeConfig) -> CGFloat {
        let baseTopY: CGFloat
        switch shape {
        case .underline:
            baseTopY = caretRect.maxY - height
        case .square where config.verticalPlacement == .aboveText,
             .dot where config.verticalPlacement == .aboveText:
            baseTopY = caretRect.minY
        case .line, .square, .dot:
            baseTopY = caretRect.minY + (caretRect.height - height) / 2
        }

        return baseTopY + CGFloat(config.verticalOffset)
    }

    private func horizontalScreenLeftX(for shape: CaretShape,
                                       caret: CaretGeometry,
                                       width: CGFloat,
                                       gap: CGFloat) -> CGFloat {
        switch shape {
        case .underline:
            return caret.anchorX + gap
        case .line, .square, .dot:
            return caret.rect.maxX + gap
        }
    }

    private func hideIndicator() {
        if window.isVisible { window.orderOut(nil) }
    }

    private func canResolveCaret(in element: AXUIElement) -> Bool {
        if let role = copyStringAttribute(kAXRoleAttribute as CFString, of: element),
           Self.textLikeRoles.contains(role) {
            return true
        }

        if let attributes = copyAttributeNames(of: element),
           attributes.contains(kAXSelectedTextRangeAttribute as String) ||
           attributes.contains(kAXSelectedTextMarkerRangeAttribute as String) {
            return true
        }

        if let parameterized = copyParameterizedAttributeNames(of: element),
           parameterized.contains(kAXBoundsForRangeParameterizedAttribute as String) ||
           parameterized.contains(kAXBoundsForTextMarkerRangeAttribute as String) {
            return true
        }

        return false
    }

    private static let textLikeRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField",
        "AXWebArea"
    ]

    private func copyStringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard axCall(AXUIElementCopyAttributeValue(element, attribute, &valueRef), element: element),
              let value = valueRef as? String else { return nil }
        return value
    }

    private func copyAttributeNames(of element: AXUIElement) -> Set<String>? {
        var namesRef: CFArray?
        guard axCall(AXUIElementCopyAttributeNames(element, &namesRef), element: element),
              let names = namesRef else { return nil }
        return Set((names as NSArray).compactMap { $0 as? String })
    }

    private func copyParameterizedAttributeNames(of element: AXUIElement) -> Set<String>? {
        var namesRef: CFArray?
        guard axCall(AXUIElementCopyParameterizedAttributeNames(element, &namesRef), element: element),
              let names = namesRef else { return nil }
        return Set((names as NSArray).compactMap { $0 as? String })
    }

    private func axCall(_ status: AXError, element: AXUIElement) -> Bool {
        guard status == .success else {
            if status == .invalidUIElement {
                handleStaleFocusedElement(element)
            }
            return false
        }
        return true
    }

    private func handleStaleFocusedElement(_ element: AXUIElement) {
        guard let focusedElement, CFEqual(focusedElement, element) else { return }
        detachFocused()
        hideIndicator()
    }

    // MARK: - Caret rect: native CFRange path

    private func hasNonEmptySelection(in element: AXUIElement) -> Bool {
        if let range = selectedTextRange(in: element) {
            return range.length > 0
        }

        return false
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var rangeRef: CFTypeRef?
        guard axCall(AXUIElementCopyAttributeValue(element,
                                                   kAXSelectedTextRangeAttribute as CFString,
                                                   &rangeRef), element: element),
              let rv = rangeRef, let rangeValue = asAXValue(rv) else { return nil }

        var selRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue, .cfRange, &selRange) else { return nil }
        return selRange
    }

    private func caretGeometryViaCFRange(_ element: AXUIElement) -> CaretGeometry? {
        guard let selRange = selectedTextRange(in: element),
              selRange.length == 0 else { return nil }

        let caretRange = CFRange(location: selRange.location, length: 0)
        guard var rect = boundsForRange(caretRange, in: element) else { return nil }
        let anchorX = caretAnchorX(for: selRange, fallbackRect: rect, in: element)

        if let glyphRect = nearbyGlyphRect(for: selRange, in: element),
           glyphRect.height <= rect.height * 1.2,
           abs(glyphRect.midY - rect.midY) <= rect.height {
            rect.origin.y = glyphRect.origin.y
            rect.size.height = glyphRect.height
        }

        guard isUsableRect(rect), anchorX.isFinite else { return nil }
        return CaretGeometry(rect: rect, anchorX: anchorX)
    }

    private func caretAnchorX(for selectedRange: CFRange,
                              fallbackRect: CGRect,
                              in element: AXUIElement) -> CGFloat {
        if fallbackRect.width <= 2 {
            return fallbackRect.midX
        }

        let nextCharacter = CFRange(location: selectedRange.location, length: 1)
        if let rect = boundsForRange(nextCharacter, in: element), isUsableRect(rect) {
            return rect.minX
        }

        if selectedRange.location > 0 {
            let previousCharacter = CFRange(location: selectedRange.location - 1, length: 1)
            if let rect = boundsForRange(previousCharacter, in: element), isUsableRect(rect) {
                return rect.maxX
            }
        }

        return fallbackRect.maxX
    }

    private func nearbyGlyphRect(for selectedRange: CFRange, in element: AXUIElement) -> CGRect? {
        if selectedRange.length > 0 {
            let firstSelected = CFRange(location: selectedRange.location, length: 1)
            return boundsForRange(firstSelected, in: element)
        }

        let nextCharacter = CFRange(location: selectedRange.location, length: 1)
        if let rect = boundsForRange(nextCharacter, in: element) {
            return rect
        }

        guard selectedRange.location > 0 else { return nil }
        let previousCharacter = CFRange(location: selectedRange.location - 1, length: 1)
        return boundsForRange(previousCharacter, in: element)
    }

    private func boundsForRange(_ range: CFRange, in element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let axRange = AXValueCreate(.cfRange, &mutableRange) else { return nil }

        var boundsRef: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            axRange,
            &boundsRef
        )
        guard axCall(status, element: element),
              let bv = boundsRef,
              let boundsValue = asAXValue(bv) else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue, .cgRect, &rect) else { return nil }
        guard isUsableRect(rect) else { return nil }
        return rect
    }

    // MARK: - Caret rect: WebKit / Chromium text-marker path

    private func caretGeometryViaTextMarker(_ element: AXUIElement) -> CaretGeometry? {
        var rangeRef: CFTypeRef?
        guard axCall(AXUIElementCopyAttributeValue(element,
                                                   kAXSelectedTextMarkerRangeAttribute,
                                                   &rangeRef), element: element),
              let range = rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForTextMarkerRangeAttribute,
            range,
            &boundsRef
        )
        guard axCall(status, element: element),
              let bv = boundsRef,
              let boundsValue = asAXValue(bv) else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue, .cgRect, &rect) else { return nil }
        guard isUsableRect(rect) else { return nil }
        return CaretGeometry(rect: rect, anchorX: rect.maxX)
    }

    private func isUsableRect(_ rect: CGRect) -> Bool {
        rect.width.isFinite &&
        rect.height.isFinite &&
        rect.minX.isFinite &&
        rect.minY.isFinite &&
        rect.height > 0
    }

    // MARK: - Focus helper

    private func copyFocusedUIElement(of app: AXUIElement) -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focused) == .success,
              let f = focused else { return nil }
        return asAXUIElement(f)
    }
}

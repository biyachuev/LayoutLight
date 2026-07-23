import Cocoa
import ApplicationServices
import Carbon

final class WindowFrameIndicator {
    private var window: WindowFrameIndicatorWindow
    private let view: WindowFrameIndicatorView
    private let isRussianActive: () -> Bool
    private var enabled = false
    private var activationObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var caretSettingsObserver: NSObjectProtocol?
    private var languageSettingsObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private var dragPollTimer: Timer?
    private var screenRefreshGeneration = 0
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var isSuppressedByMenuBar = false
    private var didPromptForAccessibility = false
    private var currentPID: pid_t = 0
    private var appElement: AXUIElement?
    private var windowObserver: AXObserver?
    private var observedWindow: AXUIElement?

    init(isRussianActive: @escaping () -> Bool) {
        self.isRussianActive = isRussianActive
        let view = WindowFrameIndicatorView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let window = WindowFrameIndicatorWindow()
        window.contentView = view
        self.view = view
        self.window = window

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .windowFrameIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
        caretSettingsObserver = NotificationCenter.default.addObserver(
            forName: .caretSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        languageSettingsObserver = NotificationCenter.default.addObserver(
            forName: .languageIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        stop()
        if let observer = settingsObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = caretSettingsObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = languageSettingsObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func setEnabled(_ on: Bool) {
        if on == enabled { return }
        enabled = on
        if on {
            start()
        } else {
            stop()
        }
    }

    func refresh() {
        guard enabled else { return }
        guard !IsSecureEventInputEnabled() else {
            hide()
            return
        }
        guard updateColor() else { return }
        guard !isMouseInMenuBarArea else {
            isSuppressedByMenuBar = true
            hide()
            return
        }
        isSuppressedByMenuBar = false
        guard hasAccessibilityPermission else {
            promptForAccessibilityIfNeeded()
            teardownWindowObserver()
            hide()
            return
        }
        guard let focusedWindow = WindowFrameGeometry.focusedWindow(),
              !focusedWindow.frame.isEmpty else {
            teardownWindowObserver()
            hide()
            return
        }
        observeFocusedWindow(focusedWindow.element)

        let frame = focusedWindow.frame

        let settings = WindowFrameIndicatorSettingsStore.shared.settings
        let thickness = CGFloat(settings.thickness)
        view.thickness = thickness

        let indicatorFrame: NSRect
        switch settings.mode {
        case .frame:
            indicatorFrame = frame
        case .edge:
            indicatorFrame = WindowFrameGeometry.edgeFrame(for: settings.edge,
                                                           thickness: thickness,
                                                           near: frame)
        }
        if let windowNumber = focusedWindow.windowNumber,
           WindowFrameGeometry.hasOwnedWindowAbove(ownerPID: currentPID,
                                                   mainWindowNumber: windowNumber,
                                                   intersecting: indicatorFrame) {
            hide()
            return
        }

        switch settings.mode {
        case .frame:
            view.renderMode = .frame
            // Keep the overlay inside the focused window bounds. Full-screen
            // windows often match the screen bounds exactly; expanding the overlay
            // outward clips 1-pixel strokes on the left/bottom edges.
            window.setFrame(frame, display: true)
        case .edge:
            view.renderMode = .edge
            view.edge = settings.edge
            window.setFrame(frame, display: true)
        }

        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    private func start() {
        promptForAccessibilityIfNeeded()

        let nc = NSWorkspace.shared.notificationCenter
        activationObserver = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
        installMouseMonitors()
        refresh()
    }

    private func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
        invalidatePendingScreenRefreshes()
        pollTimer?.invalidate()
        pollTimer = nil
        stopDragPolling()
        removeMouseMonitors()
        teardownWindowObserver()
        isSuppressedByMenuBar = false
        hide()
    }

    private func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    private func handleScreenParametersChanged() {
        guard enabled else { return }

        invalidatePendingScreenRefreshes()
        hide()
        recreateWindow()

        refresh()
        scheduleScreenRefresh(after: 0.2)
        scheduleScreenRefresh(after: 0.8)
    }

    private func recreateWindow() {
        window.contentView = nil
        window.close()

        let newWindow = WindowFrameIndicatorWindow()
        newWindow.contentView = view
        window = newWindow
    }

    private func scheduleScreenRefresh(after delay: TimeInterval) {
        let generation = screenRefreshGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.enabled, self.screenRefreshGeneration == generation else { return }
            self.refresh()
        }
    }

    private func invalidatePendingScreenRefreshes() {
        screenRefreshGeneration &+= 1
    }

    private func removeMouseMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard enabled else { return }
        switch event.type {
        case .mouseMoved:
            updateMenuBarSuppression()
        case .leftMouseDown, .leftMouseDragged:
            updateMenuBarSuppression()
            guard !isSuppressedByMenuBar else { return }
            startDragPolling()
        case .leftMouseUp:
            refresh()
            stopDragPolling(after: 0.12)
        default:
            break
        }
    }

    private func updateMenuBarSuppression() {
        let shouldSuppress = isMouseInMenuBarArea
        guard shouldSuppress != isSuppressedByMenuBar else { return }
        isSuppressedByMenuBar = shouldSuppress
        if shouldSuppress {
            stopDragPolling()
            hide()
        } else {
            refresh()
        }
    }

    private func startDragPolling() {
        guard dragPollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard NSEvent.pressedMouseButtons != 0 else {
                self.refresh()
                self.stopDragPolling()
                return
            }
            self.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        dragPollTimer = timer
        refresh()
    }

    private func stopDragPolling(after delay: TimeInterval = 0) {
        guard delay > 0 else {
            dragPollTimer?.invalidate()
            dragPollTimer = nil
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, NSEvent.pressedMouseButtons == 0 else { return }
            self.stopDragPolling()
        }
    }

    private func observeFocusedWindow(_ windowElement: AXUIElement) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        if frontmost.processIdentifier != currentPID {
            teardownWindowObserver()
            currentPID = frontmost.processIdentifier
            appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
            var newObserver: AXObserver?
            guard AXObserverCreate(frontmost.processIdentifier, Self.axCallback, &newObserver) == .success,
                  let newObserver else {
                teardownWindowObserver()
                return
            }
            windowObserver = newObserver
            CFRunLoopAddSource(CFRunLoopGetMain(),
                               AXObserverGetRunLoopSource(newObserver),
                               .commonModes)
            if let appElement {
                addAXNotification(kAXFocusedWindowChangedNotification as CFString, to: appElement)
            }
        }

        guard observedWindow.map({ !CFEqual($0, windowElement) }) ?? true else { return }
        removeObservedWindowNotifications()
        observedWindow = windowElement
        addAXNotification(kAXMovedNotification as CFString, to: windowElement)
        addAXNotification(kAXResizedNotification as CFString, to: windowElement)
    }

    private func addAXNotification(_ notification: CFString, to element: AXUIElement) {
        guard let windowObserver else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        _ = AXObserverAddNotification(windowObserver, element, notification, refcon)
    }

    private func removeObservedWindowNotifications() {
        guard let windowObserver, let observedWindow else { return }
        AXObserverRemoveNotification(windowObserver, observedWindow, kAXMovedNotification as CFString)
        AXObserverRemoveNotification(windowObserver, observedWindow, kAXResizedNotification as CFString)
    }

    private func teardownWindowObserver() {
        removeObservedWindowNotifications()
        if let windowObserver, let appElement {
            AXObserverRemoveNotification(windowObserver, appElement, kAXFocusedWindowChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  AXObserverGetRunLoopSource(windowObserver),
                                  .commonModes)
        }
        observedWindow = nil
        windowObserver = nil
        appElement = nil
        currentPID = 0
    }

    private static let axCallback: AXObserverCallback = { _, _, _, refcon in
        guard let refcon else { return }
        let indicator = Unmanaged<WindowFrameIndicator>.fromOpaque(refcon).takeUnretainedValue()
        DispatchQueue.main.async {
            indicator.refresh()
        }
    }

    private func applySettings() {
        let settings = WindowFrameIndicatorSettingsStore.shared.settings
        setEnabled(settings.isEnabled)
        refresh()
    }

    private func updateColor() -> Bool {
        let language = LanguageIndicatorSettingsStore.shared.settings
        let russianActive = isRussianActive()
        guard russianActive ? language.showForRU : language.showForEN else {
            hide()
            return false
        }
        let color = (russianActive ? language.colorRU : language.colorEN).nsColor
        if view.color != color {
            view.color = color
        }
        return true
    }

    private func hide() {
        if window.isVisible {
            window.orderOut(nil)
        }
    }

    private var isMouseInMenuBarArea: Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            return false
        }
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let threshold = max(24, min(44, menuBarHeight > 0 ? menuBarHeight : 24))
        return point.y >= screen.frame.maxY - threshold
    }

    private var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    private func promptForAccessibilityIfNeeded() {
        guard !hasAccessibilityPermission, !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        let options = [prompt: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

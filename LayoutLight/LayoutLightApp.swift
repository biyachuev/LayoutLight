import SwiftUI

@main
struct LayoutLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var menuState = MenuBarState.shared
    @StateObject private var windowSettings = WindowFrameIndicatorSettingsStore.shared
    @StateObject private var languageStore = InterfaceLanguageStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                state: menuState,
                windowSettings: windowSettings,
                languageStore: languageStore
            )
        } label: {
            MenuBarLabel(state: menuState)
        }
        .menuBarExtraStyle(.menu)

        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeys = HotKeyManager()
    private let flagOverlay = FlagOverlay()
    private let inputSourceObserver = InputSourceObserver()
    private let settingsWindowController = SettingsWindowController()

    private lazy var caretIndicator = CaretIndicator(isRussianActive: { [weak self] in
        self?.flagOverlay.isRussianActive() ?? false
    })
    private lazy var windowFrameIndicator = WindowFrameIndicator(isRussianActive: { [weak self] in
        self?.flagOverlay.isRussianActive() ?? false
    })

    private let menuState = MenuBarState.shared
    private var showOverlayOnSwitch = false
    private var colorCaretByLanguage = false
    private var settingsObserver: NSObjectProtocol?
    private var hotKeySettingsObserver: NSObjectProtocol?
    private var shortcutRecordingObserver: NSObjectProtocol?
    private var interfaceLanguageObserver: NSObjectProtocol?
    private var languageIndicatorSettingsObserver: NSObjectProtocol?
    private var windowFrameSettingsObserver: NSObjectProtocol?
    private var isRecordingShortcut = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        showOverlayOnSwitch = UserDefaults.standard.object(forKey: DefaultsKey.showOverlayOnSwitch) as? Bool ?? false
        colorCaretByLanguage = UserDefaults.standard.bool(forKey: DefaultsKey.colorCaretByLanguage)

        menuState.currentFlag = flagOverlay.currentFlag
        menuState.showOverlayOnSwitch = showOverlayOnSwitch
        menuState.colorCaretByLanguage = colorCaretByLanguage
        wireMenuStateCallbacks()

        caretIndicator.onAccessibilityStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.refreshCaretAccessibilityState() }
        }
        refreshCaretAccessibilityState()
        if colorCaretByLanguage { caretIndicator.setEnabled(true) }
        applyWindowFrameIndicatorSettings()

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .caretSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.windowFrameIndicator.refresh()
        }
        hotKeySettingsObserver = NotificationCenter.default.addObserver(
            forName: .hotKeySettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isRecordingShortcut else { return }
            self.hotkeys.start()
        }
        shortcutRecordingObserver = NotificationCenter.default.addObserver(
            forName: .shortcutRecordingChanged, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let isRecording = notification.userInfo?["isRecording"] as? Bool ?? false
            self.isRecordingShortcut = isRecording
            if isRecording {
                self.hotkeys.stop()
            } else {
                self.hotkeys.start()
            }
        }
        interfaceLanguageObserver = NotificationCenter.default.addObserver(
            forName: .interfaceLanguageChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshLocalizedTexts()
        }
        languageIndicatorSettingsObserver = NotificationCenter.default.addObserver(
            forName: .languageIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshLanguageIndicators()
        }
        windowFrameSettingsObserver = NotificationCenter.default.addObserver(
            forName: .windowFrameIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyWindowFrameIndicatorSettings()
        }

        hotkeys.onShowFlag = { [weak self] in
            DispatchQueue.main.async { self?.showFlag() }
        }
        hotkeys.start()

        inputSourceObserver.onInputSourceChanged = { [weak self] in
            self?.inputSourceChanged()
        }
        inputSourceObserver.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
        inputSourceObserver.stop()
        if let s = settingsObserver { NotificationCenter.default.removeObserver(s) }
        if let s = hotKeySettingsObserver { NotificationCenter.default.removeObserver(s) }
        if let s = shortcutRecordingObserver { NotificationCenter.default.removeObserver(s) }
        if let s = interfaceLanguageObserver { NotificationCenter.default.removeObserver(s) }
        if let s = languageIndicatorSettingsObserver { NotificationCenter.default.removeObserver(s) }
        if let s = windowFrameSettingsObserver { NotificationCenter.default.removeObserver(s) }
        windowFrameIndicator.setEnabled(false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func wireMenuStateCallbacks() {
        menuState.onToggleOverlay = { [weak self] in self?.toggleOverlay() }
        menuState.onToggleCaret = { [weak self] in self?.toggleCaretColoring() }
        menuState.onToggleWindowIndicator = { [weak self] in self?.toggleWindowFrameIndicator() }
        menuState.onOpenSettings = { [weak self] in self?.settingsWindowController.show() }
        menuState.onOpenAbout = {
            Task { @MainActor in AboutPanel.show() }
        }
        menuState.onSelectInterfaceLanguage = { choice in
            InterfaceLanguageStore.shared.choice = choice
        }
    }

    private func inputSourceChanged() {
        DispatchQueue.main.async {
            self.menuState.currentFlag = self.flagOverlay.currentFlag
            if self.showOverlayOnSwitch {
                self.flagOverlay.show()
            }
            if self.colorCaretByLanguage {
                self.caretIndicator.revealAfterInputSourceChange()
            }
            self.windowFrameIndicator.refresh()
        }
    }

    private func showFlag() {
        menuState.currentFlag = flagOverlay.currentFlag
        flagOverlay.show()
    }

    private func toggleOverlay() {
        showOverlayOnSwitch.toggle()
        menuState.showOverlayOnSwitch = showOverlayOnSwitch
        UserDefaults.standard.set(showOverlayOnSwitch, forKey: DefaultsKey.showOverlayOnSwitch)
    }

    private func toggleCaretColoring() {
        colorCaretByLanguage.toggle()
        menuState.colorCaretByLanguage = colorCaretByLanguage
        UserDefaults.standard.set(colorCaretByLanguage, forKey: DefaultsKey.colorCaretByLanguage)
        caretIndicator.setEnabled(colorCaretByLanguage)
    }

    private func toggleWindowFrameIndicator() {
        WindowFrameIndicatorSettingsStore.shared.settings.isEnabled.toggle()
    }

    private func applyWindowFrameIndicatorSettings() {
        let enabled = WindowFrameIndicatorSettingsStore.shared.settings.isEnabled
        windowFrameIndicator.setEnabled(enabled)
        windowFrameIndicator.refresh()
    }

    private func refreshCaretAccessibilityState() {
        menuState.caretWaitingForAccessibility = caretIndicator.isWaitingForAccessibilityPermission
        menuState.caretHasAccessibility = caretIndicator.hasAccessibilityPermission
    }

    private func refreshLocalizedTexts() {
        menuState.languageRevision &+= 1
        settingsWindowController.refreshLocalizedTitle()
    }

    private func refreshLanguageIndicators() {
        menuState.currentFlag = flagOverlay.currentFlag
    }
}

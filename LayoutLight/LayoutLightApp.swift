import SwiftUI

@main
struct LayoutLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
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

    private var statusMenu: StatusMenuController!
    private var showOverlayOnSwitch = false
    private var colorCaretByLanguage = false
    private var settingsObserver: NSObjectProtocol?
    private var hotKeySettingsObserver: NSObjectProtocol?
    private var shortcutRecordingObserver: NSObjectProtocol?
    private var interfaceLanguageObserver: NSObjectProtocol?
    private var windowFrameSettingsObserver: NSObjectProtocol?
    private var isRecordingShortcut = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        showOverlayOnSwitch = UserDefaults.standard.object(forKey: DefaultsKey.showOverlayOnSwitch) as? Bool ?? false
        colorCaretByLanguage = UserDefaults.standard.bool(forKey: DefaultsKey.colorCaretByLanguage)

        statusMenu = StatusMenuController(
            currentFlag: flagOverlay.currentFlag,
            showOverlayOnSwitch: showOverlayOnSwitch
        )
        wireStatusMenuCallbacks()

        caretIndicator.onAccessibilityStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.refreshCaretToggleItem() }
        }
        refreshCaretToggleItem()
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
        windowFrameSettingsObserver = NotificationCenter.default.addObserver(
            forName: .windowFrameIndicatorSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyWindowFrameIndicatorSettings()
        }
        refreshLocalizedTexts()

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
        if let s = windowFrameSettingsObserver { NotificationCenter.default.removeObserver(s) }
        windowFrameIndicator.setEnabled(false)
    }

    private func wireStatusMenuCallbacks() {
        statusMenu.onToggleOverlay = { [weak self] in
            self?.toggleOverlay()
        }
        statusMenu.onToggleCaretColoring = { [weak self] in
            self?.toggleCaretColoring()
        }
        statusMenu.onToggleWindowIndicator = { [weak self] in
            self?.toggleWindowFrameIndicator()
        }
        statusMenu.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusMenu.onSelectInterfaceLanguage = { choice in
            InterfaceLanguageStore.shared.choice = choice
        }
    }

    private func inputSourceChanged() {
        DispatchQueue.main.async {
            self.statusMenu.setCurrentFlag(self.flagOverlay.currentFlag)
            if self.showOverlayOnSwitch {
                self.flagOverlay.show()
            }
            if self.colorCaretByLanguage {
                self.caretIndicator.refreshColor()
            }
            self.windowFrameIndicator.refresh()
        }
    }

    private func showFlag() {
        statusMenu.setCurrentFlag(flagOverlay.currentFlag)
        flagOverlay.show()
    }

    private func toggleOverlay() {
        showOverlayOnSwitch.toggle()
        statusMenu.setOverlayEnabled(showOverlayOnSwitch)
        UserDefaults.standard.set(showOverlayOnSwitch, forKey: DefaultsKey.showOverlayOnSwitch)
    }

    private func toggleCaretColoring() {
        colorCaretByLanguage.toggle()
        UserDefaults.standard.set(colorCaretByLanguage, forKey: DefaultsKey.colorCaretByLanguage)
        caretIndicator.setEnabled(colorCaretByLanguage)
        refreshCaretToggleItem()
    }

    private func toggleWindowFrameIndicator() {
        WindowFrameIndicatorSettingsStore.shared.settings.isEnabled.toggle()
    }

    private func applyWindowFrameIndicatorSettings() {
        let enabled = WindowFrameIndicatorSettingsStore.shared.settings.isEnabled
        statusMenu.setWindowIndicatorEnabled(enabled)
        windowFrameIndicator.setEnabled(enabled)
        windowFrameIndicator.refresh()
    }

    private func refreshCaretToggleItem() {
        statusMenu.setCaretColoringEnabled(colorCaretByLanguage, title: caretToggleTitle)
    }

    private var caretToggleTitle: String {
        if caretIndicator.isWaitingForAccessibilityPermission {
            return I18n.t("menu.colorCaretWaiting")
        } else if !caretIndicator.hasAccessibilityPermission {
            return I18n.t("menu.colorCaretNeedsAccessibility")
        } else {
            return I18n.t("menu.colorCaret")
        }
    }

    private func refreshLocalizedTexts() {
        statusMenu.refreshLocalizedTexts(
            caretTitle: caretToggleTitle,
            isCaretColoringEnabled: colorCaretByLanguage
        )
        settingsWindowController.refreshLocalizedTitle()
    }
}

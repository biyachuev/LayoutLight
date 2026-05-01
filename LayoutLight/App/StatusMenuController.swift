import AppKit

final class StatusMenuController: NSObject {
    var onToggleOverlay: (() -> Void)?
    var onToggleCaretColoring: (() -> Void)?
    var onToggleWindowIndicator: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onSelectInterfaceLanguage: ((InterfaceLanguageChoice) -> Void)?

    private let statusItem: NSStatusItem
    private let overlayToggleItem: NSMenuItem
    private let caretToggleItem: NSMenuItem
    private let windowFrameToggleItem: NSMenuItem
    private let interfaceLanguageMenuItem: NSMenuItem
    private let settingsItem: NSMenuItem
    private let quitItem: NSMenuItem

    init(currentFlag: String, showOverlayOnSwitch: Bool) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = currentFlag

        overlayToggleItem = NSMenuItem(title: "", action: #selector(toggleOverlay), keyEquivalent: "")
        caretToggleItem = NSMenuItem(title: "", action: #selector(toggleCaretColoring), keyEquivalent: "")
        windowFrameToggleItem = NSMenuItem(title: "", action: #selector(toggleWindowFrameIndicator), keyEquivalent: "")
        interfaceLanguageMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        settingsItem = NSMenuItem(title: I18n.t("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        quitItem = NSMenuItem(title: I18n.t("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        super.init()

        overlayToggleItem.target = self
        overlayToggleItem.state = showOverlayOnSwitch ? .on : .off
        caretToggleItem.target = self
        windowFrameToggleItem.target = self
        settingsItem.target = self

        let menu = NSMenu()
        menu.addItem(overlayToggleItem)
        menu.addItem(caretToggleItem)
        menu.addItem(windowFrameToggleItem)
        interfaceLanguageMenuItem.submenu = buildInterfaceLanguageSubmenu()
        menu.addItem(interfaceLanguageMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func setCurrentFlag(_ flag: String) {
        statusItem.button?.title = flag
    }

    func setOverlayEnabled(_ isEnabled: Bool) {
        overlayToggleItem.state = isEnabled ? .on : .off
    }

    func setCaretColoringEnabled(_ isEnabled: Bool, title: String) {
        caretToggleItem.state = isEnabled ? .on : .off
        caretToggleItem.title = title
    }

    func setWindowIndicatorEnabled(_ isEnabled: Bool) {
        windowFrameToggleItem.state = isEnabled ? .on : .off
    }

    func refreshLocalizedTexts(caretTitle: String, isCaretColoringEnabled: Bool) {
        overlayToggleItem.title = I18n.t("menu.showFlagOnSwitch")
        windowFrameToggleItem.title = I18n.t("menu.windowFrameIndicator")
        interfaceLanguageMenuItem.title = I18n.t("menu.interfaceLanguage")
        interfaceLanguageMenuItem.submenu = buildInterfaceLanguageSubmenu()
        settingsItem.title = I18n.t("menu.settings")
        quitItem.title = I18n.t("menu.quit")
        setCaretColoringEnabled(isCaretColoringEnabled, title: caretTitle)
    }

    @objc private func toggleOverlay() {
        onToggleOverlay?()
    }

    @objc private func toggleCaretColoring() {
        onToggleCaretColoring?()
    }

    @objc private func toggleWindowFrameIndicator() {
        onToggleWindowIndicator?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func selectInterfaceLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = InterfaceLanguageChoice(rawValue: raw) else { return }
        onSelectInterfaceLanguage?(choice)
    }

    private func buildInterfaceLanguageSubmenu() -> NSMenu {
        let m = NSMenu()
        for choice in InterfaceLanguageChoice.allCases {
            let item = NSMenuItem(title: choice.displayName, action: #selector(selectInterfaceLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = (InterfaceLanguageStore.shared.choice == choice) ? .on : .off
            m.addItem(item)
        }
        return m
    }
}

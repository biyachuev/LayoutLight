import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var state: MenuBarState

    var body: some View {
        Text(state.currentFlag)
    }
}

struct MenuBarContent: View {
    @ObservedObject var state: MenuBarState
    @ObservedObject var windowSettings: WindowFrameIndicatorSettingsStore
    @ObservedObject var languageStore: InterfaceLanguageStore

    var body: some View {
        let _ = state.languageRevision

        Toggle(I18n.t("menu.showFlagOnSwitch"), isOn: binding(state.showOverlayOnSwitch, action: state.onToggleOverlay))
        Toggle(state.caretToggleTitle, isOn: binding(state.colorCaretByLanguage, action: state.onToggleCaret))
        Toggle(I18n.t("menu.windowFrameIndicator"), isOn: binding(windowSettings.settings.isEnabled, action: state.onToggleWindowIndicator))

        Menu(I18n.t("menu.interfaceLanguage")) {
            ForEach(InterfaceLanguageChoice.allCases) { choice in
                Toggle(choice.displayName, isOn: Binding(
                    get: { languageStore.choice == choice },
                    set: { _ in state.onSelectInterfaceLanguage(choice) }
                ))
            }
        }

        Divider()

        Button(I18n.t("menu.settings")) { state.onOpenSettings() }
        Button(String(format: I18n.t("menu.about"), AppInfo.name)) { state.onOpenAbout() }

        Divider()

        Button(I18n.t("menu.quit")) { NSApp.terminate(nil) }
    }

    private func binding(_ value: Bool, action: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: { _ in action() })
    }
}

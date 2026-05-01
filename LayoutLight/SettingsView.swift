import SwiftUI

struct SettingsView: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    @State private var previewLanguage: PreviewLanguage = .en
    @State private var russianPreviewText = PreviewSecurityTip.random()

    var body: some View {
        TabView {
            CaretSettingsPanel(
                previewLanguage: $previewLanguage,
                russianPreviewText: russianPreviewText
            )
            .tabItem {
                Label(I18n.t("settings.caret"), systemImage: "cursorarrow.rays")
            }

            WindowSettingsPanel(previewLanguage: $previewLanguage)
                .tabItem {
                    Label(I18n.t("settings.window"), systemImage: "macwindow")
                }

            GeneralSettingsPanel()
                .tabItem {
                    Label(I18n.t("settings.general"), systemImage: "gearshape")
                }
        }
        .padding(16)
        .frame(
            minWidth: SettingsLayout.windowMinWidth,
            idealWidth: SettingsLayout.windowMinWidth,
            minHeight: SettingsLayout.windowMinHeight,
            idealHeight: SettingsLayout.windowMinHeight
        )
        .onAppear { syncPreviewLanguageWithCurrentInputSource() }
    }

    private func syncPreviewLanguageWithCurrentInputSource() {
        previewLanguage = PreviewLanguage.currentInputSource()
    }
}

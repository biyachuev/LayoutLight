import SwiftUI

struct LanguageColorsCard: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    @ObservedObject var languageIndicatorStore: LanguageIndicatorSettingsStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(I18n.t("languageColors.title"))
                .font(.system(size: 13, weight: .semibold))

            Text(I18n.t("languageColors.note"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                languageRow(
                    label: I18n.t("language.english"),
                    isEnabled: $languageIndicatorStore.settings.showForEN,
                    color: $languageIndicatorStore.settings.colorEN
                )
                languageRow(
                    label: I18n.t("language.russian"),
                    isEnabled: $languageIndicatorStore.settings.showForRU,
                    color: $languageIndicatorStore.settings.colorRU
                )
            }
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
    }

    @ViewBuilder
    private func languageRow(label: String, isEnabled: Binding<Bool>, color: Binding<ColorRGBA>) -> some View {
        HStack {
            Toggle(label, isOn: isEnabled)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            ColorPicker("", selection: Binding(
                get: { Color(color.wrappedValue) },
                set: { color.wrappedValue = ColorRGBA($0) }
            ))
            .labelsHidden()
            .disabled(!isEnabled.wrappedValue)
            Spacer()
        }
    }
}

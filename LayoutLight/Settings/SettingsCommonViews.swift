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

struct IndicatorStatusRow: View {
    let isEnabled: Bool

    var body: some View {
        HStack {
            Text(I18n.t("settings.status"))
                .font(.system(size: 13))
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            IndicatorStatusPill(isEnabled: isEnabled)
            Spacer()
        }
    }
}

private struct IndicatorStatusPill: View {
    let isEnabled: Bool

    var body: some View {
        Text(isEnabled ? I18n.t("common.enabled") : I18n.t("common.disabled"))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10))
            )
    }
}

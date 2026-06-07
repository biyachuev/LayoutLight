import SwiftUI

struct WindowSettingsPanel: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    @ObservedObject var windowFrameStore: WindowFrameIndicatorSettingsStore = .shared
    @ObservedObject var languageIndicatorStore: LanguageIndicatorSettingsStore = .shared
    @Binding var previewLanguage: PreviewLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(I18n.t("windowIndicator.title"))
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.2)

            VStack(alignment: .leading, spacing: 12) {
                windowPreviewCard
                LanguageColorsCard()
                windowFrameSettingsCard
            }

            Spacer()
        }
    }

    private var windowPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(I18n.t("indicator.preview"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("", selection: $previewLanguage) {
                    ForEach(PreviewLanguage.allCases) { language in
                        Text(language.rawValue).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 88)
                .controlSize(.small)
            }

            WindowIndicatorPreview(
                settings: windowFrameStore.settings,
                languageSettings: languageIndicatorStore.settings,
                language: previewLanguage
            )
            .frame(height: 112)
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
    }

    private var windowFrameSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            IndicatorStatusRow(isEnabled: windowFrameStore.settings.isEnabled)

            Text(I18n.t("windowIndicator.note"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(I18n.t("windowIndicator.mode"))
                    .font(.system(size: 13))
                    .frame(width: SettingsLayout.labelWidth, alignment: .leading)
                Picker("", selection: $windowFrameStore.settings.mode) {
                    ForEach(WindowFrameIndicatorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                Spacer()
            }

            if windowFrameStore.settings.mode == .edge {
                HStack {
                    Text(I18n.t("windowIndicator.edgeSide"))
                        .font(.system(size: 13))
                        .frame(width: SettingsLayout.labelWidth, alignment: .leading)
                    Picker("", selection: $windowFrameStore.settings.edge) {
                        ForEach(WindowFrameIndicatorEdge.allCases) { edge in
                            Text(edge.displayName).tag(edge)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 300)
                    Spacer()
                }
            }

            HStack {
                Text(I18n.t("windowIndicator.thickness"))
                    .font(.system(size: 13))
                    .frame(width: SettingsLayout.labelWidth, alignment: .leading)
                SettingsSlider(value: $windowFrameStore.settings.thickness, range: 1...12, step: 1)
                Text("\(Int(windowFrameStore.settings.thickness))")
                    .font(.system(size: 12))
                    .frame(width: SettingsLayout.valueWidth, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
    }
}

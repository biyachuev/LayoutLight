import SwiftUI

struct CaretSettingsPanel: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    @ObservedObject var store: CaretSettingsStore = .shared
    @ObservedObject var languageIndicatorStore: LanguageIndicatorSettingsStore = .shared
    @AppStorage(DefaultsKey.colorCaretByLanguage) private var isCaretIndicatorEnabled = false
    @Binding var previewLanguage: PreviewLanguage
    let russianPreviewText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(I18n.t("settings.caret"))
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.2)

                Spacer()

                Text(I18n.t("indicator.shape"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $store.settings.shape) {
                    ForEach(CaretShape.allCases) { shape in
                        Text(shape.displayName).tag(shape)
                    }
                }
                .id(languageStore.choice)
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)
            }

            previewCard

            Text(I18n.t("indicator.compatibility.note"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SettingsLayout.cardPadding)

            LanguageColorsCard()

            caretControlsCard

            Spacer(minLength: 0)

            HStack {
                Button(I18n.t("settings.resetToDefaults")) {
                    store.resetToDefaults()
                    languageIndicatorStore.resetToDefaults()
                }
                .controlSize(.small)
                Spacer()
            }
            .padding(.bottom, 10)
        }
    }

    private var caretControlsCard: some View {
        settingsCard {
            IndicatorStatusRow(isEnabled: isCaretIndicatorEnabled)

            Divider()
                .padding(.vertical, 2)

            typingControls

            Divider()
                .padding(.vertical, 2)

            shapeSection
        }
    }

    @ViewBuilder
    private var previewCard: some View {
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

            CaretPreview(
                settings: store.settings,
                languageSettings: languageIndicatorStore.settings,
                language: previewLanguage,
                russianText: russianPreviewText
            )
            .frame(height: 82)
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
    }

    @ViewBuilder
    private var typingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(I18n.t("indicator.hideWhileTyping"), isOn: $store.settings.hideWhileTyping)
                .toggleStyle(.checkbox)
            HStack {
                Text(I18n.t("indicator.showDelay"))
                    .font(.system(size: 13))
                    .frame(width: SettingsLayout.labelWidth, alignment: .leading)
                Slider(value: $store.settings.typingResumeDelay, in: 1...5)
                    .disabled(!store.settings.hideWhileTyping)
                Text(store.settings.typingResumeDelay, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 12))
                    .frame(width: SettingsLayout.valueWidth, alignment: .trailing)
                    .monospacedDigit()
            }
            .disabled(!store.settings.hideWhileTyping)
        }
    }

    @ViewBuilder
    private var shapeSection: some View {
        switch store.settings.shape {
        case .line:        controls(for: $store.settings.line, shape: .line)
        case .square:      controls(for: $store.settings.square, shape: .square)
        case .dot:         controls(for: $store.settings.dot, shape: .dot)
        case .underline:   controls(for: $store.settings.underline, shape: .underline)
        }
    }

    @ViewBuilder
    private func controls(for cfg: Binding<CaretShapeConfig>, shape: CaretShape) -> some View {
        let labels = sliderLabels(for: shape)
        let ranges = sliderRanges(for: shape)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 9) {
                sliderRow(label: labels.width, value: cfg.width, range: ranges.width)
                sliderRow(label: labels.height, value: cfg.height, range: ranges.height)
                sliderRow(label: labels.gap, value: cfg.gap, range: 0...15)
            }

            if shape == .square || shape == .dot {
                placementRow(placement: cfg.verticalPlacement)
                    .padding(.top, 4)
            }
        }
    }

    private func sliderRanges(for shape: CaretShape) -> (width: ClosedRange<Double>, height: ClosedRange<Double>) {
        switch shape {
        case .square, .dot:
            return (1...15, 1...15)
        case .line:
            return (1...15, 1...20)
        case .underline:
            return (1...20, 1...15)
        }
    }

    private func sliderLabels(for shape: CaretShape) -> (width: String, height: String, gap: String) {
        switch shape {
        case .line:
            return (
                I18n.t("indicator.thicknessPx"),
                I18n.t("indicator.lengthPx"),
                I18n.t("indicator.gapFromCaretPx")
            )
        case .square, .dot:
            return (
                I18n.t("indicator.widthPx"),
                I18n.t("indicator.heightPx"),
                I18n.t("indicator.gapFromCaretPx")
            )
        case .underline:
            return (
                I18n.t("indicator.lengthPx"),
                I18n.t("indicator.thicknessPx"),
                I18n.t("indicator.gapFromCaretPx")
            )
        }
    }

    @ViewBuilder
    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            Slider(value: value, in: range, step: 1)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 12))
                .frame(width: SettingsLayout.valueWidth, alignment: .trailing)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func placementRow(placement: Binding<CaretVerticalPlacement>) -> some View {
        HStack {
            Text(I18n.t("indicator.verticalPosition"))
                .font(.system(size: 13))
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            Picker("", selection: placement) {
                ForEach(CaretVerticalPlacement.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .id(languageStore.choice)
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            Spacer()
        }
    }
}

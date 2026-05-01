import SwiftUI

struct CaretPreview: View {
    let settings: CaretIndicatorSettings
    let languageSettings: LanguageIndicatorSettings
    let language: PreviewLanguage
    let russianText: String

    private var config: CaretShapeConfig { settings.active }
    private var color: Color {
        switch language {
        case .en: return Color(languageSettings.colorEN)
        case .ru: return Color(languageSettings.colorRU)
        }
    }

    private var isEnabled: Bool {
        switch language {
        case .en: return languageSettings.showForEN
        case .ru: return languageSettings.showForRU
        }
    }

    private var previewText: String {
        switch language {
        case .en: return "The quick brown fox"
        case .ru: return russianText
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.textBackgroundColor))

            HStack(spacing: 0) {
                Text(previewText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .padding(.leading, 14)
                indicator
                    .opacity(isEnabled ? 1 : 0.22)
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.55), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var indicator: some View {
        let width = max(1, CGFloat(config.width))
        let height = max(1, CGFloat(config.height))
        let gap = CGFloat(config.gap)

        switch settings.shape {
        case .line:
            previewShape(
                RoundedRectangle(cornerRadius: max(1, width * 0.2), style: .continuous),
                width: width,
                height: height
            )
                .padding(.leading, gap)
        case .square:
            previewShape(
                RoundedRectangle(cornerRadius: max(2, min(width, height) * 0.2), style: .continuous),
                width: width,
                height: height
            )
                .padding(.leading, gap)
                .offset(y: config.verticalPlacement == .aboveText ? -12 : 0)
        case .dot:
            previewShape(Circle(), width: width, height: height)
                .padding(.leading, gap)
                .offset(y: config.verticalPlacement == .aboveText ? -12 : 0)
        case .underline:
            previewShape(
                RoundedRectangle(cornerRadius: max(1, height * 0.2), style: .continuous),
                width: width,
                height: height
            )
                .padding(.leading, gap)
                .offset(y: 12)
        }
    }

    private func previewShape<S: InsettableShape>(_ shape: S, width: CGFloat, height: CGFloat) -> some View {
        let drawsOutline = min(width, height) >= 3
        return shape
            .inset(by: drawsOutline ? 0.5 : 0)
            .fill(color)
            .overlay {
                if drawsOutline {
                    shape
                        .inset(by: 0.5)
                        .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                }
            }
            .frame(width: width, height: height)
    }
}

struct WindowIndicatorPreview: View {
    let settings: WindowFrameIndicatorSettings
    let languageSettings: LanguageIndicatorSettings
    let language: PreviewLanguage

    private var color: Color {
        switch language {
        case .en: return Color(languageSettings.colorEN)
        case .ru: return Color(languageSettings.colorRU)
        }
    }

    private var isLanguageEnabled: Bool {
        switch language {
        case .en: return languageSettings.showForEN
        case .ru: return languageSettings.showForRU
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.textBackgroundColor))

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.75))
                .frame(width: 330, height: 78)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.red.opacity(0.75)).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow.opacity(0.75)).frame(width: 8, height: 8)
                        Circle().fill(Color.gray.opacity(0.55)).frame(width: 8, height: 8)
                    }
                    .padding(9)
                }
                .overlay {
                    indicator
                        .opacity(settings.isEnabled && isLanguageEnabled ? 1 : 0.22)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.65), lineWidth: 1)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.55), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var indicator: some View {
        let thickness = max(1, CGFloat(settings.thickness))

        switch settings.mode {
        case .frame:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(color, lineWidth: thickness)
                .frame(width: 330, height: 78)
        case .edge:
            edge(thickness: thickness)
                .frame(width: 330, height: 78)
        }
    }

    @ViewBuilder
    private func edge(thickness: CGFloat) -> some View {
        ZStack {
            switch settings.edge {
            case .top:
                VStack { color.frame(height: thickness); Spacer(minLength: 0) }
            case .bottom:
                VStack { Spacer(minLength: 0); color.frame(height: thickness) }
            case .left:
                HStack { color.frame(width: thickness); Spacer(minLength: 0) }
            case .right:
                HStack { Spacer(minLength: 0); color.frame(width: thickness) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

import SwiftUI

enum SettingsLayout {
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let windowMinWidth: CGFloat = 680
    static let windowMinHeight: CGFloat = 680
    static let labelWidth: CGFloat = 210
    static let valueWidth: CGFloat = 42
}

extension View {
    func settingsCardStyle(
        stroke: Color = Color(NSColor.separatorColor).opacity(0.7),
        lineWidth: CGFloat = 1
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: SettingsLayout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsLayout.cardRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            )
    }
}

func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
}

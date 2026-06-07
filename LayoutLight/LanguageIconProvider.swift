import Foundation

enum LanguageIconProvider {
    static func icon(isRussian: Bool, settings: LanguageIndicatorSettings = LanguageIndicatorSettingsStore.shared.settings) -> String {
        isRussian ? "🇷🇺" : settings.englishIcon.symbol
    }
}

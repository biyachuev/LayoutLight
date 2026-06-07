import Foundation

enum EnglishLanguageIcon: String, CaseIterable, Codable, Identifiable {
    case globe1
    case globe
    case usFlag

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .globe1:
            return "🌍"
        case .globe:
            return "🌐"
        case .usFlag:
            return "🇺🇸"
        }
    }

    var displayName: String {
        switch self {
        case .globe1:
            return I18n.t("englishIcon.globe1")
        case .globe:
            return I18n.t("englishIcon.globe2")
        case .usFlag:
            return I18n.t("englishIcon.usFlag")
        }
    }
}

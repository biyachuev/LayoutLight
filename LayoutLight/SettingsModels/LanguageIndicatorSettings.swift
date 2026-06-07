import Foundation

struct LanguageIndicatorSettings: Codable, Equatable {
    var showForEN: Bool
    var showForRU: Bool
    var colorEN: ColorRGBA
    var colorRU: ColorRGBA
    var englishIcon: EnglishLanguageIcon

    static let defaults = LanguageIndicatorSettings(
        showForEN: true,
        showForRU: true,
        colorEN: .systemBlue,
        colorRU: .systemGreen,
        englishIcon: .globe1
    )

    init(showForEN: Bool,
         showForRU: Bool,
         colorEN: ColorRGBA,
         colorRU: ColorRGBA,
         englishIcon: EnglishLanguageIcon = .globe1) {
        self.showForEN = showForEN
        self.showForRU = showForRU
        self.colorEN = colorEN
        self.colorRU = colorRU
        self.englishIcon = englishIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showForEN = try container.decode(Bool.self, forKey: .showForEN)
        showForRU = try container.decode(Bool.self, forKey: .showForRU)
        colorEN = try container.decode(ColorRGBA.self, forKey: .colorEN)
        colorRU = try container.decode(ColorRGBA.self, forKey: .colorRU)
        englishIcon = try container.decodeIfPresent(EnglishLanguageIcon.self, forKey: .englishIcon) ?? .globe1
    }
}

import Foundation

struct LanguageIndicatorSettings: Codable, Equatable {
    var showForEN: Bool
    var showForRU: Bool
    var colorEN: ColorRGBA
    var colorRU: ColorRGBA

    static let defaults = LanguageIndicatorSettings(
        showForEN: true,
        showForRU: true,
        colorEN: .systemBlue,
        colorRU: .systemGreen
    )
}

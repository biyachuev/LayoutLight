import Foundation

final class LanguageIndicatorSettingsStore: ObservableObject {
    static let shared = LanguageIndicatorSettingsStore()

    @Published var settings: LanguageIndicatorSettings {
        didSet { save() }
    }

    private static let storageKey = "languageIndicatorSettings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(LanguageIndicatorSettings.self, from: data) {
            settings = decoded
        } else {
            let activeCaretConfig = CaretSettingsStore.shared.settings.active
            settings = LanguageIndicatorSettings(
                showForEN: activeCaretConfig.showForEN,
                showForRU: activeCaretConfig.showForRU,
                colorEN: activeCaretConfig.colorEN,
                colorRU: activeCaretConfig.colorRU
            )
            save(notify: false)
        }
    }

    func resetToDefaults() {
        settings = .defaults
    }

    private func save(notify: Bool = true) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        if notify {
            NotificationCenter.default.post(name: .languageIndicatorSettingsChanged, object: nil)
        }
    }
}

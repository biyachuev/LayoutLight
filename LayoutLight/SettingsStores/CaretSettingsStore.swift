import Foundation

final class CaretSettingsStore: ObservableObject {
    static let shared = CaretSettingsStore()

    @Published var settings: CaretIndicatorSettings {
        didSet {
            let normalized = settings.normalized
            if normalized != settings {
                settings = normalized
                return
            }
            save()
        }
    }

    private static let storageKey = "caretIndicatorSettings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(CaretIndicatorSettings.self, from: data) {
            settings = decoded.normalized
        } else {
            settings = .defaults
        }
    }

    func resetToDefaults() {
        settings = .defaults
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        NotificationCenter.default.post(name: .caretSettingsChanged, object: nil)
    }
}

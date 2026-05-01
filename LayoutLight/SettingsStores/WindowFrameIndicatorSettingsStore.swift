import Foundation

final class WindowFrameIndicatorSettingsStore: ObservableObject {
    static let shared = WindowFrameIndicatorSettingsStore()

    @Published var settings: WindowFrameIndicatorSettings {
        didSet {
            let normalized = settings.normalized
            if normalized != settings {
                settings = normalized
                return
            }
            save()
        }
    }

    private static let storageKey = "windowFrameIndicatorSettings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(WindowFrameIndicatorSettings.self, from: data) {
            settings = decoded.normalized
        } else {
            settings = .defaults
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        NotificationCenter.default.post(name: .windowFrameIndicatorSettingsChanged, object: nil)
    }
}

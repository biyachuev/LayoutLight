import Foundation

enum AppLanguage: String {
    case en
    case ru
}

enum InterfaceLanguageChoice: String, CaseIterable, Identifiable {
    case ru
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ru:
            return "Русский"
        case .en:
            return "English"
        }
    }

    var resolvedLanguage: AppLanguage {
        switch self {
        case .ru:
            return .ru
        case .en:
            return .en
        }
    }

    static func systemDefault() -> InterfaceLanguageChoice {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("ru") ? .ru : .en
    }
}

extension Notification.Name {
    static let interfaceLanguageChanged = Notification.Name("LayoutLight.interfaceLanguageChanged")
}

final class InterfaceLanguageStore: ObservableObject {
    static let shared = InterfaceLanguageStore()

    @Published var choice: InterfaceLanguageChoice {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: Self.storageKey)
            NotificationCenter.default.post(name: .interfaceLanguageChanged, object: nil)
        }
    }

    var language: AppLanguage {
        choice.resolvedLanguage
    }

    private static let storageKey = "interfaceLanguageChoice.v1"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = InterfaceLanguageChoice(rawValue: raw) {
            choice = saved
        } else {
            choice = InterfaceLanguageChoice.systemDefault()
        }
    }
}

enum I18n {
    static var language: AppLanguage {
        InterfaceLanguageStore.shared.language
    }

    static func t(_ key: String) -> String {
        let bundle: Bundle
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            bundle = localizedBundle
        } else {
            bundle = .main
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

}

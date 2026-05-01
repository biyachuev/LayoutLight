import Carbon
import SwiftUI

struct KeyboardShortcutConfig: Codable, Equatable {
    var keyCode: UInt32?
    var modifiers: UInt32

    var displayName: String {
        guard let keyCode else { return I18n.t("shortcut.none") }
        let modifierText = Self.displayName(forModifiers: modifiers)
        let keyText = Self.displayName(forKeyCode: keyCode) ?? "#\(keyCode)"
        if modifierText.isEmpty { return keyText }
        return "\(modifierText) \(keyText)"
    }

    var isValid: Bool {
        guard let keyCode else { return false }
        guard Self.displayName(forKeyCode: keyCode) != nil else { return false }
        return modifiers != 0 || Self.allowsWithoutModifiers(keyCode)
    }

    static let none = KeyboardShortcutConfig(keyCode: nil, modifiers: 0)

    static func displayName(forModifiers modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined(separator: " ")
    }

    static func displayName(forKeyCode keyCode: UInt32) -> String? {
        if keyCode == UInt32(kVK_Space) {
            return I18n.t("shortcut.space")
        }
        return keyNames[keyCode]
    }

    static func allowsWithoutModifiers(_ keyCode: UInt32) -> Bool {
        keyCode == UInt32(kVK_Escape) || functionKeyCodes.contains(keyCode)
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Return): "Enter",
        UInt32(kVK_Escape): "Esc", UInt32(kVK_Tab): "Tab",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
    ]

    private static let functionKeyCodes: Set<UInt32> = [
        UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
        UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
        UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12)
    ]
}

struct HotKeySettings: Codable, Equatable {
    var switchToRU: KeyboardShortcutConfig
    var switchToEN: KeyboardShortcutConfig
    var showFlag: KeyboardShortcutConfig

    static let defaults = HotKeySettings(
        switchToRU: KeyboardShortcutConfig(
            keyCode: UInt32(kVK_ANSI_1),
            modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey)
        ),
        switchToEN: KeyboardShortcutConfig(
            keyCode: UInt32(kVK_ANSI_2),
            modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey)
        ),
        showFlag: KeyboardShortcutConfig(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(controlKey | shiftKey)
        )
    )
}

extension Notification.Name {
    static let hotKeySettingsChanged = Notification.Name("LayoutLight.hotKeySettingsChanged")
    static let hotKeyRegistrationFailed = Notification.Name("LayoutLight.hotKeyRegistrationFailed")
    static let shortcutRecordingChanged = Notification.Name("LayoutLight.shortcutRecordingChanged")
}

final class HotKeySettingsStore: ObservableObject {
    static let shared = HotKeySettingsStore()

    @Published var settings: HotKeySettings {
        didSet { save() }
    }

    private static let storageKey = "hotKeySettings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(HotKeySettings.self, from: data) {
            settings = decoded
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
        NotificationCenter.default.post(name: .hotKeySettingsChanged, object: nil)
    }
}

import Foundation

final class MenuBarState: ObservableObject {
    static let shared = MenuBarState()

    @Published var currentFlag: String = ""
    @Published var showOverlayOnSwitch: Bool = false
    @Published var colorCaretByLanguage: Bool = false
    @Published var caretWaitingForAccessibility: Bool = false
    @Published var caretHasAccessibility: Bool = true
    @Published var languageRevision: Int = 0

    var onToggleOverlay: () -> Void = {}
    var onToggleCaret: () -> Void = {}
    var onToggleWindowIndicator: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onOpenAbout: () -> Void = {}
    var onSelectInterfaceLanguage: (InterfaceLanguageChoice) -> Void = { _ in }

    private init() {}

    var caretToggleTitle: String {
        if caretWaitingForAccessibility {
            return I18n.t("menu.colorCaretWaiting")
        } else if !caretHasAccessibility {
            return I18n.t("menu.colorCaretNeedsAccessibility")
        } else {
            return I18n.t("menu.colorCaret")
        }
    }
}

import Carbon

enum PreviewLanguage: String, CaseIterable, Identifiable {
    case en = "EN"
    case ru = "RU"

    var id: String { rawValue }

    static func currentInputSource() -> PreviewLanguage {
        InputSourceLanguage.isRussianActive() ? .ru : .en
    }
}

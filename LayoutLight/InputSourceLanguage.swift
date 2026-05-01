import Carbon

enum InputSourceLanguage {
    private static let russianInputSourceIDs: Set<String> = [
        "com.apple.keylayout.Russian",
        "com.apple.keylayout.RussianWin"
    ]

    static func isRussianSourceID(_ id: String) -> Bool {
        russianInputSourceIDs.contains(id)
    }

    static func currentInputSourceID() -> String? {
        guard let source = currentInputSource() else { return nil }
        return stringProperty(kTISPropertyInputSourceID, of: source)
    }

    static func isRussianActive() -> Bool {
        guard let source = currentInputSource() else { return false }
        if let id = stringProperty(kTISPropertyInputSourceID, of: source),
           isRussianSourceID(id) {
            return true
        }
        return stringArrayProperty(kTISPropertyInputSourceLanguages, of: source)
            .contains { $0.lowercased().hasPrefix("ru") }
    }

    private static func currentInputSource() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    private static func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func stringArrayProperty(_ key: CFString, of source: TISInputSource) -> [String] {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return [] }
        let values = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as [AnyObject]
        return values.compactMap { $0 as? String }
    }
}

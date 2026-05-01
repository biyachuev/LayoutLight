import Cocoa
import Carbon
import OSLog

private let hotKeyLogger = Logger(subsystem: "com.biyachuev.LayoutLight", category: "HotKeyManager")

final class HotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var enHotKeyRef: EventHotKeyRef?
    private var ruHotKeyRef: EventHotKeyRef?
    private var showFlagHotKeyRef: EventHotKeyRef?

    /// Called when the current language should be shown as an overlay
    var onShowFlag: (() -> Void)?

    private let enInputSourceIDs = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
    private let ruInputSourceIDs = ["com.apple.keylayout.Russian", "com.apple.keylayout.RussianWin"]

    func start() {
        stop()

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)

            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            switch id.id {
            case 1: manager.selectInputSource(withIDs: manager.ruInputSourceIDs) // ⌃⌥⇧⌘1 → RU
            case 2: manager.selectInputSource(withIDs: manager.enInputSourceIDs) // ⌃⌥⇧⌘2 → EN
            case 3: manager.onShowFlag?()                                        // ⌃⇧L   → show flag
            default: break
            }
            return noErr
        }, 1, &spec, callbackUserData(), &eventHandler)

        let sig = OSType(0x4C53574B) // "LSWK"
        let settings = HotKeySettingsStore.shared.settings

        register(settings.switchToRU, id: 1, sig: sig, ref: &ruHotKeyRef, label: "RU")
        register(settings.switchToEN, id: 2, sig: sig, ref: &enHotKeyRef, label: "EN")
        register(settings.showFlag, id: 3, sig: sig, ref: &showFlagHotKeyRef, label: "show flag")
    }

    private func register(_ shortcut: KeyboardShortcutConfig, id: UInt32, sig: OSType,
                          ref: UnsafeMutablePointer<EventHotKeyRef?>, label: String) {
        guard shortcut.isValid else {
            hotKeyLogger.debug("Hotkey skipped: \(label, privacy: .public), invalid shortcut")
            return
        }
        guard let keyCode = shortcut.keyCode else { return }
        register(keyCode: keyCode, mods: shortcut.modifiers, id: id, sig: sig,
                 ref: ref, label: "\(shortcut.displayName) (\(label))")
    }

    private func register(keyCode: UInt32, mods: UInt32, id: UInt32, sig: OSType,
                          ref: UnsafeMutablePointer<EventHotKeyRef?>, label: String) {
        let status = RegisterEventHotKey(keyCode, mods,
                                         EventHotKeyID(signature: sig, id: id),
                                         GetApplicationEventTarget(), 0, ref)
        if status == noErr {
            hotKeyLogger.debug("Hotkey registered: \(label, privacy: .private)")
        } else {
            let hint: String
            switch status {
            case -9878: hint = " — already taken by another app (eventHotKeyExistsErr)"
            case -9868: hint = " — invalid hotkey (eventHotKeyInvalidErr)"
            default:    hint = ""
            }
            hotKeyLogger.error("Hotkey registration failed: \(label, privacy: .private), status=\(status, privacy: .public)\(hint, privacy: .public)")
            NotificationCenter.default.post(
                name: .hotKeyRegistrationFailed,
                object: nil,
                userInfo: ["label": label, "status": status]
            )
        }
    }

    func stop() {
        if let enHotKeyRef { UnregisterEventHotKey(enHotKeyRef) }
        if let ruHotKeyRef { UnregisterEventHotKey(ruHotKeyRef) }
        if let showFlagHotKeyRef { UnregisterEventHotKey(showFlagHotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        enHotKeyRef = nil
        ruHotKeyRef = nil
        showFlagHotKeyRef = nil
        eventHandler = nil
    }

    private func callbackUserData() -> UnsafeMutableRawPointer {
        // The app delegate owns HotKeyManager for the whole app lifetime; stop()
        // removes the Carbon handler before teardown, so this unretained ref is valid.
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    private func selectInputSource(withIDs targetIDs: [String]) {
        let props: [CFString: Any] = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any]
        guard let list = TISCreateInputSourceList(props as CFDictionary, false)?
                .takeRetainedValue() as? [TISInputSource] else { return }

        for src in list {
            if let sourceID = stringProperty(kTISPropertyInputSourceID, of: src),
               targetIDs.contains(sourceID) {
                TISSelectInputSource(src)
                break
            }
        }
    }

    private func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}

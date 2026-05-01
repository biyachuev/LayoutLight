import SwiftUI

struct GeneralSettingsPanel: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    @ObservedObject var hotKeyStore: HotKeySettingsStore = .shared
    @ObservedObject var launchAtLoginStore: LaunchAtLoginStore = .shared
    @State private var recordingShortcut: ShortcutAction?
    @State private var shortcutConflict: ShortcutAction?
    @State private var shortcutWarning: ShortcutWarning?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(I18n.t("settings.general"))
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.2)

            VStack(alignment: .leading, spacing: 12) {
                launchAtLoginCard
                shortcutSettingsCard
            }

            Spacer()
        }
        .onDisappear {
            if recordingShortcut != nil {
                recordingShortcut = nil
                setShortcutRecording(false)
            }
        }
    }

    private var launchAtLoginCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                I18n.t("advanced.launchAtLogin"),
                isOn: Binding(
                    get: { launchAtLoginStore.isEnabled },
                    set: { launchAtLoginStore.setEnabled($0) }
                )
            )
            .toggleStyle(.checkbox)
            .font(.system(size: 13, weight: .medium))

            Text(launchAtLoginStore.statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
        .onAppear { launchAtLoginStore.refresh() }
    }

    private var shortcutSettingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(I18n.t("shortcuts.title"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(I18n.t("shortcuts.resetAll")) {
                    recordingShortcut = nil
                    shortcutConflict = nil
                    shortcutWarning = nil
                    hotKeyStore.resetToDefaults()
                }
                .controlSize(.small)
            }

            Text(I18n.t("shortcuts.instructions"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            if let shortcutWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(shortcutWarning.message)
                        .font(.system(size: 12, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.red)
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
            }

            shortcutRow(
                label: I18n.t("shortcuts.switchToRussian"),
                action: .switchToRU,
                shortcut: Binding(
                    get: { hotKeyStore.settings.switchToRU },
                    set: { hotKeyStore.settings.switchToRU = $0 }
                )
            )
            Divider()
            shortcutRow(
                label: I18n.t("shortcuts.switchToEnglish"),
                action: .switchToEN,
                shortcut: Binding(
                    get: { hotKeyStore.settings.switchToEN },
                    set: { hotKeyStore.settings.switchToEN = $0 }
                )
            )
            Divider()
            shortcutRow(
                label: I18n.t("shortcuts.showCurrentLanguage"),
                action: .showFlag,
                shortcut: Binding(
                    get: { hotKeyStore.settings.showFlag },
                    set: { hotKeyStore.settings.showFlag = $0 }
                )
            )
        }
        .padding(SettingsLayout.cardPadding)
        .settingsCardStyle()
        .animation(.default, value: shortcutWarning)
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyRegistrationFailed)) { notification in
            let label = notification.userInfo?["label"] as? String ?? I18n.t("shortcuts.title")
            showShortcutWarning("\(label): \(I18n.t("shortcuts.registrationFailed"))", conflict: nil)
        }
        .alert(item: $shortcutWarning) { warning in
            Alert(
                title: Text(I18n.t("shortcuts.warningTitle")),
                message: Text(warning.message),
                dismissButton: .default(Text(I18n.t("common.ok")))
            )
        }
    }

    @ViewBuilder
    private func shortcutRow(label: String,
                             action: ShortcutAction,
                             shortcut: Binding<KeyboardShortcutConfig>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .frame(width: 220, alignment: .leading)
                ShortcutRecorderButton(
                    shortcut: shortcut.wrappedValue,
                    isRecording: recordingShortcut == action,
                    hasError: shortcutConflict == action,
                    onBeginRecording: {
                        shortcutConflict = nil
                        shortcutWarning = nil
                        recordingShortcut = action
                        setShortcutRecording(true)
                    },
                    onCapture: {
                        guard !hasConflict($0, excluding: action) else {
                            recordingShortcut = nil
                            showShortcutWarning(conflictMessage(for: action), conflict: action)
                            setShortcutRecording(false)
                            NSSound.beep()
                            return
                        }
                        shortcutConflict = nil
                        shortcutWarning = nil
                        shortcut.wrappedValue = $0
                        recordingShortcut = nil
                        setShortcutRecording(false)
                    },
                    onCancel: {
                        recordingShortcut = nil
                        if shortcutConflict == action { shortcutConflict = nil }
                        setShortcutRecording(false)
                    }
                )
                .frame(width: 270)
                Button(I18n.t("shortcuts.clear")) {
                    if recordingShortcut == action { recordingShortcut = nil }
                    if shortcutConflict == action { shortcutConflict = nil }
                    setShortcutRecording(false)
                    shortcutWarning = nil
                    shortcut.wrappedValue = .none
                }
                .controlSize(.small)
                .disabled(shortcut.wrappedValue.keyCode == nil)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(recordingShortcut == action ? Color.accentColor.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(recordingShortcut == action ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
        )
    }

    private func conflictMessage(for action: ShortcutAction) -> String {
        "\(label(for: action)): \(I18n.t("shortcuts.duplicate"))"
    }

    private func showShortcutWarning(_ message: String, conflict: ShortcutAction?) {
        shortcutConflict = conflict
        shortcutWarning = ShortcutWarning(message: message)
    }

    private func setShortcutRecording(_ isRecording: Bool) {
        NotificationCenter.default.post(
            name: .shortcutRecordingChanged,
            object: nil,
            userInfo: ["isRecording": isRecording]
        )
    }

    private func label(for action: ShortcutAction) -> String {
        switch action {
        case .switchToRU:
            return I18n.t("shortcuts.switchToRussian")
        case .switchToEN:
            return I18n.t("shortcuts.switchToEnglish")
        case .showFlag:
            return I18n.t("shortcuts.showCurrentLanguage")
        }
    }

    private func hasConflict(_ shortcut: KeyboardShortcutConfig, excluding action: ShortcutAction) -> Bool {
        guard shortcut.isValid else { return false }
        return ShortcutAction.allCases.contains { other in
            other != action && shortcutForAction(other) == shortcut
        }
    }

    private func shortcutForAction(_ action: ShortcutAction) -> KeyboardShortcutConfig {
        switch action {
        case .switchToRU:
            return hotKeyStore.settings.switchToRU
        case .switchToEN:
            return hotKeyStore.settings.switchToEN
        case .showFlag:
            return hotKeyStore.settings.showFlag
        }
    }
}

private enum ShortcutAction: CaseIterable, Hashable {
    case switchToRU
    case switchToEN
    case showFlag
}

private struct ShortcutWarning: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

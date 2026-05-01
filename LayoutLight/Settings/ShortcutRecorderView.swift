import Carbon
import SwiftUI

struct ShortcutRecorderButton: View {
    @ObservedObject var languageStore: InterfaceLanguageStore = .shared
    let shortcut: KeyboardShortcutConfig
    let isRecording: Bool
    let hasError: Bool
    let onBeginRecording: () -> Void
    let onCapture: (KeyboardShortcutConfig) -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? I18n.t("shortcuts.recordingPrompt") : shortcut.displayName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button(isRecording ? I18n.t("shortcuts.cancel") : I18n.t("shortcuts.record")) {
                if isRecording {
                    onCancel()
                } else {
                    onBeginRecording()
                }
            }
            .controlSize(.small)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 30)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .background(
            ShortcutCaptureView(
                isRecording: isRecording,
                onCapture: onCapture,
                onCancel: onCancel
            )
        )
    }

    private var borderColor: Color {
        if hasError { return .red }
        if isRecording { return .accentColor }
        return Color(NSColor.separatorColor).opacity(0.8)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (KeyboardShortcutConfig) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isRecording = isRecording
    }
}

private final class ShortcutCaptureNSView: NSView {
    var onCapture: ((KeyboardShortcutConfig) -> Void)?
    var onCancel: (() -> Void)?
    var isRecording = false {
        didSet {
            guard isRecording, window?.firstResponder !== self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording else { return }
                self.window?.makeFirstResponder(self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let config = KeyboardShortcutConfig(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard config.isValid else {
            NSSound.beep()
            return
        }

        onCapture?(config)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}

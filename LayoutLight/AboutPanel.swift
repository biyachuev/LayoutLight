import AppKit
import SwiftUI

enum AppInfo {
    static let fallbackName = "LayoutLight"
    static let fallbackVersion = "1.0"

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fallbackName
    }

    static var summary: String {
        I18n.t("about.summary")
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? fallbackVersion
    }

    static var build: String? {
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !build.isEmpty,
              build != version
        else { return nil }
        return build
    }

    static var displayVersion: String {
        if let build {
            return "\(version) (\(build))"
        }
        return version
    }
}

@MainActor
enum AboutPanel {
    private static var controller: AboutWindowController?

    static func show() {
        let controller = controller ?? AboutWindowController()
        self.controller = controller
        controller.show()
    }

    static func close() {
        controller?.close()
        controller = nil
    }

    fileprivate static func windowDidClose() {
        controller = nil
    }
}

@MainActor
private final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let size = NSSize(width: 480, height: 600)
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero
        let frame = NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(format: I18n.t("about.windowTitle"), AppInfo.name)
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces]
        window.delegate = self
        window.contentView = NSHostingView(rootView: AboutView(onClose: { AboutPanel.close() }))

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        let window = window
        self.window = nil
        window?.delegate = nil
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AboutPanel.windowDidClose()
    }
}

private struct AboutView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(spacing: 10) {
                ContactRow(icon: "c.circle", title: "© 2026 Timur Biyachuev", detail: "MIT License")
                LinkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub",
                    detail: "github.com/biyachuev/LayoutLight",
                    url: "https://github.com/biyachuev/LayoutLight"
                )
                LinkRow(icon: "paperplane", title: "Telegram", detail: "t.me/tbiyachuev", url: "https://t.me/tbiyachuev")
                LinkRow(icon: "globe", title: "Website", detail: "biyachuev.com", url: "https://biyachuev.com")
            }

            InfoPanel(
                icon: "sparkles",
                title: I18n.t("about.ai.title"),
                text: I18n.t("about.ai.text")
            )

            InfoPanel(
                icon: "lock",
                title: I18n.t("about.privacy.title"),
                text: I18n.t("about.privacy.text")
            )

            HStack {
                Spacer()
                Button(I18n.t("about.close"), action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.top, 22)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(width: 480, height: 600)
        .background(Theme.bgSurface)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0,
                style: .continuous
            )
                .strokeBorder(Theme.borderDefault, lineWidth: 1)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .layeredShadow(.floating)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(AppInfo.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.fgStrong)

                Text(AppInfo.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.fgMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: I18n.t("about.version"), AppInfo.displayVersion))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.fgMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Theme.borderSubtle, lineWidth: 1)
                    )
                    .padding(.top, 1)
            }
        }
    }
}

private struct ContactRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            RowIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.fgStrong)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.fgMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 38)
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let detail: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 10) {
                RowIcon(systemName: icon)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.fgStrong)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.fgMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.fgMuted)
            }
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Theme.accentLight)
            .frame(width: 28, height: 28)
            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
            )
    }
}

private struct InfoPanel: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accentLight)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.fgStrong)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.fgMuted)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.borderSubtle, lineWidth: 1)
        )
    }
}

enum Theme {
    static let bgSurface = Color(.sRGB, red: 0.085, green: 0.085, blue: 0.105, opacity: 1)
    static let bgElevated = Color(.sRGB, red: 0.115, green: 0.115, blue: 0.135, opacity: 1)

    static let borderSubtle = Color.white.opacity(0.06)
    static let borderDefault = Color.white.opacity(0.09)

    static let fgMuted = Color(.sRGB, red: 0.58, green: 0.58, blue: 0.62, opacity: 1)
    static let fgStrong = Color(.sRGB, red: 0.96, green: 0.96, blue: 0.97, opacity: 1)

    static let accent = Color(.sRGB, red: 0.42, green: 0.58, blue: 0.96, opacity: 1)
    static let accentLight = Color(.sRGB, red: 0.55, green: 0.70, blue: 1.00, opacity: 1)
}

struct LayeredShadow: ViewModifier {
    enum Elevation {
        case floating
    }

    let elevation: Elevation

    func body(content: Content) -> some View {
        switch elevation {
        case .floating:
            content
                .shadow(color: .black.opacity(0.50), radius: 4, x: 0, y: 4)
                .shadow(color: .black.opacity(0.40), radius: 32, x: 0, y: 16)
        }
    }
}

extension View {
    func layeredShadow(_ elevation: LayeredShadow.Elevation) -> some View {
        modifier(LayeredShadow(elevation: elevation))
    }
}

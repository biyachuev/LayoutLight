import Foundation
import ServiceManagement

final class LaunchAtLoginStore: ObservableObject {
    static let shared = LaunchAtLoginStore()

    @Published private(set) var isEnabled = false
    @Published private(set) var statusText = ""

    private init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            statusText = I18n.t("advanced.launchAtLogin.enabled")
        case .requiresApproval:
            isEnabled = true
            statusText = I18n.t("advanced.launchAtLogin.requiresApproval")
        case .notRegistered:
            isEnabled = false
            statusText = I18n.t("advanced.launchAtLogin.disabled")
        case .notFound:
            isEnabled = false
            statusText = I18n.t("advanced.launchAtLogin.notFound")
        @unknown default:
            isEnabled = false
            statusText = I18n.t("advanced.launchAtLogin.unknown")
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }
            }
            refresh()
        } catch {
            refresh()
            statusText = String(format: I18n.t("advanced.launchAtLogin.error"), error.localizedDescription)
        }
    }
}

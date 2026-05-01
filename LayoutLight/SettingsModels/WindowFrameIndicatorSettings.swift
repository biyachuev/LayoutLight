import Foundation

enum WindowFrameIndicatorMode: String, Codable, CaseIterable, Identifiable {
    case frame
    case edge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frame: return I18n.t("windowFrame.mode.frame")
        case .edge: return I18n.t("windowFrame.mode.edge")
        }
    }
}

enum WindowFrameIndicatorEdge: String, Codable, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return I18n.t("windowFrame.edge.top")
        case .bottom: return I18n.t("windowFrame.edge.bottom")
        case .left: return I18n.t("windowFrame.edge.left")
        case .right: return I18n.t("windowFrame.edge.right")
        }
    }
}

struct WindowFrameIndicatorSettings: Codable, Equatable {
    var isEnabled: Bool
    var mode: WindowFrameIndicatorMode
    var edge: WindowFrameIndicatorEdge
    var thickness: Double

    var normalized: WindowFrameIndicatorSettings {
        var copy = self
        copy.thickness = min(max(copy.thickness, 1), 12)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, mode, edge, thickness
    }

    init(isEnabled: Bool,
         mode: WindowFrameIndicatorMode,
         edge: WindowFrameIndicatorEdge,
         thickness: Double) {
        self.isEnabled = isEnabled
        self.mode = mode
        self.edge = edge
        self.thickness = thickness
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        mode = try c.decodeIfPresent(WindowFrameIndicatorMode.self, forKey: .mode) ?? .frame
        edge = try c.decodeIfPresent(WindowFrameIndicatorEdge.self, forKey: .edge) ?? .top
        thickness = try c.decode(Double.self, forKey: .thickness)
        self = normalized
    }

    static let defaults = WindowFrameIndicatorSettings(isEnabled: false, mode: .frame, edge: .top, thickness: 4)
}

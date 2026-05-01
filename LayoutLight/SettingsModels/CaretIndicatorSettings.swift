import Foundation

enum CaretShape: String, Codable, CaseIterable, Identifiable {
    case line
    case square
    case dot
    case underline

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .line: return I18n.t("shape.line")
        case .square: return I18n.t("shape.square")
        case .dot: return I18n.t("shape.dot")
        case .underline: return I18n.t("shape.underline")
        }
    }
}

enum CaretVerticalPlacement: String, Codable, CaseIterable, Identifiable {
    case center
    case aboveText

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .center: return I18n.t("placement.center")
        case .aboveText: return I18n.t("placement.aboveText")
        }
    }
}

struct CaretShapeConfig: Codable, Equatable {
    var width: Double
    var height: Double
    var gap: Double
    /// Manual vertical offset in screen pixels. Positive = shift indicator
    /// DOWN on screen; negative = shift UP. Used to fine-tune position because
    /// AX line rects include different amounts of leading per app (e.g. Word
    /// reports a tight rect, TextEdit reports a taller one).
    var verticalOffset: Double
    var verticalPlacement: CaretVerticalPlacement
    var showForEN: Bool
    var showForRU: Bool
    var colorEN: ColorRGBA
    var colorRU: ColorRGBA

    init(width: Double, height: Double, gap: Double, verticalOffset: Double = 0,
         verticalPlacement: CaretVerticalPlacement = .center,
         showForEN: Bool = true, showForRU: Bool = true,
         colorEN: ColorRGBA, colorRU: ColorRGBA) {
        self.width = width
        self.height = height
        self.gap = gap
        self.verticalOffset = verticalOffset
        self.verticalPlacement = verticalPlacement
        self.showForEN = showForEN
        self.showForRU = showForRU
        self.colorEN = colorEN
        self.colorRU = colorRU
    }

    private enum CodingKeys: String, CodingKey {
        case width, height, gap, verticalOffset, verticalPlacement, showForEN, showForRU, colorEN, colorRU
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        gap = try c.decode(Double.self, forKey: .gap)
        // Backwards-compat: settings saved before verticalOffset existed.
        verticalOffset = try c.decodeIfPresent(Double.self, forKey: .verticalOffset) ?? 0
        verticalPlacement = try c.decodeIfPresent(CaretVerticalPlacement.self, forKey: .verticalPlacement) ?? .center
        showForEN = try c.decodeIfPresent(Bool.self, forKey: .showForEN) ?? true
        showForRU = try c.decodeIfPresent(Bool.self, forKey: .showForRU) ?? true
        colorEN = try c.decode(ColorRGBA.self, forKey: .colorEN)
        colorRU = try c.decode(ColorRGBA.self, forKey: .colorRU)
    }

    func clamped(width maxWidth: Double, height maxHeight: Double, gap maxGap: Double) -> CaretShapeConfig {
        var copy = self
        copy.width = min(max(copy.width, 1), maxWidth)
        copy.height = min(max(copy.height, 1), maxHeight)
        copy.gap = min(max(copy.gap, 0), maxGap)
        return copy
    }
}

struct CaretIndicatorSettings: Codable, Equatable {
    var shape: CaretShape
    var hideWhileTyping: Bool
    var typingResumeDelay: Double
    var line: CaretShapeConfig
    var square: CaretShapeConfig
    var dot: CaretShapeConfig
    var underline: CaretShapeConfig

    var active: CaretShapeConfig {
        get {
            switch shape {
            case .line: return line
            case .square: return square
            case .dot: return dot
            case .underline: return underline
            }
        }
        set {
            switch shape {
            case .line: line = newValue
            case .square: square = newValue
            case .dot: dot = newValue
            case .underline: underline = newValue
            }
        }
    }

    var normalized: CaretIndicatorSettings {
        var copy = self
        copy.typingResumeDelay = Self.clampedTypingResumeDelay(copy.typingResumeDelay)
        copy.line = copy.line.clamped(width: 15, height: 20, gap: 15)
        copy.square = copy.square.clamped(width: 15, height: 15, gap: 15)
        copy.dot = copy.dot.clamped(width: 15, height: 15, gap: 15)
        copy.underline = copy.underline.clamped(width: 20, height: 15, gap: 15)
        return copy
    }

    init(shape: CaretShape,
         hideWhileTyping: Bool = false,
         typingResumeDelay: Double = 1,
         line: CaretShapeConfig,
         square: CaretShapeConfig,
         dot: CaretShapeConfig,
         underline: CaretShapeConfig) {
        self.shape = shape
        self.hideWhileTyping = hideWhileTyping
        self.typingResumeDelay = Self.clampedTypingResumeDelay(typingResumeDelay)
        self.line = line
        self.square = square
        self.dot = dot
        self.underline = underline
    }

    private enum CodingKeys: String, CodingKey {
        case shape, hideWhileTyping, typingResumeDelay, line, square, dot, underline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = try c.decode(CaretShape.self, forKey: .shape)
        hideWhileTyping = try c.decodeIfPresent(Bool.self, forKey: .hideWhileTyping) ?? false
        typingResumeDelay = Self.clampedTypingResumeDelay(
            try c.decodeIfPresent(Double.self, forKey: .typingResumeDelay) ?? 1
        )
        line = try c.decode(CaretShapeConfig.self, forKey: .line)
        square = try c.decode(CaretShapeConfig.self, forKey: .square)
        dot = try c.decode(CaretShapeConfig.self, forKey: .dot)
        underline = try c.decode(CaretShapeConfig.self, forKey: .underline)
        self = normalized
    }

    private static func clampedTypingResumeDelay(_ value: Double) -> Double {
        min(max(value, 1), 5)
    }

    static let defaults = CaretIndicatorSettings(
        shape: .square,
        line: CaretShapeConfig(width: 4, height: 14, gap: 3, colorEN: .systemBlue, colorRU: .systemGreen),
        square: CaretShapeConfig(width: 8, height: 8, gap: 4, verticalPlacement: .aboveText, colorEN: .systemBlue, colorRU: .systemGreen),
        dot: CaretShapeConfig(width: 8, height: 8, gap: 4, colorEN: .systemBlue, colorRU: .systemGreen),
        underline: CaretShapeConfig(width: 14, height: 3, gap: 2, colorEN: .systemBlue, colorRU: .systemGreen)
    )
}

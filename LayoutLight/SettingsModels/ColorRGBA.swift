import AppKit
import SwiftUI

struct ColorRGBA: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    static let white = ColorRGBA(r: 1, g: 1, b: 1)
    // Approx. NSColor.systemBlue in sRGB.
    static let systemBlue = ColorRGBA(r: 0.0 / 255, g: 122.0 / 255, b: 255.0 / 255)
    // Approx. NSColor.systemGreen in sRGB.
    static let systemGreen = ColorRGBA(r: 52.0 / 255, g: 199.0 / 255, b: 89.0 / 255)
}

extension Color {
    init(_ rgba: ColorRGBA) {
        self = Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}

extension ColorRGBA {
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self = ColorRGBA(
            r: Double(ns.redComponent),
            g: Double(ns.greenComponent),
            b: Double(ns.blueComponent),
            a: Double(ns.alphaComponent)
        )
    }
}

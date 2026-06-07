import Testing
@testable import LayoutLight
import AppKit
import Carbon
import SwiftUI

struct LayoutLightTests {

    @Test func keyboardShortcutDisplayNameIncludesModifiersAndKey() {
        let shortcut = KeyboardShortcutConfig(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(controlKey | shiftKey)
        )

        #expect(shortcut.displayName == "⌃ ⇧ L")
        #expect(KeyboardShortcutConfig.none.displayName == I18n.t("shortcut.none"))
    }

    @Test func keyboardShortcutsAllowFunctionKeysAndEscapeWithoutModifiers() {
        #expect(KeyboardShortcutConfig(keyCode: UInt32(kVK_F1), modifiers: 0).isValid)
        #expect(KeyboardShortcutConfig(keyCode: UInt32(kVK_F12), modifiers: 0).isValid)
        #expect(KeyboardShortcutConfig(keyCode: UInt32(kVK_Escape), modifiers: 0).isValid)
        #expect(!KeyboardShortcutConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: 0).isValid)
    }

    @Test func caretSettingsNormalizationClampsOutOfRangeValues() {
        let unbounded = CaretIndicatorSettings(
            shape: .line,
            hideWhileTyping: true,
            typingResumeDelay: 10,
            line: CaretShapeConfig(width: 0, height: 99, gap: 99, colorEN: .white, colorRU: .white),
            square: CaretShapeConfig(width: 99, height: 0, gap: -1, colorEN: .white, colorRU: .white),
            dot: CaretShapeConfig(width: 99, height: 99, gap: 99, colorEN: .white, colorRU: .white),
            underline: CaretShapeConfig(width: 99, height: 99, gap: 99, colorEN: .white, colorRU: .white)
        ).normalized

        #expect(unbounded.typingResumeDelay == 5)
        #expect(unbounded.line.width == 1)
        #expect(unbounded.line.height == 20)
        #expect(unbounded.line.gap == 15)
        #expect(unbounded.square.height == 1)
        #expect(unbounded.square.gap == 0)
        #expect(unbounded.underline.width == 20)
    }

    @Test func colorRGBARoundTripsThroughSwiftUIColor() {
        let source = ColorRGBA(r: 0.25, g: 0.5, b: 0.75, a: 0.6)
        let roundTrip = ColorRGBA(Color(source))

        #expect(abs(roundTrip.r - source.r) < 0.001)
        #expect(abs(roundTrip.g - source.g) < 0.001)
        #expect(abs(roundTrip.b - source.b) < 0.001)
        #expect(abs(roundTrip.a - source.a) < 0.001)
    }

    @Test func axScreenMathConvertsTopDownDisplayCoordinatesToAppKitCoordinates() {
        let screenFrame = NSRect(x: -300, y: 100, width: 1200, height: 800)
        let frame = AXScreenMath.frameInAppKitCoordinates(
            localX: 50,
            localYFromTop: 120,
            width: 30,
            height: 40,
            screenFrame: screenFrame
        )

        #expect(frame == NSRect(x: -250, y: 740, width: 30, height: 40))
    }

    @Test func languageIndicatorSettingsDefaultsToGlobeForEnglishIcon() {
        #expect(LanguageIndicatorSettings.defaults.englishIcon == .globe1)
        #expect(LanguageIconProvider.icon(isRussian: false, settings: .defaults) == "🌍")
        #expect(LanguageIconProvider.icon(isRussian: true, settings: .defaults) == "🇷🇺")
    }

    @Test func languageIndicatorSettingsDecodesOldPayloadWithGlobe1Default() throws {
        let json = """
        {
          "showForEN": true,
          "showForRU": false,
          "colorEN": { "r": 0.1, "g": 0.2, "b": 0.3, "a": 1.0 },
          "colorRU": { "r": 0.4, "g": 0.5, "b": 0.6, "a": 1.0 }
        }
        """

        let settings = try JSONDecoder().decode(LanguageIndicatorSettings.self, from: Data(json.utf8))

        #expect(settings.showForEN)
        #expect(!settings.showForRU)
        #expect(settings.englishIcon == .globe1)
    }

    @Test func languageIndicatorSettingsKeepsSavedGlobe2Icon() throws {
        let json = """
        {
          "showForEN": true,
          "showForRU": true,
          "colorEN": { "r": 0.1, "g": 0.2, "b": 0.3, "a": 1.0 },
          "colorRU": { "r": 0.4, "g": 0.5, "b": 0.6, "a": 1.0 },
          "englishIcon": "globe"
        }
        """

        let settings = try JSONDecoder().decode(LanguageIndicatorSettings.self, from: Data(json.utf8))

        #expect(settings.englishIcon == .globe)
        #expect(LanguageIconProvider.icon(isRussian: false, settings: settings) == "🌐")
    }

}

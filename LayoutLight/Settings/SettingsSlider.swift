import SwiftUI

struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private let thumbSize: CGFloat = 22
    private let trackHeight: CGFloat = 6
    private let tickSize: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - thumbSize, 1)
            let progress = normalizedValue
            let thumbX = width * progress

            ZStack(alignment: .leading) {
                if let step {
                    tickMarks(width: width, step: step)
                        .offset(x: thumbSize / 2, y: 17)
                }

                Capsule()
                    .fill(trackColor)
                    .frame(height: trackHeight)
                    .offset(x: thumbSize / 2)

                Capsule()
                    .fill(activeTrackColor)
                    .frame(width: max(0, thumbX), height: trackHeight)
                    .offset(x: thumbSize / 2)

                Circle()
                    .fill(thumbColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .strokeBorder(thumbBorderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 4, x: 0, y: 1)
                    .offset(x: thumbX)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(from: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .number.precision(.fractionLength(step == nil ? 1 : 0))))
        .accessibilityAdjustableAction { direction in
            let increment = step ?? (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment:
                setValue(value + increment)
            case .decrement:
                setValue(value - increment)
            @unknown default:
                break
            }
        }
    }

    private var normalizedValue: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((clamped(value) - range.lowerBound) / span)
    }

    private var trackColor: Color {
        if !isEnabled {
            return Color(NSColor.separatorColor).opacity(colorScheme == .dark ? 0.35 : 0.45)
        }
        return colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.28)
    }

    private var activeTrackColor: Color {
        isEnabled ? .accentColor : Color.secondary.opacity(0.45)
    }

    private var tickColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.36)
    }

    private var thumbColor: Color {
        if colorScheme == .dark {
            return isEnabled ? Color.white.opacity(0.86) : Color.white.opacity(0.45)
        }
        return isEnabled ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor)
    }

    private var thumbBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color(NSColor.separatorColor).opacity(0.9)
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18)
    }

    private func tickMarks(width: CGFloat, step: Double) -> some View {
        let count = max(Int(((range.upperBound - range.lowerBound) / step).rounded()), 1)

        return HStack(spacing: 0) {
            ForEach(0...count, id: \.self) { index in
                Circle()
                    .fill(tickColor)
                    .frame(width: tickSize, height: tickSize)

                if index < count {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: width)
    }

    private func updateValue(from x: CGFloat, width: CGFloat) {
        let progress = min(max((x - thumbSize / 2) / width, 0), 1)
        let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
        setValue(rawValue)
    }

    private func setValue(_ newValue: Double) {
        let stepped: Double
        if let step {
            stepped = ((newValue - range.lowerBound) / step).rounded() * step + range.lowerBound
        } else {
            stepped = newValue
        }
        value = clamped(stepped)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

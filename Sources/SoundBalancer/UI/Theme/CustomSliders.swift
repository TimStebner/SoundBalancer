import SwiftUI

public struct GlassVolumeSlider: View {
    @Binding public var value: Double
    public var isMuted: Bool

    public init(value: Binding<Double>, isMuted: Bool = false) {
        self._value = value
        self.isMuted = isMuted
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let progress: CGFloat = {
                let v = CGFloat(value)
                if v <= 1.0 {
                    return max(0.0, v * 0.5)
                } else {
                    return min(1.0, 0.5 + (v - 1.0) / 3.0 * 0.5)
                }
            }()
            let fillWidth = max(6.0, width * progress)
            let isBoosted = value > 1.01

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 2, height: height * 0.7)
                    .position(x: width * 0.5, y: height * 0.5)

                if !isMuted && value > 0.01 {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(isBoosted ? LiquidGlassTheme.sliderBoostGradient : LiquidGlassTheme.sliderNormalGradient)
                        .frame(width: fillWidth, height: height)
                        .shadow(
                            color: (isBoosted ? LiquidGlassTheme.boostOrange : LiquidGlassTheme.accentCyan).opacity(0.4),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: height * 0.9, height: height * 0.9)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                    .position(x: max(height * 0.5, min(width - height * 0.5, fillWidth)), y: height * 0.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = max(0, min(width, gesture.location.x))
                        let rawProgress = Double(x / width)
                        if abs(rawProgress - 0.5) < 0.035 {
                            value = 1.0
                        } else if rawProgress < 0.5 {
                            value = rawProgress * 2.0
                        } else {
                            value = 1.0 + (rawProgress - 0.5) * 6.0
                        }
                    }
            )
        }
        .frame(height: 18)
    }
}

public struct GlassVerticalEQSlider: View {
    @Binding public var gainDB: Float
    public var label: String

    public init(gainDB: Binding<Float>, label: String) {
        self._gainDB = gainDB
        self.label = label
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(round(gainDB))) dB")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(gainDB == 0 ? .secondary : (gainDB > 0 ? LiquidGlassTheme.boostOrange : LiquidGlassTheme.accentCyan))
                .frame(height: 12)

            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                let normalized = Double(max(-12.0, min(12.0, gainDB)) + 12.0) / 24.0
                let knobY = height * (1.0 - normalized)

                ZStack {
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 6)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 12, height: 1.5)
                        .position(x: width * 0.5, y: height * 0.5)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .position(x: width * 0.5, y: max(8, min(height - 8, knobY)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let clampedY = max(0, min(height, gesture.location.y))
                            let norm = 1.0 - Double(clampedY / height)
                            if abs(norm - 0.5) < 0.04 {
                                gainDB = 0.0
                            } else {
                                gainDB = Float((norm * 24.0) - 12.0)
                            }
                        }
                )
            }
            .frame(height: 130)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(width: 28)
    }
}

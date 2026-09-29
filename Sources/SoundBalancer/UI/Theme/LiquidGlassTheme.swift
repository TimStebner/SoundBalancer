import SwiftUI

public enum LiquidGlassTheme {
    public static let accentCyan = Color(red: 0.15, green: 0.78, blue: 0.98)
    public static let accentBlue = Color(red: 0.20, green: 0.50, blue: 0.98)
    public static let accentViolet = Color(red: 0.65, green: 0.35, blue: 0.98)
    public static let boostOrange = Color(red: 1.0, green: 0.55, blue: 0.15)
    public static let boostRed = Color(red: 1.0, green: 0.30, blue: 0.35)

    public static let sliderNormalGradient = LinearGradient(
        colors: [accentCyan, accentBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let sliderBoostGradient = LinearGradient(
        colors: [accentBlue, boostOrange, boostRed],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let glassRim = LinearGradient(
        colors: [
            Color.white.opacity(0.22),
            Color.white.opacity(0.06),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let subtleBackground = Color.black.opacity(0.12)
}

public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 12

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LiquidGlassTheme.glassRim, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 14, padding: CGFloat = 12) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

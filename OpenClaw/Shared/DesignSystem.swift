import SwiftUI

// MARK: - Color Tokens (Technical Vanguard)

extension Color {
    // Surfaces
    static let surfaceLowest = Color(hex: 0x000000)
    static let surfaceBase = Color(hex: 0x0E0E0E)
    static let surfaceContainerLow = Color(hex: 0x131313)
    static let surfaceContainer = Color(hex: 0x191919)
    static let surfaceContainerHigh = Color(hex: 0x1F1F1F)
    static let surfaceContainerHighest = Color(hex: 0x262626)
    static let surfaceVariant = Color(hex: 0x262626)

    // Primary (Orange)
    static let ocPrimary = Color(hex: 0xFF9159)
    static let ocPrimaryContainer = Color(hex: 0xFF7A2F)
    static let ocPrimaryDim = Color(hex: 0xFF7524)
    static let ocOnPrimary = Color(hex: 0x531E00)

    // Secondary
    static let ocSecondary = Color(hex: 0xF88D36)

    // Tertiary (Gold)
    static let ocTertiary = Color(hex: 0xFFC562)
    static let ocTertiaryContainer = Color(hex: 0xFBB423)

    // Error
    static let ocError = Color(hex: 0xFF7351)

    // Success
    static let ocSuccess = Color(hex: 0x00C853)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xABABAB)
    static let textTertiary = Color(hex: 0x757575)

    // Outline
    static let outlineVariant = Color(hex: 0x484848)

    // Surface tint (for ambient glow)
    static let surfaceTint = Color(hex: 0xFF9159)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Typography

extension Font {
    /// Space Grotesk equivalent - Display/Headline
    static func headline(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Label - uppercase, wide tracking
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Body text - Inter equivalent
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - View Modifiers

/// "Technical Vanguard" card style - no borders, tonal layering
struct VanguardCard: ViewModifier {
    var elevated: Bool = false
    var glowBorder: Bool = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? Color.surfaceContainer : Color.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        glowBorder ? Color.ocPrimary.opacity(0.2) : Color.white.opacity(0.03),
                        lineWidth: 1
                    )
            )
    }
}

/// Ghost border style - hairline detail
struct GhostBorder: ViewModifier {
    var color: Color = .outlineVariant
    var opacity: Double = 0.15

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(color.opacity(opacity), lineWidth: 1)
            )
    }
}

/// Glassmorphic bar
struct GlassBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.black.opacity(0.8))
            .background(.ultraThinMaterial)
    }
}

extension View {
    func vanguardCard(elevated: Bool = false, glow: Bool = false) -> some View {
        modifier(VanguardCard(elevated: elevated, glowBorder: glow))
    }

    func ghostBorder(color: Color = .outlineVariant, opacity: Double = 0.15) -> some View {
        modifier(GhostBorder(color: color, opacity: opacity))
    }

    func glassBar() -> some View {
        modifier(GlassBar())
    }
}

// MARK: - Reusable Components

/// Section header with "ACTIVE PROTOCOL" style label
struct SectionLabel: View {
    let text: String
    var color: Color = .ocPrimary

    var body: some View {
        Text(text.uppercased())
            .font(.label(10, weight: .bold))
            .tracking(2)
            .foregroundStyle(color)
    }
}

/// Kind/type badge pill
struct KindBadge: View {
    let text: String
    var color: Color = .ocPrimary

    var body: some View {
        Text(text.uppercased())
            .font(.label(9, weight: .bold))
            .tracking(1.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.1))
            .overlay(
                Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// LED status dot (4px, glowing)
struct StatusLED: View {
    var color: Color = .ocSuccess
    var pulsing: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.6), radius: pulsing ? 4 : 0)
            .opacity(pulsing ? 1 : 0.8)
    }
}

/// Icon avatar circle
struct IconAvatar: View {
    let icon: String
    var color: Color = .ocPrimary
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Color.surfaceContainerHighest)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

// MARK: - Blueprint Grid Background

struct BlueprintGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            for x in stride(from: 0, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.outlineVariant.opacity(0.05)), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.outlineVariant.opacity(0.05)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

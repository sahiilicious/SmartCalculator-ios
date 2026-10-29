import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    /// Color from a 0xRRGGBB number.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    /// A color that changes automatically between light and dark mode.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// One place for the whole color system (dark navy + blue/purple accents).
enum Theme {
    static let backgroundTop = Color(light: Color(hex: 0xEEF1FF), dark: Color(hex: 0x0A0F2C))
    static let backgroundBottom = Color(light: Color(hex: 0xF7F3FF), dark: Color(hex: 0x16124A))
    static let card = Color(light: .white, dark: Color(hex: 0x171E4A))
    static let cardStroke = Color(light: Color(hex: 0xDDE2F7), dark: Color(hex: 0x2A3370))
    static let field = Color(light: Color(hex: 0xF0F2FC), dark: Color(hex: 0x0F1538))
    static let textPrimary = Color(light: Color(hex: 0x12163A), dark: .white)
    static let textSecondary = Color(light: Color(hex: 0x5B6190), dark: Color(hex: 0xA9B1E3))

    static let accent = Color(hex: 0x5B7CFF)
    static let accentPurple = Color(hex: 0x8B5CF6)
    static let danger = Color(hex: 0xFF5C6C)
    static let warning = Color(hex: 0xF5A524)
    static let success = Color(hex: 0x2FBF71)

    static let accentGradient = LinearGradient(colors: [accent, accentPurple],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)

    // Calculator keys
    static let keyDigit = Color(light: .white, dark: Color(hex: 0x1D2558))
    static let keyFunction = Color(light: Color(hex: 0xDCE3FF), dark: Color(hex: 0x2B3680))
}

// MARK: - Per-category styling

extension ConversionCategory {
    var symbolName: String {
        switch self {
        case .length: return "ruler"
        case .weight: return "scalemass"
        case .volume: return "drop"
        case .temperature: return "thermometer.medium"
        case .speed: return "speedometer"
        case .angle: return "angle"
        case .area: return "square.dashed"
        }
    }

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .length: colors = [Color(hex: 0x4F8CFF), Color(hex: 0x5B5BFF)]
        case .weight: colors = [Color(hex: 0xA25BFF), Color(hex: 0x6E4BFF)]
        case .volume: colors = [Color(hex: 0x27B6E8), Color(hex: 0x3D7BFF)]
        case .temperature: colors = [Color(hex: 0xFF7A59), Color(hex: 0xFF4F8B)]
        case .speed: colors = [Color(hex: 0x2FC8A8), Color(hex: 0x2B8CFF)]
        case .angle: colors = [Color(hex: 0xF5A524), Color(hex: 0xFF6B4A)]
        case .area: colors = [Color(hex: 0x7A6BFF), Color(hex: 0xC25BFF)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Reusable view helpers

/// Rounded card with a soft border and shadow.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

/// Gradient screen background used by every screen.
struct ScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.backgroundTop, Theme.backgroundBottom],
                           startPoint: .top,
                           endPoint: .bottom)
            Circle()
                .fill(Theme.accentPurple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 140, y: -260)
            Circle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -150, y: 320)
        }
        .ignoresSafeArea()
    }
}

/// Button style that shrinks slightly while pressed.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Small colored banner used for notices (cached rates, errors, info).
struct NoticeBanner: View {
    enum Kind { case info, warning, error }

    let kind: Kind
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    private var tint: Color {
        switch kind {
        case .info: return Theme.accent
        case .warning: return Theme.warning
        case .error: return Theme.danger
        }
    }

    private var symbol: String {
        switch kind {
        case .info: return "info.circle.fill"
        case .warning: return "clock.arrow.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundColor(tint)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Round gradient button with an icon (used for the swap action).
struct CircleIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

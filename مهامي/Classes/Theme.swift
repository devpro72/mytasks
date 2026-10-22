import SwiftUI
import AppKit

// MARK: - Color(hex:)

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - تطبيق نمط المظهر (كل نافذة تقرأ التفضيل بنفسها)

private struct AppearanceModifier: ViewModifier {
    @AppStorage("appearanceMode") private var appearanceMode = 0

    func body(content: Content) -> some View {
        content.preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

extension View {
    func applyAppearance() -> some View {
        modifier(AppearanceModifier())
    }

    /// فرض الاتجاه من اليمين إلى اليسار على هذا الجزء من الواجهة
    func forceRTL() -> some View {
        environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - نمط الأزرار (منطقة نقر كاملة + تأثير ضغط)

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var press: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - لوحة الألوان (فاتح دافئ + داكن متوافق)

private func dynamicColor(_ light: NSColor, _ dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return dark
        }
        return light
    })
}

enum Palette {
    static let background = dynamicColor(NSColor(hex: 0xFAF7F2), NSColor(hex: 0x201F1C))
    static let sidebar = dynamicColor(NSColor(hex: 0xF2EFE8), NSColor(hex: 0x262521))
    static let card = dynamicColor(NSColor(hex: 0xFFFFFF), NSColor(hex: 0x2B2A26))
    static let fieldField = dynamicColor(NSColor(hex: 0xF4F1EA), NSColor(hex: 0x33322D))
    static let text = dynamicColor(NSColor(hex: 0x2E2D2A), NSColor(hex: 0xF1EFE9))
    static let mutedText = dynamicColor(NSColor(hex: 0x8C897E), NSColor(hex: 0xA09D93))
    static let border = dynamicColor(NSColor(hex: 0xE4E0D5), NSColor(hex: 0x3B3A34))
    static let accent = dynamicColor(NSColor(hex: 0x2F4A38), NSColor(hex: 0x7FA98E))
    static let accentSoft = dynamicColor(NSColor(hex: 0x2F4A38, alpha: 0.12), NSColor(hex: 0x7FA98E, alpha: 0.2))
    static let highlight = Color(nsColor: .controlAccentColor)
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    static let appBackground = Palette.background
    static let appSidebar = Palette.sidebar
    static let appCard = Palette.card
    static let appField = Palette.fieldField
    static let appText = Palette.text
    static let appMuted = Palette.mutedText
    static let appBorder = Palette.border
    static let appAccent = Palette.accent
    static let appAccentSoft = Palette.accentSoft
}

// MARK: - مُعدّلات مشتركة

struct SurfaceBackground: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
            )
    }
}

extension View {
    func surface(cornerRadius: CGFloat = 12) -> some View {
        modifier(SurfaceBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - شارة (Chip)

struct ChipView: View {
    let label: String
    let icon: String?
    let color: Color
    var filled: Bool = true

    init(label: String, icon: String? = nil, color: Color, filled: Bool = true) {
        self.label = label
        self.icon = icon
        self.color = color
        self.filled = filled
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? color.opacity(0.14) : Color.clear)
        )
    }
}

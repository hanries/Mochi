import SwiftUI

// MARK: - Mochi design tokens
//
// The single source of styling truth for the warm Mochi look. The Home
// tab uses these exclusively; remaining tabs migrate in a later
// app-wide theme pass. No view should define inline colors, fonts, or
// radii — add a token here instead.

enum MochiTheme {

    // MARK: Colors

    static let background    = Color(hex: 0xFAF5EC)
    static let surface       = Color(hex: 0xF3E9DA)
    static let surfaceAlt    = Color(hex: 0xFFFFFF)
    static let primary       = Color(hex: 0xF29D45)
    static let accent        = Color(hex: 0xF2697D)
    static let textPrimary   = Color(hex: 0x4A2A12)
    static let textSecondary = Color(hex: 0x9A7B5F)
    static let success       = Color(hex: 0x7FA86F)
    static let warning       = Color(hex: 0xE8A21F)
    static let danger        = Color(hex: 0xC75C4A)  // warm terracotta, destructive/error

    // MARK: Typography — SF Rounded

    static let largeTitle = Font.system(size: 32, weight: .bold,     design: .rounded)
    static let title      = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let body       = Font.system(size: 16, weight: .regular,  design: .rounded)
    static let caption    = Font.system(size: 13, weight: .medium,   design: .rounded)

    // MARK: Metrics

    static let cardRadius: CGFloat   = 22
    static let buttonRadius: CGFloat = 28

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Card surface modifier

struct MochiCard: ViewModifier {
    var cornerRadius: CGFloat = MochiTheme.cardRadius
    func body(content: Content) -> some View {
        content
            .background(MochiTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func mochiCard(cornerRadius: CGFloat = MochiTheme.cardRadius) -> some View {
        modifier(MochiCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Hex color helper (file-private to keep tokens the only API)

private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255
        )
    }
}

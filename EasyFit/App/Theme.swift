import SwiftUI

// MARK: - App-wide design tokens

enum Theme {
    // Backgrounds
    static let bg       = Color(red: 0.07, green: 0.07, blue: 0.10)   // root dark
    static let card     = Color(red: 0.14, green: 0.14, blue: 0.19)   // card surface
    static let cardAlt  = Color(red: 0.10, green: 0.10, blue: 0.14)   // slightly deeper card

    // Accent
    static let teal     = Color(red: 0.17, green: 0.85, blue: 0.78)   // primary teal
    static let tealDim  = Color(red: 0.17, green: 0.85, blue: 0.78).opacity(0.18)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary  = Color.white.opacity(0.30)
}

// MARK: - Convenience modifier for card surfaces

struct DarkCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func darkCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(DarkCard(cornerRadius: cornerRadius))
    }
}

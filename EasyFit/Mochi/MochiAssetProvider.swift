import SwiftUI

// MARK: - Single source of truth for Mochi's appearance
//
// Views never reference image/symbol names directly — they call
// mochiView(for:size:). Swapping placeholders for real art or
// Lottie/Rive animations happens here only.
//
// Art lookup order per state: "hamster_<state>" asset → "hamster_idle"
// asset → SF Symbol badge. Dropping a new state image into the asset
// catalog picks it up with no code changes.

enum MochiAssetProvider {

    @ViewBuilder
    static func mochiView(for state: MochiState, size: CGFloat) -> some View {
        if let name = assetName(for: state) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            ZStack {
                Circle()
                    .fill(tint(for: state).opacity(0.16))
                Circle()
                    .strokeBorder(tint(for: state).opacity(0.35), lineWidth: 1.5)
                Image(systemName: symbolName(for: state))
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(tint(for: state))
            }
            .frame(width: size, height: size)
        }
    }

    static func assetName(for state: MochiState) -> String? {
        let preferred = "hamster_\(state.rawValue.lowercased())"
        if UIImage(named: preferred) != nil { return preferred }
        if UIImage(named: "hamster_idle") != nil { return "hamster_idle" }
        return nil
    }

    static func symbolName(for state: MochiState) -> String {
        switch state {
        case .ecstatic:   return "face.smiling.inverse"
        case .happy:      return "face.smiling"
        case .content:    return "leaf.fill"
        case .sleepy:     return "moon.zzz.fill"
        case .missingYou: return "heart.fill"
        }
    }

    static func tint(for state: MochiState) -> Color {
        switch state {
        case .ecstatic:   return Color(red: 1.0, green: 0.72, blue: 0.30)  // warm gold
        case .happy:      return Color(red: 1.0, green: 0.62, blue: 0.45)  // peach
        case .content:    return Color(red: 0.85, green: 0.72, blue: 0.55) // soft tan
        case .sleepy:     return Color(red: 0.62, green: 0.60, blue: 0.85) // dusk lavender
        case .missingYou: return Color(red: 0.95, green: 0.55, blue: 0.60) // soft rose
        }
    }
}

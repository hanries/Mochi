import SwiftUI

// MARK: - Mochi's room
//
// The habitat illustration that fills the top of the Home tab. Fills its
// container width, anchored top, with a slight bleed so no iPhone size
// letterboxes, and melts into MochiTheme.background through a soft
// gradient mask at the bottom edge — the room never ends in a hard line
// and never sits behind body text. Decorative only (hidden from
// VoiceOver). The only motion in the scene is Mochi himself.

struct MochiHabitatScene: View {
    var isNight: Bool = false

    /// Edge bleed so scaledToFill never letterboxes on any aspect ratio.
    private let bleed: CGFloat = 1.05
    /// Height of the fade into the page background at the bottom edge.
    private let fadeHeight: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Keyed by image so a day/night flip crossfades when the
                // caller animates it (instant under Reduce Motion).
                Image(MochiAssetProvider.habitatImageName(night: isNight))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * bleed,
                           height: geo.size.height * bleed,
                           alignment: .top)
                    .id(MochiAssetProvider.habitatImageName(night: isNight))
                    .transition(.opacity)
            }
            .frame(width: geo.size.width,
                   height: geo.size.height,
                   alignment: .top)
            .clipped()
            .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: fadeHeight)
                    }
                )
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    ZStack {
        MochiTheme.background.ignoresSafeArea()
        VStack {
            MochiHabitatScene()
                .frame(height: 460)
            Spacer()
        }
    }
}

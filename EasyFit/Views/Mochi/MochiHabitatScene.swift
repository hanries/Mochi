import SwiftUI
import UIKit

// MARK: - Mochi's room
//
// The habitat illustration behind Mochi on the Home tab. The image fills
// the scene width and is anchored to the BOTTOM of the scene so the rug
// (in the image's lower third) is always visible — the top of the room
// crops on shorter scenes instead. A slight bleed prevents letterboxing
// on any aspect ratio, and the bottom edge melts into
// MochiTheme.background through a gradient mask. Decorative only (hidden
// from VoiceOver); the only motion in the scene is Mochi himself.

struct MochiHabitatScene: View {
    var isNight: Bool = false

    /// Edge bleed so scaledToFill never letterboxes on any aspect ratio.
    static let bleed: CGFloat = 1.05
    /// The rug's vertical center, as a fraction of the habitat image height.
    static let rugCenterImageRatio: CGFloat = 0.88
    /// Height of the fade into the page background at the bottom edge.
    private let fadeHeight: CGFloat = 40

    /// On-screen Y of the rug's center for a given scene size, derived from
    /// the habitat image's real aspect ratio and fill scale — no hardcoded
    /// points, so Mochi's feet land on the rug at every device size.
    static func rugCenterY(sceneWidth: CGFloat, sceneHeight: CGFloat) -> CGFloat {
        guard let image = UIImage(named: MochiAssetProvider.habitatImageName(night: false)),
              image.size.width > 0, image.size.height > 0
        else { return sceneHeight * rugCenterImageRatio }

        let frameW = sceneWidth * bleed
        let frameH = sceneHeight * bleed
        let scale  = max(frameW / image.size.width, frameH / image.size.height)
        let displayedHeight = image.size.height * scale

        // Image bottom sits at the scene bottom; the rug center is
        // rugCenterImageRatio down the image.
        let rugFromBottom = displayedHeight * (1 - rugCenterImageRatio)
        return sceneHeight - rugFromBottom
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Keyed by image so a day/night flip crossfades when the
                // caller animates it (instant under Reduce Motion).
                Image(MochiAssetProvider.habitatImageName(night: isNight))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * Self.bleed,
                           height: geo.size.height * Self.bleed,
                           alignment: .bottom)
                    .id(MochiAssetProvider.habitatImageName(night: isNight))
                    .transition(.opacity)
            }
            .frame(width: geo.size.width,
                   height: geo.size.height,
                   alignment: .bottom)
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

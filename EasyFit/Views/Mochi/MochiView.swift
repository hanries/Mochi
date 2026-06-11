import SwiftUI

// MARK: - The living Mochi character
//
// Renders Mochi from flat PNG frames and makes him feel alive with
// whole-image transforms and frame swaps. All timing lives in MochiMotion.
//
// Phase 1: base frame per state + crossfade/pulse on state change.
// Later phases layer in breathing, sway, blinking, tap reaction, moments.

struct MochiView: View {
    let state: MochiState
    var size: CGFloat = 170
    var onTap: (() -> Void)? = nil   // wired in the tap-reaction phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulseScale: CGFloat = 1.0

    private let motion = MochiMotion.default

    private var baseImageName: String {
        MochiAssetProvider.baseImageName(for: state)
    }

    var body: some View {
        ZStack {
            Image(baseImageName)
                .resizable()
                .scaledToFit()
                .id(baseImageName)
                .transition(.opacity)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: motion.transitionDuration), value: baseImageName)
        .scaleEffect(pulseScale, anchor: .bottom)
        .onChange(of: state) { _, _ in
            guard !reduceMotion else { return }
            pulseScale = motion.transitionPulseScale
            withAnimation(.spring(response: motion.momentSpringResponse,
                                  dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
    }
}

#Preview("States") {
    struct Cycler: View {
        @State private var state: MochiState = .happy
        var body: some View {
            VStack(spacing: 30) {
                MochiView(state: state, size: 170)
                Button("Next state") {
                    let all = MochiState.allCases
                    let i = all.firstIndex(of: state)!
                    state = all[(i + 1) % all.count]
                }
                Text(state.rawValue).foregroundStyle(.secondary)
            }
        }
    }
    return ZStack {
        Theme.bg.ignoresSafeArea()
        Cycler()
    }
    .preferredColorScheme(.dark)
}

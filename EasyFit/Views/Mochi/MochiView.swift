import SwiftUI

// MARK: - The living Mochi character
//
// Renders Mochi from flat PNG frames and makes him feel alive with
// whole-image transforms and frame swaps. All timing lives in MochiMotion.
//
// Breathing and sway are driven by one TimelineView time source with sine
// math: phase offsets are arithmetic, per-state periods are parameters,
// and pausing (Reduce Motion / backgrounded) is a single boolean — no
// repeatForever animations to leak or restart.

struct MochiView: View {
    let state: MochiState
    var size: CGFloat = 170
    var onTap: (() -> Void)? = nil   // wired in the tap-reaction phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var isBlinking = false

    private let motion = MochiMotion.default

    private var baseImageName: String {
        MochiAssetProvider.baseImageName(for: state)
    }

    /// Blink swaps the frame inside the same view identity, so it's an
    /// instant swap — only base-frame changes get the crossfade.
    private var displayedImageName: String {
        if isBlinking, let blink = MochiAssetProvider.blinkImageName(for: state) {
            return blink
        }
        return baseImageName
    }

    private var motionPaused: Bool {
        reduceMotion || scenePhase != .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: motionPaused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Breathing: bottom-anchored squash & stretch, 0 at rest so the
            // body only expands upward. Sleepy breathes slower and deeper.
            let breathPeriod = state == .sleepy ? motion.breathPeriodSleepy : motion.breathPeriod
            let breathDepth  = state == .sleepy ? motion.breathScaleYSleepy : motion.breathScaleY
            let breath = motionPaused ? 0.0 : (sin(2 * .pi * t / breathPeriod) + 1) / 2
            let scaleY = 1 + breathDepth * breath
            let scaleX = 1 - motion.breathScaleX * breath

            // Idle sway, slightly out of phase with the breath.
            let sway = motionPaused
                ? 0.0
                : motion.swayAmplitude * sin(2 * .pi * t / motion.swayPeriod + motion.swayPhaseOffset)

            ZStack {
                Image(displayedImageName)
                    .resizable()
                    .scaledToFit()
                    .id(baseImageName)
                    .transition(.opacity)
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: motion.transitionDuration), value: baseImageName)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .rotationEffect(.degrees(sway), anchor: .bottom)
        }
        .scaleEffect(pulseScale, anchor: .bottom)
        .onChange(of: state) { _, _ in
            guard !reduceMotion else { return }
            pulseScale = motion.transitionPulseScale
            withAnimation(.spring(response: motion.momentSpringResponse,
                                  dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
        // Blink loop: restarts on state change, cancels on disappear.
        .task(id: state) {
            isBlinking = false
            guard MochiAssetProvider.blinkImageName(for: state) != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: motion.blinkInterval)))
                guard !Task.isCancelled else { return }
                await blinkOnce()
                if Int.random(in: 1...motion.doubleBlinkOdds) == 1 {
                    try? await Task.sleep(for: .seconds(motion.doubleBlinkGap))
                    guard !Task.isCancelled else { return }
                    await blinkOnce()
                }
            }
        }
    }

    private func blinkOnce() async {
        isBlinking = true
        try? await Task.sleep(for: .seconds(motion.blinkDuration))
        isBlinking = false
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

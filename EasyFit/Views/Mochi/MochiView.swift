import SwiftUI
import UIKit

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
    var moment: MochiMoment? = nil
    var size: CGFloat = 170
    var showShadow: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var isBlinking = false

    // Tap reaction
    @State private var tapScale: CGFloat = 1.0
    @State private var hopOffset: CGFloat = 0

    // Moment override (eating / milestone ecstatic)
    @State private var momentFrame: String? = nil
    @State private var momentScale: CGFloat = 1.0
    @State private var momentTask: Task<Void, Never>? = nil

    private let motion = MochiMotion.default

    private var baseImageName: String {
        MochiAssetProvider.baseImageName(for: state)
    }

    /// Identity + crossfade key: changes when the base frame or a moment
    /// override changes — those crossfade. Blinks happen inside the same
    /// identity and swap instantly.
    private var anchorFrameName: String {
        momentFrame ?? baseImageName
    }

    private var displayedImageName: String {
        if let momentFrame { return momentFrame }
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

            ZStack(alignment: .bottom) {
                // Ground-contact shadow: stays on the floor (no sway/stretch),
                // narrowing slightly as the body breathes upward.
                if showShadow {
                    Ellipse()
                        .fill(MochiTheme.textPrimary.opacity(0.12))
                        .frame(width: size * 0.55, height: size * 0.11)
                        .scaleEffect(x: 1 - 0.06 * breath, anchor: .center)
                        .blur(radius: 8)
                        .offset(y: size * 0.02)
                        .accessibilityHidden(true)
                }

                ZStack {
                    Image(displayedImageName)
                        .resizable()
                        .scaledToFit()
                        .id(anchorFrameName)
                        .transition(.opacity)
                }
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: motion.transitionDuration), value: anchorFrameName)
                .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
                .rotationEffect(.degrees(sway), anchor: .bottom)
            }
        }
        .scaleEffect(pulseScale * tapScale * momentScale, anchor: .bottom)
        .offset(y: hopOffset)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mochi, your companion, is \(state.accessibilityDescription)")
        .accessibilityAddTraits(.isButton)
        .onChange(of: state) { _, _ in
            guard !reduceMotion else { return }
            pulseScale = motion.transitionPulseScale
            withAnimation(.spring(response: motion.momentSpringResponse,
                                  dampingFraction: 0.6)) {
                pulseScale = 1.0
            }
        }
        .onChange(of: moment) { _, newMoment in
            if let newMoment { beginMoment(newMoment) }
        }
        .onDisappear {
            momentTask?.cancel()
            momentFrame = nil
            momentScale = 1.0
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

    // MARK: - Tap reaction

    private func handleTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onTap?()
        guard !reduceMotion else { return }

        withAnimation(.spring(response: motion.tapSpringResponse,
                              dampingFraction: motion.tapSpringDamping)) {
            tapScale = motion.tapBounceScale
            hopOffset = -motion.tapHopHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: motion.tapSpringResponse,
                                  dampingFraction: motion.tapSpringDamping)) {
                tapScale = 1.0
                hopOffset = 0
            }
        }
    }

    // MARK: - Moments

    private func beginMoment(_ newMoment: MochiMoment) {
        momentTask?.cancel()

        // Check-ins are acknowledgment only: no frame change, small bounce.
        switch newMoment.kind {
        case .eating:   momentFrame = MochiAssetProvider.eatingImageName
        case .ecstatic: momentFrame = MochiAssetProvider.baseImageName(for: .ecstatic)
        case .checkIn:  momentFrame = nil
        }

        if !reduceMotion {
            let peak: Double
            switch newMoment.kind {
            case .eating:   peak = motion.momentBounceEating
            case .ecstatic: peak = motion.momentBounceEcstatic
            case .checkIn:  peak = motion.tapBounceScale
            }
            withAnimation(.spring(response: motion.momentSpringResponse,
                                  dampingFraction: motion.momentSpringDamping)) {
                momentScale = peak
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: motion.momentSpringResponse,
                                      dampingFraction: motion.momentSpringDamping)) {
                    momentScale = 1.0
                }
            }
        }

        momentTask = Task {
            try? await Task.sleep(for: .seconds(motion.momentDuration))
            guard !Task.isCancelled else { return }
            momentFrame = nil   // crossfades back via anchorFrameName change
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
                Text(state.rawValue).foregroundStyle(MochiTheme.textSecondary)
            }
        }
    }
    return ZStack {
        MochiTheme.background.ignoresSafeArea()
        Cycler()
    }
    .preferredColorScheme(.dark)
}

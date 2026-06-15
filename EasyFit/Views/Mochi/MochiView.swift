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
    // Presentation pose override (guided tour). When set it replaces the
    // state-derived frame; blinking is suppressed while a pose is held.
    var pose: MochiAssetProvider.Pose? = nil
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var isBlinking = false

    // Tap reaction
    @State private var tapScale: CGFloat = 1.0
    @State private var hopOffset: CGFloat = 0

    // Moment override (eating / milestone ecstatic / cheer jump)
    @State private var momentFrame: String? = nil
    @State private var momentScale: CGFloat = 1.0
    @State private var momentTask: Task<Void, Never>? = nil
    @State private var jumpTask: Task<Void, Never>? = nil

    // Random little reaction frame when Mochi is tapped
    @State private var reactionFrame: String? = nil
    @State private var reactionTask: Task<Void, Never>? = nil

    private let motion = MochiMotion.default

    private var baseImageName: String {
        MochiAssetProvider.baseImageName(for: state)
    }

    /// Identity + crossfade key: changes when the base frame or a moment
    /// override changes — those crossfade. Blinks happen inside the same
    /// identity and swap instantly.
    private var anchorFrameName: String {
        if let pose { return MochiAssetProvider.poseImageName(pose) }
        return momentFrame ?? reactionFrame ?? baseImageName
    }

    private var displayedImageName: String {
        if let pose { return MochiAssetProvider.poseImageName(pose) }
        if let momentFrame { return momentFrame }
        if let reactionFrame { return reactionFrame }
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

                // Drifting "z" sleep cue — floats above his head, only when sleepy.
                if state == .sleepy {
                    sleepyZs(t: t)
                        .frame(width: size, height: size, alignment: .top)
                        .accessibilityHidden(true)
                }
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
        // A moment set before this view existed (e.g. a weight/photo log on
        // another tab that redirects Home, recreating this view) won't fire
        // onChange — play it on appear so the jump/eating moment still shows.
        .onAppear {
            if let moment { beginMoment(moment) }
        }
        .onDisappear {
            momentTask?.cancel()
            jumpTask?.cancel()
            reactionTask?.cancel()
            momentFrame = nil
            reactionFrame = nil
            momentScale = 1.0
            hopOffset = 0
        }
        // Blink loop: restarts on state change, cancels on disappear.
        // Sleepy blinks slowly and heavily (and never double-blinks) so Mochi
        // reads as drowsy-but-alive instead of a frozen closed frame.
        .task(id: state) {
            isBlinking = false
            guard MochiAssetProvider.blinkImageName(for: state) != nil else { return }
            let sleepy   = state == .sleepy
            let interval = sleepy ? motion.sleepyBlinkInterval : motion.blinkInterval
            let duration = sleepy ? motion.sleepyBlinkDuration : motion.blinkDuration
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: interval)))
                guard !Task.isCancelled else { return }
                await blinkOnce(duration: duration)
                if !sleepy, Int.random(in: 1...motion.doubleBlinkOdds) == 1 {
                    try? await Task.sleep(for: .seconds(motion.doubleBlinkGap))
                    guard !Task.isCancelled else { return }
                    await blinkOnce(duration: duration)
                }
            }
        }
    }

    private func blinkOnce(duration: Double) async {
        isBlinking = true
        try? await Task.sleep(for: .seconds(duration))
        isBlinking = false
    }

    // MARK: - Sleepy "z" overlay

    /// Soft "z"s drifting up off his head. Driven by the shared TimelineView
    /// clock so it pauses with the rest of the motion; Reduce Motion / inactive
    /// collapses to a single static z.
    @ViewBuilder
    private func sleepyZs(t: TimeInterval) -> some View {
        let baseX = size * 0.30   // up and to the right of his head
        let baseY = -size * 0.20
        if motionPaused {
            Text("z")
                .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                .foregroundStyle(MochiTheme.textSecondary.opacity(motion.sleepyZOpacity * 0.7))
                .offset(x: baseX, y: baseY)
        } else {
            ZStack {
                ForEach(0..<motion.sleepyZCount, id: \.self) { i in
                    let phase = ((t / motion.sleepyZPeriod) + Double(i) / Double(motion.sleepyZCount))
                        .truncatingRemainder(dividingBy: 1)
                    let fade = sin(.pi * phase)   // 0 → 1 → 0 over the cycle
                    Text("z")
                        .font(.system(size: size * (0.11 + 0.05 * (1 - phase)),
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(MochiTheme.textSecondary.opacity(motion.sleepyZOpacity * fade))
                        .offset(x: baseX + size * 0.06 * phase,
                                y: baseY - size * motion.sleepyZRise * phase)
                }
            }
        }
    }

    // MARK: - Tap reaction

    private func handleTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onTap?()

        // Don't interrupt a guided-tour pose or an in-flight moment.
        if pose == nil, momentFrame == nil {
            playReaction()
        }

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

    /// Show a random reaction frame briefly (scratching, waving, …), then
    /// crossfade back to the engine-driven frame. The frame swap is gentle, so
    /// it plays under Reduce Motion too; only the hop above is suppressed.
    private func playReaction() {
        guard let reaction = MochiAssetProvider.availableTapReactions().randomElement() else { return }
        reactionTask?.cancel()
        reactionFrame = reaction.assetName
        reactionTask = Task {
            try? await Task.sleep(for: .seconds(motion.reactionDuration))
            guard !Task.isCancelled else { return }
            reactionFrame = nil
        }
    }

    // MARK: - Moments

    private func beginMoment(_ newMoment: MochiMoment) {
        momentTask?.cancel()

        // Check-ins are acknowledgment only: no frame change, small bounce.
        switch newMoment.kind {
        case .eating:   momentFrame = MochiAssetProvider.eatingImageName
        case .ecstatic: momentFrame = MochiAssetProvider.baseImageName(for: .ecstatic)
        case .cheer:    momentFrame = MochiAssetProvider.cheerImageName
        case .checkIn:  momentFrame = nil
        }

        if newMoment.kind == .cheer {
            beginCheerJump()
        } else if !reduceMotion {
            let peak: Double
            switch newMoment.kind {
            case .eating:   peak = motion.momentBounceEating
            case .ecstatic: peak = motion.momentBounceEcstatic
            case .cheer:    peak = 1.0   // handled by the jump loop
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

    /// Mochi gets up and springs a few times for joy (weight / photo logs).
    private func beginCheerJump() {
        guard !reduceMotion else { return }
        jumpTask?.cancel()
        jumpTask = Task {
            let h = size * motion.cheerJumpFraction
            for _ in 0..<motion.cheerJumpCount {
                withAnimation(.spring(response: motion.cheerUpResponse, dampingFraction: 0.5)) {
                    hopOffset = -h
                    momentScale = motion.cheerScale
                }
                try? await Task.sleep(for: .seconds(motion.cheerUpResponse + motion.cheerHangTime))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: motion.cheerDownResponse, dampingFraction: 0.65)) {
                    hopOffset = 0
                    momentScale = 1.0
                }
                try? await Task.sleep(for: .seconds(motion.cheerDownResponse + motion.cheerLandTime))
                guard !Task.isCancelled else { return }
            }
            hopOffset = 0
            momentScale = 1.0
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

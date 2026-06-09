import SwiftUI
import CoreMotion

// MARK: - Interactive Mochi

struct InteractiveMochiView: View {
    let state:   HamsterState
    let size:    CGFloat

    // Drag
    @State private var dragOffset   = CGSize.zero
    @State private var isDragging   = false

    // Tap reactions
    @State private var tapScale:    CGFloat = 1.0
    @State private var tapRotation: Double  = 0
    @State private var showBubble   = false
    @State private var bubbleText   = ""
    @State private var bubbleOffset = CGSize(width: 0, height: -80)

    // Long press
    @State private var isPurring    = false
    @State private var purseScale:  CGFloat = 1.0

    // Double tap dance
    @State private var isDancing    = false
    @State private var danceOffset: CGFloat = 0

    // Swipe up jump
    @State private var jumpOffset:  CGFloat = 0
    @State private var jumpScale:   CGFloat = 1.0

    // Squish on drag release
    @State private var squishX:     CGFloat = 1.0
    @State private var squishY:     CGFloat = 1.0

    // Haptics
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)

    // Random quips pool
    private let tapQuips = [
        "Hey, that tickles! 🐹",
        "I'm trying to nap here...",
        "Feed me! 🥜",
        "Let's crush those goals! 💪",
        "You're doing amazing!",
        "Squeak! 👀",
        "More pets please!",
        "I believe in you!",
        "Keep going, don't stop!",
        "Protein first! 🥚",
        "Is it snack time yet?",
        "You've got this!",
        "I'm rooting for you! 🎉",
        "*happy hamster noises*",
        "Did you drink water today? 💧",
        "One more rep! 🏋️",
        "Log your meals! I'm watching 👀",
        "Proud of you! 🌟",
        "Let's go for a run! 🏃",
        "Your streak is on fire! 🔥",
    ]

    var body: some View {
        ZStack {
            // Hamster
            HamsterView(state: state, size: size)
                .scaleEffect(x: squishX * (isPurring ? purseScale : 1.0),
                             y: squishY * (isPurring ? purseScale : 1.0))
                .scaleEffect(tapScale * jumpScale)
                .rotationEffect(.degrees(tapRotation + (isDancing ? danceRotation : 0)))
                .offset(x: dragOffset.width,
                        y: dragOffset.height + (isDancing ? danceOffset : jumpOffset))
                .animation(isDragging ? .interactiveSpring() : .spring(response: 0.4, dampingFraction: 0.5),
                           value: dragOffset)

            // Speech bubble
            if showBubble {
                SpeechBubble(text: bubbleText)
                    .offset(bubbleOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal:   .opacity
                    ))
                    .zIndex(1)
            }
        }
        .frame(width: size * 2.5, height: size * 2.5)
        // MARK: - Gestures
        .gesture(
            SimultaneousGesture(
                // Drag
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        isDragging  = true
                        dragOffset  = value.translation
                        // Squish in drag direction
                        let angle   = atan2(value.translation.height, value.translation.width)
                        let stretch = 1.15
                        squishX     = 1 + (cos(angle) * (stretch - 1)) * 0.3
                        squishY     = 1 + (sin(angle) * (stretch - 1)) * 0.3
                        impactLight.impactOccurred()
                    }
                    .onEnded { value in
                        isDragging = false
                        // Spring back with squish
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            dragOffset = .zero
                            squishX    = 0.85
                            squishY    = 1.2
                        }
                        impactMedium.impactOccurred()
                        // Recover squish
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.3)) {
                                squishX = 1.0
                                squishY = 1.0
                            }
                        }
                    },

                // Tap (single)
                TapGesture(count: 1)
                    .onEnded {
                        handleTap()
                    }
            )
        )
        // Double tap — dance
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        // Long press — purr
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 20) {
            handleLongPress()
        }
        // Swipe up — jump
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -30 && abs(value.translation.width) < 40 {
                        handleSwipeUp()
                    }
                }
        )
    }

    // MARK: - Dance rotation helper

    private var danceRotation: Double {
        isDancing ? (danceOffset > 0 ? 15 : -15) : 0
    }

    // MARK: - Interaction handlers

    private func handleTap() {
        impactLight.impactOccurred()

        // Bounce
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            tapScale = 1.25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                tapScale = 1.0
            }
        }

        // Show quip bubble
        bubbleText = tapQuips.randomElement() ?? "Hey!"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showBubble   = true
            bubbleOffset = CGSize(width: 0, height: -size * 0.9)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showBubble   = false
                bubbleOffset = CGSize(width: 0, height: -80)
            }
        }
    }

    private func handleDoubleTap() {
        guard !isDancing else { return }
        impactMedium.impactOccurred()
        isDancing = true

        // Dance: rapid alternating wiggle
        let steps = 6
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    danceOffset = i % 2 == 0 ? -12 : 12
                    tapRotation = i % 2 == 0 ? -12 : 12
                }
                impactLight.impactOccurred(intensity: 0.5)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(steps) * 0.12) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                danceOffset = 0
                tapRotation = 0
                isDancing   = false
            }
        }

        // Show bubble
        bubbleText = "Woohoo! 🎉"
        withAnimation { showBubble = true; bubbleOffset = CGSize(width: 0, height: -size * 0.9) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showBubble = false }
        }
    }

    private func handleLongPress() {
        guard !isPurring else { return }
        isPurring = true
        impactHeavy.impactOccurred()

        // Gentle pulse
        withAnimation(.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true)) {
            purseScale = 1.12
        }
        // Show bubble
        bubbleText = "Purring... 😊"
        withAnimation { showBubble = true; bubbleOffset = CGSize(width: 0, height: -size * 0.9) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring()) { purseScale = 1.0; isPurring = false }
            withAnimation { showBubble = false }
        }
    }

    private func handleSwipeUp() {
        impactMedium.impactOccurred()

        // Jump up
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            jumpOffset = -size * 0.6
            jumpScale  = 0.9
            squishY    = 0.8
            squishX    = 1.2
        }
        // Fall back with squish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                jumpOffset = 0
                jumpScale  = 1.1
                squishY    = 1.3
                squishX    = 0.8
            }
            impactMedium.impactOccurred()
        }
        // Recover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                jumpScale  = 1.0
                squishY    = 1.0
                squishX    = 1.0
            }
        }
    }
}

// MARK: - Speech Bubble

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                )

            // Tail
            Triangle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 14, height: 8)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground)
        InteractiveMochiView(state: .idle, size: 150)
    }
}

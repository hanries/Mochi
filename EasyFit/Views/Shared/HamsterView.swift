import SwiftUI

// MARK: - Hamster State

enum HamsterState {
    case idle
    case sleeping
    case happy
    case excited
    case sad
    case focused

    var imageName: String {
        switch self {
        case .idle:     return "hamster_idle"
        case .sleeping: return "hamster_sleeping"
        case .happy:    return "hamster_happy"
        case .excited:  return "hamster_excited"
        case .sad:      return "hamster_sad"
        case .focused:  return "hamster_focused"
        }
    }

    var glowColor: Color {
        switch self {
        case .idle:     return Color.yellow.opacity(0.3)
        case .sleeping: return Color.blue.opacity(0.15)
        case .happy:    return Color.yellow.opacity(0.4)
        case .excited:  return Color.orange.opacity(0.6)
        case .sad:      return Color.blue.opacity(0.2)
        case .focused:  return Color.yellow.opacity(0.5)
        }
    }

    var message: String {
        switch self {
        case .idle:     return "Ready when you are! 🌟"
        case .sleeping: return "Log something to wake me up... 💤"
        case .happy:    return "Great job logging! Keep it up 🐹"
        case .excited:  return "GOAL HIT! You're amazing! 🎉"
        case .sad:      return "Don't forget to log today... 🥺"
        case .focused:  return "So close to your goal! Push it! ⚡"
        }
    }
}

// MARK: - Hamster View

struct HamsterView: View {
    let state:    HamsterState
    let size:     CGFloat

    @State private var isFloating    = false
    @State private var isBreathing   = false
    @State private var isWiggling    = false
    @State private var isBouncingBig = false
    @State private var glowPulse     = false
    @State private var showMessage   = false
    @State private var zzzOffset:   CGFloat = 0
    @State private var zzzOpacity:  Double  = 0
    @State private var particlesTrigger = false

    init(state: HamsterState, size: CGFloat = 120) {
        self.state = state
        self.size  = size
    }

    var body: some View {
        ZStack {
            // Glow behind hamster
            Circle()
                .fill(state.glowColor)
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: 20)
                .scaleEffect(glowPulse ? 1.2 : 0.9)
                .animation(glowAnimation, value: glowPulse)

            // Particles for excited state
            if state == .excited {
                ParticlesView(trigger: particlesTrigger, size: size)
            }

            // Hamster image
            Image(state.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(scaleEffect)
                .offset(y: offsetY)
                .rotationEffect(.degrees(rotation))
                .animation(mainAnimation, value: state)

            // ZZZ for sleeping
            if state == .sleeping {
                Text("z z z")
                    .font(.system(size: size * 0.12, weight: .bold))
                    .foregroundStyle(.blue.opacity(0.6))
                    .offset(x: size * 0.3, y: -size * 0.3 + zzzOffset)
                    .opacity(zzzOpacity)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .onTapGesture { showMessage.toggle() }
        .popover(isPresented: $showMessage) {
            Text(state.message)
                .font(.system(size: 14, weight: .medium))
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in startAnimations() }
    }

    // MARK: - Computed animation values

    private var scaleEffect: CGFloat {
        switch state {
        case .idle:     return isBreathing ? 1.03 : 0.98
        case .sleeping: return isBreathing ? 1.02 : 0.97
        case .happy:    return isWiggling  ? 1.08 : 1.0
        case .excited:  return isBouncingBig ? 1.18 : 0.95
        case .sad:      return 0.88
        case .focused:  return isBreathing ? 1.05 : 1.0
        }
    }

    private var offsetY: CGFloat {
        switch state {
        case .idle:     return isFloating ? -5 : 5
        case .sleeping: return 4
        case .happy:    return isFloating ? -4 : 2
        case .excited:  return isBouncingBig ? -12 : 0
        case .sad:      return 8
        case .focused:  return isFloating ? -2 : 2
        }
    }

    private var rotation: Double {
        switch state {
        case .happy:    return isWiggling ? 6 : -6
        case .excited:  return isWiggling ? 8 : -8
        default:        return 0
        }
    }

    private var mainAnimation: Animation {
        switch state {
        case .excited: return .spring(response: 0.25, dampingFraction: 0.3)
        case .sad:     return .easeInOut(duration: 0.8)
        default:       return .spring(response: 0.4, dampingFraction: 0.6)
        }
    }

    private var glowAnimation: Animation {
        switch state {
        case .excited:  return .easeInOut(duration: 0.4).repeatForever(autoreverses: true)
        case .sleeping: return .easeInOut(duration: 4.0).repeatForever(autoreverses: true)
        default:        return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        }
    }

    // MARK: - Start animations based on state

    private func startAnimations() {
        // Reset
        isFloating    = false
        isBreathing   = false
        isWiggling    = false
        isBouncingBig = false
        glowPulse     = false
        zzzOpacity    = 0

        switch state {

        case .idle:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                isBreathing = true; glowPulse = true
            }

        case .sleeping:
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                isBreathing = true; glowPulse = true
            }
            // Floating zzz
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                zzzOffset  = -20
                zzzOpacity = 0.7
            }

        case .happy:
            // Entrance spring
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                isWiggling = true
            }
            // Then float
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3).repeatCount(4, autoreverses: true)) {
                    isWiggling = false
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isFloating = true; glowPulse = true
                }
            }

        case .excited:
            // Rapid bounce sequence
            withAnimation(.spring(response: 0.2, dampingFraction: 0.25).repeatCount(5, autoreverses: true)) {
                isBouncingBig = true
            }
            withAnimation(.easeInOut(duration: 0.15).repeatCount(8, autoreverses: true)) {
                isWiggling = true
            }
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            particlesTrigger.toggle()

        case .sad:
            withAnimation(.easeInOut(duration: 0.8)) {
                glowPulse = false
            }

        case .focused:
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isBreathing = true; glowPulse = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

// MARK: - Particle System (excited state)

private struct ParticlesView: View {
    let trigger: Bool
    let size:    CGFloat

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id    = UUID()
        var pos:  CGPoint
        var vel:  CGPoint
        var color: Color
        var scale: CGFloat = 1.0
        var opacity: Double = 1.0
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                for p in particles {
                    ctx.opacity = p.opacity
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: p.pos.x - 4 * p.scale,
                            y: p.pos.y - 4 * p.scale,
                            width: 8 * p.scale,
                            height: 8 * p.scale
                        )),
                        with: .color(p.color)
                    )
                }
            }
        }
        .frame(width: size * 2, height: size * 2)
        .onChange(of: trigger) { _, _ in emitParticles() }
        .onAppear { emitParticles() }
    }

    private func emitParticles() {
        let colors: [Color] = [.yellow, .orange, .white, Color(red: 1, green: 0.85, blue: 0)]
        let center = CGPoint(x: size, y: size)

        particles = (0..<16).map { _ in
            let angle  = Double.random(in: 0...(2 * .pi))
            let speed  = Double.random(in: 40...90)
            return Particle(
                pos:   center,
                vel:   CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                color: colors.randomElement()!,
                scale: CGFloat.random(in: 0.5...1.5)
            )
        }

        // Animate particles outward and fade
        withAnimation(.easeOut(duration: 0.8)) {
            for i in particles.indices {
                particles[i].pos = CGPoint(
                    x: center.x + particles[i].vel.x,
                    y: center.y + particles[i].vel.y
                )
                particles[i].opacity = 0
                particles[i].scale   = 0.2
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            VStack {
                HamsterView(state: .idle, size: 80)
                Text("Idle").font(.caption)
            }
            VStack {
                HamsterView(state: .happy, size: 80)
                Text("Happy").font(.caption)
            }
            VStack {
                HamsterView(state: .excited, size: 80)
                Text("Excited").font(.caption)
            }
        }
        HStack(spacing: 20) {
            VStack {
                HamsterView(state: .sleeping, size: 80)
                Text("Sleeping").font(.caption)
            }
            VStack {
                HamsterView(state: .sad, size: 80)
                Text("Sad").font(.caption)
            }
            VStack {
                HamsterView(state: .focused, size: 80)
                Text("Focused").font(.caption)
            }
        }
    }
    .padding()
}

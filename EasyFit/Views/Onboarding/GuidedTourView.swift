import SwiftUI

// MARK: - First-run, Mochi-led walkthrough
//
// Runs once after onboarding (gated by `hasSeenTour`, independent of the
// onboarding flag). Mochi himself leads the user through the real app: each
// step switches the live tab behind a light scrim while a big Mochi moves,
// swaps pose, and narrates from a speech bubble. On the last step he walks to
// his home rug spot and sits, then the overlay cross-fades onto the persistent
// home Mochi so it reads as one continuous character. Fully skippable; always
// leaves the user on Home. Voice is engagement-only — never about amounts.

struct GuidedTourView: View {
    @Binding var selectedTab: AppState.Tab
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private let motion = MochiMotion.default

    private struct Step {
        let tab: AppState.Tab
        let line: String
        let pose: MochiAssetProvider.Pose
    }

    private let steps: [Step] = [
        .init(tab: .home,
              line: "Hi, I'm Mochi! 🐹 Let me show you around my home.",
              pose: .wave),
        .init(tab: .home,
              line: "Tap “Feed Mochi · log a meal” to snap or search what you eat. Every log makes me happy — I only care that you showed up, never what or how much you ate.",
              pose: .point),
        .init(tab: .log,
              line: "Your streak and progress live here in the Log tab. Keep showing up and watch them grow!",
              pose: .talk),
        .init(tab: .workout,
              line: "Planning workouts? Set your training days in the Workout tab whenever you're ready.",
              pose: .talk),
        .init(tab: .profile,
              line: "Your targets, units, and reminders are here in Profile. That's the tour — let's get logging together!",
              pose: .talk),
    ]

    private var isLast: Bool { index == steps.count - 1 }
    private var current: Step { steps[index] }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let topInset = geo.safeAreaInsets.top

            // Mochi sits low on the LEFT with his bubble to the right. The
            // ending is a plain cross-fade of this whole overlay onto the
            // home Mochi (no travel/sit — the two live in different coordinate
            // spaces, so any computed "glide" would mismatch and jump).
            let mochiSize = w * 0.38
            let mochiCenter = CGPoint(x: w * 0.24, y: h * 0.6)
            let bubbleWidth = w * 0.52
            let bubbleCenter = CGPoint(
                x: w - MochiTheme.Spacing.lg - bubbleWidth / 2,
                y: max(topInset + 120, h * 0.46)
            )

            ZStack(alignment: .top) {
                // Light scrim so the real tab shows "in context".
                MochiTheme.textPrimary.opacity(0.25)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }   // swallow taps to the app behind

                // Skip — available on every step.
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(MochiTheme.surfaceAlt)
                        .padding(MochiTheme.Spacing.lg)
                }

                // Mochi's speech bubble, sitting to his right.
                bubble
                    .frame(width: bubbleWidth)
                    .position(bubbleCenter)
                    .id(index)               // cross-fade per step
                    .transition(.opacity)

                // The guide himself — posed, grounded by his shadow.
                MochiView(state: .happy,
                          size: mochiSize,
                          showShadow: true,
                          pose: current.pose)
                    .position(mochiCenter)
                    .accessibilityHidden(true)
            }
        }
        .onAppear { go(to: 0) }
    }

    // MARK: - Bubble (text + dots + Next)

    private var bubble: some View {
        VStack(alignment: .leading, spacing: MochiTheme.Spacing.lg) {
            Text(current.line)
                .font(MochiTheme.body)
                .foregroundStyle(MochiTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? MochiTheme.primary : MochiTheme.textSecondary.opacity(0.3))
                            .frame(width: i == index ? 18 : 6, height: 6)
                    }
                }
                Spacer()
                Button { advance() } label: {
                    Text(isLast ? "Let's go" : "Next")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(MochiTheme.surfaceAlt)
                        .padding(.horizontal, MochiTheme.Spacing.xl)
                        .padding(.vertical, MochiTheme.Spacing.md)
                        .background(MochiTheme.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(MochiTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: MochiTheme.cardRadius)
                .fill(MochiTheme.surfaceAlt)
        )
        .shadow(color: MochiTheme.textPrimary.opacity(0.18), radius: 18, x: 0, y: 8)
    }

    // MARK: - Flow

    private func advance() {
        if isLast { finish() } else { go(to: index + 1) }
    }

    /// Move to a step and bring its tab forward so Mochi narrates the real
    /// screen. One spring drives both his walk and the tab cross-fade.
    private func go(to newIndex: Int) {
        let apply = {
            index = newIndex
            selectedTab = steps[newIndex].tab
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.spring(response: motion.tourMoveResponse,
                                  dampingFraction: motion.tourMoveDamping)) {
                apply()
            }
        }
    }

    /// End the tour (finish or skip) — switch to Home, then `onFinish`
    /// cross-fades this overlay away onto the persistent home Mochi.
    private func finish() {
        selectedTab = .home
        onFinish()
    }
}

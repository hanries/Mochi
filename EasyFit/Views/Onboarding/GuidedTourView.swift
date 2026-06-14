import SwiftUI

// MARK: - First-run, Mochi-led walkthrough
//
// Runs once after onboarding (gated by `hasSeenTour`, independent of the
// onboarding flag). Instead of static cards, Mochi actually walks the user
// through the real app: each step switches the live tab behind a soft warm
// scrim while Mochi narrates from a speech bubble. Fully skippable; marked
// seen whether finished or skipped. Voice is engagement-only — never about
// calories or amounts.

struct GuidedTourView: View {
    @Binding var selectedTab: AppState.Tab
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private struct Step {
        let tab: AppState.Tab
        let line: String
    }

    // Mochi's expression for the tour — warm and welcoming. Swap to a
    // dedicated `mochi_greeting` (waving) asset here once it exists.
    private let mochiState: MochiState = .happy

    private let steps: [Step] = [
        .init(tab: .home,
              line: "Hi, I'm Mochi! 🐹 Let me show you around my home."),
        .init(tab: .home,
              line: "Tap “Feed Mochi · log a meal” to snap or search what you eat. Every log makes me happy — I only care that you showed up, never what or how much you ate."),
        .init(tab: .log,
              line: "Your streak and progress live here in the Log tab. Keep showing up and watch them grow!"),
        .init(tab: .workout,
              line: "Planning workouts? Set your training days in the Workout tab whenever you're ready."),
        .init(tab: .profile,
              line: "Your targets, units, and reminders are here in Profile. That's the tour — let's get logging together!"),
    ]

    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        ZStack {
            // Soft warm scrim — the real tab stays visible underneath.
            MochiTheme.textPrimary.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }   // swallow taps to the app behind

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(MochiTheme.surfaceAlt)
                        .padding(MochiTheme.Spacing.lg)
                }

                Spacer()

                guideCard
                    .padding(.horizontal, MochiTheme.Spacing.lg)
                    .padding(.bottom, 96)   // keep the live tab bar peeking below
            }
        }
        .onAppear { go(to: 0) }
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: MochiTheme.Spacing.lg) {
            HStack(alignment: .bottom, spacing: MochiTheme.Spacing.md) {
                MochiView(state: mochiState, size: 84)
                    .accessibilityHidden(true)

                Text(steps[index].line)
                    .font(MochiTheme.body)
                    .foregroundStyle(MochiTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(MochiTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MochiTheme.surface)
                    )
                    .id(index)   // crossfade the line per step
                    .transition(.opacity)
            }

            HStack {
                // Page dots
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

    private func advance() {
        if isLast { finish() } else { go(to: index + 1) }
    }

    /// Move to a step and bring its tab forward so Mochi narrates the real screen.
    private func go(to newIndex: Int) {
        let apply = {
            index = newIndex
            selectedTab = steps[newIndex].tab
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.easeInOut(duration: MochiMotion.default.tabContentResponse)) {
                apply()
            }
        }
    }

    private func finish() { onFinish() }
}

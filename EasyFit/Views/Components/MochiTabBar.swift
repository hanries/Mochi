import SwiftUI

// MARK: - Custom bottom tab bar
//
// Replaces the system tab bar so we can animate selection: a sliding pill
// indicator behind the active item and a quick spring-bounce on the tapped
// icon. Styled with MochiTheme; respects Reduce Motion (no bounce, indicator
// jumps instantly). The content cross-fade/slide lives in ContentView.

struct MochiTabBar: View {
    @Binding var selected: AppState.Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicatorNS
    @State private var bouncing: AppState.Tab? = nil

    private let motion = MochiMotion.default

    private struct Item {
        let tab: AppState.Tab
        let icon: String
        let label: String
    }

    private let items: [Item] = [
        .init(tab: .home,    icon: "pawprint.fill",       label: "Home"),
        .init(tab: .log,     icon: "chart.bar.fill",      label: "Log"),
        .init(tab: .workout, icon: "dumbbell",            label: "Workout"),
        .init(tab: .profile, icon: "person.crop.circle",  label: "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                let isSelected = selected == item.tab
                Button {
                    bounce(item.tab)
                    if reduceMotion {
                        selected = item.tab
                    } else {
                        // Ease (no spring overshoot) so the pill + content
                        // cross-fade settle calmly rather than wobbling.
                        withAnimation(.easeInOut(duration: motion.tabContentResponse)) {
                            selected = item.tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(height: 22)
                            .scaleEffect(bouncing == item.tab ? motion.tabIconBounceScale : 1.0)
                        Text(item.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? MochiTheme.primary : MochiTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(MochiTheme.primary.opacity(0.12))
                                .matchedGeometryEffect(id: "tabIndicator", in: indicatorNS)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, MochiTheme.Spacing.md)
        .padding(.top, MochiTheme.Spacing.sm)
        .background(
            MochiTheme.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MochiTheme.textSecondary.opacity(0.12))
                        .frame(height: 0.5)
                }
        )
    }

    private func bounce(_ tab: AppState.Tab) {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: motion.tabIconBounceResponse,
                              dampingFraction: motion.tabIconBounceDamping)) {
            bouncing = tab
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: motion.tabIconBounceResponse,
                                  dampingFraction: motion.tabIconBounceDamping)) {
                bouncing = nil
            }
        }
    }
}

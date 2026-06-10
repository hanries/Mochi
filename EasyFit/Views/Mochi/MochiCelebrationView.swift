import SwiftUI

// MARK: - Brief Mochi celebration after a successful food log
//
// Hosted in ContentView's ZStack so it plays over the home screen once
// any presenting sheets are dismissed. Auto-dismisses; tap to skip.

struct MochiCelebrationView: View {
    let event: CelebrationEvent
    let state: MochiState
    let duration: TimeInterval
    let onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDone() }

            VStack(spacing: 18) {
                MochiAssetProvider.mochiView(for: state, size: 140)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .rotationEffect(.degrees(appeared ? 0 : -12))

                Text(event.line)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)
        }
        .task(id: event.id) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                appeared = true
            }
            try? await Task.sleep(for: .seconds(duration))
            onDone()
        }
    }
}

#Preview {
    MochiCelebrationView(
        event: CelebrationEvent(line: "Yay! Logged it!"),
        state: .happy,
        duration: 60,
        onDone: {}
    )
    .preferredColorScheme(.dark)
}

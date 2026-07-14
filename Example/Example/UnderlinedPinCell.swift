import CBPinEntryView
import SwiftUI

struct UnderlinedPinCell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: PinEntryCellState
    @State private var shakeTrigger: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            Text(state.character ?? "")
                .font(.title2.monospaced())
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(underlineColor)
                .frame(height: state.isFocused ? 3 : 1.5)
        }
        .modifier(ShakeEffect(animatableData: shakeTrigger))
        .onChange(of: state.isError) { _, isError in
            guard isError, !reduceMotion else { return }
            withAnimation(.default) {
                shakeTrigger += 1
            }
        }
    }

    private var underlineColor: Color {
        if state.isError { return .red }
        if state.isFocused { return .accentColor }
        return .secondary
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 6 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

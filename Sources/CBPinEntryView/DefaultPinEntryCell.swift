import SwiftUI

public struct DefaultPinEntryCell: View {
    let state: PinEntryCellState
    var backgroundColor: Color
    var filledBackgroundColor: Color
    var editingBackgroundColor: Color
    var textColor: Color
    var defaultBorderColor: Color
    var editingBorderColor: Color
    var errorBorderColor: Color
    var cornerRadius: CGFloat
    var borderWidth: CGFloat
    var font: Font

    @ScaledMetric(relativeTo: .title2) private var minimumHeight: CGFloat = 44

    public init(
        state: PinEntryCellState,
        backgroundColor: Color = Color(.secondarySystemBackground),
        filledBackgroundColor: Color = Color(.secondarySystemBackground),
        editingBackgroundColor: Color = Color(.tertiarySystemBackground),
        textColor: Color = Color(.label),
        defaultBorderColor: Color = Color(.separator),
        editingBorderColor: Color = Color.accentColor,
        errorBorderColor: Color = Color(.systemRed),
        cornerRadius: CGFloat = 8,
        borderWidth: CGFloat = 1,
        font: Font = .title2.monospaced()
    ) {
        self.state = state
        self.backgroundColor = backgroundColor
        self.filledBackgroundColor = filledBackgroundColor
        self.editingBackgroundColor = editingBackgroundColor
        self.textColor = textColor
        self.defaultBorderColor = defaultBorderColor
        self.editingBorderColor = editingBorderColor
        self.errorBorderColor = errorBorderColor
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.font = font
    }

    public var body: some View {
        Text(state.character ?? "")
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(currentBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(currentBorderColor, lineWidth: currentBorderWidth)
            )
    }

    private var currentBackgroundColor: Color {
        if state.isFocused { return editingBackgroundColor }
        if state.isFilled { return filledBackgroundColor }
        return backgroundColor
    }

    private var currentBorderColor: Color {
        if state.isError { return errorBorderColor }
        if state.isFocused { return editingBorderColor }
        return defaultBorderColor
    }

    private var currentBorderWidth: CGFloat {
        state.isError || state.isFocused ? borderWidth * 2 : borderWidth
    }
}

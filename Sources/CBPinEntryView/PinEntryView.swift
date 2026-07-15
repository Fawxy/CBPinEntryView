import SwiftUI
import UIKit

public struct PinEntryView<CellContent: View>: View {
    private var pin: Binding<String>
    private var length: Int
    private var spacing: CGFloat
    private var isErrorBinding: Binding<Bool>
    private var accessibilityLabelText: String?
    private var onComplete: ((String) -> Void)?
    private var cell: (PinEntryCellState) -> CellContent

    private var allowedEntry: AllowedEntryType = .numerical
    private var isSecure: Bool = false
    private var secureCharacter: String = "●"
    private var keyboardType: UIKeyboardType = .numberPad
    private var textContentType: UITextContentType? = .oneTimeCode
    private var textInputAutocapitalization: TextInputAutocapitalization = .never
    private var hapticEvents: PinEntryHapticEvents = .default
    private var externalFocus: FocusState<Bool>.Binding?
    private var isPasteEnabled: Bool = true

    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44
    @State private var haptics = PinEntryHaptics()
    @State private var isPasteConfirmationPresented = false

    // Reconciliation state for the invisible field. `rawText` mirrors the field's
    // own text; `pin` is the public source of truth. `previousPin` tracks whether
    // the last change crossed the completion threshold, and `isSyncingFromPin`
    // suppresses the echo when a programmatic `pin` change is pushed into `rawText`.
    @State private var previousPin: String = ""
    @State private var rawText: String = ""
    @State private var isSyncingFromPin = false

    public init(
        pin: Binding<String>,
        length: Int = 4,
        spacing: CGFloat = 10,
        isError: Binding<Bool> = .constant(false),
        accessibilityLabel: String? = nil,
        onComplete: ((String) -> Void)? = nil,
        @ViewBuilder cell: @escaping (PinEntryCellState) -> CellContent
    ) {
        self.pin = pin
        self.length = length
        self.spacing = spacing
        self.isErrorBinding = isError
        self.accessibilityLabelText = accessibilityLabel
        self.onComplete = onComplete
        self.cell = cell
    }

    private var isError: Bool { isErrorBinding.wrappedValue }

    private var effectiveFocusBinding: FocusState<Bool>.Binding {
        externalFocus ?? $internalFocus
    }

    public var body: some View {
        let displayString = isSecure ? PinEntryReducer.maskedDisplay(pin.wrappedValue, secureCharacter: secureCharacter) : pin.wrappedValue
        let visibleCharacters = Array(displayString.prefix(length))
        let isFocused = effectiveFocusBinding.wrappedValue

        ZStack {
            inputField
            ViewThatFits(in: .horizontal) {
                equalWidthCellRow(visibleCharacters: visibleCharacters, isFocused: isFocused)
                scrollingCellRow(visibleCharacters: visibleCharacters, isFocused: isFocused)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
        .onLongPressGesture { attemptPaste() }
        .onAppear {
            previousPin = pin.wrappedValue
            if pin.wrappedValue != rawText {
                isSyncingFromPin = true
            }
            rawText = pin.wrappedValue
        }
        .onChange(of: rawText) { userDidEdit(to: $0) }
        .onChange(of: pin.wrappedValue) { pinDidChangeExternally(to: $0) }
        .onChange(of: isError) { newValue in
            if newValue {
                haptics.fireError(for: hapticEvents)
            }
        }
        .task {
            haptics.prepare(for: hapticEvents)
        }
        .confirmationDialog("", isPresented: $isPasteConfirmationPresented, titleVisibility: .hidden) {
            Button("Paste") { performPaste() }
        }
    }

    private func userDidEdit(to newValue: String) {
        // A programmatic `pin` change we pushed into `rawText` echoes back here.
        // Let it pass through untouched (see CLAUDE.md — programmatic assignment
        // is never sanitised or stripped); only genuine user edits are reduced.
        if isSyncingFromPin {
            isSyncingFromPin = false
            return
        }
        let reduced = PinEntryReducer.reduce(newValue, length: length, allowedEntry: allowedEntry)
        if reduced != rawText {
            rawText = reduced
        }
        if reduced != pin.wrappedValue {
            pin.wrappedValue = reduced
        }
    }

    private func pinDidChangeExternally(to newValue: String) {
        if PinEntryReducer.didComplete(from: previousPin, to: newValue, length: length) {
            haptics.fireCompletion(for: hapticEvents)
            onComplete?(newValue)
        } else {
            haptics.fireEntry(for: hapticEvents)
        }
        previousPin = newValue
        if newValue != rawText {
            isSyncingFromPin = true
            rawText = newValue
        }
    }

    private func attemptPaste() {
        guard isPasteEnabled, UIPasteboard.general.hasStrings else { return }
        isPasteConfirmationPresented = true
    }

    private func performPaste() {
        guard let pasted = UIPasteboard.general.string else { return }
        rawText += pasted
        effectiveFocusBinding.wrappedValue = true
    }

    private func equalWidthCellRow(visibleCharacters: [Character], isFocused: Bool) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<length, id: \.self) { index in
                cell(cellState(at: index, visibleCharacters: visibleCharacters, isFocused: isFocused))
                    .frame(minWidth: minimumCellWidth, maxWidth: .infinity, minHeight: minimumCellWidth)
            }
        }
    }

    private func scrollingCellRow(visibleCharacters: [Character], isFocused: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(0..<length, id: \.self) { index in
                        cell(cellState(at: index, visibleCharacters: visibleCharacters, isFocused: isFocused))
                            .frame(minWidth: minimumCellWidth, minHeight: minimumCellWidth)
                            .id(index)
                    }
                }
            }
            .onChange(of: pin.wrappedValue) { _ in
                withAnimation {
                    proxy.scrollTo(activeIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if isPasteEnabled {
            baseInputField.accessibilityAction(named: Text("Paste")) { attemptPaste() }
        } else {
            baseInputField
        }
    }

    private var baseInputField: some View {
        Group {
            if isSecure {
                SecureField("", text: $rawText)
            } else {
                TextField("", text: $rawText)
            }
        }
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(textInputAutocapitalization)
        .focused(effectiveFocusBinding)
        .foregroundStyle(.clear)
        .tint(.clear)
        .allowsHitTesting(false)
        .accessibilityLabel(accessibilityLabelText ?? String(localized: "PIN code"))
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(String(localized: "Enter your \(length)-digit code."))
    }

    private var accessibilityValueText: String {
        let count = min(pin.wrappedValue.count, length)
        let progress: String
        if count == 0 {
            progress = String(localized: "Empty, 0 of \(length) entered")
        } else if PinEntryReducer.isComplete(pin.wrappedValue, length: length) {
            progress = String(localized: "Complete, \(length) of \(length) entered")
        } else {
            progress = String(localized: "\(count) of \(length) entered")
        }
        return isError ? progress + ", " + String(localized: "error") : progress
    }

    private var activeIndex: Int {
        min(pin.wrappedValue.count, length - 1)
    }

    private func cellState(at index: Int, visibleCharacters: [Character], isFocused: Bool) -> PinEntryCellState {
        PinEntryCellState(
            character: index < visibleCharacters.count ? String(visibleCharacters[index]) : nil,
            index: index,
            isFocused: isFocused && index == activeIndex,
            isFilled: index < visibleCharacters.count,
            isError: isError
        )
    }
}

extension PinEntryView where CellContent == DefaultPinEntryCell {
    public init(
        pin: Binding<String>,
        length: Int = 4,
        spacing: CGFloat = 10,
        isError: Binding<Bool> = .constant(false),
        accessibilityLabel: String? = nil,
        onComplete: ((String) -> Void)? = nil
    ) {
        self.init(
            pin: pin,
            length: length,
            spacing: spacing,
            isError: isError,
            accessibilityLabel: accessibilityLabel,
            onComplete: onComplete,
            cell: { state in DefaultPinEntryCell(state: state) }
        )
    }
}

extension PinEntryView {
    public func pinAllowedEntry(_ type: AllowedEntryType) -> Self {
        var copy = self
        copy.allowedEntry = type
        return copy
    }

    public func pinSecure(_ isSecure: Bool = true, character: String = "●") -> Self {
        var copy = self
        copy.isSecure = isSecure
        copy.secureCharacter = character
        return copy
    }

    public func pinKeyboardType(_ type: UIKeyboardType) -> Self {
        var copy = self
        copy.keyboardType = type
        return copy
    }

    public func pinTextContentType(_ type: UITextContentType?) -> Self {
        var copy = self
        copy.textContentType = type
        return copy
    }

    public func pinTextInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization) -> Self {
        var copy = self
        copy.textInputAutocapitalization = autocapitalization
        return copy
    }

    public func pinHaptics(_ events: PinEntryHapticEvents) -> Self {
        var copy = self
        copy.hapticEvents = events
        return copy
    }

    public func pinFocused(_ binding: FocusState<Bool>.Binding) -> Self {
        var copy = self
        copy.externalFocus = binding
        return copy
    }

    public func pinPasteEnabled(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.isPasteEnabled = enabled
        return copy
    }
}

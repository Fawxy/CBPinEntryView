# CBPinEntryView SwiftUI Modernisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite CBPinEntryView from a UIKit `@IBDesignable` view into a SwiftUI-only `PinEntryView` (breaking 2.0), fix the broken repo (delete divergent/dead source trees), ship SPM-only, and add first-class accessibility, tests, an example app, CI, and migration docs.

**Architecture:** A single invisible-but-focusable `TextField`/`SecureField` is the source of truth for a `Binding<String>`; a row of cells is drawn as an overlay from the current string via a `@ViewBuilder` closure. All non-trivial logic (sanitise, truncate, completion detection, secure masking) lives in a pure, unit-tested `PinEntryReducer` enum with no SwiftUI dependency. Configuration is applied via `pin`-prefixed builder-style modifiers, not environment/standard SwiftUI modifiers (see rationale in Design doc). No `@Observable` in the control — it belongs in the consumer's feature model, demonstrated in the example app.

**Tech Stack:** Swift 5.9, SwiftUI, Swift Testing (`@Test`/`@Suite`), Swift Package Manager. Zero external dependencies. The `xcodeproj` Ruby gem is used once, locally, as a scaffolding tool to generate the Example app's `.xcodeproj` — it is not a project or repo dependency.

## Global Constraints

- Minimum iOS for the library: **16.0**. Minimum iOS for the Example app only: **17.0** (needed for the `@Observable` feature-model screen).
- `swift-tools-version: 5.9`, `platforms: [.iOS(.v16)]`, zero external dependencies — SPM only, no CocoaPods, no Carthage.
- No UIKit compatibility shim. The only public view is `PinEntryView` under `import CBPinEntryView`.
- No snapshot tests. Swift Testing (`@Test`/`@Suite`) for pure-logic unit tests only — no tests for trivial property assignment, SwiftUI view rendering, or stdlib-guaranteed behaviour.
- Never freeze a SwiftUI `Color` to `CGColor`/`UIColor`.
- The invisible input field must stay full-alpha and laid out within the component's bounds — never `.hidden()`, `.opacity(0)`, zero-framed, or off-screen.
- `.pin`-prefixed modifiers own field configuration; standard SwiftUI text modifiers (`.keyboardType`, `.textContentType`, `.textInputAutocapitalization`) applied outside `PinEntryView` do **not** reach the internal field.
- `isSecure` is fixed per instance, chosen once at view creation — never toggled dynamically.
- The library reads `isError` but never writes it, and never clears the field on error or completion. That policy belongs to the consumer.

---

## File Structure

```
Package.swift                                    — rewritten: 5.9, iOS 16, lib + test target, zero deps
Sources/CBPinEntryView/
  AllowedEntryType.swift                          — public enum + sanitize(_:)
  PinEntryReducer.swift                           — internal pure logic: reduce, isComplete, didComplete, maskedDisplay
  PinEntryCellState.swift                         — public plain data struct passed to the cell closure
  PinEntryHaptics.swift                           — PinEntryHapticEvents (public OptionSet) + PinEntryHaptics (internal wrapper)
  DefaultPinEntryCell.swift                       — public default cell View
  PinEntryView.swift                              — public PinEntryView<CellContent>, its two inits, pin-prefixed modifiers, sanitising Binding extension
Tests/CBPinEntryViewTests/
  AllowedEntryTypeTests.swift
  PinEntryReducerTests.swift
Example/
  Example.xcodeproj                               — generated via the xcodeproj gem, local package dependency on ".."
  Example/
    ExampleApp.swift
    ContentView.swift                             — main demo screen: length, secure, error, allowed-type, clear, focus
    UnderlinedPinCell.swift                        — custom cell closure recipe (shake-on-error, honours Reduce Motion)
    ObservablePinScreen.swift                      — @Observable feature-model screen
    HostingControllerInteropScreen.swift           — UIHostingController interop screen
    Assets.xcassets
.github/workflows/ci.yml                          — library (iOS 16) + example (iOS 17) jobs
MIGRATION.md                                       — 1.x → 2.0 API mapping
README.md                                          — rewritten, SPM-only
CLAUDE.md                                          — new, repo root

Deleted:
CBPinEntryView/ (Classes/, Assets/)
Sources/CBPinEntryView/{CBPinEntryView,CBPinEntryViewDefaults,Extensions}.swift
CBPinEntryView.podspec
.travis.yml
_Pods.xcodeproj (root symlink)
Example/ (entire old CocoaPods/storyboard/UIKit content, incl. Pods/)
```

**Note on task granularity for `PinEntryView.swift`:** this file is large but ships no automated view tests (per Global Constraints — manual verification only, see Task 15), so its task is broken into build-verified steps (`swift build` after each) rather than red/green test steps.

---

### Task 1: Repo cleanup, Package.swift rewrite, `AllowedEntryType`

**Files:**
- Delete: `CBPinEntryView/` (Classes/, Assets/), `Sources/CBPinEntryView/CBPinEntryView.swift`, `Sources/CBPinEntryView/CBPinEntryViewDefaults.swift`, `Sources/CBPinEntryView/Extensions.swift`, `CBPinEntryView.podspec`, `.travis.yml`, `_Pods.xcodeproj`, `Example/` (entire old contents)
- Modify: `Package.swift`
- Create: `Sources/CBPinEntryView/AllowedEntryType.swift`
- Test: `Tests/CBPinEntryViewTests/AllowedEntryTypeTests.swift`

**Interfaces:**
- Produces: `AllowedEntryType` public enum with cases `.any`, `.numerical`, `.alphanumeric`, `.letters`, and `public func sanitize(_ input: String) -> String`. Later tasks (`PinEntryReducer`, `PinEntryView`) depend on this exact signature.

- [ ] **Step 1: Delete the dead/divergent source trees and legacy packaging**

```bash
git rm -r CBPinEntryView
git rm Sources/CBPinEntryView/CBPinEntryView.swift Sources/CBPinEntryView/CBPinEntryViewDefaults.swift Sources/CBPinEntryView/Extensions.swift
git rm CBPinEntryView.podspec .travis.yml _Pods.xcodeproj
git rm -r Example
```

- [ ] **Step 2: Rewrite `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CBPinEntryView",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "CBPinEntryView", targets: ["CBPinEntryView"])
    ],
    targets: [
        .target(name: "CBPinEntryView"),
        .testTarget(name: "CBPinEntryViewTests", dependencies: ["CBPinEntryView"])
    ]
)
```

- [ ] **Step 3: Write `Sources/CBPinEntryView/AllowedEntryType.swift`**

```swift
import Foundation

public enum AllowedEntryType: String, Hashable, Sendable {
    case any
    case numerical
    case alphanumeric
    case letters

    public func sanitize(_ input: String) -> String {
        switch self {
        case .any:
            return input
        case .numerical:
            return input.filter { $0.isNumber }
        case .alphanumeric:
            return input.filter { $0.isLetter || $0.isNumber }
        case .letters:
            return input.filter { $0.isLetter }
        }
    }
}
```

- [ ] **Step 4: Write the failing-then-passing test, `Tests/CBPinEntryViewTests/AllowedEntryTypeTests.swift`**

```swift
import Testing
@testable import CBPinEntryView

@Suite("AllowedEntryType")
struct AllowedEntryTypeTests {
    @Test("numerical strips non-digit characters")
    func numericalStripsLetters() {
        #expect(AllowedEntryType.numerical.sanitize("1a2b3c") == "123")
    }

    @Test("letters strips digits")
    func lettersStripsDigits() {
        #expect(AllowedEntryType.letters.sanitize("1a2b3c") == "abc")
    }

    @Test("alphanumeric strips symbols")
    func alphanumericStripsSymbols() {
        #expect(AllowedEntryType.alphanumeric.sanitize("a1-b2_c3!") == "a1b2c3")
    }

    @Test("any passes input through unchanged")
    func anyPassesThrough() {
        #expect(AllowedEntryType.any.sanitize("a1-b2_c3!") == "a1-b2_c3!")
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `swift test`
Expected: `Test run with 4 tests in 1 suite passed`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Delete legacy UIKit sources and CocoaPods packaging; add AllowedEntryType"
```

---

### Task 2: `PinEntryReducer` — pure logic core

**Files:**
- Create: `Sources/CBPinEntryView/PinEntryReducer.swift`
- Test: `Tests/CBPinEntryViewTests/PinEntryReducerTests.swift`

**Interfaces:**
- Consumes: `AllowedEntryType.sanitize(_:)` from Task 1.
- Produces: `enum PinEntryReducer` (internal) with `reduce(_:length:allowedEntry:) -> String`, `isComplete(_:length:) -> Bool`, `didComplete(from:to:length:) -> Bool`, `maskedDisplay(_:secureCharacter:) -> String`. `PinEntryView` (Task 6) calls all four.

- [ ] **Step 1: Write the failing tests, `Tests/CBPinEntryViewTests/PinEntryReducerTests.swift`**

```swift
import Testing
@testable import CBPinEntryView

@Suite("PinEntryReducer")
struct PinEntryReducerTests {
    @Test("sanitises before truncating so stray characters don't consume length")
    func sanitiseBeforeTruncate() {
        #expect(PinEntryReducer.reduce("12-34-56", length: 6, allowedEntry: .numerical) == "123456")
    }

    @Test("caps an over-length paste to the leading length characters")
    func capsOverLengthPaste() {
        #expect(PinEntryReducer.reduce("123456789", length: 4, allowedEntry: .numerical) == "1234")
    }

    @Test("preserves existing leading digits when appending mid-entry")
    func preservesLeadingDigitsMidEntry() {
        #expect(PinEntryReducer.reduce("123456", length: 4, allowedEntry: .numerical) == "1234")
    }

    @Test("isComplete is true at or beyond length")
    func isCompleteAtLength() {
        #expect(PinEntryReducer.isComplete("1234", length: 4))
        #expect(!PinEntryReducer.isComplete("123", length: 4))
    }

    @Test("didComplete fires transitioning from below length to exactly length")
    func didCompleteOnTransition() {
        #expect(PinEntryReducer.didComplete(from: "123", to: "1234", length: 4))
    }

    @Test("didComplete does not refire on a no-op keystroke into a full field")
    func didCompleteNoRefireOnNoOp() {
        #expect(!PinEntryReducer.didComplete(from: "1234", to: "1234", length: 4))
    }

    @Test("didComplete fires again after delete-below-then-refill")
    func didCompleteRefiresAfterDeleteAndRefill() {
        #expect(!PinEntryReducer.didComplete(from: "1234", to: "123", length: 4))
        #expect(PinEntryReducer.didComplete(from: "123", to: "1234", length: 4))
    }

    @Test("didComplete fires once for a programmatic full-value assignment beyond length")
    func didCompleteFiresForProgrammaticAssignment() {
        #expect(PinEntryReducer.didComplete(from: "12", to: "999999", length: 4))
    }

    @Test("maskedDisplay yields one mask character per entered digit, raw pin unaffected")
    func maskedDisplayYieldsMaskPerCharacter() {
        let pin = "1234"
        let masked = PinEntryReducer.maskedDisplay(pin, secureCharacter: "●")
        #expect(masked == "●●●●")
        #expect(pin == "1234")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail to compile (no `PinEntryReducer` yet)**

Run: `swift test`
Expected: FAIL with "cannot find 'PinEntryReducer' in scope"

- [ ] **Step 3: Write `Sources/CBPinEntryView/PinEntryReducer.swift`**

```swift
import Foundation

enum PinEntryReducer {
    static func reduce(_ input: String, length: Int, allowedEntry: AllowedEntryType) -> String {
        let sanitized = allowedEntry.sanitize(input)
        return String(sanitized.prefix(length))
    }

    static func isComplete(_ pin: String, length: Int) -> Bool {
        pin.count >= length
    }

    static func didComplete(from oldValue: String, to newValue: String, length: Int) -> Bool {
        oldValue.count < length && newValue.count >= length
    }

    static func maskedDisplay(_ pin: String, secureCharacter: String) -> String {
        String(repeating: secureCharacter, count: pin.count)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: `Test run with 13 tests in 2 suites passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryReducer.swift Tests/CBPinEntryViewTests/PinEntryReducerTests.swift
git commit -m "Add PinEntryReducer: pure sanitise/truncate/completion logic"
```

---

### Task 3: `PinEntryCellState`

**Files:**
- Create: `Sources/CBPinEntryView/PinEntryCellState.swift`

**Interfaces:**
- Produces: `public struct PinEntryCellState: Equatable, Sendable` with `character: String?`, `index: Int`, `isFocused: Bool`, `isFilled: Bool`, `isError: Bool`. This is the exact type `DefaultPinEntryCell` (Task 5) and `PinEntryView`'s `cell` closure parameter (Task 6) use.

No test file: this is a plain data struct with a compiler-synthesised memberwise initialiser — a test would only assert Swift's own assignment semantics, which the project's testing guidance excludes.

- [ ] **Step 1: Write the file**

```swift
import Foundation

public struct PinEntryCellState: Equatable, Sendable {
    public let character: String?
    public let index: Int
    public let isFocused: Bool
    public let isFilled: Bool
    public let isError: Bool
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryCellState.swift
git commit -m "Add PinEntryCellState, the cell closure's customisation point"
```

---

### Task 4: `PinEntryHaptics`

**Files:**
- Create: `Sources/CBPinEntryView/PinEntryHaptics.swift`

**Interfaces:**
- Produces: `public struct PinEntryHapticEvents: OptionSet, Sendable` (`.entry`, `.completion`, `.error`, `` .`default` `` = `[.completion, .error]`, `.all`), and internal `struct PinEntryHaptics` with `prepare(for:)`, `fireEntry(enabled:)`, `fireCompletion(enabled:)`, `fireError(enabled:)`. `PinEntryView` (Task 6) stores a `PinEntryHaptics` in `@State` and calls all four methods; the public `.pinHaptics(_:)` modifier takes a `PinEntryHapticEvents`.

No test file: `UIFeedbackGenerator` is a hardware/simulator side effect with no return value to assert against — there is no business logic here to unit test, only framework calls gated by a simple flag check, which `swift build` plus the manual haptics check in Task 15 covers.

- [ ] **Step 1: Write the file**

```swift
import UIKit

public struct PinEntryHapticEvents: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let entry = PinEntryHapticEvents(rawValue: 1 << 0)
    public static let completion = PinEntryHapticEvents(rawValue: 1 << 1)
    public static let error = PinEntryHapticEvents(rawValue: 1 << 2)

    public static let `default`: PinEntryHapticEvents = [.completion, .error]
    public static let all: PinEntryHapticEvents = [.entry, .completion, .error]
}

struct PinEntryHaptics {
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare(for events: PinEntryHapticEvents) {
        if events.contains(.entry) {
            selectionGenerator.prepare()
        }
        if events.contains(.completion) || events.contains(.error) {
            notificationGenerator.prepare()
        }
    }

    func fireEntry(enabled events: PinEntryHapticEvents) {
        guard events.contains(.entry) else { return }
        selectionGenerator.selectionChanged()
    }

    func fireCompletion(enabled events: PinEntryHapticEvents) {
        guard events.contains(.completion) else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func fireError(enabled events: PinEntryHapticEvents) {
        guard events.contains(.error) else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryHaptics.swift
git commit -m "Add PinEntryHaptics: configurable entry/completion/error feedback"
```

---

### Task 5: `DefaultPinEntryCell`

**Files:**
- Create: `Sources/CBPinEntryView/DefaultPinEntryCell.swift`

**Interfaces:**
- Consumes: `PinEntryCellState` from Task 3.
- Produces: `public struct DefaultPinEntryCell: View` with a public initialiser taking `state: PinEntryCellState` plus configurable colours/corner radius/border width/font (all defaulted). `PinEntryView`'s convenience initialiser (Task 6) constructs this directly: `DefaultPinEntryCell(state: state)`.

No test file: a `View`'s `body` is not unit-testable without snapshot testing, which is explicitly out of scope (Global Constraints). Verified manually in Task 15.

- [ ] **Step 1: Write the file**

```swift
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
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(currentBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(currentBorderColor, lineWidth: currentBorderWidth)
            )
            .overlay(
                Text(state.character ?? "")
                    .font(font)
                    .foregroundStyle(textColor)
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
```

Border weight doubles on focus/error (not colour alone) — this is what satisfies the "state distinguishable without colour" accessibility requirement (WCAG 1.4.1) for the shipped default.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/CBPinEntryView/DefaultPinEntryCell.swift
git commit -m "Add DefaultPinEntryCell: the one shipped default cell look"
```

---

### Task 6: `PinEntryView` — the core view

**Files:**
- Create: `Sources/CBPinEntryView/PinEntryView.swift`

**Interfaces:**
- Consumes: `AllowedEntryType` (Task 1), `PinEntryReducer` (Task 2), `PinEntryCellState` (Task 3), `PinEntryHapticEvents`/`PinEntryHaptics` (Task 4), `DefaultPinEntryCell` (Task 5).
- Produces: `public struct PinEntryView<CellContent: View>: View` — the full public surface described in the Design doc: two initialisers, and `.pinAllowedEntry(_:)`, `.pinSecure(_:character:)`, `.pinKeyboardType(_:)`, `.pinTextContentType(_:)`, `.pinTextInputAutocapitalization(_:)`, `.pinHaptics(_:)`, `.pinFocused(_:)` modifiers. The Example app (Tasks 7-10) is the sole consumer of this surface.

This view has no automated tests (Global Constraints: no snapshot/view tests). Each step below ends with `swift build`; the whole view is verified manually in Task 15.

- [ ] **Step 1: Struct skeleton, both initialisers, minimal body (equal-width cell row only, no field yet)**

```swift
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

    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44

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

        HStack(spacing: spacing) {
            ForEach(0..<length, id: \.self) { index in
                cell(cellState(at: index, visibleCharacters: visibleCharacters, isFocused: isFocused))
                    .frame(minWidth: minimumCellWidth, maxWidth: .infinity, minHeight: minimumCellWidth)
            }
        }
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
```

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 2: Add the sanitising `Binding` extension and the invisible input field**

Append to the same file, and replace `body` with the version below:

```swift
    public var body: some View {
        let displayString = isSecure ? PinEntryReducer.maskedDisplay(pin.wrappedValue, secureCharacter: secureCharacter) : pin.wrappedValue
        let visibleCharacters = Array(displayString.prefix(length))
        let isFocused = effectiveFocusBinding.wrappedValue

        ZStack {
            inputField
            HStack(spacing: spacing) {
                ForEach(0..<length, id: \.self) { index in
                    cell(cellState(at: index, visibleCharacters: visibleCharacters, isFocused: isFocused))
                        .frame(minWidth: minimumCellWidth, maxWidth: .infinity, minHeight: minimumCellWidth)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure {
                SecureField("", text: pin.sanitising(length: length, allowedEntry: allowedEntry))
            } else {
                TextField("", text: pin.sanitising(length: length, allowedEntry: allowedEntry))
            }
        }
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(textInputAutocapitalization)
        .focused(effectiveFocusBinding)
        .foregroundStyle(.clear)
        .tint(.clear)
        .allowsHitTesting(false)
    }
```

Add the private `Binding` extension at the bottom of the file (outside the `PinEntryView` struct):

```swift
private extension Binding where Value == String {
    func sanitising(length: Int, allowedEntry: AllowedEntryType) -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = PinEntryReducer.reduce($0, length: length, allowedEntry: allowedEntry) }
        )
    }
}
```

The field is invisible via clear foreground/tint only — it stays full-alpha and in-bounds, never `.hidden()`/`.opacity(0)`/zero-framed (Global Constraints), which is what preserves `.oneTimeCode` autofill and the responder chain.

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Add accessibility — label, live progress value, hint on the field; hide the cell overlay**

Replace the `inputField` and `body`'s `HStack` block to add accessibility, and add the `accessibilityValueText` helper:

```swift
    public var body: some View {
        let displayString = isSecure ? PinEntryReducer.maskedDisplay(pin.wrappedValue, secureCharacter: secureCharacter) : pin.wrappedValue
        let visibleCharacters = Array(displayString.prefix(length))
        let isFocused = effectiveFocusBinding.wrappedValue

        ZStack {
            inputField
            HStack(spacing: spacing) {
                ForEach(0..<length, id: \.self) { index in
                    cell(cellState(at: index, visibleCharacters: visibleCharacters, isFocused: isFocused))
                        .frame(minWidth: minimumCellWidth, maxWidth: .infinity, minHeight: minimumCellWidth)
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure {
                SecureField("", text: pin.sanitising(length: length, allowedEntry: allowedEntry))
            } else {
                TextField("", text: pin.sanitising(length: length, allowedEntry: allowedEntry))
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
```

The cell overlay is `accessibilityHidden(true)` and the field carries the label/value/hint — this is what guarantees a custom `cell` closure can never break accessibility (Global Constraints / Design → Accessibility).

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Add the `pin`-prefixed builder-style modifiers**

Append after the `DefaultPinEntryCell` extension:

```swift
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
}
```

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Wire completion + haptics via `onChange`**

Add two `@State` properties next to `internalFocus`:

```swift
    @State private var haptics = PinEntryHaptics()
    @State private var previousPin: String = ""
```

Append these modifiers to the end of `body`'s modifier chain (after `.onTapGesture`):

```swift
        .onAppear { previousPin = pin.wrappedValue }
        .onChange(of: pin.wrappedValue) { newValue in
            let completed = PinEntryReducer.didComplete(from: previousPin, to: newValue, length: length)
            if completed {
                haptics.fireCompletion(enabled: hapticEvents)
                onComplete?(newValue)
            } else {
                haptics.fireEntry(enabled: hapticEvents)
            }
            previousPin = newValue
        }
        .onChange(of: isError) { newValue in
            if newValue {
                haptics.fireError(enabled: hapticEvents)
            }
        }
        .task {
            haptics.prepare(for: hapticEvents)
        }
```

`previousPin` is seeded in `.onAppear`, before any `onChange` can fire, so a pin that already equals `length` when the view first appears does not spuriously fire `onComplete`.

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Add the `ViewThatFits` + horizontal-scroll fallback for Dynamic Type overflow**

Replace the inline `HStack` inside `body` with calls to two new methods, `equalWidthCellRow` and `scrollingCellRow`, wrapped in `ViewThatFits`:

```swift
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
        .onAppear { previousPin = pin.wrappedValue }
        .onChange(of: pin.wrappedValue) { newValue in
            let completed = PinEntryReducer.didComplete(from: previousPin, to: newValue, length: length)
            if completed {
                haptics.fireCompletion(enabled: hapticEvents)
                onComplete?(newValue)
            } else {
                haptics.fireEntry(enabled: hapticEvents)
            }
            previousPin = newValue
        }
        .onChange(of: isError) { newValue in
            if newValue {
                haptics.fireError(enabled: hapticEvents)
            }
        }
        .task {
            haptics.prepare(for: hapticEvents)
        }
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
```

The field is a `ZStack` sibling of `ViewThatFits`, not inside the `ScrollView` — so in the scrolled fallback the field still fills the component bounds and does not itself scroll (Design → Input mechanism); only the visual cell overlay scrolls.

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 7: Run the full test suite once more (regression check) and commit**

Run: `swift test`
Expected: `Test run with 13 tests in 2 suites passed`

```bash
git add Sources/CBPinEntryView/PinEntryView.swift
git commit -m "Add PinEntryView: invisible-field-driven SwiftUI pin entry with full accessibility"
```

---

### Task 7: Example project scaffold

**Files:**
- Create: `Example/Example.xcodeproj` (generated, not hand-written), `Example/Example/ExampleApp.swift`, `Example/Example/ContentView.swift` (minimal placeholder, replaced fully in Task 10), `Example/Example/Assets.xcassets/` (Contents.json, AppIcon.appiconset, AccentColor.colorset)

**Interfaces:**
- Consumes: the `CBPinEntryView` library product, via a local Swift package dependency on `..`.
- Produces: a buildable Xcode project with scheme `Example`, targeting iOS 17.0, that Tasks 8-10 add file references and real content to.

This step scaffolds the Xcode project entirely from the command line using the `xcodeproj` Ruby gem — not Xcode's GUI — so it is fully scriptable and reproducible. This is a one-time local tool, not a project dependency.

- [ ] **Step 1: Install the `xcodeproj` gem if not already present**

Run: `gem list xcodeproj -i || gem install xcodeproj --no-document`
Expected: `true` (already installed) or a successful install log.

- [ ] **Step 2: Create the Example source files and asset catalog**

```bash
mkdir -p Example/Example/Assets.xcassets/AppIcon.appiconset
mkdir -p Example/Example/Assets.xcassets/AccentColor.colorset
```

`Example/Example/ExampleApp.swift`:

```swift
import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`Example/Example/ContentView.swift` (minimal placeholder — Task 10 replaces this with the full demo screen):

```swift
import CBPinEntryView
import SwiftUI

struct ContentView: View {
    @State private var pin = ""

    var body: some View {
        PinEntryView(pin: $pin, length: 4)
            .padding()
    }
}
```

`Example/Example/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Example/Example/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Example/Example/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [ { "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Generate the Xcode project**

Save as a throwaway script, run it once, then delete it (the generated `.xcodeproj` is what gets committed, not the generator):

```bash
cat > /tmp/generate_example_project.rb << 'RUBY'
require 'xcodeproj'

project_path = 'Example/Example.xcodeproj'
project = Xcodeproj::Project.new(project_path)

target = project.new_target(:application, 'Example', :ios, '17.0')

group = project.main_group.new_group('Example', 'Example')
files = %w[ExampleApp.swift ContentView.swift].map { |f| group.new_file(f) }
assets = group.new_file('Assets.xcassets')

target.add_file_references(files)
target.resources_build_phase.add_file_reference(assets)

target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.chrisbyatt.CBPinEntryView.Example'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
end

local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_ref.relative_path = '..'
project.root_object.package_references << local_ref

product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_dep.package = local_ref
product_dep.product_name = 'CBPinEntryView'

target.package_product_dependencies << product_dep

frameworks_phase = target.frameworks_build_phase
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_dep
frameworks_phase.files << build_file

project.save
puts "Saved project"
RUBY
ruby /tmp/generate_example_project.rb
```

- [ ] **Step 4: Generate a shared scheme (required for headless `xcodebuild -scheme Example` to resolve destinations)**

```bash
cat > /tmp/generate_example_scheme.rb << 'RUBY'
require 'xcodeproj'

project = Xcodeproj::Project.open('Example/Example.xcodeproj')
target = project.targets.find { |t| t.name == 'Example' }

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as('Example/Example.xcodeproj', 'Example', true)
puts "Saved scheme"
RUBY
ruby /tmp/generate_example_scheme.rb
rm /tmp/generate_example_project.rb /tmp/generate_example_scheme.rb
```

- [ ] **Step 5: Build the Example app against an iOS 17 simulator**

Run: `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: `** BUILD SUCCEEDED **`

If the named simulator isn't available on this machine, run `xcrun simctl list devices available` and substitute an available iOS 17+ device name.

- [ ] **Step 6: Commit**

```bash
git add Example
git commit -m "Scaffold the SwiftUI Example app and its Xcode project"
```

---

### Task 8: Example — `@Observable` feature-model screen

**Files:**
- Create: `Example/Example/ObservablePinScreen.swift`

**Interfaces:**
- Consumes: `PinEntryView` (Task 6).
- Produces: `ObservablePinScreen: View`, referenced by `ContentView`'s `NavigationLink` (Task 10).

- [ ] **Step 1: Register the file in the Xcode project**

```bash
cat > /tmp/add_observable_screen.rb << 'RUBY'
require 'xcodeproj'

project = Xcodeproj::Project.open('Example/Example.xcodeproj')
target = project.targets.find { |t| t.name == 'Example' }
group = project.main_group.find_subpath('Example/Example', true)

file_ref = group.new_file('ObservablePinScreen.swift')
target.add_file_references([file_ref])

project.save
puts "Added ObservablePinScreen.swift"
RUBY
ruby /tmp/add_observable_screen.rb
rm /tmp/add_observable_screen.rb
```

- [ ] **Step 2: Write `Example/Example/ObservablePinScreen.swift`**

```swift
import CBPinEntryView
import SwiftUI

@Observable
final class PinVerificationModel {
    var pin = ""
    var isError = false
    private(set) var isVerifying = false

    private let correctCode = "1234"

    @MainActor
    func verify() async {
        isVerifying = true
        defer { isVerifying = false }

        try? await Task.sleep(for: .seconds(1))

        isError = pin != correctCode
    }
}

struct ObservablePinScreen: View {
    @State private var model = PinVerificationModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter 1234 to verify")
                .font(.headline)

            PinEntryView(pin: $model.pin, length: 4, isError: $model.isError) { _ in
                Task { await model.verify() }
            }
            .pinFocused($isFocused)

            if model.isVerifying {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle("Observable model")
        .onAppear { isFocused = true }
    }
}
```

This is the pattern `CLAUDE.md` (Task 14) documents: `@Observable` lives in the consumer's feature model (holding `pin`, `isError`, and async verification), not in the control itself.

- [ ] **Step 3: Build**

Run: `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Example
git commit -m "Add the @Observable feature-model example screen"
```

---

### Task 9: Example — `UIHostingController` interop screen

**Files:**
- Create: `Example/Example/HostingControllerInteropScreen.swift`

**Interfaces:**
- Consumes: `PinEntryView` (Task 6).
- Produces: `HostingControllerInteropScreen: UIViewControllerRepresentable`, referenced by `ContentView`'s `NavigationLink` (Task 10). Proves the documented UIKit migration path (a `UIHostingController` hosting `PinEntryView`) works end-to-end.

- [ ] **Step 1: Register the file in the Xcode project**

```bash
cat > /tmp/add_hosting_screen.rb << 'RUBY'
require 'xcodeproj'

project = Xcodeproj::Project.open('Example/Example.xcodeproj')
target = project.targets.find { |t| t.name == 'Example' }
group = project.main_group.find_subpath('Example/Example', true)

file_ref = group.new_file('HostingControllerInteropScreen.swift')
target.add_file_references([file_ref])

project.save
puts "Added HostingControllerInteropScreen.swift"
RUBY
ruby /tmp/add_hosting_screen.rb
rm /tmp/add_hosting_screen.rb
```

- [ ] **Step 2: Write `Example/Example/HostingControllerInteropScreen.swift`**

```swift
import CBPinEntryView
import SwiftUI
import UIKit

struct HostingControllerInteropScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PinHostingViewController {
        PinHostingViewController()
    }

    func updateUIViewController(_ uiViewController: PinHostingViewController, context: Context) {}
}

final class PinHostingViewController: UIViewController {
    private var pin = ""
    private var isError = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit interop"
        view.backgroundColor = .systemBackground

        let pinBinding = Binding(
            get: { [weak self] in self?.pin ?? "" },
            set: { [weak self] in self?.pin = $0 }
        )
        let errorBinding = Binding(
            get: { [weak self] in self?.isError ?? false },
            set: { [weak self] in self?.isError = $0 }
        )

        let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
            print("Completed from UIKit host: \(pin)")
        }

        let hosting = UIHostingController(rootView: pinView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            hosting.view.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            hosting.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            hosting.view.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
        hosting.didMove(toParent: self)
    }
}
```

The `Binding(get:set:)` here closes over the view controller's own stored properties — this is the standard, necessary pattern for bridging state into a `UIHostingController` from a plain `UIViewController` (there is no `@State` in UIKit). It is not the "no inline `Binding(get:set:)` in SwiftUI views" convention from `modern-swiftui`, which targets SwiftUI view bodies, not UIKit bridging code.

- [ ] **Step 3: Build**

Run: `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Example
git commit -m "Add the UIHostingController interop example screen"
```

---

### Task 10: Example — main demo screen + custom cell recipe

**Files:**
- Modify: `Example/Example/ContentView.swift` (replace placeholder with the full demo)
- Create: `Example/Example/UnderlinedPinCell.swift`

**Interfaces:**
- Consumes: `PinEntryView`, `AllowedEntryType`, `PinEntryCellState` (public API from Task 6), `ObservablePinScreen` (Task 8), `HostingControllerInteropScreen` (Task 9) — both already exist by this point, so `ContentView`'s `NavigationLink`s resolve cleanly with no stubbing needed.
- Produces: a working demo screen exercising length, secure toggle, error toggle (+ the optional "typing dismisses error" one-liner), allowed-type picker, clear, programmatic focus, and a custom underlined cell with a shake-on-error animation.

No file reference registration needed for `UnderlinedPinCell.swift` beyond what Task 7's scheme already covers if you pre-created the file reference — since Task 7 only registered `ExampleApp.swift`/`ContentView.swift`, register the new file now:

- [ ] **Step 1: Register `UnderlinedPinCell.swift` in the Xcode project**

```bash
cat > /tmp/add_underlined_cell.rb << 'RUBY'
require 'xcodeproj'

project = Xcodeproj::Project.open('Example/Example.xcodeproj')
target = project.targets.find { |t| t.name == 'Example' }
group = project.main_group.find_subpath('Example/Example', true)

file_ref = group.new_file('UnderlinedPinCell.swift')
target.add_file_references([file_ref])

project.save
puts "Added UnderlinedPinCell.swift"
RUBY
ruby /tmp/add_underlined_cell.rb
rm /tmp/add_underlined_cell.rb
```

- [ ] **Step 2: Write `Example/Example/UnderlinedPinCell.swift`**

```swift
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
```

This recipe demonstrates that the removed `isUnderlined` preset is trivially reproducible as a `cell` closure, and honours `accessibilityReduceMotion` per Global Constraints.

- [ ] **Step 3: Replace `Example/Example/ContentView.swift` with the full demo**

```swift
import CBPinEntryView
import SwiftUI

struct ContentView: View {
    @State private var pin = ""
    @State private var length = 4
    @State private var isSecure = false
    @State private var isError = false
    @State private var allowedEntry: AllowedEntryType = .numerical
    @State private var useUnderlinedCell = false
    @FocusState private var isPinFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin entry") {
                    Group {
                        if useUnderlinedCell {
                            PinEntryView(pin: $pin, length: length, isError: $isError, cell: UnderlinedPinCell.init)
                                .pinAllowedEntry(allowedEntry)
                                .pinSecure(isSecure)
                                .pinFocused($isPinFocused)
                        } else {
                            PinEntryView(pin: $pin, length: length, isError: $isError)
                                .pinAllowedEntry(allowedEntry)
                                .pinSecure(isSecure)
                                .pinFocused($isPinFocused)
                        }
                    }
                    .onChange(of: pin) {
                        if !pin.isEmpty {
                            isError = false
                        }
                    }
                    .padding(.vertical, 8)

                    Text("Entered: \(pin.isEmpty ? "—" : pin)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Configuration") {
                    Stepper("Length: \(length)", value: $length, in: 4...8)
                    Toggle("Secure entry", isOn: $isSecure)
                    Toggle("Underlined cell recipe", isOn: $useUnderlinedCell)
                    Picker("Allowed characters", selection: $allowedEntry) {
                        Text("Any").tag(AllowedEntryType.any)
                        Text("Numerical").tag(AllowedEntryType.numerical)
                        Text("Alphanumeric").tag(AllowedEntryType.alphanumeric)
                        Text("Letters").tag(AllowedEntryType.letters)
                    }
                }

                Section("Actions") {
                    Button("Trigger error") { isError = true }
                    Button("Clear") { pin = "" }
                    Button("Focus") { isPinFocused = true }
                }

                Section("More examples") {
                    NavigationLink("Observable feature model", destination: ObservablePinScreen())
                    NavigationLink("UIKit interop (UIHostingController)", destination: HostingControllerInteropScreen())
                }
            }
            .navigationTitle("CBPinEntryView")
        }
    }
}
```

Note the `pin`-prefixed modifiers are applied **inside each branch** of the `if`/`else`, not on the wrapping `Group` — `Group<...>` doesn't carry `PinEntryView`'s own extension methods, only `PinEntryView` itself does. This mirrors the exact footgun the modifiers are designed to avoid (see `CLAUDE.md` → "Why `pin`-prefixed modifiers, not the standard ones", Task 14).

- [ ] **Step 4: Build**

Run: `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Example
git commit -m "Build the main Example demo screen and an underlined custom-cell recipe"
```

---

### Task 11: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the `CBPinEntryView` scheme (auto-exposed by `Package.swift`, Task 1) and the `Example` scheme (Task 7).

- [ ] **Step 1: Confirm which Xcode versions / simulator runtimes are available on the target GitHub Actions runner image**

GitHub's hosted macOS runner images (see `https://github.com/actions/runner-images`) change their bundled Xcode/simulator versions over time. Before writing exact version numbers below, either check the current runner-images README for the `macos-14`/`macos-15` image in use, or push a throwaway workflow run with a debug step (`ls /Applications | grep Xcode`, `xcrun simctl list runtimes`) and adjust the `xcode-select` path and `OS=` destination values to match what's actually installed. The library job specifically needs a runtime that includes iOS 16.x — this is often an older Xcode side-install, not the runner's default.

- [ ] **Step 2: Write `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  library:
    name: Build & test library (iOS 16)
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      # Pin to an Xcode version whose default (or side-installed) simulator
      # runtime includes iOS 16.x. Confirm the exact path against the
      # current macos-14 runner image before relying on it (see Step 1).
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app
      - name: Build
        run: swift build
      - name: Test
        run: |
          xcodebuild test \
            -scheme CBPinEntryView \
            -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.2'

  example:
    name: Build example app (iOS 17)
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app
      - name: Build example
        run: |
          xcodebuild build \
            -project Example/Example.xcodeproj \
            -scheme Example \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2'
```

- [ ] **Step 3: Push and confirm both jobs go green**

Run: push the branch and open the Actions run for this commit.
Expected: both `library` and `example` jobs succeed. If either `-destination` fails to resolve, adjust the `OS=`/device name per Step 1 and re-push.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "Add CI: library tests on iOS 16, example build on iOS 17"
```

---

### Task 12: `MIGRATION.md`

**Files:**
- Create: `MIGRATION.md`

- [ ] **Step 1: Write `MIGRATION.md`**

```markdown
# Migrating from 1.x to 2.0

CBPinEntryView 2.0 is a complete SwiftUI rewrite. The UIKit `CBPinEntryView` class, its delegate protocol, and CocoaPods distribution are gone. There is no UIKit compatibility shim.

If you need to keep using it from a `UIViewController`, host the new `PinEntryView` with `UIHostingController` (see "UIKit interop" below) — you get the new behaviour with the default look; per-button UIKit customisation is not preserved.

## Distribution

CocoaPods is no longer supported. Add the package via Swift Package Manager:

```swift
.package(url: "https://github.com/Fawxy/CBPinEntryView.git", from: "2.0.0")
```

## API mapping

| 1.x (`CBPinEntryView`) | 2.0 (`PinEntryView`) |
|---|---|
| `delegate.entryCompleted(with:)` | `onComplete: (String) -> Void` init parameter |
| `delegate.entryChanged(_:)` | Dropped — derive it from `.onChange(of: pin)` on your own `pin` binding |
| `getPinAsString()` | Read your own `pin: Binding<String>` directly |
| `getPinAsInt()` | `Int(pin)` |
| `setError(isError:)` / `errorMode` | `isError: Binding<Bool>` — you own it; the view renders it but never mutates or clears it |
| `clearEntry()` | `pin = ""` |
| `becomeFirstResponder()` / `resignFirstResponder()` | A parent-owned `@FocusState` binding passed via `.pinFocused($focus)`; set `focus = true`/`false` yourself |
| Per-state style properties (`entryBackgroundColour`, `entryBorderColour`, `entryCornerRadius`, `entryFont`, etc.) | A `cell: (PinEntryCellState) -> some View` closure, or tweak `DefaultPinEntryCell`'s initialiser parameters |
| `isUnderlined` | No longer a built-in mode — write an underlined `cell` closure (see `Example/Example/UnderlinedPinCell.swift` for a working recipe) |
| `allowedEntryTypes` | `.pinAllowedEntry(_:)` (same four cases: `.any`, `.numerical`, `.alphanumeric`, `.letters`) |
| `isSecure` / `secureCharacter` | `.pinSecure(_:character:)` |
| `keyboardType` (raw `Int`) | `.pinKeyboardType(_:)`, taking a real `UIKeyboardType` |
| `textContentType` | `.pinTextContentType(_:)` |
| `textFieldCapitalization` (`UITextAutocapitalizationType`) | `.pinTextInputAutocapitalization(_:)`, taking SwiftUI's `TextInputAutocapitalization` |
| Storyboard / `@IBInspectable` placement | Place `PinEntryView` directly in SwiftUI, or host it via `UIHostingController` from UIKit |

## Behavioural notes

- **Error no longer auto-clears.** In 1.x, `resignFirstResponder()` cleared error mode. In 2.0 the view never mutates `isError` — if you want typing to dismiss an error, add it yourself: `.onChange(of: pin) { if !pin.isEmpty { isError = false } }`.
- **`isUnderlined` has no replacement flag.** It's a `cell` closure now, not a boolean mode.
- **Reading the pin is synchronous and always available** via your own `pin` binding — no more force-unwrapping `textField.text!`.

## UIKit interop

```swift
let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
    // handle completion
}
let hosting = UIHostingController(rootView: pinView)
addChild(hosting)
view.addSubview(hosting.view)
hosting.view.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    hosting.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
    hosting.view.centerYAnchor.constraint(equalTo: view.centerYAnchor)
])
hosting.didMove(toParent: self)
```

See `Example/Example/HostingControllerInteropScreen.swift` for the full, running version.
```

- [ ] **Step 2: Commit**

```bash
git add MIGRATION.md
git commit -m "Add MIGRATION.md: 1.x to 2.0 API mapping"
```

---

### Task 13: `README.md`

**Files:**
- Modify: `README.md` (full rewrite)

- [ ] **Step 1: Rewrite `README.md`**

```markdown
# CBPinEntryView

A SwiftUI view for entering pins, one-time codes, or passwords — backspace, paste, and `.oneTimeCode` autofill all work correctly out of the box, with first-class accessibility (VoiceOver progress announcements, Dynamic Type, no colour-only states).

## Requirements

- iOS 16.0+
- Swift 5.9+
- No external dependencies

## Installation

Swift Package Manager only:

```swift
dependencies: [
    .package(url: "https://github.com/Fawxy/CBPinEntryView.git", from: "2.0.0")
]
```

> Upgrading from 1.x? CBPinEntryView 2.0 is a SwiftUI-only rewrite with no UIKit compatibility shim. See [MIGRATION.md](MIGRATION.md).

## Usage

```swift
import CBPinEntryView

struct LoginView: View {
    @State private var pin = ""
    @State private var isError = false

    var body: some View {
        PinEntryView(pin: $pin, length: 6, isError: $isError) { pin in
            print("Completed: \(pin)")
        }
    }
}
```

`pin` is the single source of truth — read it directly, no `getPinAsString()` needed. Set `pin = ""` to clear.

### Configuration

Behavioural configuration is applied via `pin`-prefixed modifiers, not the standard SwiftUI ones (see "Why `pin`-prefixed modifiers?" below):

```swift
PinEntryView(pin: $pin, length: 4, isError: $isError)
    .pinAllowedEntry(.numerical)
    .pinSecure(true, character: "●")
    .pinKeyboardType(.numberPad)
    .pinTextContentType(.oneTimeCode)
    .pinTextInputAutocapitalization(.never)
    .pinHaptics(.default)
    .pinFocused($isFocused)
```

### Custom cell rendering

The library ships one default cell (`DefaultPinEntryCell`) but imposes no particular look. Pass your own `@ViewBuilder` closure over `PinEntryCellState`:

```swift
PinEntryView(pin: $pin, length: 4, isError: $isError) { state in
    VStack {
        Text(state.character ?? "")
        Rectangle()
            .fill(state.isFocused ? Color.accentColor : Color.secondary)
            .frame(height: state.isFocused ? 3 : 1)
    }
}
```

`PinEntryCellState` is already masked when secure — a custom cell never sees the raw digit in secure mode.

### Why `pin`-prefixed modifiers?

A wrapper view can't give a propagating standard modifier (`.keyboardType`, `.textContentType`, `.textInputAutocapitalization`) an overridable default: SwiftUI's environment resolves closest-to-the-field-wins, and the field inside `PinEntryView` is always closer than anything wrapped around it. Applying the standard modifier outside `PinEntryView` would silently do nothing. The `pin`-prefixed modifiers avoid that footgun — apply them directly on `PinEntryView`, before any type-erasing modifier like `.frame()`.

### Accessibility

The field carries a single accessibility element (label + a live "N of M entered" progress value); the cell overlay is hidden from VoiceOver. Secure entry reports count only, never characters. Error is surfaced non-visually as well as visually. This is guaranteed by the library regardless of the `cell` closure you provide.

### UIKit interop

`PinEntryView` is a SwiftUI-only view. Host it from UIKit with `UIHostingController`:

```swift
let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
    // handle completion
}
let hosting = UIHostingController(rootView: pinView)
addChild(hosting)
view.addSubview(hosting.view)
// ... Auto Layout constraints ...
hosting.didMove(toParent: self)
```

See `Example/Example/HostingControllerInteropScreen.swift` for a complete, running example.

## Example app

Open `Example/Example.xcodeproj` in Xcode and run the `Example` scheme (iOS 17+ simulator). It exercises length, secure toggle, error toggle, allowed-character restriction, clear, programmatic focus, a custom underlined cell with a shake-on-error animation, an `@Observable` feature-model screen, and the `UIHostingController` interop screen.

## Migrating from 1.x

See [MIGRATION.md](MIGRATION.md) for the full API mapping.

## License

CBPinEntryView is available under the MIT license. See the LICENSE file for more info.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Rewrite README for the SPM-only SwiftUI 2.0 API"
```

---

### Task 14: `CLAUDE.md`

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
# CLAUDE.md

Guidance for AI agents (and humans) working in this repository.

## Overview

CBPinEntryView is a SwiftUI leaf control for entering pins, codes, or passwords. Version 2.0 is a complete rewrite: SwiftUI-only, zero external dependencies, iOS 16+, no UIKit compatibility shim. The guiding principle is a **correct, robust core** (backspace, paste, focus, autofill, accessibility) that is **customisable without being opinionated** — the library ships sensible defaults and imposes no particular look or animation.

## Architecture

- `PinEntryView` is a `struct View`, `@Binding`-driven, recreated from the parent's state on every render. There is no persistent instance and no imperative API — everything is state the parent already owns.
- No `@Observable` model in the control itself: the value *is* the state, so a `Binding<String>` is the right primitive, same as `TextField`. `@Observable` belongs in the *consumer's* feature model (see the example app's `ObservablePinScreen.swift`), not the control.
- The only logic is a pure, unit-tested reducer (`PinEntryReducer`): sanitise, truncate, detect completion. It has no dependency on SwiftUI and is tested directly.
- One real, invisible-but-focusable `TextField`/`SecureField` is the single source of truth; a row of cells is drawn as an overlay from the current string. This is what makes backspace, paste, and `.oneTimeCode` autofill correct for free — they're inherited from the real field, not reimplemented.
- Zero external dependencies. iOS system frameworks only.

## File map

- `Sources/CBPinEntryView/PinEntryView.swift` — the public view, its two initialisers (generic `cell` closure + a `DefaultPinEntryCell` convenience), and the `pin`-prefixed configuration modifiers.
- `Sources/CBPinEntryView/PinEntryCellState.swift` — the customisation point passed into `cell`.
- `Sources/CBPinEntryView/DefaultPinEntryCell.swift` — the one shipped default cell.
- `Sources/CBPinEntryView/AllowedEntryType.swift` — character-filtering policy (`any`/`numerical`/`alphanumeric`/`letters`).
- `Sources/CBPinEntryView/PinEntryReducer.swift` — pure, unit-tested core logic (sanitise, truncate, completion detection, secure masking).
- `Sources/CBPinEntryView/PinEntryHaptics.swift` — thin wrapper over `UIFeedbackGenerator`, gated by `.pinHaptics(_:)`.
- `Tests/CBPinEntryViewTests/` — Swift Testing (`@Test`/`@Suite`) unit tests for the reducer and `AllowedEntryType` only. No snapshot tests, no view tests — see "Testing" below.
- `Example/` — a SwiftUI example app (its own Xcode project, iOS 17+) exercising every feature, including an `@Observable` feature-model screen and a `UIHostingController` interop screen.

## Public API

- `PinEntryView<CellContent: View>` — init with `pin: Binding<String>`, `length`, `spacing`, `isError: Binding<Bool>`, `accessibilityLabel`, `onComplete: ((String) -> Void)?`, and a `@ViewBuilder cell: (PinEntryCellState) -> CellContent` closure. A convenience init omits `cell` and uses `DefaultPinEntryCell`.
- `PinEntryCellState` — `character` (already masked when secure), `index`, `isFocused`, `isFilled`, `isError`. Plain data, passed into `cell`.
- `DefaultPinEntryCell` — the shipped default cell, configurable via its own initialiser (colours, corner radius, border width, font).
- `AllowedEntryType` — `.any` / `.numerical` / `.alphanumeric` / `.letters`, applied via `.pinAllowedEntry(_:)`.
- `PinEntryHapticEvents` — an `OptionSet` (`.entry`, `.completion`, `.error`, `` .`default` `` = `[.completion, .error]`, `.all`) applied via `.pinHaptics(_:)`.
- Configuration modifiers, all `pin`-prefixed and builder-style (copy-and-mutate, return `Self`): `.pinAllowedEntry(_:)`, `.pinSecure(_:character:)`, `.pinKeyboardType(_:)`, `.pinTextContentType(_:)`, `.pinTextInputAutocapitalization(_:)`, `.pinHaptics(_:)`, `.pinFocused(_:)`.

## Accessibility contract

This is a first-class part of the component, not left to the consumer:

- Exactly one accessibility element, on the field. The cell overlay is `accessibilityHidden(true)` — a custom `cell` closure can never accidentally break this.
- The field's accessibility value reports live progress ("N of M entered"); secure entry reports **count only**, never characters — enforced at the OS level by `SecureField`, not just asserted by our value string.
- Error is surfaced non-visually (appended to the accessibility value) as well as visually.
- `DefaultPinEntryCell` distinguishes focus/filled/error states by more than colour (border weight, fill, content) — WCAG 1.4.1. If you write a custom cell, do the same.
- Font is relative to a text style (scales with Dynamic Type), never a fixed point size.
- Custom `cell` closures that animate should honour `accessibilityReduceMotion` — the library ships no animation itself, so it has nothing to disable, but your closure might.

## Colour rule

Pass SwiftUI `Color` values straight through (asset catalog or semantic system colours) so light/dark adapt automatically. **Never** snapshot a `Color` to `CGColor`/`UIColor` — that freezes the appearance and was the bug in the old UIKit view.

## The invisible field rule

The field is made invisible by **clear content only** (clear foreground text, clear tint) while staying full-alpha and laid out within the component's bounds. It is **never** `.hidden()`, `.opacity(0)`, zero-framed, or pushed off-screen — any of those breaks the responder chain, `.oneTimeCode` autofill, or accessibility. Don't "tidy this up" — it's deliberate.

## Why `pin`-prefixed modifiers, not the standard ones

A wrapper view can't give a propagating standard text modifier (`.keyboardType`, `.textContentType`, `.textInputAutocapitalization`) an overridable default: SwiftUI's environment resolves closest-to-the-field-wins, and the internal field is always closer than anything a consumer wraps around `PinEntryView`. An internal default would silently beat a standard modifier applied outside the view. The `pin`-prefixed modifiers sidestep that footgun entirely — apply them directly on `PinEntryView`, before any type-erasing modifier.

## `isSecure` is fixed per instance

`.pinSecure(_:)` picks between `SecureField` and `TextField` once, at view creation. Don't toggle it dynamically based on other state — SwiftUI will tear down and rebuild the underlying field, losing focus and any in-progress entry.

## Build & test

```sh
swift build
swift test
```

Or against a specific simulator:

```sh
xcodebuild test -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=<device>'
```

## Running the example

Open `Example/Example.xcodeproj` in Xcode and run the `Example` scheme (iOS 17+ simulator — the example targets a higher deployment than the library to showcase `@Observable`).

## UIKit interop

`PinEntryView` is SwiftUI-only. Host it from a `UIViewController` with `UIHostingController` — see `Example/Example/HostingControllerInteropScreen.swift` for a complete, running recipe.

## Conventions

- No external dependencies, ever. If a feature seems to need one, it probably belongs in the consumer's app instead.
- Adding a new configuration option touches three places: `PinEntryReducer` (if it affects sanitise/truncate/completion logic), the stored property + `pin`-prefixed modifier on `PinEntryView`, and — if it's a visual default — `DefaultPinEntryCell`'s initialiser.
- A custom `cell` closure is just a function; reuse across call sites by extracting it to a named function or a small `View` struct and passing it by name (`PinEntryView(pin: $pin, cell: MyCell.init)`), the same way you'd reuse a `ForEach` row builder.
- There's no `validate` closure — correctness validation ("is this the right code?") is the consumer's job via `onComplete`, since it's often async. The library only owns *input filtering* (`AllowedEntryType`), which is synchronous and unopinionated.
- There's no UIKit compatibility shim, on purpose — see the design doc history for the rationale. Don't add one back for a single caller's convenience; point them at `UIHostingController` instead.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Add CLAUDE.md for future contributors"
```

---

### Task 15: Final manual verification pass

This task has no automated steps — it is the manual checklist from the design spec's Verification section, run once the whole tree is in place. Do not mark it complete until every item below has actually been exercised.

**Files:** none (verification only; fix forward in the relevant task's files if something fails).

- [ ] **Step 1: Automated checks**

Run: `swift build && swift test`
Expected: build succeeds, all unit tests pass.

Run: `xcodebuild test -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=<iOS 16 device>'`
Expected: `** TEST SUCCEEDED **`

Run: `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=<iOS 17 device>'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Manual run-through in the Example app simulator**

Launch the `Example` scheme and confirm:

- Typing, backspace, and pasting a full code all work; a pasted full code fills every cell.
- Secure toggle masks entered characters with `secureCharacter`.
- Allowed-type restriction rejects disallowed characters per picker selection.
- `.oneTimeCode` autofill surfaces from Messages/a code source (simulator: Settings → paste a code, or use a real device if the simulator doesn't offer a code suggestion).
- Reading `pin` directly from the example's own `@State` reflects what's on screen.
- `pin = ""` (the Clear button) resets all cells with no separate reset call.
- The over-length-paste truncation write-back does not visibly flash or jump the caret (paste a code longer than `length`).
- Setting `isError` paints the cells; the library never clears the field or flips `isError` itself; toggling "typing dismisses error" behaviour (the one-liner in `ContentView`) works.
- Haptics fire on completion and error by default, and stop when `.pinHaptics([])` is set; per-keystroke haptics are off by default and turn on with `.pinHaptics(.all)`.
- The default cell adapts between light and dark mode.
- The underlined custom cell renders and shakes on error (and does not shake with Reduce Motion enabled in Settings → Accessibility).
- Programmatic focus (the Focus button) moves keyboard focus via the example's own `@FocusState`.

- [ ] **Step 3: Secure-mode device gates**

With `isSecure` on:

- Confirm `.oneTimeCode` autofill still surfaces on the `SecureField`.
- If the field clears on refocus, confirm the `pin` binding clears with it (cells re-render empty and correct), not just the field's internal buffer.
- With VoiceOver on, confirm it reads count-only and never echoes typed digits.

If either autofill or the refocus-clear propagation fails, this is the trigger condition documented in the design spec's escape hatch: drop the secure branch only to a `UIViewRepresentable` over `UITextField` (`isSecureTextEntry = true`, `clearsOnBeginEditing = false`) and re-run this step. Do not change the non-secure branch.

- [ ] **Step 4: Accessibility pass**

With VoiceOver on:

- The field announces its label and progress (e.g. "3 of 6").
- Secure entry reports count only.
- Error is exposed non-visually.
- The cells are not individually focusable — VoiceOver lands on exactly one element for the whole component.

With colour filters / greyscale on:

- Focus, filled, and error states remain distinguishable without colour.

At the largest Dynamic Type accessibility size:

- Glyphs scale and never clip.
- A `length` long enough to overflow falls back to a horizontal scroll with the active cell scrolled into view; glyphs stay legible (never shrunk).
- Tap-to-focus and the accessibility tap target keep working while scrolled, not just at the initial scroll offset.

Repeat the VoiceOver and Dynamic Type checks against the underlined custom cell to confirm accessibility is inherited from the field, not reimplemented per cell.

- [ ] **Step 5: Confirm the `@Observable` and `UIHostingController` example screens**

- `ObservablePinScreen`: entering "1234" verifies successfully (no error); entering anything else sets `isError` after the simulated async delay.
- `HostingControllerInteropScreen`: the hosted `PinEntryView` sizes, focuses, and raises the keyboard correctly from a `UIViewController` host.

- [ ] **Step 6: Documentation pass**

Read `README.md` and `MIGRATION.md` end-to-end and confirm every code sample in both compiles against the final API (copy each snippet into a scratch file in the Example target if in doubt).

- [ ] **Step 7: Final commit (only if Steps 2-6 surfaced fixes)**

```bash
git add -A
git commit -m "Fix issues found in final manual verification pass"
```

If nothing needed fixing, there is nothing to commit — the plan is complete as of Task 14's commit.

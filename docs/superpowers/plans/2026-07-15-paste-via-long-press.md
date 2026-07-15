# Paste via Long-Press Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users trigger a paste by long-pressing the pin cells, since the invisible field currently can't receive touches and never shows a native paste affordance.

**Architecture:** A long-press gesture on `PinEntryView`'s existing `ZStack` checks the pasteboard for string content and, if present, shows a SwiftUI `confirmationDialog` with a single "Paste" action. Confirming reads `UIPasteboard.general.string` and appends it to the existing `rawText` state, which already flows through `PinEntryReducer.reduce` on every change — so filtering and truncation are free. The same trigger is exposed as a custom accessibility action on the field for VoiceOver users, avoiding the need for a second accessible element.

**Tech Stack:** SwiftUI, UIKit (`UIPasteboard`) — both already used by this file. No new imports, no new dependencies.

## Global Constraints

- iOS 16+ deployment target. `UIPasteboard`, `.onLongPressGesture`, `.confirmationDialog`, and `.accessibilityAction` are all available well below iOS 16, so there are no availability concerns for this feature.
- Zero external dependencies — everything needed is already imported in `PinEntryView.swift` (`import SwiftUI` / `import UIKit`).
- Configuration is exposed only via a `pin`-prefixed, builder-style modifier (copy-mutate-return `Self`) applied directly on `PinEntryView`, matching every other modifier in the file.
- Paste must go through `rawText` (not `pin` directly) so `PinEntryReducer.reduce` sanitizes (`allowedEntry`) and truncates (`length`) it exactly like typed input — no new reducer logic.
- iOS will show its own "Allow Paste from X?" system confirmation on every paste (accepted trade-off — see the design doc's Approach section). This is expected, not a bug to fix.
- No automated tests for this feature. Per CLAUDE.md, only `PinEntryReducer` and `AllowedEntryType` are unit-tested — this feature is gesture/pasteboard-driven view behavior, verified manually in Task 4.
- Design doc: `docs/superpowers/specs/2026-07-15-paste-via-long-press-design.md`.

---

## Task 1: Add the `pinPasteEnabled` configuration option

**Files:**
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:13-20` (stored properties)
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:260-264` (modifier extension)

**Interfaces:**
- Consumes: nothing new.
- Produces: `private var isPasteEnabled: Bool` (default `true`), `public func pinPasteEnabled(_ enabled: Bool = true) -> Self`. Later tasks read `isPasteEnabled` to gate paste behavior.

- [ ] **Step 1: Add the stored property**

In `Sources/CBPinEntryView/PinEntryView.swift`, find this block:

```swift
    private var allowedEntry: AllowedEntryType = .numerical
    private var isSecure: Bool = false
    private var secureCharacter: String = "●"
    private var keyboardType: UIKeyboardType = .numberPad
    private var textContentType: UITextContentType? = .oneTimeCode
    private var textInputAutocapitalization: TextInputAutocapitalization = .never
    private var hapticEvents: PinEntryHapticEvents = .default
    private var externalFocus: FocusState<Bool>.Binding?
```

Replace it with:

```swift
    private var allowedEntry: AllowedEntryType = .numerical
    private var isSecure: Bool = false
    private var secureCharacter: String = "●"
    private var keyboardType: UIKeyboardType = .numberPad
    private var textContentType: UITextContentType? = .oneTimeCode
    private var textInputAutocapitalization: TextInputAutocapitalization = .never
    private var hapticEvents: PinEntryHapticEvents = .default
    private var externalFocus: FocusState<Bool>.Binding?
    private var isPasteEnabled: Bool = true
```

- [ ] **Step 2: Add the modifier**

Find this block (the last modifier in the `extension PinEntryView` block):

```swift
    public func pinFocused(_ binding: FocusState<Bool>.Binding) -> Self {
        var copy = self
        copy.externalFocus = binding
        return copy
    }
}
```

Replace it with:

```swift
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
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'`
Expected: `** BUILD SUCCEEDED **`. `isPasteEnabled` is unused so far — that's expected; it's consumed starting in Task 2.

- [ ] **Step 4: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryView.swift
git commit -m "Add pinPasteEnabled configuration option"
```

---

## Task 2: Implement long-press-to-paste

**Files:**
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:22-24` (`@State` properties)
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:63-91` (`body`)
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:93-122` (private methods, adds two new ones after `pinDidChangeExternally`)

**Interfaces:**
- Consumes: `isPasteEnabled` (Task 1), `rawText: String` (`@State`, existing), `effectiveFocusBinding: FocusState<Bool>.Binding` (existing computed property).
- Produces: `private func attemptPaste()`, `private func performPaste()`, `@State private var isPasteConfirmationPresented: Bool`. Task 3 calls `attemptPaste()` from the accessibility action.

- [ ] **Step 1: Add the confirmation-dialog state**

Find:

```swift
    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44
    @State private var haptics = PinEntryHaptics()
```

Replace with:

```swift
    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44
    @State private var haptics = PinEntryHaptics()
    @State private var isPasteConfirmationPresented = false
```

- [ ] **Step 2: Wire up the long-press gesture and confirmation dialog in `body`**

Find:

```swift
        .contentShape(Rectangle())
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
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
    }
```

Replace with:

```swift
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
```

- [ ] **Step 3: Add `attemptPaste()` and `performPaste()`**

Find:

```swift
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
```

Replace with:

```swift
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
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryView.swift
git commit -m "Add long-press-to-paste gesture and confirmation dialog"
```

---

## Task 3: Expose paste via a VoiceOver accessibility action

**Files:**
- Modify: `Sources/CBPinEntryView/PinEntryView.swift:152-171` (`inputField`)

**Interfaces:**
- Consumes: `attemptPaste()` and `isPasteEnabled` (Task 2/1).
- Produces: `inputField` keeps the same external shape (still referenced once from `body`); adds a new private `baseInputField` computed property.

- [ ] **Step 1: Split `inputField` and add the conditional accessibility action**

Find:

```swift
    @ViewBuilder
    private var inputField: some View {
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
```

Replace with:

```swift
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryView.swift
git commit -m "Expose paste as a VoiceOver accessibility action"
```

---

## Task 4: Manual verification

**Files:** none (verification only, plus a temporary local-only edit to `Example/Example/ContentView.swift` that gets discarded, not committed)

**Interfaces:**
- Consumes: everything from Tasks 1-3.
- Produces: nothing — this task is a checklist, not code.

- [ ] **Step 1: Run the existing automated test suite as a regression check**

Run: `xcodebuild test -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'`
Expected: all existing `PinEntryReducer`/`AllowedEntryType` tests still pass (this change doesn't touch the reducer, so this should be unaffected).

- [ ] **Step 2: Open the Example app and run it**

Open `Example/Example.xcodeproj` in Xcode, select the `Example` scheme, run on an iOS 17+ simulator (e.g. iPhone 16 Pro).

- [ ] **Step 3: Verify tap-to-focus still works**

On the main screen's pin field, tap once. Expected: the keyboard appears and the first cell shows the focused styling (matches pre-existing behavior — this is the regression check for the tap gesture, since Task 2 added a sibling long-press gesture on the same view).

If tapping no longer focuses the field (the long-press gesture is intercepting it), open `Sources/CBPinEntryView/PinEntryView.swift` and replace:

```swift
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
        .onLongPressGesture { attemptPaste() }
```

with:

```swift
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in attemptPaste() }
        )
```

then rebuild and re-verify both gestures independently before continuing.

- [ ] **Step 4: Verify long-press paste with clipboard content**

In the simulator, open Safari or Notes, type and copy a numeric string longer than the pin's length (e.g. copy `98765` for a 4-digit field). Switch back to the Example app. Long-press the pin cells. Expected: a "Paste" action sheet appears with a "Paste" and "Cancel" option. Tap "Paste". Expected: iOS shows its own "Allow Paste from [App]?" system alert; tap "Allow". Expected: the field fills with the first 4 digits of the copied value (truncated to `length` via the existing reducer), the field becomes focused, and — since the field is now complete — the completion haptic/`onComplete` fires as it would for typed input.

- [ ] **Step 5: Verify long-press with an empty/non-string clipboard is a no-op**

In the simulator, copy an image (e.g. long-press an image in Photos and choose Copy) so the pasteboard has no string content. Switch back to the Example app, long-press the pin cells. Expected: nothing happens — no confirmation dialog appears.

- [ ] **Step 6: Verify append-then-truncate with partial existing entry**

Clear the pin field. Type 2 digits manually. Copy a numeric string via Safari/Notes as in Step 4. Long-press the pin cells and confirm paste. Expected: the pasted digits are appended after the 2 already-typed digits, then truncated to `length` — matching normal typed-input truncation, not a full overwrite.

- [ ] **Step 7: Verify `pinPasteEnabled(false)` disables both the gesture and the accessibility action**

Temporarily edit `Example/Example/ContentView.swift`: find the `PinEntryView` used on the main screen and chain `.pinPasteEnabled(false)` onto it. Rebuild and run. With a numeric string copied to the clipboard, long-press the pin cells — expected: no confirmation dialog appears. Then enable VoiceOver (Settings → Accessibility → VoiceOver, or Accessibility Inspector's simulator toggle) and swipe to focus the pin field — expected: no "Paste" action is offered in the actions rotor. Once confirmed, discard the temporary edit:

```bash
git checkout -- Example/Example/ContentView.swift
```

- [ ] **Step 8: Verify the VoiceOver accessibility action when paste is enabled**

Revert the temporary edit from Step 7 if not already done. With VoiceOver enabled and a numeric string on the clipboard, swipe to focus the pin field, then swipe up/down to cycle through the actions rotor until "Paste" is announced, and double-tap to activate. Expected: the same confirmation dialog from Step 4 appears, reachable and operable entirely through VoiceOver.

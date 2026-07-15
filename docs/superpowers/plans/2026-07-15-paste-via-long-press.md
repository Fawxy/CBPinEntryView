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

> **Note:** Steps 3-8 below were written against the original
> `.onLongPressGesture`/`.confirmationDialog` mechanism and have been
> updated in place for the `.contextMenu`-based revision (Task 5). If Task
> 5 hasn't run yet when you read this, the "context menu"/"custom
> accessibility action from `.contextMenu`" wording won't match the code —
> check `git log` for whether "Replace long-press dialog with native
> contextMenu" has landed.

- [ ] **Step 3: Verify tap-to-focus still works**

On the main screen's pin field, tap once. Expected: the keyboard appears and the first cell shows the focused styling (matches pre-existing behavior — this is the regression check for the tap gesture, since `.contextMenu` installs its own long-press recognizer on the same view).

If tapping no longer focuses the field (the context menu's long-press is intercepting it), this needs further investigation — `.contextMenu` is a native, heavily-used SwiftUI API, so a straightforward composition failure here would be unexpected; report it rather than working around it blindly.

- [ ] **Step 4: Verify long-press paste with clipboard content**

In the simulator, open Safari or Notes, type and copy a numeric string longer than the pin's length (e.g. copy `98765` for a 4-digit field). Switch back to the Example app. Long-press the pin cells. Expected: a small floating context menu appears at the touch point with a single "Paste" action (no "Cancel" — tapping elsewhere dismisses it, as with any `.contextMenu`). Tap "Paste". Expected: iOS shows its own "Allow Paste from [App]?" system alert; tap "Allow". Expected: the field fills with the first 4 digits of the copied value (truncated to `length` via the existing reducer), the field becomes focused, and — since the field is now complete — the completion haptic/`onComplete` fires as it would for typed input.

- [ ] **Step 5: Verify long-press with an empty/non-string clipboard is a true no-op**

In the simulator, copy an image (e.g. long-press an image in Photos and choose Copy) so the pasteboard has no string content. Switch back to the Example app, long-press the pin cells. Expected: nothing happens — no context menu appears at all (not even an empty one). This is the specific behavior flagged as unverified in the design doc's "Revised trigger" section — if an empty floating box appears instead of nothing, report it; it may mean the `if` inside the `.contextMenu` builder needs a different structure (e.g. `.contextMenu(menuItems:)` with an explicit empty check) to suppress the menu entirely.

- [ ] **Step 6: Verify append-then-truncate with partial existing entry**

Clear the pin field. Type 2 digits manually. Copy a numeric string via Safari/Notes as in Step 4. Long-press the pin cells and confirm paste. Expected: the pasted digits are appended after the 2 already-typed digits, then truncated to `length` — matching normal typed-input truncation, not a full overwrite.

- [ ] **Step 7: Verify `pinPasteEnabled(false)` disables the context menu entirely**

Temporarily edit `Example/Example/ContentView.swift`: find the `PinEntryView` used on the main screen and chain `.pinPasteEnabled(false)` onto it. Rebuild and run. With a numeric string copied to the clipboard, long-press the pin cells — expected: no context menu appears (same "true no-op" expectation as Step 5). Then enable VoiceOver (Settings → Accessibility → VoiceOver, or Accessibility Inspector's simulator toggle) and swipe to focus the pin field — expected: no "Paste" action is offered in the actions rotor. Once confirmed, discard the temporary edit:

```bash
git checkout -- Example/Example/ContentView.swift
```

- [ ] **Step 8: Verify VoiceOver exposes "Paste" automatically from `.contextMenu`, with no duplicate**

Revert the temporary edit from Step 7 if not already done. With VoiceOver enabled and a numeric string on the clipboard, swipe to focus the pin field, then swipe up/down to cycle through the actions rotor. Expected: exactly one "Paste" action is announced (confirming SwiftUI surfaces `.contextMenu` buttons as VoiceOver custom actions automatically, per the design doc's "Accessibility (revised)" section — and confirming there is no leftover duplicate from the old manual `.accessibilityAction`, which Task 5 removes). Double-tap to activate it. Expected: the same confirmation flow from Step 4 (context menu's "Paste" fires, then the OS "Allow Paste" alert), reachable and operable entirely through VoiceOver. If no "Paste" action appears at all, `.contextMenu` isn't auto-exposing to VoiceOver for this view and the manual `.accessibilityAction` from the original Task 3 needs to be reinstated — report this rather than silently re-adding it.

---

## Task 5: Replace long-press dialog with native contextMenu

**Context:** Tasks 1-3 implemented paste via `.onLongPressGesture` +
`.confirmationDialog` (Task 2) plus a manual `.accessibilityAction` (Task
3). Post-implementation review determined `.contextMenu` is a better fit:
it's natively long-press-triggered (no separate gesture needed), presents a
small floating menu instead of a bottom action sheet, and its buttons are
automatically exposed to VoiceOver as custom actions — making the manual
accessibility action from Task 3 redundant. See the design doc's "Revision"
note and "Revised trigger: `.contextMenu`" section:
`docs/superpowers/specs/2026-07-15-paste-via-long-press-design.md`.

**Files:**
- Modify: `Sources/CBPinEntryView/PinEntryView.swift` (remove
  `isPasteConfirmationPresented` state, replace the long-press
  gesture/confirmationDialog with `.contextMenu` in `body`, remove
  `attemptPaste()`, revert the `inputField`/`baseInputField` split back to
  a single `inputField`)

**Interfaces:**
- Consumes: `isPasteEnabled` (Task 1, unchanged), `performPaste()`
  (Task 2, unchanged — still reads the pasteboard, appends to `rawText`,
  focuses the field).
- Produces: no new public API. `attemptPaste()` and
  `isPasteConfirmationPresented` are removed; `inputField` and
  `baseInputField` are merged back into a single `inputField`.

- [ ] **Step 1: Remove the confirmation-dialog state**

Find:

```swift
    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44
    @State private var haptics = PinEntryHaptics()
    @State private var isPasteConfirmationPresented = false
```

Replace with:

```swift
    @FocusState private var internalFocus: Bool
    @ScaledMetric(relativeTo: .title2) private var minimumCellWidth: CGFloat = 44
    @State private var haptics = PinEntryHaptics()
```

- [ ] **Step 2: Replace the long-press gesture and confirmation dialog with `.contextMenu` in `body`**

Find:

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

Replace with:

```swift
        .contentShape(Rectangle())
        .onTapGesture { effectiveFocusBinding.wrappedValue = true }
        .contextMenu {
            if isPasteEnabled, UIPasteboard.general.hasStrings {
                Button("Paste") { performPaste() }
            }
        }
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

- [ ] **Step 3: Remove the now-unused `attemptPaste()`**

Find:

```swift
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

Replace with:

```swift
    private func performPaste() {
        guard let pasted = UIPasteboard.general.string else { return }
        rawText += pasted
        effectiveFocusBinding.wrappedValue = true
    }
```

- [ ] **Step 4: Revert `inputField`/`baseInputField` back to a single `inputField`**

Find:

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

Replace with:

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

- [ ] **Step 5: Build to verify it compiles**

Run: `xcodebuild build -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Sources/CBPinEntryView/PinEntryView.swift
git commit -m "Replace long-press dialog with native contextMenu"
```

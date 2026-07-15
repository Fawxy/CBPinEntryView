# Error Shake Animation Example Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Example app's existing "Trigger error" button play a horizontal shake animation on the pin cell row, in addition to the existing border-color error styling, while respecting Reduce Motion.

**Architecture:** Single-file change to `Example/Example/ContentView.swift`. Add a `shakeTrigger` counter incremented alongside `isError = true`, and drive a `PhaseAnimator`-based horizontal offset off that counter via the `.phaseAnimator(_:trigger:content:animation:)` view modifier (iOS 17+).

**Tech Stack:** SwiftUI, `PhaseAnimator` (iOS 17+), `CBPinEntryView` package (unchanged).

## Global Constraints

- Example app only — do not modify `Sources/CBPinEntryView` or its tests (spec: "Scope").
- Example app targets iOS 17+ (per project CLAUDE.md), so `PhaseAnimator` APIs are available.
- Zero external dependencies — use only SwiftUI/Foundation APIs (project-wide invariant).
- Must respect `accessibilityReduceMotion`: when enabled, no offset jitter plays (spec: "Design").
- The shake must replay on every "Trigger error" tap, even repeated taps while already in an error state (spec: "Design").

---

### Task 1: Add shake animation to the "Trigger error" flow

**Files:**
- Modify: `Example/Example/ContentView.swift`

**Interfaces:**
- Consumes: existing `PinEntryView(pin:length:isError:...)` initializers and `pinAllowedEntry`/`pinSecure`/`pinFocused` modifiers (unchanged, from `Sources/CBPinEntryView/PinEntryView.swift`).
- Produces: no new public API — this task only changes `ContentView`'s internal `body`.

- [ ] **Step 1: Read the current file to confirm line numbers before editing**

Run: view `Example/Example/ContentView.swift` (34 lines below is the version this plan was written against — re-check if it has since diverged).

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

- [ ] **Step 2: Add the `shakeTrigger` state and `accessibilityReduceMotion` environment value**

Add these two properties directly below the existing `@FocusState private var isPinFocused: Bool` line:

```swift
    @State private var shakeTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 3: Wire the "Trigger error" button to increment `shakeTrigger`**

Replace:

```swift
                    Button("Trigger error") { isError = true }
```

with:

```swift
                    Button("Trigger error") {
                        isError = true
                        shakeTrigger += 1
                    }
```

- [ ] **Step 4: Wrap the pin entry `Group` in a `.phaseAnimator` shake effect**

Replace the `Group { ... }.onChange(of: pin) { ... }.padding(.vertical, 8)` block with:

```swift
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
                    .phaseAnimator([0, -8, 8, -8, 8, 0], trigger: shakeTrigger) { content, offset in
                        content.offset(x: reduceMotion ? 0 : offset)
                    } animation: { _ in
                        .easeInOut(duration: 0.06)
                    }
```

(Only the `Button("Trigger error")` action and the trailing `.phaseAnimator(...)` modifier are new; everything else in the block is unchanged from Step 1's baseline.)

- [ ] **Step 5: Build the Example app to confirm it compiles**

Run:
```bash
xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,name=iPhone 15'
```
Expected: `** BUILD SUCCEEDED **`. If the named simulator isn't available, run `xcrun simctl list devices available` and substitute an installed iOS 17+ device name.

- [ ] **Step 6: Manually verify the shake in the simulator**

Launch the `Example` scheme on an iOS 17+ simulator (via Xcode, or `xcodebuild test`-style launch is unnecessary here — a plain run is enough). On the root screen:
1. Tap "Trigger error" — confirm the pin cell row jitters left-right briefly and the cells show the red error border, matching current behavior plus the new shake.
2. Tap "Trigger error" again without typing anything in between — confirm the shake replays even though `isError` was already `true`.
3. In Settings > Accessibility > Motion, enable "Reduce Motion", relaunch, and tap "Trigger error" again — confirm the cells still show the red error border but no longer jitter.

Expected: shake plays on every tap; no jitter when Reduce Motion is on; error border styling unaffected in both cases.

- [ ] **Step 7: Commit**

```bash
git add Example/Example/ContentView.swift
git commit -m "Add shake animation to Example app's trigger-error flow"
```

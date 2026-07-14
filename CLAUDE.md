# CLAUDE.md

CBPinEntryView — a SwiftUI leaf control for entering pins/codes/passwords. SwiftUI-only, SPM, iOS 16+, zero external dependencies.

## Commands

The library imports UIKit, so `swift build`/`swift test` fail on macOS ("no such module 'UIKit'"). Always target a simulator:

```sh
xcodebuild test -scheme CBPinEntryView -destination 'platform=iOS Simulator,name=<device>'
```

Example app: open `Example/Example.xcodeproj`, run the `Example` scheme (iOS 17+ simulator — it targets higher than the library to showcase `@Observable`).

## Architecture

- One real, invisible-but-focusable `TextField`/`SecureField` is the single source of truth; the row of cells is a non-interactive overlay drawn from the current string. This is why backspace, paste, and `.oneTimeCode` autofill work for free — inherited from the real field, not reimplemented.
- All logic lives in `PinEntryReducer`: a pure function (no SwiftUI) tested directly — sanitise, truncate, completion detection, secure masking.
- `PinEntryView` is a `Binding<String>`-driven `struct View`, recreated from the parent's state each render. The value *is* the state — no model, no imperative API, no `@Observable` in the control (that belongs in the consumer's feature model).

## File map

- `Sources/CBPinEntryView/PinEntryView.swift` — public view, initialisers, `pin`-prefixed config modifiers.
- `PinEntryReducer.swift` — pure core logic (unit-tested).
- `PinEntryCellState.swift` — data passed into a custom `cell` closure.
- `DefaultPinEntryCell.swift` — the one shipped default cell.
- `AllowedEntryType.swift` — input filtering (`any`/`numerical`/`alphanumeric`/`letters`).
- `PinEntryHaptics.swift` — `UIFeedbackGenerator` wrapper, gated by `.pinHaptics(_:)`.
- `Tests/CBPinEntryViewTests/` — Swift Testing unit tests for the reducer and `AllowedEntryType` only.
- `Example/` — SwiftUI example app exercising every feature.

The public API is small and self-documenting — read `PinEntryView.swift` rather than duplicating signatures here.

## Invariants — don't break these

- **Invisible field = clear content only.** Clear foreground/tint while full-alpha and laid out in bounds. Never `.hidden()`, `.opacity(0)`, zero-frame, or off-screen — each breaks the responder chain, autofill, or accessibility.
- **Colours pass through as SwiftUI `Color`.** Never snapshot to `CGColor`/`UIColor` — that freezes light/dark appearance (the original UIKit bug).
- **Accessibility: exactly one element, on the field.** The overlay is `accessibilityHidden(true)`. The value reports live progress ("N of M entered"); secure entry reports count only, never characters. Error is surfaced in the value, not just visually. A custom `cell` must distinguish focus/filled/error by more than colour (WCAG 1.4.1) and use a Dynamic-Type-relative font.
- **`pin`-prefixed modifiers only, applied directly on `PinEntryView`** before any type-erasing modifier. Standard modifiers (`.keyboardType`, `.textContentType`, `.textInputAutocapitalization`) can't be given an overridable default from a wrapper — the internal field always wins the environment.
- **`.pinSecure(_:)` is fixed per instance.** Don't toggle it from other state — SwiftUI rebuilds the field, losing focus and in-progress entry.
- **No validation closure.** Validating the code (usually async) is the consumer's job via `onComplete`; the library owns input filtering only.
- **No UIKit shim.** Host from UIKit via `UIHostingController` (see `Example/Example/HostingControllerInteropScreen.swift`).
- **Zero external dependencies, ever.** If a feature seems to need one, it belongs in the consumer's app.

## Adding a configuration option

Touch three places: `PinEntryReducer` (if it affects sanitise/truncate/completion), the stored property + `pin`-prefixed modifier on `PinEntryView`, and `DefaultPinEntryCell`'s initialiser (if it's a visual default). Modifiers are builder-style: copy-mutate-return `Self`. A reusable custom `cell` is just a function — extract it and pass by name (`PinEntryView(pin: $pin, cell: MyCell.init)`).

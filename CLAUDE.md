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

The library imports UIKit, so plain `swift build`/`swift test` fail on macOS with "no such module 'UIKit'" — always build/test against an iOS Simulator:

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

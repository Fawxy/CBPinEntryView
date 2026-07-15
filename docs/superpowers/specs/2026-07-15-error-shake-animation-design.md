# Error shake animation example

## Purpose

Demonstrate, in the Example app, how a consumer can react to `PinEntryView`'s
`isError` binding with a visual animation (a horizontal shake) on top of the
existing border-color/width error styling. This is example-app-only —
`isError` triggering/animating is already a consumer concern, not something
the library owns.

## Scope

`Example/Example/ContentView.swift` only. No changes to
`Sources/CBPinEntryView`.

## Design

- Add `@State private var shakeTrigger = 0` alongside the existing `isError`
  state.
- The "Trigger error" button action sets `isError = true` **and** increments
  `shakeTrigger`. Incrementing unconditionally (rather than reacting to
  `isError` flipping to `true`) ensures the shake replays even if the button
  is tapped again while already in an error state, since `isError` wouldn't
  change in that case.
- Wrap the `PinEntryView` group in a `.phaseAnimator([...], trigger:
  shakeTrigger)` (iOS 17+, matching the Example app's deployment target).
  Phases step through horizontal offsets `0 → -8 → 8 → -8 → 8 → 0` with a
  fast easeInOut animation per phase.
- Read `@Environment(\.accessibilityReduceMotion)`. When enabled, the phase
  animator always renders offset `0` (no jitter). The error is still
  communicated via the existing border styling and the accessibility value
  text, so no information is lost for reduced-motion users.

## Out of scope

- No changes to `PinEntryView`, `PinEntryReducer`, or `DefaultPinEntryCell`.
- No new configuration/toggle for animation style — only the shake variant
  requested.

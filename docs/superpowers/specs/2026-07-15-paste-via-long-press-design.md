# Paste via long-press on pin cells

## Purpose

`PinEntryView` is documented as supporting paste, but there is currently no
way to *trigger* one by touch. The invisible `TextField`/`SecureField` has
`.allowsHitTesting(false)`, and the outer `ZStack` has its own
`.onTapGesture` that always wins any tap and just sets focus — so the real
field never receives a touch, and iOS's native "Paste" callout (which only
appears when a tap lands directly on a focused, empty text field) never has
a chance to show. Paste today only works via `⌘V` on a hardware keyboard or
`.oneTimeCode` autofill.

This adds a touch-driven way to paste: long-press anywhere on the pin cells
presents a "Paste" confirmation, which pastes the clipboard's string content
into the field.

## Approach

Three touch-driven options were considered:

1. **SwiftUI `PasteButton`** — no OS confirmation prompt, but Apple requires
   it to always render a visible icon/label; it can't be hidden until
   needed, and its icon glyph can't be swapped for a custom one (tint and
   label style are the only customizable parts).
2. **Long-press → `UIEditMenuInteraction`** — the real system Edit Menu
   bubble, invisible until triggered, no confirmation prompt (it's one of
   the three OS-exempted paste paths: Edit Menu, `⌘V`, `UIPasteControl`/
   `PasteButton`). Requires bridging a `UIView` via `UIViewRepresentable`,
   since there's no SwiftUI-native wrapper for this interaction.
3. **Long-press → SwiftUI `confirmationDialog`** — pure SwiftUI, invisible
   until triggered, but reading `UIPasteboard.general.string` outside the
   three exempted paths means iOS shows its own "Allow Paste from X?"
   confirmation on top, every time.

**Chosen: option 3.** Staying pure SwiftUI (no `UIViewRepresentable` bridge)
was prioritized over avoiding the OS prompt.

## Design

### Trigger and confirmation

- Add `.onLongPressGesture { attemptPaste() }` alongside the existing
  `.onTapGesture` on the `ZStack`'s content shape.
- `attemptPaste()` checks `UIPasteboard.general.hasStrings` first (checking
  *presence* doesn't trigger the OS prompt — only reading the actual
  `.string` value does) and only presents the confirmation if there's
  something pasteable. If the pasteboard has no string, the long-press is a
  no-op.
- Presentation: a new `@State private var isPasteConfirmationPresented =
  false`, driving `.confirmationDialog("", isPresented:
  $isPasteConfirmationPresented, titleVisibility: .hidden) { Button("Paste")
  { performPaste() } }`. This renders as a bottom action sheet (or a popover
  on iPad) with a system-provided "Cancel" — **not** a small floating bubble
  anchored to the touch point like the native text-field Edit Menu. That
  visual difference is an accepted consequence of staying SwiftUI-only.
- `performPaste()` reads `UIPasteboard.general.string` (triggering iOS's own
  "Allow Paste from X?" prompt the first time in a session, per Apple's iOS
  16+ pasteboard privacy model — accepted, see Approach above), appends it
  to `rawText` (not `pin` directly), and sets
  `effectiveFocusBinding.wrappedValue = true`.
- Appending to `rawText` — rather than replacing it — means paste always
  adds to whatever's already been typed. It also means the paste flows
  through the exact same `.onChange(of: rawText)` → `userDidEdit(to:)` →
  `PinEntryReducer.reduce` pipeline as manual typing, so filtering
  (`allowedEntry`) and truncation (`length`) are handled automatically with
  no new reducer logic. If the field is already at `length`, the appended
  paste is truncated away entirely — identical to typing extra characters
  once full.

### Configuration

- New stored property `private var isPasteEnabled: Bool = true` and a
  builder-style modifier:

  ```swift
  public func pinPasteEnabled(_ enabled: Bool = true) -> Self
  ```

- Defaults to enabled (opt-out), since the whole point of this feature is
  fixing a gap in already-shipped "paste support" — existing consumers get
  the fix with no code changes. `isPasteEnabled` gates both the long-press
  gesture and the accessibility action below.

### Accessibility

- Expose the same `attemptPaste()` behavior as a custom
  `.accessibilityAction(named: Text("Paste")) { attemptPaste() }` on the
  existing invisible field (the library's one accessible element).
- Because this reuses the field's existing accessibility element rather
  than introducing a separate visible control, **no change to the
  "exactly one element" invariant in CLAUDE.md is needed.** VoiceOver users
  reach paste through the field's actions rotor, activate it, and hit the
  same confirmation-dialog/OS-prompt flow as a sighted long-press.

### Implementation risk to verify

- `.onLongPressGesture` and `.onTapGesture` attached to the same view can
  sometimes need explicit composition (e.g. `.simultaneously(with:)`) to
  both fire correctly rather than one suppressing the other. This needs
  on-device verification during implementation; if the default composition
  doesn't work cleanly, the tap-to-focus and long-press-to-paste gestures
  may need to be combined explicitly.

## Out of scope

- `UIPasteControl`/`PasteButton` and `UIEditMenuInteraction` (see Approach).
- Avoiding the OS "Allow Paste" confirmation prompt.
- Pasting non-string content (images, URLs as distinct types, etc.) —
  `UIPasteboard.general.string` only.
- A "Clear" or other action alongside "Paste" in the confirmation dialog.
- Any Example app changes — this is default-on library behavior, already
  exercised by every existing pin field in the Example app.
- Automated tests — this is gesture/UIKit-pasteboard-driven view behavior,
  not the kind of pure logic `PinEntryReducer`/`AllowedEntryType` tests
  cover (per CLAUDE.md, only those two are unit-tested). Verified manually.

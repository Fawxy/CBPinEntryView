# Paste via long-press on pin cells

> **Revision (post-implementation):** the original design (below) used
> `.onLongPressGesture` + `.confirmationDialog`, which was implemented and
> reviewed. It was then revised to use `.contextMenu` instead — see
> "Revised trigger: `.contextMenu`" under Design. The rest of this doc
> (Purpose, the rejected `PasteButton`/`UIEditMenuInteraction` options,
> append-to-`rawText` semantics, `pinPasteEnabled` configuration) is
> unchanged and still accurate.

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

### Trigger and confirmation (superseded — see revision below)

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

### Revised trigger: `.contextMenu`

`.confirmationDialog` renders as a bottom action sheet (or iPad popover)
with full-width button rows — visually a poor match for "a plain paste
action near the touch point." SwiftUI's `.contextMenu` is the closer fit:
it's natively long-press-triggered (no separate `.onLongPressGesture`
needed) and presents a small floating list of plain text/icon actions at
the touch point, much closer to the native Edit Menu look than an action
sheet. It does **not** change the OS prompt trade-off — a custom
`.contextMenu` button reading `UIPasteboard.general.string` is still
outside the three exempted paths (Edit Menu, `⌘V`, `UIPasteControl`/
`PasteButton`), so "Allow Paste from X?" still appears every time.

Replaces the previous "Trigger and confirmation" section's mechanism:

- Remove `.onLongPressGesture { attemptPaste() }`, `.confirmationDialog`,
  `@State private var isPasteConfirmationPresented`, and `attemptPaste()`
  entirely — `.contextMenu`'s own gesture recognition and presentation
  replace all of it.
- Add, alongside the existing `.onTapGesture` on the `ZStack`'s content
  shape:

  ```swift
  .contextMenu {
      if isPasteEnabled, UIPasteboard.general.hasStrings {
          Button("Paste") { performPaste() }
      }
  }
  ```

- The `if` inside the menu builder is evaluated live at long-press time, so
  it reflects the pasteboard's current contents and the current
  `isPasteEnabled` value — no separate presentation-state variable needed.
- `performPaste()` is unchanged: reads `UIPasteboard.general.string`,
  appends to `rawText`, focuses the field.
- **Needs on-device verification:** when the `if` produces zero menu items
  (paste disabled or nothing pasteable), does long-pressing show no menu at
  all, or an empty floating box? Expected behavior (per SwiftUI's general
  handling of empty menu builders) is no menu, but this hasn't been
  confirmed on a simulator/device for this exact call site.

### Configuration

- New stored property `private var isPasteEnabled: Bool = true` and a
  builder-style modifier:

  ```swift
  public func pinPasteEnabled(_ enabled: Bool = true) -> Self
  ```

- Defaults to enabled (opt-out), since the whole point of this feature is
  fixing a gap in already-shipped "paste support" — existing consumers get
  the fix with no code changes. `isPasteEnabled` gates the `.contextMenu`'s
  content (see Revised trigger above).

### Accessibility (revised)

- Originally: a custom `.accessibilityAction(named: Text("Paste")) {
  attemptPaste() }` on the existing invisible field, to avoid introducing a
  second accessible element.
- **Revised:** `.contextMenu` buttons are standard SwiftUI `Button`s, and
  SwiftUI automatically surfaces a view's `.contextMenu` actions to
  VoiceOver as custom actions on that view's existing accessibility element
  (the same rotor mechanism `.accessibilityAction` uses) — without a
  separate physical long-press from the VoiceOver user. This means the
  manual `.accessibilityAction` is redundant once `.contextMenu` is in
  place, and has been removed.
- This still satisfies the "exactly one accessible element" invariant in
  CLAUDE.md — no new element is introduced either way.
- **Needs on-device verification:** confirm VoiceOver actually exposes a
  "Paste" custom action from the `.contextMenu` alone (no double entry, no
  missing entry). If it doesn't, reinstate the manual
  `.accessibilityAction` as a fallback.

### Implementation risk to verify

- `.contextMenu`'s built-in long-press recognition and the existing
  `.onTapGesture` on the same view: does tap-to-focus still work
  cleanly alongside `.contextMenu`'s gesture? `.contextMenu` uses a native,
  widely-used interaction (`UIContextMenuInteraction` under the hood) rather
  than a hand-rolled gesture, so this is expected to be more robust than the
  original `.onLongPressGesture` composition — but still needs on-device
  confirmation, not just assumed.
- The empty-menu-builder behavior noted under "Revised trigger" above.

## Out of scope

- `UIPasteControl`/`PasteButton` and `UIEditMenuInteraction` (see Approach).
- Avoiding the OS "Allow Paste" confirmation prompt.
- Pasting non-string content (images, URLs as distinct types, etc.) —
  `UIPasteboard.general.string` only.
- A "Clear" or other action alongside "Paste" in the context menu.
- Any Example app changes — this is default-on library behavior, already
  exercised by every existing pin field in the Example app.
- Automated tests — this is gesture/UIKit-pasteboard-driven view behavior,
  not the kind of pure logic `PinEntryReducer`/`AllowedEntryType` tests
  cover (per CLAUDE.md, only those two are unit-tested). Verified manually.

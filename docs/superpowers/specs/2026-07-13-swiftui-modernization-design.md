# CBPinEntryView SwiftUI Modernisation — Design

## Context

`CBPinEntryView` is a published open-source library (CocoaPods + SPM) providing a
customisable PIN/code/password entry field. Today it is a UIKit `@IBDesignable`
`UIView` — a hidden `UITextField` driving a row of `UIButton` cells in a stack
view, with a `CBPinEntryViewDelegate`. The goal is to completely modernise it to
SwiftUI while preserving (and where sensible, improving) all existing
functionality, ship it via SPM only (dropping CocoaPods), leave a `CLAUDE.md` for
future contributors, and apply Point-Free / modern-SwiftUI paradigms — without
importing any external dependency. iOS system frameworks only.

This is a **SwiftUI-only** rewrite shipped as a breaking **2.0**. There is **no
UIKit compatibility shim** (see Decisions). UIKit consumers migrate by hosting
the new view in a `UIHostingController` — a documented, few-line recipe carried
in `MIGRATION.md` and the README.

The repo is also in a broken state that must be cleaned up regardless:

- Two divergent source trees: `CBPinEntryView/Classes/` (CocoaPods, clean) and
  `Sources/CBPinEntryView/` (SPM). The SPM copy does not compile — it references
  `IQKeyboardManager` (undeclared dependency) and ships `Extensions.swift`, ~1700
  lines of unrelated cruft copied from another project.
- Inconsistent version/Swift metadata; stale Travis CI targeting Xcode 7.3.

## Guiding principle

Provide a PIN field with a **correct, robust core** — proper backspace, paste,
focus, autofill, **and accessibility** (the behaviours that are broken in so many
apps) — that is **customisable without being opinionated**. Ship sensible
defaults; impose no particular look or animation. Accessibility is treated as
part of the robust core, not as an add-on: the default experience must be fully
usable with VoiceOver and Dynamic Type out of the box.

## Decisions

- **Compatibility: SwiftUI-only, no UIKit shim.** A thin behavioural shim (class
  + bindings + delegate + imperative methods, default look only) would serve a
  near-empty set: this is a *leaf control*, and any consumer willing to accept
  the default look can host the SwiftUI view in a `UIHostingController` in ~5
  lines. A full shim that also reproduced UIKit-native cell customisation was
  considered and rejected as over-engineering for a shrinking UIKit audience
  already forced to change code for a breaking 2.0. So the choice is full or
  nothing, and nothing is coherent. Accepted, documented losses: storyboard /
  `@IBInspectable` / live `@IBDesignable` placement is gone; existing
  `delegate` + outlet + `getPinAsString()`/`setError()`/`clearEntry()` call
  sites must be rewritten. `MIGRATION.md` maps every removed API to its
  replacement, and the README/example show the `UIHostingController` recipe.
  (Side benefit: with the legacy `CBPinEntryView` *class* gone, the only public
  type is `PinEntryView`, so there is no longer a module-name/type-name clash.)
- **Architecture:** Lightweight, `@Binding`-driven SwiftUI leaf view. No models
  forced on consumers, no external dependencies. Logic extracted into small,
  pure, testable types.
- **Input core:** A single real SwiftUI text field is the source of truth
  (invisible but focusable) — `SecureField` or `TextField` per `isSecure` (see
  **Secure entry**); cells are drawn from the string binding as an overlay. This
  inherits correct keyboard, backspace, paste, and `.oneTimeCode` autofill from
  iOS defaults; because the whole pin lives in one binding, a pasted full code
  fills every cell automatically. Input is **sanitised and truncated in a
  derived binding's setter** before it reaches the consumer's `pin` binding (see
  Design → Input mechanism) — not by writing a corrected value back inside
  `onChange`, which can flash or fight the caret on fast paste/autofill.
- **Secure entry uses `SecureField`, not a masked `TextField`.** When `isSecure`
  is true the backing field is a `SecureField`; otherwise it is a `TextField`.
  `isSecure` is **fixed per instance** (not designed for live toggling), so the
  choice is made once at view creation with no view-identity churn. `SecureField`
  makes the component *live up to* the flag: VoiceOver character echo is
  suppressed at the platform level (so the "count only, never the characters" AX
  contract is enforced, not asserted) and the entry gets `isSecureTextEntry` OS
  protection (screenshot / screen-recording redaction, no predictive caching) —
  retiring the "no OS-level protection" limitation an earlier draft accepted. The
  visible mask is still drawn by the cell overlay from `secureCharacter`, so mask
  customisation is unaffected. Accepted, documented consequences of secure mode:
  dictation is unavailable, and the field's contents **may clear when it is
  refocused** — expected `SecureField` behaviour that leaves the field in a valid
  empty state (cells derive from `pin.count`), not a defect. Two behaviours must
  be **verified on device** because they gate the pure-SwiftUI approach:
  (1) `.oneTimeCode` autofill still surfaces on a `SecureField` (non-negotiable —
  OTP support is a headline feature); (2) clear-on-refocus propagates to the
  `pin` binding (benign: cells re-render empty) rather than clearing only the
  field's buffer (which would desync binding and field). **Escape hatch:** if
  either gate fails, the *secure branch only* drops to a `UIViewRepresentable`
  over `UITextField` (`isSecureTextEntry = true`, `clearsOnBeginEditing = false`,
  binding authoritative); the non-secure branch stays plain SwiftUI `TextField`.
- **`@Observable` belongs in the consumer's feature model, not the control.**
  This is a control, like `TextField`: the value *is* the state, so a `Binding`
  is the right primitive and an `@Observable` model in the core would only add
  ceremony (a reference-type allocation for a text field). The only logic —
  sanitise/truncate/`isComplete` — is a pure reducer, already testable without
  Observation. Where an `@Observable` model *does* belong is the consumer's
  screen (holding pin + validation + error + "codes don't match" logic); the
  example app and `CLAUDE.md` demonstrate that pattern at that layer.
- **Accessibility (first-class), owned by the library:** the accessibility
  element lives on the field, not the cells, so a custom `cell` closure can
  **never degrade accessibility** — every look a consumer builds inherits the
  full behaviour. The behaviour is defined normatively in the **Accessibility
  behaviour** section below (single AX element; live progress value; count-only
  for secure; every state distinguishable without colour; Dynamic Type; no
  default motion) and verified by an explicit accessibility pass, not left to
  the consumer.
- **Haptics:** Configurable (one flag/modifier to disable), using the system
  `UIFeedbackGenerator`, `prepare()`d for low latency. Default: **completion and
  error on; per-keystroke entry off** (per-key haptics are noisy). Respects the
  system haptics setting.
- **Dynamic colour:** Style is expressed in SwiftUI `Color`, applied directly in
  the view body so asset-catalog and semantic colours adapt to light/dark
  automatically — no convenience initialiser needed. Defaults use **semantic
  system colours**. Hard rule: never snapshot a `Color` to `CGColor`/`UIColor`
  (that would freeze the appearance — the bug in the old UIKit code).
- **Customisable look/animation, not opinionated:** Expose cell rendering as a
  `@ViewBuilder` content closure, `(PinEntryCellState) -> some View`, rather
  than a `ButtonStyle`-like protocol. Rationale: Apple reserves the style-protocol
  pattern for reskinning *system controls that keep their own built-in
  interactive behaviour* (`Button`, `Toggle`); our cells have no independent
  behaviour — they're a pure rendering of state computed by the parent, which is
  exactly the case SwiftUI handles with a content closure (`List`, `ForEach`,
  `Picker` rows). A closure also needs no new type declared by the consumer, and
  reuse across call sites is a plain function passed by name
  (`PinEntryView(pin: $pin, cell: myPinCell)`). The library ships exactly **one**
  default cell, used only by a zero-argument convenience initialiser so
  `PinEntryView(pin:)` renders out of the box — not positioned as "option 1 of a
  supported set." An underlined look, or anything else, is a closure a consumer
  writes; the example app includes one as a recipe, not as shipped library code.
  No baked-in shake/flash animation.
- **State-driven, not imperative:** `PinEntryView` is a `struct View` re-created
  from the parent's state on every render — there is no persistent instance to
  call methods on, so every legacy imperative member is replaced by state the
  parent already owns:
  - No `getPinAsString()`/`getPinAsInt()` — the caller owns `pin: Binding<String>`
    and derives whatever type it needs (`Int(pin)`, etc.) itself.
  - No `clearEntry()` — the caller sets `pin = ""`. Cell highlighting is derived
    from `pin.count`, so an empty string alone renders correctly (all cells
    empty, first cell active); no separate refocus step is needed.
  - No `becomeFirstResponder()`/`resignFirstResponder()` — replaced by a
    parent-owned `@FocusState` binding passed into the view; the parent
    focuses/blurs by setting their own state.
  - No `delegate`/`CBPinEntryViewDelegate` — `entryChanged(_ completed:)` is
    pure duplication once the parent owns `pin` (already observable via
    `.onChange(of: pin)`), so it is dropped. `entryCompleted(with:)` survives as
    one optional convenience closure, `onComplete: (String) -> Void`.
- **Error handling — the library reads it, never writes it:** error is a
  `isError: Binding<Bool>` the view **renders** (cells reflect it via
  `PinEntryCellState.isError`) but **never mutates**, and the view **never clears
  the field** on error. This is deliberate:
  - Whether to wipe digits on a wrong code is *policy* (a lock screen wipes for
    security; a 6-digit OTP where you fat-fingered one digit should let you
    correct in place). Policy is the consumer's: they set `pin = ""` if they
    want a wipe.
  - Because the library never writes `isError`, there is no ordering hazard
    between the library resetting it and the parent setting it (the footgun in
    the "reset on any change" alternative, which was considered and rejected).
    The mental model is dead simple: *`isError` is the consumer's; the view
    paints cells red when it's true.*
  - "Typing dismisses the error" is a nice touch but opinionated, so it's **not**
    built in; the example shows the one-liner a consumer adds if they want it:
    `.onChange(of: pin) { if !pin.isEmpty { isError = false } }`.
- **Input filtering vs. correctness validation:** `AllowedEntryType` owns
  *input filtering* (which characters are permitted) — pure, synchronous,
  unopinionated, and the library's job. **Correctness validation** ("is this the
  right code?") is the consumer's, via `onComplete`; a dedicated `validate`
  closure was **considered and rejected** because it would force the library to
  own *when* to validate and *what the result does*, and correctness checks are
  usually async (network) — none of which a leaf control should own.
  `onComplete: (String) -> Void` already expresses it cleanly (sync or async),
  keeping `isError` consumer-owned. If the four `AllowedEntryType` cases ever
  prove limiting, the clean extension is a `.custom(CharacterSet)` case, not a
  general validate closure (deferred — YAGNI).
- **Real types over legacy IB workarounds:** `keyboardType` is exposed as a
  genuine `UIKeyboardType` (default `.numberPad`) via `.pinKeyboardType(_:)`,
  instead of the legacy raw `Int` — that encoding only existed because old
  `@IBInspectable` couldn't hold a real enum. Capitalisation is exposed via
  `.pinTextInputAutocapitalization(_:)` taking SwiftUI's native
  `TextInputAutocapitalization` rather than bridging the legacy
  `UITextAutocapitalizationType`. (Both are owned `pin`-prefixed modifiers — see
  Design, not the standard SwiftUI ones, for the override-precedence reason given
  there; both tie the API to UIKit-backed types, which is fine for an iOS-only
  component but forecloses a future multiplatform target — an accepted trade.)
- **Minimum iOS: 16.0.** Nothing in the design requires 17 — the core is
  binding-driven (no `@Observable`), and `@FocusState`, `.oneTimeCode`, and
  `TextField` all exist on 16. 16 widens open-source reach at effectively zero
  design cost; the two-parameter `onChange(of:)` is the only 17-ism and is
  trivially handled with the 16 signature. The example app targets iOS 17 to
  showcase the `@Observable` feature-model pattern.
- **Example & tests:** Rewrite the demo app in SwiftUI; add unit tests. **No
  snapshot tests** — and the reason is *not* the zero-dependency rule:
  `swift-snapshot-testing` would be a **test-target** dependency, which does not
  propagate to consumers, so it wouldn't burden them. It's a deliberate
  maintenance choice — for a solo-maintained leaf control, snapshot flakiness and
  CI-simulator pinning outweigh the benefit. Light/dark and per-state cell
  rendering are verified **manually** against the example app. The "never freeze a
  `Color`" rule is kept as a **documented convention**, not an asserted test:
  passing SwiftUI `Color` values directly (never snapshotting to `CGColor`) makes
  the frozen-appearance bug nearly unreachable in the new architecture, and a
  light-vs-dark-resolution assertion would be a weak proxy (a dynamic colour may
  legitimately resolve equal across appearances, so `light != dark` tests the
  palette's contrast, not the colour's adaptivity).
- **Distribution: SPM only.** CocoaPods is in formal wind-down and Carthage is
  dead; a podspec for a new SwiftUI rewrite would be pure liability.

## Behaviour to preserve

Reference: `CBPinEntryView/Classes/CBPinEntryView.swift` +
`CBPinEntryViewDefaults.swift` (the clean CocoaPods copy).

- Configurable `length` (default 4) and `spacing` (10).
- Two visual styles: boxed (full border) and underlined. The *capability* is
  preserved as a cell content closure — not a special-cased boolean mode. The
  library ships the boxed default only; the underlined look is an example-app
  recipe (a closure a consumer writes). The legacy `isUnderlined: Bool` property
  is **not** carried over.
- Per-state styling. The legacy defaults (normal background white, text
  `darkText`, corner radius 3, border width 1, default border `.clear`, editing
  border `rgb(69,78,86)`, editing background `rgb(135,154,168)`, filled
  background `.clear`, error border `.red`, font system 16) are **modernised**,
  not reproduced verbatim: `DefaultPinEntryCell`'s defaults use **semantic
  system colours** that adapt to light/dark, and a **scalable font** rather than
  fixed 16pt. Pixel-parity with the old frozen palette is explicitly *not* a
  goal (it conflicts with the adaptive-colour hard rule). The individual
  colour/corner-radius/border/font values remain configurable on
  `DefaultPinEntryCell`'s initialiser for consumers who want to tweak without
  writing a cell from scratch.
- Secure entry (`isSecure`) with customisable `secureCharacter` (default `●`).
  Now backed by `SecureField` (see Decisions → Secure entry); `secureCharacter`
  is still the glyph drawn by the cell overlay, so customisation is preserved.
- Allowed entry types: `any` / `numerical` / `alphanumeric` / `letters`.
- Keyboard type (default `.numberPad`) as a real `UIKeyboardType`.
- Autofill / capitalisation: `.oneTimeCode` content type, capitalisation.
- Error mode: expressed as `isError: Binding<Bool>` the view renders but never
  writes (see Decisions). "Cleared on resign / new input" is now a consumer
  choice (the documented one-liner), not built-in.
- Read the pin: via direct binding access (`pin`), not `getPinAsString()`/
  `getPinAsInt()`.
- Reset / focus: `pin = ""` to clear; a parent-owned `@FocusState` binding to
  focus/blur.
- Delegate: `entryCompleted(with:)` → optional `onComplete` closure.
  `entryChanged(_:)` and the protocol are dropped (derivable via
  `.onChange(of: pin)`).

## Accessibility behaviour

A defined part of the component contract, not left to the consumer. The
accessibility element is owned by the library and lives on the field, so **a
custom `cell` closure cannot break any of the guarantees below** — every look
inherits them.

**Accessibility element model**

- The component exposes exactly **one** accessibility element: the input field.
  The cell overlay is `accessibilityHidden(true)` — VoiceOver never lands on the
  individual cells, so users interact with one coherent field, not N mystery
  buttons.
- The whole cell stack is the single tap/hit target (trivially ≥44×44pt); a tap
  anywhere on it focuses the field. Individual cell dimensions are therefore
  purely *visual* — there is no per-cell minimum-tap-target requirement.

**Label, value, traits**

- **Label:** configurable via `accessibilityLabel` (default localised
  "PIN code").
- **Value:** reports progress as "N of M entered", updated live as `pin`
  changes; empty reads as "empty" / "0 of M"; a full pin reads as complete.
- **Secure entry:** the value reports the **count only** — never the entered
  characters and never the mask glyph. `SecureField` suppresses VoiceOver's
  per-character typing echo at the platform level, so this is **enforced by the
  OS**, not merely asserted by our accessibility value.
- **Hint (optional):** "Enter your M-digit code."

**Focus & activation**

- A tap anywhere on the cell stack focuses the field; VoiceOver activation
  (double-tap) focuses it and raises the keyboard.
- Programmatic focus via the parent `@FocusState` binding moves system/VoiceOver
  focus accordingly.
- `.oneTimeCode` autofill and paste work under VoiceOver (inherited from the
  real `TextField`).

**State without colour (WCAG 1.4.1)**

- Focus, filled, and error states are distinguishable **without relying on hue**.
  `DefaultPinEntryCell` differentiates them by border weight / fill / content as
  well as colour.
- Error is surfaced to assistive technology through the field's accessibility
  value (e.g. appends "error"), guaranteed by the library regardless of the cell
  look. `CLAUDE.md` reminds consumers that custom cells' *visual* error state
  should likewise not be colour-only.

**Dynamic Type**

- `DefaultPinEntryCell` uses a font **relative to a text style** (scales with the
  user's setting), never a fixed point size — the legacy fixed 16pt is treated as
  a bug, not a spec.
- Cells fill the available width equally (as the legacy `.fillEqually` stack did)
  **when they fit**, down to a **minimum legible cell width** derived from the
  scaled font. Layout is chosen by `ViewThatFits(in: .horizontal)` (iOS 16):
  primary is the equal-width `HStack`; when the cells can no longer fit at their
  minimum legible width (long code and/or largest accessibility sizes), it falls
  back to a **horizontal `ScrollView`** of minimum-width cells, with
  `ScrollViewReader` keeping the active cell in view. Only the visual cell overlay
  scrolls; the invisible input field stays pinned to the component bounds (see
  Input mechanism), so focus, tap-to-focus, and the single AX element are
  unaffected by scroll offset. The glyph **never shrinks**
  (no `minimumScaleFactor`), so legibility is always preserved — the stated
  priority — and text **never clips** in either branch. A vertical/column fallback
  was rejected: a single column of cells does not read as a code and grows tall;
  the row model is preserved by scrolling instead. Overflow handling is
  **library-owned** (it is an accessibility concern, like the AX element itself),
  not delegated to the consumer's cell closure or exposed as a layout-axis knob.

**Motion**

- The library ships no animation, so the default experience has **no motion to
  reduce**. Custom cell closures that animate must honour
  `accessibilityReduceMotion` (documented in `CLAUDE.md`; not enforceable by the
  library).

**Secure-entry privacy**

- In secure mode the source of truth is a `SecureField`, so the entry gets full
  `isSecureTextEntry` OS protection: redaction from screenshots and screen
  recording, no predictive-text caching, and suppressed VoiceOver echo. The cell
  overlay renders `secureCharacter` for the visible mask; the raw pin is never
  shown or read aloud.
- Remaining honest caveat: the pin is exposed to the consumer as a plain `String`
  binding **by design** (the consumer must read the value to verify it), so it
  necessarily lives in memory as a `String` — `isSecureTextEntry` protects the
  display and input surface, not the consumer's copy of the value. Dictation is
  also unavailable in secure mode. Both are accepted and documented.

**Layout direction**

- Cells follow the environment layout direction; entered characters render in
  input order.

## Improvements (intentional)

- **Fix multi-character paste**: pasting a full code fills all cells (one
  `@Binding` holds the whole string).
- **Correct backspace / focus** as an explicit quality bar — the core value
  proposition of the rewrite.
- **First-class accessibility**: VoiceOver progress announcements, decorative
  cells hidden, Dynamic Type, error not conveyed by colour alone (see
  Decisions). This is new versus the legacy view, which had none.
- **Configurable haptics** on entry, completion, and error.
- **Adaptive colour**: SwiftUI `Color` rendered directly so asset/semantic
  colours track light/dark automatically.
- **Customisable cell rendering** via a plain `@ViewBuilder` closure over
  `PinEntryCellState` (consumer-owned animations, e.g. shake-on-error) — no
  protocol, no environment key.
- **API simplification**: dropping the delegate protocol and four imperative
  methods in favour of state the parent already owns; a `TextField`-sized init
  plus `pin`-prefixed builder modifiers for behavioural config; `keyboardType` as
  a real `UIKeyboardType` and the native `TextInputAutocapitalization`; `isError`
  as a read-only-to-the-library binding with no ordering footgun.
- **Single source of truth**: one clean source tree; delete the divergent/broken
  copies, `Extensions.swift`, and the `IQKeyboardManager` reference.

## Design

Module name stays `CBPinEntryView` so `import CBPinEntryView` keeps working. The
new (and only) public view is `PinEntryView`.

### Input mechanism

One real, invisible-but-focusable field is the single source of truth —
`SecureField` when `isSecure`, otherwise `TextField` (chosen once at view
creation; see Decisions → Secure entry) — with an `HStack` of cells overlaid,
rendered from the current characters. The field is bound to a **derived binding**
whose setter runs the pure reducer (sanitise + truncate to `length`) before
assigning the consumer's `pin` — so **user-entered** input (typing, paste,
autofill) always reaches the consumer's binding valid and capped, with no
write-back round trip. This guardrail covers only writes that flow *through*
the field; a value the consumer assigns to `pin` directly bypasses it
entirely and is rendered best-effort (see "Programmatic assignment" below) —
the two are different write paths, not a contradiction. This binding is implemented
as a named `Binding<String>` extension (e.g. `.sanitising(length:allowedEntry:)`),
not an inline `Binding(get:set:)` at the call site — an encapsulated, accepted
exception to the modern-SwiftUI "no inline `Binding(get:set:)`" rule, which
targets optional/presentation derivations rather than transforming setters. The field is made invisible
by **clear content only** — clear text foreground and clear tint (caret) — while
remaining **full-alpha and laid out within the component's bounds**, behind the
overlay and co-located with the *component* (not with individual cells). It is
**never** `.hidden()`, `.opacity(0)`, zero-framed, or
pushed off-screen: any of those breaks the responder chain, `.oneTimeCode`
autofill, or accessibility (a normative rule, also called out in `CLAUDE.md`, so a
later "tidy-up" cannot silently kill autofill or focus). A per-cell blinking caret
is not shipped, but a consumer can render one in their closure using
`PinEntryCellState.isFocused`. Focus is driven by `@FocusState` and a tap gesture spanning the
component's bounds (not tied to any individual cell); the field itself is
`.allowsHitTesting(false)` and the overlay is `accessibilityHidden(true)`. In the
horizontal-scroll fallback (see Dynamic Type) the field **fills the component
bounds and does not itself scroll** — only the visual cell overlay scrolls — so
focus and the single AX element, both on the stable field, stay independent of the
scroll offset. `.onChange(of: pin)` fires `onComplete` and haptics
only — never mutates `pin` or `isError`. Keyboard, backspace, paste, and
`.oneTimeCode` autofill come from iOS defaults (dictation too, in the non-secure
branch).

`onComplete` semantics: fires **once** when the pin transitions from fewer than
`length` characters to exactly `length`. The transition decision is a pure
reducer function, `didComplete(from:to:length:)`, so it is unit-tested directly;
the view holds only a `@State previousPin` as memory and calls the reducer from
`.onChange(of: pin)` (the same decision also triggers the completion haptic — one
source of truth). It does not refire on subsequent no-op keystrokes into a full
field (truncation rejects them, so the value does not change). If the user
deletes below `length` and re-fills, it fires again. Because the binding cannot
distinguish a user edit from a programmatic set, a paste, `.oneTimeCode`
autofill, **or a consumer assigning a full value directly** all fire it once —
this is intended (completing the code is the event, however it arrives).

Oversize input is handled by **sanitising before truncating**, then keeping the
leading `length` characters. Order matters: a paste like `"12-34-56"` into a
6-digit numerical field must sanitise to `"123456"` *then* fit, not truncate to
`"12-34-"` first (which would sanitise to only four digits). After sanitising,
any overflow is chopped from the **end** (`prefix(length)`), which also does the
right thing mid-entry — existing digits stay at the front and the paste fills the
remainder. Truncating an over-length paste is the one case where the corrected
value is written back into the field (which briefly held the longer string); this
residual write-back is on the device-test checklist for flash/caret jump.

Programmatic assignment is **best-effort**, matching `TextField`'s model (the
control renders what is set): sanitisation and truncation apply to *user input*
only, not to a value the consumer assigns to `pin` directly. An injected value
that violates the allowed type or exceeds `length` is rendered as-is across the
`length` cells (only the first `length` characters are shown; the overflow is
neither displayed nor stripped from the consumer's binding — stripping would hide
their bug and desync their state). Completion callbacks are guaranteed only for
values within the allowed type and no longer than `length`. Separately, with a
hardware keyboard the insertion point can be moved mid-string with arrow keys; the
entered value stays correct, but because the active cell is derived from
`pin.count` (an end-insertion assumption) the active-cell highlight can momentarily
mismatch. Pure SwiftUI `TextField` offers no clean selection control, so this is a
documented minor limitation rather than a reason to adopt a `UIViewRepresentable`.

### New files — `Sources/CBPinEntryView/`

- **`PinEntryView.swift`** — public SwiftUI view, generic over its cell content.
  The initialiser is kept `TextField`-sized (structural + always-relevant params
  only); all behavioural configuration is applied via modifiers (below):
  ```swift
  struct PinEntryView<CellContent: View>: View {
      init(
          pin: Binding<String>,
          length: Int = 4,
          spacing: CGFloat = 10,
          isError: Binding<Bool> = .constant(false),
          accessibilityLabel: String? = nil,   // default localised "PIN code"
          onComplete: ((String) -> Void)? = nil,
          @ViewBuilder cell: @escaping (PinEntryCellState) -> CellContent
      )
  }

  extension PinEntryView where CellContent == DefaultPinEntryCell {
      init(
          pin: Binding<String>,
          length: Int = 4,
          spacing: CGFloat = 10,
          isError: Binding<Bool> = .constant(false),
          accessibilityLabel: String? = nil,
          onComplete: ((String) -> Void)? = nil
      ) // supplies DefaultPinEntryCell as `cell`, so PinEntryView(pin:) alone works
  }
  ```
  **Configuration is owned by the control and applied via builder-style modifiers
  that return `Self`** (copy-and-mutate the struct — no environment keys, no extra
  types): `.pinAllowedEntry(_:)`, `.pinSecure(_:character:)`,
  `.pinKeyboardType(_:)`, `.pinTextContentType(_:)`,
  `.pinTextInputAutocapitalization(_:)`, `.pinHaptics(_:)`, `.pinFocused(_:)`. All
  are `pin`-prefixed deliberately.

  *Why owned, and why not the standard modifiers:* a wrapper cannot give a
  propagating standard text modifier (`.keyboardType`, `.textContentType`,
  `.textInputAutocapitalization`) an *overridable default*. Environment text
  modifiers resolve closest-to-the-field-wins, and the internal field is always
  closer than anything a consumer wraps around `PinEntryView` — so an internal
  default silently beats the consumer's standard modifier, while omitting the
  default loses number-pad / `.oneTimeCode` out of the box. The control therefore
  owns these through `pin`-prefixed modifiers, and the README documents that
  standard `.keyboardType`/etc. do **not** configure the field. The `pin`-prefix
  (rather than shadowing the standard names) makes it unmistakable the modifier
  must sit on the `PinEntryView`, avoiding the `.padding().keyboardType(…)`-does-
  nothing footgun. Chaining rule: apply `pin`-modifiers before any type-erasing
  standard modifier.

  Focus is a **parent-supplied `FocusState<Bool>.Binding`** via `.pinFocused($x)`
  (the binding is stored and applied with `.focused(_:)` internally), with an
  internal `@FocusState` fallback when unspecified — **never** a
  `Bool`-to-`@FocusState` bridge (that reintroduces the sync-ordering fragility).
  `spacing` controls the `HStack`'s inter-cell spacing and stays an init parameter
  (structural, not threaded through `cell`); `accessibilityLabel` is an init
  parameter defaulting to the localised "PIN code". Holds the invisible field with
  the derived sanitising binding; calls `cell(_:)` once per index; wires the
  accessibility element (label + progress value; count-only for secure; error
  surfaced non-visually).
- **`PinEntryCellState.swift`** — the non-opinionated customisation point: a
  plain public struct exposing `character: String?` (**already masked** when
  secure — the raw digit is never handed to the cell), `index: Int`,
  `isFocused: Bool`, `isFilled: Bool`, `isError: Bool`. Passed into the `cell`
  closure. Pre-masking is deliberate: the cell overlay is what is actually on
  screen (the secure field itself is invisible), so it is *not* covered by the
  `isSecureTextEntry` screenshot redaction from Decisions → Secure entry — handing
  a custom cell the raw character would let it paint real digits into a
  screenshot-visible layer and defeat that protection. Peek-last-digit is
  therefore **intentionally unsupported** in secure mode, a consequence of the
  redaction guarantee rather than an arbitrary limitation. `isSecure` is
  deliberately *not* on the state: it is fixed per instance, so a consumer
  authoring a cell already knows whether it is secure and bakes any
  secure-specific styling into the closure directly — adding the flag later is a
  safe additive change if a shared-closure need ever arises (YAGNI).
- **`DefaultPinEntryCell.swift`** — a small, ordinary `View` matching a modern
  box look, configurable via initialiser (colours per state, corner radius,
  border width, font). Uses **semantic system colours** and a **scalable font**
  by default. Used automatically by the zero-cell-argument convenience
  initialiser, and reusable inside a consumer's own closure for minor tweaks
  (`DefaultPinEntryCell(state: state, backgroundColor: .gray)`).
- **`AllowedEntryType.swift`** — public enum `any`/`numerical`/`alphanumeric`/
  `letters` with a pure `func sanitize(_ input: String) -> String` (per-character
  filtering — robust for paste).
- **`PinEntryReducer.swift`** — pure logic, the unit-tested core:
  `reduce(_:length:allowedEntry:)` (**sanitise first, then truncate** — order
  matters, see `onComplete` semantics; sanitising needs `allowedEntry` since
  what counts as a stray character depends on it), `isComplete`,
  `didComplete(from:to:length:)` (the
  completion-transition decision, lifted out of the view so it is testable), and
  `maskedDisplay` (secure). Truncation keeps the **leading** `length` characters
  (`prefix(length)`), dropping any overflow at the end.
- **`PinEntryHaptics.swift`** — thin wrapper over `UIFeedbackGenerator` for
  entry / completion / error events, gated by the configurable haptics flag,
  `prepare()`d for latency.

There is **no** `Legacy/` directory and **no** `PinEntryCellRepresentable` /
`cellType` machinery — those belonged to the rejected shim.

### Tests — `Tests/CBPinEntryViewTests/`

Swift Testing (`@Test`/`@Suite`), targeting real logic only:

- `AllowedEntryType.sanitize` per case (numerical strips letters, letters strips
  digits, alphanumeric strips symbols, any passes through).
- `reduce` sanitises **before** truncating: `"12-34-56"` into a 6-digit
  numerical field yields `"123456"`, not `"1234"` (the order-of-operations bug).
- `reduce` caps an over-length paste to the leading `length` characters (the
  paste fix), preserving existing leading digits when appending mid-entry.
- `isComplete` detection at `length`.
- `didComplete(from:to:length:)`: true on `<length → ==length`; false on a no-op
  keystroke into a full field; true again after delete-below-then-refill; true
  once for an over-length paste and for a programmatic full-value assignment.
- Secure masking yields `length` mask characters while the raw pin stays intact.

Deliberately no tests for trivial property assignment, SwiftUI view rendering, or
stdlib-guaranteed behaviour. Accessibility and light/dark rendering are verified
manually against the example app (see Verification) — there is no snapshot suite
(a deliberate maintenance choice for a solo-maintained library, not a
dependency-propagation constraint).

### Example — `Example/`

Replace the CocoaPods/storyboard UIKit demo with a SwiftUI app (SwiftUI `App`
lifecycle) depending on the root package as a local SPM package, exercising every
feature: length, secure toggle, error toggle (its own `@State` driving
`isError`, including the optional "typing dismisses error" one-liner),
allowed-type picker, clear (resetting its own `pin`), programmatic focus (via
`@FocusState`), and a custom `cell` closure recipe rendering an underlined look
with a shake-on-error animation (honouring Reduce Motion) — demonstrating the
extensibility point and that the removed underlined preset is trivially
reproducible. It includes:

- An **`@Observable` feature-model screen** — a small `@Observable` model holding
  `pin`, `isError`, and (async) verification, bound into `PinEntryView` — showing
  the modern-SwiftUI pattern applied at the *consumer* layer (the right home for
  Observation).
- A **`UIHostingController` interop screen** — hosting `PinEntryView` from a
  `UIViewController`, proving the documented UIKit migration path works
  end-to-end (replacing what a shim would have provided).

### Repo cleanup / packaging

- Rewrite `Package.swift`: `swift-tools-version: 5.9`,
  `platforms: [.iOS(.v16)]`, library + test target, no dependencies.
- Delete: `CBPinEntryView/Classes/`, `CBPinEntryView/Assets/`, old
  `Sources/CBPinEntryView/{CBPinEntryView,CBPinEntryViewDefaults,Extensions}.swift`,
  `CBPinEntryView.podspec`, `.travis.yml`, the root `_Pods.xcodeproj` symlink,
  and the old CocoaPods-based `Example/` (Podfile, workspace, storyboard, UIKit
  view controller).
- Add `.github/workflows/ci.yml`: build + `xcodebuild test` for the library on
  an iOS 16 simulator, **and separately build/run the example app on an iOS 17
  simulator** (its own higher deployment target, for the `@Observable` demo
  screen — see Decisions → Minimum iOS) so a broken demo fails CI, replacing
  Travis.
- Add `MIGRATION.md`: 1.x → 2.0, mapping every removed API to its replacement
  (delegate → `onComplete` + `.onChange`; `getPinAsString()` → `pin`;
  `getPinAsInt()` → `Int(pin)`; `setError()`/`errorMode` → `isError` binding +
  consumer policy; `clearEntry()` → `pin = ""`; `become/resignFirstResponder()`
  → `@FocusState`; per-state style properties/`isUnderlined` → `cell` closure /
  `DefaultPinEntryCell` init; `allowedEntryTypes` → `.pinAllowedEntry(_:)`;
  `isSecure`/`secureCharacter` → `.pinSecure(_:character:)`; `keyboardType`
  (raw `Int`) → `.pinKeyboardType(_:)` (real `UIKeyboardType`);
  `textContentType`/`textFieldCapitalization` → `.pinTextContentType(_:)`/
  `.pinTextInputAutocapitalization(_:)`; storyboard placement → `PinEntryView`
  in SwiftUI or `UIHostingController` in UIKit, with the recipe).
- Rewrite `README.md`: SPM-only install, `PinEntryView` as the primary path
  (init, `pin`/`isError` bindings, `cell` closure customisation, accessibility
  notes), a short UIKit-via-`UIHostingController` section, a pointer to
  `MIGRATION.md`, refreshed badges/metadata. No leftover CocoaPods/storyboard
  instructions.
- Add `CLAUDE.md` at the repo root.

### CLAUDE.md contents

Overview + guiding principle (robust core incl. accessibility, non-opinionated
customisation); architecture (SwiftUI-only, no UIKit shim, zero dependencies,
iOS 16, pfw patterns applied, state-driven not imperative, `@Observable` at the
consumer layer not the control); file map; public API — `PinEntryView`
(`pin`/`isError` bindings, focus binding, `accessibilityLabel`, `onComplete`, the
`cell` content closure), `PinEntryCellState`, `DefaultPinEntryCell`, the haptics
flag; accessibility contract (field carries label + progress value, count-only
for secure, cells hidden, error not colour-only, Dynamic Type, custom cells
should honour Reduce Motion); colour rule (pass asset/semantic `Color`s, never
freeze to `CGColor`); the invisible-field rule (clear content only; never
`.hidden()`/`.opacity(0)`/off-screen, which would break autofill/focus); why
configuration uses `.pin`-prefixed modifiers (`.pinKeyboardType(_:)`,
`.pinTextContentType(_:)`, etc.) instead of the standard SwiftUI ones — the
override-precedence footgun a standard modifier applied outside `PinEntryView`
would silently lose to; that `.pinSecure(_:)` is fixed per instance and should
not be toggled dynamically after creation (SwiftUI would tear down and rebuild
the underlying field, losing focus); how to
build & test (`swift test` / xcodebuild); how to run
the SwiftUI example; UIKit interop via `UIHostingController`; conventions (no
external dependencies; how to add a new config option across the reducer, view,
default cell; how a consumer writes a custom cell closure with their own
animation and reuses it across call sites; why there is no `validate` closure and
no UIKit shim).

## Verification

- `swift build` and `swift test` from the repo root — package compiles with no
  dependencies; all unit tests pass.
- `xcodebuild build`/`test` for the library against an iOS 16 simulator (the
  package's stated minimum). Build/run the example app separately against an
  iOS 17 simulator, matching its own higher deployment target (needed for the
  `@Observable` feature-model screen, see Decisions → Minimum iOS) — the two
  targets are verified at their own respective minimums, not both at 16.
- Run the SwiftUI example on the simulator and manually confirm each preserved
  behaviour: typing, backspace, paste of a full code fills all cells, secure
  masking, allowed-type restriction, `.oneTimeCode` autofill, reading the pin
  directly from the example's own `@State`, and clearing via `pin = ""` alone
  re-rendering correctly with no separate reset call.
- Confirm the over-length-paste truncation write-back (the one case where the
  corrected value is written back into the field after it briefly held the
  longer string, per Design → Input mechanism) does not visibly flash or jump
  the caret on device.
- Confirm error handling: setting the example's `isError` paints the cells;
  the library never clears the field or flips `isError` itself; the optional
  "typing dismisses error" one-liner works when the example opts in.
- Confirm new capabilities: haptics fire and can be disabled; the default cell
  adapts to light/dark; a custom `cell` closure renders an underlined look and
  animates via `PinEntryCellState`; programmatic focus via the example's own
  `@FocusState`.
- **Secure-mode device gates** (decide whether pure `SecureField` suffices or the
  secure branch needs the `UIViewRepresentable` escape hatch): with `isSecure`
  on, confirm (1) `.oneTimeCode` autofill still surfaces on the `SecureField`,
  and (2) if the field clears on refocus, the `pin` binding clears with it (cells
  re-render empty and correct) rather than the field and binding desyncing. Also
  confirm VoiceOver reads count-only and never echoes typed digits in secure
  mode.
- **Accessibility pass** (first-class, so verified explicitly against the
  Accessibility behaviour contract): with VoiceOver on, the field announces its
  label and progress ("3 of 6"), reports **count only** for secure entry,
  exposes error non-visually, and the cells are not individually focusable (one
  element, one tap target); focus, filled, and error are distinguishable with
  colour filters on (no colour-only state); at the largest Dynamic Type size
  glyphs scale and never clip, and a long code that overflows falls back to a
  horizontal scroll with the active cell scrolled into view (glyphs staying
  legible, never shrunk); in dark mode colours adapt. In the scrolled fallback,
  confirm tap-to-focus and the accessibility tap target keep working while
  scrolled (not just at the initial scroll offset) — the field is pinned to the
  component bounds and does not scroll (see Input mechanism), so this should hold;
  verify it on device. Repeat the pass against a custom `cell` closure to confirm
  accessibility is inherited, not reimplemented.
- Confirm the `@Observable` feature-model example screen works end-to-end
  (including async verification setting `isError`).
- Confirm the `UIHostingController` interop screen hosts `PinEntryView`
  correctly (sizing, focus, keyboard) — the documented UIKit migration path.
- Read the rewritten `README.md` and `MIGRATION.md` end-to-end and confirm every
  code sample compiles against the final API.

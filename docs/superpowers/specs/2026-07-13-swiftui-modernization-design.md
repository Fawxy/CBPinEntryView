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

The repo is also in a broken state that must be cleaned up regardless:

- Two divergent source trees: `CBPinEntryView/Classes/` (CocoaPods, clean) and
  `Sources/CBPinEntryView/` (SPM). The SPM copy does not compile — it references
  `IQKeyboardManager` (undeclared dependency) and ships `Extensions.swift`, ~1700
  lines of unrelated cruft copied from another project.
- Inconsistent version/Swift metadata; stale Travis CI targeting Xcode 7.3.

## Guiding principle

Provide a PIN field with a **correct, robust core** — proper backspace, paste,
focus, and autofill (the behaviours that are broken in so many apps) — that is
**customisable without being opinionated**. Ship sensible defaults; impose no
particular look or animation.

## Decisions

- **Compatibility:** SwiftUI-first, plus a UIKit compatibility shim so existing
  `CBPinEntryView: UIView` / storyboard / delegate consumers still compile.
- **Architecture:** Lightweight, `@Binding`-driven SwiftUI leaf view. No models
  forced on consumers, no external dependencies. Logic extracted into small,
  pure, testable types.
- **Input core:** A single real SwiftUI `TextField` is the source of truth
  (invisible but focusable); cells are drawn from the string binding as an
  overlay. This inherits correct keyboard, backspace, paste, `.oneTimeCode`
  autofill, and dictation from iOS defaults; because the whole pin lives in one
  binding, a pasted full code fills every cell automatically.
- **Haptics:** Configurable (on by default, one flag/modifier to disable), using
  the system `UIFeedbackGenerator`.
- **Dynamic colour:** Style is expressed in SwiftUI `Color`, applied directly in
  the view body so asset-catalog and semantic colours adapt to light/dark
  automatically — no convenience initialiser needed. Defaults use semantic
  system colours. Hard rule: never snapshot a `Color` to `CGColor`/`UIColor`
  (that would freeze the appearance — the bug in the old UIKit code).
- **Customisable look/animation, not opinionated:** Expose cell rendering as a
  `@ViewBuilder` content closure, `(PinEntryCellState) -> some View`, rather
  than a `ButtonStyle`-like protocol. Considered and rejected the protocol
  approach: Apple reserves that pattern for reskinning *system controls that
  keep their own built-in interactive behaviour* (`Button`, `Toggle`); our
  cells have no independent behaviour of their own — they're a pure rendering
  of state computed by the parent — which is exactly the case SwiftUI itself
  handles with a content closure (`List`, `ForEach`, `Picker` rows), not a
  style protocol. A closure also needs no new type declared by the consumer.
  Reuse across multiple `PinEntryView`s is still trivial without any
  library-specific "theme" mechanism — a consumer writes one plain function
  returning `some View` and passes it by name at each call site
  (`PinEntryView(pin: $pin, cell: myPinCell)`); the only capability actually
  lost versus an environment-based style is *silent* inheritance by
  descendants that don't mention it at all, judged not worth the extra
  protocol/environment-key/modifier machinery for a component typically used
  once or twice per screen. The library ships exactly **one** default cell
  view, used only by a zero-argument convenience initialiser so
  `PinEntryView(pin:)` renders something out of the box — not positioned as
  "option 1 of a supported set." An underlined look, or anything else, is a
  closure a consumer writes themselves; the example app includes one as a
  recipe, not as shipped library code. No baked-in shake/flash animation.
- **State-driven, not imperative:** `PinEntryView` is a `struct View` re-created
  from the parent's state on every render — there is no persistent instance to
  call methods on, so every legacy imperative member is replaced by state the
  parent already owns:
  - No `getPinAsString()`/`getPinAsInt()` — the caller owns `pin: Binding<String>`
    and derives whatever type it needs (`Int(pin)`, etc.) itself.
  - No `clearEntry()` — the caller sets `pin = ""`. Cell highlighting is derived
    from `pin.count`, so an empty string alone renders correctly (all cells
    empty, first cell active); no separate refocus step is needed.
  - No `setError(isError:)`/`errorMode` getter — replaced by a two-way
    `isError: Binding<Bool>` parameter. The view flips it back to `false` on
    **any** change to `pin` (typed or set externally by the parent), which
    reproduces both legacy behaviours at once — "typing clears error" and
    "clearing clears error" — with one `onChange` handler and no dedicated
    method. The parent sets it `true` the same way it sets any other `@State`.
  - No `becomeFirstResponder()`/`resignFirstResponder()` — replaced by a
    parent-owned `@FocusState` binding passed into the view; the parent
    focuses/blurs by setting their own state.
  - No `delegate`/`CBPinEntryViewDelegate` — `entryChanged(_ completed:)` is
    pure duplication once the parent owns `pin` (already observable via
    `.onChange(of: pin)`), so it is dropped entirely. `entryCompleted(with:)`
    survives as one optional convenience closure, `onComplete: (String) -> Void`
    — genuinely optional (derivable via `.onChange(of: pin)` + a length check)
    but worth keeping so callers don't have to re-derive "pin reached full
    length" themselves.
  All of the above are preserved on the legacy UIKit shim, where they are a
  real backwards-compatibility requirement (old call sites are class instances
  holding no state of their own).
- **Real types over legacy IB workarounds:** `keyboardType` becomes a genuine
  `UIKeyboardType` parameter (default `.numberPad`) instead of the legacy raw
  `Int` — that raw-int encoding only existed because old `@IBInspectable` couldn't
  hold a real enum, a constraint that doesn't apply to SwiftUI. Similarly,
  capitalisation is applied via SwiftUI's native `.textInputAutocapitalization(_:)`
  modifier (`TextInputAutocapitalization`) rather than bridging the legacy
  `UITextAutocapitalizationType`.
- **Minimum iOS:** 17.0.
- **Example & tests:** Rewrite the demo app in SwiftUI; add unit tests (no
  snapshot tests).
- **Distribution:** SPM only.

## Behaviour to preserve

Reference: `CBPinEntryView/Classes/CBPinEntryView.swift` +
`CBPinEntryViewDefaults.swift` (the clean CocoaPods copy).

- Configurable `length` (default 4) and `spacing` (10).
- Two visual styles: boxed (full border) and underlined. The *capability* is
  preserved — either look (or any other) is achievable as a cell content
  closure — but neither is a boolean mode baked into `PinEntryView`; see the
  Design section. The legacy `isUnderlined: Bool` property itself is preserved
  only on the UIKit shim, for backwards compatibility.
- Per-state styling with these defaults: normal background white, text
  `darkText`, corner radius 3, border width 1, default border `.clear`, editing
  border `rgb(69,78,86)`, editing background `rgb(135,154,168)`, filled
  background (`filledEntryColour`, default `.clear`), error border `.red`, font
  system 16. These become `DefaultPinEntryCell`'s own default initialiser
  values (see Design) — a consumer who wants a few colours tweaked can
  instantiate it directly inside their own closure with different arguments,
  without needing to build a look from scratch.
- Secure entry (`isSecure`) with customisable `secureCharacter` (default `●`).
- Allowed entry types: `any` / `numerical` / `alphanumeric` / `letters`.
- Keyboard type (default `.numberPad`); real `UIKeyboardType` on the new view,
  legacy raw `Int` preserved on the shim only (see Decisions).
- Autofill / capitalisation: `.oneTimeCode` content type, capitalisation.
- Error mode: cleared on resign / new input. On the new view this is
  `isError: Binding<Bool>` (see Decisions); `setError(isError:)`/`errorMode`
  preserved as methods/properties on the legacy shim only.
- Read: `getPinAsString()`, `getPinAsInt()` — preserved on the legacy shim only;
  superseded on the new view by direct binding access (see Decisions).
- Reset / focus: preserved as capabilities — the new view accepts `pin = ""` to
  clear and a parent-owned `@FocusState` binding to focus/blur. `clearEntry()`,
  `becomeFirstResponder()`, `resignFirstResponder()` as named methods are
  preserved on the legacy shim only.
- Delegate: `entryCompleted(with:)` survives as an optional `onComplete`
  closure on the new view. `entryChanged(_ completed:)` and the delegate
  protocol itself are dropped from the new view (see Decisions) but preserved
  on the legacy shim.

## Improvements (intentional)

- **Fix multi-character paste**: pasting a full code fills all cells. The
  SwiftUI view holds the whole string in one `@Binding`, so paste distributes
  correctly for free (today, only the currently-active cell receives pasted
  text).
- **Correct backspace / focus** as an explicit quality bar — the core value
  proposition of the rewrite.
- **Configurable haptics** on entry, completion, and error.
- **Adaptive colour**: accept SwiftUI `Color` and render it directly so
  asset/semantic colours track light/dark automatically.
- **Customisable cell rendering** via a plain `@ViewBuilder` closure over
  `PinEntryCellState` (user-owned animations, e.g. shake-on-error or fill
  transitions) — no protocol to declare, no environment key.
- **API simplification**: dropping the delegate protocol and four imperative
  methods (`clearEntry`, `setError`, `becomeFirstResponder`,
  `resignFirstResponder`) from the new view in favour of state the parent
  already owns (bindings + `@FocusState`) — see "State-driven, not imperative"
  in Decisions. Also: `keyboardType` becomes a real `UIKeyboardType` instead of
  a raw `Int`, and capitalisation uses SwiftUI's native
  `.textInputAutocapitalization(_:)` instead of bridging a UIKit type.
- **Single source of truth**: one clean source tree; delete the
  divergent/broken copies and the `Extensions.swift` cruft +
  `IQKeyboardManager` reference.
- Modernise `CBPinEntryViewDelegate: class` → `AnyObject`.

## Design

Module name stays `CBPinEntryView` so `import CBPinEntryView` keeps working. The
new SwiftUI view is named `PinEntryView`.

### Input mechanism

One real, invisible-but-focusable `TextField` bound to the pin string is the
single source of truth; an `HStack` of cells is overlaid, rendered from the
current characters of the binding. Focus is driven by `@FocusState` and a tap
gesture on the cell stack (the field itself needn't be tappable). `.onChange(of:)`
runs a pure reducer (sanitise + truncate) and fires completion callbacks.
Keyboard, backspace, paste, `.oneTimeCode` autofill, and dictation all come from
iOS defaults — this is what fixes the paste bug and guarantees correct backspace
behaviour without bespoke keystroke handling.

### New files — `Sources/CBPinEntryView/`

- **`PinEntryView.swift`** — public SwiftUI view, generic over its cell content:
  ```swift
  struct PinEntryView<CellContent: View>: View {
      init(
          pin: Binding<String>,
          length: Int = 4,
          spacing: CGFloat = 10,
          isError: Binding<Bool> = .constant(false),
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
          onComplete: ((String) -> Void)? = nil
      ) // supplies DefaultPinEntryCell as `cell`, so PinEntryView(pin:) alone works
  }
  ```
  Plus a parent-suppliable `FocusState<Bool>.Binding` for programmatic
  focus/blur (exact plumbing — init parameter vs. `.focused(_:)`-style modifier
  — decided during implementation). `spacing` controls inter-cell layout (the
  `HStack`'s spacing), not a single cell's own rendering, so it stays a plain
  initialiser parameter rather than something threaded through `cell`. Further
  behavioural options (allowed type, secure, keyboard type, content type,
  capitalisation, haptics on/off) via initialiser params and/or view modifiers.
  Holds the invisible `TextField`; calls `cell(_:)` once per index to render
  each cell. `.onChange(of: pin)` runs the reducer and resets `isError` to
  `false` on any change.
- **`PinEntryCellState.swift`** — the non-opinionated customisation point: a
  plain public struct (not a protocol) exposing `character: String?` (already
  masked when secure), `index: Int`, `isFocused: Bool`, `isFilled: Bool`,
  `isError: Bool`. Passed into the `cell` closure; the consumer's closure body
  is free to branch on these and apply whatever modifiers/animations they like
  — no type to declare, no conformance.
- **`DefaultPinEntryCell.swift`** — a small, ordinary `View` (not a style
  conformance) matching the legacy default box look, configurable via
  initialiser (colours per state, corner radius, border width, font). Used
  automatically by the zero-cell-argument convenience initialiser above,
  and reusable directly inside a consumer's own closure for minor tweaks
  (`DefaultPinEntryCell(state: state, backgroundColor: .gray)`) without
  building a look from scratch. An underlined look is demonstrated only in the
  example app, as a plain closure a consumer writes themselves (see Example
  section).
- **`AllowedEntryType.swift`** — public enum `any`/`numerical`/`alphanumeric`/
  `letters` with a pure `func sanitize(_ input: String) -> String`
  (per-character filtering — robust for paste; this is an improved semantic
  over the old whole-string scan).
- **`PinEntryReducer.swift`** — pure logic, plain functions/struct (logic
  extracted out of the view, no Observation needed): sanitise + truncate to
  length, `isComplete`, and `maskedDisplay` (secure). This is the unit-tested
  core.
- **`PinEntryHaptics.swift`** — thin wrapper over `UIFeedbackGenerator` for
  entry / completion / error events, gated by the configurable haptics flag.

### Compatibility shim — `Sources/CBPinEntryView/Legacy/CBPinEntryView.swift`

- `open class CBPinEntryView: UIView` hosting `PinEntryView` via
  `UIHostingController` (added as a hosted subview). Re-exposes the full legacy
  API — all former `@IBInspectable` properties, `CBPinEntryViewDelegate` (now
  `AnyObject`), `allowedEntryTypes`, `textContentType`,
  `textFieldCapitalization`, `errorMode`, `getPinAsString()/getPinAsInt()`,
  `setError(_:)`, `clearEntry()`, `become/resignFirstResponder()`, and the
  legacy raw-`Int` `keyboardType` — even though the new `PinEntryView` itself no
  longer has these. This is the shim's whole purpose: bridge the old imperative
  surface onto the new state-driven one.
- Internally holds its own `@State` pin string, `@State` error flag, and
  `@FocusState`, wired to the hosted `PinEntryView`'s bindings. Maps legacy
  `UIColor`/`UIFont` properties into `DefaultPinEntryCell`'s initialiser, maps
  the legacy raw `Int` `keyboardType` into the real `UIKeyboardType`, and
  forwards binding changes to the delegate to reproduce
  `entryChanged`/`entryCompleted`. For `isUnderlined = true` the shim supplies
  its own small cell closure private to `Legacy/` (not part of the public
  library API) that reproduces the old underlined look — since the public
  library no longer ships an underlined look, this bit of legacy-only
  rendering code lives solely here, scoped to backwards compatibility.
- Keeps `@IBInspectable` so storyboard property-setting works at runtime.
  Note: `@IBDesignable` *live* Interface Builder rendering is not preserved
  (SwiftUI hosted content) — the one accepted, documented regression.

### Tests — `Tests/CBPinEntryViewTests/`

Swift Testing (`@Test`/`@Suite`), targeting real logic only:

- `AllowedEntryType.sanitize` per case (numerical strips letters, letters
  strips digits, alphanumeric strips symbols, any passes through).
- Sanitise + truncate caps over-length paste to `length` (the paste fix).
- `isComplete` detection at `length`.
- Secure masking yields `length` mask characters while the raw pin stays
  intact.

Deliberately no tests for trivial property assignment, SwiftUI view rendering,
or stdlib-guaranteed behaviour (e.g. `Int("abc")` returning `nil` is a standard
library guarantee, not project logic — the legacy shim's `getPinAsInt` needs no
dedicated test). Those are covered by manual verification of the example app
instead.

### Example — `Example/`

Replace the CocoaPods/storyboard UIKit demo with a SwiftUI app (SwiftUI `App`
lifecycle) that depends on the root package as a local SPM package and
exercises every feature: length, secure toggle, error toggle (via its own
`@State` driving `isError`), allowed-type picker, clear (by resetting its own
`pin` state), programmatic focus (via `@FocusState`), and a custom `cell`
closure recipe rendering an underlined look — demonstrating both the
extensibility point and that the removed underlined preset is trivially
reproducible by a consumer, reused across more than one call site by
referencing the same function.

### Repo cleanup / packaging

- Rewrite `Package.swift`: `swift-tools-version: 5.9`,
  `platforms: [.iOS(.v17)]`, library + test target, no dependencies.
- Delete: `CBPinEntryView/Classes/`, `CBPinEntryView/Assets/`, old
  `Sources/CBPinEntryView/{CBPinEntryView,CBPinEntryViewDefaults,Extensions}.swift`,
  `CBPinEntryView.podspec`, `.travis.yml`, the root `_Pods.xcodeproj` symlink,
  and the old CocoaPods-based `Example/` (Podfile, workspace, storyboard, UIKit
  view controller).
- Add `.github/workflows/ci.yml`: build + `xcodebuild test` on an iOS 17
  simulator, replacing Travis.
- Update `README.md`: SPM-only install, SwiftUI usage as the primary path plus
  a legacy UIKit section; refresh badges/metadata.
- Add `CLAUDE.md` at the repo root.

### CLAUDE.md contents

Overview + guiding principle (robust core, non-opinionated customisation);
architecture (SwiftUI-first + UIKit shim, zero dependencies, iOS 17, pfw
patterns applied, state-driven not imperative); file map; public API — SwiftUI
`PinEntryView` (`pin`/`isError` bindings, focus binding, `onComplete`, the
`cell` content closure), `PinEntryCellState`, `DefaultPinEntryCell`, the
haptics flag, and the legacy `CBPinEntryView`; note that colours track
light/dark automatically (pass asset/semantic `Color`s); how to build & test
(`swift test` / xcodebuild); how to run the SwiftUI example; conventions (no
external dependencies, iOS defaults; how to add a new config option in the
reducer, the SwiftUI view, the default cell, and the shim; how a consumer
writes a custom cell closure with their own animation, e.g. reproducing an
underlined look, and how to reuse one closure across multiple `PinEntryView`
call sites by extracting it to a plain function).

## Verification

- `swift build` and `swift test` from the repo root — package compiles with no
  dependencies; all unit tests pass.
- `xcodebuild build`/`test` against an iOS 17 simulator for the library and the
  example app.
- Run the SwiftUI example on the simulator and manually confirm each preserved
  behaviour: typing, backspace, paste of a full code fills all cells, secure
  masking, error state (`isError` binding, auto-clears on new input or on
  clearing), allowed-type restriction, `.oneTimeCode` autofill, and reading the
  pin directly from the example's own `@State`.
- Confirm the new capabilities: haptics fire and can be disabled; the default
  cell adapts to light/dark; a custom `cell` closure in the example renders an
  underlined look and animates using the exposed `PinEntryCellState`;
  programmatic focus via the example's own `@FocusState`; clearing via
  `pin = ""` alone re-renders correctly with no separate reset call.
- Sanity-check the shim compiles against the old call sites (the former
  `ViewController` usage: outlet + delegate + `getPinAsString`/`setError`/
  `clearEntry`/`resignFirstResponder`) and that `isUnderlined` still renders the
  legacy underlined look via the shim's private cell closure.

# Migrating from 1.x to 2.0

CBPinEntryView 2.0 is a complete SwiftUI rewrite. The UIKit `CBPinEntryView` class, its delegate protocol, and CocoaPods distribution are gone. There is no UIKit compatibility shim.

If you need to keep using it from a `UIViewController`, host the new `PinEntryView` with `UIHostingController` (see "UIKit interop" below) — you get the new behaviour with the default look; per-button UIKit customisation is not preserved.

## Distribution

CocoaPods is no longer supported. Add the package via Swift Package Manager:

```swift
.package(url: "https://github.com/Fawxy/CBPinEntryView.git", from: "2.0.0")
```

## API mapping

| 1.x (`CBPinEntryView`) | 2.0 (`PinEntryView`) |
|---|---|
| `delegate.entryCompleted(with:)` | `onComplete: (String) -> Void` init parameter |
| `delegate.entryChanged(_:)` | Dropped — derive it from `.onChange(of: pin)` on your own `pin` binding |
| `getPinAsString()` | Read your own `pin: Binding<String>` directly |
| `getPinAsInt()` | `Int(pin)` |
| `setError(isError:)` / `errorMode` | `isError: Binding<Bool>` — you own it; the view renders it but never mutates or clears it |
| `clearEntry()` | `pin = ""` |
| `becomeFirstResponder()` / `resignFirstResponder()` | A parent-owned `@FocusState` binding passed via `.pinFocused($focus)`; set `focus = true`/`false` yourself |
| Per-state style properties (`entryBackgroundColour`, `entryBorderColour`, `entryCornerRadius`, `entryFont`, etc.) | A `cell: (PinEntryCellState) -> some View` closure, or tweak `DefaultPinEntryCell`'s initialiser parameters |
| `isUnderlined` | No longer a built-in mode — write an underlined `cell` closure (see `Example/Example/UnderlinedPinCell.swift` for a working recipe) |
| `allowedEntryTypes` | `.pinAllowedEntry(_:)` (same four cases: `.any`, `.numerical`, `.alphanumeric`, `.letters`) |
| `isSecure` / `secureCharacter` | `.pinSecure(_:character:)` |
| `keyboardType` (raw `Int`) | `.pinKeyboardType(_:)`, taking a real `UIKeyboardType` |
| `textContentType` | `.pinTextContentType(_:)` |
| `textFieldCapitalization` (`UITextAutocapitalizationType`) | `.pinTextInputAutocapitalization(_:)`, taking SwiftUI's `TextInputAutocapitalization` |
| Storyboard / `@IBInspectable` placement | Place `PinEntryView` directly in SwiftUI, or host it via `UIHostingController` from UIKit |

## Behavioural notes

- **Error no longer auto-clears.** In 1.x, `resignFirstResponder()` cleared error mode. In 2.0 the view never mutates `isError` — if you want typing to dismiss an error, add it yourself: `.onChange(of: pin) { if !pin.isEmpty { isError = false } }`.
- **`isUnderlined` has no replacement flag.** It's a `cell` closure now, not a boolean mode.
- **Reading the pin is synchronous and always available** via your own `pin` binding — no more force-unwrapping `textField.text!`.

## UIKit interop

```swift
let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
    // handle completion
}
let hosting = UIHostingController(rootView: pinView)
addChild(hosting)
view.addSubview(hosting.view)
hosting.view.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    hosting.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
    hosting.view.centerYAnchor.constraint(equalTo: view.centerYAnchor)
])
hosting.didMove(toParent: self)
```

See `Example/Example/HostingControllerInteropScreen.swift` for the full, running version.

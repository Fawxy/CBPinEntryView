# CBPinEntryView

A SwiftUI view for entering pins, one-time codes, or passwords — backspace, paste, and `.oneTimeCode` autofill all work correctly out of the box, with first-class accessibility (VoiceOver progress announcements, Dynamic Type, no colour-only states).

## Requirements

- iOS 16.0+
- Swift 5.9+
- No external dependencies

## Installation

Swift Package Manager only:

```swift
dependencies: [
    .package(url: "https://github.com/Fawxy/CBPinEntryView.git", from: "2.0.0")
]
```

> Upgrading from 1.x? CBPinEntryView 2.0 is a SwiftUI-only rewrite with no UIKit compatibility shim. See [MIGRATION.md](MIGRATION.md).

## Usage

```swift
import CBPinEntryView

struct LoginView: View {
    @State private var pin = ""
    @State private var isError = false

    var body: some View {
        PinEntryView(pin: $pin, length: 6, isError: $isError) { pin in
            print("Completed: \(pin)")
        }
    }
}
```

`pin` is the single source of truth — read it directly, no `getPinAsString()` needed. Set `pin = ""` to clear.

### Configuration

Behavioural configuration is applied via `pin`-prefixed modifiers, not the standard SwiftUI ones (see "Why `pin`-prefixed modifiers?" below):

```swift
PinEntryView(pin: $pin, length: 4, isError: $isError)
    .pinAllowedEntry(.numerical)
    .pinSecure(true, character: "●")
    .pinKeyboardType(.numberPad)
    .pinTextContentType(.oneTimeCode)
    .pinTextInputAutocapitalization(.never)
    .pinHaptics(.default)
    .pinFocused($isFocused)
    .pinPasteEnabled(false)
```

### Custom cell rendering

The library ships one default cell (`DefaultPinEntryCell`) but imposes no particular look. Pass your own `@ViewBuilder` closure over `PinEntryCellState`:

```swift
PinEntryView(pin: $pin, length: 4, isError: $isError) { state in
    VStack {
        Text(state.character ?? "")
        Rectangle()
            .fill(state.isFocused ? Color.accentColor : Color.secondary)
            .frame(height: state.isFocused ? 3 : 1)
    }
}
```

`PinEntryCellState` is already masked when secure — a custom cell never sees the raw digit in secure mode.

### Why `pin`-prefixed modifiers?

A wrapper view can't give a propagating standard modifier (`.keyboardType`, `.textContentType`, `.textInputAutocapitalization`) an overridable default: SwiftUI's environment resolves closest-to-the-field-wins, and the field inside `PinEntryView` is always closer than anything wrapped around it. Applying the standard modifier outside `PinEntryView` would silently do nothing. The `pin`-prefixed modifiers avoid that footgun — apply them directly on `PinEntryView`, before any type-erasing modifier like `.frame()`.

### Accessibility

The field carries a single accessibility element (label + a live "N of M entered" progress value); the cell overlay is hidden from VoiceOver. Secure entry reports count only, never characters. Error is surfaced non-visually as well as visually. This is guaranteed by the library regardless of the `cell` closure you provide.

### UIKit interop

`PinEntryView` is a SwiftUI-only view. Host it from UIKit with `UIHostingController`:

```swift
let pinView = PinEntryView(pin: pinBinding, length: 4, isError: errorBinding) { pin in
    // handle completion
}
let hosting = UIHostingController(rootView: pinView)
addChild(hosting)
view.addSubview(hosting.view)
// ... Auto Layout constraints ...
hosting.didMove(toParent: self)
```

See `Example/Example/HostingControllerInteropScreen.swift` for a complete, running example.

## Example app

Open `Example/Example.xcodeproj` in Xcode and run the `Example` scheme (iOS 17+ simulator). It exercises length, secure toggle, error toggle, allowed-character restriction, clear, programmatic focus, a custom underlined cell with a shake-on-error animation, an `@Observable` feature-model screen, and the `UIHostingController` interop screen.

## Migrating from 1.x

See [MIGRATION.md](MIGRATION.md) for the full API mapping.

## License

CBPinEntryView is available under the MIT license. See the LICENSE file for more info.

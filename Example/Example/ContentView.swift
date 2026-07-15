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
    @State private var shakeTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin entry") {
                    // The two branches differ only in the cell closure, which changes
                    // PinEntryView's generic type — so they can't be unified into one
                    // expression. `configured` applies the shared modifiers to both.
                    Group {
                        if useUnderlinedCell {
                            configured(PinEntryView(pin: $pin, length: length, isError: $isError, cell: UnderlinedPinCell.init))
                        } else {
                            configured(PinEntryView(pin: $pin, length: length, isError: $isError))
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
                    Button("Trigger error") {
                        isError = true
                        shakeTrigger += 1
                    }
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

    private func configured<Cell: View>(_ view: PinEntryView<Cell>) -> some View {
        view
            .pinAllowedEntry(allowedEntry)
            .pinSecure(isSecure)
            .pinFocused($isPinFocused)
    }
}

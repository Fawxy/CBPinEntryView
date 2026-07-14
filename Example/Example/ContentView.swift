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

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin entry") {
                    Group {
                        if useUnderlinedCell {
                            PinEntryView(pin: $pin, length: length, isError: $isError, cell: UnderlinedPinCell.init)
                                .pinAllowedEntry(allowedEntry)
                                .pinSecure(isSecure)
                                .pinFocused($isPinFocused)
                        } else {
                            PinEntryView(pin: $pin, length: length, isError: $isError)
                                .pinAllowedEntry(allowedEntry)
                                .pinSecure(isSecure)
                                .pinFocused($isPinFocused)
                        }
                    }
                    .onChange(of: pin) {
                        if !pin.isEmpty {
                            isError = false
                        }
                    }
                    .padding(.vertical, 8)

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
                    Button("Trigger error") { isError = true }
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
}

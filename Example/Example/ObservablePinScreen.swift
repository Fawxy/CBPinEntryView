import CBPinEntryView
import SwiftUI

@Observable
final class PinVerificationModel {
    var pin = ""
    var isError = false
    private(set) var isVerifying = false

    private let correctCode = "1234"

    @MainActor
    func verify() async {
        isVerifying = true
        defer { isVerifying = false }

        try? await Task.sleep(for: .seconds(1))

        isError = pin != correctCode
    }
}

struct ObservablePinScreen: View {
    @State private var model = PinVerificationModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter 1234 to verify")
                .font(.headline)

            PinEntryView(pin: $model.pin, length: 4, isError: $model.isError) { _ in
                Task { await model.verify() }
            }
            .pinFocused($isFocused)

            if model.isVerifying {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle("Observable model")
        .onAppear { isFocused = true }
    }
}

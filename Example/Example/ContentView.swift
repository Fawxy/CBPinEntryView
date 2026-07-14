import CBPinEntryView
import SwiftUI

struct ContentView: View {
    @State private var pin = ""

    var body: some View {
        PinEntryView(pin: $pin, length: 4)
            .padding()
    }
}

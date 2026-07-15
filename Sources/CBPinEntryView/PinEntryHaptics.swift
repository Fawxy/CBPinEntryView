import UIKit

public struct PinEntryHapticEvents: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let entry = PinEntryHapticEvents(rawValue: 1 << 0)
    public static let completion = PinEntryHapticEvents(rawValue: 1 << 1)
    public static let error = PinEntryHapticEvents(rawValue: 1 << 2)

    public static let `default`: PinEntryHapticEvents = [.completion, .error]
    public static let all: PinEntryHapticEvents = [.entry, .completion, .error]
}

struct PinEntryHaptics {
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare(for events: PinEntryHapticEvents) {
        if events.contains(.entry) {
            selectionGenerator.prepare()
        }
        if events.contains(.completion) || events.contains(.error) {
            notificationGenerator.prepare()
        }
    }

    func fireEntry(for events: PinEntryHapticEvents) {
        guard events.contains(.entry) else { return }
        selectionGenerator.selectionChanged()
    }

    func fireCompletion(for events: PinEntryHapticEvents) {
        guard events.contains(.completion) else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func fireError(for events: PinEntryHapticEvents) {
        guard events.contains(.error) else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}

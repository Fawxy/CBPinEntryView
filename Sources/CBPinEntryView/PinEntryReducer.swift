import Foundation

enum PinEntryReducer {
    static func reduce(_ input: String, length: Int, allowedEntry: AllowedEntryType) -> String {
        let sanitized = allowedEntry.sanitize(input)
        return String(sanitized.prefix(length))
    }

    static func isComplete(_ pin: String, length: Int) -> Bool {
        pin.count >= length
    }

    static func didComplete(from oldValue: String, to newValue: String, length: Int) -> Bool {
        oldValue.count < length && newValue.count >= length
    }

    static func maskedDisplay(_ pin: String, secureCharacter: String) -> String {
        String(repeating: secureCharacter, count: pin.count)
    }
}

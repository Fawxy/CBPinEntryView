import Foundation

public enum AllowedEntryType: String, Hashable, Sendable {
    case any
    case numerical
    case alphanumeric
    case letters

    public func sanitize(_ input: String) -> String {
        switch self {
        case .any:
            return input
        case .numerical:
            return input.filter { $0.isNumber }
        case .alphanumeric:
            return input.filter { $0.isLetter || $0.isNumber }
        case .letters:
            return input.filter { $0.isLetter }
        }
    }
}

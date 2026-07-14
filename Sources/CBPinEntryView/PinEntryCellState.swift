import Foundation

public struct PinEntryCellState: Equatable, Sendable {
    public let character: String?
    public let index: Int
    public let isFocused: Bool
    public let isFilled: Bool
    public let isError: Bool
}

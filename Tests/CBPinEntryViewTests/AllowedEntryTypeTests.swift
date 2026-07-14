import Testing
@testable import CBPinEntryView

@Suite("AllowedEntryType")
struct AllowedEntryTypeTests {
    @Test("numerical strips non-digit characters")
    func numericalStripsLetters() {
        #expect(AllowedEntryType.numerical.sanitize("1a2b3c") == "123")
    }

    @Test("letters strips digits")
    func lettersStripsDigits() {
        #expect(AllowedEntryType.letters.sanitize("1a2b3c") == "abc")
    }

    @Test("alphanumeric strips symbols")
    func alphanumericStripsSymbols() {
        #expect(AllowedEntryType.alphanumeric.sanitize("a1-b2_c3!") == "a1b2c3")
    }

    @Test("any passes input through unchanged")
    func anyPassesThrough() {
        #expect(AllowedEntryType.any.sanitize("a1-b2_c3!") == "a1-b2_c3!")
    }
}

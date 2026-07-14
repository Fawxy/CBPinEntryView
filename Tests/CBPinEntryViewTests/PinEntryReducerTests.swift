import Testing
@testable import CBPinEntryView

@Suite("PinEntryReducer")
struct PinEntryReducerTests {
    @Test("sanitises before truncating so stray characters don't consume length")
    func sanitiseBeforeTruncate() {
        #expect(PinEntryReducer.reduce("12-34-56", length: 6, allowedEntry: .numerical) == "123456")
    }

    @Test("caps an over-length paste to the leading length characters")
    func capsOverLengthPaste() {
        #expect(PinEntryReducer.reduce("123456789", length: 4, allowedEntry: .numerical) == "1234")
    }

    @Test("preserves existing leading digits when appending mid-entry")
    func preservesLeadingDigitsMidEntry() {
        #expect(PinEntryReducer.reduce("123456", length: 4, allowedEntry: .numerical) == "1234")
    }

    @Test("isComplete is true at or beyond length")
    func isCompleteAtLength() {
        #expect(PinEntryReducer.isComplete("1234", length: 4))
        #expect(!PinEntryReducer.isComplete("123", length: 4))
    }

    @Test("didComplete fires transitioning from below length to exactly length")
    func didCompleteOnTransition() {
        #expect(PinEntryReducer.didComplete(from: "123", to: "1234", length: 4))
    }

    @Test("didComplete does not refire on a no-op keystroke into a full field")
    func didCompleteNoRefireOnNoOp() {
        #expect(!PinEntryReducer.didComplete(from: "1234", to: "1234", length: 4))
    }

    @Test("didComplete fires again after delete-below-then-refill")
    func didCompleteRefiresAfterDeleteAndRefill() {
        #expect(!PinEntryReducer.didComplete(from: "1234", to: "123", length: 4))
        #expect(PinEntryReducer.didComplete(from: "123", to: "1234", length: 4))
    }

    @Test("didComplete fires once for a programmatic full-value assignment beyond length")
    func didCompleteFiresForProgrammaticAssignment() {
        #expect(PinEntryReducer.didComplete(from: "12", to: "999999", length: 4))
    }

    @Test("maskedDisplay yields one mask character per entered digit")
    func maskedDisplayYieldsMaskPerCharacter() {
        let pin = "1234"
        let masked = PinEntryReducer.maskedDisplay(pin, secureCharacter: "●")
        #expect(masked == "●●●●")
    }
}

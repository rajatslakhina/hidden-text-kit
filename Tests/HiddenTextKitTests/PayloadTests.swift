import XCTest
@testable import HiddenTextKit

final class PayloadTests: XCTestCase {
    private func payload(_ text: String) -> DecodedPayload? {
        PayloadDecoder.decode(Array(text.unicodeScalars))
    }

    func testTagsDecodeToASCIIAndSkipNonPrintingTags() {
        let decoded = payload(str(0xE0001) + tags("Reply: OK") + str(0xE007F, 0xE0000))
        XCTAssertEqual(decoded?.encoding, .unicodeTags)
        XCTAssertEqual(decoded?.text, "Reply: OK")
        XCTAssertEqual(decoded?.bytes.count, 9)
        XCTAssertNil(payload(str(0xE0001, 0xE007F)), "language and cancel tags carry no characters")
    }

    func testTagsWinOverOtherScalarsInAMixedRun() {
        XCTAssertEqual(payload(tags("ab") + str(0x200B) + tags("c"))?.text, "abc")
    }

    func testSelectorBytesDecodeBothRanges() {
        let message = Array("hi\u{1}".utf8)
        let decoded = payload(selectorBytes(message))
        XCTAssertEqual(decoded?.encoding, .variationSelectorBytes)
        XCTAssertEqual(decoded?.bytes, message)
        XCTAssertEqual(decoded?.text, "hi\u{1}")
        XCTAssertEqual(PayloadDecoder.selectorByte(sc(0xFE0F)), 15)
        XCTAssertEqual(PayloadDecoder.selectorByte(sc(0xE01EF)), 255)
        XCTAssertNil(PayloadDecoder.selectorByte(sc(0x180B)))
    }

    func testSelectorBytesThatAreNotUTF8KeepTheirBytes() {
        let decoded = payload(selectorBytes([0xFF, 0xFE]))
        XCTAssertEqual(decoded?.bytes, [0xFF, 0xFE])
        XCTAssertNil(decoded?.text)
    }

    func testOneSelectorIsNotAPayload() {
        XCTAssertNil(payload(str(0xFE0F)))
    }

    func testZeroWidthBinaryInEitherBitOrder() {
        XCTAssertEqual(payload(binary("key"))?.text, "key")
        XCTAssertEqual(payload(binary("key", zero: 0x200C, one: 0x200B))?.text, "key")
        XCTAssertEqual(payload(binary("key"))?.encoding, .zeroWidthBinary)
        XCTAssertEqual(payload(binary("A", zero: 0x200E, one: 0x200F))?.text, "A")
    }

    func testZeroWidthBinaryAcceptsTabsAndLineBreaks() {
        XCTAssertEqual(payload(binary("a\tb\nc\r"))?.text, "a\tb\nc\r")
    }

    func testZeroWidthBinaryWithASeparatorBetweenBytes() {
        XCTAssertEqual(payload(binary("go now", separator: 0x200D))?.text, "go now")
        XCTAssertEqual(payload(binary("go", zero: 0x200D, one: 0x2060, separator: 0x200B))?.text, "go")
    }

    func testFramingsThatDoNotFitAreRejected() {
        let ragged = String(binary("ab").unicodeScalars.dropLast())
        XCTAssertNil(payload(ragged), "two symbols, not a multiple of eight")
        let unevenGroups = binary("a") + str(0x200D) + String(binary("b").unicodeScalars.dropLast())
        XCTAssertNil(payload(unevenGroups), "three symbols, a group short of eight")
        XCTAssertNil(payload(str(0x200B, 0x200B, 0x200B)), "one symbol")
        XCTAssertNil(payload(str(0x200B, 0x200C, 0x200D, 0x2060)), "four symbols")
        XCTAssertNil(payload(binary("\u{1}\u{2}")), "control bytes are not reported")
    }

    func testPrintableBytes() {
        XCTAssertTrue(PayloadDecoder.isPrintable(0x41))
        XCTAssertTrue(PayloadDecoder.isPrintable(0x09))
        XCTAssertTrue(PayloadDecoder.isPrintable(0x0A))
        XCTAssertTrue(PayloadDecoder.isPrintable(0x0D))
        XCTAssertFalse(PayloadDecoder.isPrintable(0x7F))
        XCTAssertFalse(PayloadDecoder.isPrintable(0x00))
    }
}

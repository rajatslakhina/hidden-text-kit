import XCTest
@testable import HiddenTextKit

final class FormatterTests: XCTestCase {
    private let open = HiddenTextFormatter.openBracket
    private let close = HiddenTextFormatter.closeBracket

    func testCodePoints() {
        XCTAssertEqual(HiddenTextFormatter.codePoint(sc(0xAD)), "U+00AD")
        XCTAssertEqual(HiddenTextFormatter.codePoint(sc(0x200B)), "U+200B")
        XCTAssertEqual(HiddenTextFormatter.codePoint(sc(0xE0041)), "U+E0041")
        let scalars = Array(str(0x200B, 0x200C, 0x200B, 0x200C, 0x200B, 0x200C).unicodeScalars)
        XCTAssertEqual(HiddenTextFormatter.codePoints(scalars), "U+200B U+200C U+200B U+200C +2 more")
        XCTAssertEqual(HiddenTextFormatter.codePoints(Array(scalars.prefix(2))), "U+200B U+200C")
        XCTAssertEqual(HiddenTextFormatter.codePoints(scalars, limit: 6), "U+200B U+200C U+200B U+200C U+200B U+200C")
    }

    func testEscapingKeepsNestedLayersVisible() {
        XCTAssertEqual(HiddenTextFormatter.escaped("a \"b\" \\ c"), "a \\\"b\\\" \\\\ c")
        XCTAssertEqual(HiddenTextFormatter.escaped("x" + str(0x200B) + "\n" + str(0xE9)), "x\\u{200B}\\u{A}\\u{E9}")
    }

    func testQuotedPayloads() {
        XCTAssertEqual(HiddenTextFormatter.quoted(DecodedPayload(encoding: .unicodeTags, bytes: [0x68, 0x69])), "\"hi\"")
        XCTAssertEqual(
            HiddenTextFormatter.quoted(DecodedPayload(encoding: .variationSelectorBytes, bytes: [0xFF, 0x00])),
            "<2 bytes, not UTF-8>"
        )
    }

    func testMarkers() {
        let runs = HiddenTextScanner().scan("a" + tags("go") + "b" + str(0x2060) + "c").runs
        XCTAssertEqual(HiddenTextFormatter.marker(for: runs[0]), "\(open)hidden unicodeTags: \"go\"\(close)")
        XCTAssertEqual(HiddenTextFormatter.marker(for: runs[1]), "\(open)U+2060\(close)")
    }

    func testVisibleShowsLegitimateScalarsToo() {
        XCTAssertEqual(
            HiddenTextFormatter.visible(family),
            str(0x1F468) + "\(open)U+200D\(close)" + str(0x1F469) + "\(open)U+200D\(close)" + str(0x1F467)
        )
        XCTAssertEqual(HiddenTextFormatter.visible("plain"), "plain")
    }

    func testSummaries() {
        let scanner = HiddenTextScanner()
        XCTAssertEqual(HiddenTextFormatter.summary(scanner.scan("plain")), "clean")
        XCTAssertEqual(HiddenTextFormatter.summary(scanner.scan(scotland)), "clean (1 legitimate run kept)")
        XCTAssertEqual(HiddenTextFormatter.summary(scanner.scan(family)), "clean (2 legitimate runs kept)")
        XCTAssertEqual(
            HiddenTextFormatter.summary(scanner.scan("a" + tags("go") + "b" + str(0x2060) + "c")),
            "2 suspicious runs, 3 scalars (tag 2, zeroWidth 1); unicodeTags \"go\""
        )
        XCTAssertEqual(
            HiddenTextFormatter.summary(scanner.scan("a" + str(0x2060) + "b")),
            "1 suspicious run, 1 scalar (zeroWidth 1)"
        )
    }
}

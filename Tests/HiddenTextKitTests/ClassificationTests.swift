import XCTest
@testable import HiddenTextKit

final class ClassificationTests: XCTestCase {
    func testEveryRangeLandsInItsClass() {
        let expectations: [(UInt32, HiddenScalarClass?)] = [
            (0xE0000, .tag), (0xE0041, .tag), (0xE007F, .tag),
            (0xFE00, .variationSelector), (0xFE0F, .variationSelector), (0xE0100, .variationSelector),
            (0xE01EF, .variationSelector), (0x180B, .variationSelector), (0x180F, .variationSelector),
            (0x200B, .zeroWidth), (0x200C, .zeroWidth), (0x200D, .zeroWidth), (0x2060, .zeroWidth),
            (0xFEFF, .zeroWidth),
            (0x202A, .bidiControl), (0x202E, .bidiControl), (0x2066, .bidiControl), (0x2069, .bidiControl),
            (0x200E, .bidiMark), (0x200F, .bidiMark), (0x061C, .bidiMark),
            (0x00AD, .invisibleFormat), (0x034F, .invisibleFormat), (0x115F, .invisibleFormat),
            (0x1160, .invisibleFormat), (0x17B4, .invisibleFormat), (0x17B5, .invisibleFormat),
            (0x180E, .invisibleFormat), (0x2061, .invisibleFormat), (0x2064, .invisibleFormat),
            (0x206A, .invisibleFormat), (0x206F, .invisibleFormat), (0x3164, .invisibleFormat),
            (0xFFA0, .invisibleFormat), (0xFFF9, .invisibleFormat), (0xFFFB, .invisibleFormat),
            (0x1BCA0, .invisibleFormat), (0x1D173, .invisibleFormat), (0x1D17A, .invisibleFormat),
            (0x41, nil), (0x20, nil), (0x1F600, nil), (0xE0080, nil), (0x2065, nil), (0x180A, nil)
        ]
        for (value, expected) in expectations {
            XCTAssertEqual(HiddenScalarClass(sc(value)), expected, String(value, radix: 16))
            XCTAssertEqual(HiddenScalarClass.isHidden(sc(value)), expected != nil)
        }
    }

    func testRunClassesAreReportedInDeclarationOrder() {
        let run = HiddenRun(
            range: 0..<3,
            scalars: [sc(0x200E), sc(0xE0041), sc(0x200B)],
            verdict: .suspicious(.tagRun),
            payload: nil
        )
        XCTAssertEqual(run.classes, [.tag, .zeroWidth, .bidiMark])
        XCTAssertTrue(run.isSuspicious)
        XCTAssertFalse(HiddenRunVerdict.legitimate(.softHyphen).isSuspicious)
    }

    func testEnumsListEveryCase() {
        XCTAssertEqual(HiddenScalarClass.allCases.count, 6)
        XCTAssertEqual(LegitimateUse.allCases.count, 9)
        XCTAssertEqual(Suspicion.allCases.count, 8)
        XCTAssertEqual(PayloadEncoding.allCases.count, 3)
        XCTAssertEqual(HiddenTextAction.allCases.count, 4)
    }
}

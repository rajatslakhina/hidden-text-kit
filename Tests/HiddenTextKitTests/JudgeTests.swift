import XCTest
@testable import HiddenTextKit

final class JudgeTests: XCTestCase {
    func testLegitimateCorpusIsLeftAlone() {
        let corpus: [(String, LegitimateUse)] = [
            (scotland, .subdivisionFlag),
            (family, .emojiJoiner),
            (rainbow, .emojiJoiner),
            (str(0x31, 0xFE0F, 0x20E3), .variationSequence),
            (persian, .scriptJoiner),
            (str(0x915, 0x94D, 0x200D, 0x937), .scriptJoiner),
            (str(0xE2A, 0xE35, 0x200B, 0xE04), .wordBreakHint),
            (str(0xFEFF) + "Report", .byteOrderMark),
            ("Donau" + str(0x00AD) + "schiff", .softHyphen),
            (str(0x5E9, 0x200F) + "!", .directionMark),
            ("a" + str(0x2068) + "b" + str(0x2069), .balancedIsolate),
            (str(0x845B, 0xE0100), .variationSequence),
            (str(0x1820, 0x180B), .variationSequence)
        ]
        for (text, use) in corpus {
            XCTAssertTrue(verdicts(text).allSatisfy { $0 == .legitimate(use) }, "\(use)")
            XCTAssertFalse(verdicts(text).isEmpty)
        }
    }

    func testSingleScalarsOutOfContext() {
        XCTAssertEqual(verdicts("a" + str(0xE0041) + "b"), [.suspicious(.tagRun)])
        XCTAssertEqual(verdicts(str(0xFE0F) + "a"), [.suspicious(.orphanSelector)])
        XCTAssertEqual(verdicts(" " + str(0xFE0F)), [.suspicious(.orphanSelector)])
        XCTAssertEqual(verdicts(str(0x07, 0xFE0F)), [.suspicious(.orphanSelector)])
        XCTAssertEqual(verdicts("a" + str(0x200D) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts(str(0x1F600, 0x200D) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("1" + str(0x200D) + "2"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0x200C) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0x200B) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts(str(0xE2A, 0x200B) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0xFEFF)), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0x2060) + "b"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0x00AD) + "1"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("1" + str(0x00AD) + "a"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("a" + str(0x202E) + "b"), [.suspicious(.bidiOverride)])
        XCTAssertEqual(verdicts("a" + str(0x2066) + "b"), [.suspicious(.unbalancedIsolate)])
        XCTAssertEqual(verdicts("a" + str(0x2069) + "b"), [.suspicious(.unbalancedIsolate)])
        XCTAssertEqual(verdicts("a" + str(0x2062) + "b"), [.suspicious(.formatCharacter)])
        XCTAssertEqual(verdicts("a" + str(0x3164) + "b"), [.suspicious(.formatCharacter)])
    }

    func testJoinersNeedANonASCIILetterOrMarkOnBothSides() {
        XCTAssertEqual(verdicts("a" + str(0x200C, 0x645)), [.legitimate(.scriptJoiner)])
        XCTAssertEqual(verdicts(str(0x645, 0x200C) + "a"), [.legitimate(.scriptJoiner)])
        XCTAssertEqual(verdicts(str(0x645, 0x200C) + "1"), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts("1" + str(0x200C, 0x645)), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts(str(0x200C, 0x645)), [.suspicious(.outOfContext)])
        XCTAssertEqual(verdicts(str(0x645, 0x200C)), [.suspicious(.outOfContext)])
    }

    func testMultiScalarRuns() {
        XCTAssertEqual(verdicts("a" + tags("hi")), [.suspicious(.tagRun)])
        XCTAssertEqual(verdicts("a" + str(0xFE0F, 0xFE0E)), [.suspicious(.selectorRun)])
        XCTAssertEqual(verdicts("a" + str(0x200B, 0x200B)), [.suspicious(.invisibleRun)])
        XCTAssertEqual(verdicts("a" + str(0x200B, 0xE0041)), [.suspicious(.tagRun)])
        XCTAssertEqual(verdicts("a" + str(0xFE0F, 0x200D) + "b"), [.suspicious(.invisibleRun)])
        XCTAssertEqual(verdicts(str(0x1F3F3, 0xFE0F, 0x200D) + "b"), [.suspicious(.invisibleRun)])
        XCTAssertEqual(verdicts(str(0x1F3F3, 0x200D, 0xFE0F, 0x1F308)), [.suspicious(.invisibleRun)])
    }

    func testSubdivisionFlagShape() {
        XCTAssertTrue(RunJudge.isSubdivisionFlag(Array(str(0xE0067, 0xE0062, 0xE0031, 0xE007F).unicodeScalars),
                                                 before: sc(0x1F3F4)))
        let malformed: [(String, UInt32?)] = [
            (str(0xE0067, 0xE0062, 0xE0073, 0xE007F), 0x1F3F3),
            (str(0xE0067, 0xE0062, 0xE0073, 0xE0063), 0x1F3F4),
            (str(0xE0067, 0xE0062, 0xE007F), 0x1F3F4),
            (str(0xE0067, 0xE0062, 0xE0073, 0xE0063, 0xE0074, 0xE0075, 0xE0076, 0xE007F), 0x1F3F4),
            (str(0xE0067, 0xE0042, 0xE0073, 0xE007F), 0x1F3F4),
            (str(0xE0067, 0xE0020, 0xE0073, 0xE007F), 0x1F3F4),
            (str(0xE0067, 0xE0062, 0xE0073, 0xE007F), nil)
        ]
        for (run, before) in malformed {
            XCTAssertFalse(RunJudge.isSubdivisionFlag(Array(run.unicodeScalars), before: before.map(sc)))
        }
        XCTAssertEqual(verdicts(str(0x1F3F4) + tags("ignore all") + str(0xE007F)), [.suspicious(.tagRun)])
    }

    func testHelpers() {
        XCTAssertFalse(RunJudge.isBase(nil))
        XCTAssertFalse(RunJudge.isBase(" "))
        XCTAssertFalse(RunJudge.isBase(sc(0x07)))
        XCTAssertTrue(RunJudge.isBase("a"))
        XCTAssertFalse(RunJudge.isPictographic(nil))
        XCTAssertFalse(RunJudge.isPictographic("1"))
        XCTAssertFalse(RunJudge.isPictographic(sc(0xE9)))
        XCTAssertTrue(RunJudge.isPictographic(sc(0x1F600)))
        XCTAssertFalse(RunJudge.isLetter(nil))
        XCTAssertFalse(RunJudge.isLetter("1"))
        XCTAssertTrue(RunJudge.isLetter(sc(0x645)))
        XCTAssertTrue(RunJudge.isLetterOrMark(sc(0x94D)))
        XCTAssertTrue(RunJudge.isLetterOrMark(sc(0x903)))
        XCTAssertTrue(RunJudge.isLetterOrMark(sc(0x20E3)))
        XCTAssertFalse(RunJudge.isLetterOrMark("-"))
        XCTAssertFalse(RunJudge.isUnspacedScript(nil))
        for value: UInt32 in [0xE01, 0xE81, 0xF40, 0x1000, 0x1780] {
            XCTAssertTrue(RunJudge.isUnspacedScript(sc(value)))
        }
        XCTAssertFalse(RunJudge.isUnspacedScript("a"))
    }

    func testIsolatePairing() {
        let text = Array(("a" + str(0x2066) + "b" + str(0x2067) + "c" + str(0x2069) + "d" + str(0x2069) + "e"
            + str(0x2069) + str(0x2068) + "\n" + str(0x2066) + "f").unicodeScalars)
        let pairs = RunJudge.isolatePairs(in: text)
        XCTAssertEqual(pairs.pairs, [RunJudge.IsolatePair(open: 3, close: 5), RunJudge.IsolatePair(open: 1, close: 7)])
        XCTAssertEqual(pairs.unclosed, [12])
        XCTAssertEqual(pairs.balanced, [1, 3, 5, 7])
        for separator: UInt32 in [0x0D, 0x1C, 0x1E, 0x85, 0x2029] {
            let split = Array((str(0x2066) + "a" + str(separator) + "b" + str(0x2069)).unicodeScalars)
            XCTAssertTrue(RunJudge.isolatePairs(in: split).pairs.isEmpty)
        }
    }
}

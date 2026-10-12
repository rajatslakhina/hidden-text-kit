import XCTest
@testable import HiddenTextKit

final class LedgerTests: XCTestCase {
    func testTalliesBySource() async {
        let ledger = HiddenTextLedger(recentPayloadLimit: 2)
        let scanner = HiddenTextScanner()
        let tally = await ledger.record(scanner.scan("a" + tags("one") + family), from: .userInput)
        XCTAssertEqual(tally.textsScanned, 1)
        XCTAssertEqual(tally.textsWithFindings, 1)
        XCTAssertEqual(tally.suspiciousScalars, 3)
        XCTAssertEqual(tally.payloads, 1)
        XCTAssertEqual(tally.legitimateRunsKept, 2)
        await ledger.record(scanner.scan("clean"), from: .userInput)
        await ledger.record(scanner.scan("b" + tags("two")), from: .toolResult("web_fetch"))
        await ledger.record(scanner.scan("c" + tags("three")), from: .document("kb-1"))
        await ledger.record(scanner.scan(binary("four")), from: .modelOutput)

        let user = await ledger.tally(for: .userInput)
        XCTAssertEqual(user.textsScanned, 2)
        XCTAssertEqual(user.textsWithFindings, 1)
        let labels = await ledger.tallies().map(\.source.label)
        XCTAssertEqual(labels, ["document: kb-1", "model output", "tool result: web_fetch", "user input"])
        let recent = await ledger.recentPayloads()
        XCTAssertEqual(recent.map(\.payload.text), ["three", "four"])
        XCTAssertEqual(recent.map(\.source), [.document("kb-1"), .modelOutput])
        let total = await ledger.totalSuspiciousScalars
        XCTAssertEqual(total, 3 + 3 + 5 + 32)
        XCTAssertEqual(ledger.recentPayloadLimit, 2)
    }

    func testAnUnseenSourceHasAnEmptyTally() async {
        let tally = await HiddenTextLedger().tally(for: .toolResult("calculator"))
        XCTAssertEqual(tally.textsScanned, 0)
        XCTAssertEqual(tally.source.label, "tool result: calculator")
    }

    func testConcurrentRecordingLosesNothing() async {
        let ledger = HiddenTextLedger()
        let report = HiddenTextScanner().scan("x" + tags("go"))
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask { await ledger.record(report, from: .modelOutput) }
            }
        }
        let tally = await ledger.tally(for: .modelOutput)
        XCTAssertEqual(tally.textsScanned, 200)
        XCTAssertEqual(tally.suspiciousScalars, 400)
        let recent = await ledger.recentPayloads()
        XCTAssertEqual(recent.count, 20)
    }
}

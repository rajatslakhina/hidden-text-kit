/// Where a scanned text came from.
public enum HiddenTextSource: Hashable, Sendable {
    case userInput
    case modelOutput
    case toolResult(String)
    case document(String)

    public var label: String {
        switch self {
        case .userInput: return "user input"
        case .modelOutput: return "model output"
        case let .toolResult(name): return "tool result: \(name)"
        case let .document(id): return "document: \(id)"
        }
    }
}

/// Running totals for one source.
public struct HiddenTextTally: Sendable, Equatable {
    public let source: HiddenTextSource
    public internal(set) var textsScanned = 0
    public internal(set) var textsWithFindings = 0
    public internal(set) var suspiciousScalars = 0
    public internal(set) var payloads = 0
    public internal(set) var legitimateRunsKept = 0

    init(source: HiddenTextSource) {
        self.source = source
    }
}

/// A decoded payload and the source it arrived from.
public struct SourcedPayload: Sendable, Equatable {
    public let source: HiddenTextSource
    public let payload: DecodedPayload
}

/// Collects reports from every place text enters a conversation, so a diagnostics screen can say
/// where hidden content is coming from rather than only that it happened.
///
/// An actor because reports arrive from concurrent sends, tool calls and streams.
public actor HiddenTextLedger {
    public nonisolated let recentPayloadLimit: Int
    private var storage: [HiddenTextSource: HiddenTextTally] = [:]
    private var recent: [SourcedPayload] = []

    public init(recentPayloadLimit: Int = 20) {
        self.recentPayloadLimit = recentPayloadLimit
    }

    @discardableResult
    public func record(_ report: HiddenTextReport, from source: HiddenTextSource) -> HiddenTextTally {
        var tally = storage[source] ?? HiddenTextTally(source: source)
        tally.textsScanned += 1
        tally.textsWithFindings += report.isClean ? 0 : 1
        tally.suspiciousScalars += report.suspiciousScalarCount
        tally.payloads += report.payloads.count
        tally.legitimateRunsKept += report.legitimateRuns.count
        storage[source] = tally
        recent += report.payloads.map { SourcedPayload(source: source, payload: $0) }
        recent = Array(recent.suffix(recentPayloadLimit))
        return tally
    }

    public func tally(for source: HiddenTextSource) -> HiddenTextTally {
        storage[source] ?? HiddenTextTally(source: source)
    }

    /// Every source seen, ordered by label.
    public func tallies() -> [HiddenTextTally] {
        storage.values.sorted { $0.source.label < $1.source.label }
    }

    /// The most recent payloads, oldest first, at most `recentPayloadLimit`.
    public func recentPayloads() -> [SourcedPayload] {
        recent
    }

    public var totalSuspiciousScalars: Int {
        storage.values.reduce(0) { $0 + $1.suspiciousScalars }
    }
}

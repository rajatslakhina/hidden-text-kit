/// Everything a scan found in one text.
public struct HiddenTextReport: Sendable, Equatable {
    /// `text.unicodeScalars.count` of the scanned text.
    public let scalarCount: Int
    /// Every hidden run, legitimate or not, in text order.
    public let runs: [HiddenRun]

    public init(scalarCount: Int, runs: [HiddenRun]) {
        self.scalarCount = scalarCount
        self.runs = runs
    }

    public var suspiciousRuns: [HiddenRun] { runs.filter(\.isSuspicious) }
    public var legitimateRuns: [HiddenRun] { runs.filter { !$0.isSuspicious } }
    /// True when nothing out of place was found. Legitimate runs do not count against it.
    public var isClean: Bool { suspiciousRuns.isEmpty }
    public var hiddenScalarCount: Int { runs.reduce(0) { $0 + $1.scalars.count } }
    public var suspiciousScalarCount: Int { suspiciousRuns.reduce(0) { $0 + $1.scalars.count } }
    /// What the suspicious runs spell. Legitimate runs can decode too (a flag of Scotland reads
    /// `gbsct`), but that is the flag, not a message.
    public var payloads: [DecodedPayload] { suspiciousRuns.compactMap(\.payload) }

    /// Suspicious scalars per class. Classes with none are absent.
    public var suspiciousScalarsByClass: [HiddenScalarClass: Int] {
        var counts: [HiddenScalarClass: Int] = [:]
        for hiddenClass in suspiciousRuns.flatMap(\.scalars).compactMap({ HiddenScalarClass($0) }) {
            counts[hiddenClass, default: 0] += 1
        }
        return counts
    }
}

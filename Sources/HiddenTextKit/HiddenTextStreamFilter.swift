/// Sanitizes a streamed answer chunk by chunk, with the same result as sanitizing the whole text.
///
/// Whether a run is legitimate depends on the visible scalar after it, and a run can continue
/// into the next chunk, so the filter holds back any hidden scalars at the end of what it has
/// seen. It also never releases half of a direction isolate: an opener waits until its partner
/// arrives or its paragraph ends. Everything else is released as soon as it arrives.
///
/// Two limits, both deliberate. Past `maxPendingScalars` held scalars the filter releases what it
/// has rather than buffer without bound, and the result can then differ from a whole-text scan.
/// And a `.refuse` action cannot take back text already released: the run is stripped and
/// `refusalRequested` is set, for the caller to act on before it commits the answer.
public struct HiddenTextStreamFilter: Sendable {
    public let sanitizer: HiddenTextSanitizer
    public let maxPendingScalars: Int
    /// Every run judged so far, with ranges counted from the start of the stream.
    public private(set) var runs: [HiddenRun] = []
    public private(set) var refusalRequested = false

    private var pending: [Unicode.Scalar] = []
    /// The scalar just before `pending`, when it is visible. A forced release can end on a hidden
    /// scalar, and then the next run has no visible neighbour on that side.
    private var visibleBefore: Unicode.Scalar?
    private var releasedCount = 0

    public init(sanitizer: HiddenTextSanitizer = HiddenTextSanitizer(), maxPendingScalars: Int = 4_096) {
        self.sanitizer = sanitizer
        self.maxPendingScalars = maxPendingScalars
    }

    /// Scalars received but not yet released.
    public var pendingCount: Int { pending.count }

    /// Takes the next chunk and returns whatever can now be released, possibly nothing.
    public mutating func feed(_ chunk: String) -> String {
        pending.append(contentsOf: chunk.unicodeScalars)
        let cut = pending.count > maxPendingScalars ? pending.count : Self.releasePoint(in: pending)
        return release(upTo: cut)
    }

    /// Releases everything still held. Call once, after the last chunk.
    public mutating func finish() -> String {
        release(upTo: pending.count)
    }

    /// The report the whole stream would have produced so far.
    public var report: HiddenTextReport {
        HiddenTextReport(scalarCount: releasedCount, runs: runs)
    }

    /// Just after the last visible scalar, moved back past any isolate whose partner is not yet
    /// inside the released part. Pairs nest, so moving back can expose an enclosing pair; the
    /// loop repeats until no pair straddles the cut.
    static func releasePoint(in pending: [Unicode.Scalar]) -> Int {
        guard let lastVisible = pending.lastIndex(where: { !HiddenScalarClass.isHidden($0) }) else {
            return 0
        }
        var cut = lastVisible + 1
        let isolates = RunJudge.isolatePairs(in: pending)
        while let blocker = (
            isolates.pairs.filter { $0.open < cut && $0.close >= cut }.map(\.open)
                + isolates.unclosed.filter { $0 < cut }
        ).min() {
            let previousVisible = pending[..<blocker].lastIndex { !HiddenScalarClass.isHidden($0) }
            cut = (previousVisible ?? -1) + 1
        }
        return cut
    }

    private mutating func release(upTo cut: Int) -> String {
        guard cut > 0 else { return "" }
        let window = Array(pending[..<cut])
        let applied = sanitizer.apply(to: window, before: visibleBefore, baseOffset: releasedCount)
        runs += applied.runs
        if case .refused = applied.outcome {
            refusalRequested = true
        }
        let last = window[cut - 1]
        visibleBefore = HiddenScalarClass.isHidden(last) ? nil : last
        pending.removeFirst(cut)
        releasedCount += cut
        return applied.text
    }
}

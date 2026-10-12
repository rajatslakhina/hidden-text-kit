/// Finds every hidden run in a text and judges each one.
///
/// A pure value: no state, no isolation, safe to call from anywhere.
public struct HiddenTextScanner: Sendable {
    public init() {}

    public func scan(_ text: String) -> HiddenTextReport {
        let scalars = Array(text.unicodeScalars)
        return HiddenTextReport(
            scalarCount: scalars.count,
            runs: Self.runs(in: scalars, before: nil, baseOffset: 0)
        )
    }

    /// `leading` is the visible scalar that came before `scalars` when they continue a stream.
    /// `baseOffset` is where `scalars` start in the whole text, so reported ranges stay absolute.
    static func runs(
        in scalars: [Unicode.Scalar],
        before leading: Unicode.Scalar?,
        baseOffset: Int
    ) -> [HiddenRun] {
        let balanced = RunJudge.isolatePairs(in: scalars).balanced
        var runs: [HiddenRun] = []
        var index = 0
        while index < scalars.count {
            guard HiddenScalarClass.isHidden(scalars[index]) else {
                index += 1
                continue
            }
            let start = index
            while index < scalars.count, HiddenScalarClass.isHidden(scalars[index]) {
                index += 1
            }
            let run = Array(scalars[start..<index])
            let context = RunJudge.Context(
                before: start > 0 ? scalars[start - 1] : leading,
                after: index < scalars.count ? scalars[index] : nil,
                startsText: baseOffset + start == 0,
                isBalancedIsolate: balanced.contains(start)
            )
            runs.append(
                HiddenRun(
                    range: (baseOffset + start)..<(baseOffset + index),
                    scalars: run,
                    verdict: RunJudge.verdict(for: run, in: context),
                    payload: PayloadDecoder.decode(run)
                )
            )
        }
        return runs
    }
}

/// A text after a policy has been applied to it.
public struct SanitizedText: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        /// No run called for a change.
        case unchanged
        /// Scalars were removed or replaced by markers. Counts are in scalars.
        case modified(stripped: Int, revealed: Int)
        /// At least one run's action was `.refuse`. Those runs are listed; `text` holds what the
        /// text becomes with them stripped, so a caller can offer it as the way forward.
        case refused(runs: [HiddenRun])
    }

    public let text: String
    public let report: HiddenTextReport
    public let outcome: Outcome

    public var isRefused: Bool {
        if case .refused = outcome { return true }
        return false
    }
}

/// Applies a `HiddenTextPolicy` to whole texts.
public struct HiddenTextSanitizer: Sendable {
    public var policy: HiddenTextPolicy

    public init(policy: HiddenTextPolicy = .standard) {
        self.policy = policy
    }

    public func sanitize(_ text: String) -> SanitizedText {
        let scalars = Array(text.unicodeScalars)
        let applied = apply(to: scalars, before: nil, baseOffset: 0)
        return SanitizedText(
            text: applied.text,
            report: HiddenTextReport(scalarCount: scalars.count, runs: applied.runs),
            outcome: applied.outcome
        )
    }

    struct Application {
        let text: String
        let runs: [HiddenRun]
        let outcome: SanitizedText.Outcome
    }

    /// The shared core of `sanitize(_:)` and the stream filter, which hands it one window at a time.
    func apply(to scalars: [Unicode.Scalar], before: Unicode.Scalar?, baseOffset: Int) -> Application {
        let runs = HiddenTextScanner.runs(in: scalars, before: before, baseOffset: baseOffset)
        var output = String.UnicodeScalarView()
        var cursor = 0
        var stripped = 0
        var revealed = 0
        var refusing: [HiddenRun] = []
        for run in runs {
            output.append(contentsOf: scalars[cursor..<(run.range.lowerBound - baseOffset)])
            cursor = run.range.upperBound - baseOffset
            switch policy.action(for: run) {
            case .keep:
                output.append(contentsOf: run.scalars)
            case .strip:
                stripped += run.scalars.count
            case .reveal:
                output.append(contentsOf: HiddenTextFormatter.marker(for: run).unicodeScalars)
                revealed += run.scalars.count
            case .refuse:
                stripped += run.scalars.count
                refusing.append(run)
            }
        }
        output.append(contentsOf: scalars[cursor...])
        let outcome: SanitizedText.Outcome
        if !refusing.isEmpty {
            outcome = .refused(runs: refusing)
        } else if stripped + revealed == 0 {
            outcome = .unchanged
        } else {
            outcome = .modified(stripped: stripped, revealed: revealed)
        }
        return Application(text: String(output), runs: runs, outcome: outcome)
    }
}

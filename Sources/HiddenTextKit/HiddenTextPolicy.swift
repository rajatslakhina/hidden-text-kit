/// What to do with a run.
public enum HiddenTextAction: String, Sendable, CaseIterable {
    /// Leave the scalars in place.
    case keep
    /// Remove the scalars.
    case strip
    /// Replace the run with a visible marker that says what it was and, when it decodes, what it spells.
    case reveal
    /// Remove the scalars and report the text as refused, so the caller can stop and ask.
    case refuse
}

/// Which action applies to which kind of run.
///
/// Three buckets, because they deserve different treatment: a run doing a legitimate job, a run
/// that is out of place, and an out-of-place run that decodes to a message.
public struct HiddenTextPolicy: Sendable, Equatable {
    public var legitimate: HiddenTextAction
    public var suspicious: HiddenTextAction
    public var payload: HiddenTextAction

    public init(
        legitimate: HiddenTextAction = .keep,
        suspicious: HiddenTextAction = .strip,
        payload: HiddenTextAction = .strip
    ) {
        self.legitimate = legitimate
        self.suspicious = suspicious
        self.payload = payload
    }

    /// Keep legitimate runs, strip everything out of place.
    public static let standard = HiddenTextPolicy()
    /// Refuse a text that spells something hidden; strip the rest of what is out of place.
    public static let strict = HiddenTextPolicy(payload: .refuse)
    /// Make every out-of-place run visible instead of removing it. For review screens and logs.
    public static let audit = HiddenTextPolicy(suspicious: .reveal, payload: .reveal)
    /// Remove every hidden scalar, legitimate ones included. For keyword matching only, never for
    /// display: it turns the flag of Scotland into a black flag and a family into three people.
    public static let matching = HiddenTextPolicy(legitimate: .strip)

    public func action(for run: HiddenRun) -> HiddenTextAction {
        guard run.isSuspicious else { return legitimate }
        return run.payload == nil ? suspicious : payload
    }
}

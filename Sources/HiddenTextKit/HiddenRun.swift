/// A maximal stretch of consecutive hidden scalars, and what it is doing there.
///
/// Runs are maximal across classes on purpose. A payload that alternates two classes, say a
/// zero-width space for 0 and a left-to-right mark for 1, would otherwise fall apart into single
/// characters that each look legitimate on their own.
public struct HiddenRun: Sendable, Equatable {
    /// Offsets into the scanned text's `unicodeScalars`, counted from 0.
    public let range: Range<Int>
    public let scalars: [Unicode.Scalar]
    public let verdict: HiddenRunVerdict
    /// What the run spells, when it decodes under one of the known smuggling encodings.
    public let payload: DecodedPayload?

    public init(
        range: Range<Int>,
        scalars: [Unicode.Scalar],
        verdict: HiddenRunVerdict,
        payload: DecodedPayload?
    ) {
        self.range = range
        self.scalars = scalars
        self.verdict = verdict
        self.payload = payload
    }

    public var isSuspicious: Bool { verdict.isSuspicious }

    /// Every class present in the run, in declaration order.
    public var classes: [HiddenScalarClass] {
        let present = Set(scalars.compactMap { HiddenScalarClass($0) })
        return HiddenScalarClass.allCases.filter { present.contains($0) }
    }
}

/// Whether a run is text doing its job or content a reader cannot see.
public enum HiddenRunVerdict: Sendable, Equatable {
    case legitimate(LegitimateUse)
    case suspicious(Suspicion)

    public var isSuspicious: Bool {
        if case .suspicious = self { return true }
        return false
    }
}

/// A job an invisible character legitimately does in real text.
public enum LegitimateUse: String, Sendable, CaseIterable {
    /// Tag letters after U+1F3F4, closed by U+E007F: the flags of England, Scotland and Wales
    /// (UTS #51 emoji tag sequences).
    case subdivisionFlag
    /// One variation selector after a visible base: emoji or text presentation, a keycap, a
    /// standardized variant, a CJK ideographic variant.
    case variationSequence
    /// A zero-width joiner between two emoji, optionally after U+FE0F: family, profession and
    /// pride-flag sequences.
    case emojiJoiner
    /// A ZWJ or ZWNJ between letters or marks, at least one of them outside ASCII: Persian, Arabic,
    /// Devanagari, Malayalam and other scripts that shape on it.
    case scriptJoiner
    /// A zero-width space between letters of a script written without spaces: Thai, Lao, Tibetan,
    /// Myanmar, Khmer.
    case wordBreakHint
    /// U+FEFF as the very first scalar of the text.
    case byteOrderMark
    /// A left-to-right, right-to-left or Arabic letter mark.
    case directionMark
    /// A direction isolate with its partner in the same paragraph.
    case balancedIsolate
    /// A soft hyphen between two letters.
    case softHyphen
}

/// Why a run is treated as hidden content rather than as text doing its job.
public enum Suspicion: String, Sendable, CaseIterable {
    /// Tag characters outside a subdivision flag. They spell ASCII that a screen does not show.
    case tagRun
    /// Two or more variation selectors in a row. A variation sequence uses exactly one.
    case selectorRun
    /// A variation selector with no visible base before it.
    case orphanSelector
    /// Two or more invisible characters in a row of any other kind.
    case invisibleRun
    /// A single zero-width character or soft hyphen where no script or emoji needs it.
    case outOfContext
    /// A bidi embedding or override, U+202A to U+202E: the Trojan Source reordering primitive.
    case bidiOverride
    /// A direction isolate with no partner in its paragraph.
    case unbalancedIsolate
    /// A format character with no ordinary job in chat text: an invisible math operator, a
    /// Hangul filler, an interlinear annotation mark.
    case formatCharacter
}

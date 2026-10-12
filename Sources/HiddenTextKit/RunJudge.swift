/// Decides whether a run is doing a job real text needs.
///
/// The rules read only the run, the visible scalar on each side of it, whether it starts the
/// text, and, for an isolate, whether it has a partner. That locality is what lets
/// `HiddenTextStreamFilter` reach the same decision chunk by chunk as a whole-text scan.
enum RunJudge {
    struct Context {
        let before: Unicode.Scalar?
        let after: Unicode.Scalar?
        let startsText: Bool
        let isBalancedIsolate: Bool
    }

    static func verdict(for run: [Unicode.Scalar], in context: Context) -> HiddenRunVerdict {
        if run.count == 1 {
            return single(run[0], in: context)
        }
        if isSubdivisionFlag(run, before: context.before) {
            return .legitimate(.subdivisionFlag)
        }
        if run == ["\u{FE0F}", "\u{200D}"], isPictographic(context.before), isPictographic(context.after) {
            return .legitimate(.emojiJoiner)
        }
        if run.contains(where: { HiddenScalarClass($0) == .tag }) {
            return .suspicious(.tagRun)
        }
        if run.allSatisfy({ HiddenScalarClass($0) == .variationSelector }) {
            return .suspicious(.selectorRun)
        }
        return .suspicious(.invisibleRun)
    }

    private static func single(_ scalar: Unicode.Scalar, in context: Context) -> HiddenRunVerdict {
        switch HiddenScalarClass(scalar) {
        case .tag:
            return .suspicious(.tagRun)
        case .variationSelector:
            return isBase(context.before) ? .legitimate(.variationSequence) : .suspicious(.orphanSelector)
        case .zeroWidth:
            return zeroWidth(scalar, in: context)
        case .bidiControl:
            guard scalar.value >= 0x2066 else { return .suspicious(.bidiOverride) }
            return context.isBalancedIsolate ? .legitimate(.balancedIsolate) : .suspicious(.unbalancedIsolate)
        case .bidiMark:
            return .legitimate(.directionMark)
        case .invisibleFormat, .none:
            guard scalar == "\u{00AD}" else { return .suspicious(.formatCharacter) }
            let hyphen = isLetter(context.before) && isLetter(context.after)
            return hyphen ? .legitimate(.softHyphen) : .suspicious(.outOfContext)
        }
    }

    private static func zeroWidth(_ scalar: Unicode.Scalar, in context: Context) -> HiddenRunVerdict {
        switch scalar.value {
        case 0x200D:
            if isPictographic(context.before) && isPictographic(context.after) {
                return .legitimate(.emojiJoiner)
            }
            return joinsLetters(context) ? .legitimate(.scriptJoiner) : .suspicious(.outOfContext)
        case 0x200C:
            return joinsLetters(context) ? .legitimate(.scriptJoiner) : .suspicious(.outOfContext)
        case 0x200B:
            let hint = isUnspacedScript(context.before) && isUnspacedScript(context.after)
            return hint ? .legitimate(.wordBreakHint) : .suspicious(.outOfContext)
        case 0xFEFF:
            return context.startsText ? .legitimate(.byteOrderMark) : .suspicious(.outOfContext)
        default:
            return .suspicious(.outOfContext)
        }
    }

    /// U+1F3F4, then three to six tag digits or lowercase tag letters, then U+E007F.
    static func isSubdivisionFlag(_ run: [Unicode.Scalar], before: Unicode.Scalar?) -> Bool {
        guard before == "\u{1F3F4}", run.last == "\u{E007F}" else { return false }
        let spec = run.dropLast()
        return (3...6).contains(spec.count) && spec.allSatisfy {
            (0xE0030...0xE0039).contains($0.value) || (0xE0061...0xE007A).contains($0.value)
        }
    }

    static func isBase(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        return !scalar.properties.isWhitespace && scalar.properties.generalCategory != .control
    }

    /// An emoji outside ASCII. Digits, `#` and `*` carry the Emoji property too, and a joiner
    /// between two digits is not an emoji sequence.
    static func isPictographic(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        return scalar.value > 0x7F && scalar.properties.isEmoji
    }

    static func isLetter(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return true
        default:
            return false
        }
    }

    static func isLetterOrMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark:
            return true
        default:
            return isLetter(scalar)
        }
    }

    /// Letters or marks on both sides, at least one of them outside ASCII. A joiner between two
    /// ASCII letters shapes nothing in any script.
    static func joinsLetters(_ context: Context) -> Bool {
        guard let before = context.before, let after = context.after,
              isLetterOrMark(before), isLetterOrMark(after) else { return false }
        return before.value > 0x7F || after.value > 0x7F
    }

    /// Thai, Lao, Tibetan, Myanmar and Khmer, which are written without spaces between words.
    static func isUnspacedScript(_ scalar: Unicode.Scalar?) -> Bool {
        guard let value = scalar?.value else { return false }
        switch value {
        case 0x0E00...0x0EFF, 0x0F00...0x0FFF, 0x1000...0x109F, 0x1780...0x17FF:
            return true
        default:
            return false
        }
    }

    struct IsolatePair: Equatable {
        let open: Int
        let close: Int
    }

    struct IsolatePairs: Equatable {
        var pairs: [IsolatePair] = []
        /// Openers still waiting for a U+2069 when the text ran out, in an unfinished paragraph.
        var unclosed: [Int] = []

        var balanced: Set<Int> {
            Set(pairs.flatMap { [$0.open, $0.close] })
        }
    }

    /// Pairs LRI, RLI and FSI with PDI the way the Unicode bidi algorithm does: innermost first,
    /// and never across a paragraph separator.
    static func isolatePairs(in scalars: [Unicode.Scalar]) -> IsolatePairs {
        var result = IsolatePairs()
        var stack: [Int] = []
        for (index, scalar) in scalars.enumerated() {
            switch scalar.value {
            case 0x2066...0x2068:
                stack.append(index)
            case 0x2069:
                if let open = stack.popLast() {
                    result.pairs.append(IsolatePair(open: open, close: index))
                }
            case 0x0A, 0x0D, 0x1C...0x1E, 0x85, 0x2029:
                stack.removeAll()
            default:
                break
            }
        }
        result.unclosed = stack
        return result
    }
}

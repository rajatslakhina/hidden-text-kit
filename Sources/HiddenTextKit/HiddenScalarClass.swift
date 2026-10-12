/// The families of Unicode scalars that take up no visible space in ordinary rendering.
///
/// Every family has a legitimate job somewhere in real text, so membership alone is never a
/// finding. The class says what a scalar is; `HiddenRun.verdict` says whether one particular
/// occurrence is doing that job.
public enum HiddenScalarClass: String, Sendable, CaseIterable {
    /// U+E0000 to U+E007F. The block mirrors printable ASCII, so a run of tags spells text that a
    /// tokenizer reads and a screen does not draw. Its one current legitimate use is the
    /// subdivision flag, such as the flag of Scotland.
    case tag
    /// U+FE00 to U+FE0F, U+E0100 to U+E01EF and the Mongolian free variation selectors. One
    /// selector after a base character picks a glyph; a run of them can carry a byte each.
    case variationSelector
    /// U+200B zero-width space, U+200C ZWNJ, U+200D ZWJ, U+2060 word joiner, U+FEFF byte order mark.
    case zeroWidth
    /// U+202A to U+202E and U+2066 to U+2069: embeddings, overrides and isolates, which change the
    /// order in which a reader sees characters.
    case bidiControl
    /// U+200E, U+200F and U+061C. They set the direction of neutral characters next to them and
    /// cannot reorder text on their own.
    case bidiMark
    /// Other default-ignorable format characters and blank fillers: soft hyphen, combining
    /// grapheme joiner, invisible math operators, Hangul fillers, Khmer inherent vowels,
    /// interlinear annotation marks, shorthand format controls, musical formatting characters.
    case invisibleFormat

    /// The class of `scalar`, or nil when it is an ordinary visible character.
    public init?(_ scalar: Unicode.Scalar) {
        switch scalar.value {
        case 0xE0000...0xE007F:
            self = .tag
        case 0xFE00...0xFE0F, 0xE0100...0xE01EF, 0x180B...0x180D, 0x180F:
            self = .variationSelector
        case 0x200B...0x200D, 0x2060, 0xFEFF:
            self = .zeroWidth
        case 0x202A...0x202E, 0x2066...0x2069:
            self = .bidiControl
        case 0x200E, 0x200F, 0x061C:
            self = .bidiMark
        case 0x00AD, 0x034F, 0x115F, 0x1160, 0x17B4, 0x17B5, 0x180E, 0x2061...0x2064,
             0x206A...0x206F, 0x3164, 0xFFA0, 0xFFF9...0xFFFB, 0x1BCA0...0x1BCA3,
             0x1D173...0x1D17A:
            self = .invisibleFormat
        default:
            return nil
        }
    }

    /// Whether `scalar` belongs to any hidden class.
    public static func isHidden(_ scalar: Unicode.Scalar) -> Bool {
        HiddenScalarClass(scalar) != nil
    }
}

import Foundation

/// The smuggling encodings this package can read back.
public enum PayloadEncoding: String, Sendable, CaseIterable {
    /// Tag characters U+E0020 to U+E007E, one per printable ASCII character.
    case unicodeTags
    /// One byte per selector: U+FE00 to U+FE0F carry 0 to 15, U+E0100 to U+E01EF carry 16 to 255.
    case variationSelectorBytes
    /// Two invisible characters standing for 0 and 1, eight per byte, most significant bit first,
    /// optionally with a third character between bytes.
    case zeroWidthBinary
}

/// What a hidden run spells.
public struct DecodedPayload: Sendable, Equatable {
    public let encoding: PayloadEncoding
    public let bytes: [UInt8]
    /// The bytes as UTF-8, or nil when they are not valid UTF-8.
    public let text: String?

    public init(encoding: PayloadEncoding, bytes: [UInt8]) {
        self.encoding = encoding
        self.bytes = bytes
        self.text = String(bytes: bytes, encoding: .utf8)
    }
}

/// Reads a run back under each known encoding, most specific first.
///
/// Tags are a fixed mapping, so any tag in a run decodes. Selector bytes need two or more
/// selectors, because one selector after a base is an ordinary variation sequence. Zero-width
/// binary is a guess about framing, so it is only reported when every byte it produces is
/// printable ASCII: a decoder that reported garbage would make every stray run look like a message.
enum PayloadDecoder {
    static func decode(_ run: [Unicode.Scalar]) -> DecodedPayload? {
        let tagBytes = run.compactMap(tagByte)
        if !tagBytes.isEmpty {
            return DecodedPayload(encoding: .unicodeTags, bytes: tagBytes)
        }
        let selectorBytes = run.compactMap(selectorByte)
        if selectorBytes.count >= 2 {
            return DecodedPayload(encoding: .variationSelectorBytes, bytes: selectorBytes)
        }
        return zeroWidthBinary(run)
    }

    static func tagByte(_ scalar: Unicode.Scalar) -> UInt8? {
        guard (0xE0020...0xE007E).contains(scalar.value) else { return nil }
        return UInt8(scalar.value - 0xE0000)
    }

    static func selectorByte(_ scalar: Unicode.Scalar) -> UInt8? {
        switch scalar.value {
        case 0xFE00...0xFE0F: return UInt8(scalar.value - 0xFE00)
        case 0xE0100...0xE01EF: return UInt8(scalar.value - 0xE0100 + 16)
        default: return nil
        }
    }

    static func zeroWidthBinary(_ run: [Unicode.Scalar]) -> DecodedPayload? {
        var alphabet: [Unicode.Scalar] = []
        for scalar in run where !alphabet.contains(scalar) {
            alphabet.append(scalar)
        }
        for framing in framings(of: run, alphabet: alphabet) {
            let bytes = framing.groups.map { group in
                group.reduce(UInt8(0)) { ($0 << 1) | ($1 == framing.one ? 1 : 0) }
            }
            if bytes.allSatisfy(isPrintable) {
                return DecodedPayload(encoding: .zeroWidthBinary, bytes: bytes)
            }
        }
        return nil
    }

    static func isPrintable(_ byte: UInt8) -> Bool {
        (0x20...0x7E).contains(byte) || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    private struct Framing {
        let one: Unicode.Scalar
        let groups: [[Unicode.Scalar]]
    }

    /// Two symbols: bits, eight to a byte. Three symbols: each in turn as the byte separator.
    /// Both bit assignments are tried; for printable ASCII at most one can succeed, because
    /// swapping them inverts the top bit.
    private static func framings(of run: [Unicode.Scalar], alphabet: [Unicode.Scalar]) -> [Framing] {
        switch alphabet.count {
        case 2:
            guard run.count.isMultiple(of: 8) else { return [] }
            let groups = stride(from: 0, to: run.count, by: 8).map { Array(run[$0..<$0 + 8]) }
            return orders(alphabet[0], alphabet[1], groups)
        case 3:
            return alphabet.flatMap { separator -> [Framing] in
                let bits = alphabet.filter { $0 != separator }
                let groups = run.split(separator: separator).map { Array($0) }
                guard groups.allSatisfy({ $0.count == 8 }) else { return [] }
                return orders(bits[0], bits[1], groups)
            }
        default:
            return []
        }
    }

    private static func orders(
        _ first: Unicode.Scalar,
        _ second: Unicode.Scalar,
        _ groups: [[Unicode.Scalar]]
    ) -> [Framing] {
        [Framing(one: second, groups: groups), Framing(one: first, groups: groups)]
    }
}

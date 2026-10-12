import HiddenTextKit

/// Builders for the encodings the demo attacks with. Each is the published scheme, written out
/// here so the demo does not depend on the package to construct what the package must detect.
enum Encode {
    /// Each printable ASCII character as its tag twin, U+E0000 + the ASCII value.
    static func tags(_ ascii: String) -> String {
        String(String.UnicodeScalarView(ascii.unicodeScalars.map { scalar($0.value + 0xE0000) }))
    }

    /// UTF-8 bytes as variation selectors: 0 to 15 on U+FE00, 16 to 255 on U+E0100.
    static func selectorBytes(_ text: String) -> String {
        let scalars = text.utf8.map { byte in
            byte < 16 ? scalar(0xFE00 + UInt32(byte)) : scalar(0xE0100 + UInt32(byte) - 16)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// ASCII as bits, U+200B for 0 and U+200C for 1, most significant bit first.
    static func zeroWidthBinary(_ ascii: String) -> String {
        var out = String.UnicodeScalarView()
        for byte in ascii.utf8 {
            for shift in (0..<8).reversed() {
                out.append((byte >> UInt8(shift)) & 1 == 1 ? "\u{200C}" : "\u{200B}")
            }
        }
        return String(out)
    }

    static func scalars(_ values: UInt32...) -> String {
        String(String.UnicodeScalarView(values.map(scalar)))
    }

    static func scalar(_ value: UInt32) -> Unicode.Scalar {
        Unicode.Scalar(value) ?? "\u{FFFD}"
    }
}

func heading(_ title: String) {
    print("")
    print(title)
    print(String(repeating: "=", count: title.count))
}

func padded(_ text: String, _ width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
}

func check(_ condition: Bool) -> String {
    condition ? "yes" : "NO"
}

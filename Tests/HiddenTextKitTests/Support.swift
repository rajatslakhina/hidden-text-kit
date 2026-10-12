import HiddenTextKit

/// A string built from code points, so no test source has to contain an invisible character.
func str(_ values: UInt32...) -> String {
    String(String.UnicodeScalarView(values.map { Unicode.Scalar($0)! }))
}

func sc(_ value: UInt32) -> Unicode.Scalar {
    Unicode.Scalar(value)!
}

/// Printable ASCII as tag characters.
func tags(_ ascii: String) -> String {
    String(String.UnicodeScalarView(ascii.unicodeScalars.map { Unicode.Scalar($0.value + 0xE0000)! }))
}

/// UTF-8 bytes as variation selectors, the emoji-smuggling scheme.
func selectorBytes(_ bytes: [UInt8]) -> String {
    String(String.UnicodeScalarView(bytes.map { byte in
        byte < 16 ? Unicode.Scalar(0xFE00 + UInt32(byte))! : Unicode.Scalar(0xE0100 + UInt32(byte) - 16)!
    }))
}

/// ASCII as bits with two chosen scalars, optionally a separator between bytes.
func binary(_ ascii: String, zero: UInt32 = 0x200B, one: UInt32 = 0x200C, separator: UInt32? = nil) -> String {
    var out = String.UnicodeScalarView()
    for (index, byte) in ascii.utf8.enumerated() {
        if let separator, index > 0 { out.append(sc(separator)) }
        for shift in (0..<8).reversed() {
            out.append(sc((byte >> UInt8(shift)) & 1 == 1 ? one : zero))
        }
    }
    return String(out)
}

let scotland = str(0x1F3F4, 0xE0067, 0xE0062, 0xE0073, 0xE0063, 0xE0074, 0xE007F)
let family = str(0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467)
let rainbow = str(0x1F3F3, 0xFE0F, 0x200D, 0x1F308)
let persian = str(0x645, 0x6CC, 0x200C, 0x62E, 0x648, 0x627, 0x647, 0x645)

/// Verdicts of every run, for compact assertions.
func verdicts(_ text: String) -> [HiddenRunVerdict] {
    HiddenTextScanner().scan(text).runs.map(\.verdict)
}

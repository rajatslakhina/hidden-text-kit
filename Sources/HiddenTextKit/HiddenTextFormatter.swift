/// Turns hidden content into text a person can read.
public enum HiddenTextFormatter {
    /// Brackets that cannot be confused with anything a model or a user typed by accident:
    /// U+27E6 and U+27E7, mathematical white square brackets.
    public static let openBracket = "\u{27E6}"
    public static let closeBracket = "\u{27E7}"

    /// The visible stand-in `.reveal` writes in place of a run.
    public static func marker(for run: HiddenRun) -> String {
        guard let payload = run.payload else {
            return openBracket + codePoints(run.scalars) + closeBracket
        }
        return openBracket + "hidden \(payload.encoding.rawValue): " + quoted(payload) + closeBracket
    }

    /// `U+200B U+200C U+200B U+200C +12 more`.
    public static func codePoints(_ scalars: [Unicode.Scalar], limit: Int = 4) -> String {
        let shown = scalars.prefix(limit).map(codePoint).joined(separator: " ")
        let rest = scalars.count - min(scalars.count, limit)
        return rest > 0 ? "\(shown) +\(rest) more" : shown
    }

    public static func codePoint(_ scalar: Unicode.Scalar) -> String {
        let hex = String(scalar.value, radix: 16, uppercase: true)
        return "U+" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
    }

    /// A payload as a quoted literal that is safe to print.
    public static func quoted(_ payload: DecodedPayload) -> String {
        guard let text = payload.text else {
            return "<\(payload.bytes.count) bytes, not UTF-8>"
        }
        return "\"" + escaped(text) + "\""
    }

    /// Printable ASCII as itself; quotes and backslashes escaped; everything else, including any
    /// hidden layer nested inside a payload, as `\u{...}`.
    public static func escaped(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x22, 0x5C:
                out += "\\" + String(scalar)
            case 0x20...0x7E:
                out.unicodeScalars.append(scalar)
            default:
                out += "\\u{" + String(scalar.value, radix: 16, uppercase: true) + "}"
            }
        }
        return out
    }

    /// Every hidden scalar in `text`, legitimate or not, written out as a bracketed code point.
    /// For showing a reviewer what a string really contains.
    public static func visible(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if HiddenScalarClass.isHidden(scalar) {
                out.append(contentsOf: (openBracket + codePoint(scalar) + closeBracket).unicodeScalars)
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }

    /// One line: `clean`, `clean (2 legitimate runs kept)`, or the suspicious runs, their scalar
    /// count per class, and what each payload spells.
    public static func summary(_ report: HiddenTextReport) -> String {
        let suspicious = report.suspiciousRuns
        guard !suspicious.isEmpty else {
            let kept = report.legitimateRuns.count
            return kept == 0 ? "clean" : "clean (\(plural(kept, "legitimate run")) kept)"
        }
        let byClass = report.suspiciousScalarsByClass
        let classes = HiddenScalarClass.allCases
            .compactMap { hiddenClass in byClass[hiddenClass].map { "\(hiddenClass.rawValue) \($0)" } }
            .joined(separator: ", ")
        var line = "\(plural(suspicious.count, "suspicious run")), "
            + "\(plural(report.suspiciousScalarCount, "scalar")) (\(classes))"
        for payload in report.payloads {
            line += "; \(payload.encoding.rawValue) " + quoted(payload)
        }
        return line
    }

    static func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)" + (count == 1 ? "" : "s")
    }
}

import HiddenTextKit

/// The legitimate corpus: text in which every invisible character is doing a job.
let legitimateCorpus: [(String, String)] = [
    ("flag of Scotland", Encode.scalars(0x1F3F4, 0xE0067, 0xE0062, 0xE0073, 0xE0063, 0xE0074, 0xE007F)),
    ("family emoji", Encode.scalars(0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467)),
    ("rainbow flag", Encode.scalars(0x1F3F3, 0xFE0F, 0x200D, 0x1F308)),
    ("heart on fire", Encode.scalars(0x2764, 0xFE0F, 0x200D, 0x1F525)),
    ("keycap one", Encode.scalars(0x31, 0xFE0F, 0x20E3)),
    ("Persian mi-khaham", Encode.scalars(0x645, 0x6CC, 0x200C, 0x62E, 0x648, 0x627, 0x647, 0x645)),
    ("Devanagari half-form", Encode.scalars(0x915, 0x94D, 0x200D, 0x937)),
    ("Thai word break", Encode.scalars(0xE2A, 0xE27, 0xE31, 0xE2A, 0xE14, 0xE35, 0x200B, 0xE04, 0xE23, 0xE31, 0xE1A)),
    ("byte order mark", "\u{FEFF}Quarterly report"),
    ("soft hyphens", "Donau\u{00AD}dampf\u{00AD}schiff"),
    ("Hebrew with RLM", Encode.scalars(0x5E9, 0x5DC, 0x5D5, 0x5DD, 0x200F) + " (hello)"),
    ("isolated user name", "User \u{2068}" + Encode.scalars(0x645, 0x627, 0x647, 0x631) + "\u{2069} joined"),
    ("CJK variant", Encode.scalars(0x845B, 0xE0100) + " (Katsushika)")
]

/// Scenario 2: what an honest sanitizer must leave alone.
func survivors() {
    heading("2. Text that must survive: every invisible character here is doing a job")
    let scanner = HiddenTextScanner()
    let standard = HiddenTextSanitizer()
    let matching = HiddenTextSanitizer(policy: .matching)
    var keptByStandard = 0
    var changedByMatching = 0
    print(padded("text", 22) + padded("kept as", 20) + padded("standard", 11) + "strip-everything")
    for (label, text) in legitimateCorpus {
        let report = scanner.scan(text)
        let uses = report.legitimateRuns.compactMap { run -> String? in
            if case let .legitimate(use) = run.verdict { return use.rawValue }
            return nil
        }
        let unchanged = standard.sanitize(text).text == text && report.isClean
        let stripped = matching.sanitize(text).text
        keptByStandard += unchanged ? 1 : 0
        changedByMatching += stripped == text ? 0 : 1
        let damage = "\(text.count) -> \(stripped.count) characters, \(text.unicodeScalars.count) -> "
            + "\(stripped.unicodeScalars.count) scalars"
        print(padded(label, 22) + padded(Set(uses).sorted().joined(separator: "+"), 20)
            + padded(unchanged ? "unchanged" : "CHANGED", 11) + damage)
    }
    print("")
    print("standard policy left \(keptByStandard) of \(legitimateCorpus.count) unchanged and found nothing suspicious")
    print("stripping every hidden scalar changed \(changedByMatching) of \(legitimateCorpus.count)")
    if let payload = scanner.scan(legitimateCorpus[0].1).runs.first?.payload {
        print("the Scotland flag's tags decode to \(HiddenTextFormatter.quoted(payload)); the run is kept as a flag")
    }
}

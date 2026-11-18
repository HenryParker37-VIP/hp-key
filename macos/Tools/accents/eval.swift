// Measures AccentRestorer: strips every accent from real Vietnamese text, restores it, and counts words.
// usage: eval AccentModel.bin TEXT.txt [examples]
// Built and run by Tools/accents/eval.sh with the app's own App/Model/AccentRestorer.swift.
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let data = FileManager.default.contents(atPath: args[1]),
      let restorer = AccentRestorer(data: data),
      let text = try? String(contentsOfFile: args[2], encoding: .utf8) else {
    print("usage: eval AccentModel.bin TEXT.txt [examples]"); exit(2)
}
let examples = args.count > 3 ? Int(args[3]) ?? 0 : 0
let env = ProcessInfo.processInfo.environment
if let v = env["HPK_K"].flatMap(Double.init) { restorer.smoothing = v }
if let v = env["HPK_SW"].flatMap(Double.init) { restorer.switchChance = v }
if let v = env["HPK_SE"].flatMap(Double.init) { restorer.startEnglish = v }
if env["HPK_NOCOMMA"] != nil { restorer.joinCommas = false }
if let v = env["HPK_K3"].flatMap(Double.init) { restorer.tripleBackoff = v }

/// hòa and hoà are the same word (tone placement styles): compare in the modern placement.
func modern(_ w: String) -> String {
    let marks: Set<UInt32> = [0x300, 0x301, 0x303, 0x309, 0x323]
    let scalars = Array(w.decomposedStringWithCanonicalMapping.unicodeScalars)
    guard let t = scalars.first(where: { marks.contains($0.value) }) else { return w }
    var bare = Array(String(String.UnicodeScalarView(scalars.filter { $0 != t })).precomposedStringWithCanonicalMapping)
    let b = AccentRestorer.stripAccents(String(bare)).lowercased()
    guard bare.count >= 2, b.hasSuffix("oa") || b.hasSuffix("oe") || (b.hasSuffix("uy") && !b.hasSuffix("quy")) else { return w }
    bare[bare.count - 1] = Character((String(bare[bare.count - 1]) + String(t)).precomposedStringWithCanonicalMapping)
    return String(bare)
}
func words(_ s: String) -> [String] {
    s.precomposedStringWithCanonicalMapping.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "’" }).map { modern(String($0)) }
}

var accented = 0, accentedOK = 0      // words written with accents: restored exactly?
var plain = 0, plainKept = 0          // words written without accents (English, "anh", "ban"...): left alone?
var lines = 0, linesOK = 0, shown = 0
let start = Date()
for line in text.split(separator: "\n") {
    let original = String(line)
    let input = AccentRestorer.stripAccents(original)
    let output = restorer.restore(input)
    let a = words(original), b = words(output)
    guard a.count == b.count else { continue }
    lines += 1
    var allOK = true
    for (x, y) in zip(a, b) {
        if x.unicodeScalars.allSatisfy({ $0.isASCII }) { plain += 1; if x == y { plainKept += 1 } else { allOK = false } }
        else { accented += 1; if x == y { accentedOK += 1 } else { allOK = false } }
    }
    if allOK { linesOK += 1 } else if shown < examples { shown += 1; print("  in : \(input)\n  out: \(output)\n  ref: \(original)\n") }
}
func pct(_ a: Int, _ b: Int) -> String { String(format: "%.1f%%", b == 0 ? 0 : 100 * Double(a) / Double(b)) }
let ms = Date().timeIntervalSince(start) * 1000 / Double(max(lines, 1))
print("words with accents restored exactly: \(pct(accentedOK, accented)) of \(accented)")
print("words without accents left alone:    \(pct(plainKept, plain)) of \(plain)")
print("all words right in the line:         \(pct(linesOK, lines)) of \(lines) lines")
print(String(format: "time: %.2f ms per line", ms))

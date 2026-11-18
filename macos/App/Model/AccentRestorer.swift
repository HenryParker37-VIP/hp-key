// Copyright © 2026 Nguyen Manh Tuan Hung (Henry Parker). Licensed under GPL-3.0.
//
// HP Key: adds Vietnamese accents to text typed without them ("toi di hoc" → "tôi đi học"), on this Mac.
// AccentModel.bin (built by Tools/accents/build_model.py) holds word and word-pair counts. Each word
// typed without accents can be any accented form with the same letters, or an English word kept as
// typed; the most likely sentence wins (second-order Viterbi: each word sees the two before it). Words that already
// carry accents are kept and used as context. Nothing is stored or sent anywhere.

import Foundation

final class AccentRestorer {
    static let shared: AccentRestorer? = {
        guard let url = Bundle.main.url(forResource: "AccentModel", withExtension: "bin"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return AccentRestorer(data: data)
    }()

    /// Pull toward plain word frequency when a pair is rare (Dirichlet smoothing).
    var smoothing: Double = 400
    /// Weight of the two-word estimate when three words in a row were never seen together.
    var tripleBackoff: Double = 0.7
    /// Chance that the next word changes language (Vietnamese ↔ English).
    var switchChance: Double = 0.08
    /// Chance that a run of words starts in English.
    var startEnglish: Double = 0.25
    /// hoà / khoẻ / thuỷ (true) or hòa / khỏe / thủy (false).
    var modernTone = true
    /// Read on across a comma ("rồi, bạn") instead of starting over.
    var joinCommas = false

    private var words: [String] = []
    private var counts: [Double] = []      // corpus counts: how often a word starts a pair
    private var priors: [Double] = []      // corpus + everyday speech: how likely a word is on its own
    private var idOf: [String: Int] = [:]
    private var candidates: [String: [Int]] = [:]   // base (no marks) → ids of its accented forms
    private var pairKeys: [UInt32] = []             // prev << 16 | next, sorted
    private var pairCounts: [UInt32] = []
    private var tripleKeys: [UInt64] = []           // a << 32 | b << 16 | next, sorted
    private var tripleCounts: [UInt32] = []
    private var english: [String: Double] = [:]     // word → log probability
    private var priorTotal: Double = 1

    private static let keepAsTyped = -1   // an English (or unknown) word
    private static let noContext = -2     // an accented word the model does not know

    init?(data: Data) {
        var at = 0
        func u8() -> Int { defer { at += 1 }; return Int(data[data.startIndex + at]) }
        func u16() -> UInt32 { UInt32(u8()) | UInt32(u8()) << 8 }
        func u32() -> UInt32 { u16() | u16() << 16 }
        func u64() -> Double { Double(UInt64(u32()) | UInt64(u32()) << 32) }
        func str(_ n: Int) -> String { defer { at += n }; let s = data.startIndex + at; return String(decoding: data[s..<s + n], as: UTF8.self) }
        guard data.count > 44, str(4) == "HPKA", u32() == 3 else { return nil }
        let nVocab = Int(u32()), nPairs = Int(u32()), nTriples = Int(u32()), nEnglish = Int(u32())
        _ = u64(); priorTotal = max(u64(), 1); let englishTotal = max(u64(), 1)
        words.reserveCapacity(nVocab); counts.reserveCapacity(nVocab); priors.reserveCapacity(nVocab)
        for id in 0..<nVocab {
            guard at + 2 < data.count else { return nil }
            let w = str(u8()), b = str(u8()), c = u32(), p = u32()
            words.append(w); counts.append(Double(max(c, 1))); priors.append(Double(max(p, 1))); idOf[w] = id
            if id > 0 { candidates[b, default: []].append(id) }
        }
        guard data.count >= at + nPairs * 8 else { return nil }
        pairKeys.reserveCapacity(nPairs); pairCounts.reserveCapacity(nPairs)
        for _ in 0..<nPairs { pairKeys.append(u16() << 16 | u16()); pairCounts.append(u32()) }
        guard data.count >= at + nTriples * 10 else { return nil }
        tripleKeys.reserveCapacity(nTriples); tripleCounts.reserveCapacity(nTriples)
        for _ in 0..<nTriples { tripleKeys.append(UInt64(u16()) << 32 | UInt64(u16()) << 16 | UInt64(u16())); tripleCounts.append(u32()) }
        for _ in 0..<nEnglish {
            guard at < data.count else { return nil }
            let w = str(u8()); english[w] = log(Double(max(u32(), 1)) / englishTotal)
        }
    }

    // MARK: text in, text out

    /// The text with accents added to words typed without them; everything else is kept as it was.
    func restore(_ text: String) -> String {
        var out = "", run: [Substring] = [], gaps: [Substring] = []
        func flush() {
            guard !run.isEmpty else { return }
            let chosen = decode(run)
            for k in run.indices { out += chosen[k]; if k < gaps.count { out += gaps[k] } }
            run.removeAll(); gaps.removeAll()
        }
        func isApostrophe(_ c: Character) -> Bool { c == "'" || c == "’" }
        var i = text.startIndex
        while i < text.endIndex {
            guard text[i].isLetter else { out.append(text[i]); i = text.index(after: i); continue }
            // a word: letters, with apostrophes inside ("I've", "don't" stay one word)
            var j = i
            while j < text.endIndex {
                if text[j].isLetter { j = text.index(after: j); continue }
                let n = text.index(after: j)
                if isApostrophe(text[j]), n < text.endIndex, text[n].isLetter { j = n; continue }
                break
            }
            run.append(text[i..<j]); i = j
            // spaces (and a comma) between two words keep the run going; anything else ends it
            var k = i; while k < text.endIndex, text[k] == " " || text[k] == "\t" { k = text.index(after: k) }
            if joinCommas, k < text.endIndex, text[k] == "," { k = text.index(after: k); while k < text.endIndex, text[k] == " " || text[k] == "\t" { k = text.index(after: k) } }
            if k > i, k < text.endIndex, text[k].isLetter { gaps.append(text[i..<k]); i = k } else { flush() }
        }
        flush()
        return out
    }

    /// The accented text when the selection looks like Vietnamese typed without accents, else nil.
    func suggestion(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = trimmed.filter(\.isLetter)
        guard letters.count >= 4, trimmed.count <= 2000, letters.unicodeScalars.allSatisfy({ $0.isASCII }) else { return nil }
        let restored = restore(trimmed)
        guard restored != trimmed else { return nil }
        // most words must have become Vietnamese: a line of English with one lucky match is not shown
        let before = trimmed.split(whereSeparator: { !$0.isLetter }), after = restored.split(whereSeparator: { !$0.isLetter })
        let changed = zip(before, after).filter { $0 != $1 }.count
        return changed * 3 >= before.count ? restored : nil
    }

    // MARK: scoring

    private func pair(_ prev: Int, _ next: Int) -> Double {
        let key = UInt32(prev) << 16 | UInt32(next)
        var lo = 0, hi = pairKeys.count
        while lo < hi { let mid = (lo + hi) / 2; if pairKeys[mid] < key { lo = mid + 1 } else { hi = mid } }
        return lo < pairKeys.count && pairKeys[lo] == key ? Double(pairCounts[lo]) : 0
    }

    private func triple(_ a: Int, _ b: Int, _ next: Int) -> Double {
        let key = UInt64(a) << 32 | UInt64(b) << 16 | UInt64(next)
        var lo = 0, hi = tripleKeys.count
        while lo < hi { let mid = (lo + hi) / 2; if tripleKeys[mid] < key { lo = mid + 1 } else { hi = mid } }
        return lo < tripleKeys.count && tripleKeys[lo] == key ? Double(tripleCounts[lo]) : 0
    }

    private func prior(_ id: Int) -> Double { priors[id] / priorTotal }

    /// log score of `cur` after `before` and `prev`: three Vietnamese words use the triple counts.
    private func step(_ before: Int, _ prev: Int, _ cur: Int, englishScore: Double) -> Double {
        guard before >= 0, prev > 0, cur > 0 else { return step(prev, cur, englishScore: englishScore) }
        let two = (pair(prev, cur) + smoothing * prior(cur)) / (counts[prev] + smoothing)
        // rare triples are not stored, so a missing one is not evidence against it: back off to the
        // two-word estimate at a fixed discount ("stupid backoff")
        let seen = triple(before, prev, cur), context = pair(before, prev)
        let three = seen > 0 && context > 0 ? seen / context : tripleBackoff * two
        return log(1 - switchChance) + log(max(three, tripleBackoff * two))
    }

    /// log score of going from `prev` to `cur`: ids ≥ 0 are Vietnamese words (0 = start of the run).
    private func step(_ prev: Int, _ cur: Int, englishScore: Double) -> Double {
        let change = prev == 0 ? startEnglish : switchChance
        switch (prev, cur) {
        case (0..., 0...):
            return log(1 - change) + log((pair(prev, cur) + smoothing * prior(cur)) / (counts[prev] + smoothing))
        case (0..., Self.keepAsTyped), (Self.noContext, Self.keepAsTyped):
            return log(change) + englishScore
        case (Self.keepAsTyped, 0...):
            return log(switchChance) + log(prior(cur))
        case (Self.keepAsTyped, Self.keepAsTyped):
            return log(1 - switchChance) + englishScore
        case (Self.noContext, 0...):
            return log(1 - switchChance) + log(prior(cur))
        case (Self.keepAsTyped, Self.noContext):
            return log(switchChance)
        default:
            return log(1 - change)   // into an unknown accented word
        }
    }

    /// The best spelling of each word in a run of words separated by spaces.
    private func decode(_ run: [Substring]) -> [String] {
        var options: [[Int]] = [], englishScores: [Double] = []
        for w in run {
            let lower = w.lowercased()
            if lower.unicodeScalars.allSatisfy({ $0.isASCII }) {
                let en = english[lower]
                var opts = candidates[lower] ?? []
                // English when it is an English word, or when nothing Vietnamese is spelled this way
                if en != nil || opts.isEmpty { opts.append(Self.keepAsTyped) }
                options.append(opts); englishScores.append(en ?? log(1e-8))
            } else {
                options.append([idOf[lower] ?? Self.noContext]); englishScores.append(0)
            }
        }
        // states: (choice for the word before, choice for this word); the run starts as ("<s>", "<s>")
        struct State { var before: Int; var prev: Int; var score: Double; var back: Int }
        var layer = [State(before: 0, prev: 0, score: 0, back: -1)]
        var layers: [[State]] = []
        for (pos, opts) in options.enumerated() {
            var next: [State] = []
            for prev in pos == 0 ? [0] : options[pos - 1] {
                for id in opts {
                    var best = State(before: prev, prev: id, score: -.infinity, back: 0)
                    for (j, st) in layer.enumerated() where st.prev == prev {
                        let v = st.score + step(st.before, prev, id, englishScore: englishScores[pos])
                        if v > best.score { best.score = v; best.back = j }
                    }
                    next.append(best)
                }
            }
            layers.append(next); layer = next
        }
        var result = run.map(String.init)
        var j = layer.indices.max { layer[$0].score < layer[$1].score } ?? 0
        for pos in stride(from: run.count - 1, through: 0, by: -1) {
            let st = layers[pos][j]
            if st.prev > 0 { result[pos] = matchCase(tone(words[st.prev]), like: run[pos]) }
            j = st.back
        }
        return result
    }

    // MARK: spelling

    /// The model stores the modern placement (hoà); the classic one puts the tone on the o / u (hòa, thủy).
    private func tone(_ w: String) -> String {
        guard !modernTone else { return w }
        let marks: Set<UInt32> = [0x300, 0x301, 0x303, 0x309, 0x323]
        let scalars = Array(w.decomposedStringWithCanonicalMapping.unicodeScalars)
        guard let t = scalars.first(where: { marks.contains($0.value) }) else { return w }
        var bare = Array(String(String.UnicodeScalarView(scalars.filter { $0 != t })).precomposedStringWithCanonicalMapping)
        let b = Self.stripAccents(String(bare)).lowercased()
        guard bare.count >= 2, b.hasSuffix("oa") || b.hasSuffix("oe") || (b.hasSuffix("uy") && !b.hasSuffix("quy")) else { return w }
        bare[bare.count - 2] = Character((String(bare[bare.count - 2]) + String(t)).precomposedStringWithCanonicalMapping)
        return String(bare)
    }

    /// "Toi" → "Tôi", "TOI" → "TÔI", "toi" → "tôi".
    private func matchCase(_ word: String, like typed: Substring) -> String {
        guard let first = typed.first, first.isUppercase else { return word }
        if typed.count > 1, typed.allSatisfy({ $0.isUppercase }) { return word.uppercased() }
        return word.prefix(1).uppercased() + word.dropFirst()
    }

    /// Removes every mark: "Tiếng Việt" → "Tieng Viet".
    static func stripAccents(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
            .folding(options: .diacriticInsensitive, locale: nil)
    }
}

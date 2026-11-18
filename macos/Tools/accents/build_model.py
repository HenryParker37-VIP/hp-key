#!/usr/bin/env python3
"""Builds HP Key's accent-restoration model (macos/App/Resources/AccentModel.bin).

usage: build_model.py OUT.bin HELDOUT.txt SENTENCES.txt [SENTENCES.txt ...]

Input: Leipzig Corpora Collection sentence files ("id<TAB>sentence" per line, CC BY 4.0), plus the
word frequencies already in Tools/autoswitch (FrequencyWords / OpenSubtitles 2018, CC BY-SA 4.0):
vi_50k.txt makes everyday words ("nhé", "lắm", "thôi") weigh as much as news words; en_50k.txt with
en_spell_ok.txt and en_extra.txt lets the decoder keep English words as typed.

Every 20th sentence is held out (written to HELDOUT.txt, never counted) so accuracy is measured on
text the model has not seen. The model holds only counts, no sentence text. Tones are stored in the
modern placement (hoà, khoẻ, thuỷ); the app converts to the user's style.

Format (little endian):
  "HPKA" u32 version(3) u32 nVocab u32 nPairs u32 nTriples u32 nEnglish u64 corpusTokens u64 priorTotal u64 englishTotal
  nVocab x   { u8 len, utf8 word, u8 len, ascii base, u32 corpusCount, u32 prior }   id 0 is "<s>"
  nPairs x   { u16 prev, u16 next, u32 count }                                     sorted by (prev, next)
  nTriples x { u16 a, u16 b, u16 next, u32 count }                         sorted by (a, b, next)
  nEnglish x { u8 len, ascii word, u32 count }
"""
import os, re, struct, sys, unicodedata
from collections import Counter

MIN_WORD = 3        # a syllable needs this many occurrences to be a candidate
MIN_PAIR = 2        # a pair needs this many occurrences to be stored
MIN_TRIPLE = 3      # and a triple (three words in a row)
MAX_VOCAB = 65535   # ids are u16
MAX_ENGLISH = 30000
WORD = re.compile(r"[^\W\d_]+")
BOUNDARY = re.compile(r"[^\w\s,]|\d")   # punctuation (except commas) and digits end a run of words
TONES = "̣̀́̃̉"
HERE = os.path.dirname(os.path.abspath(__file__))
AUTOSWITCH = os.path.join(HERE, "..", "autoswitch")

def base(w):
    d = unicodedata.normalize("NFD", w.replace("đ", "d"))
    return "".join(c for c in d if not unicodedata.combining(c))

def modern(w):
    """Tone on the last vowel of a final oa / oe / uy: hòa → hoà, khỏe → khoẻ, thủy → thuỷ (quý stays)."""
    d = unicodedata.normalize("NFD", w)
    tone = next((c for c in d if c in TONES), None)
    if not tone: return w
    bare = unicodedata.normalize("NFC", d.replace(tone, ""))
    b = base(bare)
    if not (b.endswith(("oa", "oe")) or (b.endswith("uy") and not b.endswith("quy"))): return w
    return unicodedata.normalize("NFC", bare[:-1] + bare[-1] + tone)

def runs(sentence):
    """Runs of words not interrupted by punctuation or digits."""
    for chunk in BOUNDARY.split(unicodedata.normalize("NFC", sentence).lower().replace(",", " ")):
        words = WORD.findall(chunk)
        if words: yield words

def syllable(w):
    return len(w) <= 7 and base(w).isascii()

def freq(name):
    for line in open(os.path.join(AUTOSWITCH, name), encoding="utf-8"):
        parts = line.split()
        if len(parts) == 2: yield parts[0], int(parts[1])

def main():
    out, heldout, sources = sys.argv[1], sys.argv[2], sys.argv[3:]
    uni, bi, tri = Counter(), Counter(), Counter()
    with open(heldout, "w", encoding="utf-8") as ho:
        for path in sources:
            for i, line in enumerate(open(path, encoding="utf-8")):
                text = line.rstrip("\n").split("\t", 1)[-1]
                if i % 20 == 0: ho.write(text + "\n"); continue
                for words in runs(text):
                    pp, prev = None, "<s>"
                    for w in (modern(w) for w in words if syllable(w)):
                        uni[w] += 1; bi[(prev, w)] += 1
                        if pp is not None: tri[(pp, prev, w)] += 1
                        pp, prev = prev, w
    corpus_total = sum(uni.values())
    # everyday Vietnamese: subtitle frequencies, scaled to weigh as much as the corpus
    spoken = Counter()
    for w, c in freq("vi_50k.txt"):
        w = modern(unicodedata.normalize("NFC", w.lower()))
        if syllable(w) and WORD.fullmatch(w) and (not w.isascii() or w in uni): spoken[w] += c
    scale = corpus_total / max(sum(spoken.values()), 1)
    prior = Counter({w: uni[w] + round(spoken[w] * scale) for w in set(uni) | set(spoken)})
    vocab = ["<s>"] + [w for w, c in prior.most_common(MAX_VOCAB - 1) if c >= MIN_WORD]
    ids = {w: i for i, w in enumerate(vocab)}
    starts = sum(c for (p, _), c in bi.items() if p == "<s>")
    pairs = sorted((ids[p], ids[n], c) for (p, n), c in bi.items() if c >= MIN_PAIR and p in ids and n in ids)
    triples = sorted((ids[a], ids[b], ids[n], c) for (a, b, n), c in tri.items() if c >= MIN_TRIPLE and a in ids and b in ids and n in ids)
    # English words people mix in: real dictionary words and developer/chat words
    ok = {l.strip() for l in open(os.path.join(AUTOSWITCH, "en_spell_ok.txt"), encoding="utf-8")}
    extra = {w.lower() for l in open(os.path.join(AUTOSWITCH, "en_extra.txt"), encoding="utf-8") if not l.startswith("#") for w in l.split()}
    english = [(w, c) for w, c in freq("en_50k.txt") if w.isascii() and w.isalpha() and (w in ok or w in extra)][:MAX_ENGLISH]
    have = {w for w, _ in english}
    floor = english[-1][1] if english else 1
    english += [(w, floor) for w in sorted(extra) if w.isascii() and w.isalpha() and w not in have]
    with open(out, "wb") as f:
        f.write(b"HPKA" + struct.pack("<IIIIIQQQ", 3, len(vocab), len(pairs), len(triples), len(english), corpus_total, sum(prior[w] for w in vocab[1:]), sum(c for _, c in english)))
        for w in vocab:
            wb, bb = w.encode("utf-8"), ("" if w == "<s>" else base(w)).encode("ascii")
            c = starts if w == "<s>" else uni[w]
            p = starts if w == "<s>" else prior[w]
            f.write(struct.pack("<B", len(wb)) + wb + struct.pack("<B", len(bb)) + bb + struct.pack("<II", min(c, 2**32 - 1), min(p, 2**32 - 1)))
        for p, n, c in pairs:
            f.write(struct.pack("<HHI", p, n, c))
        for a, b, n, c in triples:
            f.write(struct.pack("<HHHI", a, b, n, c))
        for w, c in english:
            wb = w.encode("ascii")
            f.write(struct.pack("<B", len(wb)) + wb + struct.pack("<I", min(c, 2**32 - 1)))
    print(f"vocab {len(vocab)}, pairs {len(pairs)}, triples {len(triples)}, english {len(english)}, tokens {corpus_total}")

if __name__ == "__main__":
    main()

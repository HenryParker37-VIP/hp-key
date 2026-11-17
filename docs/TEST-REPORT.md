# HP Key (Vikey-based) test report, 2026-11-17

Machine: Apple Silicon, macOS 27.0. HP Key 1.0.0 built from Vikey commit 03c4939, signed Apple Development.
Typing tests used HP Key Lab (`lab/`): a local window with native fields and a WebKit page, driven by real key
codes through the system event stream, the same path as a physical keyboard. Only one keyboard app ran at a time.

## Engine regression (`scripts/test.sh`, inherited from Vikey): PASS

Rules 229/229, Simple Telex 14/14 + 14/14, reported bugs 21/21, golden snapshots unchanged (chat, typos,
synthetic, every Vietnamese syllable), undo after fix/switch/click ok, driver == simulator, realistic typing
0 broken words, performance avg ~350 ns/key, p99.9 ~4 µs. Identical to upstream Vikey on the same machine.

## Real typing in HP Key Lab, Tiếng Việt mode, ~11 characters/second

| Field | Original Vikey 1.0.34 (baseline) | HP Key 1.0.0 |
|---|---|---|
| Native text view (NSTextView) | PASS 8/8 | PASS 8/8 |
| Native single-line field | PASS 8/8 | PASS 8/8 |
| Native search field | PASS 8/8 | PASS 8/8 |
| WebKit `input` | PASS 8/8 | PASS 8/8 |
| WebKit `textarea` | PASS 8/8 | PASS 8/8 |
| WebKit `contenteditable` | PASS 8/8 | PASS 8/8 |
| Native password field | PASS (untouched) | PASS (untouched) |
| WebKit password field | PASS (untouched) | PASS (untouched) |
| **Total** | **50/50** | **50/50** |

Cases per field: `tieesng vieejt truowfng hoaf ddaay`, `tieengs vieetj` (tone after the final letter),
`review code` kept as English, `Tieengs Vieetj` with Shift, `xin chaof, banj.` punctuation, Backspace inside a
word, caret moved left into the middle of a sentence, and a 234-keystroke passage. Raw output: `build/lab-*.txt`.

## Stress, ~40 characters/second (about 4x a fast typist)

HP Key: one long passage in the native text view came out garbled once; the run then stopped when another
window took focus. The Vikey comparison at this speed could not run (another app held focus; the driver refuses
to type unless the Lab is in front). NOT CONCLUSIVE; human-speed results above are clean for both.

## Acceptance matrix

| Scenario | Result | Evidence / reason |
|---|---|---|
| Vietnamese Telex | PASS | Lab, all fields |
| English words kept | PASS | Lab, all fields |
| Smart mode (auto switch) | NOT TESTED live | Same engine switch as Vikey's auto switch; covered by the engine suite (metrics, golden) |
| WebKit input / textarea / contenteditable | PASS | Lab WebKit page (Safari's engine) |
| Chrome, Safari | PASS (owner) | Owner typed Vietnamese in Chrome and Safari after the install and confirmed it works (2026-11-17) |
| Firefox, Edge, Arc | NOT TESTED | Automation may not type into browsers |
| TextEdit / native fields | PASS | Lab native fields (same AppKit controls) |
| VS Code / Cursor / Terminal | NOT TESTED | Automation may not type into editors/terminals; owner check below |
| Menu mode buttons (English / Tiếng Việt / Smart) | NOT TESTED live | Menu hidden behind the menu-bar manager; code applies each mode to the running engine |
| Switch hotkey | NOT TESTED live | Imported from the owner's Vikey settings |
| App switching, caret moves | PASS (caret) | Lab mid-sentence case; engine suite covers clicks/switch trips |
| Restart HP Key | PASS | Relaunched several times; Accessibility kept (same signing requirement) |
| Sleep / wake | NOT TESTED | Vikey's stop-on-sleep / restart-on-wake code is unchanged |
| Secure input fields | PASS | Lab password fields untouched |
| Vikey running at the same time | Guarded | HP Key pauses its event tap while Vikey runs |

## Owner checks (2 minutes)

Quit Vikey first (HP Key pauses while it runs). In Chrome and Safari, type `tieesng vieejt ` into a search box
and a ChatGPT/Gmail message box: expect `tiếng việt `. In VS Code type the same in a comment. In the HP Key menu,
choose English, Tiếng Việt and Smart in turn and type `review tieesng `.

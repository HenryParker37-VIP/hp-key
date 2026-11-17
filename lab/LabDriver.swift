import AppKit
import CoreGraphics

// Drives HP Key Lab with real HID key codes (U.S. layout) and compares each field's value with the
// expected Telex result. Synthetic phrases only; results print as PASS/FAIL per field and case.
// Usage: lab-driver <backend-label> [key-interval-ms]   (the backend must be in Vietnamese mode)
let label = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "unknown"
let interval = UInt32(CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 12 : 12) * 1000
let codes: [Character: CGKeyCode] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,
    "y":16,"t":17,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46," ":49,",":43,".":47]
let source = CGEventSource(stateID: .privateState)

func post(_ code: CGKeyCode, flags: CGEventFlags = []) {
    // Safety: every key goes only to the disposable lab window; stop at once if anything else is in front.
    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.henryparker.hpkey.lab" else {
        print("ABORT: HP Key Lab lost the front; no further keys were sent."); exit(2)
    }
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)!
        event.flags = flags; event.post(tap: .cghidEventTap); usleep(interval)
    }
}
// Script: letters/space as typed, "\u{8}" Backspace, "<" Left arrow, "^" Control-Shift-Space, "\n" Return.
func type(_ script: String) {
    for ch in script {
        switch ch {
        case "\u{8}": post(51)
        case "<": post(123)
        case "^": post(49, flags: [.maskControl, .maskShift]); usleep(400_000)
        case "\n": post(36)
        default:
            // Capitals are typed with Shift, like a person would.
            if ch.isUppercase, let lower = ch.lowercased().first, let code = codes[lower] { post(code, flags: .maskShift) }
            else { post(codes[ch]!) }
        }
    }
}

var lastValue: String?
let center = DistributedNotificationCenter.default()
let observer = center.addObserver(forName: Notification.Name("com.henryparker.hpkey.lab.value"), object: nil, queue: nil) { note in
    lastValue = note.userInfo?["value"] as? String
}
func pump(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }
func read(_ id: String) -> String? {
    lastValue = nil
    center.postNotificationName(Notification.Name("com.henryparker.hpkey.lab.read"), object: id, userInfo: nil, deliverImmediately: true)
    for _ in 0..<40 where lastValue == nil { pump(0.05) }
    return lastValue
}
func focus(_ id: String) {
    center.postNotificationName(Notification.Name("com.henryparker.hpkey.lab.focus"), object: id, userInfo: nil, deliverImmediately: true)
    pump(0.8)
    // Safety: never post keys unless the disposable lab window is frontmost.
    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.henryparker.hpkey.lab" else {
        print("ABORT: HP Key Lab is not frontmost; no keys were sent."); exit(2)
    }
}

struct Case { let name: String; let script: String; let expected: String }
let fields = ["textview", "field", "search", "input", "textarea", "rich"]
let cases = [
    Case(name: "telex words", script: "tieesng vieejt truowfng hoaf ddaay ", expected: "tiếng việt trường hòa đây "),
    Case(name: "tone after final", script: "tieengs vieetj ", expected: "tiếng việt "),
    Case(name: "english word kept", script: "review code ", expected: "review code "),
    Case(name: "capitals", script: "Tieengs Vieetj ", expected: "Tiếng Việt "),
    Case(name: "punctuation", script: "xin chaof, banj. ", expected: "xin chào, bạn. "),
    Case(name: "backspace in word", script: "vieejt\u{8}t ", expected: "việt "),
    Case(name: "caret moved mid-sentence", script: "xin chaof ban <<<<cacs ", expected: "xin chào các ban "),
    Case(name: "long text", script: String(repeating: "chungs toi ddang vieets tieesng vieejt ", count: 6),
         expected: String(repeating: "chúng toi đang viết tiếng việt ", count: 6)),
]
var pass = 0, fail = 0
print("backend=\(label) interval=\(interval / 1000)ms")
for field in fields {
    for item in cases {
        focus(field); type(item.script); pump(0.5 + Double(item.script.count) * 0.01)
        let value = read(field)?.replacingOccurrences(of: "\u{00A0}", with: " ")
        let ok = value == item.expected
        if ok { pass += 1 } else { fail += 1 }
        print("\(ok ? "PASS" : "FAIL") \(field) · \(item.name)" + (ok ? "" : " · got \(value.map { "\"\($0)\"" } ?? "no reply")"))
    }
}
// Secure fields must never be converted: typing "aa " must leave 3 characters (converted would be 2).
for field in ["secure", "password"] {
    focus(field); pump(0.5); type("aa "); pump(0.5)
    let value = read(field)
    let ok = value == "length:3"
    if ok { pass += 1 } else { fail += 1 }
    print("\(ok ? "PASS" : "FAIL") \(field) · secure field untouched" + (ok ? "" : " · got \(value ?? "no reply")"))
}
print("TOTAL backend=\(label) pass=\(pass) fail=\(fail)")
center.removeObserver(observer)

import AppKit
import WebKit

// HP Key Lab: a disposable local window with representative text controls for live compatibility
// tests. Synthetic data only. Controlled by distributed notifications so a test driver can focus
// a field and read its value back. No network, storage or logging.
final class LabController: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 760), styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 700, height: 90))
    let field = NSTextField(frame: NSRect(x: 30, y: 570, width: 700, height: 26))
    let search = NSSearchField(frame: NSRect(x: 30, y: 530, width: 700, height: 26))
    let secure = NSSecureTextField(frame: NSRect(x: 30, y: 490, width: 700, height: 26))
    let web = WKWebView(frame: NSRect(x: 30, y: 20, width: 700, height: 450))
    static let page = """
    <!doctype html><meta charset=utf-8><style>body{font:16px system-ui;color-scheme:light dark}input,textarea,div[contenteditable]{width:95%;font:16px system-ui;margin:4px 0}textarea,div[contenteditable]{height:60px;border:1px solid #888}</style>
    <label>web input</label><input id=input autocomplete=off spellcheck=false>
    <label>web textarea</label><textarea id=textarea spellcheck=false></textarea>
    <label>web contenteditable</label><div id=rich contenteditable=true spellcheck=false></div>
    <label>web password</label><input id=password type=password autocomplete=new-password>
    """

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "HP Key Lab"
        let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
        let scroll = NSScrollView(frame: NSRect(x: 30, y: 620, width: 700, height: 110))
        scroll.documentView = textView; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        textView.isRichText = false; textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false; textView.isAutomaticQuoteSubstitutionEnabled = false
        for view in [scroll, field, search, secure, web] as [NSView] { content.addSubview(view) }
        web.loadHTMLString(Self.page, baseURL: nil)
        window.contentView = content; window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.henryparker.hpkey.lab.focus"), object: nil, queue: .main) { [weak self] note in
            self?.focus(note.object as? String ?? "")
        }
        center.addObserver(forName: Notification.Name("com.henryparker.hpkey.lab.read"), object: nil, queue: .main) { [weak self] note in
            self?.read(note.object as? String ?? "")
        }
    }
    private func focus(_ id: String) {
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        switch id {
        case "textview": textView.string = ""; window.makeFirstResponder(textView)
        case "field": field.stringValue = ""; window.makeFirstResponder(field)
        case "search": search.stringValue = ""; window.makeFirstResponder(search)
        case "secure": secure.stringValue = ""; window.makeFirstResponder(secure)
        default:
            window.makeFirstResponder(web)
            let js = "(()=>{const e=document.getElementById('\(id)'); if(!e) return; if('value' in e) e.value=''; else e.textContent=''; e.focus(); })()"
            web.evaluateJavaScript(js)
        }
    }
    // Replies with the field's current value so the driver can compare it with the expectation.
    // Password fields report only their length, never their contents.
    private func read(_ id: String) {
        func reply(_ value: String) {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name("com.henryparker.hpkey.lab.value"),
                object: nil, userInfo: ["id": id, "value": value], deliverImmediately: true)
        }
        switch id {
        case "textview": reply(textView.string)
        case "field": reply(field.currentEditor()?.string ?? field.stringValue)
        case "search": reply(search.currentEditor()?.string ?? search.stringValue)
        case "secure": reply("length:\((secure.currentEditor()?.string ?? secure.stringValue).count)")
        case "password":
            web.evaluateJavaScript("'length:'+document.getElementById('password').value.length") { value, _ in reply(value as? String ?? "") }
        default:
            web.evaluateJavaScript("(()=>{const e=document.getElementById('\(id)'); return e ? ('value' in e ? e.value : e.innerText) : ''})()") { value, _ in
                reply(value as? String ?? "")
            }
        }
    }
}

@main enum LabMain {
    static func main() {
        let app = NSApplication.shared
        let controller = LabController()
        app.delegate = controller
        app.setActivationPolicy(.regular)
        withExtendedLifetime(controller) { app.run() }
    }
}

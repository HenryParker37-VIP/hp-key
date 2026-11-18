// Copyright © 2026 Nguyen Manh Tuan Hung (Henry Parker). Licensed under GPL-3.0.
//
// HP Key: select Vietnamese written without accents in any app ("hien tai nguoi dung nay khong hoat
// dong") and a bubble above the selection shows it with accents. The selection is read through the
// Accessibility permission HP Key already has, only right after the user selects something; it is never
// stored, logged or sent anywhere, password fields are skipped, and the original text is not changed.
// The same works from the right-click menu (Services): "HP Key: Xem có dấu" shows the bubble and
// "HP Key: Thêm dấu" replaces the selection in a text field; macOS hands over only the selected text.

import AppKit
import ApplicationServices
import Carbon.HIToolbox   // IsSecureEventInputEnabled
import SwiftUI

@MainActor final class SelectionAccents: NSObject {
    static let shared = SelectionAccents()
    static let enabledKey = "HPKeyAccentsOnSelect"

    private var monitors: [Any] = []
    private var panel: NSPanel?
    private var shownFor = ""
    private var downAt = NSPoint.zero
    private var pending: DispatchWorkItem?
    private var accessibleSince: [pid_t: Date] = [:]

    func install() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
        guard monitors.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { _ = AccentRestorer.shared }   // load the model before the first selection
        let watch: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] _ in self?.downAt = NSEvent.mouseLocation; self?.hide() }),
            (.leftMouseUp, { [weak self] e in
                guard let self else { return }
                let p = NSEvent.mouseLocation
                if e.clickCount >= 2 || hypot(p.x - self.downAt.x, p.y - self.downAt.y) > 3 { self.check(near: p) }
            }),
            (.keyDown, { [weak self] _ in self?.hide() }),
            (.keyUp, { [weak self] e in
                // Shift+arrows extend a selection; ⌘A selects everything
                let arrows: Set<UInt16> = [123, 124, 125, 126]
                if (e.modifierFlags.contains(.shift) && arrows.contains(e.keyCode)) || (e.modifierFlags.contains(.command) && e.keyCode == 0) {
                    self?.check(near: NSEvent.mouseLocation)
                }
            }),
            (.scrollWheel, { [weak self] _ in self?.hide() }),
        ]
        for (mask, handler) in watch {
            if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { e in MainActor.assumeIsolated { handler(e) } }) { monitors.append(m) }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                self?.hide()
                if let app { self?.prepare(app) }   // web apps build their text tree for us in the background
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication { prepare(front) }
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    private func prepare(_ app: NSRunningApplication) {
        guard enabled, AXIsProcessTrusted(), app.processIdentifier != getpid() else { return }
        makeAccessible(app)
    }

    private var enabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// Reads the selection a moment after the click or key (the app updates it first).
    private func check(near point: NSPoint) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.show(near: point) } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func show(near point: NSPoint, retry: Bool = true) {
        guard enabled, AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid(),
              let restorer = AccentRestorer.shared else { return }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        makeAccessible(front)
        let focused = attribute(app, kAXFocusedUIElementAttribute) as AXUIElement?
        if let focused, (attribute(focused, kAXRoleAttribute) as String?) == "AXSecureTextField"
            || (attribute(focused, kAXSubroleAttribute) as String?) == "AXSecureTextField" { return }
        var selected = focused.flatMap { attribute($0, kAXSelectedTextAttribute) as String? }
        var top = focused.flatMap(selectionTop)
        if selected?.isEmpty ?? true, let web = webArea(app: app, focused: focused) {   // text selected on a web page
            (selected, top) = webSelection(web)
        }
        guard let selected, !selected.isEmpty else {
            // a web app that has just been asked for its text needs a moment to build it: look once more
            if retry, let since = accessibleSince[front.processIdentifier], Date().timeIntervalSince(since) < 5 {
                let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.show(near: point, retry: false) } }
                pending = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            }
            return
        }
        restorer.modernTone = UserDefaults.standard.integer(forKey: PrefKey.modernOrthography) != 0
        guard let accented = restorer.suggestion(for: selected) else { return }
        if accented == shownFor, panel?.isVisible == true { return }
        present(accented, above: top ?? point)
    }

    /// The web page holding the focus (WebKit and Chromium), found from the focused element or the window.
    private func webArea(app: AXUIElement, focused: AXUIElement?) -> AXUIElement? {
        var e = focused
        for _ in 0..<30 {   // the focused element, then its ancestors
            guard let cur = e else { break }
            if (attribute(cur, kAXRoleAttribute) as String?) == "AXWebArea" { return cur }
            e = attribute(cur, kAXParentAttribute) as AXUIElement?
        }
        guard let window = attribute(app, kAXFocusedWindowAttribute) as AXUIElement? else { return nil }
        var queue = [window], seen = 0
        while !queue.isEmpty, seen < 300 {   // breadth first: the page sits a few levels under the window
            let cur = queue.removeFirst(); seen += 1
            if (attribute(cur, kAXRoleAttribute) as String?) == "AXWebArea" { return cur }
            queue += (attribute(cur, kAXChildrenAttribute) as [AXUIElement]?) ?? []
        }
        return nil
    }

    /// The selected text of a web page and its top on screen, through WebKit's text markers.
    private func webSelection(_ web: AXUIElement) -> (String?, NSPoint?) {
        guard let range = attribute(web, "AXSelectedTextMarkerRange") as CFTypeRef? else {
            return (attribute(web, kAXSelectedTextAttribute) as String?, nil)
        }
        var text: CFTypeRef?, bounds: CFTypeRef?
        AXUIElementCopyParameterizedAttributeValue(web, "AXStringForTextMarkerRange" as CFString, range, &text)
        var top: NSPoint?
        if AXUIElementCopyParameterizedAttributeValue(web, "AXBoundsForTextMarkerRange" as CFString, range, &bounds) == .success,
           let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() {
            var rect = CGRect.zero
            if AXValueGetValue(bounds as! AXValue, .cgRect, &rect), rect.width > 0 {
                top = NSPoint(x: rect.midX, y: (NSScreen.screens.first?.frame.height ?? 0) - rect.minY)
            }
        }
        return (text as? String, top)
    }

    /// Chromium and Electron apps (Chrome, Helium, ChatGPT, Zalo, Claude, Slack…) only expose the text of
    /// their pages to Accessibility clients that ask for it. Electron apps answer AXManualAccessibility;
    /// Chromium browsers and apps built on Chromium answer AXEnhancedUserInterface (asked only of them:
    /// some native apps animate windows differently with it on).
    private func makeAccessible(_ running: NSRunningApplication) {
        let pid = running.processIdentifier
        guard accessibleSince[pid] == nil else { return }
        accessibleSince[pid] = Date()
        let app = AXUIElementCreateApplication(pid)
        if AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) != .success, isChromium(running) {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }

    /// Chromium-based apps ship "<Name> Framework.framework" (Google Chrome Framework, Helium Framework…).
    private func isChromium(_ app: NSRunningApplication) -> Bool {
        guard let dir = app.bundleURL?.appendingPathComponent("Contents/Frameworks").path,
              let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return false }
        return items.contains { $0.hasSuffix(" Framework.framework") }
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value else { return nil }
        return value as? T
    }

    /// The top middle of the selection on screen (Cocoa coordinates), when the app can tell.
    private func selectionTop(_ element: AXUIElement) -> NSPoint? {
        var range: CFTypeRef?, bounds: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success, let range,
              AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &bounds) == .success,
              let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect), rect.width > 0 || rect.height > 0 else { return nil }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSPoint(x: rect.midX, y: primaryHeight - rect.minY)   // AX counts from the top of the main screen
    }

    // MARK: right-click menu (Services)

    /// "HP Key: Xem có dấu": the bubble for the text selected in any app, chosen from its right-click menu.
    @objc nonisolated func showAccents(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let text = pboard.string(forType: .string)
        MainActor.assumeIsolated {
            guard let text, let accented = Self.accented(text) else { error.pointee = "HP Key không đọc được đoạn chữ này." ; return }
            let same = accented == text.trimmingCharacters(in: .whitespacesAndNewlines)
            present(same ? "Đoạn này không cần thêm dấu." : accented, above: NSEvent.mouseLocation, copyable: !same)
        }
    }

    /// "HP Key: Thêm dấu": replaces the selection in a text field with the accented text.
    @objc nonisolated func addAccents(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else { return }
        let result = MainActor.assumeIsolated { () -> String? in
            guard let accented = Self.accented(text) else { return nil }
            // keep the spaces and line breaks around the selection as they were
            let lead = text.prefix { $0.isWhitespace || $0.isNewline }, trail = String(text.reversed().prefix { $0.isWhitespace || $0.isNewline }.reversed())
            return lead + accented + trail
        }
        guard let result else { error.pointee = "HP Key không đọc được đoạn chữ này."; return }
        pboard.clearContents()
        pboard.setString(result, forType: .string)
    }

    /// The text with accents, for a selection the user chose to send (up to a few pages).
    private static func accented(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20_000, let restorer = AccentRestorer.shared else { return nil }
        restorer.modernTone = UserDefaults.standard.integer(forKey: PrefKey.modernOrthography) != 0
        return restorer.restore(trimmed)
    }

    private func present(_ text: String, above anchor: NSPoint, copyable: Bool = true) {
        shownFor = text
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: AccentBubble(text: text, copyable: copyable) { [weak self] in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.hide()
        })
        let size = host.fittingSize
        panel.contentView = host
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y + 8)
        if origin.y + size.height > visible.maxY { origin.y = anchor.y - size.height - 36 }   // no room above: below the line
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        return p
    }

    func hide() {
        pending?.cancel()
        panel?.orderOut(nil)
        shownFor = ""
    }
}

/// The bubble: the text with accents and a copy button.
private struct AccentBubble: View {
    let text: String
    let copyable: Bool
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text)
                .font(.system(size: 14))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420, alignment: .leading)
            if copyable {
                Button(action: copy) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Sao chép")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .padding(6)   // room for the shadow
        .fixedSize()
    }
}

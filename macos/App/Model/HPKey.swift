import AppKit

// Copyright © 2026 Nguyen Manh Tuan Hung (Henry Parker). Licensed under GPL-3.0.
//
// HP Key additions on top of Vikey (GPL-3.0). Kept in one file so the Vikey-derived code stays easy
// to compare with upstream.

/// The three typing modes HP Key shows. They map onto Vikey's real engine switches:
/// English = Vietnamese off, auto switch off; Vietnamese = Vietnamese on, auto switch off;
/// Smart = Vikey's auto switch on (it switches English/Vietnamese word by word).
enum TypingMode: String, CaseIterable {
    case english, vietnamese, smart

    var title: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .smart: return "Smart (tự chuyển Anh/Việt)"
        }
    }

    static var current: TypingMode {
        if UserDefaults.standard.integer(forKey: PrefKey.autoSwitch) == 1 { return .smart }
        return VikeyCore.language() == 1 ? .vietnamese : .english
    }

    /// Applies the mode to the running engine (not only to the UI).
    @MainActor func apply() {
        UserDefaults.standard.set(self == .smart ? 1 : 0, forKey: PrefKey.autoSwitch)
        Preferences.apply()
        switch self {
        case .english: AppState.shared.setLanguage(0)
        case .vietnamese: AppState.shared.setLanguage(1)
        case .smart: AppState.shared.setLanguage(Int(VikeyCore.language()))
        }
        AppState.shared.frontAppChanged()
    }
}

/// Two keyboard processors must never handle the same keystroke: while the original Vikey (or another
/// Vietnamese keyboard utility) runs, HP Key stops its event tap and says so; it starts again when that app quits.
@MainActor
enum ConflictGuard {
    static let bundleIDs = ["com.devuap.vikey", "com.tuyenmai.openkey", "com.lamquangminh.EVKey", "com.trankynam.GoTiengViet"]

    static var runningConflict: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let id = app.bundleIdentifier else { return false }
            return bundleIDs.contains(where: { id.caseInsensitiveCompare($0) == .orderedSame })
        }
    }

    static func install() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppState.shared.conflictChanged() }
            }
        }
    }
}

/// One-time import so HP Key types the way the user's Vikey does, and keeps HP Key's own app exclusions.
enum HPKeyMigration {
    private static let doneKey = "HPKeyMigratedToVikeyEngine"
    private static let skipped: Set<String> = ["CrashReportsAuto", "CrashReportsSeenUntil", "crashEndpoint", "TypingLogEnabled"]

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        let vikey = defaults.persistentDomain(forName: "com.devuap.vikey")
        // Vikey's settings, per-app/per-site language memory, macros and hotkey (never its typing log).
        if let vikey {
            for (key, value) in vikey where !skipped.contains(key) && !key.hasPrefix("NS") && !key.hasPrefix("SU") {
                defaults.set(value, forKey: key)
            }
            // Vikey already handled OpenKey for this user: don't import OpenKey over it.
            defaults.set(true, forKey: "MigratedFromOpenKey")
        }
        // HP Key's previous settings file: its excluded apps, and its mode if Vikey had nothing to bring.
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/HP Key/settings.json")
        guard let data = try? Data(contentsOf: url),
              let old = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // Only exclusions the user added: the old HP Key's built-in defaults (terminals, VS Code, remote tools)
        // would keep HP Key out of apps where the Vikey engine works (it is programming-aware).
        let oldDefaults: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.microsoft.VSCode",
                                        "com.microsoft.rdc.macos", "com.apple.ScreenSharing", "com.anydesk.AnyDesk", "com.teamviewer.TeamViewer"]
        if let excluded = old["excludedBundleIDs"] as? [String] {
            let added = excluded.filter { !oldDefaults.contains($0) }
            if !added.isEmpty {
            let current = defaults.stringArray(forKey: PrefKey.excludedApps) ?? ExcludedApps.defaults
            defaults.set(current + added.filter { !current.contains($0) }, forKey: PrefKey.excludedApps)
            }
        }
        if vikey == nil {
            if let mode = old["mode"] as? String {
                defaults.set(mode == "smart" ? 1 : 0, forKey: PrefKey.autoSwitch)
                defaults.set(mode == "english" ? 0 : 1, forKey: "InputMethod")
            }
            if let tone = old["toneStyle"] as? String { defaults.set(tone == "legacy" ? 0 : 1, forKey: PrefKey.modernOrthography) }
        }
    }
}

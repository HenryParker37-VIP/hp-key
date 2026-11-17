import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var state: AppState
    @AppStorage(PrefKey.autoSwitch) private var autoSwitch = 1
    @AppStorage(PrefKey.hotkey) private var hotkeyRaw = Hotkey.defaultValue

    var body: some View {
        if state.needsOnboarding {
            Button("Cấp quyền cho HP Key…") { OnboardingWindow.show() }
            Divider()
        }
        if let other = state.conflictApp {
            Text("Tạm dừng: \(other) đang chạy. Thoát \(other) để dùng HP Key.").foregroundStyle(.secondary)
            Divider()
        }
        // HP Key's three modes, each applied to the running engine (TypingMode in HPKey.swift).
        if state.modeTick >= 0 {
            let current = TypingMode.current
            ForEach(TypingMode.allCases, id: \.self) { mode in
                Button((current == mode ? "✓ " : "    ") + mode.title) { mode.apply() }
            }
        }
        Text("Chuyển Anh/Việt: \(Hotkey(raw: hotkeyRaw).display)").foregroundStyle(.secondary)
        // Per app: remembered for the app in front (the tick makes SwiftUI re-read it after an app change).
        if state.frontAppTick >= 0 {
            let app = VikeyCore.frontAppName()
            if VikeyCore.frontAppIsExcluded() {
                Text("\(app): đã loại trừ").foregroundStyle(.secondary)
            } else {
                Toggle("Tự chuyển ở \(app)", isOn: Binding(
                    get: { VikeyCore.autoSwitchEnabledForFrontApp() },
                    set: {
                        VikeyCore.setAutoSwitchForFrontApp($0)
                        state.frontAppChanged()
                    }))
            }
        }
        Divider()
        Button("Mở HP Key…") { Windows.main.show() }
            .keyboardShortcut(",")
        Divider()
        Button("Hướng dẫn…") { OnboardingWindow.show() }
        Button("Giới thiệu HP Key") { AboutPanel.show() }
        Button("Thoát HP Key") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Debug items, in the HP Key app menu only (not the menu bar icon).
struct DebugMenu: View {
    @AppStorage(PrefKey.typingLogEnabled) private var logEnabled = 0

    var body: some View {
        Menu("Gỡ lỗi") {
            Toggle("Ghi nhật ký gõ", isOn: Binding(get: { logEnabled == 1 }, set: { logEnabled = $0 ? 1 : 0; Preferences.apply() }))
            Button("Xem nhật ký gõ…") { Windows.history.show() }
                .disabled(logEnabled == 0)
        }
    }
}


# HP Key: origin, license and modifications

HP Key is made by **Nguyen Manh Tuan Hung (Henry Parker)**. Copyright © 2026 Nguyen Manh Tuan Hung (Henry Parker) for the HP Key modifications.

HP Key for macOS is a modified version of **Vikey** by Tony Dinh (Đinh Quang Trung),
https://github.com/tonyminibot/Vikey, imported from commit `03c49391977ffe15965bc4cf92efa9a24f9d638e`
(2026-11-17, Vikey 1.0.34). Vikey is based on **OpenKey** by Tuyen Mai (https://github.com/tuyenvm/OpenKey).
Both are licensed under the GNU General Public License v3.0, so HP Key is also GPL-3.0 (see `LICENSE`).
Copyright notices in the imported files are kept unchanged. Data and code credits: `macos/ACKNOWLEDGEMENTS.md`.

If HP Key is ever given to anyone else (binary or source), it must be distributed under GPL-3.0 with its
complete corresponding source, including the modifications listed below.

## Imported unchanged

- `macos/Engine/` (Telex engine, auto switch, word data)
- `macos/App/Core/` (event tap keyboard core) except the one line noted below
- `macos/Tools/autoswitch/` (engine regression suite) except the macOS-only scoping noted below
- `macos/DECISIONS.md`, `macos/ACKNOWLEDGEMENTS.md`

## HP Key modifications (2026-11-17)

- Identity: app name "HP Key", bundle id `com.henryparker.hpkey`, HP Key icon, version 1.0.0, signed with the
  owner's local Apple Development identity (`macos/project.yml`, `macos/App/Info.plist`, app icon assets).
- Removed network features: the Sparkle auto-updater (it would install Vikey over HP Key), crash-report
  upload to vikey.app and the feedback link (`Updater.swift`, `CrashReporter.swift` deleted; references removed
  from `AppDelegate.swift`, `VikeyApp.swift`, `MenuBarContent.swift`, `MainView.swift`).
- User-visible text says "HP Key" instead of "Vikey"; the About panel and Info.plist copyright name the
  author, Nguyen Manh Tuan Hung (Henry Parker), and credit Vikey and OpenKey.
- `VikeyCore.mm`: the support folder is `~/Library/Application Support/HP Key` (one line).
- New `App/Model/HPKey.swift`: English / Tiếng Việt / Smart modes mapped onto the engine's language and
  auto-switch settings; a guard that pauses HP Key while Vikey, OpenKey, EVKey or GoTiengViet runs; a one-time
  import of the user's Vikey settings and of exclusions the user added in the previous HP Key.
- `AppState.swift`, `AppDelegate.swift`, `MenuBarContent.swift`: wiring for the above.
- `Tools/autoswitch/check.sh`: the DECISIONS audit ignores tests that live in Vikey's iOS/Windows/Linux/Android
  folders, which HP Key does not include; missing macOS/engine tests still fail.

## HP Key for Windows (2026-11-17)

`windows/` is Vikey's `Windows/` folder from the same commit, with these changes:

- Identity: product name "HP Key", `HPKey.exe`, HP Key icon, author and copyright in the version resource,
  manifest and installer (`windows/installer/HPKey.iss`, new installer id); settings in `HKCU\Software\HP Key`,
  data in `%LOCALAPPDATA%\HP Key`; window classes and the single-instance mutex renamed so HP Key and Vikey
  never mistake each other.
- Removed network features: the auto-updater (`Updater.cpp`, TweetNaCl), crash-report upload
  (`CrashReporter.cpp`) and the feedback links; the "Tự động cập nhật" and "Góp ý" rows are gone.
- HP Key does not start while Vikey for Windows is running (it would handle every key twice).
- User-visible text says "HP Key"; the About window names the author and credits Vikey and OpenKey; the
  settings window ends with "Made by Nguyen Manh Tuan Hung (Henry Parker)".
- Paths point at the shared engine under `macos/` (`windows/CMakeLists.txt`, `App/CMakeLists.txt`,
  `HPKey.rc`, `main.cpp`, `check.ps1`); Vikey's VM-only test scripts were dropped.
- `check.ps1`: the driver/simulator comparison passes `--as-typed`, as the macOS `driver/cmp.sh` does
  (without it the comparison fails since Vikey's D62 Enter change).
- `.github/workflows/windows.yml`: Vikey's workflow without code signing, packaging on published releases.

- `scripts/build.sh` builds a universal (Apple silicon + Intel) app; `scripts/make-dmg.sh` packages it as a DMG.

An earlier, unrelated HP Key prototype (Rust engine, InputMethodKit) is not part of this repository.

# HP Key

Bộ gõ tiếng Việt cho macOS và Windows. Gõ Telex trên bàn phím ABC/U.S. quen thuộc, HP Key tự bỏ dấu
và tự nhận ra khi bạn gõ tiếng Anh.

Made by **Nguyen Manh Tuan Hung (Henry Parker)**. Based on **[Vikey](https://github.com/tonyminibot/Vikey)**
by Tony Dinh and **[OpenKey](https://github.com/tuyenvm/OpenKey)** by Tuyen Mai. Open source under GPL-3.0
(see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md)).

## Tải về

Vào [Releases](https://github.com/HenryParker37-VIP/hp-key/releases/latest):

| Máy | File |
|---|---|
| Mac (Apple silicon và Intel, macOS 13 trở lên) | `HPKey-<version>.dmg` |
| Windows 10/11, máy Intel/AMD | `HPKey-<version>-x64-Setup.exe` (hoặc bản `-portable.zip` không cần cài) |
| Windows 11 trên ARM | `HPKey-<version>-arm64-Setup.exe` |

### Cài trên Mac

1. Mở file `.dmg`, kéo **HP Key** vào **Applications**.
2. Mở HP Key. Bản này chưa được Apple notarize, nên lần đầu macOS sẽ chặn: vào **System Settings ›
   Privacy & Security**, kéo xuống và bấm **Open Anyway**.
3. Cấp quyền **Accessibility** khi HP Key hỏi (cần để bỏ dấu trong mọi ứng dụng).

### Cài trên Windows

Chạy file `Setup.exe` (không cần quyền quản trị). File chưa được ký số, nên Windows SmartScreen có thể báo
"Windows protected your PC": bấm **More info › Run anyway**. HP Key nằm ở khay hệ thống; bấm **Alt+Z** để
chuyển Anh/Việt.

## Cách dùng

- Ba chế độ: **English**, **Tiếng Việt**, **Smart** (tự chuyển Anh/Việt theo từng từ).
- Phím tắt chuyển Anh/Việt: mặc định **Ctrl+Z** trên Mac và **Alt+Z** trên Windows, đổi được trong cài đặt.
- Nhớ Anh/Việt theo từng ứng dụng và từng trang web.
- HP Key tự tạm dừng khi Vikey đang chạy, để hai bộ gõ không cùng xử lý một phím. Hãy thoát các bộ gõ
  tiếng Việt khác (OpenKey, EVKey, UniKey, GoTiengViet) khi dùng HP Key.

## Quyền riêng tư

HP Key không gửi gì lên mạng: không tự cập nhật, không gửi báo lỗi, không lưu những gì bạn gõ. Nhật ký gõ
(chỉ để gỡ lỗi) mặc định tắt. Ô mật khẩu được bỏ qua.

## Build từ mã nguồn

**macOS** (cần Xcode và [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```sh
brew install xcodegen
./scripts/test.sh              # engine regression suite (from Vikey)
./scripts/build.sh             # universal app, signed with the Apple Development identity in .signing-identity
./scripts/make-dmg.sh          # build/HPKey-<version>.dmg
./scripts/install-app.sh       # installs to ~/Applications, backs up the previous copy first
./scripts/rollback-app.sh      # restores the backup
```

To build with your own Apple account, change `DEVELOPMENT_TEAM` in `macos/project.yml` and put your signing
certificate's SHA-1 in `.signing-identity` (or `HPKEY_SIGN_IDENTITY`).

**Windows** (Visual Studio 2022 with C++, CMake, Ninja, Python 3; run in a Developer PowerShell):

```powershell
pwsh windows/check.ps1                                   # engine checks
cmake -S windows -B windows/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build windows/build --target vikey               # windows/build/App/HPKey.exe
```

GitHub Actions (`.github/workflows/windows.yml`) builds x64 and ARM64 on every push and attaches the installers
to each published release.

## Thư mục

- `macos/`: Mac app (`App/`), shared typing engine (`Engine/`), engine tests (`Tools/autoswitch/`)
- `windows/`: Windows app (`App/`), installer (`installer/`), engine check script
- `lab/`: HP Key Lab, a local test window used to type into native and web fields
- `scripts/`: build, package, install and rollback scripts for macOS
- `docs/TEST-REPORT.md`: what was tested, how, and what is still untested

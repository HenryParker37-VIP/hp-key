; HP Key for Windows installer (Inno Setup 6). Per-user, no admin prompt.
; Based on Vikey's installer (GPL-3.0).
;   iscc /DVersion=1.0.0 /DArch=x64 /DSrc=..\build\App HPKey.iss
#ifndef Version
  #define Version "0.0.0"
#endif
#ifndef Arch
  #define Arch "x64"
#endif
#ifndef Src
  #define Src "..\build\App"
#endif

[Setup]
AppId={{6F74E1E9-2E9E-4738-B97D-F61889E60065}
AppName=HP Key
AppVersion={#Version}
AppVerName=HP Key {#Version}
AppPublisher=Nguyen Manh Tuan Hung (Henry Parker)
AppPublisherURL=https://github.com/HenryParker37-VIP/hp-key
AppSupportURL=https://github.com/HenryParker37-VIP/hp-key/issues
AppUpdatesURL=https://github.com/HenryParker37-VIP/hp-key/releases
AppCopyright=Copyright 2026 Nguyen Manh Tuan Hung (Henry Parker). GPL-3.0.
VersionInfoVersion={#Version}
DefaultDirName={localappdata}\Programs\HP Key
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=.\out
OutputBaseFilename=HPKey-{#Version}-{#Arch}-Setup
SetupIconFile=..\App\HPKey.ico
UninstallDisplayIcon={app}\HPKey.exe
UninstallDisplayName=HP Key
LicenseFile=..\..\LICENSE
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=HPKey.exe
RestartApplications=no
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Messages]
; the few screens people see, in Vietnamese like the app
WelcomeLabel1=Cài đặt HP Key
WelcomeLabel2=HP Key {#Version} sẽ được cài cho tài khoản của bạn, không cần quyền quản trị.%n%nMade by Nguyen Manh Tuan Hung (Henry Parker).%n%nBấm Next để tiếp tục.
FinishedHeadingLabel=Đã cài xong HP Key
FinishedLabel=HP Key nằm ở khay hệ thống (góc dưới bên phải). Bấm Alt+Z để chuyển Anh/Việt.
ConfirmUninstall=Gỡ HP Key khỏi máy?

[Files]
Source: "{#Src}\HPKey.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\HP Key"; Filename: "{app}\HPKey.exe"

[Registry]
; the app's own "Mở HP Key khi đăng nhập" entry goes away with the app
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "HP Key"; Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\HPKey.exe"; Description: "Mở HP Key"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/IM HPKey.exe /F"; Flags: runhidden; RunOnceId: "KillHPKey"

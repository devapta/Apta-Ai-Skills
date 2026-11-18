; Inno Setup 6 script for the Windows installer.
; Copy to the project root as installer.iss and replace every <placeholder>.
; build.ps1 rewrites the "#define MyAppVersion" line from pubspec.yaml; do not edit that value by hand.

#define MyAppName "<App Name>"
#define MyAppVersion "0.0.0"
#define MyAppPublisher "<Publisher>"
#define MyAppURL "<https://example.com/>"
; The exe Flutter produces is named after BINARY_NAME in windows/CMakeLists.txt (the project name by default).
#define MyAppExeName "<binary_name>.exe"
; Output file name prefix, e.g. "my-app" produces my-app-v1.2.3.exe. Keep it equal to $AppSlug in build.ps1.
#define MyAppSlug "<app-slug>"

[Setup]
; AppId identifies this app across upgrades. Generate a new one per app and never change it afterwards:
;   [guid]::NewGuid().ToString().ToUpper()      (PowerShell)
; Keep the double opening brace: Inno Setup treats "{{" as a literal "{".
AppId={{<NEW-GUID>}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=build\installer_output
OutputBaseFilename={#MyAppSlug}-v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Optional: ship .env next to the exe. The app already bundles it as a Flutter asset, so delete this line if nothing reads it there.
Source: ".env"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove per-user data on uninstall. Flutter plugins (shared_preferences, path_provider) store data under
; %APPDATA%\<CompanyName>\<ProductName>, taken from windows\runner\Runner.rc (the default company is "com.example").
; Add one pair of lines per folder your app really creates, and confirm the names on a test install.
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
; Type: filesandordirs; Name: "{userappdata}\<CompanyName>\<ProductName>"
; Type: filesandordirs; Name: "{localappdata}\<CompanyName>\<ProductName>"

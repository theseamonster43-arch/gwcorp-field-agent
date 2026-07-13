#define MyAppName "GWCORP Field Agent"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "GWCORP"
#define MyAppExeName "gwcorp_field_agent.exe"
#define BuildDir "..\build\windows\x64\runner\Release"
#define AppURL "https://ihs-gwcorp.web.app"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\GWCORP Field Agent
DefaultGroupName={#MyAppName}
OutputDir=output
OutputBaseFilename=GWCORP_FieldAgent_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Branding
WizardStyle=classic
WizardImageFile=wizard_sidebar.bmp
WizardSmallImageFile=wizard_small.bmp
WizardSizePercent=110

; Compression
Compression=lzma2/ultra64
SolidCompression=yes

; Behaviour
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
ShowLanguageDialog=no
DisableWelcomePage=no
DisableDirPage=no
DisableReadyPage=no
AlwaysShowDirOnReadyPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll";           DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "{#BuildDir}\data\*";          DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";           Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";     Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

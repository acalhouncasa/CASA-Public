#define MyAppName "Local Coder"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "CASA-Trinity"
#define SourceRoot ".."

[Setup]
AppId={{8E3C2A11-6B4F-4D9A-9C1E-7B2A91F04C18}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/acalhouncasa/CASA-Public
DefaultDirName={localappdata}\Programs\LocalCoder
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
OutputDir=..\dist
OutputBaseFilename=LocalCoder-{#MyAppVersion}-Setup
UninstallDisplayName={#MyAppName}
; Unsigned builds WILL show SmartScreen. Sign with Sign-LocalCoder.ps1 / signtool.
; This installer copies readable scripts. It does not embed Ollama or VSCodium EXEs.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceRoot}\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\THIRD_PARTY.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\INSTALL.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\HIPAA.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\HOW_IT_WORKS.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\IT.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\WELCOME.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\setup.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\setup-datasci.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\run.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\seed_cline.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\.clinerules"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\Launch-LocalCoder.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\harden-firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\Sign-LocalCoder.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\Uninstall-LocalCoder.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\Install.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\Start Local Coder.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\templates\*"; DestDir: "{app}\templates"; Flags: ignoreversion
Source: "{#SourceRoot}\payload\README.txt"; DestDir: "{app}\payload"; Flags: ignoreversion
Source: "{#SourceRoot}\data\README.txt"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "{#SourceRoot}\branding\*"; DestDir: "{app}\branding"; Flags: ignoreversion

[Icons]
Name: "{group}\Install or repair Local Coder"; Filename: "{app}\Install.cmd"
Name: "{group}\Local Coder"; Filename: "{app}\Start Local Coder.cmd"
Name: "{group}\Install instructions"; Filename: "{app}\INSTALL.md"
Name: "{group}\HIPAA limits"; Filename: "{app}\HIPAA.md"
Name: "{group}\IT notes"; Filename: "{app}\IT.md"

[Run]
Filename: "{app}\Install.cmd"; Description: "Install VSCodium, Ollama, and Cline from official sources"; Flags: postinstall nowait

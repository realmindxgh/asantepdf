#define MyAppName "AsantePDF"
#define MyAppVersion "1.0.0"
#ifndef MyAppDisplayVersion
  #define MyAppDisplayVersion "1.0.0-rc10"
#endif
#define MyAppPublisher "RealMindX Education Ltd"
#define MyAppExeName "AsantePDF.exe"
#ifndef SourceDir
  #define SourceDir "..\dist\app"
#endif

[Setup]
AppId={{B6CFF511-70ED-4D05-A54F-5D11E9D8B4D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppDisplayVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://realmindxgh.com
AppSupportURL=https://realmindxgh.com
DefaultDirName={autopf}\AsantePDF
DefaultGroupName=AsantePDF
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\dist\installer
OutputBaseFilename=AsantePDF Setup
SetupIconFile=..\assets\asantepdf.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
DisableWelcomePage=no
CloseApplications=yes
RestartApplications=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Local-first PDF workspace for Windows
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "openwith"; Description: "Add AsantePDF to the Windows Open with menu for PDF files"; GroupDescription: "PDF integration:"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\prereqs\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\AsantePDF"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\AsantePDF"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "AsantePDF"; Tasks: openwith; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""; Tasks: openwith
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: openwith

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing required Microsoft runtime..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AsantePDF"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard;
begin
  WizardForm.Color := $00F7F7F7;
  WizardForm.WelcomeLabel1.Caption := 'Install AsantePDF';
  WizardForm.WelcomeLabel2.Caption :=
    'A local-first PDF workspace for organising, converting, OCR, editing, signing, inspecting, repairing and processing PDF files.' + #13#10 + #13#10 +
    'Setup includes the local PDF, OCR and Office conversion engines required by AsantePDF.' + #13#10 +
    'Your documents stay on this computer during normal AsantePDF operations.';
end;

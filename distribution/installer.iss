; =====================================================================
;  Inno Setup - BDJ Studio Sample Pad
;  Instalador oficial para Windows
;  Salida: BDJ-Studio-Sample-Pad-Setup-1.0.3.exe en distribution/
; =====================================================================

#define MyAppName "BDJ Studio Sample Pad"
#define MyAppVersion "1.0.3"
#define MyAppPublisher "BDJ Studio"
#define MyAppPublisherURL "https://www.bdjstudio.com"
#define MyAppSupportURL "https://www.bdjstudio.com/soporte"
#define MyAppExeName "sample_pad_pro.exe"
#define MyAppIcon "..\frontend\windows\runner\resources\app_icon.ico"
#define MySourceDir "..\frontend\build\windows\x64\runner\Release"
#define MyOutputDir "."

[Setup]
AppId={{7F3A9C2E-5B4D-4E1A-9F8C-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppSupportURL}
AppComments=Licencia oficial de {#MyAppName}
AppCopyright=Copyright (C) 2026 BDJ Studio. Todos los derechos reservados.
DefaultDirName={autopf}\BDJ Studio\Sample Pad
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=BDJ-Studio-Sample-Pad-Setup-{#MyAppVersion}
SetupIconFile={#MyAppIcon}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardResizable=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
VersionInfoDescription={#MyAppName}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}.0
VersionInfoVersion={#MyAppVersion}.0
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\sample_pad_pro"
Type: filesandordirs; Name: "{localappdata}\sample_pad_pro"
Type: filesandordirs; Name: "{userappdata}\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{localappdata}\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\sample_pad_pro"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio\sample_pad_pro"
Type: filesandordirs; Name: "{userappdata}\com.example\sample_pad_pro"
Type: filesandordirs; Name: "{localappdata}\com.example\sample_pad_pro"
Type: filesandordirs; Name: "{userdocs}\SamplePadPro_Audios"
Type: filesandordirs; Name: "{app}"

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    DataDir := ExpandConstant('{userappdata}') + '\BDJ Studio Sample Pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\BDJ Studio Sample Pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\bdj_studio_sample_pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\bdj_studio_sample_pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\BDJ Studio\bdj_studio_sample_pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\BDJ Studio\BDJ Studio Sample Pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\BDJ Studio\bdj_studio_sample_pad';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\BDJ Studio\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\BDJ Studio\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userappdata}') + '\com.example\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{localappdata}') + '\com.example\sample_pad_pro';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);

    DataDir := ExpandConstant('{userdocs}') + '\SamplePadPro_Audios';
    if DirExists(DataDir) then DelTree(DataDir, True, True, True);
  end;
end;
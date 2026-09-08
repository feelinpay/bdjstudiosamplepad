; BDJ Studio Sample Pad - Instalador Windows (Inno Setup 6)
; Estructura basada en bdj_studio_license_setup.iss

#define MyAppName "BDJ Studio Sample Pad"
; La version puede inyectarse desde fuera para que no se desincronice de
; pubspec.yaml:  ISCC /DMyAppVersion=1.0.4 installer.iss
; El valor de abajo es solo el respaldo cuando se compila a mano.
#ifndef MyAppVersion
  #define MyAppVersion "1.0.3"
#endif
#define MyAppPublisher "BDJ Studio"
#define MyAppExeName "sample_pad_pro.exe"

[Setup]
AppId={{A47B9E12-53D8-4C6F-9AB1-72E4F80C5D39}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Iconos y logos de la aplicacion
SetupIconFile=..\frontend\windows\runner\resources\app_icon.ico
WizardImageFile=setup_assets\wizard_logo.bmp
WizardSmallImageFile=setup_assets\wizard_small.bmp
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
PrivilegesRequired=admin
OutputDir=.
OutputBaseFilename=BDJ_Studio_Sample_Pad_Setup_{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; Política del producto (compartida con las demás apps BDJ Studio): los datos
; NO sobreviven a la desinstalación. Se borra la carpeta de soporte de la app
; --%APPDATA%\CompanyName\ProductName, la misma que devuelve
; getApplicationSupportDirectory() (Runner.rc)-- incluidos Database, ajustes,
; shared_preferences.json y el almacén cifrado (flutter_secure_storage.dat), y
; los nombres que usaban versiones antiguas.
[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{userappdata}\bdj_studio_sample_pad"

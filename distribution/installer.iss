[Setup]
AppName=BDJ Studio Sample Pad
AppVersion=1.0
DefaultDirName={autopf}\BDJ Studio Sample Pad
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=C:\Users\David Zapata\Desktop\Aplicacion_para_DJs\BDJ_Studio_Sample_Pad\distribution
OutputBaseFilename=BDJ_Studio_Sample_Pad-Windows-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "C:\Users\David Zapata\Desktop\Aplicacion_para_DJs\BDJ_Studio_Sample_Pad\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\BDJ Studio Sample Pad"; Filename: "{app}\sample_pad_pro.exe"
Name: "{autodesktop}\BDJ Studio Sample Pad"; Filename: "{app}\sample_pad_pro.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Iconos adicionales:"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio\sample_pad_pro"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio\sample_pad_pro"
Type: filesandordirs; Name: "{userappdata}\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{localappdata}\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{userappdata}\com.bdjstudio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{localappdata}\com.bdjstudio\BDJ Studio Sample Pad"
Type: filesandordirs; Name: "{userappdata}\com.bdjstudio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{localappdata}\com.bdjstudio\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\com.bdjstudio\frontend"
Type: filesandordirs; Name: "{localappdata}\com.bdjstudio\frontend"
Type: filesandordirs; Name: "{userappdata}\com.example\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{localappdata}\com.example\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userappdata}\sample_pad_pro"
Type: filesandordirs; Name: "{localappdata}\sample_pad_pro"
Type: filesandordirs; Name: "{userappdata}\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{localappdata}\bdj_studio_sample_pad"
Type: filesandordirs; Name: "{userdocs}\SamplePadPro_Audios"
Type: filesandordirs; Name: "{app}"

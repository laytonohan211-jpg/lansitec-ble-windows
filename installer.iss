[Setup]
AppId={{C7181B89-FBC1-418F-A05F-53D5BB6BE457}
AppName=Ls BLE Guided
AppVersion=1.3.3
DefaultDirName={localappdata}\Programs\Ls BLE Guided
DefaultGroupName=Ls BLE Guided
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=dist
OutputBaseFilename=Ls_BLE_Guided_Windows_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\Ls_BLE_Guided.exe

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ls BLE Guided"; Filename: "{app}\Ls_BLE_Guided.exe"
Name: "{userdesktop}\Ls BLE Guided"; Filename: "{app}\Ls_BLE_Guided.exe"

[Run]
Filename: "{app}\Ls_BLE_Guided.exe"; Description: "Avvia Ls BLE Guided"; Flags: nowait postinstall skipifsilent

; Instalador do Bruma para Windows (Inno Setup 6). Gerado pelo GitHub Actions a cada versão (.github/workflows/bruma-android.yml).
; Para gerar na mão: iscc /DVersao=0.9.2 /DOrigem=C:\caminho\da\pasta\com\o\Bruma.exe bruma.iss
; O save e as configurações ficam em %APPDATA%\Pescador, fora da pasta do jogo: instalar por cima ou desinstalar não apaga nada.

#ifndef Versao
  #define Versao "0.0.0"
#endif
#ifndef Origem
  #define Origem "..\build"
#endif

[Setup]
; AppId fixo: é o que faz uma versão nova instalar por cima da antiga. Não mudar.
AppId={{6E2B9C41-7D35-4F0A-9B8E-3C1D5A7F2E90}
AppName=Bruma
AppVersion={#Versao}
AppVerName=Bruma {#Versao}
AppPublisher=Gabriel Medeiros
DefaultDirName={autopf}\Bruma
DefaultGroupName=Bruma
DisableProgramGroupPage=yes
; Quem não é administrador pode instalar só para si (na pasta do usuário).
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=saida
OutputBaseFilename=Bruma_Setup_v{#Versao}
SetupIconFile=bruma.ico
UninstallDisplayIcon={app}\bruma.ico
UninstallDisplayName=Bruma
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "atalho"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Origem}\Bruma.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "bruma.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Bruma"; Filename: "{app}\Bruma.exe"; IconFilename: "{app}\bruma.ico"
Name: "{group}\{cm:UninstallProgram,Bruma}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Bruma"; Filename: "{app}\Bruma.exe"; IconFilename: "{app}\bruma.ico"; Tasks: atalho

[Run]
Filename: "{app}\Bruma.exe"; Description: "{cm:LaunchProgram,Bruma}"; Flags: nowait postinstall skipifsilent

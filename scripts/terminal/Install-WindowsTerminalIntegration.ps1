#Requires -Version 5.1

<#
.SYNOPSIS
    TechSquad MCP Ghidra5 - Windows Terminal Integration Installer (Production)
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SetAsDefault,
    [switch]$InstallPowerShell7,
    [switch]$InstallFonts,
    [switch]$ConfigOnly
)

$ErrorActionPreference = "Stop"
$ProgressPreference   = "SilentlyContinue"

# ===================== SAFE LOGGING =====================
function Write-Info    { param($m) Write-Host "ℹ️  $m" -ForegroundColor Cyan }
function Write-Success { param($m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err     { param($m) Write-Host "❌ $m" -ForegroundColor Red }

# ===================== BANNER =====================
Write-Host @"
/$$$$$$$$                  /$$        /$$$$$$                                      /$$               
|__  $$__/                 | $$       /$$__  $$                                    | $$               
   | $$  /$$$$$$   /$$$$$$$| $$$$$$$ | $$  \__/  /$$$$$$  /$$   /$$  /$$$$$$   /$$$$$$$               
   | $$ /$$__  $$ /$$_____/| $$__  $$|  $$$$$$  /$$__  $$| $$  | $$ |____  $$ /$$__  $$               
   | $$| $$$$$$$$| $$      | $$  \ $$ \____  $$| $$  \ $$| $$  | $$  /$$$$$$$| $$  | $$               
   | $$| $$_____/| $$      | $$  | $$ /$$  \ $$| $$  | $$| $$  | $$ /$$__  $$| $$  | $$               
   | $$|  $$$$$$$|  $$$$$$$| $$  | $$|  $$$$$$/|  $$$$$$$|  $$$$$$/|  $$$$$$$|  $$$$$$$               
   |__/ \_______/ \_______/|__/  |__/ \______/  \____  $$ \______/  \_______/ \_______/               
                                                     | $$                                             
                                                     | $$                                             
                                                     |__/                                             
 /$$      /$$  /$$$$$$  /$$$$$$$         /$$$$$$  /$$       /$$       /$$                    /$$$$$$$ 
| $$$    /$$$ /$$__  $$| $$__  $$       /$$__  $$| $$      |__/      | $$                   | $$____/ 
| $$$$  /$$$$| $$  \__/| $$  \ $$      | $$  \__/| $$$$$$$  /$$  /$$$$$$$  /$$$$$$  /$$$$$$ | $$      
| $$ $$/$$ $$| $$      | $$$$$$$/      | $$ /$$$$| $$__  $$| $$ /$$__  $$ /$$__  $$|____  $$| $$$$$$$ 
| $$  $$$| $$| $$      | $$____/       | $$|_  $$| $$  \ $$| $$| $$  | $$| $$  \__/ /$$$$$$$|_____  $$
| $$\  $ | $$| $$    $$| $$            | $$  \ $$| $$  | $$| $$| $$  | $$| $$      /$$__  $$ /$$  \ $$
| $$ \/  | $$|  $$$$$$/| $$            |  $$$$$$/| $$  | $$| $$|  $$$$$$$| $$     |  $$$$$$$|  $$$$$$/
|__/     |__/ \______/ |__/             \______/ |__/  |__/|__/ \_______/|__/      \_______/ \______/ 
"@ -ForegroundColor Magenta

# ===================== REQUIREMENTS =====================
$windowsVersion = [Environment]::OSVersion.Version
if ($windowsVersion -lt [Version]"10.0.18362.0") {
    Write-Err "Windows 10 1903+ required"
    exit 1
}

$wtPackage = Get-AppxPackage Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
if (-not $wtPackage) {
    Write-Err "Windows Terminal not installed"
    exit 1
}

# ===================== OPTIONAL INSTALLS =====================
if (-not $ConfigOnly -and $InstallPowerShell7 -and -not (Get-Command pwsh.exe -EA SilentlyContinue)) {
    Write-Info "Installing PowerShell 7"
    $msi = "$env:TEMP\ps7.msi"
    Invoke-WebRequest https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.0-win-x64.msi -OutFile $msi
    Start-Process msiexec.exe -ArgumentList "/i",$msi,"/quiet","/norestart" -Wait
    Remove-Item $msi -Force
}

# ===================== TERMINAL SETTINGS =====================
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $wtSettingsPath)) {
    Write-Err "settings.json not found"
    exit 1
}

Copy-Item $wtSettingsPath "$wtSettingsPath.bak.$(Get-Date -Format yyyyMMddHHmmss)"

$settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
if (-not $settings.profiles) { $settings | Add-Member profiles @{ list = @() } -Force }
if (-not $settings.profiles.list) { $settings.profiles.list = @() }
if (-not $settings.schemes) { $settings.schemes = @() }

$installPath = "$env:ProgramFiles\TechSquad\MCP-Ghidra5"
$guidPS5 = "{f4a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c5}"
$guidPS7 = "{f4a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c6}"

$settings.profiles.list = @($settings.profiles.list | Where-Object {
    $_.guid -notin @($guidPS5,$guidPS7)
})

$baseProfile = @{
    guid = $guidPS5
    name = "TechSquad MCP Ghidra5"
    commandline = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force`""
    startingDirectory = $installPath
    fontFace = "Cascadia Code PL"
    fontSize = 11
    colorScheme = "TechSquad Dark"
    cursorShape = "vintage"
    useAcrylic = $true
    acrylicOpacity = 0.85
}

$settings.profiles.list += $baseProfile

if (Get-Command pwsh.exe -EA SilentlyContinue) {
    $ps7Profile = $baseProfile | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $ps7Profile.guid = $guidPS7
    $ps7Profile.name = "TechSquad MCP Ghidra5 (PowerShell 7)"
    $ps7Profile.commandline = "pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force`""
    $settings.profiles.list += $ps7Profile
}

$settings.schemes = @($settings.schemes | Where-Object { $_.name -ne "TechSquad Dark" })
$settings.schemes += @{
    name = "TechSquad Dark"
    background = "#0C0C0C"
    foreground = "#CCCCCC"
    green = "#00D4AA"
    cursorColor = "#00D4AA"
}

if ($SetAsDefault) {
    $settings.defaultProfile = $guidPS5
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8

# ===================== POWERSHELL PROFILE =====================
$profileText = @"
# TechSquad MCP Ghidra5
if (Test-Path '$installPath\modules\TechSquadMCP.psd1') {
    Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force -ErrorAction SilentlyContinue
}
"@

$profiles = @($PROFILE.CurrentUserAllHosts)
if (Get-Command pwsh.exe -EA SilentlyContinue) {
    $profiles += (& pwsh.exe -Command '$PROFILE.CurrentUserAllHosts')
}

foreach ($p in $profiles) {
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $p) -or $Force) {
        Add-Content $p "`n$profileText"
    }
}

# ===================== SHORTCUT =====================
try {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\TechSquad MCP Ghidra5.lnk")
    $sc.TargetPath = "wt.exe"
    $sc.Arguments = "-p `"TechSquad MCP Ghidra5`""
    $sc.WorkingDirectory = $installPath
    $sc.Save()
} catch {}

Write-Success "TechSquad MCP Ghidra5 installation complete"

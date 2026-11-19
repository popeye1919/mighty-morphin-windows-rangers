<#
.SYNOPSIS
    MIGHTY MORPHIN WINDOWS RANGERS // Invoke-MorphinStartup.ps1
    The 90s Hacker Dad & Nerdy Professor Interactive PowerShell Startup, Browser & Custom Zord Module Orchestrator.
    "It's Morphin Time! Mastodon! Pterodactyl! Triceratops! Sabertooth Tiger! Tyrannosaurus! PowerShell!"

.DESCRIPTION
    A 100% pure-PowerShell interactive startup automation suite for Windows 10/11 power users,
    cyber instructors, SOC analysts, and 90s Hacker Dads.

    Core Capabilities:
      1. Deep Startup Folder & Registry Run Inspection:
         Audits Per-User (shell:startup), All-Users (shell:common startup), and Registry Run keys
         (HKCU/HKLM...\CurrentVersion\Run), unwrapping .lnk shortcuts via WScript.Shell COM.
      2. Multi-Hive Registry Installed Program Discovery:
         Queries 64-bit (HKLM), 32-bit (HKLM\WOW6432Node), and Per-User (HKCU) Uninstall Registry
         hives plus App Paths in milliseconds (never touching slow Win32_Product WMI).
      3. Highly Responsive Interactive Wizard (Console TUI + Optional Out-GridView GUI):
         Lets the user filter (/search), toggle (1,3,5-7), and configure startup applications
         with per-app arguments, launch delays, window styles, and idempotent process guards.
      4. Main Browser & Native Chrome Tab Group Orchestrator:
         Auto-detects installed browsers and OS defaults. For Google Chrome users, organizes
         startup websites into Standard Tabs, Separate Windows, or TRUE Named & Color-Coded
         Chrome Tab Groups via an auto-synthesized Manifest V3 chrome.tabGroups micro-extension.
      5. Pluggable Custom PowerShell Zord Modules (modules\*.psm1):
         Automatically discovers custom PowerShell modules (.psm1) in .\modules\, prompts the
         user to enable & configure them during the Wizard, executes them during startup, and
         includes a built-in module generator (-Mode NewModule -ModuleName "Morphin.MyZord").

.PARAMETER Mode
    Operation mode:
      - Menu        : Interactive 90s Command Center Main Menu (Pure PowerShell)
      - Wizard      : Full interactive setup wizard (Startup Apps + Browser/Tab Groups + Custom .psm1 Modules)
      - Run         : Execute the saved startup profile (launches enabled Zord modules, apps, and browser tab groups)
      - Audit       : Inspect current Startup Folders, Registry Run keys, Installed Programs, and Custom Modules
      - ListModules : List all discovered custom PowerShell modules in .\modules\*.psm1
      - NewModule   : Scaffold a new custom PowerShell startup module in .\modules\<ModuleName>.psm1
      - Install     : Register Invoke-MorphinStartup.ps1 into Windows shell:startup (with pre-change backup)
      - ExportAudit : Export a full JSON forensic inventory of startup items, registry apps, and modules
      - Demo        : Run the interactive wizard with simulated registry/startup data (works on Windows, Linux & macOS!)

.PARAMETER ModuleName
    Used with -Mode NewModule to specify the name of the new custom PowerShell module (e.g., "Morphin.MyCustomZord").

.PARAMETER ConfigPath
    Path to the JSON startup profile. Defaults to .\config\startup-profile.json.

.PARAMETER UseGridView
    When specified on Windows, opens PowerShell's graphical Out-GridView (-PassThru) picker.

.PARAMETER VerifySignatures
    When specified, checks Authenticode digital signatures on target executables before launching.

.PARAMETER DryRun
    Simulates launching modules, applications, and browser tab groups without spawning processes.

.PARAMETER NoBanner
    Suppresses the 90s Command Center ASCII header.

.EXAMPLE
    .\Invoke-MorphinStartup.ps1
    .\Invoke-MorphinStartup.ps1 -Mode Wizard
    .\Invoke-MorphinStartup.ps1 -Mode Wizard -UseGridView
    .\Invoke-MorphinStartup.ps1 -Mode Run
    .\Invoke-MorphinStartup.ps1 -Mode NewModule -ModuleName "Morphin.HamRadio"
    .\Invoke-MorphinStartup.ps1 -Mode ListModules
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Menu", "Wizard", "Run", "Audit", "ListModules", "NewModule", "Install", "ExportAudit", "Demo")]
    [string]$Mode = "Menu",

    [Parameter()]
    [string]$ModuleName = "",

    [Parameter()]
    [string]$ConfigPath = "",

    [Parameter()]
    [switch]$UseGridView,

    [Parameter()]
    [switch]$VerifySignatures,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$NoBanner
)

$ErrorActionPreference = "Stop"

# ==============================================================================
# 0x00 // ENVIRONMENT & DIRECTORY INITIALIZATION
# ==============================================================================
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$ConfigDir  = Join-Path $ScriptRoot "config"
$ModulesDir = Join-Path $ScriptRoot "modules"
$BackupDir  = Join-Path $ScriptRoot "backups"
$LogDir     = Join-Path $ScriptRoot "logs"
$ExtDir     = Join-Path $ConfigDir  "chrome-tabgroups-ext"

foreach ($dir in @($ConfigDir, $ModulesDir, $BackupDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ConfigDir "startup-profile.json"
}

$IsWindowsHost = ($env:OS -match "Windows") -or ($PSVersionTable.Platform -eq "Win32NT") -or ([System.Environment]::OSVersion.Platform -eq "Win32NT")

# ==============================================================================
# 0x01 // MIGHTY MORPHIN COMMAND CENTER BANNER & LOGGING
# ==============================================================================
function Write-MorphinBanner {
    if ($NoBanner) { return }
    $banner = @"
+----------------------------------------------------------------------------------------------+
| [/] MIGHTY MORPHIN WINDOWS RANGERS // Invoke-MorphinStartup.ps1                [_][#][X]     |
+----------------------------------------------------------------------------------------------+
|                                                                                              |
|     .-------------.                        .-------------------.              .-----------.  |
|     | .---------. |   HKLM\..\Uninstall    | [1] shell:startup |   --tabs     | [o] [o]   |  |
|     | | PS C:\> | |  ===================>  | [2] Registry Apps |  =========>  |  CHROME   |  |
|     | | MORPHIN | |    shell:startup       | [3] Main Browser  |   TabGroups  |  TAB GRPS |  |
|     | |  TIME!  | |  ===================>  | [4] Zord Modules  |  =========>  |  .PSM1    |  |
|     | '---------' |   modules\*.psm1       '-------------------'              '-----------'  |
|     '-----+-+-----'                                  |                                       |
|       .---'-'---.          "THERE'S NO PLACE LIKE 127.0.0.1 (TRYING TO FIND MY WAN)"         |
|      /:::::::::::\         "Ay-yi-yi-yi-yi! Hold your dino cookies—Dad is morphin boot!"     |
|                                                                                              |
+==============================================================================================+
|  [ SYSOP: The Nerdy Professor (d4rksp2rk) // ENGINE: Pure PowerShell 5.1+ & 7+            ]  |
|  [ ZORDS: Startup Folder + 3-Hive Registry + Chrome Tab Groups + Custom .psm1 Modules     ]  |
+==============================================================================================+
"@
    Write-Host $banner -ForegroundColor Cyan
}

function Write-SectionHeader {
    param([string]$HexCode, [string]$Title, [string]$Subtitle = "")
    Write-Host ""
    Write-Host "==============================================================================================" -ForegroundColor DarkCyan
    Write-Host " [$HexCode] // $Title" -ForegroundColor Cyan
    if ($Subtitle) {
        Write-Host "        $Subtitle" -ForegroundColor DarkGray
    }
    Write-Host "==============================================================================================" -ForegroundColor DarkCyan
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $LogDir "morphin_startup.log"
    "[$ts] [$Level] $Message" | Add-Content -Path $logFile -Encoding UTF8 -ErrorAction SilentlyContinue

    switch ($Level) {
        "INFO"  { Write-Host "[*] $Message" -ForegroundColor Cyan }
        "OK"    { Write-Host "[+] $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[-] $Message" -ForegroundColor Red }
    }
}

function Read-HostWithDefault {
    param(
        [string]$Prompt,
        [string]$DefaultValue = ""
    )
    $displayPrompt = if ($DefaultValue -ne "") { "$Prompt [$DefaultValue]" } else { $Prompt }
    Write-Host -NoNewline "    [?] ${displayPrompt}: " -ForegroundColor Yellow
    $inputVal = Read-Host
    if ([string]::IsNullOrWhiteSpace($inputVal)) {
        return $DefaultValue
    }
    return $inputVal.Trim()
}

# ==============================================================================
# 0x02 // STARTUP FOLDER & SHORTCUT (.LNK) FORENSIC INSPECTOR
# ==============================================================================
function Resolve-ShortcutTarget {
    <#
    .SYNOPSIS
        Uses WScript.Shell COM automation on Windows to resolve .lnk shortcut files
        inside shell:startup to their underlying TargetPath, Arguments, and WorkingDirectory.
    #>
    param([Parameter(Mandatory = $true)][string]$ShortcutPath)

    $result = [PSCustomObject]@{
        TargetPath       = $ShortcutPath
        Arguments        = ""
        WorkingDirectory = Split-Path -Parent $ShortcutPath
        Description      = ""
    }

    if (-not $IsWindowsHost) { return $result }

    if ($ShortcutPath -match '\.lnk$') {
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $sc  = $wsh.CreateShortcut($ShortcutPath)
            if ($sc.TargetPath) {
                $result.TargetPath       = $sc.TargetPath
                $result.Arguments        = [string]$sc.Arguments
                $result.WorkingDirectory = [string]$sc.WorkingDirectory
                $result.Description      = [string]$sc.Description
            }
        } catch {
            # Fallback to raw shortcut path if COM resolution fails
        }
    }
    return $result
}

function Get-StartupFolderItems {
    <#
    .SYNOPSIS
        Inspects both the Per-User Startup folder (shell:startup) and All-Users Common
        Startup folder (shell:common startup), plus HKCU/HKLM Registry Run keys.
    #>
    param([switch]$DemoMode)

    if ($DemoMode -or (-not $IsWindowsHost)) {
        return @(
            [PSCustomObject]@{
                Id               = "STARTUP-01"
                Name             = "Discord"
                Source           = "User Startup Folder (shell:startup)"
                ExecutablePath   = "C:\Users\HackerDad\AppData\Local\Discord\Update.exe"
                Arguments        = "--processStart Discord.exe"
                ProcessName      = "Discord"
                AlreadyInStartup = $true
                Publisher        = "Discord Inc."
            },
            [PSCustomObject]@{
                Id               = "STARTUP-02"
                Name             = "PowerToys"
                Source           = "User Startup Folder (shell:startup)"
                ExecutablePath   = "C:\Program Files\PowerToys\PowerToys.exe"
                Arguments        = ""
                ProcessName      = "PowerToys"
                AlreadyInStartup = $true
                Publisher        = "Microsoft Corporation"
            },
            [PSCustomObject]@{
                Id               = "STARTUP-03"
                Name             = "Docker Desktop"
                Source           = "Common Startup Folder (shell:common startup)"
                ExecutablePath   = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                Arguments        = ""
                ProcessName      = "Docker Desktop"
                AlreadyInStartup = $true
                Publisher        = "Docker Inc."
            },
            [PSCustomObject]@{
                Id               = "STARTUP-04"
                Name             = "Everything Search Engine"
                Source           = "Registry Run (HKCU\...\CurrentVersion\Run)"
                ExecutablePath   = "C:\Program Files\Everything\Everything.exe"
                Arguments        = "-startup"
                ProcessName      = "Everything"
                AlreadyInStartup = $true
                Publisher        = "voidtools"
            }
        )
    }

    $items = @()
    $startupLocations = @(
        @{ Label = "User Startup Folder (shell:startup)";          Path = [Environment]::GetFolderPath('Startup') },
        @{ Label = "Common Startup Folder (shell:common startup)"; Path = [Environment]::GetFolderPath('CommonStartup') }
    )

    $idx = 1
    foreach ($loc in $startupLocations) {
        if ($loc.Path -and (Test-Path $loc.Path)) {
            $files = Get-ChildItem -Path $loc.Path -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '^desktop\.ini$' }

            foreach ($f in $files) {
                $resolved  = Resolve-ShortcutTarget -ShortcutPath $f.FullName
                $exePath   = if ($resolved.TargetPath) { $resolved.TargetPath } else { $f.FullName }
                $procName  = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                $cleanName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)

                $items += [PSCustomObject]@{
                    Id               = ("STARTUP-{0:D2}" -f $idx)
                    Name             = $cleanName
                    Source           = $loc.Label
                    ShortcutPath     = $f.FullName
                    ExecutablePath   = $exePath
                    Arguments        = $resolved.Arguments
                    ProcessName      = $procName
                    AlreadyInStartup = $true
                    Publisher        = "Startup Folder Entry"
                }
                $idx++
            }
        }
    }

    $runKeys = @(
        @{ Label = "Registry Run (HKCU)"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" },
        @{ Label = "Registry Run (HKLM)"; Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" }
    )
    foreach ($rk in $runKeys) {
        if (Test-Path $rk.Path) {
            $props = Get-ItemProperty -Path $rk.Path -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -in @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) { continue }
                    $rawCmd = [string]$prop.Value
                    if (-not $rawCmd) { continue }

                    $exePath = $rawCmd
                    $argsStr = ""
                    if ($rawCmd -match '^"([^"]+)"\s*(.*)$') {
                        $exePath = $Matches[1]
                        $argsStr = $Matches[2]
                    } elseif ($rawCmd -match '^([^\s]+\.exe)\s*(.*)$') {
                        $exePath = $Matches[1]
                        $argsStr = $Matches[2]
                    }

                    $procName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                    $items += [PSCustomObject]@{
                        Id               = ("STARTUP-{0:D2}" -f $idx)
                        Name             = $prop.Name
                        Source           = $rk.Label
                        ShortcutPath     = $rk.Path
                        ExecutablePath   = $exePath
                        Arguments        = $argsStr
                        ProcessName      = $procName
                        AlreadyInStartup = $true
                        Publisher        = "Registry Run Key"
                    }
                    $idx++
                }
            }
        }
    }

    return $items
}

# ==============================================================================
# 0x03 // MULTI-HIVE WINDOWS REGISTRY INSTALLED APPLICATION SCANNER
# ==============================================================================
function Get-AppPathsRegistryMap {
    $map = @{}
    if (-not $IsWindowsHost) { return $map }

    $appPathRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths"
    )
    foreach ($root in $appPathRoots) {
        if (Test-Path $root) {
            foreach ($sub in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
                $val = (Get-ItemProperty -Path $sub.PSPath -ErrorAction SilentlyContinue).'(default)'
                if ($val) {
                    $cleanVal = ($val -replace '^"|"$', '').Trim()
                    $keyName  = [System.IO.Path]::GetFileNameWithoutExtension($sub.PSChildName).ToLower()
                    if (Test-Path $cleanVal) {
                        $map[$keyName] = $cleanVal
                    }
                }
            }
        }
    }
    return $map
}

function Resolve-RegistryAppExecutable {
    param(
        [Parameter(Mandatory = $true)]$RegEntry,
        [Parameter(Mandatory = $true)][hashtable]$AppPathsMap
    )

    if ($RegEntry.DisplayIcon) {
        $iconPath = [string]$RegEntry.DisplayIcon
        $iconPath = ($iconPath -replace ',\s*-?\d+$', '') -replace '^"|"$', ''
        $iconPath = $iconPath.Trim()
        if ($iconPath -match '\.exe$' -and ($iconPath -notmatch 'unins|msiexec|arpcache|setup|installer') -and (Test-Path $iconPath)) {
            return $iconPath
        }
    }

    if ($RegEntry.InstallLocation) {
        $instDir = ([string]$RegEntry.InstallLocation -replace '^"|"$', '').Trim()
        if ($instDir -and (Test-Path $instDir)) {
            $exes = Get-ChildItem -Path $instDir -Filter "*.exe" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '^(unins|update|crashpad|helper|setup|vcredist|dxsetup|elevate|createdump)' }

            if ($exes) {
                $dispSimple = ($RegEntry.DisplayName -replace '[^A-Za-z0-9]', '').ToLower()
                $bestMatch = $exes | Where-Object {
                    $stem = ($_.BaseName -replace '[^A-Za-z0-9]', '').ToLower()
                    ($dispSimple -match [regex]::Escape($stem)) -or ($stem -match [regex]::Escape($dispSimple))
                } | Select-Object -First 1

                if ($bestMatch) { return $bestMatch.FullName }
                return ($exes | Sort-Object Length -Descending | Select-Object -First 1).FullName
            }
        }
    }

    $cleanDisp = ([string]$RegEntry.DisplayName).ToLower()
    foreach ($k in $AppPathsMap.Keys) {
        if ($k.Length -ge 3 -and $cleanDisp -match "\b$([regex]::Escape($k))\b") {
            return $AppPathsMap[$k]
        }
    }

    return ""
}

function Get-InstalledRegistryApplications {
    param([switch]$DemoMode)

    if ($DemoMode -or (-not $IsWindowsHost)) {
        return @(
            [PSCustomObject]@{ Id = "REG-01"; Name = "Visual Studio Code";           Version = "1.96.0";   Publisher = "Microsoft Corporation";          ExecutablePath = "C:\Users\HackerDad\AppData\Local\Programs\Microsoft VS Code\Code.exe"; ProcessName = "Code";            Hive = "HKCU\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-02"; Name = "Wireshark 4.4.2 (64-bit)";     Version = "4.4.2";    Publisher = "The Wireshark developer community"; ExecutablePath = "C:\Program Files\Wireshark\Wireshark.exe";                        ProcessName = "Wireshark";       Hive = "HKLM\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-03"; Name = "Obsidian";                     Version = "1.7.7";    Publisher = "Obsidian";                       ExecutablePath = "C:\Users\HackerDad\AppData\Local\Programs\Obsidian\Obsidian.exe";      ProcessName = "Obsidian";        Hive = "HKCU\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-04"; Name = "Windows Terminal";             Version = "1.21.0";   Publisher = "Microsoft Corporation";          ExecutablePath = "C:\Users\HackerDad\AppData\Local\Microsoft\WindowsApps\wt.exe";        ProcessName = "WindowsTerminal"; Hive = "HKCU\...\App Paths" },
            [PSCustomObject]@{ Id = "REG-05"; Name = "CHIRP-next (Ham Radio CPS)";   Version = "20261101"; Publisher = "Dan Smith (KK7DS)";              ExecutablePath = "C:\Program Files (x86)\CHIRP\chirpw.exe";                              ProcessName = "chirpw";          Hive = "HKLM\WOW6432Node\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-06"; Name = "VMware Workstation Pro";       Version = "17.6.1";   Publisher = "VMware, Inc.";                   ExecutablePath = "C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe";          ProcessName = "vmware";          Hive = "HKLM\WOW6432Node\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-07"; Name = "PuTTY release 0.82 (64-bit)";  Version = "0.82";     Publisher = "Simon Tatham";                   ExecutablePath = "C:\Program Files\PuTTY\putty.exe";                                     ProcessName = "putty";           Hive = "HKLM\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-08"; Name = "Sysinternals Process Explorer";Version = "17.06";    Publisher = "Mark Russinovich";               ExecutablePath = "C:\Tools\Sysinternals\procexp64.exe";                                  ProcessName = "procexp64";       Hive = "HKLM\...\App Paths" },
            [PSCustomObject]@{ Id = "REG-09"; Name = "Spotify";                      Version = "1.2.50";   Publisher = "Spotify AB";                     ExecutablePath = "C:\Users\HackerDad\AppData\Roaming\Spotify\Spotify.exe";               ProcessName = "Spotify";         Hive = "HKCU\...\Uninstall" },
            [PSCustomObject]@{ Id = "REG-10"; Name = "Slack";                        Version = "4.41.90";  Publisher = "Slack Technologies Inc.";        ExecutablePath = "C:\Users\HackerDad\AppData\Local\slack\slack.exe";                     ProcessName = "slack";           Hive = "HKCU\...\Uninstall" }
        )
    }

    $appPathsMap = Get-AppPathsRegistryMap
    $registryHives = @(
        @{ Label = "HKLM (64-Bit)";     Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" },
        @{ Label = "HKLM (32-Bit WOW)"; Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" },
        @{ Label = "HKCU (Per-User)";   Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" }
    )

    $seenNames  = @{}
    $discovered = @()

    foreach ($hive in $registryHives) {
        $entries = Get-ItemProperty -Path $hive.Path -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -and
                ($_.SystemComponent -ne 1) -and
                (-not $_.ParentKeyName) -and
                ($_.ReleaseType -notmatch 'Security Update|Update Rollup|Hotfix') -and
                ($_.DisplayName -notmatch '^(KB\d+|Microsoft Visual C\+\+.*Redistributable|Microsoft \.NET|Windows Software Development Kit)')
            }

        foreach ($entry in $entries) {
            $name    = ([string]$entry.DisplayName).Trim()
            $normKey = $name.ToLower()
            if ($seenNames.ContainsKey($normKey)) { continue }

            $exePath = Resolve-RegistryAppExecutable -RegEntry $entry -AppPathsMap $appPathsMap
            $seenNames[$normKey] = $true

            $procName = if ($exePath) {
                [System.IO.Path]::GetFileNameWithoutExtension($exePath)
            } else {
                ($name -replace '[^A-Za-z0-9_-]', '')
            }

            $discovered += [PSCustomObject]@{
                Name           = $name
                Version        = [string]$entry.DisplayVersion
                Publisher      = [string]$entry.Publisher
                InstallDir     = [string]$entry.InstallLocation
                ExecutablePath = $exePath
                ProcessName    = $procName
                Hive           = $hive.Label
            }
        }
    }

    $sorted = $discovered | Sort-Object @{Expression = { [bool]$_.ExecutablePath }; Descending = $true }, Name
    $finalList = @()
    $idx = 1
    foreach ($app in $sorted) {
        $finalList += [PSCustomObject]@{
            Id             = ("REG-{0:D2}" -f $idx)
            Name           = $app.Name
            Version        = $app.Version
            Publisher      = $app.Publisher
            ExecutablePath = $app.ExecutablePath
            ProcessName    = $app.ProcessName
            Hive           = $app.Hive
        }
        $idx++
    }
    return $finalList
}

# ==============================================================================
# 0x04 // BROWSER DETECTION & CHROME TAB GROUP ENGINE
# ==============================================================================
function Get-InstalledBrowsers {
    param([switch]$DemoMode)

    if ($DemoMode -or (-not $IsWindowsHost)) {
        return @(
            [PSCustomObject]@{ Key = "Chrome";  Name = "Google Chrome";   ExecutablePath = "C:\Program Files\Google\Chrome\Application\chrome.exe";             IsChromium = $true;  IsDefault = $true  },
            [PSCustomObject]@{ Key = "Edge";    Name = "Microsoft Edge";  ExecutablePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe";       IsChromium = $true;  IsDefault = $false },
            [PSCustomObject]@{ Key = "Firefox"; Name = "Mozilla Firefox"; ExecutablePath = "C:\Program Files\Mozilla Firefox\firefox.exe";                       IsChromium = $false; IsDefault = $false },
            [PSCustomObject]@{ Key = "Brave";   Name = "Brave Browser";   ExecutablePath = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"; IsChromium = $true;  IsDefault = $false }
        )
    }

    $defaultProgId = ""
    $userChoicePath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
    if (Test-Path $userChoicePath) {
        $defaultProgId = [string](Get-ItemProperty -Path $userChoicePath -ErrorAction SilentlyContinue).ProgId
    }

    $candidates = @(
        @{
            Key        = "Chrome"
            Name       = "Google Chrome"
            ProgMatch  = "ChromeHTML"
            IsChromium = $true
            Paths      = @(
                "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe"
            )
        },
        @{
            Key        = "Edge"
            Name       = "Microsoft Edge"
            ProgMatch  = "MSEdgeHTM"
            IsChromium = $true
            Paths      = @(
                "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
            )
        },
        @{
            Key        = "Firefox"
            Name       = "Mozilla Firefox"
            ProgMatch  = "FirefoxURL"
            IsChromium = $false
            Paths      = @(
                "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
                "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
            )
        },
        @{
            Key        = "Brave"
            Name       = "Brave Browser"
            ProgMatch  = "BraveHTML"
            IsChromium = $true
            Paths      = @(
                "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe",
                "${env:LOCALAPPDATA}\BraveSoftware\Brave-Browser\Application\brave.exe"
            )
        },
        @{
            Key        = "Vivaldi"
            Name       = "Vivaldi"
            ProgMatch  = "VivaldiHTM"
            IsChromium = $true
            Paths      = @(
                "${env:LOCALAPPDATA}\Vivaldi\Application\vivaldi.exe",
                "${env:ProgramFiles}\Vivaldi\Application\vivaldi.exe"
            )
        }
    )

    $found = @()
    foreach ($cand in $candidates) {
        $exe = $cand.Paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        if ($exe) {
            $found += [PSCustomObject]@{
                Key            = $cand.Key
                Name           = $cand.Name
                ExecutablePath = $exe
                IsChromium     = $cand.IsChromium
                IsDefault      = ($defaultProgId -match $cand.ProgMatch)
            }
        }
    }

    if ($found.Count -eq 0) {
        $found += [PSCustomObject]@{
            Key            = "Chrome"
            Name           = "Google Chrome (Custom/PATH)"
            ExecutablePath = "chrome.exe"
            IsChromium     = $true
            IsDefault      = $true
        }
    }

    return $found
}

function Build-ChromeTabGroupExtension {
    <#
    .SYNOPSIS
        Synthesizes a zero-dependency Manifest V3 Chrome Extension that calls
        chrome.tabs.group() + chrome.tabGroups.update() to create true named,
        color-coded Chrome Tab Groups on startup.
    #>
    param(
        [Parameter(Mandatory = $true)][array]$TabGroups,
        [Parameter(Mandatory = $true)][string]$OutputDirectory
    )

    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $manifestObj = [Ordered]@{
        manifest_version = 3
        name             = "Mighty Morphin Windows Rangers — Chrome Tab Group Zord"
        version          = "1.0.0"
        description      = "Automatically organizes your PowerShell startup URLs into named, color-coded Chrome Tab Groups."
        permissions      = @("tabs", "tabGroups")
        background       = @{
            service_worker = "background.js"
        }
    }

    $manifestPath = Join-Path $OutputDirectory "manifest.json"
    $manifestObj | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8

    $groupsJson = ($TabGroups | ConvertTo-Json -Depth 6 -Compress)

    $bgJs = @"
// ============================================================================
// Mighty Morphin Windows Rangers // Chrome Tab Group Zord (Manifest V3)
// Valid Chrome TabGroup colors: grey, blue, red, yellow, green, pink, purple, cyan, orange
// ============================================================================
const STARTUP_TAB_GROUPS = $groupsJson;
let hasExecuted = false;

async function orchestrateTabGroups() {
  if (hasExecuted) return;
  hasExecuted = true;

  try {
    const currentWin = await chrome.windows.getLastFocused({ populate: true });
    for (const grp of STARTUP_TAB_GROUPS) {
      if (!grp.Urls || grp.Urls.length === 0) continue;

      const createdTabIds = [];
      for (const targetUrl of grp.Urls) {
        const tab = await chrome.tabs.create({
          windowId: currentWin.id,
          url: targetUrl,
          active: false
        });
        createdTabIds.push(tab.id);
      }

      if (createdTabIds.length > 0) {
        const groupId = await chrome.tabs.group({
          tabIds: createdTabIds,
          createProperties: { windowId: currentWin.id }
        });

        await chrome.tabGroups.update(groupId, {
          title: grp.GroupName || "Ranger Tab Group",
          color: (grp.Color || "blue").toLowerCase(),
          collapsed: Boolean(grp.Collapsed)
        });
      }
    }
  } catch (err) {
    console.error("[Mighty Morphin TabGroup Zord] Error:", err);
  }
}

chrome.runtime.onStartup.addListener(orchestrateTabGroups);
chrome.runtime.onInstalled.addListener(orchestrateTabGroups);
"@

    $bgPath = Join-Path $OutputDirectory "background.js"
    Set-Content -Path $bgPath -Value $bgJs -Encoding UTF8

    return $OutputDirectory
}

# ==============================================================================
# 0x05 // CUSTOM POWERSHELL ZORD MODULE ENGINE (modules\*.psm1)
# ==============================================================================
function Get-MorphinCustomModules {
    <#
    .SYNOPSIS
        Discovers all PowerShell modules (.psm1) inside .\modules\, loads their
        Get-MorphinModuleInfo metadata, and returns them for the Wizard or Runner.
    #>
    $discovered = @()
    if (-not (Test-Path $ModulesDir)) { return $discovered }

    $moduleFiles = Get-ChildItem -Path $ModulesDir -Filter "*.psm1" -File -ErrorAction SilentlyContinue | Sort-Object Name
    $idx = 1

    foreach ($file in $moduleFiles) {
        try {
            $mod = Import-Module -Name $file.FullName -PassThru -Force -DisableNameChecking -ErrorAction Stop
            $info = $null
            $infoCmd = $mod.ExportedFunctions["Get-MorphinModuleInfo"]
            if ($infoCmd) {
                $info = & $mod { Get-MorphinModuleInfo }
            }

            $hasInteractiveConfig = [bool]$mod.ExportedFunctions["Set-MorphinModuleConfig"]

            $discovered += [PSCustomObject]@{
                Id            = ("ZORD-{0:D2}" -f $idx)
                ModuleName    = if ($info -and $info.ModuleName)  { $info.ModuleName }  else { $file.BaseName }
                ZordName      = if ($info -and $info.ZordName)    { $info.ZordName }    else { "$($file.BaseName) Custom Zord" }
                RangerColor   = if ($info -and $info.RangerColor) { $info.RangerColor } else { "Cyan" }
                Version       = if ($info -and $info.Version)     { $info.Version }     else { "1.0.0" }
                Author        = if ($info -and $info.Author)      { $info.Author }      else { "Custom Ranger" }
                Description   = if ($info -and $info.Description) { $info.Description } else { "Custom PowerShell startup module ($($file.Name))" }
                ModulePath    = $file.FullName
                HasConfigHook = $hasInteractiveConfig
            }
            $idx++
        } catch {
            Write-Log "Could not load custom module '$($file.Name)': $($_.Exception.Message)" -Level WARN
        }
    }

    return $discovered
}

function New-MorphinModuleTemplate {
    <#
    .SYNOPSIS
        Scaffolds a ready-to-customize PowerShell module (.psm1) inside .\modules\
        so any user can extend Invoke-MorphinStartup.ps1 with their own automation!
    #>
    param([Parameter(Mandatory = $true)][string]$TargetName)

    $cleanName = $TargetName -replace '\.psm1$', ''
    if ($cleanName -notmatch '^Morphin\.') {
        $cleanName = "Morphin.$cleanName"
    }

    $targetFile = Join-Path $ModulesDir "$cleanName.psm1"
    if (Test-Path $targetFile) {
        throw "Module already exists at: $targetFile"
    }

    $shortTitle = $cleanName -replace '^Morphin\.', ''
    $templateContent = @"
<#
.SYNOPSIS
    $cleanName.psm1 — Custom Mighty Morphin Windows Rangers Startup Zord Module.
    Created with: .\Invoke-MorphinStartup.ps1 -Mode NewModule -ModuleName "$cleanName"

.DESCRIPTION
    Drop any .psm1 file exporting Get-MorphinModuleInfo and Invoke-MorphinModule
    into .\modules\ and Invoke-MorphinStartup.ps1 will automatically discover it!
#>

function Get-MorphinModuleInfo {
    return [PSCustomObject]@{
        ModuleName  = "$cleanName"
        ZordName    = "$shortTitle Custom Automation Zord"
        RangerColor = "Green"
        Version     = "1.0.0"
        Author      = "$env:USERNAME"
        Description = "Custom PowerShell startup module for $shortTitle tasks."
    }
}

function Set-MorphinModuleConfig {
    <#
    .SYNOPSIS
        Optional interactive configuration hook called during '.\Invoke-MorphinStartup.ps1 -Mode Wizard'
        when the user selects this module. Return a hashtable of settings to save in startup-profile.json!
    #>
    param([hashtable]`$CurrentSettings = @{})

    Write-Host "    [$shortTitle Zord] Configuring custom parameters..." -ForegroundColor Green
    `$defaultMsg = if (`$CurrentSettings.CustomGreeting) { `$CurrentSettings.CustomGreeting } else { "Dragonzord Power Online!" }

    Write-Host -NoNewline "    [?] Enter custom startup message [`$defaultMsg]: " -ForegroundColor Yellow
    `$userInput = Read-Host
    if ([string]::IsNullOrWhiteSpace(`$userInput)) { `$userInput = `$defaultMsg }

    return [Ordered]@{
        CustomGreeting = `$userInput.Trim()
    }
}

function Invoke-MorphinModule {
    <#
    .SYNOPSIS
        Main execution entry point called automatically during '.\Invoke-MorphinStartup.ps1 -Mode Run'.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][hashtable]`$Settings = @{},
        [Parameter()][switch]`$DryRun
    )

    `$msg = if (`$Settings.CustomGreeting) { `$Settings.CustomGreeting } else { "Dragonzord Power Online!" }
    Write-Host "    [$($shortTitle.ToUpper()) ZORD] Executing custom PowerShell module..." -ForegroundColor Green

    if (`$DryRun) {
        Write-Host "    [+] [DRY-RUN] Would execute $cleanName with message: `"`$msg`"" -ForegroundColor Cyan
        return
    }

    # -------------------------------------------------------------------------
    # ADD YOUR CUSTOM POWERSHELL STARTUP AUTOMATION BELOW!
    # Examples:
    #   - Mount encrypted VeraCrypt / BitLocker / SMB network drives
    #   - Pull latest git commits on your course / project repositories
    #   - Set custom Windows audio volume, power plan, or wallpaper
    #   - Query an API, check radio repeaters, or start local background jobs
    # -------------------------------------------------------------------------
    Write-Host "    [+] $cleanName says: `$msg" -ForegroundColor Green
}

Export-ModuleMember -Function Get-MorphinModuleInfo, Set-MorphinModuleConfig, Invoke-MorphinModule
"@

    Set-Content -Path $targetFile -Value $templateContent -Encoding UTF8
    Write-Log "Created new custom PowerShell Zord module template at: $targetFile" -Level OK
    return $targetFile
}

# ==============================================================================
# 0x06 // INTERACTIVE WIZARD PHASES (APPS + BROWSER + CUSTOM .PSM1 MODULES)
# ==============================================================================
function Invoke-InteractiveAppSelection {
    param(
        [array]$StartupItems,
        [array]$RegistryItems,
        [switch]$UseGuiPicker
    )

    Write-SectionHeader -HexCode "0x01" `
        -Title "PHASE 1: CURRENT STARTUP FOLDER & REGISTRY RUN AUDIT" `
        -Subtitle "Inspecting shell:startup, shell:common startup, and Registry Run keys..."

    if ($StartupItems.Count -eq 0) {
        Write-Host "    [*] No existing items found in Startup folders." -ForegroundColor DarkGray
    } else {
        Write-Host ("    {0,-6} {1,-12} {2,-28} {3,-34} {4}" -f "[#]", "ID", "Application Name", "Source Location", "Resolved Target & Args") -ForegroundColor Cyan
        Write-Host ("    " + ("-" * 105)) -ForegroundColor DarkCyan
        for ($i = 0; $i -lt $StartupItems.Count; $i++) {
            $item = $StartupItems[$i]
            $targetPreview = "$($item.ExecutablePath) $($item.Arguments)".Trim()
            if ($targetPreview.Length -gt 38) { $targetPreview = $targetPreview.Substring(0, 35) + "..." }
            Write-Host ("    [{0,2}]   {1,-12} {2,-28} {3,-34} {4}" -f ($i + 1), $item.Id, $item.Name, $item.Source, $targetPreview) -ForegroundColor Green
        }
    }

    $selectedApps = @()

    if ($StartupItems.Count -gt 0) {
        Write-Host ""
        Write-Host "    Professor's Tip: Items in shell:startup launch automatically with Windows, OR you can let" -ForegroundColor DarkGray
        Write-Host "    this script orchestrate them with process-duplicate checks and staggered boot delays!" -ForegroundColor DarkGray
        $startupChoice = Read-HostWithDefault -Prompt "Enter numbers of Startup Folder apps to include (e.g. 1,3 or 'all' or 'none')" -DefaultValue "none"

        if ($startupChoice -and $startupChoice.ToLower() -ne "none") {
            $indices = @()
            if ($startupChoice.ToLower() -eq "all") {
                $indices = 1..($StartupItems.Count)
            } else {
                foreach ($token in ($startupChoice -split ',')) {
                    $t = $token.Trim()
                    if ($t -match '^(\d+)-(\d+)$') {
                        $indices += ([int]$Matches[1])..([int]$Matches[2])
                    } elseif ($t -match '^\d+$') {
                        $indices += [int]$t
                    }
                }
            }
            foreach ($idx in ($indices | Select-Object -Unique)) {
                if ($idx -ge 1 -and $idx -le $StartupItems.Count) {
                    $sItem = $StartupItems[$idx - 1]
                    $selectedApps += [Ordered]@{
                        Name           = $sItem.Name
                        Origin         = $sItem.Source
                        ExecutablePath = $sItem.ExecutablePath
                        Arguments      = $sItem.Arguments
                        ProcessName    = $sItem.ProcessName
                        DelaySeconds   = 2
                        WindowStyle    = "Normal"
                    }
                }
            }
        }
    }

    Write-SectionHeader -HexCode "0x02" `
        -Title "PHASE 2: INSTALLED PROGRAMS VIA WINDOWS REGISTRY QUERY" `
        -Subtitle "Scanned HKLM (64-bit), HKLM\WOW6432Node (32-bit), HKCU Uninstall & App Paths ($($RegistryItems.Count) programs found)"

    if ($UseGuiPicker -and $IsWindowsHost -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)) {
        Write-Log "Opening graphical Out-GridView multi-select picker (Hold CTRL to select multiple apps, then click OK)..." -Level INFO
        $guiPicked = $RegistryItems | Out-GridView -Title "Mighty Morphin Windows Rangers // Select Installed Applications to Launch" -PassThru
        foreach ($app in $guiPicked) {
            $exePath = $app.ExecutablePath
            if (-not $exePath) {
                $exePath = Read-HostWithDefault -Prompt "Enter executable path for '$($app.Name)'" -DefaultValue ""
            }
            if ($exePath) {
                $selectedApps += [Ordered]@{
                    Name           = $app.Name
                    Origin         = "Registry ($($app.Hive))"
                    ExecutablePath = $exePath
                    Arguments      = ""
                    ProcessName    = $app.ProcessName
                    DelaySeconds   = 2
                    WindowStyle    = "Normal"
                }
            }
        }
        return $selectedApps
    }

    $currentFilter = ""
    $pageSize = 25
    $donePicking = $false
    $pickedIds = @{}

    while (-not $donePicking) {
        $filteredList = if ($currentFilter) {
            @($RegistryItems | Where-Object { $_.Name -match [regex]::Escape($currentFilter) -or $_.Publisher -match [regex]::Escape($currentFilter) })
        } else {
            @($RegistryItems | Select-Object -First $pageSize)
        }

        Write-Host ""
        if ($currentFilter) {
            Write-Host "    Showing installed apps matching filter '$currentFilter' ($($filteredList.Count) matches):" -ForegroundColor Yellow
        } else {
            Write-Host "    Showing top $($filteredList.Count) of $($RegistryItems.Count) installed applications (type '/search <keyword>' to filter):" -ForegroundColor Cyan
        }

        Write-Host ("    {0,-6} {1,-10} {2,-10} {3,-32} {4,-24} {5}" -f "[#]", "Status", "ID", "Application Name", "Publisher", "Resolved Executable") -ForegroundColor Cyan
        Write-Host ("    " + ("-" * 112)) -ForegroundColor DarkCyan

        for ($i = 0; $i -lt $filteredList.Count; $i++) {
            $app = $filteredList[$i]
            $isPicked = $pickedIds.ContainsKey($app.Id)
            $statusBadge = if ($isPicked) { "[SELECTED]" } else { "[        ]" }
            $rowColor    = if ($isPicked) { "Green" } elseif ($app.ExecutablePath) { "White" } else { "DarkGray" }

            $dispName = if ($app.Name.Length -gt 30) { $app.Name.Substring(0, 27) + "..." } else { $app.Name }
            $pubName  = if ($app.Publisher -and $app.Publisher.Length -gt 22) { $app.Publisher.Substring(0, 19) + "..." } else { [string]$app.Publisher }
            $exeDisp  = if ($app.ExecutablePath) {
                if ($app.ExecutablePath.Length -gt 36) { "..." + $app.ExecutablePath.Substring($app.ExecutablePath.Length - 33) } else { $app.ExecutablePath }
            } else {
                "(Prompt for path if chosen)"
            }

            Write-Host ("    [{0,2}]   {1,-10} {2,-10} {3,-32} {4,-24} {5}" -f ($i + 1), $statusBadge, $app.Id, $dispName, $pubName, $exeDisp) -ForegroundColor $rowColor
        }

        Write-Host ""
        Write-Host "    Commands: " -NoNewline -ForegroundColor Cyan
        Write-Host "Enter number(s) to toggle (e.g. " -NoNewline -ForegroundColor Gray
        Write-Host "1,3,5-7" -NoNewline -ForegroundColor Yellow
        Write-Host ") | " -NoNewline -ForegroundColor Gray
        Write-Host "/search <name>" -NoNewline -ForegroundColor Yellow
        Write-Host " | " -NoNewline -ForegroundColor Gray
        Write-Host "/all" -NoNewline -ForegroundColor Yellow
        Write-Host " (reset filter) | " -NoNewline -ForegroundColor Gray
        Write-Host "/custom" -NoNewline -ForegroundColor Yellow
        Write-Host " (add custom exe) | " -NoNewline -ForegroundColor Gray
        Write-Host "done" -ForegroundColor Green

        $cmd = Read-HostWithDefault -Prompt "Select app(s) or command" -DefaultValue "done"

        if ($cmd.ToLower() -eq "done" -or $cmd.ToLower() -eq "d") {
            $donePicking = $true
            break
        } elseif ($cmd -match '^/(search|filter|s)\s+(.+)$') {
            $currentFilter = $Matches[2].Trim()
            continue
        } elseif ($cmd -match '^/(all|reset)$') {
            $currentFilter = ""
            continue
        } elseif ($cmd -match '^/custom$') {
            $custName = Read-HostWithDefault -Prompt "Custom Application Display Name" -DefaultValue "My Cyber Tool"
            $custExe  = Read-HostWithDefault -Prompt "Full Path to Executable (.exe / .ps1)" -DefaultValue ""
            $custArgs = Read-HostWithDefault -Prompt "Optional Launch Arguments" -DefaultValue ""
            if ($custExe) {
                $selectedApps += [Ordered]@{
                    Name           = $custName
                    Origin         = "Custom User Entry"
                    ExecutablePath = $custExe
                    Arguments      = $custArgs
                    ProcessName    = [System.IO.Path]::GetFileNameWithoutExtension($custExe)
                    DelaySeconds   = 2
                    WindowStyle    = "Normal"
                }
                Write-Log "Added custom application: $custName ($custExe)" -Level OK
            }
            continue
        } else {
            $toggleIndices = @()
            foreach ($token in ($cmd -split ',')) {
                $t = $token.Trim()
                if ($t -match '^(\d+)-(\d+)$') {
                    $toggleIndices += ([int]$Matches[1])..([int]$Matches[2])
                } elseif ($t -match '^\d+$') {
                    $toggleIndices += [int]$t
                }
            }

            foreach ($idx in ($toggleIndices | Select-Object -Unique)) {
                if ($idx -ge 1 -and $idx -le $filteredList.Count) {
                    $targetApp = $filteredList[$idx - 1]
                    if ($pickedIds.ContainsKey($targetApp.Id)) {
                        $pickedIds.Remove($targetApp.Id)
                        Write-Log "Deselected: $($targetApp.Name)" -Level WARN
                    } else {
                        $exePath = $targetApp.ExecutablePath
                        if (-not $exePath) {
                            Write-Host "    [!] Registry entry for '$($targetApp.Name)' did not expose a direct .exe path." -ForegroundColor Yellow
                            $exePath = Read-HostWithDefault -Prompt "Provide the full path to '$($targetApp.Name)' .exe (or leave blank to skip)" -DefaultValue ""
                        }
                        if ($exePath) {
                            $customArgs = Read-HostWithDefault -Prompt "Optional CLI arguments for '$($targetApp.Name)' (press Enter for none)" -DefaultValue ""
                            $delayInput = Read-HostWithDefault -Prompt "Launch delay in seconds after previous app" -DefaultValue "2"
                            $winStyle   = Read-HostWithDefault -Prompt "Window Style (Normal / Minimized / Maximized)" -DefaultValue "Normal"
                            if ($winStyle -notin @("Normal", "Minimized", "Maximized", "Hidden")) { $winStyle = "Normal" }

                            $pickedIds[$targetApp.Id] = [Ordered]@{
                                Name           = $targetApp.Name
                                Origin         = "Registry ($($targetApp.Hive))"
                                ExecutablePath = $exePath
                                Arguments      = $customArgs
                                ProcessName    = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                                DelaySeconds   = ([int]($delayInput -as [int]))
                                WindowStyle    = $winStyle
                            }
                            Write-Log "Queued '$($targetApp.Name)' for startup!" -Level OK
                        }
                    }
                }
            }
        }
    }

    foreach ($k in $pickedIds.Keys) {
        $selectedApps += $pickedIds[$k]
    }

    return $selectedApps
}

function Invoke-InteractiveBrowserWizard {
    param([array]$DetectedBrowsers)

    Write-SectionHeader -HexCode "0x03" `
        -Title "PHASE 3: MAIN BROWSER & CHROME TAB GROUP ORCHESTRATOR" `
        -Subtitle "Detecting installed browsers and OS default HTTP handler..."

    for ($i = 0; $i -lt $DetectedBrowsers.Count; $i++) {
        $b = $DetectedBrowsers[$i]
        $defTag   = if ($b.IsDefault) { " [OS DEFAULT]" } else { "" }
        $chromTag = if ($b.Key -eq "Chrome") { " (Supports Native Chrome Tab Groups!)" } elseif ($b.IsChromium) { " (Chromium Engine)" } else { "" }
        Write-Host ("    [{0}] {1,-22}{2}{3}" -f ($i + 1), $b.Name, $defTag, $chromTag) -ForegroundColor Cyan
        Write-Host ("        Path: {0}" -f $b.ExecutablePath) -ForegroundColor DarkGray
    }
    Write-Host ("    [{0}] Custom Browser Path" -f ($DetectedBrowsers.Count + 1)) -ForegroundColor Cyan

    $defaultIdx = 1
    for ($i = 0; $i -lt $DetectedBrowsers.Count; $i++) {
        if ($DetectedBrowsers[$i].IsDefault) { $defaultIdx = $i + 1; break }
    }

    Write-Host ""
    $bChoice = Read-HostWithDefault -Prompt "Which browser is your MAIN startup browser? (Enter number)" -DefaultValue "$defaultIdx"
    $bIndex  = ($bChoice -as [int])

    $chosenBrowser = $null
    if ($bIndex -ge 1 -and $bIndex -le $DetectedBrowsers.Count) {
        $chosenBrowser = $DetectedBrowsers[$bIndex - 1]
    } else {
        $custBName = Read-HostWithDefault -Prompt "Enter Custom Browser Name (e.g. Chrome, Firefox, LibreWolf)" -DefaultValue "Chrome"
        $custBPath = Read-HostWithDefault -Prompt "Enter Full Path to Browser Executable" -DefaultValue "C:\Program Files\Google\Chrome\Application\chrome.exe"
        $isChrome  = ($custBName -match "Chrome" -or $custBPath -match "chrome\.exe")
        $chosenBrowser = [PSCustomObject]@{
            Key            = if ($isChrome) { "Chrome" } else { "Custom" }
            Name           = $custBName
            ExecutablePath = $custBPath
            IsChromium     = $isChrome
            IsDefault      = $true
        }
    }

    Write-Log "Selected Main Browser: $($chosenBrowser.Name) ($($chosenBrowser.ExecutablePath))" -Level OK

    $wantWebsites = Read-HostWithDefault -Prompt "Do you want specific websites automatically opened at startup? (Y/N)" -DefaultValue "Y"
    if ($wantWebsites -notmatch '^[Yy]') {
        return [Ordered]@{
            Enabled        = $false
            BrowserKey     = $chosenBrowser.Key
            BrowserName    = $chosenBrowser.Name
            ExecutablePath = $chosenBrowser.ExecutablePath
            ProfileName    = "Default"
            LaunchMode     = "None"
            TabGroups      = @()
        }
    }

    $profileDir = "Default"
    if ($chosenBrowser.IsChromium) {
        $profileDir = Read-HostWithDefault -Prompt "Chromium Profile Directory (e.g., 'Default', 'Profile 1')" -DefaultValue "Default"
    }

    $launchMode = "SingleWindowTabs"
    $tabGroups  = @()

    if ($chosenBrowser.Key -eq "Chrome") {
        Write-Host ""
        Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Green
        Write-Host "    | [CHROME RANGER DETECTED] — Choose Your Tab & Tab Group Strategy:                 |" -ForegroundColor Green
        Write-Host "    |   [1] Native Colored Chrome Tab Groups (Named & color-coded inside 1 window!)    |" -ForegroundColor Green
        Write-Host "    |   [2] Separate Chrome Windows per Group (Each group opens in its own window)     |" -ForegroundColor Green
        Write-Host "    |   [3] Standard Tabs in a Single Window (All websites open as regular tabs)       |" -ForegroundColor Green
        Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Green

        $modeChoice = Read-HostWithDefault -Prompt "How should Chrome organize your startup websites? (1, 2, or 3)" -DefaultValue "1"
        switch ($modeChoice) {
            "1" { $launchMode = "ChromeNativeTabGroups" }
            "2" { $launchMode = "SeparateWindowsPerGroup" }
            "3" { $launchMode = "SingleWindowTabs" }
            default { $launchMode = "ChromeNativeTabGroups" }
        }
    } else {
        Write-Host ""
        Write-Host "    How should $($chosenBrowser.Name) open your startup websites?" -ForegroundColor Cyan
        Write-Host "      [1] Standard Tabs in a Single Window" -ForegroundColor White
        Write-Host "      [2] Separate Browser Windows per Topic Group" -ForegroundColor White
        $modeChoice = Read-HostWithDefault -Prompt "Select layout mode (1 or 2)" -DefaultValue "1"
        $launchMode = if ($modeChoice -eq "2") { "SeparateWindowsPerGroup" } else { "SingleWindowTabs" }
    }

    if ($launchMode -in @("ChromeNativeTabGroups", "SeparateWindowsPerGroup")) {
        Write-Host ""
        Write-Host "    Let's build your Tab Groups! (Valid Chrome Colors: blue, red, yellow, green, pink, purple, cyan, orange, grey)" -ForegroundColor Cyan
        Write-Host "    Tip: Type 'preset' at the Group Name prompt to load the 90s Hacker Dad / Cyber Professor starter groups!" -ForegroundColor DarkGray

        $addingGroups = $true
        $grpIndex = 1
        while ($addingGroups) {
            Write-Host ""
            $defaultGrpName = if ($grpIndex -eq 1) { "SOC & Threat Intel (or type 'preset')" } else { "" }
            $grpName = Read-HostWithDefault -Prompt "Tab Group #$grpIndex Name (or 'preset' for Hacker Dad defaults, or 'done' to finish)" -DefaultValue $defaultGrpName

            if (-not $grpName -or $grpName.ToLower() -eq "done") {
                break
            }

            if ($grpName.ToLower() -eq "preset") {
                $tabGroups += @(
                    [Ordered]@{
                        GroupName = "SOC & Threat Intel"
                        Color     = "red"
                        Collapsed = $false
                        Urls      = @(
                            "https://gchq.github.io/CyberChef/",
                            "https://www.virustotal.com/gui/home/search",
                            "https://attack.mitre.org/"
                        )
                    },
                    [Ordered]@{
                        GroupName = "Professor Command Deck"
                        Color     = "blue"
                        Collapsed = $false
                        Urls      = @(
                            "https://github.com/popeye1919",
                            "https://scholar.google.com/",
                            "https://so-crates.org/"
                        )
                    },
                    [Ordered]@{
                        GroupName = "90s Hacker Dad Shack"
                        Color     = "green"
                        Collapsed = $true
                        Urls      = @(
                            "https://w4dv.club/repeaters/area-repeaters/",
                            "https://chirpmyradio.com/projects/chirp/wiki/Home",
                            "http://phrack.org/"
                        )
                    }
                )
                Write-Log "Loaded 3 preset 90s Hacker Dad / Cyber Professor Tab Groups!" -Level OK
                break
            }

            if ($grpName -match "\(or type 'preset'\)") {
                $grpName = "SOC & Threat Intel"
            }

            $grpColor = "blue"
            $grpCollapsed = $false
            if ($launchMode -eq "ChromeNativeTabGroups") {
                $grpColor = (Read-HostWithDefault -Prompt "Tab Group Badge Color (blue/red/yellow/green/pink/purple/cyan/orange/grey)" -DefaultValue "blue").ToLower()
                if ($grpColor -notin @("grey", "blue", "red", "yellow", "green", "pink", "purple", "cyan", "orange")) {
                    $grpColor = "blue"
                }
                $colInput = Read-HostWithDefault -Prompt "Start this Tab Group collapsed to save tab-bar space? (Y/N)" -DefaultValue "N"
                $grpCollapsed = ($colInput -match '^[Yy]')
            }

            $rawUrls = Read-HostWithDefault -Prompt "Enter comma-separated URLs for '$grpName'" -DefaultValue "https://github.com/popeye1919, https://gchq.github.io/CyberChef/"
            $parsedUrls = @()
            foreach ($u in ($rawUrls -split ',')) {
                $cleanU = $u.Trim()
                if (-not $cleanU) { continue }
                if ($cleanU -notmatch '^https?://') { $cleanU = "https://$cleanU" }
                $parsedUrls += $cleanU
            }

            if ($parsedUrls.Count -gt 0) {
                $tabGroups += [Ordered]@{
                    GroupName = $grpName
                    Color     = $grpColor
                    Collapsed = $grpCollapsed
                    Urls      = $parsedUrls
                }
                Write-Log "Added Group '$grpName' [$grpColor] with $($parsedUrls.Count) tabs." -Level OK
                $grpIndex++
            }

            $more = Read-HostWithDefault -Prompt "Add another Tab Group? (Y/N)" -DefaultValue "Y"
            if ($more -notmatch '^[Yy]') {
                $addingGroups = $false
            }
        }
    } else {
        Write-Host ""
        $rawUrls = Read-HostWithDefault -Prompt "Enter comma-separated URLs to open in tabs" -DefaultValue "https://github.com/popeye1919, https://gchq.github.io/CyberChef/, https://attack.mitre.org/"
        $parsedUrls = @()
        foreach ($u in ($rawUrls -split ',')) {
            $cleanU = $u.Trim()
            if (-not $cleanU) { continue }
            if ($cleanU -notmatch '^https?://') { $cleanU = "https://$cleanU" }
            $parsedUrls += $cleanU
        }
        $tabGroups += [Ordered]@{
            GroupName = "Primary Startup Tabs"
            Color     = "blue"
            Collapsed = $false
            Urls      = $parsedUrls
        }
    }

    return [Ordered]@{
        Enabled        = $true
        BrowserKey     = $chosenBrowser.Key
        BrowserName    = $chosenBrowser.Name
        ExecutablePath = $chosenBrowser.ExecutablePath
        ProfileName    = $profileDir
        LaunchMode     = $launchMode
        TabGroups      = $tabGroups
    }
}

function Invoke-InteractiveModuleSelection {
    <#
    .SYNOPSIS
        Phase 4 of the Interactive Wizard: Presents all discovered custom PowerShell
        modules (modules\*.psm1), lets the user toggle which ones to activate at startup,
        and calls Set-MorphinModuleConfig on each chosen module!
    #>
    param([array]$DiscoveredModules)

    Write-SectionHeader -HexCode "0x04" `
        -Title "PHASE 4: SUMMON CUSTOM POWERSHELL ZORD MODULES (modules\*.psm1)" `
        -Subtitle "Plug-and-play PowerShell modules discovered in .\modules\ ($($DiscoveredModules.Count) modules available)"

    $enabledModules = @()
    if ($DiscoveredModules.Count -eq 0) {
        Write-Host "    [*] No custom .psm1 modules found in .\modules\." -ForegroundColor DarkGray
        Write-Host "    [*] Tip: Create one anytime with: .\Invoke-MorphinStartup.ps1 -Mode NewModule -ModuleName 'Morphin.MyZord'" -ForegroundColor Cyan
        return $enabledModules
    }

    Write-Host ("    {0,-6} {1,-10} {2,-26} {3,-10} {4}" -f "[#]", "ID", "Module Name", "Ranger", "Zord Description") -ForegroundColor Cyan
    Write-Host ("    " + ("-" * 105)) -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $DiscoveredModules.Count; $i++) {
        $m = $DiscoveredModules[$i]
        Write-Host ("    [{0,2}]   {1,-10} {2,-26} {3,-10} {4}" -f ($i + 1), $m.Id, $m.ModuleName, $m.RangerColor, $m.Description) -ForegroundColor Green
    }

    Write-Host ""
    $modChoice = Read-HostWithDefault -Prompt "Enter module number(s) to enable at startup (e.g. 1,3 or 'all' or 'none')" -DefaultValue "all"
    if (-not $modChoice -or $modChoice.ToLower() -eq "none") {
        return $enabledModules
    }

    $indices = @()
    if ($modChoice.ToLower() -eq "all") {
        $indices = 1..($DiscoveredModules.Count)
    } else {
        foreach ($token in ($modChoice -split ',')) {
            $t = $token.Trim()
            if ($t -match '^(\d+)-(\d+)$') {
                $indices += ([int]$Matches[1])..([int]$Matches[2])
            } elseif ($t -match '^\d+$') {
                $indices += [int]$t
            }
        }
    }

    foreach ($idx in ($indices | Select-Object -Unique)) {
        if ($idx -ge 1 -and $idx -le $DiscoveredModules.Count) {
            $chosenMod = $DiscoveredModules[$idx - 1]
            $modSettings = @{}

            if ($chosenMod.HasConfigHook) {
                Write-Host ""
                $loadedMod = Import-Module -Name $chosenMod.ModulePath -PassThru -Force -DisableNameChecking
                $modSettings = & $loadedMod { Set-MorphinModuleConfig -CurrentSettings @{} }
            }

            $enabledModules += [Ordered]@{
                ModuleName = $chosenMod.ModuleName
                ZordName   = $chosenMod.ZordName
                ModulePath = "modules\$([System.IO.Path]::GetFileName($chosenMod.ModulePath))"
                Enabled    = $true
                Settings   = $modSettings
            }
            Write-Log "Activated Custom Zord Module: $($chosenMod.ModuleName) ($($chosenMod.ZordName))" -Level OK
        }
    }

    return $enabledModules
}

# ==============================================================================
# 0x07 // EXECUTION ENGINE: RUNNING ZORD MODULES, APPS & CHROME TAB GROUPS
# ==============================================================================
function ConvertTo-Hashtable {
    param($InputObject)
    $hash = @{}
    if ($null -eq $InputObject) { return $hash }
    if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary]) {
        return $InputObject
    }
    foreach ($prop in $InputObject.PSObject.Properties) {
        $hash[$prop.Name] = $prop.Value
    }
    return $hash
}

function Invoke-StartupProfileExecution {
    param(
        [Parameter(Mandatory = $true)]$ProfileData,
        [switch]$SimulateOnly
    )

    Write-SectionHeader -HexCode "0x05" `
        -Title "IT'S MORPHIN TIME! // EXECUTING STARTUP COMMAND DECK" `
        -Subtitle "Idempotent Process Guard: ON | Authenticode Check: $VerifySignatures | DryRun: $SimulateOnly"

    # 1. Execute Enabled Custom PowerShell Zord Modules (.psm1)
    $customMods = $ProfileData.CustomModules
    if ($customMods -and $customMods.Count -gt 0) {
        foreach ($mEntry in $customMods) {
            if (-not $mEntry.Enabled) { continue }
            $relOrAbsPath = $mEntry.ModulePath
            $fullModPath  = if ([System.IO.Path]::IsPathRooted($relOrAbsPath)) {
                $relOrAbsPath
            } else {
                Join-Path $ScriptRoot ($relOrAbsPath -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
            }

            Write-Host "----------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
            if (Test-Path $fullModPath) {
                Write-Log "Summoning Custom PowerShell Module: $($mEntry.ModuleName) ($($mEntry.ZordName))" -Level INFO
                $loadedMod = Import-Module -Name $fullModPath -PassThru -Force -DisableNameChecking
                $settingsHash = ConvertTo-Hashtable -InputObject $mEntry.Settings
                & $loadedMod ([scriptblock]{
                    param($s, $d)
                    Invoke-MorphinModule -Settings $s -DryRun:$d
                }) $settingsHash $SimulateOnly
            } else {
                Write-Log "Custom module file not found at '$fullModPath'. Skipping '$($mEntry.ModuleName)'." -Level WARN
            }
        }
    }

    # 2. Launch Selected Desktop Applications
    $apps = $ProfileData.StartupApplications
    if (-not $apps -or $apps.Count -eq 0) {
        Write-Log "No desktop applications configured in profile." -Level INFO
    } else {
        foreach ($app in $apps) {
            $appName  = $app.Name
            $exePath  = $app.ExecutablePath
            $appArgs  = [string]$app.Arguments
            $procName = [string]$app.ProcessName
            $delaySec = if ($null -ne $app.DelaySeconds) { [int]$app.DelaySeconds } else { 2 }
            $winStyle = if ($app.WindowStyle) { [string]$app.WindowStyle } else { "Normal" }

            Write-Host "----------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
            Write-Log "Processing Application: $appName" -Level INFO

            if (-not $SimulateOnly -and $IsWindowsHost) {
                if ($procName) {
                    $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
                    if ($running) {
                        Write-Log "'$appName' ($procName) is ALREADY running (PID: $($running[0].Id)). Skipping duplicate spawn!" -Level OK
                        continue
                    }
                }

                if (-not (Test-Path $exePath)) {
                    Write-Log "Executable not found at '$exePath'. Skipping '$appName'." -Level WARN
                    continue
                }

                if ($VerifySignatures) {
                    $sig = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction SilentlyContinue
                    if (-not $sig -or $sig.Status -ne "Valid") {
                        Write-Log "[SECURITY BLOCK] '$exePath' failed Authenticode signature check (Status: $($sig.Status))!" -Level ERROR
                        continue
                    }
                    Write-Log "Authenticode Signature Verified: $($sig.SignerCertificate.Subject)" -Level OK
                }

                $startParams = @{
                    FilePath    = $exePath
                    WindowStyle = $winStyle
                }
                if ($appArgs) {
                    $startParams["ArgumentList"] = $appArgs
                }

                Start-Process @startParams
                Write-Log "Launched '$appName' -> $exePath $appArgs" -Level OK
                if ($delaySec -gt 0) {
                    Start-Sleep -Seconds $delaySec
                }
            } else {
                Write-Log "[DRY-RUN / DEMO] Would launch: `"$exePath`" $appArgs (WindowStyle: $winStyle, Delay: ${delaySec}s)" -Level OK
            }
        }
    }

    # 3. Launch Main Browser & Chrome Tab Groups
    $browserCfg = $ProfileData.BrowserConfiguration
    if ($browserCfg -and $browserCfg.Enabled) {
        Write-Host "----------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Log "Orchestrating Main Browser: $($browserCfg.BrowserName) (Mode: $($browserCfg.LaunchMode))" -Level INFO

        $bExe    = $browserCfg.ExecutablePath
        $bKey    = $browserCfg.BrowserKey
        $profile = if ($browserCfg.ProfileName) { $browserCfg.ProfileName } else { "Default" }
        $groups  = $browserCfg.TabGroups

        switch ($browserCfg.LaunchMode) {
            "ChromeNativeTabGroups" {
                $extPath = Build-ChromeTabGroupExtension -TabGroups $groups -OutputDirectory $ExtDir
                Write-Log "Synthesized Chrome Manifest V3 Tab Group Zord Extension at: $extPath" -Level OK

                foreach ($g in $groups) {
                    Write-Host ("    -> Tab Group [{0,-6}] '{1}' ({2} tabs): {3}" -f $g.Color.ToUpper(), $g.GroupName, $g.Urls.Count, ($g.Urls -join ', ')) -ForegroundColor Cyan
                }

                $chromeArgs = @(
                    "--profile-directory=`"$profile`"",
                    "--load-extension=`"$extPath`"",
                    "--new-window"
                )

                if (-not $SimulateOnly -and $IsWindowsHost -and (Test-Path $bExe)) {
                    Start-Process -FilePath $bExe -ArgumentList ($chromeArgs -join ' ')
                    Write-Log "Launched Google Chrome with Native Tab Groups!" -Level OK
                } else {
                    Write-Log "[DRY-RUN / DEMO] Would execute: `"$bExe`" $($chromeArgs -join ' ')" -Level OK
                }
            }

            "SeparateWindowsPerGroup" {
                foreach ($g in $groups) {
                    if (-not $g.Urls -or $g.Urls.Count -eq 0) { continue }
                    $winArgs = @()
                    if ($bKey -in @("Chrome", "Edge", "Brave", "Vivaldi")) {
                        $winArgs += "--profile-directory=`"$profile`""
                        $winArgs += "--new-window"
                    } elseif ($bKey -eq "Firefox") {
                        $winArgs += "-new-window"
                    }
                    foreach ($u in $g.Urls) {
                        $winArgs += "`"$u`""
                    }

                    Write-Host ("    -> Window Group '{0}' ({1} tabs): {2}" -f $g.GroupName, $g.Urls.Count, ($g.Urls -join ', ')) -ForegroundColor Cyan
                    if (-not $SimulateOnly -and $IsWindowsHost -and (Test-Path $bExe)) {
                        Start-Process -FilePath $bExe -ArgumentList ($winArgs -join ' ')
                        Start-Sleep -Seconds 1
                    } else {
                        Write-Log "[DRY-RUN / DEMO] Would execute: `"$bExe`" $($winArgs -join ' ')" -Level OK
                    }
                }
            }

            default {
                $allUrls = @()
                foreach ($g in $groups) {
                    if ($g.Urls) { $allUrls += $g.Urls }
                }
                if ($allUrls.Count -gt 0) {
                    $tabArgs = @()
                    if ($bKey -in @("Chrome", "Edge", "Brave", "Vivaldi")) {
                        $tabArgs += "--profile-directory=`"$profile`""
                        $tabArgs += "--new-window"
                    }
                    foreach ($u in $allUrls) {
                        $tabArgs += "`"$u`""
                    }
                    if (-not $SimulateOnly -and $IsWindowsHost -and (Test-Path $bExe)) {
                        Start-Process -FilePath $bExe -ArgumentList ($tabArgs -join ' ')
                        Write-Log "Launched $($browserCfg.BrowserName) with $($allUrls.Count) tabs." -Level OK
                    } else {
                        Write-Log "[DRY-RUN / DEMO] Would execute: `"$bExe`" $($tabArgs -join ' ')" -Level OK
                    }
                }
            }
        }
    }

    Write-Host ""
    Write-Log "Megazord Sequence Complete! Grab your dad mug and hack the planet." -Level OK
}

# ==============================================================================
# 0x08 // PERSISTENCE & STARTUP REGISTRATION (PURE POWERSHELL)
# ==============================================================================
function Save-StartupProfile {
    param(
        [Parameter(Mandatory = $true)]$ProfileObject,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (Test-Path $DestinationPath) {
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $bakFile = Join-Path $BackupDir "startup-profile_backup_$ts.json"
        Copy-Item -Path $DestinationPath -Destination $bakFile -Force
        Write-Log "Backed up previous startup profile to: $bakFile" -Level INFO
    }

    $ProfileObject | ConvertTo-Json -Depth 8 | Set-Content -Path $DestinationPath -Encoding UTF8
    $hash = (Get-FileHash -Path $DestinationPath -Algorithm SHA256).Hash.ToLower()
    Write-Log "Saved startup profile to: $DestinationPath (SHA-256: $hash)" -Level OK
}

function Register-StartupLauncher {
    param([string]$ProfileFilePath)

    if (-not $IsWindowsHost) {
        Write-Log "[DEMO / NON-WINDOWS] On Windows, this creates 'MightyMorphinStartup.lnk' inside shell:startup invoking PowerShell directly." -Level INFO
        return
    }

    $userStartupDir = [Environment]::GetFolderPath('Startup')
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $startupSnapDir = Join-Path $BackupDir "shell_startup_snapshot_$ts"
    New-Item -ItemType Directory -Path $startupSnapDir -Force | Out-Null

    Get-ChildItem -Path $userStartupDir -File -ErrorAction SilentlyContinue |
        Copy-Item -Destination $startupSnapDir -Force -ErrorAction SilentlyContinue
    Write-Log "Pre-change snapshot of shell:startup saved to: $startupSnapDir" -Level OK

    $pwshExe = if (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    $lnkPath = Join-Path $userStartupDir "MightyMorphinStartup.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $sc  = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath       = $pwshExe
    $sc.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Run -ConfigPath `"$ProfileFilePath`""
    $sc.WorkingDirectory = $ScriptRoot
    $sc.Description      = "Mighty Morphin Windows Rangers // Pure PowerShell Startup & Chrome Tab Group Orchestrator"
    $sc.Save()

    Write-Log "Registered pure-PowerShell Startup shortcut: $lnkPath" -Level OK
}

# ==============================================================================
# 0x09 // PURE POWERSHELL INTERACTIVE COMMAND CENTER MENU & DISPATCH
# ==============================================================================
function Invoke-WizardFlow {
    param([switch]$DemoMode)

    $startupItems  = Get-StartupFolderItems -DemoMode:$DemoMode
    $registryItems = Get-InstalledRegistryApplications -DemoMode:$DemoMode
    $browsers      = Get-InstalledBrowsers -DemoMode:$DemoMode
    $customMods    = Get-MorphinCustomModules

    $chosenApps    = Invoke-InteractiveAppSelection -StartupItems $startupItems -RegistryItems $registryItems -UseGuiPicker:$UseGridView
    $browserConfig = Invoke-InteractiveBrowserWizard -DetectedBrowsers $browsers
    $enabledMods   = Invoke-InteractiveModuleSelection -DiscoveredModules $customMods

    $fullProfile = [Ordered]@{
        SchemaVersion        = "1.0.0"
        Author               = "Mighty Morphin Windows Rangers // Invoke-MorphinStartup.ps1"
        UpdatedAtUtc         = (Get-Date).ToUniversalTime().ToString("o")
        VerifyAuthenticode   = [bool]$VerifySignatures
        CustomModules        = $enabledMods
        StartupApplications  = $chosenApps
        BrowserConfiguration = $browserConfig
    }

    Write-SectionHeader -HexCode "0x06" -Title "PHASE 5: SAVE PROFILE, TEST DRIVE & AUTO-START REGISTRATION"
    Save-StartupProfile -ProfileObject $fullProfile -DestinationPath $ConfigPath

    $testNow = Read-HostWithDefault -Prompt "Would you like to test-run your new startup configuration right now? (Y/N)" -DefaultValue "Y"
    if ($testNow -match '^[Yy]') {
        $loadedProfile = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        Invoke-StartupProfileExecution -ProfileData $loadedProfile -SimulateOnly:($DryRun -or $DemoMode)
    }

    $installAuto = Read-HostWithDefault -Prompt "Register Invoke-MorphinStartup.ps1 into your Windows Startup Folder (shell:startup) so it runs automatically at login? (Y/N)" -DefaultValue "N"
    if ($installAuto -match '^[Yy]') {
        Register-StartupLauncher -ProfileFilePath $ConfigPath
    }

    Write-Host ""
    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "    | [MEGAZORD ONLINE] Your custom startup profile is locked in at:                   |" -ForegroundColor Cyan
    Write-Host "    |   $ConfigPath" -ForegroundColor Green
    Write-Host "    | Run anytime with: .\Invoke-MorphinStartup.ps1 -Mode Run                          |" -ForegroundColor Cyan
    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Cyan
}

Write-MorphinBanner

$useDemo = ($Mode -eq "Demo") -or (-not $IsWindowsHost)
if (-not $IsWindowsHost -and $Mode -in @("Menu", "Wizard", "Audit")) {
    Write-Log "Non-Windows OS detected ($($PSVersionTable.OS)). Engaging simulated Windows Registry & shell:startup data so you can test drive the full experience!" -Level WARN
}

switch ($Mode) {
    "ListModules" {
        $mods = Get-MorphinCustomModules
        Write-SectionHeader -HexCode "ZORDS" -Title "DISCOVERED CUSTOM POWERSHELL ZORD MODULES ($($mods.Count) modules in .\modules\)"
        $mods | Format-Table -AutoSize Id, ModuleName, RangerColor, Version, Author, Description
    }

    "NewModule" {
        if (-not $ModuleName) {
            $ModuleName = Read-HostWithDefault -Prompt "Enter a name for your new custom PowerShell module (e.g. Morphin.MyCustomZord)" -DefaultValue "Morphin.CustomZord"
        }
        $createdPath = New-MorphinModuleTemplate -TargetName $ModuleName
        Write-Host ""
        Write-Host "    [+] Next Step: Open '$createdPath' in VS Code, add your custom PowerShell commands inside" -ForegroundColor Green
        Write-Host "        Invoke-MorphinModule, and run '.\Invoke-MorphinStartup.ps1 -Mode Wizard'!" -ForegroundColor Green
    }

    "Audit" {
        $startupItems  = Get-StartupFolderItems -DemoMode:$useDemo
        $registryItems = Get-InstalledRegistryApplications -DemoMode:$useDemo
        $browsers      = Get-InstalledBrowsers -DemoMode:$useDemo
        $mods          = Get-MorphinCustomModules

        Write-SectionHeader -HexCode "AUDIT-1" -Title "CURRENT STARTUP FOLDERS & REGISTRY RUN KEYS ($($startupItems.Count) items)"
        $startupItems | Format-Table -AutoSize Id, Name, Source, ExecutablePath, Arguments

        Write-SectionHeader -HexCode "AUDIT-2" -Title "INSTALLED APPLICATIONS VIA REGISTRY UNINSTALL HIVES ($($registryItems.Count) apps)"
        $registryItems | Select-Object -First 40 | Format-Table -AutoSize Id, Name, Version, Publisher, Hive, ExecutablePath

        Write-SectionHeader -HexCode "AUDIT-3" -Title "DETECTED WEB BROWSERS ($($browsers.Count) browsers)"
        $browsers | Format-Table -AutoSize Key, Name, IsDefault, IsChromium, ExecutablePath

        Write-SectionHeader -HexCode "AUDIT-4" -Title "CUSTOM POWERSHELL ZORD MODULES ($($mods.Count) modules in .\modules\)"
        $mods | Format-Table -AutoSize Id, ModuleName, RangerColor, Version, Description
    }

    "ExportAudit" {
        $startupItems  = Get-StartupFolderItems -DemoMode:$useDemo
        $registryItems = Get-InstalledRegistryApplications -DemoMode:$useDemo
        $browsers      = Get-InstalledBrowsers -DemoMode:$useDemo
        $mods          = Get-MorphinCustomModules

        $reportPath = Join-Path $LogDir ("morphin_forensic_audit_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
        $payload = [Ordered]@{
            generated_at_utc   = (Get-Date).ToUniversalTime().ToString("o")
            host_name          = [Environment]::MachineName
            custom_modules     = $mods
            startup_items      = $startupItems
            installed_programs = $registryItems
            detected_browsers  = $browsers
        }
        $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
        Write-Log "Exported full startup, registry & module forensic audit to: $reportPath" -Level OK
    }

    "Run" {
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "No startup profile found at '$ConfigPath'. Launching Interactive Setup Wizard first..." -Level WARN
            Invoke-WizardFlow -DemoMode:$useDemo
            exit 0
        }
        $profileData = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        Invoke-StartupProfileExecution -ProfileData $profileData -SimulateOnly:($DryRun -or $useDemo)
    }

    "Install" {
        if (-not (Test-Path $ConfigPath)) {
            throw "Startup profile not found at '$ConfigPath'. Run '.\Invoke-MorphinStartup.ps1 -Mode Wizard' first."
        }
        Register-StartupLauncher -ProfileFilePath $ConfigPath
    }

    "Menu" {
        Write-Host ""
        Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Cyan
        Write-Host "    | [COMMAND CENTER MENU] Choose Your Mighty Morphin PowerShell Action:              |" -ForegroundColor Cyan
        Write-Host "    |   [1] INTERACTIVE WIZARD (Console TUI) : Pick Apps, Chrome Tab Groups & Modules  |" -ForegroundColor White
        Write-Host "    |   [2] INTERACTIVE WIZARD (Out-GridView): Pick Registry Apps via Windows GUI      |" -ForegroundColor White
        Write-Host "    |   [3] EXECUTE STARTUP PROFILE NOW      : Run Saved Modules, Apps & Tab Groups    |" -ForegroundColor Green
        Write-Host "    |   [4] FORENSIC AUDIT                   : Inspect shell:startup, Registry & Zords |" -ForegroundColor White
        Write-Host "    |   [5] CREATE NEW CUSTOM .PSM1 MODULE   : Scaffold a Custom PowerShell Zord Module|" -ForegroundColor Yellow
        Write-Host "    |   [6] INSTALL TO WINDOWS STARTUP       : Register in shell:startup (+Backup)     |" -ForegroundColor White
        Write-Host "    |   [Q] QUIT COMMAND CENTER                                                        |" -ForegroundColor DarkGray
        Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Cyan

        $choice = Read-HostWithDefault -Prompt "Select Option (1-6 or Q)" -DefaultValue "1"
        switch ($choice.ToUpper()) {
            "1" { Invoke-WizardFlow -DemoMode:$useDemo }
            "2" { $UseGridView = $true; Invoke-WizardFlow -DemoMode:$useDemo }
            "3" { & $PSCommandPath -Mode Run -ConfigPath $ConfigPath -DryRun:$DryRun -NoBanner }
            "4" { & $PSCommandPath -Mode Audit -NoBanner }
            "5" { & $PSCommandPath -Mode NewModule -NoBanner }
            "6" { & $PSCommandPath -Mode Install -ConfigPath $ConfigPath -NoBanner }
            default { Write-Log "May the Power protect you! // EOF 0xFF" -Level OK }
        }
    }

    default {
        # Wizard or Demo mode
        Invoke-WizardFlow -DemoMode:$useDemo
    }
}

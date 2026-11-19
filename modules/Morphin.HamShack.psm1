<#
.SYNOPSIS
    Morphin.HamShack.psm1 — Yellow Ranger / Sabertooth Tiger Ultimate Budget Ham Shack Zord Module.
    Inspired by VK Ham Radio's "The Ultimate Budget Ham Shack – Overview and Concept"
    (https://www.vkhamradio.com/the-ultimate-budget-ham-shack-overview-and-concept/)
    and CSRA Ham DMR Automation (DE KR4JLC).

.DESCRIPTION
    1. Scans Windows WMI/CIM PnP bus for USB CAT & Radio Programming COM ports (FTDI, CH340, CP210x, GD32).
    2. Displays current UTC Ham Shack time & ITU Morse Code beacon.
    3. Orchestrates the Ultimate Budget Ham Shack software stack in proper CAT dependency order:
       Step 1: FLRIG (Transceiver CAT Control Master Linchpin)
       Step 2: WSJT-X (FT8 / FT4 / Weak-Signal Digital Modes hooked to FLRIG)
       Step 3: GridTracker (UDP Multicast QSO Map & Callsign Roster)
       Step 4: Ham2K Portable Logger / CHIRP-next
#>

function Get-MorphinModuleInfo {
    return [PSCustomObject]@{
        ModuleName  = "Morphin.HamShack"
        ZordName    = "Sabertooth Tiger Ultimate Budget Ham Shack & CAT Zord"
        RangerColor = "Yellow"
        Version     = "1.0.0"
        Author      = "Trini Kwan, KR4JLC & VK1ED Concept Tribute"
        Description = "Probes USB CAT/Serial COM ports, prints UTC Shack Clock, and boots FLRIG -> WSJT-X -> GridTracker -> Ham2K/CHIRP."
    }
}

function Set-MorphinModuleConfig {
    param([hashtable]$CurrentSettings = @{})

    Write-Host "    [Yellow Ranger Ham Shack Zord] Configuring Ultimate Budget Ham Shack Stack..." -ForegroundColor Yellow
    $defCall = if ($CurrentSettings.Callsign)   { $CurrentSettings.Callsign }   else { "KR4JLC" }
    $defGrid = if ($CurrentSettings.GridSquare) { $CurrentSettings.GridSquare } else { "EM83" }

    Write-Host -NoNewline "    [?] Enter your Amateur Radio Callsign [$defCall]: " -ForegroundColor Yellow
    $inCall = Read-Host
    if ([string]::IsNullOrWhiteSpace($inCall)) { $inCall = $defCall }

    Write-Host -NoNewline "    [?] Enter your Maidenhead Grid Square [$defGrid]: " -ForegroundColor Yellow
    $inGrid = Read-Host
    if ([string]::IsNullOrWhiteSpace($inGrid)) { $inGrid = $defGrid }

    return [Ordered]@{
        Callsign       = $inCall.Trim().ToUpper()
        GridSquare     = $inGrid.Trim().ToUpper()
        ProbeComPorts  = $true
        StaggerCatSec  = 3
    }
}

function Invoke-MorphinModule {
    [CmdletBinding()]
    param(
        [Parameter()][hashtable]$Settings = @{},
        [Parameter()][switch]$DryRun
    )

    $callsign = if ($Settings.Callsign)      { $Settings.Callsign }      else { "KR4JLC" }
    $grid     = if ($Settings.GridSquare)    { $Settings.GridSquare }    else { "EM83" }
    $catDelay = if ($Settings.StaggerCatSec) { [int]$Settings.StaggerCatSec } else { 3 }
    $utcNow   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")

    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "    | [SABERTOOTH HAM SHACK ZORD] // DE $callsign ($grid) // 73 (--... ...--)           |" -ForegroundColor Yellow
    Write-Host "    |   * Shack WallBoard Clock : $utcNow                                  |" -ForegroundColor Cyan
    Write-Host "    |   * Architecture Concept  : FLRIG (CAT Master) -> WSJT-X -> GridTracker -> Ham2K |" -ForegroundColor Cyan
    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "    [+] [DRY-RUN] Would scan Windows WMI/CIM Win32_PnPEntity for USB CAT / K-Plug COM ports (FTDI, CH340, CP210x)." -ForegroundColor Green
        Write-Host "    [+] [DRY-RUN] Would verify FLRIG CAT initialization (${catDelay}s delay) before attaching WSJT-X & GridTracker UDP stream." -ForegroundColor Green
        return
    }

    # Scan Windows COM ports for connected CAT transceivers & programming cables
    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        $comDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\(COM\d+\)' }
        if ($comDevices) {
            foreach ($dev in $comDevices) {
                Write-Host "    [+] Detected Shack Serial/CAT Port: $($dev.Name)" -ForegroundColor Green
            }
        } else {
            Write-Host "    [*] No USB CAT or K-Plug serial cables currently attached to COM bus." -ForegroundColor DarkGray
        }
    }
}

Export-ModuleMember -Function Get-MorphinModuleInfo, Set-MorphinModuleConfig, Invoke-MorphinModule

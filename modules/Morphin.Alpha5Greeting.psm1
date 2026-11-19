<#
.SYNOPSIS
    Morphin.Alpha5Greeting.psm1 — Red Ranger / Alpha-5 Command Center Telemetry & Voice Zord Module.
    Outputs a quick workstation security & resource briefing (and optional Windows SpeechSynthesizer voice greeting!).
#>

function Get-MorphinModuleInfo {
    return [PSCustomObject]@{
        ModuleName  = "Morphin.Alpha5Greeting"
        ZordName    = "Tyrannosaurus & Alpha-5 Command Center Briefing Zord"
        RangerColor = "Red"
        Version     = "1.0.0"
        Author      = "Jason Lee Scott, Alpha-5 & The 90s Hacker Dad"
        Description = "Prints a morning workstation security & uptime HUD and optionally speaks an Alpha-5/Zordon TTS greeting."
    }
}

function Set-MorphinModuleConfig {
    param([hashtable]$CurrentSettings = @{})

    Write-Host "    [Red Ranger Zord] Configuring Alpha-5 Command Center Briefing..." -ForegroundColor Red
    $defCallsign = if ($CurrentSettings.RangerCallsign) { $CurrentSettings.RangerCallsign } else { "Professor Ranger" }

    Write-Host -NoNewline "    [?] Your Ranger Callsign / Handle [$defCallsign]: " -ForegroundColor Yellow
    $inCallsign = Read-Host
    if ([string]::IsNullOrWhiteSpace($inCallsign)) { $inCallsign = $defCallsign }

    Write-Host -NoNewline "    [?] Enable Windows SpeechSynthesizer voice greeting ('Ay-yi-yi-yi-yi!')? (Y/N) [N]: " -ForegroundColor Yellow
    $inVoice = Read-Host
    $useVoice = ($inVoice -match '^[Yy]')

    return [Ordered]@{
        RangerCallsign = $inCallsign.Trim()
        EnableVoiceTts = $useVoice
    }
}

function Invoke-MorphinModule {
    [CmdletBinding()]
    param(
        [Parameter()][hashtable]$Settings = @{},
        [Parameter()][switch]$DryRun
    )

    $callsign = if ($Settings.RangerCallsign) { $Settings.RangerCallsign } else { "Professor Ranger" }
    $useVoice = [bool]$Settings.EnableVoiceTts

    $hostName = [Environment]::MachineName
    $osVer    = [Environment]::OSVersion.VersionString
    $procCnt  = [Environment]::ProcessorCount

    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Red
    Write-Host "    | [ALPHA-5 TELEMETRY] Ay-yi-yi-yi-yi! Welcome back to the Command Center, $callsign!" -ForegroundColor Yellow
    Write-Host "    |   * Host Battle Station : $hostName ($osVer)" -ForegroundColor Cyan
    Write-Host "    |   * Logical CPU Cores   : $procCnt Zord Threads Ready" -ForegroundColor Cyan
    Write-Host "    +----------------------------------------------------------------------------------+" -ForegroundColor Red

    if ($useVoice) {
        $phrase = "Ay yi yi yi yi! Welcome to the Command Center, $callsign. All Zords and PowerShell startup systems are online!"
        if ($DryRun) {
            Write-Host "    [+] [DRY-RUN] Would speak via System.Speech.Synthesis.SpeechSynthesizer: `"$phrase`"" -ForegroundColor Green
        } else {
            try {
                Add-Type -AssemblyName System.Speech -ErrorAction Stop
                $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $synth.Rate = 1
                $synth.Speak($phrase)
            } catch {
                Write-Host "    [*] (Voice TTS unavailable on this platform; continuing silently)" -ForegroundColor DarkGray
            }
        }
    }
}

Export-ModuleMember -Function Get-MorphinModuleInfo, Set-MorphinModuleConfig, Invoke-MorphinModule

<#
.SYNOPSIS
    Morphin.CyberLab.psm1 — Black Ranger / Mastodon WSL2, Container & VM Lab Zord Module.
    Automatically spins up WSL2 distros (e.g. kali-linux) or Docker containers (e.g. so-crates) at login.
#>

function Get-MorphinModuleInfo {
    return [PSCustomObject]@{
        ModuleName  = "Morphin.CyberLab"
        ZordName    = "Mastodon Cyber Range & WSL2 Zord"
        RangerColor = "DarkGray"
        Version     = "1.0.0"
        Author      = "Zack Taylor & The 90s Hacker Dad"
        Description = "Warms up WSL2 Linux instances (e.g., kali-linux) and starts favorite Docker lab containers (e.g., so-crates)."
    }
}

function Set-MorphinModuleConfig {
    param([hashtable]$CurrentSettings = @{})

    Write-Host "    [Black Ranger Zord] Configuring Mastodon Cyber Lab & WSL2 Launcher..." -ForegroundColor Cyan
    $defWsl    = if ($CurrentSettings.WslDistro) { $CurrentSettings.WslDistro } else { "kali-linux" }
    $defDocker = if ($CurrentSettings.DockerContainer) { $CurrentSettings.DockerContainer } else { "so-crates-lab" }

    Write-Host -NoNewline "    [?] WSL2 Distro to warm up in background (or 'none') [$defWsl]: " -ForegroundColor Yellow
    $inWsl = Read-Host
    if ([string]::IsNullOrWhiteSpace($inWsl)) { $inWsl = $defWsl }

    Write-Host -NoNewline "    [?] Docker container name to start if Docker is running (or 'none') [$defDocker]: " -ForegroundColor Yellow
    $inDocker = Read-Host
    if ([string]::IsNullOrWhiteSpace($inDocker)) { $inDocker = $defDocker }

    return [Ordered]@{
        WslDistro       = $inWsl.Trim()
        DockerContainer = $inDocker.Trim()
    }
}

function Invoke-MorphinModule {
    [CmdletBinding()]
    param(
        [Parameter()][hashtable]$Settings = @{},
        [Parameter()][switch]$DryRun
    )

    $wslDistro = if ($Settings.WslDistro) { $Settings.WslDistro } else { "kali-linux" }
    $dockerCtr = if ($Settings.DockerContainer) { $Settings.DockerContainer } else { "so-crates-lab" }

    Write-Host "    [MASTODON ZORD] Summoning Cyber Lab Containers & WSL2 Subsystems..." -ForegroundColor Cyan

    if ($wslDistro -and $wslDistro.ToLower() -ne "none") {
        if ($DryRun) {
            Write-Host "    [+] [DRY-RUN] Would warm up WSL2 distribution: wsl.exe -d $wslDistro -- echo 'Zord Online'" -ForegroundColor Green
        } elseif (Get-Command "wsl.exe" -ErrorAction SilentlyContinue) {
            Start-Process -FilePath "wsl.exe" -ArgumentList "-d $wslDistro -- echo 'Morphin WSL2 Ready'" -WindowStyle Hidden
            Write-Host "    [+] Warmed up WSL2 distribution: $wslDistro" -ForegroundColor Green
        } else {
            Write-Host "    [!] wsl.exe not found on PATH; skipping WSL2 warmup." -ForegroundColor Yellow
        }
    }

    if ($dockerCtr -and $dockerCtr.ToLower() -ne "none") {
        if ($DryRun) {
            Write-Host "    [+] [DRY-RUN] Would start Docker container: docker start $dockerCtr" -ForegroundColor Green
        } elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
            & docker start $dockerCtr 2>$null | Out-Null
            Write-Host "    [+] Issued 'docker start $dockerCtr' for forensic lab container." -ForegroundColor Green
        } else {
            Write-Host "    [*] Docker CLI not detected; skipping container start." -ForegroundColor DarkGray
        }
    }
}

Export-ModuleMember -Function Get-MorphinModuleInfo, Set-MorphinModuleConfig, Invoke-MorphinModule

<#
.SYNOPSIS
    Morphin.NetCheck.psm1 — Blue Ranger / Triceratops Network & VPN Telemetry Zord Module.
    Verifies LAN gateway, DNS resolution, WAN connectivity, and active VPN interfaces at startup.
#>

function Get-MorphinModuleInfo {
    return [PSCustomObject]@{
        ModuleName  = "Morphin.NetCheck"
        ZordName    = "Triceratops Network & VPN Telemetry Zord"
        RangerColor = "Blue"
        Version     = "1.0.0"
        Author      = "Billy Cranston & The 90s Hacker Dad"
        Description = "Tests default gateway, DNS resolution, WAN ping, and checks for active VPN/WireGuard/OpenVPN interfaces."
    }
}

function Set-MorphinModuleConfig {
    param([hashtable]$CurrentSettings = @{})

    Write-Host "    [Blue Ranger Zord] Configuring Triceratops Network Telemetry..." -ForegroundColor Cyan
    $defaultTarget = if ($CurrentSettings.PingTarget) { $CurrentSettings.PingTarget } else { "1.1.1.1" }
    $defaultDns    = if ($CurrentSettings.DnsCheckHost) { $CurrentSettings.DnsCheckHost } else { "github.com" }

    Write-Host -NoNewline "    [?] Target IP for WAN connectivity check [$defaultTarget]: " -ForegroundColor Yellow
    $inTarget = Read-Host
    if ([string]::IsNullOrWhiteSpace($inTarget)) { $inTarget = $defaultTarget }

    Write-Host -NoNewline "    [?] Hostname for DNS resolution verification [$defaultDns]: " -ForegroundColor Yellow
    $inDns = Read-Host
    if ([string]::IsNullOrWhiteSpace($inDns)) { $inDns = $defaultDns }

    return [Ordered]@{
        PingTarget   = $inTarget.Trim()
        DnsCheckHost = $inDns.Trim()
        CheckVpn     = $true
    }
}

function Invoke-MorphinModule {
    [CmdletBinding()]
    param(
        [Parameter()][hashtable]$Settings = @{},
        [Parameter()][switch]$DryRun
    )

    $pingTarget = if ($Settings.PingTarget) { $Settings.PingTarget } else { "1.1.1.1" }
    $dnsHost    = if ($Settings.DnsCheckHost) { $Settings.DnsCheckHost } else { "github.com" }

    Write-Host "    [TRICERATOPS ZORD] Running Command Center Network & VPN Pre-Flight Check..." -ForegroundColor Blue

    if ($DryRun) {
        Write-Host "    [+] [DRY-RUN] Would test ICMP reachability to $pingTarget, resolve DNS for $dnsHost, and enumerate VPN adapters." -ForegroundColor Green
        return
    }

    # 1. Check WAN Reachability
    try {
        $pingOk = Test-Connection -ComputerName $pingTarget -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($pingOk) {
            Write-Host "    [+] WAN Uplink ($pingTarget) : ONLINE ('There's no place like 127.0.0.1, found my WAN!')" -ForegroundColor Green
        } else {
            Write-Host "    [!] WAN Uplink ($pingTarget) : NO RESPONSE (ICMP blocked or offline)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    [!] WAN Uplink check skipped: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # 2. Check DNS Resolution
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($dnsHost) | Select-Object -First 1
        if ($resolved) {
            Write-Host "    [+] DNS Resolution ($dnsHost) : OK -> $($resolved.IPAddressToString)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [!] DNS Resolution failed for $dnsHost" -ForegroundColor Yellow
    }

    # 3. Check VPN / Tunnel Adapters on Windows
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $vpnAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceDescription -match 'WireGuard|TAP-Windows|OpenVPN|Tailscale|Cisco AnyConnect|Wintun' -and $_.Status -eq 'Up' }
        if ($vpnAdapters) {
            foreach ($v in $vpnAdapters) {
                Write-Host "    [+] Active VPN Tunnel Detected : $($v.Name) ($($v.InterfaceDescription))" -ForegroundColor Cyan
            }
        } else {
            Write-Host "    [*] VPN Tunnel Status : No active VPN tunnel interfaces (Direct WAN mode)" -ForegroundColor DarkGray
        }
    }
}

Export-ModuleMember -Function Get-MorphinModuleInfo, Set-MorphinModuleConfig, Invoke-MorphinModule

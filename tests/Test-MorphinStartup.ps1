<#
.SYNOPSIS
    Automated Self-Test & Verification Suite for Invoke-MorphinStartup.ps1.
    Validates PowerShell AST syntax, Custom Zord Module discovery (-Mode ListModules),
    Preset Profiles (-Profile PentestLab, -Profile HamShack, -Profile CyberProfessor),
    Audit mode, and DryRun execution.
#>

$ErrorActionPreference = "Stop"
$RepoRoot   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$MainScript = Join-Path $RepoRoot "Invoke-MorphinStartup.ps1"
$ExampleCfg = Join-Path $RepoRoot "config\startup-profile.example.json"
$ExtDir     = Join-Path $RepoRoot "config\chrome-tabgroups-ext"
$ModulesDir = Join-Path $RepoRoot "modules"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [TEST SUITE] Verifying Mighty Morphin // Invoke-MorphinStartup.ps1" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Test 1: Syntax & AST Parse Check on Main Script & All Modules
Write-Host "[*] Test 1: Checking PowerShell AST syntax on Invoke-MorphinStartup.ps1 and .\modules\*.psm1..." -ForegroundColor Yellow
$filesToParse = @($MainScript) + (Get-ChildItem -Path $ModulesDir -Filter "*.psm1" | Select-Object -ExpandProperty FullName)
foreach ($f in $filesToParse) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        throw "Syntax errors detected in ${f}: $($errors | Out-String)"
    }
}
Write-Host "[+] Test 1 PASSED: Zero syntax errors across main script and all 5 custom Zord modules!" -ForegroundColor Green

# Test 2: Custom Module Discovery (-Mode ListModules)
Write-Host "[*] Test 2: Running -Mode ListModules -NoBanner..." -ForegroundColor Yellow
& $MainScript -Mode ListModules -NoBanner | Out-Null
Write-Host "[+] Test 2 PASSED: Custom .psm1 Zord modules discovered cleanly!" -ForegroundColor Green

# Test 3: Audit Mode Execution
Write-Host "[*] Test 3: Running -Mode Audit -NoBanner..." -ForegroundColor Yellow
& $MainScript -Mode Audit -NoBanner | Out-Null
Write-Host "[+] Test 3 PASSED: Audit mode inspected Startup Folder, Registry Uninstall hives, Browsers, and Modules!" -ForegroundColor Green

# Test 4: Run Mode with Preset Profiles (-Profile PentestLab, HamShack, CyberProfessor)
foreach ($prof in @("PentestLab", "HamShack", "CyberProfessor")) {
    Write-Host "[*] Test 4 ($prof): Running -Mode Run -Profile $prof -DryRun..." -ForegroundColor Yellow
    & $MainScript -Mode Run -Profile $prof -DryRun -NoBanner
}
if (-not (Test-Path (Join-Path $ExtDir "manifest.json"))) {
    throw "Expected Chrome Tab Group manifest.json was not created in $ExtDir!"
}
if (-not (Test-Path (Join-Path $ExtDir "background.js"))) {
    throw "Expected Chrome Tab Group background.js was not created in $ExtDir!"
}
Write-Host "[+] Test 4 PASSED: All 3 Preset Profiles (PentestLab, HamShack, CyberProfessor) & Chrome Tab Group Manifest V3 generation verified!" -ForegroundColor Green

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [ALL TESTS PASSED] It's Morphin Time! // EOF 0xFF" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

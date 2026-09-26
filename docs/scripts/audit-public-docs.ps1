# ==============================================================================
# AUDIT PUBLIC DOCS - LEAKAGE PREVENTION SCANNER
# Scans docs/public-wiki/ to guarantee zero internal SuamiSihat references exist.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
        $ScriptDir = "$PSScriptRoot"
    }
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
        $ScriptDir = ".\docs\scripts"
    }
    $TargetDir = Join-Path $ScriptDir "..\public-wiki"
}

$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "CAM Studio Public Documentation Leakage Scanner" -ForegroundColor Cyan
Write-Host "Target: $TargetDir" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not (Test-Path $TargetDir)) {
    Write-Error "Target directory does not exist: $TargetDir"
    exit 1
}

$Blacklist = @(
    "suamisihat",
    "suamisihat.myds.me",
    "assets.suamisihat.myds.me",
    "creative.suamisihat.myds.me",
    "radio.suamisihat.myds.me",
    "SSNAS",
    "\\SSNAS\",
    "00_logo_SuamiSihat",
    "SuamiSihat123!"
)

$Violations = @()
$Files = Get-ChildItem -Path $TargetDir -Recurse -File -Include *.md, *.html, *.json, *.yml, *.yaml

foreach ($File in $Files) {
    $Content = Get-Content -Path $File.FullName -Raw
    foreach ($Pattern in $Blacklist) {
        if ($Content -match "(?i)$([regex]::Escape($Pattern))") {
            $Violations += [PSCustomObject]@{
                File = $File.Name
                Pattern = $Pattern
                FullPath = $File.FullName
            }
        }
    }
}

if ($Violations.Count -gt 0) {
    Write-Host "`n[FAIL] LEAKAGE DETECTED! Found $($Violations.Count) blacklisted references:" -ForegroundColor Red
    foreach ($v in $Violations) {
        Write-Host "  - File: $($v.File) | Pattern: '$($v.Pattern)'" -ForegroundColor Yellow
    }
    Write-Host "`nPublic wiki generation halted. Remove all internal references before publishing." -ForegroundColor Red
    exit 1
}

Write-Host "`n[PASS] Zero internal references detected in public documentation." -ForegroundColor Green
Write-Host "All $($Files.Count) files passed leakage validation. Safe for public distribution." -ForegroundColor Green
exit 0

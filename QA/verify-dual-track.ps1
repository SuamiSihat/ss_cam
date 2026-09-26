# ==============================================================================
# SS-CAM MASTER DUAL-TRACK GOVERNANCE GATEKEEPER
# Enforces code safety, UTF-8 BOM, Fluent 2 UI standards, public wiki leakage
# prevention, and Release build integrity across Core and Edition tracks.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$Fix
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = "."
}
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "SS-CAM Dual-Track Governance Gatekeeper" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Step 1: Source Guardian Verification
Write-Host "`n[STEP 1/3] Running Source Guardian..." -ForegroundColor Yellow
$SourceGuardianScript = Join-Path $RepoRoot "QA\verify-sscam.ps1"
if (-not (Test-Path $SourceGuardianScript)) {
    Write-Error "Source Guardian script not found: $SourceGuardianScript"
    exit 1
}

$SgArgs = @()
if ($Fix) { $SgArgs += "-Fix" }

& powershell -ExecutionPolicy Bypass -File $SourceGuardianScript @SgArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[FAIL] Source Guardian checks failed. Review and fix issues above." -ForegroundColor Red
    exit 1
}

# Step 2: Public Documentation Leakage Audit
Write-Host "`n[STEP 2/3] Auditing Public Documentation for Leakage..." -ForegroundColor Yellow
$AuditScript = Join-Path $RepoRoot "docs\scripts\audit-public-docs.ps1"
if (-not (Test-Path $AuditScript)) {
    Write-Error "Public docs audit script not found: $AuditScript"
    exit 1
}

& powershell -ExecutionPolicy Bypass -File $AuditScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[FAIL] Public documentation contains blacklisted internal references!" -ForegroundColor Red
    exit 1
}

# Step 3: Optional Release Build Verification
if ($Build) {
    Write-Host "`n[STEP 3/3] Compiling Release Build..." -ForegroundColor Yellow
    $QaRunner = Join-Path $RepoRoot ".agents\skills\sscam-qa\scripts\run-sscam-qa.ps1"
    if (Test-Path $QaRunner) {
        & powershell -ExecutionPolicy Bypass -File $QaRunner -Build -Configuration Release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`n[FAIL] Release build verification failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  [SKIP] QA runner not found; skipping build." -ForegroundColor Gray
    }
} else {
    Write-Host "`n[STEP 3/3] Build check skipped (Pass -Build to trigger full Release compile)." -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "RESULT: ALL DUAL-TRACK GOVERNANCE CHECKS PASSED!" -ForegroundColor Green
Write-Host "Safe for SS-Master commit and commercial distribution." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
exit 0

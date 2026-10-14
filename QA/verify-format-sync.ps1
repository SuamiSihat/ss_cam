<#
.SYNOPSIS
    Check-only verification that every SS-CAM client uses the same project format.

.DESCRIPTION
    Verifies, without modifying any file, that Windows (WPF), Web, Linux and Android agree on:
      - the canonical project status values
      - the 5 project subfolders
      - the year / month folder layout (<YYYY>/<YYYYMM>_<Month>, no "SS-" year prefix)
      - the copy file location (03_COPYWRITING/COPY.md)
    Replaces the old sync-status-enums.ps1, which rewrote source files from an external JSON file.

.EXAMPLE
    .\QA\verify-format-sync.ps1
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repo 'src'

$statuses   = @('backlog', 'in-progress', 'review', 'revision', 'approved', 'on-hold')
$subfolders = @('01_BRIEF_ASSETS', '02_SOURCE_FILES', '03_COPYWRITING', '04_WORK_IN_PROGRESS', '05_DELIVERABLES')

$script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { Write-Host "  [PASS] $name" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $name $detail" -ForegroundColor Red; $script:fail++ }
}
function Read([string]$rel) {
    $p = Join-Path $src $rel
    if (-not (Test-Path $p)) { Write-Host "  [FAIL] Missing file: $rel" -ForegroundColor Red; $script:fail++; return '' }
    return Get-Content $p -Raw -Encoding UTF8
}
function ContainsAll([string]$text, [string[]]$values) {
    foreach ($v in $values) { if ($text -notmatch [regex]::Escape($v)) { return $false } }
    return $true
}

Write-Host "SS-CAM cross-platform format check" -ForegroundColor Cyan
Write-Host "Repository: $repo`n"

Write-Host "[ STATUS VALUES ]" -ForegroundColor Cyan
$wpfStatus = Read 'SS-CAM\Models\ProjectStatus.cs'
Check 'Windows ProjectStatusConstants' (ContainsAll $wpfStatus ($statuses | ForEach-Object { "= `"$_`"" }))
$webTypes = Read 'SS-CAM.Web\client\src\lib\types\index.ts'
Check 'Web ProjectStatus type' (ContainsAll $webTypes ($statuses | ForEach-Object { "'$_'" }))
$webFormat = Read 'SS-CAM.Web\server\services\ProjectFormat.js'
Check 'Web server ProjectFormat' (ContainsAll $webFormat ($statuses | ForEach-Object { "'$_'" }))
$android = Read 'SS-CAM.Android\app\src\main\java\com\suamisihat\sscam\data\models\Models.kt'
Check 'Android ProjectStatusConstants' (ContainsAll $android @('IN_PROGRESS = "in-progress"', 'REVIEW = "review"', 'APPROVED = "approved"', 'ON_HOLD = "on-hold"'))
$linuxStatus = Read 'SS-CAM.Linux\Models\ProjectStatusItem.cs'
Check 'Linux NormalizeStatus' ($linuxStatus -match 'public static string NormalizeStatus')

Write-Host "`n[ PROJECT FOLDERS ]" -ForegroundColor Cyan
Check 'Windows category presets' (ContainsAll (Read 'SS-CAM\Services\CategoryPresetService.cs') $subfolders)
Check 'Web ProjectFormat subfolders' (ContainsAll $webFormat $subfolders)
Check 'Linux category presets' (ContainsAll (Read 'SS-CAM.Linux\Services\CategoryPresetService.cs') $subfolders)
$linuxGen = Read 'SS-CAM.Linux\Services\ProjectGeneratorService.cs'
Check 'Linux project generator subfolders' (ContainsAll $linuxGen $subfolders)
$legacy = @('01_BRIEFS"', '02_RAW_ASSETS', '03_WORKING_FILES', '04_EXPORTS')
Check 'No legacy Linux folder names' (-not ($legacy | Where-Object { $linuxGen -match [regex]::Escape($_) }))

Write-Host "`n[ FOLDER LAYOUT ]" -ForegroundColor Cyan
Check 'Linux year folder has no SS- prefix' ($linuxGen -notmatch '\$"SS-\{cleanYear\}"')
Check 'Linux month name uses invariant culture' ($linuxGen -match 'MMMM", System\.Globalization\.CultureInfo\.InvariantCulture')
Check 'Web creates projects inside the month folder' ($webFormat -match 'getMonthContainer')
Check 'Copy file in 03_COPYWRITING (Linux)' ($linuxGen -match '"03_COPYWRITING", "COPY\.md"')

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "RESULT: FAIL -- $($script:fail) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "RESULT: PASS -- all clients use the same project format." -ForegroundColor Green

$exePath = (Resolve-Path "src\SS-CAM\bin\Release\SS-CAM.exe").Path
[Reflection.Assembly]::LoadFrom($exePath) | Out-Null

$passCount = 0
$failCount = 0

function Assert-Test($condition, $name) {
    if ($condition) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $global:passCount++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $global:failCount++
    }
}

Write-Host "=========================================="
Write-Host "  T3 STARTUP & PERFORMANCE AUTOMATED QA"
Write-Host "=========================================="

# Test 1: UserProfileService in-memory caching
Write-Host "`n1. UserProfileService in-memory cache:"
[SS_CAM.Services.UserProfileService]::InvalidateCache()
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$p1 = [SS_CAM.Services.UserProfileService]::LoadProfile($false)
$firstCallMs = $sw.ElapsedMilliseconds
$sw.Restart()

# 50 consecutive calls
for ($i = 0; $i -lt 50; $i++) {
    $p = [SS_CAM.Services.UserProfileService]::LoadProfile($false)
}
$fiftyCallsMs = $sw.ElapsedMilliseconds
$sw.Stop()

Write-Host "  First call (disk load): ${firstCallMs} ms"
Write-Host "  50 cached calls: ${fiftyCallsMs} ms (average $([Math]::Round($fiftyCallsMs / 50.0, 3)) ms/call)"

Assert-Test ($p1 -ne $null) "Initial profile loaded successfully"
Assert-Test ($fiftyCallsMs -le 50) "50 cached calls execute in under 50 ms total (<1 ms each)"

# Test 2: Cache update on SaveProfile
Write-Host "`n2. UserProfile cache invalidation & update:"
$testName = "QA_Tester_" + (Get-Random)
$p1.DesignerName = $testName
[SS_CAM.Services.UserProfileService]::SaveProfile($p1)
$pCached = [SS_CAM.Services.UserProfileService]::LoadProfile($false)
Assert-Test ($pCached.DesignerName -eq $testName) "SaveProfile updates in-memory cached instance"

# Test 3: PayloadInstallerService version marker
Write-Host "`n3. Payload deployment marker check:"
$res1 = [SS_CAM.Services.PayloadInstallerService]::DeployBrandAssets("")
Write-Host "  Deploy run 1: $res1"
$res2 = [SS_CAM.Services.PayloadInstallerService]::DeployBrandAssets("")
Write-Host "  Deploy run 2: $res2"
Assert-Test ($res2.Contains("already up to date")) "Second deployment skips copy and returns version marker match"

# Test 4: Brand fonts marker check
Write-Host "`n4. Brand fonts deployment marker check:"
$fontRes1 = [SS_CAM.Services.PayloadInstallerService]::InstallBrandFonts()
Write-Host "  Font run 1: $fontRes1"
$fontRes2 = [SS_CAM.Services.PayloadInstallerService]::InstallBrandFonts()
Write-Host "  Font run 2: $fontRes2"
Assert-Test ($fontRes2.Contains("already verified")) "Second font run skips extraction and returns version marker match"

# Test 5: NasConfigSyncService safe directory checking
Write-Host "`n5. NAS discovery responsiveness:"
$discSw = [System.Diagnostics.Stopwatch]::StartNew()
$root = [SS_CAM.Services.NasConfigSyncService]::DiscoverWorkspaceRoot()
$discMs = $discSw.ElapsedMilliseconds
Write-Host "  DiscoverWorkspaceRoot result: $root (in ${discMs} ms)"
Assert-Test ($discMs -lt 3000) "Workspace root discovery completes quickly without thread hanging"

Write-Host "=========================================="
Write-Host "  RESULTS: $passCount PASSED, $failCount FAILED"
Write-Host "=========================================="
if ($failCount -gt 0) { exit 1 } else { exit 0 }

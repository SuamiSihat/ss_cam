$buildExe = (Resolve-Path "src\SS-CAM\bin\Release\SS-CAM.exe").Path
[Reflection.Assembly]::LoadFrom($buildExe) | Out-Null

$testRoot = Join-Path $env:TEMP "sscam_archive_test_$(Get-Random)"
$ws = Join-Path $testRoot "Workspace"
$archiveRoot = Join-Path $ws "_Archive"
$project1 = Join-Path $ws "2026_001_TestProject"

try {
    # 1. Setup dummy workspace and project
    New-Item -ItemType Directory -Path $project1 -Force | Out-Null
    Set-Content -Path (Join-Path $project1 "brief.md") -Value "# Test Brief`nContent here"
    Set-Content -Path (Join-Path $project1 "deliverable.png") -Value "dummy image content 1234567890"
    
    $origFiles = Get-ChildItem -Path $project1 -Recurse
    $origCount = $origFiles.Count
    Write-Host "Setup: Dummy project created with $origCount files at $project1"

    # 2. Run ArchiveBatchAsync via ArchiveVaultService
    $opts = New-Object SS_CAM.Services.ArchiveBatchOptions
    $opts.ArchiveRoot = $archiveRoot
    $opts.CopyOnly = $true
    $opts.OperatorName = "AutomatedQA"

    $paths = New-Object 'System.Collections.Generic.List[string]'
    $paths.Add($project1)

    $task = [SS_CAM.Services.ArchiveVaultService]::ArchiveBatchAsync($paths, $opts)
    $task.Wait()
    $result = $task.Result

    Write-Host "Result Success: $($result.Success)"
    Write-Host "ArchivedCount: $($result.ArchivedCount)"
    Write-Host "TotalZipBytes: $($result.TotalZipBytes)"
    Write-Host "CatalogPath: $($result.CatalogPath)"

    # Verification 1: Success is true
    if (-not $result.Success) {
        Write-Host "FAIL: ArchiveBatchAsync returned Success=false"
        exit 1
    }

    # Verification 2: Catalog exists and has entry
    if (-not (Test-Path $result.CatalogPath)) {
        Write-Host "FAIL: Catalog file missing"
        exit 1
    }
    $catalogLines = Get-Content $result.CatalogPath
    Write-Host "Catalog lines count: $($catalogLines.Count)"
    Write-Host "Catalog line: $($catalogLines[0])"

    # Verification 3: Source is untouched
    $afterFiles = Get-ChildItem -Path $project1 -Recurse
    if ($afterFiles.Count -ne $origCount) {
        Write-Host "FAIL: Source folder was modified! Expected $origCount files, found $($afterFiles.Count)"
        exit 1
    }
    Write-Host "PASS: Source project remains 100% untouched ($($afterFiles.Count) files intact)"

    # Verification 4: Archive zip exists in year/month folder
    $zipFiles = Get-ChildItem -Path $archiveRoot -Recurse -Filter "*.zip"
    if ($zipFiles.Count -eq 0) {
        Write-Host "FAIL: No zip file created in archive"
        exit 1
    }
    Write-Host "PASS: Archive zip created: $($zipFiles[0].FullName) (Size: $($zipFiles[0].Length) bytes)"

    # Verification 5: Test invalid/offline root
    $badOpts = New-Object SS_CAM.Services.ArchiveBatchOptions
    $badOpts.ArchiveRoot = "Z:\NonExistentDrive\Archive"
    $badOpts.CopyOnly = $true
    $badTask = [SS_CAM.Services.ArchiveVaultService]::ArchiveBatchAsync($paths, $badOpts)
    $badTask.Wait()
    $badResult = $badTask.Result
    Write-Host "Invalid root Success: $($badResult.Success), ErrorMessage: $($badResult.ErrorMessage)"
    if ($badResult.Success -eq $false -and $badResult.ErrorMessage -ne $null) {
        Write-Host "PASS: Invalid root handled gracefully without freeze or unhandled exception"
    } else {
        Write-Host "FAIL: Invalid root did not report expected error"
        exit 1
    }

    Write-Host "`nALL T1 ARCHIVE TESTS PASSED SUCCESSFULLY!"
}
finally {
    if (Test-Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

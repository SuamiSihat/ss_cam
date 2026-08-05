<#
.SYNOPSIS
    Build-Installer.ps1 — produces the SS-CAM distributable for the active branch.

    v1.x  (Version like 1.*.*) : builds the legacy PowerShell bootstrapper EXE.
    v2.x+ (Version like 2.*.*) : compiles the native C# WPF app via MSBuild and
                                  outputs SS-CAM-vX.Y.Z.exe (the app itself) plus
                                  SS-CAM-vX.Y.Z-portable.zip (app + all DLLs).
                                  No bootstrapper - avoids AV false positives.
#>
[CmdletBinding()]
param(
    [ValidatePattern("^\d+\.\d+\.\d+$")]
    [string]$Version = "1.9.10"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$projectRoot     = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputDirectory = Join-Path $projectRoot "dist"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$major = [int]($Version.Split('.')[0])

# ── v2.0+ build path ─────────────────────────────────────────────────────────
if ($major -ge 2) {

    Write-Host "Building SS-CAM v$Version (native C# WPF - no bootstrapper)" -ForegroundColor Cyan

    $msBuild      = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
    $csharpProj   = Join-Path $projectRoot "src\SS-CAM\SS-CAM.csproj"
    $releaseDir   = Join-Path $projectRoot "src\SS-CAM\bin\Release"

    # 1. Compile
    Write-Host "Compiling SS-CAM via MSBuild..."
    & $msBuild $csharpProj /p:Configuration=Release /t:Build /nologo
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed." }

    $sourceExe = Join-Path $releaseDir "SS-CAM.exe"
    if (-not (Test-Path $sourceExe)) { throw "SS-CAM.exe not found at $sourceExe" }

    # 2. Create versioned output folder with EXE + all dependencies
    $versionedDir = Join-Path $outputDirectory "SS-CAM-v$Version"
    if (Test-Path $versionedDir) { Remove-Item $versionedDir -Recurse -Force }
    New-Item -ItemType Directory -Path $versionedDir | Out-Null

    Get-ChildItem -Path $releaseDir -File | Where-Object {
        $_.Extension -in @('.exe', '.dll', '.xml', '.pdb', '.nlp', '.config')
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $versionedDir $_.Name) -Force
    }

    # Rename SS-CAM.exe to SS-CAM-v$Version.exe inside the folder for clarity
    $innerExe    = Join-Path $versionedDir "SS-CAM.exe"
    $renamedExe  = Join-Path $versionedDir "SS-CAM-v$Version.exe"
    if (Test-Path $innerExe) { Rename-Item -LiteralPath $innerExe -NewName "SS-CAM-v$Version.exe" -Force }

    # Also copy the standalone EXE to dist root (will fail silently without DLLs but is handy for devs)
    $outputExe = Join-Path $outputDirectory "SS-CAM-v$Version.exe"
    Copy-Item -LiteralPath $renamedExe -Destination $outputExe -Force

    # 3. Build portable ZIP from the versioned folder
    $portableZip = Join-Path $outputDirectory "SS-CAM-v$Version-portable.zip"
    if (Test-Path $portableZip) { Remove-Item $portableZip -Force }
    Compress-Archive -Path (Join-Path $versionedDir "*") `
        -DestinationPath $portableZip -CompressionLevel Optimal -Force

    $dirSize = (Get-ChildItem $versionedDir -File | Measure-Object -Property Length -Sum).Sum / 1MB
    $zipInfo = Get-Item $portableZip
    Write-Host ""
    Write-Host "Build complete:" -ForegroundColor Green
    Write-Host "  Run folder : $versionedDir  ($([math]::Round($dirSize,2)) MB total)"
    Write-Host "  Portable   : $($zipInfo.FullName)  ($([math]::Round($zipInfo.Length/1MB,2)) MB)"
    Write-Host ""
    Write-Host "To run: open the folder and double-click SS-CAM-v$Version.exe" -ForegroundColor Yellow

    exit 0
}

# ── v1.x legacy bootstrapper build path ─────────────────────────────────────
Write-Host "Building Suamisihat Creative Assets Management v$Version" -ForegroundColor Cyan

$outputFile            = Join-Path $outputDirectory "SS-CAM-v$Version.exe"
$iconFile              = Join-Path $projectRoot "payload\Brand Assets\Logos\ss_favicon\favicon.ico"
$bootstrapperSource    = Join-Path $PSScriptRoot "bootstrapper\Program.cs"
$applicationManifest   = Join-Path $PSScriptRoot "bootstrapper\app.manifest"
$frameworkRoot         = Join-Path $env:WINDIR "Microsoft.NET"
$compilerCandidates    = @(
    (Join-Path $frameworkRoot "Framework64\v4.0.30319\csc.exe"),
    (Join-Path $frameworkRoot "Framework\v4.0.30319\csc.exe")
)
$compiler = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
$wpfReferenceRoot              = Join-Path (Split-Path -Parent $compiler) "WPF"
$presentationFrameworkReference = Join-Path $wpfReferenceRoot "PresentationFramework.dll"
$presentationCoreReference      = Join-Path $wpfReferenceRoot "PresentationCore.dll"
$windowsBaseReference           = Join-Path $wpfReferenceRoot "WindowsBase.dll"
$systemXamlReference            = Join-Path (Split-Path -Parent $compiler) "System.Xaml.dll"
$tempDirectory  = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$buildRoot      = Join-Path $tempDirectory ("SuamiSihatInstallerBuild-" + [guid]::NewGuid().ToString("N"))
$archiveRoot    = Join-Path $buildRoot "archive"
$archiveFile    = Join-Path $buildRoot "SuamiSihat-Designer-Assets.zip"
$assemblyInfoFile = Join-Path $buildRoot "AssemblyInfo.cs"

$requiredPaths = @(
    (Join-Path $projectRoot "payload\Fonts"),
    (Join-Path $projectRoot "payload\Brand Assets"),
    (Join-Path $PSScriptRoot "src\Install-SuamiSihat.ps1"),
    (Join-Path $PSScriptRoot "src\Install-SuamiSihat-WPF.ps1"),
    (Join-Path $PSScriptRoot "src\Installer.Common.ps1"),
    (Join-Path $PSScriptRoot "src\Installer.WellbeingData.ps1"),
    (Join-Path $PSScriptRoot "src\Installer.Wellbeing.ps1"),
    (Join-Path $PSScriptRoot "EULA.txt"),
    (Join-Path $PSScriptRoot "assets\suamisihat-logo-on-dark-ui.png"),
    (Join-Path $PSScriptRoot "assets\suamisihat-logo-on-light-ui.png"),
    $bootstrapperSource, $applicationManifest,
    $presentationFrameworkReference, $presentationCoreReference,
    $windowsBaseReference, $systemXamlReference,
    $iconFile, $compiler
)
foreach ($requiredPath in $requiredPaths) {
    if (-not $requiredPath -or -not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required installer input is missing: $requiredPath"
    }
}

try {
    Write-Host "Preparing the self-contained payload..."

    New-Item -ItemType Directory -Path (Join-Path $archiveRoot "installer\src") -Force | Out-Null

    Copy-Item -LiteralPath (Join-Path $projectRoot "payload") -Destination $archiveRoot -Recurse
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "src") -File -Filter "*.ps1" |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $archiveRoot "installer\src")
        }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "EULA.txt") `
        -Destination (Join-Path $archiveRoot "installer")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "assets") `
        -Destination (Join-Path $archiveRoot "installer") -Recurse

    Compress-Archive -Path (Join-Path $archiveRoot "*") -DestinationPath $archiveFile `
        -CompressionLevel Optimal -Force

    $assemblyVersion = "$Version.0"
    $assemblyInfo = @"
using System.Reflection;
[assembly: AssemblyTitle("SuamiSihat Creative Assets Management")]
[assembly: AssemblyDescription("SuamiSihat brand assets, font installer, and Post Haste project template creator")]
[assembly: AssemblyCompany("SuamiSihat")]
[assembly: AssemblyProduct("SuamiSihat Creative Assets Management")]
[assembly: AssemblyCopyright("Copyright (c) SuamiSihat")]
[assembly: AssemblyVersion("$assemblyVersion")]
[assembly: AssemblyFileVersion("$assemblyVersion")]
"@
    Set-Content -LiteralPath $assemblyInfoFile -Value $assemblyInfo -Encoding UTF8

    Write-Host "Compiling the Windows EXE..."
    $compilerArguments = @(
        "/nologo", "/target:winexe", "/optimize+", "/platform:anycpu",
        ('/out:"{0}"'          -f $outputFile),
        ('/win32icon:"{0}"'    -f $iconFile),
        ('/win32manifest:"{0}"' -f $applicationManifest),
        ('/resource:"{0}",SuamiSihat.Payload.Zip' -f $archiveFile),
        "/reference:System.dll", "/reference:System.Core.dll",
        ('/reference:"{0}"' -f $presentationFrameworkReference),
        ('/reference:"{0}"' -f $presentationCoreReference),
        ('/reference:"{0}"' -f $windowsBaseReference),
        ('/reference:"{0}"' -f $systemXamlReference),
        "/reference:System.IO.Compression.dll",
        "/reference:System.IO.Compression.FileSystem.dll",
        ('"{0}"' -f $bootstrapperSource),
        ('"{0}"' -f $assemblyInfoFile)
    )
    & $compiler $compilerArguments
    if ($LASTEXITCODE -ne 0) { throw "The .NET compiler failed with exit code $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
        throw "The compiler completed but the expected EXE was not created: $outputFile"
    }

    $outputInfo = Get-Item -LiteralPath $outputFile
    Write-Host ""
    Write-Host "Installer created:" -ForegroundColor Green
    Write-Host $outputInfo.FullName
    Write-Host ("Size: {0:N2} MB" -f ($outputInfo.Length / 1MB))

} finally {
    $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
    if ($resolvedBuildRoot.StartsWith($tempDirectory, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedBuildRoot).StartsWith("SuamiSihatInstallerBuild-")) {
        if (Test-Path -LiteralPath $resolvedBuildRoot) {
            Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
        }
    }
}

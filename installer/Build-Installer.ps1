[CmdletBinding()]
param(
    [ValidatePattern("^\d+\.\d+\.\d+$")]
    [string]$Version = "1.9.10"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputDirectory = Join-Path $projectRoot "dist"
$outputFile = Join-Path $outputDirectory "SS-CAM-v$Version.exe"
$iconFile = Join-Path $projectRoot "payload\Brand Assets\Logos\ss_favicon\favicon.ico"
$bootstrapperSource = Join-Path $PSScriptRoot "bootstrapper\Program.cs"
$applicationManifest = Join-Path $PSScriptRoot "bootstrapper\app.manifest"
$frameworkRoot = Join-Path $env:WINDIR "Microsoft.NET"
$compilerCandidates = @(
    (Join-Path $frameworkRoot "Framework64\v4.0.30319\csc.exe"),
    (Join-Path $frameworkRoot "Framework\v4.0.30319\csc.exe")
)
$compiler = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
$wpfReferenceRoot = if ($compiler) { Join-Path (Split-Path -Parent $compiler) "WPF" } else { "" }
$presentationFrameworkReference = if ($wpfReferenceRoot) { Join-Path $wpfReferenceRoot "PresentationFramework.dll" } else { "" }
$presentationCoreReference = if ($wpfReferenceRoot) { Join-Path $wpfReferenceRoot "PresentationCore.dll" } else { "" }
$windowsBaseReference = if ($wpfReferenceRoot) { Join-Path $wpfReferenceRoot "WindowsBase.dll" } else { "" }
$systemXamlReference = if ($compiler) { Join-Path (Split-Path -Parent $compiler) "System.Xaml.dll" } else { "" }
$tempDirectory = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$buildRoot = Join-Path $tempDirectory ("SuamiSihatInstallerBuild-" + [guid]::NewGuid().ToString("N"))
$archiveRoot = Join-Path $buildRoot "archive"
$archiveFile = Join-Path $buildRoot "SuamiSihat-Designer-Assets.zip"
$assemblyInfoFile = Join-Path $buildRoot "AssemblyInfo.cs"

$requiredPaths = @(
    (Join-Path $projectRoot "payload\Fonts"),
    (Join-Path $projectRoot "payload\Brand Assets"),
    (Join-Path $PSScriptRoot "src\Install-SuamiSihat.ps1"),
    (Join-Path $PSScriptRoot "src\Install-SuamiSihat-WPF.ps1"),
    (Join-Path $PSScriptRoot "src\Installer.Common.ps1"),
    (Join-Path $PSScriptRoot "EULA.txt"),
    (Join-Path $PSScriptRoot "assets\suamisihat-logo-on-dark-ui.png"),
    (Join-Path $PSScriptRoot "assets\suamisihat-logo-on-light-ui.png"),
    $bootstrapperSource,
    $applicationManifest,
    $presentationFrameworkReference,
    $presentationCoreReference,
    $windowsBaseReference,
    $systemXamlReference,
    $iconFile,
    $compiler
)
foreach ($requiredPath in $requiredPaths) {
    if (-not $requiredPath -or -not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required installer input is missing: $requiredPath"
    }
}

try {
    Write-Host "Building Suamisihat Creative Assets Management v$Version" -ForegroundColor Cyan
    Write-Host "Preparing the self-contained payload..."

    New-Item -ItemType Directory -Path (Join-Path $archiveRoot "installer\src") -Force | Out-Null
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

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
        "/nologo",
        "/target:winexe",
        "/optimize+",
        "/platform:anycpu",
        ('/out:"{0}"' -f $outputFile),
        ('/win32icon:"{0}"' -f $iconFile),
        ('/win32manifest:"{0}"' -f $applicationManifest),
        ('/resource:"{0}",SuamiSihat.Payload.Zip' -f $archiveFile),
        "/reference:System.dll",
        "/reference:System.Core.dll",
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
    $compilerExitCode = $LASTEXITCODE
    if ($compilerExitCode -ne 0) {
        throw "The .NET compiler failed with exit code $compilerExitCode."
    }
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







[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("All", "Core")]
    [string]$FontSet = "All",

    [string]$Destination = "",

    [switch]$SkipFonts,
    [switch]$SkipAssets,
    [switch]$SkipReports,
    [switch]$SkipWebShortcuts,
    [switch]$OpenImportFiles
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$commonFunctions = Join-Path $PSScriptRoot "Installer.Common.ps1"
if (-not (Test-Path -LiteralPath $commonFunctions -PathType Leaf)) {
    throw "Installer support file not found: $commonFunctions"
}
. $commonFunctions
$documentsDirectory = [Environment]::GetFolderPath("MyDocuments")
if ([string]::IsNullOrWhiteSpace($documentsDirectory)) {
    $documentsDirectory = Join-Path $env:USERPROFILE "Documents"
}
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $documentsDirectory "SuamiSihat Brand Assets"
}
$fontLibrary = Join-Path $projectRoot "payload\Fonts"
$assetFolders = @(
    @{ Source = "payload\Brand Assets\Logos"; Target = "Logos" },
    @{ Source = "payload\Brand Assets\Libraries"; Target = "Libraries" },
    @{ Source = "payload\Brand Assets\Colour Palettes"; Target = "Colour Palettes" }
)
$fontExtensions = @(".ttf", ".otf", ".ttc")

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-InternetShortcut {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Url
    )

    $parentDirectory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
    $shortcutContent = @(
        "[InternetShortcut]",
        "URL=$Url",
        "IconFile=$env:SystemRoot\System32\SHELL32.dll",
        "IconIndex=14"
    )
    Set-Content -LiteralPath $Path -Value $shortcutContent -Encoding ASCII
}

function Get-FileSha256 {
    param([string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "")
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-UniqueFontFiles {
    param([string[]]$Roots)

    $seenHashes = @{}
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        foreach ($font in Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName) {
            if ($fontExtensions -notcontains $font.Extension.ToLowerInvariant()) {
                continue
            }

            $hash = Get-FileSha256 -Path $font.FullName
            if (-not $seenHashes.ContainsKey($hash)) {
                $seenHashes[$hash] = $true
                $font
            }
        }
    }
}

function Install-CurrentUserFont {
    param(
        [System.IO.FileInfo]$Font,
        [string]$FontsDirectory,
        [string]$RegistryPath
    )

    $targetPath = Join-Path $FontsDirectory $Font.Name
    if (Test-Path -LiteralPath $targetPath) {
        $sourceHash = Get-FileSha256 -Path $Font.FullName
        $targetHash = Get-FileSha256 -Path $targetPath

        if ($sourceHash -ne $targetHash) {
            $shortHash = $sourceHash.Substring(0, 8)
            $targetName = "{0}-{1}{2}" -f $Font.BaseName, $shortHash, $Font.Extension
            $targetPath = Join-Path $FontsDirectory $targetName
        }
    }

    $fontType = if ($Font.Extension -ieq ".otf") { "OpenType" } else { "TrueType" }
    $registryName = "{0} ({1})" -f [IO.Path]::GetFileNameWithoutExtension($targetPath), $fontType

    if ($PSCmdlet.ShouldProcess($Font.Name, "Install font for the current Windows user")) {
        Copy-Item -LiteralPath $Font.FullName -Destination $targetPath -Force
        New-ItemProperty -Path $RegistryPath -Name $registryName -Value $targetPath `
            -PropertyType String -Force | Out-Null
        [void][SuamiSihatFontRefresh]::AddFontResourceEx($targetPath, 0, [IntPtr]::Zero)
    }
}

$runningOnWindows = $env:OS -eq "Windows_NT"
if (-not $runningOnWindows) {
    throw "This setup script is for Windows. Use install-fonts.sh or install_fonts.py on other platforms."
}

Write-Host "SuamiSihat Designer Assets Installer" -ForegroundColor Green
Write-Host "Source: $projectRoot"

$installedCount = 0
$selectedFonts = @()
if (-not $SkipFonts) {
    if (-not (Test-Path -LiteralPath $fontLibrary -PathType Container)) {
        throw "Font library not found: $fontLibrary"
    }

    $fontRoots = if ($FontSet -eq "Core") {
        @(
            Get-ChildItem -LiteralPath $fontLibrary -Directory |
                Where-Object { $_.Name -match "^(01|02|03|04)-" } |
                ForEach-Object { $_.FullName }
        )
    } else {
        @($fontLibrary)
    }

    $fonts = @(Get-UniqueFontFiles -Roots $fontRoots)
    $selectedFonts = $fonts
    $userFontsDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontsRegistry = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    Write-Step "Installing $($fonts.Count) unique $FontSet font files for the current user"
    if (-not $WhatIfPreference -and -not ("SuamiSihatFontRefresh" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SuamiSihatFontRefresh {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int AddFontResourceEx(string name, uint flags, IntPtr reserved);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
    }

    if ($PSCmdlet.ShouldProcess($userFontsDirectory, "Create per-user fonts directory")) {
        New-Item -ItemType Directory -Path $userFontsDirectory -Force | Out-Null
        New-Item -Path $fontsRegistry -Force | Out-Null
    }

    foreach ($font in $fonts) {
        try {
            Install-CurrentUserFont -Font $font -FontsDirectory $userFontsDirectory -RegistryPath $fontsRegistry
            $installedCount++
            Write-Host "  Font: $($font.Name)"
        } catch {
            Write-Warning "Could not install '$($font.FullName)': $($_.Exception.Message)"
        }
    }

    if (-not $WhatIfPreference) {
        $refreshResult = [UIntPtr]::Zero
        [void][SuamiSihatFontRefresh]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero,
            0x0002, 5000, [ref]$refreshResult
        )
    }
}

$copiedFolders = 0
$assetFileCount = 0
if (-not $SkipAssets) {
    Write-Step "Copying brand resources to $Destination"
    if ($PSCmdlet.ShouldProcess($Destination, "Create brand assets directory")) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    foreach ($folder in $assetFolders) {
        $folderName = $folder.Target
        $sourceFolder = Join-Path $projectRoot $folder.Source
        if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) {
            Write-Warning "Asset folder not found: $sourceFolder"
            continue
        }

        $targetFolder = Join-Path $Destination $folderName
        if ($PSCmdlet.ShouldProcess($targetFolder, "Copy $folderName")) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
            foreach ($item in Get-ChildItem -LiteralPath $sourceFolder -Force) {
                Copy-Item -LiteralPath $item.FullName -Destination $targetFolder -Recurse -Force
            }
        }
        $copiedFolders++
        $assetFileCount += @(Get-ChildItem -LiteralPath $sourceFolder -Recurse -File).Count
        Write-Host "  Assets: $folderName"
    }
}

$webShortcutsCreated = 0
if (-not $SkipWebShortcuts -and -not $WhatIfPreference) {
    Write-Step "Creating SuamiSihat web shortcuts"
    $favoritesDirectory = [Environment]::GetFolderPath("Favorites")
    if ([string]::IsNullOrWhiteSpace($favoritesDirectory)) {
        $favoritesDirectory = Join-Path $env:USERPROFILE "Favorites"
    }

    $shortcutLocations = @(
        @{
            Path = Join-Path (Join-Path $favoritesDirectory "SuamiSihat") "SuamiSihat Service Dashboard.url"
            Url = "https://suamisihat.myds.me"
        },
        @{
            Path = Join-Path (Join-Path $favoritesDirectory "SuamiSihat") "SuamiSihat Internal Assets.url"
            Url = "https://assets.suamisihat.com.my"
        }
    )
    if (-not $SkipAssets) {
        $linksDirectory = Join-Path $Destination "Links"
        $shortcutLocations += @(
            @{
                Path = Join-Path $linksDirectory "SuamiSihat Service Dashboard.url"
                Url = "https://suamisihat.myds.me"
            },
            @{
                Path = Join-Path $linksDirectory "SuamiSihat Internal Assets.url"
                Url = "https://assets.suamisihat.com.my"
            }
        )
    }

    foreach ($shortcut in $shortcutLocations) {
        if ($PSCmdlet.ShouldProcess($shortcut.Path, "Create web shortcut")) {
            New-InternetShortcut -Path $shortcut.Path -Url $shortcut.Url
            $webShortcutsCreated++
            Write-Host "  Shortcut: $($shortcut.Path)"
        }
    }
}

if (-not $SkipAssets -and -not $SkipReports -and -not $WhatIfPreference) {
    Write-Step "Creating workstation and font inventory reports"
    $reportsDirectory = Join-Path $Destination "Reports"
    $workstationReport = Join-Path $reportsDirectory "SuamiSihat-Workstation-Report.md"
    $fontInventory = Join-Path $reportsDirectory "SuamiSihat-Font-Inventory.md"

    if ($PSCmdlet.ShouldProcess($reportsDirectory, "Create local installation reports")) {
        $systemInformation = Get-WorkstationInformation
        $softwareInventory = @(Get-DesignSoftwareInventory)
        $reportFontSet = if ($SkipFonts) { "Skipped" } else { $FontSet }
        New-WorkstationMarkdownReport -SystemInformation $systemInformation `
            -SoftwareInventory $softwareInventory -Path $workstationReport `
            -FontsProcessed $installedCount -AssetFilesCopied $assetFileCount `
            -WebShortcutsCreated $webShortcutsCreated -FontSet $reportFontSet

        $fontRows = foreach ($font in $selectedFonts | Sort-Object Name, FullName) {
            $relativePath = $font.FullName.Substring($fontLibrary.Length).TrimStart("\")
            $category = Split-Path $relativePath -Parent
            if ([string]::IsNullOrWhiteSpace($category)) {
                $category = "Root"
            }
            "| $category | $($font.Name) | $($font.Extension.TrimStart('.').ToUpperInvariant()) |"
        }
        if (-not $fontRows) {
            $fontRows = @("| - | Fonts were not installed in this run | - |")
        }

        $fontMarkdown = @"
# SuamiSihat Font Inventory

File naming standard: `Family-Style.ext`, using hyphens instead of spaces and lowercase file extensions.

| Source group | Standard filename | Format |
| --- | --- | --- |
$($fontRows -join [Environment]::NewLine)
"@
        New-Item -ItemType Directory -Path $reportsDirectory -Force | Out-Null
        Set-Content -LiteralPath $fontInventory -Value $fontMarkdown -Encoding UTF8
    }
    Write-Host "  Report: Reports\SuamiSihat-Workstation-Report.md"
    Write-Host "  Report: Reports\SuamiSihat-Font-Inventory.md"
}

if ($OpenImportFiles -and -not $SkipAssets -and -not $WhatIfPreference) {
    Write-Step "Opening native library and palette files"
    $importExtensions = @(".afassets", ".afpalette", ".cclibs", ".ase")
    $importFiles = @(
        Get-ChildItem -LiteralPath $Destination -Recurse -File |
            Where-Object { $importExtensions -contains $_.Extension.ToLowerInvariant() }
    )

    foreach ($importFile in $importFiles) {
        try {
            Start-Process -FilePath $importFile.FullName
            Write-Host "  Opened: $($importFile.Name)"
        } catch {
            Write-Warning "No associated application could open '$($importFile.Name)'. Import it from the application instead."
        }
    }
}

# Install Windows App Shortcuts
try {
    $currentProcessExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($currentProcessExe -and (Test-Path -LiteralPath $currentProcessExe -PathType Leaf) -and $currentProcessExe.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) {
        $appInstallDir = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management"
        New-Item -ItemType Directory -Path $appInstallDir -Force | Out-Null
        $installedExePath = Join-Path $appInstallDir "SuamiSihat-Creative-Assets-Management.exe"
        Copy-Item -LiteralPath $currentProcessExe -Destination $installedExePath -Force
        Install-SuamiSihatShortcuts -TargetExePath $installedExePath
        Write-Host "  Installed Windows Application shortcut: Start Menu -> SuamiSihat Creative Assets Management"
    }
} catch {}

Write-Step "Setup complete"
if (-not $SkipFonts) {
    Write-Host "$installedCount font files processed. Restart Affinity and Adobe apps if they were open."
}
if (-not $SkipAssets) {
    Write-Host "$copiedFolders resource folders copied to:"
    Write-Host "  $Destination" -ForegroundColor Yellow
}
if (-not $SkipWebShortcuts) {
    Write-Host "$webShortcutsCreated SuamiSihat web shortcuts created."
}
if (-not $OpenImportFiles -and -not $SkipAssets) {
    Write-Host "Run again with -OpenImportFiles to open the Affinity and Adobe import packs."
}


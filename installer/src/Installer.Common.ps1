Set-StrictMode -Version 2.0

function Get-DesignSoftwareInventory {
    $registeredApplications = @()
    $registryRoots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($registryRoot in $registryRoots) {
        $registeredApplications += @(
            Get-ItemProperty -Path $registryRoot -ErrorAction SilentlyContinue |
                Select-Object DisplayName, DisplayVersion, InstallLocation |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) }
        )
    }

    try {
        $registeredApplications += @(
            Get-AppxPackage -ErrorAction Stop |
                Select-Object @{Name = "DisplayName"; Expression = { $_.Name } },
                    @{Name = "DisplayVersion"; Expression = { $_.Version.ToString() } },
                    @{Name = "InstallLocation"; Expression = { $_.InstallLocation }}
        )
    } catch {
        # AppX discovery is optional; classic application registration remains available.
    }

    $definitions = @(
        @{
            Name = "Affinity"
            Pattern = "(?i)(^|[^a-z])Affinity($|[^a-z])|Affinity Designer|Affinity Photo|Affinity Publisher"
            Paths = @(
                (Join-Path $env:ProgramFiles "Affinity\Affinity.exe"),
                (Join-Path $env:LOCALAPPDATA "Programs\Affinity\Affinity.exe")
            )
            DownloadUrl = "https://www.affinity.studio/download"
        },
        @{
            Name = "Canva"
            Pattern = "(?i)^Canva$|Canva for Windows|Canva Desktop"
            Paths = @(
                (Join-Path $env:LOCALAPPDATA "Programs\Canva\Canva.exe"),
                (Join-Path $env:LOCALAPPDATA "Canva\Canva.exe")
            )
            DownloadUrl = "https://www.canva.com/download/windows/"
        },
        @{
            Name = "Figma"
            Pattern = "(?i)^Figma($|\s)|Figma Desktop"
            Paths = @(
                (Join-Path $env:LOCALAPPDATA "Figma\Figma.exe"),
                (Join-Path $env:LOCALAPPDATA "Programs\Figma\Figma.exe"),
                (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Figma.exe")
            )
            DownloadUrl = "https://www.figma.com/downloads/"
        },
        @{
            Name = "Adobe Creative Cloud"
            Pattern = "(?i)Adobe Creative Cloud"
            Paths = @(
                (Join-Path ${env:ProgramFiles(x86)} "Adobe\Adobe Creative Cloud\ACC\Creative Cloud.exe"),
                (Join-Path $env:ProgramFiles "Adobe\Adobe Creative Cloud\ACC\Creative Cloud.exe")
            )
            DownloadUrl = "https://creativecloud.adobe.com/apps/download/creative-cloud"
        },
        @{
            Name = "Adobe Photoshop"
            Pattern = "(?i)Adobe Photoshop"
            Paths = @()
            DownloadUrl = "https://creativecloud.adobe.com/apps/all/desktop"
        },
        @{
            Name = "Adobe Illustrator"
            Pattern = "(?i)Adobe Illustrator"
            Paths = @()
            DownloadUrl = "https://creativecloud.adobe.com/apps/all/desktop"
        },
        @{
            Name = "CapCut"
            Pattern = "(?i)^CapCut$|CapCut PC|CapCut for Windows"
            Paths = @(
                (Join-Path $env:LOCALAPPDATA "CapCut\Apps\CapCut.exe"),
                (Join-Path $env:LOCALAPPDATA "Programs\CapCut\CapCut.exe"),
                (Join-Path $env:ProgramFiles "CapCut\CapCut.exe")
            )
            DownloadUrl = "https://www.capcut.com/download"
        },
        @{
            Name = "DaVinci Resolve"
            Pattern = "(?i)DaVinci Resolve"
            Paths = @(
                (Join-Path $env:ProgramFiles "Blackmagic Design\DaVinci Resolve\Resolve.exe"),
                (Join-Path ${env:ProgramFiles(x86)} "Blackmagic Design\DaVinci Resolve\Resolve.exe")
            )
            DownloadUrl = "https://www.blackmagicdesign.com/products/davinciresolve"
        }
    )

    $adobeRoot = Join-Path $env:ProgramFiles "Adobe"
    if (Test-Path -LiteralPath $adobeRoot -PathType Container) {
        $photoshopPaths = @(
            Get-ChildItem -LiteralPath $adobeRoot -Directory -Filter "Adobe Photoshop *" -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName "Photoshop.exe" }
        )
        $illustratorPaths = @(
            Get-ChildItem -LiteralPath $adobeRoot -Directory -Filter "Adobe Illustrator *" -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName "Support Files\Contents\Windows\Illustrator.exe" }
        )
        ($definitions | Where-Object Name -eq "Adobe Photoshop").Paths = $photoshopPaths
        ($definitions | Where-Object Name -eq "Adobe Illustrator").Paths = $illustratorPaths
    }

    foreach ($definition in $definitions) {
        $registration = $registeredApplications |
            Where-Object { $_.DisplayName -match $definition.Pattern } |
            Select-Object -First 1
        $installedPath = $definition.Paths |
            Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
            Select-Object -First 1
        $installed = $null -ne $registration -or $null -ne $installedPath
        $version = if ($registration) { [string]$registration.DisplayVersion } else { "" }
        $location = if ($installedPath) {
            $installedPath
        } elseif ($registration) {
            [string]$registration.InstallLocation
        } else {
            ""
        }

        [pscustomobject]@{
            Name = $definition.Name
            Installed = $installed
            Version = $version
            Location = $location
            DownloadUrl = $definition.DownloadUrl
        }
    }
}

function Get-WorkstationInformation {
    $computerSystem = $null
    $operatingSystem = $null
    $processor = $null
    $graphicsAdapter = $null
    try { $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch {}
    try { $operatingSystem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch {}
    try { $processor = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch {}
    try {
        $graphicsAdapter = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Sort-Object AdapterRAM -Descending |
            Select-Object -First 1
    } catch {}

    $systemDrive = [Environment]::GetEnvironmentVariable("SystemDrive")
    $driveInfo = $null
    try { $driveInfo = New-Object IO.DriveInfo($systemDrive) } catch {}

    [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        CurrentUser = [Environment]::UserName
        Manufacturer = if ($computerSystem) { [string]$computerSystem.Manufacturer } else { "Unavailable" }
        Model = if ($computerSystem) { [string]$computerSystem.Model } else { "Unavailable" }
        Windows = if ($operatingSystem) {
            "$($operatingSystem.Caption) $($operatingSystem.Version) (Build $($operatingSystem.BuildNumber))"
        } else {
            [Environment]::OSVersion.VersionString
        }
        WindowsVersion = if ($operatingSystem) { [string]$operatingSystem.Version } else { [Environment]::OSVersion.Version.ToString() }
        Architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        Processor = if ($processor) { [string]$processor.Name } else { "Unavailable" }
        ProcessorCores = if ($processor) { [int]$processor.NumberOfCores } else { 0 }
        Graphics = if ($graphicsAdapter) { [string]$graphicsAdapter.Name } else { "Unavailable" }
        GraphicsMemoryGB = if ($graphicsAdapter -and $graphicsAdapter.AdapterRAM) {
            [math]::Round([double]$graphicsAdapter.AdapterRAM / 1GB, 2)
        } else {
            0
        }
        MemoryGB = if ($computerSystem) {
            [math]::Round([double]$computerSystem.TotalPhysicalMemory / 1GB, 2)
        } else {
            "Unavailable"
        }
        SystemDriveFreeGB = if ($driveInfo) {
            [math]::Round($driveInfo.AvailableFreeSpace / 1GB, 2)
        } else {
            "Unavailable"
        }
        PowerShell = $PSVersionTable.PSVersion.ToString()
        CollectedAt = Get-Date
    }
}

function New-WorkstationMarkdownReport {
    param(
        [Parameter(Mandatory = $true)]$SystemInformation,
        [Parameter(Mandatory = $true)][object[]]$SoftwareInventory,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$FontsProcessed,
        [int]$AssetFilesCopied,
        [int]$WebShortcutsCreated,
        [string]$FontSet
    )

    $softwareRows = foreach ($software in $SoftwareInventory) {
        $status = if ($software.Installed) { "Installed" } else { "Not detected" }
        $version = if ([string]::IsNullOrWhiteSpace($software.Version)) { "-" } else { $software.Version }
        "| $($software.Name) | $status | $version |"
    }
    $memoryDisplay = if ($SystemInformation.MemoryGB -is [ValueType]) {
        "$($SystemInformation.MemoryGB) GB"
    } else {
        [string]$SystemInformation.MemoryGB
    }
    $diskDisplay = if ($SystemInformation.SystemDriveFreeGB -is [ValueType]) {
        "$($SystemInformation.SystemDriveFreeGB) GB"
    } else {
        [string]$SystemInformation.SystemDriveFreeGB
    }

    $markdown = @"
# SuamiSihat Designer Workstation Report

Generated locally by the SuamiSihat Designer Assets Installer.

## Computer

| Property | Value |
| --- | --- |
| Computer name | $($SystemInformation.ComputerName) |
| Windows user | $($SystemInformation.CurrentUser) |
| Manufacturer | $($SystemInformation.Manufacturer) |
| Model | $($SystemInformation.Model) |
| Windows | $($SystemInformation.Windows) |
| Architecture | $($SystemInformation.Architecture) |
| Processor | $($SystemInformation.Processor) |
| Processor cores | $($SystemInformation.ProcessorCores) |
| Graphics | $($SystemInformation.Graphics) |
| Reported graphics memory | $($SystemInformation.GraphicsMemoryGB) GB |
| Installed memory | $memoryDisplay |
| System drive free space | $diskDisplay |
| PowerShell | $($SystemInformation.PowerShell) |
| Report time | $($SystemInformation.CollectedAt.ToString("yyyy-MM-dd HH:mm:ss zzz")) |

## Detected design software

| Application | Status | Version |
| --- | --- | --- |
$($softwareRows -join [Environment]::NewLine)

## SuamiSihat installation

| Item | Result |
| --- | --- |
| Font set | $FontSet |
| Font files processed | $FontsProcessed |
| Brand asset files copied | $AssetFilesCopied |
| Web shortcuts created | $WebShortcutsCreated |

## Privacy

This report was created and stored locally. The installer does not transmit workstation information.
"@

    $reportDirectory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
}

function New-SuamiSihatProjectFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDirectory,
        [string]$SubBrand = "SS",
        [string]$JobNumber = "0001D",
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [string]$PresetType = "GraphicDesign",
        [string]$Year = "",
        [string]$Description = "",
        [string[]]$ExtraSubFolders = @(),
        [switch]$InjectTemplates,
        [string]$TemplateExtension = ".af",
        [string]$DesignerName = "",
        [string]$DesignerDept = "",
        [string]$TargetPlatform = "Meta / IG Square (1:1 - 1080x1080 RGB)"
    )

    $cleanProjectName = $ProjectName -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_'
    $cleanProjectName = $cleanProjectName.Trim('_')
    if ([string]::IsNullOrWhiteSpace($cleanProjectName)) {
        throw "Project name cannot be empty."
    }

    if ([string]::IsNullOrWhiteSpace($Year)) {
        $Year = (Get-Date).ToString("yyyy")
    }
    $currentMonth = (Get-Date).ToString("MM")
    $dateCode = "${Year}${currentMonth}"
    
    $brandValue = $SubBrand.Trim()
    $cleanSubBrand = if ($brandValue -match '^([A-Z]{2,4})\s+-\s+') {
        $matches[1].ToUpperInvariant()
    } else { switch -Wildcard ($brandValue) {
        "*HOLDING*"  { "SSH" }
        "*HEALTHCARE*" { "SSC" }
        "*WELLNESS*" { "SSW" }
        "*ECOM*"     { "SSE" }
        "*TECH*"     { "SST" }
        "SSH"        { "SSH" }
        "SSC"        { "SSC" }
        "SSW"        { "SSW" }
        "SSE"        { "SSE" }
        "SST"        { "SST" }
        default      { "SS" }
    } }

    $cleanYear = if ($Year -match '^\d{4}$') { $Year } else { (Get-Date).ToString("yyyy") }
    $curMonthNum = (Get-Date).ToString("MM")
    $curMonthFull = (Get-Culture).TextInfo.ToTitleCase((Get-Date).ToString("MMMM"))
    $curDay = (Get-Date).ToString("dd")

    $yearFolder = "SS-${cleanYear}"
    $monthFolder = "${cleanYear}${curMonthNum}_${curMonthFull}"
    $dateCode = "${cleanYear}${curMonthNum}"

    $cleanJob = ConvertTo-SuamiSihatJobID $JobNumber
    if ($cleanJob -match '^\d+$') { $cleanJob = "${cleanJob}D" }
    if ([string]::IsNullOrWhiteSpace($cleanJob)) { $cleanJob = "0001D" }

    $folderName = "${dateCode}_${cleanJob}_${cleanSubBrand}_${cleanProjectName}"
    $yearRoot = if ($RootDirectory -match '\\SS-\d{4}$') { Split-Path -Parent $RootDirectory } else { $RootDirectory }
    $yearPath = Join-Path $yearRoot $yearFolder
    $monthlyRoot = Join-Path $yearPath $monthFolder
    $projectRoot = Join-Path $monthlyRoot $folderName

    $subFolders = switch -Wildcard ($PresetType) {
        "*Social*"  { @("Working Files", "Source Assets", "Copywriting", "Final Exports") }
        "*Video*"   { @("Project Files", "Footage", "Audio", "Renders", "Final Exports") }
        "*Brand*"   { @("Vector Master", "Brand Guidelines", "Colour Palettes", "Export Packages") }
        default     { @("Artwork Design", "Artwork Mockup", "Assets", "Production") }
    }

    if ($ExtraSubFolders -and @($ExtraSubFolders).Count -gt 0) {
        foreach ($extra in $ExtraSubFolders) {
            if (-not [string]::IsNullOrWhiteSpace($extra) -and $subFolders -notcontains $extra) {
                $subFolders += $extra.Trim()
            }
        }
    }

    foreach ($subFolder in $subFolders) {
        $path = Join-Path $projectRoot $subFolder
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    $appState = Get-SuamiSihatAppState
    $cleanDesigner = if (-not [string]::IsNullOrWhiteSpace($DesignerName)) {
        $DesignerName.Trim()
    } elseif ($appState.DesignerName) {
        $appState.DesignerName
    } else {
        $env:USERNAME
    }

    $cleanDept = if (-not [string]::IsNullOrWhiteSpace($DesignerDept)) {
        $DesignerDept.Trim()
    } elseif ($appState.Department) {
        $appState.Department
    } else {
        "Creative & Brand"
    }

    $targetSpecInfo = switch -Wildcard ($TargetPlatform) {
        "*9:16*"       { @{ Ratio = "9:16"; Resolution = "1080 x 1920 px"; ColorSpace = "RGB 72 DPI"; Type = "Vertical Video / Story / Reels" } }
        "*1:1*"        { @{ Ratio = "1:1"; Resolution = "1080 x 1080 px"; ColorSpace = "RGB 72 DPI"; Type = "Square Social Post / Feed" } }
        "*16:9*"       { @{ Ratio = "16:9"; Resolution = "1920 x 1080 px / 4K"; ColorSpace = "RGB 72 DPI"; Type = "Horizontal Video / YouTube" } }
        "*Print*"      { @{ Ratio = "Custom Print"; Resolution = "300 DPI Vector/PDF"; ColorSpace = "CMYK 300 DPI"; Type = "Physical POSM / Print Banner" } }
        "*E-Commerce*" { @{ Ratio = "Banner"; Resolution = "1200 x 628 px"; ColorSpace = "RGB 72 DPI"; Type = "Web & E-Commerce Header" } }
        default        { @{ Ratio = "Flexible"; Resolution = "Vector / High-Res"; ColorSpace = "RGB 72 DPI"; Type = "General Asset" } }
    }

    $frontmatter = @"
---
filename: $folderName
date: $((Get-Date).ToString("yyyy-MM-dd HH:mm"))
Job ID: $cleanJob
Brand: $cleanSubBrand
Project Name: $cleanProjectName
Designer: $cleanDesigner
Department: $cleanDept
Target Platform: $TargetPlatform
Target Ratio: $($targetSpecInfo.Ratio)
Target Resolution: $($targetSpecInfo.Resolution)
Color Profile: $($targetSpecInfo.ColorSpace)
---
"@

    # Save Project Description / Creative Brief as README.md in project root
    $readmeFile = Join-Path $projectRoot "README.md"
    $readmeBody = if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $Description
    } else {
@"
# Project: $folderName

- **Job ID**: $cleanJob
- **Preset**: $PresetType
- **Sub-Brand**: $cleanSubBrand
- **Designer**: $cleanDesigner ($cleanDept)
- **Created**: $((Get-Date).ToString("yyyy-MM-dd HH:mm"))

## Target Specifications
- **Platform / Format**: $($targetSpecInfo.Type)
- **Aspect Ratio**: $($targetSpecInfo.Ratio)
- **Canvas Resolution**: $($targetSpecInfo.Resolution)
- **Color Profile**: $($targetSpecInfo.ColorSpace)

## Description & Creative Brief
SuamiSihat brand creative assets project directory.
"@
    }
    $readmeContent = "${frontmatter}`r`n`r`n${readmeBody}"
    Set-Content -LiteralPath $readmeFile -Value $readmeContent -Encoding UTF8

    # Inject Starter Master Template File if requested
    if ($InjectTemplates) {
        $mainFolder = Join-Path $projectRoot $subFolders[0]
        $ext = if ($TemplateExtension.StartsWith(".")) { $TemplateExtension } else { ".$TemplateExtension" }
        $canvasFileName = "${folderName}${ext}"
        $canvasFile = Join-Path $mainFolder $canvasFileName
        if (-not (Test-Path -LiteralPath $canvasFile)) {
            New-Item -ItemType File -Path $canvasFile -Force | Out-Null
        }
        $templateNote = Join-Path $mainFolder "_STARTER_CANVAS_README.md"
        $noteText = @"
${frontmatter}

# SuamiSihat Master Canvas Starter File

Project: $folderName
Preset: $PresetType
Master Canvas: $canvasFileName
Designer: $cleanDesigner ($cleanDept)
Created: $((Get-Date).ToString("yyyy-MM-dd HH:mm"))

## Target Specifications:
- **Platform / Format**: $($targetSpecInfo.Type)
- **Aspect Ratio**: $($targetSpecInfo.Ratio)
- **Canvas Resolution**: $($targetSpecInfo.Resolution)
- **Color Profile**: $($targetSpecInfo.ColorSpace)

## Master Canvas Guidelines:
1. Primary Font: Poppins (Bold / Medium / Regular)
2. Secondary Font: Calibri / Helvetica Neue
3. Official Brand Palette: SuamiSihat Blue (#0A192F), Cyan (#007ACC)
4. Export specs: High resolution PNG / PDF / MP4
"@
        Set-Content -LiteralPath $templateNote -Value $noteText -Encoding UTF8
    }

    # Save created project history & auto-increment next Job ID
    $savedState = Save-SuamiSihatAppState `
        -LastProjectPath $projectRoot `
        -LastProjectName $folderName `
        -LastJobNumber $cleanJob `
        -DefaultWorkspace $RootDirectory `
        -PresetType $PresetType

    return @{
        FolderName    = $folderName
        ProjectPath   = $projectRoot
        SubFolders    = $subFolders
        NextJobNumber = $savedState.NextJobNumber
        RecentProjects = $savedState.RecentProjects
    }
}

function Get-SuamiSihatAppStatePath {
    $appDataDir = Join-Path $env:LOCALAPPDATA "SuamiSihat"
    if (-not (Test-Path -LiteralPath $appDataDir)) {
        New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null
    }
    Join-Path $appDataDir "app_state.json"
}

function ConvertTo-SuamiSihatJobID {
    param([string]$JobID)

    if ([string]::IsNullOrWhiteSpace($JobID)) { return "" }
    $clean = ($JobID.Trim().ToUpperInvariant() -replace '[^A-Z0-9-]', '')
    if ($clean -match '^(\d+)([A-Z-]+)$') { return "$($matches[1])$($matches[2])" }
    if ($clean -match '^([A-Z-]+)(\d+)$') { return "$($matches[2])$($matches[1])" }
    return $clean
}

function Get-SuamiSihatBrandKitRegistration {
    $defaultAssetsPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "SuamiSihat Brand Assets"
    $result = @{ IsInstalled = $false; AssetsPath = $defaultAssetsPath; Version = "" }
    try {
        $registryPath = "HKCU:\Software\SuamiSihat\SS-CAM"
        if (Test-Path -LiteralPath $registryPath) {
            $entry = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace([string]$entry.BrandAssetsPath)) {
                $result.AssetsPath = [string]$entry.BrandAssetsPath
            }
            $result.Version = [string]$entry.BrandKitVersion
            $result.IsInstalled = ([int]$entry.BrandKitInstalled -eq 1)
        }
    } catch {}
    if (Test-Path -LiteralPath $result.AssetsPath -PathType Container) {
        $hasBrandContent = @("Colour Palettes", "Libraries", "Logos", "Reports") | Where-Object {
            Test-Path -LiteralPath (Join-Path $result.AssetsPath $_)
        }
        if (@($hasBrandContent).Count -gt 0) { $result.IsInstalled = $true }
    }
    return $result
}

function Set-SuamiSihatBrandKitRegistration {
    param(
        [Parameter(Mandatory = $true)][string]$AssetsPath,
        [string]$Version = "1.9.2"
    )
    if ($WhatIfPreference) { return }
    $registryPath = "HKCU:\Software\SuamiSihat\SS-CAM"
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "BrandKitInstalled" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "BrandAssetsPath" -Value $AssetsPath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name "BrandKitVersion" -Value $Version -PropertyType String -Force | Out-Null
}

function Get-SuamiSihatAppState {
    $stateFile = Get-SuamiSihatAppStatePath
    $currentYear = (Get-Date).ToString("yyyy")
    $defaultDocs = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($defaultDocs)) { $defaultDocs = Join-Path $env:USERPROFILE "Documents" }
    $defaultWorkspace = Join-Path $defaultDocs "Creative Workspace\SS-$currentYear"

    $defaultDesignerName = if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { "SuamiSihat Designer" } else { (Get-Culture).TextInfo.ToTitleCase($env:USERNAME.ToLower()) }
    $defaultDept = "Creative & Brand"
    $defaultEmail = "branding@suamisihat.com"

    if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
        try {
            $json = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            $recent = @()
            if ($json.RecentProjects -and ($json.RecentProjects -is [System.Collections.IEnumerable])) {
                foreach ($item in $json.RecentProjects) {
                    $fName = [string]$item.FolderName
                    if (-not [string]::IsNullOrWhiteSpace($fName)) {
                        $recent += @{
                            FolderName  = $fName
                            ProjectPath = [string]$item.ProjectPath
                            PresetType  = [string]$item.PresetType
                            Created     = [string]$item.Created
                        }
                    }
                }
            }
            $profiles = @()
            if ($json.Profiles -and ($json.Profiles -is [System.Collections.IEnumerable])) {
                foreach ($prof in $json.Profiles) {
                    $pName = [string]$prof.Name
                    if (-not [string]::IsNullOrWhiteSpace($pName)) {
                        $profiles += @{
                            Name       = $pName
                            Department = [string]$prof.Department
                            Email      = [string]$prof.Email
                            AvatarPath = [string]$prof.AvatarPath
                        }
                    }
                }
            }
            if (@($profiles).Count -eq 0) {
                $profiles += @{
                    Name       = $defaultDesignerName
                    Department = $defaultDept
                    Email      = $defaultEmail
                    AvatarPath = ""
                }
            }
            $localPool = @()
            if ($json.LocalJobPool -and ($json.LocalJobPool -is [System.Collections.IEnumerable])) {
                foreach ($id in $json.LocalJobPool) {
                    $sId = [string]$id
                    if (-not [string]::IsNullOrWhiteSpace($sId) -and $sId -ne "System.Management.Automation.PSCustomObject") {
                        $localPool += (ConvertTo-SuamiSihatJobID $sId)
                    }
                }
            }
            $pendingSync = @()
            if ($json.PendingSync -and ($json.PendingSync -is [System.Collections.IEnumerable])) {
                foreach ($item in $json.PendingSync) {
                    $jId = [string]$item.JobID
                    if (-not [string]::IsNullOrWhiteSpace($jId)) {
                        $pendingSync += @{
                            JobID      = ConvertTo-SuamiSihatJobID $jId
                            StaffID    = [string]$item.StaffID
                            FolderName = [string]$item.FolderName
                            Path       = [string]$item.Path
                            PresetType = [string]$item.PresetType
                            Created    = [string]$item.Created
                        }
                    }
                }
            }
            return @{
                LastProjectPath  = [string]$json.LastProjectPath
                LastProjectName  = [string]$json.LastProjectName
                LastJobNumber    = ConvertTo-SuamiSihatJobID ([string]$json.LastJobNumber)
                NextJobNumber    = if ([string]::IsNullOrWhiteSpace([string]$json.NextJobNumber)) { "0001D" } else { ConvertTo-SuamiSihatJobID ([string]$json.NextJobNumber) }
                DefaultWorkspace = if ([string]::IsNullOrWhiteSpace([string]$json.DefaultWorkspace)) { $defaultWorkspace } else { [string]$json.DefaultWorkspace }
                DesignerName     = if ([string]::IsNullOrWhiteSpace([string]$json.DesignerName)) { $defaultDesignerName } else { [string]$json.DesignerName }
                Department       = if ([string]::IsNullOrWhiteSpace([string]$json.Department)) { $defaultDept } else { [string]$json.Department }
                DesignerEmail    = if ([string]::IsNullOrWhiteSpace([string]$json.DesignerEmail)) { $defaultEmail } else { [string]$json.DesignerEmail }
                AvatarPath       = if ([string]::IsNullOrWhiteSpace([string]$json.AvatarPath)) { "" } else { [string]$json.AvatarPath }
                StaffID          = if ([string]::IsNullOrWhiteSpace([string]$json.StaffID)) { "" } else { ([string]$json.StaffID).ToUpper() }
                Profiles         = $profiles
                RecentProjects   = $recent
                LocalJobPool     = $localPool
                PendingSync      = $pendingSync
            }
        } catch {}
    }

    $defaultProfiles = @(
        @{
            Name       = $defaultDesignerName
            Department = $defaultDept
            Email      = $defaultEmail
            AvatarPath = ""
        }
    )

    return @{
        LastProjectPath  = ""
        LastProjectName  = "None"
        LastJobNumber    = ""
        NextJobNumber    = "0001D"
        DefaultWorkspace = $defaultWorkspace
        DesignerName     = $defaultDesignerName
        Department       = $defaultDept
        DesignerEmail    = $defaultEmail
        AvatarPath       = ""
        StaffID          = ""
        Profiles         = $defaultProfiles
        RecentProjects   = @()
        LocalJobPool     = @()
        PendingSync      = @()
    }
}

function Clear-SuamiSihatRecentProjects {
    $stateFile = Get-SuamiSihatAppStatePath
    $state = Get-SuamiSihatAppState

    # Clear only launcher history. Preserve workspace, profile, Job ID pool,
    # pending sync, and every other application setting.
    $state.LastProjectPath = ""
    $state.LastProjectName = "None"
    $state.RecentProjects = @()
    $state.Updated = (Get-Date).ToString("o")

    $json = $state | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $stateFile -Value $json -Encoding UTF8
    return $state
}

function Get-SuamiSihatJobPrefix {
    param([string]$PresetName)
    switch -Wildcard ($PresetName) {
        "*Video*"   { "V" }
        "*Brand*"   { "P" }
        "*Social*"  { "S" }
        default     { "D" }
    }
}

function Save-SuamiSihatAppState {
    param(
        [string]$LastProjectPath = "",
        [string]$LastProjectName = "",
        [string]$LastJobNumber = "",
        [string]$NextJobNumber = "",
        [string]$DefaultWorkspace = "",
        [string]$PresetType = "GraphicDesign",
        [string]$DesignerName = "",
        [string]$Department = "",
        [string]$DesignerEmail = "",
        [string]$AvatarPath = "",
        [string]$StaffID = "",
        [object[]]$Profiles = $null,
        [string[]]$LocalJobPool = $null,
        [object[]]$PendingSync = $null
    )

    $stateFile = Get-SuamiSihatAppStatePath
    $prevState = Get-SuamiSihatAppState
    
    $normalizedLastJob = ConvertTo-SuamiSihatJobID $LastJobNumber
    $nextJob = if ($prevState.NextJobNumber) { ConvertTo-SuamiSihatJobID ([string]$prevState.NextJobNumber) } else { "0001D" }
    if ($normalizedLastJob -match '^(\d+)([A-Za-z\-]+)$') {
        $num = [int]$matches[1] + 1
        $digits = $matches[1].Length
        if ($digits -lt 4) { $digits = 4 }
        $nextJob = $num.ToString().PadLeft($digits, '0') + $matches[2].ToUpper()
    }
    if (-not [string]::IsNullOrWhiteSpace($NextJobNumber)) {
        $nextJob = ConvertTo-SuamiSihatJobID $NextJobNumber
    }

    # Update Recent Projects list (keep top 5)
    $recent = @()
    if (-not [string]::IsNullOrWhiteSpace($LastProjectName) -and $LastProjectName -ne "None") {
        $recent += @{
            FolderName  = $LastProjectName
            ProjectPath = $LastProjectPath
            PresetType  = $PresetType
            Created     = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        }
    }
    if ($prevState.RecentProjects) {
        foreach ($p in $prevState.RecentProjects) {
            if ($p.FolderName -ne $LastProjectName -and @($recent).Count -lt 5) {
                $recent += $p
            }
        }
    }

    $finalDesignerName = if (-not [string]::IsNullOrWhiteSpace($DesignerName)) { $DesignerName } elseif ($prevState.DesignerName) { $prevState.DesignerName } else { $env:USERNAME }
    $finalDepartment   = if (-not [string]::IsNullOrWhiteSpace($Department)) { $Department } elseif ($prevState.Department) { $prevState.Department } else { "Creative & Brand" }
    $finalEmail        = if (-not [string]::IsNullOrWhiteSpace($DesignerEmail)) { $DesignerEmail } elseif ($prevState.DesignerEmail) { $prevState.DesignerEmail } else { "branding@suamisihat.com" }
    $finalAvatar       = if ($null -ne $AvatarPath) { $AvatarPath } else { [string]$prevState.AvatarPath }

    # Sync profiles list as clean array of hashtables
    $cleanProfilesList = @()
    $foundCur = $false

    $sourceProfiles = if ($Profiles -and @($Profiles).Count -gt 0) {
        $Profiles
    } elseif ($prevState.Profiles -and @($prevState.Profiles).Count -gt 0) {
        $prevState.Profiles
    } else {
        @()
    }

    foreach ($p in $sourceProfiles) {
        $pName = [string]$p.Name
        if ([string]::IsNullOrWhiteSpace($pName)) { continue }
        if ($pName -eq $finalDesignerName) {
            $cleanProfilesList += @{
                Name       = $finalDesignerName
                Department = $finalDepartment
                Email      = $finalEmail
                AvatarPath = $finalAvatar
            }
            $foundCur = $true
        } else {
            $cleanProfilesList += @{
                Name       = $pName
                Department = [string]$p.Department
                Email      = [string]$p.Email
                AvatarPath = [string]$p.AvatarPath
            }
        }
    }

    if (-not $foundCur -and -not [string]::IsNullOrWhiteSpace($finalDesignerName)) {
        $cleanProfilesList += @{
            Name       = $finalDesignerName
            Department = $finalDepartment
            Email      = $finalEmail
            AvatarPath = $finalAvatar
        }
    }

    $finalStaffID = if (-not [string]::IsNullOrWhiteSpace($StaffID)) {
        ($StaffID.ToUpper() -replace '[^A-Z0-9]', '').Substring(0, [Math]::Min(5, ($StaffID.ToUpper() -replace '[^A-Z0-9]', '').Length))
    } elseif (-not [string]::IsNullOrWhiteSpace($prevState.StaffID)) {
        $prevState.StaffID
    } else { "" }

    $finalLocalPool = @()
    $rawPool = if ($null -ne $LocalJobPool) { $LocalJobPool } elseif ($prevState.LocalJobPool) { $prevState.LocalJobPool } else { @() }
    foreach ($item in @($rawPool)) {
        $sItem = [string]$item
        if (-not [string]::IsNullOrWhiteSpace($sItem) -and $sItem -ne "System.Management.Automation.PSCustomObject") {
            $finalLocalPool += (ConvertTo-SuamiSihatJobID $sItem)
        }
    }

    $finalPendingSync = @()
    $rawPending = if ($null -ne $PendingSync) { $PendingSync } elseif ($prevState.PendingSync) { $prevState.PendingSync } else { @() }
    foreach ($item in @($rawPending)) {
        if ($item.JobID -and -not [string]::IsNullOrWhiteSpace([string]$item.JobID)) {
            $item.JobID = ConvertTo-SuamiSihatJobID ([string]$item.JobID)
            $finalPendingSync += $item
        }
    }

    $state = @{
        LastProjectPath  = $LastProjectPath
        LastProjectName  = $LastProjectName
        LastJobNumber    = if ($normalizedLastJob) { $normalizedLastJob } else { $prevState.LastJobNumber }
        NextJobNumber    = $nextJob
        DefaultWorkspace = if (-not [string]::IsNullOrWhiteSpace($DefaultWorkspace)) { $DefaultWorkspace } else { $prevState.DefaultWorkspace }
        DesignerName     = $finalDesignerName
        Department       = $finalDepartment
        DesignerEmail    = $finalEmail
        AvatarPath       = $finalAvatar
        StaffID          = $finalStaffID
        Profiles         = $cleanProfilesList
        RecentProjects   = $recent
        LocalJobPool     = $finalLocalPool
        PendingSync      = $finalPendingSync
        Updated          = (Get-Date).ToString("o")
    }

    $json = $state | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $stateFile -Value $json -Encoding UTF8
    return $state
}

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Team NAS Registry Functions (v1.9.2)
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function Get-TeamRegistryPath {
    param([string]$WorkspaceRoot)
    return Join-Path $WorkspaceRoot "_team\team_registry.json"
}

function Test-NASAvailable {
    param([string]$WorkspaceRoot)
    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { return $false }
    try {
        $registryPath = Get-TeamRegistryPath -WorkspaceRoot $WorkspaceRoot
        $teamDir = Split-Path $registryPath -Parent
        # Quick existence check with a short timeout via Test-Path
        return (Test-Path -LiteralPath $teamDir -PathType Container -ErrorAction Stop) -or
               (Test-Path -LiteralPath $WorkspaceRoot -PathType Container -ErrorAction Stop)
    } catch { return $false }
}

function Read-TeamRegistry {
    param([string]$WorkspaceRoot)
    $registryPath = Get-TeamRegistryPath -WorkspaceRoot $WorkspaceRoot
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return @{
            Version           = 1
            GlobalNextCounter = 1
            LastUpdated       = (Get-Date).ToString("o")
            Designers         = @()
            Projects          = @()
        }
    }
    try {
        $json = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $designers = @()
        if ($json.Designers) {
            foreach ($d in $json.Designers) {
                $designers += @{
                    StaffID    = [string]$d.StaffID
                    Name       = [string]$d.Name
                    Department = [string]$d.Department
                    Email      = [string]$d.Email
                    AvatarPath = [string]$d.AvatarPath
                }
            }
        }
        $projects = @()
        if ($json.Projects) {
            foreach ($p in $json.Projects) {
                $projects += @{
                    JobID      = [string]$p.JobID
                    StaffID    = [string]$p.StaffID
                    FolderName = [string]$p.FolderName
                    Path       = [string]$p.Path
                    PresetType = [string]$p.PresetType
                    Created    = [string]$p.Created
                    Synced     = $true
                }
            }
        }
        return @{
            Version           = if ($json.Version) { [int]$json.Version } else { 1 }
            GlobalNextCounter = if ($json.GlobalNextCounter) { [int]$json.GlobalNextCounter } else { 1 }
            LastUpdated       = [string]$json.LastUpdated
            Designers         = $designers
            Projects          = $projects
        }
    } catch {
        return @{
            Version           = 1
            GlobalNextCounter = 1
            LastUpdated       = (Get-Date).ToString("o")
            Designers         = @()
            Projects          = @()
        }
    }
}

function Write-TeamRegistry {
    param(
        [string]$WorkspaceRoot,
        [hashtable]$Registry
    )
    $registryPath = Get-TeamRegistryPath -WorkspaceRoot $WorkspaceRoot
    $teamDir = Split-Path $registryPath -Parent
    $lockPath = "$registryPath.lock"

    New-Item -ItemType Directory -Path $teamDir -Force | Out-Null

    # Acquire lock (wait up to 4 seconds for stale lock)
    $waited = 0
    while ((Test-Path -LiteralPath $lockPath) -and $waited -lt 4000) {
        Start-Sleep -Milliseconds 200
        $waited += 200
    }
    try {
        [IO.File]::WriteAllText($lockPath, (Get-Date).ToString("o"))
        $Registry.LastUpdated = (Get-Date).ToString("o")
        $json = $Registry | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $registryPath -Value $json -Encoding UTF8
    } finally {
        if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
    }
}

function Refill-LocalJobPool {
    # Reserve next N job IDs from NAS registry into local pool
    param(
        [string]$WorkspaceRoot,
        [string]$JobPrefix = "D",
        [int]$PoolSize = 5
    )
    try {
        $registry = Read-TeamRegistry -WorkspaceRoot $WorkspaceRoot
        $counter = [int]$registry.GlobalNextCounter
        $pool = @()
        for ($i = 0; $i -lt $PoolSize; $i++) {
            $pool += ($counter + $i).ToString().PadLeft(4, '0') + $JobPrefix.ToUpperInvariant()
        }
        $registry.GlobalNextCounter = $counter + $PoolSize
        Write-TeamRegistry -WorkspaceRoot $WorkspaceRoot -Registry $registry
        return $pool
    } catch {
        return @()
    }
}

function Claim-NextJobID {
    # Try NAS first; if unavailable, pop from local pool
    param(
        [string]$WorkspaceRoot,
        [string]$JobPrefix = "D",
        [hashtable]$AppState
    )
    $result = @{ JobID = ""; Source = "NAS"; PoolRemaining = 0 }

    if (Test-NASAvailable -WorkspaceRoot $WorkspaceRoot) {
        try {
            $registry = Read-TeamRegistry -WorkspaceRoot $WorkspaceRoot
            $counter = [int]$registry.GlobalNextCounter
            $jobID = $counter.ToString().PadLeft(4, '0') + $JobPrefix.ToUpperInvariant()
            $registry.GlobalNextCounter = $counter + 1
            Write-TeamRegistry -WorkspaceRoot $WorkspaceRoot -Registry $registry

            # Refill local pool if it's running low
            $currentPool = if ($AppState.LocalJobPool) { @($AppState.LocalJobPool) } else { @() }
            if ($currentPool.Count -lt 2) {
                $newPool = @(Refill-LocalJobPool -WorkspaceRoot $WorkspaceRoot -JobPrefix $JobPrefix -PoolSize 5)
                $result.PoolRemaining = $newPool.Count
                # Persist new pool to app state (caller must save)
                $AppState.LocalJobPool = $newPool
            } else {
                $result.PoolRemaining = $currentPool.Count
            }

            $result.JobID = $jobID
            $result.Source = "NAS"
            return $result
        } catch {}
    }

    # NAS unavailable â€” use local pool
    # NOTE: do NOT assign ArrayList via if-else â€” PowerShell pipeline enumerates it,
    # collapsing an empty ArrayList to $null, breaking .Count under Set-StrictMode.
    $pool = [System.Collections.ArrayList]::new()
    foreach ($id in @($AppState.LocalJobPool)) {
        $sId = [string]$id
        if (-not [string]::IsNullOrWhiteSpace($sId)) { [void]$pool.Add($sId) }
    }
    if ($pool.Count -gt 0) {
        $jobID = $pool[0]
        $pool.RemoveAt(0)
        $AppState.LocalJobPool = @($pool)
        $result.JobID = ConvertTo-SuamiSihatJobID ([string]$jobID)
        $result.Source = "Local"
        $result.PoolRemaining = $pool.Count
    } else {
        # Pool exhausted â€” generate a timestamp-based fallback (very rare)
        $result.JobID = (Get-Date).ToString("HHmmss") + $JobPrefix.ToUpperInvariant()
        $result.Source = "Fallback"
        $result.PoolRemaining = 0
    }
    return $result
}

function Register-TeamDesigner {
    # Ensure designer is present in team_registry.json; add if missing
    param(
        [string]$WorkspaceRoot,
        [string]$StaffID,
        [string]$Name,
        [string]$Department = "",
        [string]$Email = "",
        [string]$AvatarPath = ""
    )
    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot) -or [string]::IsNullOrWhiteSpace($StaffID)) { return }
    try {
        $registry = Read-TeamRegistry -WorkspaceRoot $WorkspaceRoot
        $found = $false
        foreach ($d in $registry.Designers) {
            if ($d.StaffID -eq $StaffID) {
                $d.Name = $Name; $d.Department = $Department; $d.Email = $Email
                $found = $true; break
            }
        }
        if (-not $found) {
            $registry.Designers += @{
                StaffID    = $StaffID
                Name       = $Name
                Department = $Department
                Email      = $Email
                AvatarPath = $AvatarPath
            }
        }
        # Ensure designer folder exists
        $designerFolder = Join-Path $WorkspaceRoot $StaffID
        New-Item -ItemType Directory -Path $designerFolder -Force | Out-Null
        Write-TeamRegistry -WorkspaceRoot $WorkspaceRoot -Registry $registry
    } catch {}
}

function Sync-PendingProjects {
    # Upload locally-created (offline) projects to NAS team_registry.json
    param(
        [string]$WorkspaceRoot,
        [hashtable]$AppState
    )
    if (-not (Test-NASAvailable -WorkspaceRoot $WorkspaceRoot)) { return 0 }
    $pending = if ($AppState.PendingSync) { @($AppState.PendingSync) } else { @() }
    if ($pending.Count -eq 0) { return 0 }

    try {
        $registry = Read-TeamRegistry -WorkspaceRoot $WorkspaceRoot
        $synced = 0
        foreach ($proj in $pending) {
            $alreadyExists = $false
            foreach ($rp in $registry.Projects) {
                if ($rp.JobID -eq $proj.JobID -and $rp.StaffID -eq $proj.StaffID) {
                    $alreadyExists = $true; break
                }
            }
            if (-not $alreadyExists) {
                $registry.Projects += @{
                    JobID      = $proj.JobID
                    StaffID    = $proj.StaffID
                    FolderName = $proj.FolderName
                    Path       = $proj.Path
                    PresetType = $proj.PresetType
                    Created    = $proj.Created
                    Synced     = $true
                }
                $synced++
            }
        }
        Write-TeamRegistry -WorkspaceRoot $WorkspaceRoot -Registry $registry
        $AppState.PendingSync = @()
        return $synced
    } catch { return 0 }
}

function Install-SuamiSihatShortcuts {
    param(
        [string]$TargetExePath,
        [string]$Version = "1.9.2"
    )

    if (-not (Test-Path -LiteralPath $TargetExePath -PathType Leaf)) {
        return
    }

    try {
        $wshell = New-Object -ComObject WScript.Shell

        # Start Menu Shortcut
        $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\SuamiSihat"
        New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
        $startShortcutPath = Join-Path $startMenuDir "SuamiSihat Creative Assets Management.lnk"
        $sc = $wshell.CreateShortcut($startShortcutPath)
        $sc.TargetPath = $TargetExePath
        $sc.WorkingDirectory = Split-Path -Parent $TargetExePath
        $sc.Description = "SuamiSihat Creative Assets Management & Project Creator"
        $sc.Save()

        # Desktop Shortcut
        $desktopDir = [Environment]::GetFolderPath("Desktop")
        if (-not [string]::IsNullOrWhiteSpace($desktopDir)) {
            $desktopShortcutPath = Join-Path $desktopDir "SuamiSihat Creative Assets Management.lnk"
            $sc2 = $wshell.CreateShortcut($desktopShortcutPath)
            $sc2.TargetPath = $TargetExePath
            $sc2.WorkingDirectory = Split-Path -Parent $TargetExePath
            $sc2.Description = "SuamiSihat Creative Assets Management & Project Creator"
            $sc2.Save()
        }

        # Windows App Paths (Registered so Win+R or Search finds SS-CAM / SuamiSihat)
        $appPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\SS-CAM.exe"
        New-Item -Path $appPathsKey -Force | Out-Null
        Set-ItemProperty -Path $appPathsKey -Name "(Default)" -Value $TargetExePath
        Set-ItemProperty -Path $appPathsKey -Name "Path" -Value (Split-Path -Parent $TargetExePath)

        # Windows Apps & Features / Add or Remove Programs Registration
        $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SuamiSihatCreativeAssetsManagement"
        New-Item -Path $uninstallKey -Force | Out-Null
        Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "SuamiSihat Creative Assets Management"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value $Version
        Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "SuamiSihat"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $TargetExePath
        Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value (Split-Path -Parent $TargetExePath)
        Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "`"$TargetExePath`" --installer"
        Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -PropertyType DWord
        Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 0 -PropertyType DWord
    } catch {
        # Shortcut creation is non-blocking
    }
}

function Get-SuamiSihatInstalledVersion {
    $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SuamiSihatCreativeAssetsManagement"
    $appPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\SS-CAM.exe"
    $defaultExePath = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management\SS-CAM.exe"
    $exePath = $defaultExePath
    $installLocation = ""

    if (Test-Path -Path $uninstallKey) {
        try {
            $installLocation = [string](Get-ItemProperty -Path $uninstallKey -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
            if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
                $registeredExe = Join-Path $installLocation "SS-CAM.exe"
                if (Test-Path -LiteralPath $registeredExe -PathType Leaf) { $exePath = $registeredExe }
            }
        } catch {}
    }
    if ($exePath -eq $defaultExePath -and (Test-Path -Path $appPathsKey)) {
        try {
            $appPathExe = [string](Get-Item -Path $appPathsKey -ErrorAction SilentlyContinue).GetValue("")
            if (-not [string]::IsNullOrWhiteSpace($appPathExe) -and (Test-Path -LiteralPath $appPathExe -PathType Leaf)) {
                $exePath = $appPathExe
            }
        } catch {}
    }
    
    $installed = Test-Path -LiteralPath $exePath -PathType Leaf
    $version = ""
    
    if (Test-Path -Path $uninstallKey) {
        try {
            $regVersion = (Get-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
            if (-not [string]::IsNullOrWhiteSpace($regVersion)) {
                $version = [string]$regVersion
            }
        } catch {}
    }

    if ($installed -and [string]::IsNullOrWhiteSpace($version)) {
        try {
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion
        } catch {}
        # Don't use a hardcoded fallback â€” leave blank if not determinable
    }

    return [pscustomobject]@{
        IsInstalled = $installed
        Version     = $version
        ExePath     = $exePath
    }
}

function Uninstall-SuamiSihatApp {
    param([switch]$RemoveAppState)

    $installedApp = Get-SuamiSihatInstalledVersion
    $uninstallErrors = [System.Collections.Generic.List[string]]::new()
    try {
        if ($installedApp.ExePath) {
            foreach ($process in @(Get-Process -Name "SS-CAM*" -ErrorAction SilentlyContinue)) {
                try {
                    $runningPath = $process.MainModule.FileName
                    if ($runningPath -and [IO.Path]::GetFullPath($runningPath).Equals([IO.Path]::GetFullPath($installedApp.ExePath), [StringComparison]::OrdinalIgnoreCase)) {
                        $process | Stop-Process -Force -PassThru | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
                    }
                } catch {}
            }
        }
    } catch { $uninstallErrors.Add($_.Exception.Message) }

    try {
        $desktopLnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "SuamiSihat Creative Assets Management.lnk"
        if (Test-Path -LiteralPath $desktopLnk) { Remove-Item -LiteralPath $desktopLnk -Force -ErrorAction SilentlyContinue }

        $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\SuamiSihat"
        if (Test-Path -LiteralPath $startMenuDir) { Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue }

        $appPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\SS-CAM.exe"
        if (Test-Path -Path $appPathsKey) { Remove-Item -Path $appPathsKey -Recurse -Force -ErrorAction SilentlyContinue }

        $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SuamiSihatCreativeAssetsManagement"
        if (Test-Path -Path $uninstallKey) { Remove-Item -Path $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue }
    } catch { $uninstallErrors.Add($_.Exception.Message) }

    try {
        $appInstallDir = if ($installedApp.ExePath) { Split-Path -Parent $installedApp.ExePath } else { Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management" }
        if (Test-Path -LiteralPath $appInstallDir) {
            $resolvedAppDir = [IO.Path]::GetFullPath($appInstallDir).TrimEnd('\')
            $driveRoot = [IO.Path]::GetPathRoot($resolvedAppDir).TrimEnd('\')
            if ($resolvedAppDir -ne $driveRoot -and (Split-Path -Leaf $resolvedAppDir) -eq "SuamiSihat Creative Assets Management") {
                Remove-Item -LiteralPath $resolvedAppDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $parentDir = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat"
        if ((Test-Path -LiteralPath $parentDir) -and (@(Get-ChildItem -LiteralPath $parentDir).Count -eq 0)) {
            Remove-Item -LiteralPath $parentDir -Force -ErrorAction SilentlyContinue
        }
    } catch { $uninstallErrors.Add($_.Exception.Message) }

    if ($RemoveAppState) {
        try {
            $stateFile = Get-SuamiSihatAppStatePath
            if (Test-Path -LiteralPath $stateFile) { Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue }
        } catch { $uninstallErrors.Add($_.Exception.Message) }
    }

    $remainingExe = $installedApp.ExePath -and (Test-Path -LiteralPath $installedApp.ExePath -PathType Leaf)
    return [pscustomobject]@{
        Success         = (-not $remainingExe -and $uninstallErrors.Count -eq 0)
        ExePath         = $installedApp.ExePath
        SettingsRemoved = [bool]$RemoveAppState
        Errors          = @($uninstallErrors)
    }
}

function Get-SuamiSihatLatestRelease {
    param([string]$CurrentVersion = "1.9.9")

    $apiUrls = @(
        "https://api.github.com/repos/SuamiSihat/ss_cam/releases/latest"
    )

    foreach ($url in $apiUrls) {
        try {
            $headers = @{ "User-Agent" = "SuamiSihat-Creative-Assets-Management" }
            $response = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 5 -ErrorAction Stop
            
            $latestTag = [string]$response.tag_name -replace '^v', ''
            $latestVersion = if ([string]::IsNullOrWhiteSpace($latestTag)) { $CurrentVersion } else { $latestTag }
            $htmlUrl = [string]$response.html_url
            $releaseNotes = [string]$response.body
            
            $downloadUrl = ""
            if ($response.assets) {
                $exeAsset = $response.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
                if ($exeAsset) {
                    $downloadUrl = $exeAsset.browser_download_url
                }
            }

            $hasUpdate = $false
            if ($latestVersion -and $CurrentVersion) {
                try {
                    $vCur = [version]$CurrentVersion
                    $vLat = [version]$latestVersion
                    if ($vLat -gt $vCur) { $hasUpdate = $true }
                } catch {
                    if ($latestVersion -ne $CurrentVersion) { $hasUpdate = $true }
                }
            }

            return @{
                HasUpdate      = $hasUpdate
                CurrentVersion = $CurrentVersion
                LatestVersion  = $latestVersion
                ReleaseNotes   = $releaseNotes
                DownloadUrl    = $downloadUrl
                HtmlUrl        = $htmlUrl
                CheckedAt      = (Get-Date).ToString("yyyy-MM-dd HH:mm")
            }
        } catch {}
    }

    return @{
        HasUpdate      = $false
        CurrentVersion = $CurrentVersion
        LatestVersion  = $CurrentVersion
        ReleaseNotes   = "Unable to connect to GitHub releases API."
        DownloadUrl    = ""
        HtmlUrl        = "https://github.com/SuamiSihat/ss_cam/releases"
        CheckedAt      = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    }
}

function Start-SuamiSihatAutoUpdate {
    param([string]$DownloadUrl)

    if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
        throw "No download URL provided for auto-update."
    }

    $tempDir = Join-Path $env:TEMP "SuamiSihatUpdate"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $updateExePath = Join-Path $tempDir "SuamiSihat-Creative-Assets-Management-Update.exe"

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $updateExePath -UseBasicParsing
    if (-not (Test-Path -LiteralPath $updateExePath -PathType Leaf)) {
        throw "Failed to download update package."
    }

    Start-Process -FilePath $updateExePath
    return $updateExePath
}











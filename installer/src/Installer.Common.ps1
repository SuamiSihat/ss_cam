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
        [string]$JobNumber = "D0001",
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
    
    $cleanSubBrand = switch -Wildcard ($SubBrand.Trim()) {
        "*HEALTH*"   { "SSH" }
        "*CLINIC*"   { "SSC" }
        "*WELLNESS*" { "SSW" }
        "*ECOM*"     { "SSE" }
        "*TECH*"     { "SST" }
        "SSH"        { "SSH" }
        "SSC"        { "SSC" }
        "SSW"        { "SSW" }
        "SSE"        { "SSE" }
        "SST"        { "SST" }
        default      { "SS" }
    }

    $cleanYear = if ($Year -match '^\d{4}$') { $Year } else { (Get-Date).ToString("yyyy") }
    $curMonthNum = (Get-Date).ToString("MM")
    $curMonthFull = (Get-Culture).TextInfo.ToTitleCase((Get-Date).ToString("MMMM"))
    $curDay = (Get-Date).ToString("dd")

    $yearFolder = "SS-${cleanYear}"
    $monthFolder = "${cleanYear}${curMonthNum}_${curMonthFull}"
    $dateCode = "${cleanYear}${curMonthNum}"

    $cleanJob = ($JobNumber -replace '\s+', '').ToUpper()
    if ($cleanJob -notmatch '^[A-Z]') {
        $cleanJob = "D$cleanJob"
    }

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

    if ($ExtraSubFolders -and $ExtraSubFolders.Count -gt 0) {
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
            if ($json.RecentProjects) {
                foreach ($item in $json.RecentProjects) {
                    $recent += @{
                        FolderName  = [string]$item.FolderName
                        ProjectPath = [string]$item.ProjectPath
                        PresetType  = [string]$item.PresetType
                        Created     = [string]$item.Created
                    }
                }
            }
            $profiles = @()
            if ($json.Profiles) {
                foreach ($prof in $json.Profiles) {
                    $profiles += @{
                        Name       = [string]$prof.Name
                        Department = [string]$prof.Department
                        Email      = [string]$prof.Email
                        AvatarPath = [string]$prof.AvatarPath
                    }
                }
            }
            if ($profiles.Count -eq 0) {
                $profiles += @{
                    Name       = $defaultDesignerName
                    Department = $defaultDept
                    Email      = $defaultEmail
                    AvatarPath = ""
                }
            }
            return @{
                LastProjectPath  = [string]$json.LastProjectPath
                LastProjectName  = [string]$json.LastProjectName
                LastJobNumber    = [string]$json.LastJobNumber
                NextJobNumber    = if ([string]::IsNullOrWhiteSpace([string]$json.NextJobNumber)) { "D0001" } else { [string]$json.NextJobNumber }
                DefaultWorkspace = if ([string]::IsNullOrWhiteSpace([string]$json.DefaultWorkspace)) { $defaultWorkspace } else { [string]$json.DefaultWorkspace }
                DesignerName     = if ([string]::IsNullOrWhiteSpace([string]$json.DesignerName)) { $defaultDesignerName } else { [string]$json.DesignerName }
                Department       = if ([string]::IsNullOrWhiteSpace([string]$json.Department)) { $defaultDept } else { [string]$json.Department }
                DesignerEmail    = if ([string]::IsNullOrWhiteSpace([string]$json.DesignerEmail)) { $defaultEmail } else { [string]$json.DesignerEmail }
                AvatarPath       = if ([string]::IsNullOrWhiteSpace([string]$json.AvatarPath)) { "" } else { [string]$json.AvatarPath }
                Profiles         = $profiles
                RecentProjects   = $recent
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
        NextJobNumber    = "D0001"
        DefaultWorkspace = $defaultWorkspace
        DesignerName     = $defaultDesignerName
        Department       = $defaultDept
        DesignerEmail    = $defaultEmail
        AvatarPath       = ""
        Profiles         = $defaultProfiles
        RecentProjects   = @()
    }
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
        [string]$LastJobNumber = "D0001",
        [string]$DefaultWorkspace = "",
        [string]$PresetType = "GraphicDesign",
        [string]$DesignerName = "",
        [string]$Department = "",
        [string]$DesignerEmail = "",
        [string]$AvatarPath = "",
        [object[]]$Profiles = $null
    )

    $stateFile = Get-SuamiSihatAppStatePath
    $prevState = Get-SuamiSihatAppState
    
    $prefix = "D"
    $nextJob = "D0002"
    if ($LastJobNumber -match '^([A-Za-z\-]+)(\d+)') {
        $prefix = $matches[1].ToUpper()
        $num = [int]$matches[2] + 1
        $digits = $matches[2].Length
        if ($digits -lt 4) { $digits = 4 }
        $nextJob = "${prefix}" + $num.ToString().PadLeft($digits, '0')
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
            if ($p.FolderName -ne $LastProjectName -and $recent.Count -lt 5) {
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

    $sourceProfiles = if ($Profiles -and $Profiles.Count -gt 0) {
        $Profiles
    } elseif ($prevState.Profiles -and $prevState.Profiles.Count -gt 0) {
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

    $state = @{
        LastProjectPath  = $LastProjectPath
        LastProjectName  = $LastProjectName
        LastJobNumber    = $LastJobNumber
        NextJobNumber    = $nextJob
        DefaultWorkspace = if (-not [string]::IsNullOrWhiteSpace($DefaultWorkspace)) { $DefaultWorkspace } else { $prevState.DefaultWorkspace }
        DesignerName     = $finalDesignerName
        Department       = $finalDepartment
        DesignerEmail    = $finalEmail
        AvatarPath       = $finalAvatar
        Profiles         = $cleanProfilesList
        RecentProjects   = $recent
        Updated          = (Get-Date).ToString("o")
    }

    $json = $state | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $stateFile -Value $json -Encoding UTF8
    return $state
}

function Install-SuamiSihatShortcuts {
    param(
        [string]$TargetExePath,
        [string]$Version = "1.6.2"
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
    $exePath = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management\SS-CAM.exe"
    $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SuamiSihatCreativeAssetsManagement"
    
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
        if ([string]::IsNullOrWhiteSpace($version)) { $version = "1.6.2" }
    }

    return [pscustomobject]@{
        IsInstalled = $installed
        Version     = $version
        ExePath     = $exePath
    }
}

function Uninstall-SuamiSihatApp {
    param([switch]$RemoveAppState)

    try {
        Get-Process -Name "SS-CAM*" -ErrorAction SilentlyContinue | Stop-Process -Force
    } catch {}

    try {
        $desktopLnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "SuamiSihat Creative Assets Management.lnk"
        if (Test-Path -LiteralPath $desktopLnk) { Remove-Item -LiteralPath $desktopLnk -Force -ErrorAction SilentlyContinue }

        $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\SuamiSihat"
        if (Test-Path -LiteralPath $startMenuDir) { Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue }

        $appPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\SS-CAM.exe"
        if (Test-Path -Path $appPathsKey) { Remove-Item -Path $appPathsKey -Recurse -Force -ErrorAction SilentlyContinue }

        $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SuamiSihatCreativeAssetsManagement"
        if (Test-Path -Path $uninstallKey) { Remove-Item -Path $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue }
    } catch {}

    try {
        $appInstallDir = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management"
        if (Test-Path -LiteralPath $appInstallDir) {
            Remove-Item -LiteralPath $appInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $parentDir = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat"
        if ((Test-Path -LiteralPath $parentDir) -and ((Get-ChildItem -LiteralPath $parentDir).Count -eq 0)) {
            Remove-Item -LiteralPath $parentDir -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    if ($RemoveAppState) {
        try {
            $stateFile = Get-SuamiSihatAppStatePath
            if (Test-Path -LiteralPath $stateFile) { Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
}

function Get-SuamiSihatLatestRelease {
    param([string]$CurrentVersion = "1.6.0")

    $apiUrls = @(
        "https://api.github.com/repos/SuamiSihat/SS-Designer-Assets/releases/latest",
        "https://api.github.com/repos/SuamiSihat/SS-Brand-Assets/releases/latest"
    )

    foreach ($url in $apiUrls) {
        try {
            $headers = @{ "User-Agent" = "SuamiSihat-Creative-Assets-Management" }
            $response = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 5 -ErrorAction Stop
            
            $latestTag = [string]$response.tag_name -replace '^v', ''
            $latestVersion = if ([string]::IsNullOrWhiteSpace($latestTag)) { "1.6.0" } else { $latestTag }
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
        HtmlUrl        = "https://github.com/SuamiSihat/SS-Designer-Assets/releases"
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






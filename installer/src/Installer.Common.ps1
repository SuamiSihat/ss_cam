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
        [string[]]$ExtraSubFolders = @(),
        [switch]$InjectTemplates
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
    $curMonthName = (Get-Date).ToString("MMM").ToUpper()
    $monthFolder = "${cleanYear}-${curMonthName}"
    $dateCode = "${cleanYear}${curMonthNum}"

    $cleanJob = ($JobNumber -replace '\s+', '').ToUpper()
    if (-not $cleanJob.StartsWith("D")) {
        $cleanJob = "D$cleanJob"
    }

    $folderName = "${dateCode}_${cleanJob}_${cleanSubBrand}_${cleanProjectName}"
    $monthlyRoot = Join-Path $RootDirectory $monthFolder
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

    # Inject Starter Master Template File if requested
    if ($InjectTemplates) {
        $mainFolder = Join-Path $projectRoot $subFolders[0]
        $templateNote = Join-Path $mainFolder "_STARTER_CANVAS_README.md"
        $noteText = @"
# SuamiSihat Master Canvas Starter File

Project: $folderName
Preset: $PresetType
Created: $((Get-Date).ToString("yyyy-MM-dd HH:mm"))

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
            return @{
                LastProjectPath  = [string]$json.LastProjectPath
                LastProjectName  = [string]$json.LastProjectName
                LastJobNumber    = [string]$json.LastJobNumber
                NextJobNumber    = if ([string]::IsNullOrWhiteSpace([string]$json.NextJobNumber)) { "D0001" } else { [string]$json.NextJobNumber }
                DefaultWorkspace = if ([string]::IsNullOrWhiteSpace([string]$json.DefaultWorkspace)) { $defaultWorkspace } else { [string]$json.DefaultWorkspace }
                RecentProjects   = $recent
            }
        } catch {}
    }

    return @{
        LastProjectPath  = ""
        LastProjectName  = "None"
        LastJobNumber    = ""
        NextJobNumber    = "D0001"
        DefaultWorkspace = $defaultWorkspace
        RecentProjects   = @()
    }
}

function Save-SuamiSihatAppState {
    param(
        [string]$LastProjectPath = "",
        [string]$LastProjectName = "",
        [string]$LastJobNumber = "D0001",
        [string]$DefaultWorkspace = "",
        [string]$PresetType = "GraphicDesign"
    )

    $stateFile = Get-SuamiSihatAppStatePath
    $prevState = Get-SuamiSihatAppState
    
    $nextJob = "D0002"
    if ($LastJobNumber -match '(\d+)') {
        $num = [int]$matches[1] + 1
        $digits = $matches[1].Length
        if ($digits -lt 4) { $digits = 4 }
        $nextJob = "D" + $num.ToString().PadLeft($digits, '0')
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

    $state = @{
        LastProjectPath  = $LastProjectPath
        LastProjectName  = $LastProjectName
        LastJobNumber    = $LastJobNumber
        NextJobNumber    = $nextJob
        DefaultWorkspace = $DefaultWorkspace
        RecentProjects   = $recent
        Updated          = (Get-Date).ToString("o")
    }

    $json = $state | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $stateFile -Value $json -Encoding UTF8
    return $state
}

function Install-SuamiSihatShortcuts {
    param([string]$TargetExePath)

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
        Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.6.0"
        Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "SuamiSihat"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $TargetExePath
        Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value (Split-Path -Parent $TargetExePath)
        Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "`"$TargetExePath`" --installer"
        Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -PropertyType DWord
        Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -PropertyType DWord
    } catch {
        # Shortcut creation is non-blocking
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






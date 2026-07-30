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
        [string]$Year = ""
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

    $cleanJob = ($JobNumber -replace '\s+', '').ToUpper()
    if (-not $cleanJob.StartsWith("D")) {
        $cleanJob = "D$cleanJob"
    }

    $folderName = "${dateCode}_${cleanJob}_${cleanSubBrand}_${cleanProjectName}"
    $projectRoot = Join-Path $RootDirectory $folderName

    $subFolders = switch -Wildcard ($PresetType) {
        "*Social*"  { @("Working Files", "Source Assets", "Copywriting", "Final Exports") }
        "*Video*"   { @("Project Files", "Footage", "Audio", "Renders", "Final Exports") }
        "*Brand*"   { @("Vector Master", "Brand Guidelines", "Colour Palettes", "Export Packages") }
        default     { @("Artwork Design", "Artwork Mockup", "Assets", "Production") }
    }

    foreach ($subFolder in $subFolders) {
        $path = Join-Path $projectRoot $subFolder
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    # Save created project history & auto-increment next Job ID
    $savedState = Save-SuamiSihatAppState `
        -LastProjectPath $projectRoot `
        -LastProjectName $folderName `
        -LastJobNumber $cleanJob `
        -DefaultWorkspace $RootDirectory

    return @{
        FolderName   = $folderName
        ProjectPath  = $projectRoot
        SubFolders   = $subFolders
        NextJobNumber = $savedState.NextJobNumber
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
            return @{
                LastProjectPath  = [string]$json.LastProjectPath
                LastProjectName  = [string]$json.LastProjectName
                LastJobNumber    = [string]$json.LastJobNumber
                NextJobNumber    = if ([string]::IsNullOrWhiteSpace([string]$json.NextJobNumber)) { "D0075" } else { [string]$json.NextJobNumber }
                DefaultWorkspace = if ([string]::IsNullOrWhiteSpace([string]$json.DefaultWorkspace)) { $defaultWorkspace } else { [string]$json.DefaultWorkspace }
            }
        } catch {}
    }

    return @{
        LastProjectPath  = ""
        LastProjectName  = "None"
        LastJobNumber    = "D0074"
        NextJobNumber    = "D0075"
        DefaultWorkspace = $defaultWorkspace
    }
}

function Save-SuamiSihatAppState {
    param(
        [string]$LastProjectPath = "",
        [string]$LastProjectName = "",
        [string]$LastJobNumber = "D0074",
        [string]$DefaultWorkspace = ""
    )

    $stateFile = Get-SuamiSihatAppStatePath
    
    $nextJob = "D0075"
    if ($LastJobNumber -match '(\d+)') {
        $num = [int]$matches[1] + 1
        $digits = $matches[1].Length
        if ($digits -lt 4) { $digits = 4 }
        $nextJob = "D" + $num.ToString().PadLeft($digits, '0')
    }

    $state = @{
        LastProjectPath  = $LastProjectPath
        LastProjectName  = $LastProjectName
        LastJobNumber    = $LastJobNumber
        NextJobNumber    = $nextJob
        DefaultWorkspace = $DefaultWorkspace
        Updated          = (Get-Date).ToString("o")
    }

    $json = $state | ConvertTo-Json
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
    } catch {
        # Shortcut creation is non-blocking
    }
}





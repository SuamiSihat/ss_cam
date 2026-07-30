[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [string]$PreviewPath = "",
    [ValidateRange(0, 7)]
    [int]$PreviewPage = 0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$script:installerProcess = $null
$script:standardOutputTask = $null
$script:standardErrorTask = $null
$script:installationRunning = $false
$script:setupComplete = $false
$script:pageIndex = 0
$script:softwareInventory = @()

$commandLineInstaller = Join-Path $PSScriptRoot "Install-SuamiSihat.ps1"
$commonFunctions = Join-Path $PSScriptRoot "Installer.Common.ps1"
$installerRoot = Split-Path $PSScriptRoot -Parent
$licenceFile = Join-Path $installerRoot "EULA.txt"
$darkLogoFile = Join-Path $installerRoot "assets\suamisihat-logo-on-dark-ui.png"
$lightLogoFile = Join-Path $installerRoot "assets\suamisihat-logo-on-light-ui.png"

foreach ($requiredFile in @($commandLineInstaller, $commonFunctions, $licenceFile, $darkLogoFile, $lightLogoFile)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        [Windows.Forms.MessageBox]::Show(
            "A required installer file is missing:`n$requiredFile",
            "SuamiSihat Designer Assets Installer",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }
}
. $commonFunctions

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height = 24
    )

    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object Drawing.Point($X, $Y)
    $label.Size = New-Object Drawing.Size($Width, $Height)
    $label
}

function New-Page {
    $page = New-Object Windows.Forms.Panel
    $page.Location = New-Object Drawing.Point(20, 108)
    $page.Size = New-Object Drawing.Size(720, 500)
    $page.BackColor = [Drawing.Color]::White
    $page.Visible = $false
    $page
}

function Quote-ProcessArgument {
    param([string]$Value)
    if ($Value.Contains('"')) {
        throw "Paths containing double-quote characters are not supported."
    }
    '"' + $Value + '"'
}

function Open-VendorSetupPage {
    param([string]$Url)
    try {
        Start-Process -FilePath $Url
    } catch {
        [Windows.Forms.MessageBox]::Show(
            "Windows could not open the official setup page:`n$Url`n`n$($_.Exception.Message)",
            "Unable to open download",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
}

$documentsDirectory = [Environment]::GetFolderPath("MyDocuments")
if ([string]::IsNullOrWhiteSpace($documentsDirectory)) {
    $documentsDirectory = Join-Path $env:USERPROFILE "Documents"
}
$defaultDestination = Join-Path $documentsDirectory "SuamiSihat Brand Assets"
$systemInformation = Get-WorkstationInformation
$darkLogoImage = [Drawing.Image]::FromFile($darkLogoFile)
$lightLogoImage = [Drawing.Image]::FromFile($lightLogoFile)

$form = New-Object Windows.Forms.Form
$form.Text = "SuamiSihat Designer Assets Installer"
$form.ClientSize = New-Object Drawing.Size(760, 690)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [Drawing.Color]::FromArgb(244, 247, 251)
$form.Font = New-Object Drawing.Font("Segoe UI", 9)

$header = New-Object Windows.Forms.Panel
$header.Location = New-Object Drawing.Point(0, 0)
$header.Size = New-Object Drawing.Size(760, 92)
$header.BackColor = [Drawing.Color]::FromArgb(2, 32, 87)
$form.Controls.Add($header)

$headerLogo = New-Object Windows.Forms.PictureBox
$headerLogo.Location = New-Object Drawing.Point(14, 1)
$headerLogo.Size = New-Object Drawing.Size(294, 78)
$headerLogo.SizeMode = "Zoom"
$headerLogo.Image = $darkLogoImage
$header.Controls.Add($headerLogo)

$title = New-Label -Text "Designer Assets Installer" -X 326 -Y 14 -Width 405 -Height 34
$title.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$title.ForeColor = [Drawing.Color]::White
$header.Controls.Add($title)

$stepLabel = New-Label -Text "" -X 329 -Y 54 -Width 400 -Height 24
$stepLabel.ForeColor = [Drawing.Color]::FromArgb(109, 198, 236)
$header.Controls.Add($stepLabel)

$headerAccent = New-Object Windows.Forms.Panel
$headerAccent.Location = New-Object Drawing.Point(0, 88)
$headerAccent.Size = New-Object Drawing.Size(760, 4)
$headerAccent.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
$header.Controls.Add($headerAccent)

$pages = New-Object Collections.ArrayList

# Page 1: Welcome
$welcomePage = New-Page
[void]$pages.Add($welcomePage)
$welcomeLogo = New-Object Windows.Forms.PictureBox
$welcomeLogo.Location = New-Object Drawing.Point(20, 12)
$welcomeLogo.Size = New-Object Drawing.Size(330, 96)
$welcomeLogo.SizeMode = "Zoom"
$welcomeLogo.Image = $lightLogoImage
$welcomePage.Controls.Add($welcomeLogo)
$welcomeIntro = New-Label -Text "Prepare this Windows PC for SuamiSihat design work." -X 30 -Y 119 -Width 650 -Height 30
$welcomeIntro.Font = New-Object Drawing.Font("Segoe UI", 12)
$welcomeIntro.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$welcomePage.Controls.Add($welcomeIntro)
$welcomeBody = New-Label -Text @"
This guided installer will:

  - compare this PC with the minimum and recommended design specification;
  - show and record acceptance of the internal-use licence;
  - collect basic PC information for a local Markdown report;
  - detect Affinity, Canva, Figma, Creative Cloud, Photoshop, and Illustrator;
  - direct you to official vendor setup when required;
  - install the selected SuamiSihat fonts for your Windows account;
  - create a structured brand-assets folder at your chosen location;
  - save a standardized font inventory and workstation report.

Close Affinity and Adobe applications before continuing.
"@ -X 32 -Y 161 -Width 650 -Height 260
$welcomeBody.Font = New-Object Drawing.Font("Segoe UI", 10)
$welcomePage.Controls.Add($welcomeBody)
$welcomePrivacy = New-Label -Text "PC information remains local and is not transmitted by this installer." -X 32 -Y 442 -Width 650
$welcomePrivacy.ForeColor = [Drawing.Color]::DimGray
$welcomePage.Controls.Add($welcomePrivacy)

# Page 2: PC requirements
$requirementsPage = New-Page
[void]$pages.Add($requirementsPage)
$requirementsTitle = New-Label -Text "PC compatibility check" -X 24 -Y 16 -Width 670 -Height 34
$requirementsTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$requirementsTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$requirementsPage.Controls.Add($requirementsTitle)
$requirementsIntro = New-Label -Text "Before accepting the licence, compare this PC with the SuamiSihat design-workstation target." -X 27 -Y 55 -Width 660 -Height 28
$requirementsPage.Controls.Add($requirementsIntro)
$requirementsMachine = New-Label -Text (
    "$($systemInformation.Manufacturer) $($systemInformation.Model)`r`n" +
    "$($systemInformation.Windows)"
) -X 27 -Y 86 -Width 660 -Height 47
$requirementsMachine.ForeColor = [Drawing.Color]::FromArgb(55, 65, 70)
$requirementsPage.Controls.Add($requirementsMachine)

$requirementsList = New-Object Windows.Forms.ListView
$requirementsList.Location = New-Object Drawing.Point(26, 141)
$requirementsList.Size = New-Object Drawing.Size(668, 270)
$requirementsList.View = "Details"
$requirementsList.FullRowSelect = $true
$requirementsList.GridLines = $true
$requirementsList.HeaderStyle = "Nonclickable"
$requirementsList.ShowItemToolTips = $true
$requirementsList.Font = New-Object Drawing.Font("Segoe UI", 8.5)
[void]$requirementsList.Columns.Add("Status", 55)
[void]$requirementsList.Columns.Add("Component", 105)
[void]$requirementsList.Columns.Add("Detected", 250)
[void]$requirementsList.Columns.Add("SuamiSihat target", 230)
$requirementsPage.Controls.Add($requirementsList)

$requirementsNote = New-Label -Text "Minimum: Windows 10+ 64-bit and 16 GB RAM. Recommended rows guide performance and do not block installation." -X 27 -Y 423 -Width 660 -Height 48
$requirementsNote.ForeColor = [Drawing.Color]::DimGray
$requirementsPage.Controls.Add($requirementsNote)

# Page 3: Licence
$licencePage = New-Page
[void]$pages.Add($licencePage)
$licenceTitle = New-Label -Text "Licence agreement" -X 24 -Y 18 -Width 660 -Height 34
$licenceTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$licenceTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$licencePage.Controls.Add($licenceTitle)
$licenceText = New-Object Windows.Forms.RichTextBox
$licenceText.Location = New-Object Drawing.Point(25, 62)
$licenceText.Size = New-Object Drawing.Size(670, 355)
$licenceText.ReadOnly = $true
$licenceText.BackColor = [Drawing.Color]::White
$licenceText.Text = Get-Content -LiteralPath $licenceFile -Raw
$licencePage.Controls.Add($licenceText)
$acceptLicence = New-Object Windows.Forms.CheckBox
$acceptLicence.Text = "I have read and accept the licence agreement."
$acceptLicence.Location = New-Object Drawing.Point(27, 438)
$acceptLicence.Size = New-Object Drawing.Size(620, 28)
$acceptLicence.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$licencePage.Controls.Add($acceptLicence)

# Page 4: Design software readiness
$systemPage = New-Page
[void]$pages.Add($systemPage)
$systemTitle = New-Label -Text "Design-software readiness" -X 24 -Y 16 -Width 670 -Height 34
$systemTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$systemTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$systemPage.Controls.Add($systemTitle)

$softwareList = New-Object Windows.Forms.ListView
$softwareList.Location = New-Object Drawing.Point(26, 64)
$softwareList.Size = New-Object Drawing.Size(668, 271)
$softwareList.View = "Details"
$softwareList.FullRowSelect = $true
$softwareList.GridLines = $true
[void]$softwareList.Columns.Add("Application", 260)
[void]$softwareList.Columns.Add("Status", 145)
[void]$softwareList.Columns.Add("Version", 225)
$systemPage.Controls.Add($softwareList)

$softwareNote = New-Label -Text "Shared design account: branding@suamisihat.com. Request the current password and OTP from the team lead. Missing applications use their official vendor setup; sign in, then select Rescan." -X 27 -Y 338 -Width 660 -Height 48
$softwareNote.ForeColor = [Drawing.Color]::DimGray
$systemPage.Controls.Add($softwareNote)

$affinityDownload = New-Object Windows.Forms.Button
$affinityDownload.Text = "Get Affinity"
$affinityDownload.Location = New-Object Drawing.Point(27, 392)
$affinityDownload.Size = New-Object Drawing.Size(135, 34)
$systemPage.Controls.Add($affinityDownload)

$adobeDownload = New-Object Windows.Forms.Button
$adobeDownload.Text = "Get Adobe apps"
$adobeDownload.Location = New-Object Drawing.Point(172, 392)
$adobeDownload.Size = New-Object Drawing.Size(145, 34)
$systemPage.Controls.Add($adobeDownload)

$canvaDownload = New-Object Windows.Forms.Button
$canvaDownload.Text = "Get Canva"
$canvaDownload.Location = New-Object Drawing.Point(327, 392)
$canvaDownload.Size = New-Object Drawing.Size(115, 34)
$systemPage.Controls.Add($canvaDownload)

$figmaDownload = New-Object Windows.Forms.Button
$figmaDownload.Text = "Get Figma"
$figmaDownload.Location = New-Object Drawing.Point(452, 392)
$figmaDownload.Size = New-Object Drawing.Size(115, 34)
$systemPage.Controls.Add($figmaDownload)

$rescanButton = New-Object Windows.Forms.Button
$rescanButton.Text = "Rescan"
$rescanButton.Location = New-Object Drawing.Point(588, 392)
$rescanButton.Size = New-Object Drawing.Size(106, 34)
$systemPage.Controls.Add($rescanButton)

$softwareContinue = New-Label -Text "You may continue with fonts and assets even if optional design software is not installed yet." -X 27 -Y 445 -Width 660 -Height 30
$softwareContinue.ForeColor = [Drawing.Color]::DimGray
$systemPage.Controls.Add($softwareContinue)

# Page 5: Fonts
$fontPage = New-Page
[void]$pages.Add($fontPage)
$fontTitle = New-Label -Text "Font installation" -X 24 -Y 18 -Width 660 -Height 34
$fontTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$fontTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$fontPage.Controls.Add($fontTitle)
$fontIntro = New-Label -Text "Choose which approved typefaces should be available to the current Windows user." -X 27 -Y 64 -Width 650 -Height 28
$fontPage.Controls.Add($fontIntro)
$fontChoice = New-Object Windows.Forms.ComboBox
$fontChoice.Location = New-Object Drawing.Point(27, 108)
$fontChoice.Size = New-Object Drawing.Size(390, 28)
$fontChoice.DropDownStyle = "DropDownList"
[void]$fontChoice.Items.Add("All bundled desktop fonts (recommended)")
[void]$fontChoice.Items.Add("Core brand fonts only")
[void]$fontChoice.Items.Add("Do not install fonts")
$fontChoice.SelectedIndex = 0
$fontPage.Controls.Add($fontChoice)
$fontDetails = New-Label -Text @"
Core brand fonts
Poppins, Calibri, Helvetica Neue, and Montserrat.

All bundled fonts
Core fonts plus approved supporting, icon, barcode, and display typefaces.

Standard
Font files use "Family-Style.ext" names with hyphens instead of spaces and lowercase extensions. A Markdown inventory is written to the Reports folder.

Fonts are installed per user and do not require administrator access.
"@ -X 29 -Y 165 -Width 650 -Height 250
$fontDetails.Font = New-Object Drawing.Font("Segoe UI", 10)
$fontPage.Controls.Add($fontDetails)

# Page 6: Brand assets destination
$assetPage = New-Page
[void]$pages.Add($assetPage)
$assetTitle = New-Label -Text "Brand-assets folder" -X 24 -Y 18 -Width 660 -Height 34
$assetTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$assetTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$assetPage.Controls.Add($assetTitle)
$copyAssets = New-Object Windows.Forms.CheckBox
$copyAssets.Text = "Create and populate the SuamiSihat brand-assets folder"
$copyAssets.Location = New-Object Drawing.Point(27, 69)
$copyAssets.Size = New-Object Drawing.Size(620, 28)
$copyAssets.Checked = $true
$assetPage.Controls.Add($copyAssets)
$destinationLabel = New-Label -Text "Suggested location:" -X 27 -Y 115 -Width 130
$assetPage.Controls.Add($destinationLabel)
$destinationBox = New-Object Windows.Forms.TextBox
$destinationBox.Location = New-Object Drawing.Point(27, 143)
$destinationBox.Size = New-Object Drawing.Size(548, 27)
$destinationBox.Text = $defaultDestination
$assetPage.Controls.Add($destinationBox)
$browseButton = New-Object Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object Drawing.Point(587, 140)
$browseButton.Size = New-Object Drawing.Size(106, 31)
$assetPage.Controls.Add($browseButton)
$folderStructure = New-Label -Text @"
The installer creates:

  Logos\
  Libraries\
  Colour Palettes\
  Links\SuamiSihat web shortcuts
  Reports\SuamiSihat-Workstation-Report.md
  Reports\SuamiSihat-Font-Inventory.md
"@ -X 28 -Y 190 -Width 650 -Height 145
$folderStructure.Font = New-Object Drawing.Font("Consolas", 9.5)
$assetPage.Controls.Add($folderStructure)
$createWebShortcuts = New-Object Windows.Forms.CheckBox
$createWebShortcuts.Text = "Create Service Dashboard and Internal Assets web shortcuts"
$createWebShortcuts.Location = New-Object Drawing.Point(28, 340)
$createWebShortcuts.Size = New-Object Drawing.Size(620, 27)
$createWebShortcuts.Checked = $true
$assetPage.Controls.Add($createWebShortcuts)
$openImports = New-Object Windows.Forms.CheckBox
$openImports.Text = "Open Affinity and Adobe library/palette files after copying"
$openImports.Location = New-Object Drawing.Point(28, 374)
$openImports.Size = New-Object Drawing.Size(620, 27)
$assetPage.Controls.Add($openImports)
$reportNote = New-Label -Text "The Reports folder is local. No PC information or account password is stored or uploaded." -X 29 -Y 414 -Width 630
$reportNote.ForeColor = [Drawing.Color]::DimGray
$assetPage.Controls.Add($reportNote)

# Page 7: Review
$reviewPage = New-Page
[void]$pages.Add($reviewPage)
$reviewTitle = New-Label -Text "Review and install" -X 24 -Y 18 -Width 660 -Height 34
$reviewTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$reviewTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$reviewPage.Controls.Add($reviewTitle)
$reviewChecklist = New-Object Windows.Forms.ListView
$reviewChecklist.Location = New-Object Drawing.Point(27, 68)
$reviewChecklist.Size = New-Object Drawing.Size(666, 350)
$reviewChecklist.View = "Details"
$reviewChecklist.FullRowSelect = $true
$reviewChecklist.GridLines = $true
$reviewChecklist.HeaderStyle = "Nonclickable"
$reviewChecklist.ShowItemToolTips = $true
$reviewChecklist.Font = New-Object Drawing.Font("Segoe UI", 9)
[void]$reviewChecklist.Columns.Add("Ready", 58)
[void]$reviewChecklist.Columns.Add("Checklist item", 180)
[void]$reviewChecklist.Columns.Add("Details", 403)
$reviewPage.Controls.Add($reviewChecklist)
$reviewNote = New-Label -Text "Green checks will be installed or are ready. Red X marks are skipped, missing, or require action." -X 29 -Y 430 -Width 640
$reviewNote.ForeColor = [Drawing.Color]::DimGray
$reviewPage.Controls.Add($reviewNote)

# Page 8: Progress and completion
$progressPage = New-Page
[void]$pages.Add($progressPage)
$progressTitle = New-Label -Text "Installing" -X 24 -Y 18 -Width 660 -Height 34
$progressTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$progressTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$progressPage.Controls.Add($progressTitle)
$progressStatus = New-Label -Text "Preparing setup..." -X 27 -Y 67 -Width 650 -Height 28
$progressStatus.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$progressPage.Controls.Add($progressStatus)
$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location = New-Object Drawing.Point(27, 101)
$progressBar.Size = New-Object Drawing.Size(666, 22)
$progressPage.Controls.Add($progressBar)
$logBox = New-Object Windows.Forms.TextBox
$logBox.Location = New-Object Drawing.Point(27, 145)
$logBox.Size = New-Object Drawing.Size(666, 285)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "Vertical"
$logBox.BackColor = [Drawing.Color]::White
$logBox.Font = New-Object Drawing.Font("Consolas", 8.5)
$progressPage.Controls.Add($logBox)
$completionHint = New-Label -Text "" -X 28 -Y 446 -Width 650 -Height 32
$completionHint.ForeColor = [Drawing.Color]::DimGray
$progressPage.Controls.Add($completionHint)

foreach ($page in $pages) {
    $form.Controls.Add($page)
}

$backButton = New-Object Windows.Forms.Button
$backButton.Text = "< Back"
$backButton.Location = New-Object Drawing.Point(432, 631)
$backButton.Size = New-Object Drawing.Size(94, 34)
$form.Controls.Add($backButton)

$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object Drawing.Point(536, 631)
$cancelButton.Size = New-Object Drawing.Size(94, 34)
$form.Controls.Add($cancelButton)

$nextButton = New-Object Windows.Forms.Button
$nextButton.Text = "Next >"
$nextButton.Location = New-Object Drawing.Point(640, 631)
$nextButton.Size = New-Object Drawing.Size(94, 34)
$nextButton.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$nextButton.ForeColor = [Drawing.Color]::White
$nextButton.FlatStyle = "Flat"
$form.Controls.Add($nextButton)
$form.AcceptButton = $nextButton
$form.CancelButton = $cancelButton

$folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Choose the parent folder for the SuamiSihat brand assets."
$folderBrowser.ShowNewFolderButton = $true

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400

$licencePageIndex = $pages.IndexOf($licencePage)
$assetPageIndex = $pages.IndexOf($assetPage)
$reviewPageIndex = $pages.IndexOf($reviewPage)
$progressPageIndex = $pages.IndexOf($progressPage)

function Add-RequirementChecklistItem {
    param(
        [Parameter(Mandatory = $true)][bool]$Ready,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Detected,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $marker = if ($Ready) { [char]0x2713 } else { [char]0x2715 }
    $item = New-Object Windows.Forms.ListViewItem([string]$marker)
    [void]$item.SubItems.Add($Name)
    [void]$item.SubItems.Add($Detected)
    [void]$item.SubItems.Add($Target)
    $item.UseItemStyleForSubItems = $false
    $item.SubItems[0].ForeColor = if ($Ready) {
        [Drawing.Color]::FromArgb(20, 135, 75)
    } else {
        [Drawing.Color]::FromArgb(194, 45, 55)
    }
    $item.SubItems[1].ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
    $item.SubItems[2].ForeColor = [Drawing.Color]::FromArgb(70, 75, 80)
    $item.SubItems[3].ForeColor = [Drawing.Color]::FromArgb(70, 75, 80)
    $item.ToolTipText = "$Name - Detected: $Detected - Target: $Target"
    [void]$requirementsList.Items.Add($item)
}

function Refresh-PCRequirements {
    $windowsReady = $false
    try {
        $windowsReady = ([version]$systemInformation.WindowsVersion).Major -ge 10
    } catch {}
    $memoryReady = $systemInformation.MemoryGB -is [ValueType] -and [double]$systemInformation.MemoryGB -ge 16
    $architectureReady = $systemInformation.Architecture -eq "X64"
    $processorReady = [int]$systemInformation.ProcessorCores -ge 6
    $graphicsReady = [double]$systemInformation.GraphicsMemoryGB -ge 4
    $storageReady = $systemInformation.SystemDriveFreeGB -is [ValueType] -and [double]$systemInformation.SystemDriveFreeGB -ge 100
    $screenBounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $displayLongEdge = [math]::Max($screenBounds.Width, $screenBounds.Height)
    $displayShortEdge = [math]::Min($screenBounds.Width, $screenBounds.Height)
    $displayReady = $displayLongEdge -ge 1920 -and $displayShortEdge -ge 1080
    $script:minimumRequirementsMet = $windowsReady -and $memoryReady -and $architectureReady

    $requirementsList.BeginUpdate()
    try {
        $requirementsList.Items.Clear()
        Add-RequirementChecklistItem -Ready $windowsReady -Name "Windows" `
            -Detected $systemInformation.Windows -Target "Minimum 10; recommended 11"
        Add-RequirementChecklistItem -Ready $architectureReady -Name "Architecture" `
            -Detected $systemInformation.Architecture -Target "Minimum 64-bit"
        Add-RequirementChecklistItem -Ready $memoryReady -Name "Memory" `
            -Detected "$($systemInformation.MemoryGB) GB RAM" -Target "Minimum 16 GB; recommended 32 GB+"
        Add-RequirementChecklistItem -Ready $processorReady -Name "Processor" `
            -Detected "$($systemInformation.ProcessorCores) cores - $($systemInformation.Processor)" `
            -Target "Recommended 6+ core Core i7 / Ryzen 7"
        Add-RequirementChecklistItem -Ready $graphicsReady -Name "Graphics" `
            -Detected "$($systemInformation.Graphics) ($($systemInformation.GraphicsMemoryGB) GB reported)" `
            -Target "Recommended DirectX 12, 4 GB+ VRAM"
        Add-RequirementChecklistItem -Ready $storageReady -Name "Storage" `
            -Detected "$($systemInformation.SystemDriveFreeGB) GB free on system drive" `
            -Target "Recommended SSD with 100 GB+ free"
        Add-RequirementChecklistItem -Ready $displayReady -Name "Display" `
            -Detected "$($screenBounds.Width) x $($screenBounds.Height)" `
            -Target "Recommended 1920 x 1080+ IPS display"
    } finally {
        $requirementsList.EndUpdate()
    }
}

function Refresh-SoftwareList {
    $softwareList.Items.Clear()
    $script:softwareInventory = @(Get-DesignSoftwareInventory)
    foreach ($software in $script:softwareInventory) {
        $status = if ($software.Installed) { "Installed" } else { "Not detected" }
        $version = if ([string]::IsNullOrWhiteSpace($software.Version)) { "" } else { $software.Version }
        $item = New-Object Windows.Forms.ListViewItem($software.Name)
        [void]$item.SubItems.Add($status)
        [void]$item.SubItems.Add($version)
        if ($software.Installed) {
            $item.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
        } else {
            $item.ForeColor = [Drawing.Color]::FromArgb(189, 154, 115)
        }
        [void]$softwareList.Items.Add($item)
    }
}

function Add-ReviewChecklistItem {
    param(
        [Parameter(Mandatory = $true)][bool]$Ready,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Details
    )

    $marker = if ($Ready) { [char]0x2713 } else { [char]0x2715 }
    $item = New-Object Windows.Forms.ListViewItem([string]$marker)
    [void]$item.SubItems.Add($Name)
    [void]$item.SubItems.Add($Details)
    $item.UseItemStyleForSubItems = $false
    $item.SubItems[0].ForeColor = if ($Ready) {
        [Drawing.Color]::FromArgb(20, 135, 75)
    } else {
        [Drawing.Color]::FromArgb(194, 45, 55)
    }
    $item.SubItems[1].ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
    $item.SubItems[2].ForeColor = [Drawing.Color]::FromArgb(70, 75, 80)
    $item.ToolTipText = "$Name - $Details"
    [void]$reviewChecklist.Items.Add($item)
}

function Update-Review {
    $fontSummary = switch ($fontChoice.SelectedIndex) {
        0 { "All bundled desktop fonts" }
        1 { "Core brand fonts only" }
        default { "Skip font installation" }
    }
    $assetSummary = if ($copyAssets.Checked) {
        "Copy to $($destinationBox.Text.Trim())"
    } else {
        "Skipped by user"
    }
    $shortcutSummary = if ($createWebShortcuts.Checked) {
        "Service Dashboard and Internal Assets"
    } else {
        "Skipped by user"
    }

    $reviewChecklist.BeginUpdate()
    try {
        $reviewChecklist.Items.Clear()
        Add-ReviewChecklistItem -Ready $acceptLicence.Checked `
            -Name "Licence agreement" -Details "Accepted for authorised internal use"
        Add-ReviewChecklistItem -Ready $script:minimumRequirementsMet `
            -Name "Minimum PC specification" -Details "Windows 10+ 64-bit and at least 16 GB RAM"
        Add-ReviewChecklistItem -Ready $true `
            -Name "Shared account" -Details "branding@suamisihat.com"
        Add-ReviewChecklistItem -Ready $false `
            -Name "Password and OTP" -Details "Obtain current credentials from the team lead"

        foreach ($software in $script:softwareInventory) {
            $softwareDetails = if ($software.Installed) {
                if ([string]::IsNullOrWhiteSpace($software.Version)) { "Installed" } else { "Installed - $($software.Version)" }
            } else {
                "Not detected"
            }
            Add-ReviewChecklistItem -Ready $software.Installed `
                -Name $software.Name -Details $softwareDetails
        }

        Add-ReviewChecklistItem -Ready ($fontChoice.SelectedIndex -ne 2) `
            -Name "Fonts" -Details $fontSummary
        Add-ReviewChecklistItem -Ready $copyAssets.Checked `
            -Name "Brand assets" -Details $assetSummary
        Add-ReviewChecklistItem -Ready $createWebShortcuts.Checked `
            -Name "Web shortcuts" -Details $shortcutSummary
        Add-ReviewChecklistItem -Ready $copyAssets.Checked `
            -Name "Local reports" -Details $(if ($copyAssets.Checked) { "Workstation and font inventory Markdown files" } else { "Skipped with brand assets" })
    } finally {
        $reviewChecklist.EndUpdate()
    }
}

function Show-Page {
    param([int]$Index)
    if ($Index -lt 0 -or $Index -ge $pages.Count) {
        return
    }
    foreach ($page in $pages) {
        $page.Visible = $false
    }
    $script:pageIndex = $Index
    $pages[$Index].Visible = $true
    $lastPageIndex = $pages.Count - 1
    $stepLabel.Text = "Step $($Index + 1) of $($pages.Count)"
    $backButton.Visible = $Index -gt 0 -and $Index -lt $lastPageIndex
    $backButton.Enabled = -not $script:installationRunning
    $cancelButton.Visible = -not $script:setupComplete
    $cancelButton.Enabled = -not $script:installationRunning
    $nextButton.Visible = $Index -ne $lastPageIndex
    $nextButton.Enabled = -not $script:installationRunning
    $nextButton.Text = if ($Index -eq $reviewPageIndex) { "Install" } else { "Next >" }
    if ($Index -eq $reviewPageIndex) {
        Update-Review
    }
}

function Start-Installation {
    $arguments = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Quote-ProcessArgument $commandLineInstaller)
    )
    if ($fontChoice.SelectedIndex -eq 2) {
        $arguments += "-SkipFonts"
    } else {
        $fontSet = if ($fontChoice.SelectedIndex -eq 1) { "Core" } else { "All" }
        $arguments += @("-FontSet", $fontSet)
    }
    if ($copyAssets.Checked) {
        $arguments += @("-Destination", (Quote-ProcessArgument $destinationBox.Text.Trim()))
        if ($openImports.Checked) {
            $arguments += "-OpenImportFiles"
        }
    } else {
        $arguments += @("-SkipAssets", "-SkipReports")
    }
    if (-not $createWebShortcuts.Checked) {
        $arguments += "-SkipWebShortcuts"
    }

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = $arguments -join " "
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $PSScriptRoot

    try {
        $script:installerProcess = New-Object Diagnostics.Process
        $script:installerProcess.StartInfo = $startInfo
        if (-not $script:installerProcess.Start()) {
            throw "Windows could not start the setup engine."
        }
        $script:standardOutputTask = $script:installerProcess.StandardOutput.ReadToEndAsync()
        $script:standardErrorTask = $script:installerProcess.StandardError.ReadToEndAsync()
    } catch {
        [Windows.Forms.MessageBox]::Show(
            "Setup could not start:`n$($_.Exception.Message)",
            "SuamiSihat Designer Assets Installer",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    $script:installationRunning = $true
    Show-Page $progressPageIndex
    $stepLabel.Text = "Installing fonts and brand assets"
    $progressTitle.Text = "Installing"
    $progressStatus.Text = "Please wait while the workstation is prepared..."
    $progressStatus.ForeColor = [Drawing.Color]::Black
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 25
    $logBox.Text = "Setup is running. This can take a few minutes..."
    $timer.Start()
}

$affinityDownload.Add_Click({
    Open-VendorSetupPage "https://www.affinity.studio/download"
})
$adobeDownload.Add_Click({
    Open-VendorSetupPage "https://creativecloud.adobe.com/apps/download/creative-cloud"
})
$canvaDownload.Add_Click({
    Open-VendorSetupPage "https://www.canva.com/download/windows/"
})
$figmaDownload.Add_Click({
    Open-VendorSetupPage "https://www.figma.com/downloads/"
})
$rescanButton.Add_Click({
    $rescanButton.Enabled = $false
    $rescanButton.Text = "Scanning..."
    try {
        Refresh-SoftwareList
    } finally {
        $rescanButton.Text = "Rescan"
        $rescanButton.Enabled = $true
    }
})
$copyAssets.Add_CheckedChanged({
    $enabled = $copyAssets.Checked
    $destinationBox.Enabled = $enabled
    $browseButton.Enabled = $enabled
    $openImports.Enabled = $enabled
})
$browseButton.Add_Click({
    $requestedPath = $destinationBox.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($requestedPath)) {
        if (Test-Path -LiteralPath $requestedPath -PathType Container) {
            $folderBrowser.SelectedPath = $requestedPath
        } else {
            $parentPath = Split-Path -Parent $requestedPath
            if (-not [string]::IsNullOrWhiteSpace($parentPath) -and
                (Test-Path -LiteralPath $parentPath -PathType Container)) {
                $folderBrowser.SelectedPath = $parentPath
            }
        }
    }
    if ($folderBrowser.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) {
        $destinationBox.Text = Join-Path $folderBrowser.SelectedPath "SuamiSihat Brand Assets"
    }
})
$backButton.Add_Click({
    if (-not $script:installationRunning) {
        Show-Page ($script:pageIndex - 1)
    }
})
$cancelButton.Add_Click({
    if (-not $script:installationRunning) {
        $form.Close()
    }
})
$nextButton.Add_Click({
    if ($script:pageIndex -eq $licencePageIndex -and -not $acceptLicence.Checked) {
        [Windows.Forms.MessageBox]::Show(
            "You must accept the licence agreement before continuing.",
            "Licence acceptance required",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    if ($script:pageIndex -eq $assetPageIndex -and $copyAssets.Checked -and
        [string]::IsNullOrWhiteSpace($destinationBox.Text)) {
        [Windows.Forms.MessageBox]::Show(
            "Choose where the SuamiSihat brand-assets folder should be created.",
            "Destination required",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    if ($script:pageIndex -eq $reviewPageIndex) {
        Start-Installation
    } else {
        Show-Page ($script:pageIndex + 1)
    }
})

$timer.Add_Tick({
    if ($null -eq $script:installerProcess -or -not $script:installerProcess.HasExited) {
        return
    }

    $timer.Stop()
    $standardOutput = $script:standardOutputTask.Result
    $standardError = $script:standardErrorTask.Result
    $exitCode = $script:installerProcess.ExitCode
    $script:installerProcess.Dispose()
    $script:installerProcess = $null
    $script:standardOutputTask = $null
    $script:standardErrorTask = $null
    $script:installationRunning = $false

    $combinedOutput = ($standardOutput.Trim() + [Environment]::NewLine + $standardError.Trim()).Trim()
    if ([string]::IsNullOrWhiteSpace($combinedOutput)) {
        $combinedOutput = "Setup produced no status output."
    }
    $logBox.Text = $combinedOutput
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
    $progressBar.Style = "Blocks"
    $progressBar.MarqueeAnimationSpeed = 0
    $progressBar.Value = 100

    if ($exitCode -eq 0) {
        $script:setupComplete = $true
        $progressTitle.Text = "Setup complete"
        $progressStatus.Text = "This PC is ready for SuamiSihat design work."
        $progressStatus.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
        $completionHint.Text = "Restart any Affinity or Adobe applications that were open. Select Close to finish."
        $stepLabel.Text = "Completed successfully"
        $cancelButton.Visible = $false
        $nextButton.Visible = $true
        $nextButton.Text = "Close"
        $nextButton.Enabled = $true
        $nextButton.Add_Click({ $form.Close() })
    } else {
        $progressTitle.Text = "Setup encountered an error"
        $progressStatus.Text = "Review the log below, then go back and try again."
        $progressStatus.ForeColor = [Drawing.Color]::Firebrick
        $completionHint.Text = "No rollback is required; the installer is safe to run again."
        $stepLabel.Text = "Action required"
        $backButton.Visible = $true
        $backButton.Enabled = $true
        $cancelButton.Visible = $true
        $cancelButton.Enabled = $true
    }
})

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:installationRunning) {
        $eventArgs.Cancel = $true
        [Windows.Forms.MessageBox]::Show(
            "Setup is still running. Please wait until it finishes.",
            "SuamiSihat Designer Assets Installer",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
})

Refresh-PCRequirements
Refresh-SoftwareList
Show-Page 0

if ($SmokeTest) {
    if (-not [string]::IsNullOrWhiteSpace($PreviewPath)) {
        if ($PreviewPage -eq $reviewPageIndex) {
            $acceptLicence.Checked = $true
        }
        Show-Page $PreviewPage
        $form.StartPosition = "Manual"
        $form.Location = New-Object Drawing.Point(-32000, -32000)
        $form.Show()
        $form.Refresh()
        $previewBitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
        $form.DrawToBitmap($previewBitmap, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
        $previewBitmap.Save($PreviewPath, [Drawing.Imaging.ImageFormat]::Png)
        $previewBitmap.Dispose()
        $form.Hide()
    }
    Write-Output "GUI construction, PC requirements, and software detection: OK"
} else {
    [void]$form.ShowDialog()
}

$timer.Dispose()
$folderBrowser.Dispose()
$darkLogoImage.Dispose()
$lightLogoImage.Dispose()
$form.Dispose()

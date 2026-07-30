[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [string]$PreviewPath = "",
    [ValidateRange(0, 9)]
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
$form.Text = "SuamiSihat Creative Assets Management"
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
$headerLogo.Size = New-Object Drawing.Size(240, 78)
$headerLogo.SizeMode = "Zoom"
$headerLogo.Image = $darkLogoImage
$header.Controls.Add($headerLogo)

$title = New-Label -Text "Creative Assets Management" -X 260 -Y 12 -Width 260 -Height 34
$title.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$title.ForeColor = [Drawing.Color]::White
$header.Controls.Add($title)

$stepLabel = New-Label -Text "" -X 263 -Y 52 -Width 250 -Height 24
$stepLabel.ForeColor = [Drawing.Color]::FromArgb(109, 198, 236)
$header.Controls.Add($stepLabel)

# Header Mode Switcher Buttons
$btnNavProject = New-Object Windows.Forms.Button
$btnNavProject.Text = "Project Creator"
$btnNavProject.Location = New-Object Drawing.Point(440, 14)
$btnNavProject.Size = New-Object Drawing.Size(110, 60)
$btnNavProject.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnNavProject.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
$btnNavProject.ForeColor = [Drawing.Color]::White
$btnNavProject.FlatStyle = "Flat"
$btnNavProject.Cursor = [Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnNavProject)

$btnNavFonts = New-Object Windows.Forms.Button
$btnNavFonts.Text = "Assets Wizard"
$btnNavFonts.Location = New-Object Drawing.Point(555, 14)
$btnNavFonts.Size = New-Object Drawing.Size(95, 60)
$btnNavFonts.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnNavFonts.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnNavFonts.ForeColor = [Drawing.Color]::White
$btnNavFonts.FlatStyle = "Flat"
$btnNavFonts.Cursor = [Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnNavFonts)

$btnNavSettings = New-Object Windows.Forms.Button
$btnNavSettings.Text = "Settings"
$btnNavSettings.Location = New-Object Drawing.Point(655, 14)
$btnNavSettings.Size = New-Object Drawing.Size(87, 60)
$btnNavSettings.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnNavSettings.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnNavSettings.ForeColor = [Drawing.Color]::White
$btnNavSettings.FlatStyle = "Flat"
$btnNavSettings.Cursor = [Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnNavSettings)


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
$machineText = "$($systemInformation.Manufacturer) $($systemInformation.Model)`r`n$($systemInformation.Windows)"
$requirementsMachine = New-Label -Text $machineText -X 27 -Y 86 -Width 660 -Height 47
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

# Load Saved App State
$script:appState = Get-SuamiSihatAppState

# Page 9: Creative Project Folder Creator
$creatorPage = New-Page
[void]$pages.Add($creatorPage)
$creatorPageIndex = $pages.IndexOf($creatorPage)

$creatorTitle = New-Label -Text "Creative Project Folder Creator" -X 24 -Y 10 -Width 670 -Height 28
$creatorTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$creatorTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$creatorPage.Controls.Add($creatorTitle)

$creatorIntro = New-Label -Text "Post Haste-style template presets with history tracking & auto-incrementing Job IDs." -X 27 -Y 38 -Width 660 -Height 20
$creatorPage.Controls.Add($creatorIntro)

# Recent Project Info Box
$lastProjectGroup = New-Object Windows.Forms.GroupBox
$lastProjectGroup.Text = " Last Created Project "
$lastProjectGroup.Location = New-Object Drawing.Point(27, 60)
$lastProjectGroup.Size = New-Object Drawing.Size(667, 50)
$lastProjectGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($lastProjectGroup)

$lastProjectLabel = New-Label -Text $(if ([string]::IsNullOrWhiteSpace($script:appState.LastProjectName)) { "None yet" } else { $script:appState.LastProjectName }) -X 15 -Y 18 -Width 637 -Height 24
$lastProjectLabel.Font = New-Object Drawing.Font("Consolas", 9)
$lastProjectLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$lastProjectGroup.Controls.Add($lastProjectLabel)

# Project Preset Selector
$presetLabel = New-Label -Text "Project Preset Template:" -X 27 -Y 116 -Width 200
$presetLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($presetLabel)

$presetCombo = New-Object Windows.Forms.ComboBox
$presetCombo.Location = New-Object Drawing.Point(27, 138)
$presetCombo.Size = New-Object Drawing.Size(667, 28)
$presetCombo.DropDownStyle = "DropDownList"
@("Graphic & Print Design", "Social Media & E-Commerce", "Video & Motion Graphics", "Brand Identity") | ForEach-Object { [void]$presetCombo.Items.Add($_) }
$presetCombo.SelectedIndex = 0
$creatorPage.Controls.Add($presetCombo)

# Year Selection
$yearLabel = New-Label -Text "Year:" -X 27 -Y 172 -Width 80
$yearLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($yearLabel)

$yearCombo = New-Object Windows.Forms.ComboBox
$yearCombo.Location = New-Object Drawing.Point(27, 194)
$yearCombo.Size = New-Object Drawing.Size(95, 28)
$yearCombo.DropDownStyle = "DropDownList"
$currentYrInt = [int](Get-Date).ToString("yyyy")
(($currentYrInt - 2)..($currentYrInt + 3)) | ForEach-Object { [void]$yearCombo.Items.Add($_) }
$yearCombo.SelectedItem = $currentYrInt
$creatorPage.Controls.Add($yearCombo)

# Sub-Brand Selection
$brandLabel = New-Label -Text "Sub-Brand:" -X 135 -Y 172 -Width 110
$brandLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($brandLabel)

$subBrandCombo = New-Object Windows.Forms.ComboBox
$subBrandCombo.Location = New-Object Drawing.Point(135, 194)
$subBrandCombo.Size = New-Object Drawing.Size(125, 28)
$subBrandCombo.DropDownStyle = "DropDownList"
@("SS", "HEALTH", "CLINIC", "WELLNESS", "ECOM", "TECH") | ForEach-Object { [void]$subBrandCombo.Items.Add($_) }
$subBrandCombo.SelectedIndex = 0
$creatorPage.Controls.Add($subBrandCombo)

# Job ID
$jobLabel = New-Label -Text "Job ID (e.g. D0075):" -X 272 -Y 172 -Width 130
$jobLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($jobLabel)

$jobIdText = New-Object Windows.Forms.TextBox
$jobIdText.Location = New-Object Drawing.Point(272, 194)
$jobIdText.Size = New-Object Drawing.Size(125, 27)
$jobIdText.Text = $script:appState.NextJobNumber
$creatorPage.Controls.Add($jobIdText)

# Project Name
$nameLabel = New-Label -Text "Project Name (e.g. POSM_Banner):" -X 410 -Y 172 -Width 280
$nameLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($nameLabel)

$projectNameText = New-Object Windows.Forms.TextBox
$projectNameText.Location = New-Object Drawing.Point(410, 194)
$projectNameText.Size = New-Object Drawing.Size(284, 27)
$projectNameText.Text = "POSM_Banner"
$creatorPage.Controls.Add($projectNameText)

# Workspace Root Location
$workspaceLabel = New-Label -Text "Parent Workspace Directory:" -X 27 -Y 228 -Width 300
$workspaceLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$creatorPage.Controls.Add($workspaceLabel)

$workspacePathText = New-Object Windows.Forms.TextBox
$workspacePathText.Location = New-Object Drawing.Point(27, 248)
$workspacePathText.Size = New-Object Drawing.Size(548, 27)
$workspacePathText.Text = $script:appState.DefaultWorkspace
$creatorPage.Controls.Add($workspacePathText)

$workspaceBrowseBtn = New-Object Windows.Forms.Button
$workspaceBrowseBtn.Text = "Browse..."
$workspaceBrowseBtn.Location = New-Object Drawing.Point(587, 245)
$workspaceBrowseBtn.Size = New-Object Drawing.Size(107, 31)
$creatorPage.Controls.Add($workspaceBrowseBtn)

# Folder Path Preview Box
$previewGroup = New-Object Windows.Forms.GroupBox
$previewGroup.Text = " Folder Path Preview "
$previewGroup.Location = New-Object Drawing.Point(27, 282)
$previewGroup.Size = New-Object Drawing.Size(667, 58)
$previewGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($previewGroup)

$previewPathLabel = New-Label -Text "" -X 15 -Y 20 -Width 637 -Height 30
$previewPathLabel.Font = New-Object Drawing.Font("Consolas", 8.5)
$previewPathLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$previewGroup.Controls.Add($previewPathLabel)

# Sub-folder Structure Information
$structureGroup = New-Object Windows.Forms.GroupBox
$structureGroup.Text = " Sub-Folders Created for Selected Preset "
$structureGroup.Location = New-Object Drawing.Point(27, 344)
$structureGroup.Size = New-Object Drawing.Size(667, 92)
$structureGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($structureGroup)

$structureInfoLabel = New-Label -Text "" -X 15 -Y 18 -Width 637 -Height 68
$structureInfoLabel.Font = New-Object Drawing.Font("Consolas", 8)
$structureInfoLabel.ForeColor = [Drawing.Color]::FromArgb(70, 75, 80)
$structureGroup.Controls.Add($structureInfoLabel)

# Create Button & Status
$createProjectBtn = New-Object Windows.Forms.Button
$createProjectBtn.Text = "Create Project Folder && Open in File Explorer"
$createProjectBtn.Location = New-Object Drawing.Point(27, 442)
$createProjectBtn.Size = New-Object Drawing.Size(370, 42)
$createProjectBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$createProjectBtn.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$createProjectBtn.ForeColor = [Drawing.Color]::White
$createProjectBtn.FlatStyle = "Flat"
$createProjectBtn.Cursor = [Windows.Forms.Cursors]::Hand
$creatorPage.Controls.Add($createProjectBtn)

$creatorStatusLabel = New-Label -Text "" -X 410 -Y 444 -Width 284 -Height 40
$creatorStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($creatorStatusLabel)

# Page 10: Settings & Maintenance Page
$settingsPage = New-Page
[void]$pages.Add($settingsPage)
$settingsPageIndex = $pages.IndexOf($settingsPage)

$settingsTitle = New-Label -Text "Settings && Asset Maintenance" -X 24 -Y 12 -Width 670 -Height 30
$settingsTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 16)
$settingsTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$settingsPage.Controls.Add($settingsTitle)

$settingsIntro = New-Label -Text "Manage local workspace defaults, Job ID counters, or reinstall official brand assets && fonts." -X 27 -Y 44 -Width 660 -Height 22
$settingsPage.Controls.Add($settingsIntro)

# Group 1: Font & Asset Maintenance
$fontGroup = New-Object Windows.Forms.GroupBox
$fontGroup.Text = " Brand Fonts && Asset Maintenance "
$fontGroup.Location = New-Object Drawing.Point(27, 72)
$fontGroup.Size = New-Object Drawing.Size(667, 100)
$fontGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($fontGroup)

$fontGroupInfo = New-Label -Text "Reinstall or repair official bundled fonts (Poppins, Calibri, Helvetica Neue, Montserrat, FontAwesome Pro, etc.) and sync design libraries." -X 15 -Y 24 -Width 637 -Height 30
$fontGroupInfo.Font = New-Object Drawing.Font("Segoe UI", 9)
$fontGroup.Controls.Add($fontGroupInfo)

$repairFontsBtn = New-Object Windows.Forms.Button
$repairFontsBtn.Text = "Reinstall / Repair Fonts && Brand Assets"
$repairFontsBtn.Location = New-Object Drawing.Point(15, 56)
$repairFontsBtn.Size = New-Object Drawing.Size(270, 32)
$repairFontsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$repairFontsBtn.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$repairFontsBtn.ForeColor = [Drawing.Color]::White
$repairFontsBtn.FlatStyle = "Flat"
$repairFontsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$fontGroup.Controls.Add($repairFontsBtn)

# Group 2: App & History Settings
$appGroup = New-Object Windows.Forms.GroupBox
$appGroup.Text = " Workspace && Sequential Counter Defaults "
$appGroup.Location = New-Object Drawing.Point(27, 185)
$appGroup.Size = New-Object Drawing.Size(667, 240)
$appGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($appGroup)

$setWorkspaceLabel = New-Label -Text "Default Parent Workspace Directory:" -X 15 -Y 24 -Width 300
$appGroup.Controls.Add($setWorkspaceLabel)

$setWorkspaceText = New-Object Windows.Forms.TextBox
$setWorkspaceText.Location = New-Object Drawing.Point(15, 48)
$setWorkspaceText.Size = New-Object Drawing.Size(520, 27)
$setWorkspaceText.Text = $script:appState.DefaultWorkspace
$appGroup.Controls.Add($setWorkspaceText)

$setWorkspaceBrowseBtn = New-Object Windows.Forms.Button
$setWorkspaceBrowseBtn.Text = "Browse..."
$setWorkspaceBrowseBtn.Location = New-Object Drawing.Point(543, 45)
$setWorkspaceBrowseBtn.Size = New-Object Drawing.Size(107, 31)
$appGroup.Controls.Add($setWorkspaceBrowseBtn)

$setJobLabel = New-Label -Text "Next Sequential Job ID Counter (e.g. D0075):" -X 15 -Y 88 -Width 300
$appGroup.Controls.Add($setJobLabel)

$setJobText = New-Object Windows.Forms.TextBox
$setJobText.Location = New-Object Drawing.Point(15, 110)
$setJobText.Size = New-Object Drawing.Size(200, 27)
$setJobText.Text = $script:appState.NextJobNumber
$appGroup.Controls.Add($setJobText)

$lastProjSettingsLabel = New-Label -Text "Last Created Project: $(if ([string]::IsNullOrWhiteSpace($script:appState.LastProjectName)) { 'None' } else { $script:appState.LastProjectName })" -X 15 -Y 150 -Width 630 -Height 24
$lastProjSettingsLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$appGroup.Controls.Add($lastProjSettingsLabel)

$saveSettingsBtn = New-Object Windows.Forms.Button
$saveSettingsBtn.Text = "Save Settings"
$saveSettingsBtn.Location = New-Object Drawing.Point(15, 186)
$saveSettingsBtn.Size = New-Object Drawing.Size(160, 34)
$saveSettingsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$saveSettingsBtn.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
$saveSettingsBtn.ForeColor = [Drawing.Color]::White
$saveSettingsBtn.FlatStyle = "Flat"
$saveSettingsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$appGroup.Controls.Add($saveSettingsBtn)

$settingsStatusLabel = New-Label -Text "" -X 190 -Y 190 -Width 450 -Height 24
$settingsStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$appGroup.Controls.Add($settingsStatusLabel)

# Event Handlers for Creator Page
$updatePreview = {
    $selYear = if ($yearCombo.SelectedItem) { [string]$yearCombo.SelectedItem } else { (Get-Date).ToString("yyyy") }
    $curMonth = (Get-Date).ToString("MM")
    $dateCode = "${selYear}${curMonth}"

    if ($workspacePathText.Text -match '\\Creative Workspace\\SS-\d{4}$') {
        $workspacePathText.Text = $workspacePathText.Text -replace 'SS-\d{4}$', "SS-$selYear"
    }

    $sub = ($subBrandCombo.SelectedItem -replace '\s+', '_').ToUpper()
    $job = ($jobIdText.Text.Trim() -replace '\s+', '').ToUpper()
    if (-not $job.StartsWith("D")) { $job = "D$job" }
    $proj = ($projectNameText.Text.Trim() -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($proj)) { $proj = "Project" }
    
    $folderName = "${dateCode}_${job}_${sub}_${proj}"
    $targetPath = Join-Path $workspacePathText.Text.Trim() $folderName
    $previewPathLabel.Text = $targetPath

    $structureInfoLabel.Text = switch -Wildcard ($presetCombo.SelectedItem) {
        "*Social*"  { "  |-- Working Files/      (Source graphics, PSD, Affinity files)`r`n  |-- Source Assets/      (Raw images, photos & brand assets)`r`n  |-- Copywriting/        (Post text, captions & ad copy)`r`n  \-- Final Exports/      (PNG, JPG, MP4 web/ad outputs)" }
        "*Video*"   { "  |-- Project Files/      (Premiere, After Effects, DaVinci projects)`r`n  |-- Footage/            (Raw video clips & B-roll)`r`n  |-- Audio/              (Music, voiceover & SFX)`r`n  |-- Renders/            (Intermediate cache & motion graphics)`r`n  \-- Final Exports/      (Master MP4, MOV video files)" }
        "*Brand*"   { "  |-- Vector Master/      (Master logo files: SVG, EPS, AI)`r`n  |-- Brand Guidelines/   (PDF brand books & usage guides)`r`n  |-- Colour Palettes/   (ASE, AFPALETTE color files)`r`n  \-- Export Packages/    (Complete client zip assets)" }
        default     { "  |-- Artwork Design/      (Editable source files: .afdesign, .psd, .ai)`r`n  |-- Artwork Mockup/      (Previews, client mockups & presentation files)`r`n  |-- Assets/              (Raw images, stock photos, icons & reference files)`r`n  \-- Production/          (Final approved print & digital exports: PDF, PNG, SVG)" }
    }
}

$presetCombo.Add_SelectedIndexChanged($updatePreview)
$yearCombo.Add_SelectedIndexChanged($updatePreview)
$subBrandCombo.Add_SelectedIndexChanged($updatePreview)
$jobIdText.Add_TextChanged($updatePreview)
$projectNameText.Add_TextChanged($updatePreview)
$workspacePathText.Add_TextChanged($updatePreview)
&$updatePreview

$workspaceBrowseBtn.Add_Click({
    $folderBrowser.SelectedPath = $workspacePathText.Text
    if ($folderBrowser.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $workspacePathText.Text = $folderBrowser.SelectedPath
    }
})

$createProjectBtn.Add_Click({
    try {
        $result = New-SuamiSihatProjectFolder `
            -RootDirectory $workspacePathText.Text.Trim() `
            -SubBrand $subBrandCombo.SelectedItem `
            -JobNumber $jobIdText.Text.Trim() `
            -ProjectName $projectNameText.Text.Trim() `
            -PresetType $presetCombo.SelectedItem `
            -Year ([string]$yearCombo.SelectedItem)
        
        $script:appState = Get-SuamiSihatAppState
        $lastProjectLabel.Text = $result.FolderName
        $lastProjSettingsLabel.Text = "Last Created Project: $($result.FolderName)"
        $jobIdText.Text = $result.NextJobNumber
        $setJobText.Text = $result.NextJobNumber

        $creatorStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $creatorStatusLabel.Text = "Project Created! Next Job: $($result.NextJobNumber)`r`nOpening File Explorer..."
        
        # Open in Explorer
        Start-Process -FilePath "explorer.exe" -ArgumentList (Quote-ProcessArgument $result.ProjectPath)
    } catch {
        $creatorStatusLabel.ForeColor = [Drawing.Color]::Firebrick
        $creatorStatusLabel.Text = "Error: $($_.Exception.Message)"
    }
})

# Settings Page Handlers
$repairFontsBtn.Add_Click({
    Show-Page 0
})

$setWorkspaceBrowseBtn.Add_Click({
    $folderBrowser.SelectedPath = $setWorkspaceText.Text
    if ($folderBrowser.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $setWorkspaceText.Text = $folderBrowser.SelectedPath
    }
})

$saveSettingsBtn.Add_Click({
    try {
        $script:appState = Save-SuamiSihatAppState `
            -LastProjectPath $script:appState.LastProjectPath `
            -LastProjectName $script:appState.LastProjectName `
            -LastJobNumber $setJobText.Text.Trim() `
            -DefaultWorkspace $setWorkspaceText.Text.Trim()

        $jobIdText.Text = $script:appState.NextJobNumber
        $workspacePathText.Text = $script:appState.DefaultWorkspace
        $settingsStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $settingsStatusLabel.Text = "Settings saved successfully!"
    } catch {
        $settingsStatusLabel.ForeColor = [Drawing.Color]::Firebrick
        $settingsStatusLabel.Text = "Error saving settings: $($_.Exception.Message)"
    }
})

$btnNavFonts.Add_Click({
    Show-Page 0
})

$btnNavProject.Add_Click({
    Show-Page $creatorPageIndex
})

$btnNavSettings.Add_Click({
    Show-Page $settingsPageIndex
})


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
    
    if ($Index -eq $creatorPageIndex) {
        $stepLabel.Text = "Creative Project Creator"
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Text = "Close"
        $cancelButton.Visible = $true
        $btnNavProject.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
        $btnNavFonts.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
        $btnNavSettings.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
        return
    }

    if ($Index -eq $settingsPageIndex) {
        $stepLabel.Text = "Settings and Maintenance"
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Text = "Close"
        $cancelButton.Visible = $true
        $btnNavSettings.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
        $btnNavProject.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
        $btnNavFonts.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
        return
    }

    $btnNavFonts.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
    $btnNavProject.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
    $btnNavSettings.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)

    $wizardPagesCount = 8
    $lastPageIndex = $wizardPagesCount - 1
    $stepLabel.Text = "Step $($Index + 1) of $wizardPagesCount"
    $backButton.Visible = $Index -gt 0 -and $Index -lt $lastPageIndex
    $backButton.Enabled = -not $script:installationRunning
    $cancelButton.Text = "Cancel"
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
Show-Page $creatorPageIndex

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

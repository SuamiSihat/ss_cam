[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [switch]$InstallerMode,
    [string]$InstallerExePath = "",
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
$script:copyTimer = $null

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

# Taskbar & Form Icon Integration
$iconFile = Join-Path $installerRoot "payload\Brand Assets\Logos\ss_favicon\favicon.ico"
if (Test-Path -LiteralPath $iconFile -PathType Leaf) {
    try {
        $form.Icon = New-Object Drawing.Icon($iconFile)
    } catch {}
}

try {
    $typeDefinition = @"
using System;
using System.Runtime.InteropServices;
public class Win32Taskbar {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);
}
"@
    Add-Type -TypeDefinition $typeDefinition -ErrorAction SilentlyContinue
    [Win32Taskbar]::SetCurrentProcessExplicitAppUserModelID("SuamiSihat.CreativeAssetsManagement") | Out-Null
} catch {}

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

# Header Settings Navigation Button
$btnNavSettings = New-Object Windows.Forms.Button
$btnNavSettings.Text = "Settings"
$btnNavSettings.Location = New-Object Drawing.Point(620, 22)
$btnNavSettings.Size = New-Object Drawing.Size(115, 42)
$btnNavSettings.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$btnNavSettings.BackColor = [Drawing.Color]::FromArgb(15, 76, 129)
$btnNavSettings.ForeColor = [Drawing.Color]::White
$btnNavSettings.FlatStyle = "Flat"
$btnNavSettings.Cursor = [Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnNavSettings)

# Header Update Notification Badge / Pill
$headerUpdateBadge = New-Object Windows.Forms.Button
$headerUpdateBadge.Text = "Update Available!"
$headerUpdateBadge.Location = New-Object Drawing.Point(460, 24)
$headerUpdateBadge.Size = New-Object Drawing.Size(150, 38)
$headerUpdateBadge.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$headerUpdateBadge.BackColor = [Drawing.Color]::FromArgb(220, 38, 38)
$headerUpdateBadge.ForeColor = [Drawing.Color]::White
$headerUpdateBadge.FlatStyle = "Flat"
$headerUpdateBadge.FlatAppearance.BorderSize = 0
$headerUpdateBadge.Cursor = [Windows.Forms.Cursors]::Hand
$headerUpdateBadge.Visible = $false
$header.Controls.Add($headerUpdateBadge)

$headerUpdateBadge.Add_Click({
    Show-Page $settingsPageIndex
})


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
$welcomeLogo.Size = New-Object Drawing.Size(200, 80)
$welcomeLogo.SizeMode = "Zoom"
$welcomeLogo.Image = $lightLogoImage
$welcomePage.Controls.Add($welcomeLogo)

# Welcome Page Installed Version Status Pill
$installStatusBadge = New-Object Windows.Forms.Button
$installStatusBadge.Location = New-Object Drawing.Point(450, 18)
$installStatusBadge.Size = New-Object Drawing.Size(240, 34)
$installStatusBadge.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$installStatusBadge.ForeColor = [Drawing.Color]::White
$installStatusBadge.FlatStyle = "Flat"
$installStatusBadge.FlatAppearance.BorderSize = 0
$installStatusBadge.Enabled = $false
$welcomePage.Controls.Add($installStatusBadge)

# Selection prompt
$welcomeSelectLabel = New-Label -Text "Select what to set up on this PC:" -X 24 -Y 96 -Width 500 -Height 22
$welcomeSelectLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$welcomeSelectLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$welcomePage.Controls.Add($welcomeSelectLabel)

# --- Tile 1: Brand Kit ---
$tileBrandKit = New-Object Windows.Forms.Panel
$tileBrandKit.Location = New-Object Drawing.Point(24, 124)
$tileBrandKit.Size = New-Object Drawing.Size(666, 80)
$tileBrandKit.BorderStyle = "FixedSingle"
$tileBrandKit.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
$tileBrandKit.Cursor = [Windows.Forms.Cursors]::Hand
$welcomePage.Controls.Add($tileBrandKit)

$chkWelcomeBrandKit = New-Object Windows.Forms.CheckBox
$chkWelcomeBrandKit.Location = New-Object Drawing.Point(14, 29)
$chkWelcomeBrandKit.Size = New-Object Drawing.Size(18, 18)
$chkWelcomeBrandKit.Checked = $true
$tileBrandKit.Controls.Add($chkWelcomeBrandKit)

$tileLabel1 = New-Label -Text "Brand Kit" -X 40 -Y 10 -Width 600 -Height 24
$tileLabel1.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$tileLabel1.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$tileBrandKit.Controls.Add($tileLabel1)

$tileDesc1 = New-Label -Text "Fonts, design libraries, colour palettes, web shortcuts and workstation reports for SuamiSihat creative work. Detailed options on the following pages." -X 40 -Y 34 -Width 612 -Height 40
$tileDesc1.ForeColor = [Drawing.Color]::FromArgb(70, 80, 95)
$tileBrandKit.Controls.Add($tileDesc1)

# --- Tile 2: Creative Project Management ---
$tileCPM = New-Object Windows.Forms.Panel
$tileCPM.Location = New-Object Drawing.Point(24, 214)
$tileCPM.Size = New-Object Drawing.Size(666, 80)
$tileCPM.BorderStyle = "FixedSingle"
$tileCPM.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
$tileCPM.Cursor = [Windows.Forms.Cursors]::Hand
$welcomePage.Controls.Add($tileCPM)

$chkWelcomeCPM = New-Object Windows.Forms.CheckBox
$chkWelcomeCPM.Location = New-Object Drawing.Point(14, 29)
$chkWelcomeCPM.Size = New-Object Drawing.Size(18, 18)
$chkWelcomeCPM.Checked = $true
$tileCPM.Controls.Add($chkWelcomeCPM)

$tileLabel2 = New-Label -Text "Creative Project Management" -X 40 -Y 10 -Width 600 -Height 24
$tileLabel2.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$tileLabel2.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$tileCPM.Controls.Add($tileLabel2)

$tileDesc2 = New-Label -Text "SS-CAM desktop application: creative project folder creator with job ID tracking, workspace management, and Start Menu and Desktop shortcuts." -X 40 -Y 34 -Width 612 -Height 40
$tileDesc2.ForeColor = [Drawing.Color]::FromArgb(70, 80, 95)
$tileCPM.Controls.Add($tileDesc2)

$welcomeValidation = New-Label -Text "Select at least one component above to continue." -X 24 -Y 306 -Width 550 -Height 22
$welcomeValidation.ForeColor = [Drawing.Color]::FromArgb(194, 45, 55)
$welcomeValidation.Visible = $false
$welcomePage.Controls.Add($welcomeValidation)

# App-mode buttons (visible only when app is already installed)
$btnWelcomeLaunch = New-Object Windows.Forms.Button
$btnWelcomeLaunch.Text = "Launch Workspace"
$btnWelcomeLaunch.Location = New-Object Drawing.Point(24, 362)
$btnWelcomeLaunch.Size = New-Object Drawing.Size(185, 38)
$btnWelcomeLaunch.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$btnWelcomeLaunch.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnWelcomeLaunch.ForeColor = [Drawing.Color]::White
$btnWelcomeLaunch.FlatStyle = "Flat"
$btnWelcomeLaunch.Cursor = [Windows.Forms.Cursors]::Hand
$btnWelcomeLaunch.Visible = $false
$welcomePage.Controls.Add($btnWelcomeLaunch)

$btnWelcomeUninstall = New-Object Windows.Forms.Button
$btnWelcomeUninstall.Text = "Uninstall App"
$btnWelcomeUninstall.Location = New-Object Drawing.Point(222, 362)
$btnWelcomeUninstall.Size = New-Object Drawing.Size(160, 38)
$btnWelcomeUninstall.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$btnWelcomeUninstall.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$btnWelcomeUninstall.ForeColor = [Drawing.Color]::FromArgb(220, 38, 38)
$btnWelcomeUninstall.FlatStyle = "Flat"
$btnWelcomeUninstall.Cursor = [Windows.Forms.Cursors]::Hand
$btnWelcomeUninstall.Visible = $false
$welcomePage.Controls.Add($btnWelcomeUninstall)

$welcomePrivacy = New-Label -Text "PC information remains local and is not transmitted by this installer." -X 24 -Y 460 -Width 650
$welcomePrivacy.ForeColor = [Drawing.Color]::DimGray
$welcomePage.Controls.Add($welcomePrivacy)



# Page 3: PC requirements
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
"@
$fontDetails.Location = New-Object Drawing.Point(29, 165)
$fontDetails.Size = New-Object Drawing.Size(650, 250)
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
"@
$folderStructure.Location = New-Object Drawing.Point(28, 190)
$folderStructure.Size = New-Object Drawing.Size(650, 145)
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

# Page 6: Creative Project Management info (shown when CPM is selected)
$cpmPage = New-Page
[void]$pages.Add($cpmPage)

$cpmTitle = New-Label -Text "Creative Project Management" -X 24 -Y 18 -Width 660 -Height 34
$cpmTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$cpmTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$cpmPage.Controls.Add($cpmTitle)

$cpmSubtitle = New-Label -Text "SS-CAM will be installed as a Windows desktop application on this PC." -X 27 -Y 60 -Width 660 -Height 22
$cpmPage.Controls.Add($cpmSubtitle)

$cpmInstallPath = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management"
$cpmPathLabel = New-Label -Text "Installation path:  $cpmInstallPath" -X 27 -Y 85 -Width 666 -Height 36
$cpmPathLabel.Font = New-Object Drawing.Font("Consolas", 8.5)
$cpmPathLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$cpmPage.Controls.Add($cpmPathLabel)

$cpmDetails = New-Label -Text @"

What's included:

  -  Creative Project Folder Creator - Post Haste-style presets for graphic, video, social and brand projects
  -  Sequential Job ID tracking with D / V / P / S prefix and auto-increment
  -  Recent project history with one-click Explorer launch and clipboard folder-name copy
  -  Configurable workspace root directory and job counter via Settings

Access after installation:

  -  Start Menu shortcut: Programs > SuamiSihat > Creative Assets Management
  -  Desktop shortcut created automatically

No administrator rights required.
Installs per-user and can be removed at any time from Settings.
"@
$cpmDetails.Location = New-Object Drawing.Point(27, 125)
$cpmDetails.Size = New-Object Drawing.Size(666, 300)
$cpmDetails.Font = New-Object Drawing.Font("Segoe UI", 9.5)
$cpmPage.Controls.Add($cpmDetails)

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

$creatorTitle = New-Label -Text "Creative Project Folder Creator" -X 24 -Y 8 -Width 670 -Height 26
$creatorTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$creatorTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$creatorPage.Controls.Add($creatorTitle)

$creatorIntro = New-Label -Text "Post Haste-style template presets with history tracking, Clipboard Copy, & auto-incrementing Job IDs." -X 27 -Y 34 -Width 660 -Height 18
$creatorIntro.ForeColor = [Drawing.Color]::FromArgb(100, 110, 125)
$creatorPage.Controls.Add($creatorIntro)

# Card 1: Recent Projects Quick-Launcher Box
$recentGroup = New-Object Windows.Forms.GroupBox
$recentGroup.Text = " Recent Active Projects "
$recentGroup.Location = New-Object Drawing.Point(27, 52)
$recentGroup.Size = New-Object Drawing.Size(667, 60)
$recentGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($recentGroup)

$recentInfoLabel = New-Label -Text "No recent projects yet." -X 15 -Y 20 -Width 510 -Height 26
$recentInfoLabel.Font = New-Object Drawing.Font("Consolas", 8.5)
$recentInfoLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$recentGroup.Controls.Add($recentInfoLabel)

$recentOpenBtn = New-Object Windows.Forms.Button
$recentOpenBtn.Text = "Open Folder"
$recentOpenBtn.Location = New-Object Drawing.Point(540, 17)
$recentOpenBtn.Size = New-Object Drawing.Size(112, 30)
$recentOpenBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$recentOpenBtn.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$recentOpenBtn.ForeColor = [Drawing.Color]::FromArgb(30, 41, 59)
$recentOpenBtn.FlatStyle = "Flat"
$recentOpenBtn.Cursor = [Windows.Forms.Cursors]::Hand
$recentOpenBtn.Enabled = $false
$recentGroup.Controls.Add($recentOpenBtn)

# Card 2: Template Parameters & Customization Options
$paramGroup = New-Object Windows.Forms.GroupBox
$paramGroup.Text = " Project Template & Folder Options "
$paramGroup.Location = New-Object Drawing.Point(27, 117)
$paramGroup.Size = New-Object Drawing.Size(667, 235)
$paramGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($paramGroup)

# Project Preset Selector
$presetLabel = New-Label -Text "Project Preset Template:" -X 15 -Y 22 -Width 200
$presetLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($presetLabel)

$presetCombo = New-Object Windows.Forms.ComboBox
$presetCombo.Location = New-Object Drawing.Point(15, 42)
$presetCombo.Size = New-Object Drawing.Size(637, 26)
$presetCombo.DropDownStyle = "DropDownList"
@("Graphic & Print Design", "Social Media & E-Commerce", "Video & Motion Graphics", "Brand Identity") | ForEach-Object { [void]$presetCombo.Items.Add($_) }
$presetCombo.SelectedIndex = 0
$paramGroup.Controls.Add($presetCombo)

# Year Selection
$yearLabel = New-Label -Text "Year:" -X 15 -Y 72 -Width 75
$yearLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($yearLabel)

$yearCombo = New-Object Windows.Forms.ComboBox
$yearCombo.Location = New-Object Drawing.Point(15, 92)
$yearCombo.Size = New-Object Drawing.Size(85, 26)
$yearCombo.DropDownStyle = "DropDownList"
$currentYrInt = [int](Get-Date).ToString("yyyy")
(($currentYrInt - 2)..($currentYrInt + 3)) | ForEach-Object { [void]$yearCombo.Items.Add($_) }
$yearCombo.SelectedItem = $currentYrInt
$paramGroup.Controls.Add($yearCombo)

# Sub-Brand Selection
$brandLabel = New-Label -Text "Sub-Brand:" -X 110 -Y 72 -Width 100
$brandLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($brandLabel)

$subBrandCombo = New-Object Windows.Forms.ComboBox
$subBrandCombo.Location = New-Object Drawing.Point(110, 92)
$subBrandCombo.Size = New-Object Drawing.Size(105, 26)
$subBrandCombo.DropDownStyle = "DropDownList"
@("SS", "SSH", "SSC", "SSW", "SSE", "SST") | ForEach-Object { [void]$subBrandCombo.Items.Add($_) }
$subBrandCombo.SelectedIndex = 0
$paramGroup.Controls.Add($subBrandCombo)

# Job ID Code (D- Graphic, V- Video, P- Product/Brand, S- Social)
$jobLabel = New-Label -Text "Job ID (D/V/P/S):" -X 225 -Y 72 -Width 130
$jobLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($jobLabel)

$jobIdText = New-Object Windows.Forms.TextBox
$jobIdText.Location = New-Object Drawing.Point(225, 92)
$jobIdText.Size = New-Object Drawing.Size(115, 25)
$jobIdText.Text = $script:appState.NextJobNumber
$paramGroup.Controls.Add($jobIdText)

# Project Name
$nameLabel = New-Label -Text "Project Name:" -X 350 -Y 72 -Width 280
$nameLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($nameLabel)

$projectNameText = New-Object Windows.Forms.TextBox
$projectNameText.Location = New-Object Drawing.Point(350, 92)
$projectNameText.Size = New-Object Drawing.Size(302, 25)
$projectNameText.Text = "POSM_Banner"
$paramGroup.Controls.Add($projectNameText)

# Project Description / Creative Brief Input (Saved as README.md)
$descLabel = New-Label -Text "Project Description / Creative Brief (Markdown - saved as README.md):" -X 15 -Y 122 -Width 490
$descLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($descLabel)

# Expand/collapse toggle for the description box
$script:descExpanded = $false
$btnDescToggle = New-Object Windows.Forms.Button
$btnDescToggle.Text = [char]0x25BC  # ▼ expand
$btnDescToggle.Location = New-Object Drawing.Point(622, 119)
$btnDescToggle.Size = New-Object Drawing.Size(30, 20)
$btnDescToggle.Font = New-Object Drawing.Font("Segoe UI", 7)
$btnDescToggle.FlatStyle = "Flat"
$btnDescToggle.FlatAppearance.BorderSize = 0
$btnDescToggle.BackColor = [Drawing.Color]::FromArgb(230, 235, 245)
$btnDescToggle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnDescToggle.Cursor = [Windows.Forms.Cursors]::Hand
$btnDescToggle.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($btnDescToggle)

$projDescText = New-Object Windows.Forms.TextBox
$projDescText.Multiline = $true
$projDescText.ScrollBars = "Vertical"
$projDescText.Location = New-Object Drawing.Point(15, 142)
$projDescText.Size = New-Object Drawing.Size(637, 44)
$projDescText.Text = "# Creative Brief`r`n- Objective: SuamiSihat Marketing Campaign`r`n- Deliverables: Brand Graphics & Digital Assets"
$paramGroup.Controls.Add($projDescText)

# Options Checkboxes (Feature 3 & 4) - Y position driven by $script:chkBaseY for expand support
$script:chkBaseY = 195
$chkInjectTemplate = New-Object Windows.Forms.CheckBox
$chkInjectTemplate.Text = "Inject Master Canvas (.psd/.afdesign)"
$chkInjectTemplate.Location = New-Object Drawing.Point(15, $script:chkBaseY)
$chkInjectTemplate.Size = New-Object Drawing.Size(260, 24)
$chkInjectTemplate.Checked = $true
$paramGroup.Controls.Add($chkInjectTemplate)

$chkExtraRevisions = New-Object Windows.Forms.CheckBox
$chkExtraRevisions.Text = "+ Revisions Folder"
$chkExtraRevisions.Location = New-Object Drawing.Point(285, $script:chkBaseY)
$chkExtraRevisions.Size = New-Object Drawing.Size(140, 24)
$paramGroup.Controls.Add($chkExtraRevisions)

$chkExtraRaw = New-Object Windows.Forms.CheckBox
$chkExtraRaw.Text = "+ RAW Audio/3D"
$chkExtraRaw.Location = New-Object Drawing.Point(435, $script:chkBaseY)
$chkExtraRaw.Size = New-Object Drawing.Size(140, 24)
$paramGroup.Controls.Add($chkExtraRaw)

# Workspace Root Location Text Box (Hidden internally, customizable via Settings)
$workspacePathText = New-Object Windows.Forms.TextBox
$workspacePathText.Text = $script:appState.DefaultWorkspace

# Folder Path Preview Box & 1-Click Clipboard Copy (Feature 1)
$previewGroup = New-Object Windows.Forms.GroupBox
$previewGroup.Text = " Folder Path Preview "
$previewGroup.Location = New-Object Drawing.Point(27, 357)
$previewGroup.Size = New-Object Drawing.Size(667, 56)
$previewGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($previewGroup)

$previewPathLabel = New-Label -Text "" -X 15 -Y 18 -Width 515 -Height 30
$previewPathLabel.Font = New-Object Drawing.Font("Consolas", 8.5)
$previewPathLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$previewGroup.Controls.Add($previewPathLabel)

$btnCopyName = New-Object Windows.Forms.Button
$btnCopyName.Text = "Copy Name"
$btnCopyName.Location = New-Object Drawing.Point(540, 15)
$btnCopyName.Size = New-Object Drawing.Size(112, 30)
$btnCopyName.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnCopyName.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$btnCopyName.ForeColor = [Drawing.Color]::FromArgb(30, 41, 59)
$btnCopyName.FlatStyle = "Flat"
$btnCopyName.Cursor = [Windows.Forms.Cursors]::Hand
$previewGroup.Controls.Add($btnCopyName)

# Sub-folder Structure Information
$structureGroup = New-Object Windows.Forms.GroupBox
$structureGroup.Text = " Sub-Folders Created for Selected Preset "
$structureGroup.Location = New-Object Drawing.Point(27, 418)
$structureGroup.Size = New-Object Drawing.Size(667, 95)
$structureGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($structureGroup)

$structureInfoLabel = New-Label -Text "" -X 15 -Y 18 -Width 637 -Height 72
$structureInfoLabel.Font = New-Object Drawing.Font("Consolas", 8)
$structureInfoLabel.ForeColor = [Drawing.Color]::FromArgb(70, 75, 80)
$structureGroup.Controls.Add($structureInfoLabel)

# Create Button, Clear Form Button & Status
# These are form-level controls (not inside the page panel) so they align with the Close button row
$createProjectBtn = New-Object Windows.Forms.Button
$createProjectBtn.Text = "Create Project Folder && Open Explorer"
$createProjectBtn.Location = New-Object Drawing.Point(20, 631)
$createProjectBtn.Size = New-Object Drawing.Size(300, 34)
$createProjectBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$createProjectBtn.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$createProjectBtn.ForeColor = [Drawing.Color]::White
$createProjectBtn.FlatStyle = "Flat"
$createProjectBtn.Cursor = [Windows.Forms.Cursors]::Hand
$createProjectBtn.Visible = $false

$btnClearForm = New-Object Windows.Forms.Button
$btnClearForm.Text = "Clear Form"
$btnClearForm.Location = New-Object Drawing.Point(328, 631)
$btnClearForm.Size = New-Object Drawing.Size(95, 34)
$btnClearForm.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$btnClearForm.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$btnClearForm.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
$btnClearForm.FlatStyle = "Flat"
$btnClearForm.Cursor = [Windows.Forms.Cursors]::Hand
$btnClearForm.Visible = $false

$creatorStatusLabel = New-Label -Text "" -X 430 -Y 633 -Width 195 -Height 28
$creatorStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorStatusLabel.Visible = $false

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

$uninstallSettingsBtn = New-Object Windows.Forms.Button
$uninstallSettingsBtn.Text = "Uninstall App && Shortcuts"
$uninstallSettingsBtn.Location = New-Object Drawing.Point(300, 56)
$uninstallSettingsBtn.Size = New-Object Drawing.Size(220, 32)
$uninstallSettingsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$uninstallSettingsBtn.BackColor = [Drawing.Color]::FromArgb(220, 38, 38)
$uninstallSettingsBtn.ForeColor = [Drawing.Color]::White
$uninstallSettingsBtn.FlatStyle = "Flat"
$uninstallSettingsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$fontGroup.Controls.Add($uninstallSettingsBtn)

# Group 2: App & History Settings
$appGroup = New-Object Windows.Forms.GroupBox
$appGroup.Text = " Workspace && Sequential Counter Defaults "
$appGroup.Location = New-Object Drawing.Point(27, 185)
$appGroup.Size = New-Object Drawing.Size(667, 160)
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

$setJobLabel = New-Label -Text "Next Sequential Job ID Counter (e.g. D0075):" -X 15 -Y 85 -Width 300
$appGroup.Controls.Add($setJobLabel)

$setJobText = New-Object Windows.Forms.TextBox
$setJobText.Location = New-Object Drawing.Point(15, 108)
$setJobText.Size = New-Object Drawing.Size(160, 27)
$setJobText.Text = $script:appState.NextJobNumber
$appGroup.Controls.Add($setJobText)

$saveSettingsBtn = New-Object Windows.Forms.Button
$saveSettingsBtn.Text = "Save Settings"
$saveSettingsBtn.Location = New-Object Drawing.Point(190, 105)
$saveSettingsBtn.Size = New-Object Drawing.Size(130, 32)
$saveSettingsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$saveSettingsBtn.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
$saveSettingsBtn.ForeColor = [Drawing.Color]::White
$saveSettingsBtn.FlatStyle = "Flat"
$saveSettingsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$appGroup.Controls.Add($saveSettingsBtn)

$settingsStatusLabel = New-Label -Text "" -X 335 -Y 110 -Width 310 -Height 24
$settingsStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$appGroup.Controls.Add($settingsStatusLabel)

# Group 3: About & Check for Updates
$updateGroup = New-Object Windows.Forms.GroupBox
$updateGroup.Text = " About && Software Updates "
$updateGroup.Location = New-Object Drawing.Point(27, 355)
$updateGroup.Size = New-Object Drawing.Size(667, 125)
$updateGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($updateGroup)

$aboutLabel = New-Label -Text "SuamiSihat Creative Assets Management  |  Installed Version: v1.6.2`r`nGitHub: https://github.com/SuamiSihat/SS-Designer-Assets" -X 15 -Y 24 -Width 637 -Height 36
$aboutLabel.Font = New-Object Drawing.Font("Segoe UI", 8.5)
$aboutLabel.ForeColor = [Drawing.Color]::FromArgb(30, 41, 59)
$updateGroup.Controls.Add($aboutLabel)

$btnCheckUpdate = New-Object Windows.Forms.Button
$btnCheckUpdate.Text = "Check for Updates"
$btnCheckUpdate.Location = New-Object Drawing.Point(15, 68)
$btnCheckUpdate.Size = New-Object Drawing.Size(160, 32)
$btnCheckUpdate.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnCheckUpdate.ForeColor = [Drawing.Color]::White
$btnCheckUpdate.FlatStyle = "Flat"
$btnCheckUpdate.Cursor = [Windows.Forms.Cursors]::Hand
$updateGroup.Controls.Add($btnCheckUpdate)

$btnInstallUpdate = New-Object Windows.Forms.Button
$btnInstallUpdate.Text = "Install Update"
$btnInstallUpdate.Location = New-Object Drawing.Point(185, 68)
$btnInstallUpdate.Size = New-Object Drawing.Size(140, 32)
$btnInstallUpdate.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnInstallUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
$btnInstallUpdate.ForeColor = [Drawing.Color]::White
$btnInstallUpdate.FlatStyle = "Flat"
$btnInstallUpdate.Cursor = [Windows.Forms.Cursors]::Hand
$btnInstallUpdate.Visible = $false
$updateGroup.Controls.Add($btnInstallUpdate)

$updateStatusLabel = New-Label -Text "" -X 185 -Y 72 -Width 460 -Height 28
$updateStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$updateGroup.Controls.Add($updateStatusLabel)

# Event Handlers for Creator Page
$updatePreview = {
    $selYear = if ($yearCombo.SelectedItem) { [string]$yearCombo.SelectedItem } else { (Get-Date).ToString("yyyy") }
    $curMonthNum = (Get-Date).ToString("MM")
    $curMonthFull = (Get-Culture).TextInfo.ToTitleCase((Get-Date).ToString("MMMM"))
    $curDay = (Get-Date).ToString("dd")

    $yearFolder = "SS-${selYear}"
    $monthFolder = "${selYear}${curMonthNum}_${curMonthFull}"
    $dateCode = "${selYear}${curMonthNum}${curDay}"

    $rootBase = $workspacePathText.Text.Trim()
    if ($rootBase -match '\\SS-\d{4}$') {
        $rootBase = Split-Path -Parent $rootBase
    }

    $sub = ($subBrandCombo.SelectedItem -replace '\s+', '_').ToUpper()
    if ($sub -match 'SUAMISIHAT|SS') { $sub = "SS" }
    elseif ($sub -match 'HEALTH') { $sub = "SSH" }
    elseif ($sub -match 'CLINIC') { $sub = "SSC" }
    elseif ($sub -match 'WELLNESS') { $sub = "SSW" }
    elseif ($sub -match 'ECOM') { $sub = "SSE" }
    elseif ($sub -match 'TECH') { $sub = "SST" }

    $job = ($jobIdText.Text.Trim() -replace '\s+', '').ToUpper()
    if (-not $job.StartsWith("D")) { $job = "D$job" }
    $proj = ($projectNameText.Text.Trim() -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($proj)) { $proj = "Project" }
    
    $folderName = "${dateCode}_${job}_${sub}_${proj}"
    $targetPath = Join-Path (Join-Path (Join-Path $rootBase $yearFolder) $monthFolder) $folderName
    $previewPathLabel.Text = $targetPath

    # Refresh Recent Projects UI
    if ($script:appState.RecentProjects -and $script:appState.RecentProjects.Count -gt 0) {
        $firstRecent = $script:appState.RecentProjects[0]
        $recentInfoLabel.Text = "$($firstRecent.FolderName)  ($($firstRecent.Created))"
        $recentOpenBtn.Enabled = $true
    } else {
        $recentInfoLabel.Text = "No recent projects yet."
        $recentOpenBtn.Enabled = $false
    }
    $b = [char]0x251C + [char]0x2500 + [char]0x2500 + " "
    $e = [char]0x2514 + [char]0x2500 + [char]0x2500 + " "

    $structureInfoLabel.Text = switch -Wildcard ($presetCombo.SelectedItem) {
        "*Social*"  { "${b}Working Files\      (PSD/AF source design files)`r`n${b}Source Assets\      (Photos & reference graphics)`r`n${b}Copywriting\        (Ad text copy & caption files)`r`n${e}Final Exports\      (Exported web & social graphics)" }
        "*Video*"   { "${b}Project Files\      (NLE PR/AE/DR timeline files)`r`n${b}Footage\            (Raw video clips & recordings)`r`n${b}Audio\              (SFX & music stems)`r`n${e}Final Exports\      (Master rendered MP4/MOV outputs)" }
        "*Brand*"   { "${b}Vector Master\      (SVG & AI master logos)`r`n${b}Brand Guidelines\   (Brand system documentation PDF)`r`n${b}Colour Palettes\    (ASE & AF palette files)`r`n${e}Export Packages\    (ZIP distribution packages)" }
        default     { "${b}Artwork Design\     (Working source files: .afdesign, .psd, .ai)`r`n${b}Artwork Mockup\     (Presentation mockups & client previews)`r`n${b}Assets\             (Raw photos, icons, reference materials)`r`n${e}Production\         (Exported outputs: PDF, PNG, SVG)" }
    }
}

# Description box expand/collapse toggle handler
# Collapsed: projDescText H=44, checkboxes Y=195, paramGroup H=235, previewGroup Y=357, structureGroup visible
# Expanded (+80px): projDescText H=124, checkboxes Y=275, paramGroup H=315, previewGroup Y=437, structureGroup hidden
$btnDescToggle.Add_Click({
    if (-not $script:descExpanded) {
        # Expand
        $projDescText.Size       = New-Object Drawing.Size(637, 124)
        $chkInjectTemplate.Location = New-Object Drawing.Point(15, 275)
        $chkExtraRevisions.Location = New-Object Drawing.Point(285, 275)
        $chkExtraRaw.Location    = New-Object Drawing.Point(435, 275)
        $paramGroup.Size         = New-Object Drawing.Size(667, 315)
        $previewGroup.Location   = New-Object Drawing.Point(27, 437)
        $structureGroup.Visible  = $false
        $btnDescToggle.Text      = [char]0x25B2   # ▲ collapse
        $script:descExpanded     = $true
    } else {
        # Collapse
        $projDescText.Size       = New-Object Drawing.Size(637, 44)
        $chkInjectTemplate.Location = New-Object Drawing.Point(15, 195)
        $chkExtraRevisions.Location = New-Object Drawing.Point(285, 195)
        $chkExtraRaw.Location    = New-Object Drawing.Point(435, 195)
        $paramGroup.Size         = New-Object Drawing.Size(667, 235)
        $previewGroup.Location   = New-Object Drawing.Point(27, 357)
        $structureGroup.Visible  = $true
        $btnDescToggle.Text      = [char]0x25BC   # ▼ expand
        $script:descExpanded     = $false
    }
})

$presetCombo.Add_SelectedIndexChanged({
    $prefix = Get-SuamiSihatJobPrefix -PresetName $presetCombo.SelectedItem
    $currentJob = $jobIdText.Text.Trim()
    if ($currentJob -match '^[A-Za-z]+(\d+)') {
        $numPart = $matches[1]
        $jobIdText.Text = "${prefix}${numPart}"
    } else {
        $jobIdText.Text = "${prefix}0001"
    }
    &$updatePreview
})

$yearCombo.Add_SelectedIndexChanged($updatePreview)
$subBrandCombo.Add_SelectedIndexChanged($updatePreview)
$jobIdText.Add_TextChanged($updatePreview)
$projectNameText.Add_TextChanged({
    $cursor = $projectNameText.SelectionStart
    $originalText = $projectNameText.Text
    $cleaned = $originalText -replace '\s+', '_'
    if ($originalText -ne $cleaned) {
        $projectNameText.Text = $cleaned
        $projectNameText.SelectionStart = [Math]::Min($cursor, $cleaned.Length)
    }
    &$updatePreview
})
$workspacePathText.Add_TextChanged($updatePreview)
&$updatePreview

# Clear Form Button Handler
$btnClearForm.Add_Click({
    $projectNameText.Text = ""
    $projDescText.Text = ""
    $presetCombo.SelectedIndex = 0
    $subBrandCombo.SelectedIndex = 0
    $prefix = Get-SuamiSihatJobPrefix -PresetName $presetCombo.SelectedItem
    $jobIdText.Text = "${prefix}0001"
    $creatorStatusLabel.Text = ""
    &$updatePreview
})

# Feature 1: Clipboard Copy Handler
$btnCopyName.Add_Click({
    $selYear = if ($yearCombo.SelectedItem) { [string]$yearCombo.SelectedItem } else { (Get-Date).ToString("yyyy") }
    $curMonth = (Get-Date).ToString("MM")
    $dateCode = "${selYear}${curMonth}"
    $sub = ($subBrandCombo.SelectedItem -replace '\s+', '_').ToUpper()
    $job = ($jobIdText.Text.Trim() -replace '\s+', '').ToUpper()
    $proj = ($projectNameText.Text.Trim() -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($proj)) { $proj = "Project" }
    $folderName = "${dateCode}_${job}_${sub}_${proj}"

    try {
        [Windows.Forms.Clipboard]::SetText($folderName)
        $btnCopyName.Text = "Copied!"
        $btnCopyName.BackColor = [Drawing.Color]::FromArgb(220, 252, 231)
        $btnCopyName.ForeColor = [Drawing.Color]::FromArgb(21, 128, 61)
        
        # Reset copy button text after 2 seconds
        if ($null -ne $script:copyTimer) {
            try { $script:copyTimer.Stop(); $script:copyTimer.Dispose() } catch {}
        }
        $script:copyTimer = New-Object Windows.Forms.Timer
        $script:copyTimer.Interval = 2000
        $script:copyTimer.Add_Tick({
            $btnCopyName.Text = "Copy Name"
            $btnCopyName.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
            $btnCopyName.ForeColor = [Drawing.Color]::FromArgb(30, 41, 59)
            if ($null -ne $script:copyTimer) {
                $script:copyTimer.Stop()
                $script:copyTimer.Dispose()
                $script:copyTimer = $null
            }
        })
        $script:copyTimer.Start()
    } catch {}
})

# Feature 2: Recent Projects Quick-Launcher Handler
$recentOpenBtn.Add_Click({
    if ($script:appState.RecentProjects -and $script:appState.RecentProjects.Count -gt 0) {
        $recentPath = $script:appState.RecentProjects[0].ProjectPath
        if (Test-Path -LiteralPath $recentPath -PathType Container) {
            Start-Process -FilePath "explorer.exe" -ArgumentList (Quote-ProcessArgument $recentPath)
        }
    }
})

# Create Button Action
$createProjectBtn.Add_Click({
    try {
        $extraFolders = @()
        if ($chkExtraRevisions.Checked) { $extraFolders += "Client Revisions" }
        if ($chkExtraRaw.Checked) { $extraFolders += "Raw Audio & 3D" }

        $result = New-SuamiSihatProjectFolder `
            -RootDirectory $workspacePathText.Text.Trim() `
            -SubBrand $subBrandCombo.SelectedItem `
            -JobNumber $jobIdText.Text.Trim() `
            -ProjectName $projectNameText.Text.Trim() `
            -PresetType $presetCombo.SelectedItem `
            -Year ([string]$yearCombo.SelectedItem) `
            -Description $projDescText.Text.Trim() `
            -ExtraSubFolders $extraFolders `
            -InjectTemplates:$chkInjectTemplate.Checked
        
        $script:appState = Get-SuamiSihatAppState
        $jobIdText.Text = $result.NextJobNumber
        $setJobText.Text = $result.NextJobNumber
        &$updatePreview

        $creatorStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $creatorStatusLabel.Text = "Project Created! Next Job: $($result.NextJobNumber)`r`nOpening File Explorer..."
        
        # Open in Explorer
        Start-Process -FilePath "explorer.exe" -ArgumentList (Quote-ProcessArgument $result.ProjectPath)
    } catch {
        $creatorStatusLabel.ForeColor = [Drawing.Color]::Firebrick
        $creatorStatusLabel.Text = "Error: $($_.Exception.Message)"
    }
})

# App Installed Version Status Refresh
$refreshAppVersionStatus = {
    $script:installedInfo = Get-SuamiSihatInstalledVersion
    $script:isNewInstall = -not $script:installedInfo.IsInstalled
    if ($script:installedInfo.IsInstalled) {
        $installStatusBadge.Text = "Installed: v$($script:installedInfo.Version)"
        $installStatusBadge.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $aboutLabel.Text = "SuamiSihat Creative Assets Management  |  Installed: v$($script:installedInfo.Version)`r`nStatus: Installed  |  Executable: $($script:installedInfo.ExePath)"
        $btnWelcomeLaunch.Visible = $true
        $btnWelcomeUninstall.Visible = $true
        $chkWelcomeBrandKit.Checked = $true
        $chkWelcomeCPM.Checked = $true
        $tileBrandKit.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
        $tileCPM.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
    } else {
        $installStatusBadge.Text = "Not Installed  (v1.6.2 Ready)"
        $installStatusBadge.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
        $aboutLabel.Text = "SuamiSihat Creative Assets Management  |  Status: Not Installed`r`nRun setup wizard below to install SuamiSihat brand kit && assets."
        $btnWelcomeLaunch.Visible = $false
        $btnWelcomeUninstall.Visible = $false
        $chkWelcomeBrandKit.Checked = $true
        $chkWelcomeCPM.Checked = $true
    }
}

# Welcome Page Handlers
$btnWelcomeLaunch.Add_Click({
    Show-Page $creatorPageIndex
})

$uninstallAppHandler = {
    $confirm = [Windows.Forms.MessageBox]::Show(
        "Are you sure you want to uninstall SuamiSihat Creative Assets Management and its shortcuts from this PC?",
        "Uninstall SuamiSihat App",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -eq [Windows.Forms.DialogResult]::Yes) {
        Uninstall-SuamiSihatApp
        [Windows.Forms.MessageBox]::Show(
            "SuamiSihat Creative Assets Management has been uninstalled successfully.",
            "Uninstalled",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        &$refreshAppVersionStatus
    }
}

$btnWelcomeUninstall.Add_Click($uninstallAppHandler)
$uninstallSettingsBtn.Add_Click($uninstallAppHandler)

# Welcome tile + checkbox handlers (toggle selection, validate, sync, tile colouring)
$tileBrandKit.Add_Click({ $chkWelcomeBrandKit.Checked = -not $chkWelcomeBrandKit.Checked })
$tileLabel1.Add_Click({ $chkWelcomeBrandKit.Checked = -not $chkWelcomeBrandKit.Checked })
$tileDesc1.Add_Click({ $chkWelcomeBrandKit.Checked = -not $chkWelcomeBrandKit.Checked })
$tileCPM.Add_Click({ $chkWelcomeCPM.Checked = -not $chkWelcomeCPM.Checked })
$tileLabel2.Add_Click({ $chkWelcomeCPM.Checked = -not $chkWelcomeCPM.Checked })
$tileDesc2.Add_Click({ $chkWelcomeCPM.Checked = -not $chkWelcomeCPM.Checked })

$script:UpdateWelcomeState = {
    $anySelected = $chkWelcomeBrandKit.Checked -or $chkWelcomeCPM.Checked
    $welcomeValidation.Visible = -not $anySelected
    $tileBrandKit.BackColor = if ($chkWelcomeBrandKit.Checked) { [Drawing.Color]::FromArgb(240, 245, 255) } else { [Drawing.Color]::White }
    $tileCPM.BackColor     = if ($chkWelcomeCPM.Checked)      { [Drawing.Color]::FromArgb(240, 245, 255) } else { [Drawing.Color]::White }
    if ($script:pageIndex -eq 0) { $nextButton.Enabled = $anySelected }
    # Sync Brand Kit selection with per-page asset/font controls
    $copyAssets.Checked = $chkWelcomeBrandKit.Checked
    if (-not $chkWelcomeBrandKit.Checked -and $fontChoice.SelectedIndex -ne 2) { $fontChoice.SelectedIndex = 2 }
    if ($chkWelcomeBrandKit.Checked -and $fontChoice.SelectedIndex -eq 2)      { $fontChoice.SelectedIndex = 0 }
}
$chkWelcomeBrandKit.Add_CheckedChanged({ & $script:UpdateWelcomeState })
$chkWelcomeCPM.Add_CheckedChanged({ & $script:UpdateWelcomeState })

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

# GitHub Update Handlers
$script:updateInfo = $null

$btnCheckUpdate.Add_Click({
    $btnCheckUpdate.Enabled = $false
    $btnCheckUpdate.Text = "Checking..."
    $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
    $updateStatusLabel.Text = "Checking GitHub Releases API..."
    $btnInstallUpdate.Visible = $false
    $updateStatusLabel.Location = New-Object Drawing.Point(185, 72)
    $updateStatusLabel.Width = 460

    $script:updateInfo = Get-SuamiSihatLatestRelease -CurrentVersion "1.6.2"

    if ($script:updateInfo.HasUpdate) {
        $btnCheckUpdate.Text = "Check for Updates"
        $btnCheckUpdate.Enabled = $true
        $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $updateStatusLabel.Text = "New Version Available: v$($script:updateInfo.LatestVersion)!"
        if (-not [string]::IsNullOrWhiteSpace($script:updateInfo.DownloadUrl)) {
            $btnInstallUpdate.Location = New-Object Drawing.Point(185, 68)
            $btnInstallUpdate.Visible = $true
            $updateStatusLabel.Location = New-Object Drawing.Point(335, 72)
            $updateStatusLabel.Width = 310
        }
    } else {
        # Already on latest — disable button and mark as up to date
        $btnCheckUpdate.Text = "Up to Date"
        $btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $btnCheckUpdate.Enabled = $false
        $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $updateStatusLabel.Text = "You are running the latest version (v1.6.2)."
    }
})

$btnInstallUpdate.Add_Click({
    if ($script:updateInfo -and $script:updateInfo.DownloadUrl) {
        try {
            $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
            $updateStatusLabel.Text = "Downloading update from GitHub..."
            Start-SuamiSihatAutoUpdate -DownloadUrl $script:updateInfo.DownloadUrl
            $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
            $updateStatusLabel.Text = "Update downloaded! Launching installer..."
        } catch {
            $updateStatusLabel.ForeColor = [Drawing.Color]::Firebrick
            $updateStatusLabel.Text = "Update error: $($_.Exception.Message)"
        }
    }
})

$btnNavSettings.Add_Click({
    if ($script:pageIndex -eq $settingsPageIndex) {
        Show-Page $creatorPageIndex
    } else {
        Show-Page $settingsPageIndex
    }
})


foreach ($page in $pages) {
    $form.Controls.Add($page)
}

# Form-level buttons (wizard nav + creator action row, all at Y=631)
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

# Add creator-page action buttons to form (so they sit in the same row as Close)
$form.Controls.Add($createProjectBtn)
$form.Controls.Add($btnClearForm)
$form.Controls.Add($creatorStatusLabel)

# Form-level Skip Fonts button (visible only on the Font page)
$btnSkipFonts = New-Object Windows.Forms.Button
$btnSkipFonts.Text = "Skip Fonts"
$btnSkipFonts.Location = New-Object Drawing.Point(20, 631)
$btnSkipFonts.Size = New-Object Drawing.Size(110, 34)
$btnSkipFonts.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$btnSkipFonts.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$btnSkipFonts.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
$btnSkipFonts.FlatStyle = "Flat"
$btnSkipFonts.Cursor = [Windows.Forms.Cursors]::Hand
$btnSkipFonts.Visible = $false
$form.Controls.Add($btnSkipFonts)

# Form-level Open App button (shown at Setup Complete when CPM was installed)
$btnOpenApp = New-Object Windows.Forms.Button
$btnOpenApp.Text = "Open App"
$btnOpenApp.Location = New-Object Drawing.Point(20, 631)
$btnOpenApp.Size = New-Object Drawing.Size(130, 34)
$btnOpenApp.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$btnOpenApp.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
$btnOpenApp.ForeColor = [Drawing.Color]::White
$btnOpenApp.FlatStyle = "Flat"
$btnOpenApp.Cursor = [Windows.Forms.Cursors]::Hand
$btnOpenApp.Visible = $false
$form.Controls.Add($btnOpenApp)

$script:installedInfo = $null
$script:isNewInstall = $true

$folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Choose the parent folder for the SuamiSihat brand assets."
$folderBrowser.ShowNewFolderButton = $true

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400

$licencePageIndex = $pages.IndexOf($licencePage)
$assetPageIndex = $pages.IndexOf($assetPage)
$reviewPageIndex = $pages.IndexOf($reviewPage)
$progressPageIndex = $pages.IndexOf($progressPage)
$cpmPageIndex = $pages.IndexOf($cpmPage)
$fontPageIndex = $pages.IndexOf($fontPage)
$requirementsPageIndex = $pages.IndexOf($requirementsPage)
$systemPageIndex = $pages.IndexOf($systemPage)

# Dynamic wizard routing — navigates by component selection and install mode
function Get-NextPageIndex {
    param([int]$Current)
    $brandKit = $chkWelcomeBrandKit.Checked
    $cpm = $chkWelcomeCPM.Checked
    $newInstall = $script:isNewInstall
    if ($Current -eq 0)                            { return $requirementsPageIndex }
    if ($Current -eq $requirementsPageIndex)       { return $systemPageIndex }
    if ($Current -eq $systemPageIndex) {
        if ($newInstall) { return $licencePageIndex } else { return $fontPageIndex }
    }
    if ($Current -eq $licencePageIndex)            { return $fontPageIndex }
    if ($Current -eq $fontPageIndex) {
        if ($brandKit) { return $assetPageIndex }
        elseif ($cpm)  { return $cpmPageIndex }
        else           { return $reviewPageIndex }
    }
    if ($Current -eq $assetPageIndex) {
        if ($cpm) { return $cpmPageIndex } else { return $reviewPageIndex }
    }
    if ($Current -eq $cpmPageIndex)                { return $reviewPageIndex }
    return ($Current + 1)
}

function Get-PrevPageIndex {
    param([int]$Current)
    $brandKit = $chkWelcomeBrandKit.Checked
    $cpm = $chkWelcomeCPM.Checked
    $newInstall = $script:isNewInstall
    if ($Current -eq $requirementsPageIndex)       { return 0 }
    if ($Current -eq $systemPageIndex)             { return $requirementsPageIndex }
    if ($Current -eq $licencePageIndex)            { return $systemPageIndex }
    if ($Current -eq $fontPageIndex) {
        if ($newInstall) { return $licencePageIndex } else { return $systemPageIndex }
    }
    if ($Current -eq $assetPageIndex)              { return $fontPageIndex }
    if ($Current -eq $cpmPageIndex) {
        if ($brandKit) { return $assetPageIndex } else { return $fontPageIndex }
    }
    if ($Current -eq $reviewPageIndex) {
        if ($cpm)           { return $cpmPageIndex }
        elseif ($brandKit)  { return $assetPageIndex }
        else                { return $fontPageIndex }
    }
    return ($Current - 1)
}

function Get-WizardStepInfo {
    param([int]$PageIndex)
    $brandKit = $chkWelcomeBrandKit.Checked
    $cpm = $chkWelcomeCPM.Checked
    $newInstall = $script:isNewInstall
    $seq = [System.Collections.Generic.List[int]]::new()
    $seq.Add(0)
    $seq.Add($requirementsPageIndex)
    $seq.Add($systemPageIndex)
    if ($newInstall) { $seq.Add($licencePageIndex) }
    $seq.Add($fontPageIndex)
    if ($brandKit) { $seq.Add($assetPageIndex) }
    if ($cpm)      { $seq.Add($cpmPageIndex) }
    $seq.Add($reviewPageIndex)
    $seq.Add($progressPageIndex)
    $pos = $seq.IndexOf($PageIndex)
    if ($pos -lt 0) { $pos = 0 }
    return @{ Step = ($pos + 1); Total = $seq.Count }
}

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
        Add-ReviewChecklistItem -Ready $chkWelcomeCPM.Checked `
            -Name "Creative Project Mgmt" -Details $(if ($chkWelcomeCPM.Checked) { "SS-CAM app, Start Menu and Desktop shortcuts" } else { "Skipped by user" })
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
        $title.Text = "Creative Assets Management"
        $stepLabel.Text = "Creative Project Creator"
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Text = "Close"
        $cancelButton.Location = New-Object Drawing.Point(640, 631)
        $cancelButton.Visible = $true
        $createProjectBtn.Visible = $true
        $btnClearForm.Visible = $true
        $creatorStatusLabel.Visible = $true
        $btnNavSettings.Text = "Settings"
        $btnNavSettings.Visible = $true
        return
    }

    if ($Index -eq $settingsPageIndex) {
        $title.Text = "Creative Assets Management"
        $stepLabel.Text = "Settings and Maintenance"
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Text = "Close"
        $cancelButton.Location = New-Object Drawing.Point(640, 631)
        $cancelButton.Visible = $true
        $createProjectBtn.Visible = $false
        $btnClearForm.Visible = $false
        $creatorStatusLabel.Visible = $false
        $btnNavSettings.Text = "< Back"
        $btnNavSettings.Visible = $true
        return
    }

    # Wizard pages: hide creator action buttons and reset bottom bar
    $createProjectBtn.Visible = $false
    $btnClearForm.Visible = $false
    $creatorStatusLabel.Visible = $false
    $cancelButton.Location = New-Object Drawing.Point(536, 631)
    $btnOpenApp.Visible = $false

    $title.Text = "Brand Kit Setup Wizard"
    $btnNavSettings.Visible = $false

    # Dynamic step counter based on selected components and install type
    $stepInfo = Get-WizardStepInfo $Index
    $stepLabel.Text = "Step $($stepInfo.Step) of $($stepInfo.Total)"

    $isLastPage = ($Index -eq $progressPageIndex)
    $backButton.Visible = ($Index -gt 0 -and -not $isLastPage)
    $backButton.Enabled = -not $script:installationRunning
    $cancelButton.Text = "Cancel"
    $cancelButton.Visible = -not $script:setupComplete
    $cancelButton.Enabled = -not $script:installationRunning
    $nextButton.Visible = -not $isLastPage
    $nextButton.Enabled = (-not $script:installationRunning) -and
        ($Index -ne 0 -or ($chkWelcomeBrandKit.Checked -or $chkWelcomeCPM.Checked))
    $nextButton.Text = if ($Index -eq $reviewPageIndex) { "Install" } else { "Next >" }

    # Skip Fonts button (form-level) only visible on Font page
    $btnSkipFonts.Visible = ($Index -eq $fontPageIndex)

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
    if (-not [string]::IsNullOrWhiteSpace($InstallerExePath)) {
        $arguments += @("-InstallerExePath", (Quote-ProcessArgument $InstallerExePath))
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

# Skip Fonts button — skips font installation and advances to the next page
$btnSkipFonts.Add_Click({
    $fontChoice.SelectedIndex = 2   # "Do not install fonts"
    Show-Page (Get-NextPageIndex $script:pageIndex)
})

# Open App button — launches SS-CAM after setup completes
$btnOpenApp.Add_Click({
    $appExe = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management\SS-CAM.exe"
    if (Test-Path -LiteralPath $appExe -PathType Leaf) {
        Start-Process -FilePath $appExe
    }
    $form.Close()
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
        Show-Page (Get-PrevPageIndex $script:pageIndex)
    }
})
$cancelButton.Add_Click({
    if (-not $script:installationRunning) {
        $form.Close()
    }
})
$nextButton.Add_Click({
    # Welcome page: must select at least one component
    if ($script:pageIndex -eq 0) {
        if (-not $chkWelcomeBrandKit.Checked -and -not $chkWelcomeCPM.Checked) {
            $welcomeValidation.Visible = $true
            return
        }
        $copyAssets.Checked = $chkWelcomeBrandKit.Checked
        if (-not $chkWelcomeBrandKit.Checked -and $fontChoice.SelectedIndex -ne 2) { $fontChoice.SelectedIndex = 2 }
        Show-Page (Get-NextPageIndex $script:pageIndex)
        return
    }
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
        Show-Page (Get-NextPageIndex $script:pageIndex)
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
        try {
            $sourceExe = if (-not [string]::IsNullOrWhiteSpace($InstallerExePath) -and (Test-Path -LiteralPath $InstallerExePath -PathType Leaf)) {
                $InstallerExePath
            } else {
                [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            }

            if ($chkWelcomeCPM.Checked -and $sourceExe -and (Test-Path -LiteralPath $sourceExe -PathType Leaf) -and $sourceExe.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) {
                $appInstallDir = Join-Path $env:LOCALAPPDATA "Programs\SuamiSihat\SuamiSihat Creative Assets Management"
                New-Item -ItemType Directory -Path $appInstallDir -Force | Out-Null
                $targetExePath = Join-Path $appInstallDir "SS-CAM.exe"
                Copy-Item -LiteralPath $sourceExe -Destination $targetExePath -Force
                Install-SuamiSihatShortcuts -TargetExePath $targetExePath
            }
            try { Save-SuamiSihatAppState } catch {}
        } catch {}

        $script:setupComplete = $true
        $progressTitle.Text = "Setup complete"
        $progressStatus.Text = "This PC is ready for SuamiSihat design work."
        $progressStatus.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
        $completionHint.Text = "Restart any open Affinity or Adobe apps. Select Close (or Open App) to finish."
        $stepLabel.Text = "Completed successfully"
        $cancelButton.Visible = $false
        $nextButton.Visible = $true
        $nextButton.Text = "Close"
        $nextButton.Location = New-Object Drawing.Point(640, 631)
        $nextButton.Enabled = $true
        $nextButton.Add_Click({ $form.Close() })
        # Show Open App button if Creative Project Management was installed
        if ($chkWelcomeCPM.Checked) {
            $btnOpenApp.Visible = $true
            $btnOpenApp.Location = New-Object Drawing.Point(20, 631)
        }
        try { & $refreshAppVersionStatus } catch {}
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

$form.Add_Shown({
    try { &$refreshAppVersionStatus } catch {}
    if (-not $SmokeTest) {
        $worker = New-Object System.ComponentModel.BackgroundWorker
        $worker.add_DoWork({
            param($sender, $e)
            try {
                $e.Result = Get-SuamiSihatLatestRelease -CurrentVersion "1.6.2"
            } catch {
                $e.Result = $null
            }
        })
        $worker.add_RunWorkerCompleted({
            param($sender, $e)
            if ($null -ne $e.Result -and $e.Result.HasUpdate) {
                $script:updateInfo = $e.Result
                $headerUpdateBadge.Text = "Update v$($e.Result.LatestVersion)!"
                $headerUpdateBadge.Visible = $true
                $btnNavSettings.Text = "Settings *"
                $btnNavSettings.BackColor = [Drawing.Color]::FromArgb(194, 65, 12)

                $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(194, 65, 12)
                $updateStatusLabel.Text = "New Update Available: v$($e.Result.LatestVersion)"
                if (-not [string]::IsNullOrWhiteSpace($e.Result.DownloadUrl)) {
                    $btnInstallUpdate.Location = New-Object Drawing.Point(185, 68)
                    $btnInstallUpdate.Visible = $true
                    $updateStatusLabel.Location = New-Object Drawing.Point(335, 72)
                    $updateStatusLabel.Width = 310
                }
            } elseif ($null -ne $e.Result -and -not $e.Result.HasUpdate) {
                # Startup check confirmed: already on latest — mark button as up to date
                $btnCheckUpdate.Text = "Up to Date"
                $btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
                $btnCheckUpdate.Enabled = $false
                $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
                $updateStatusLabel.Text = "You are running the latest version (v1.6.2)."
            }
        })
        $worker.RunWorkerAsync()
    }
})

Refresh-PCRequirements
Refresh-SoftwareList
$installedInfo = Get-SuamiSihatInstalledVersion
if ($InstallerMode -or -not $installedInfo.IsInstalled) {
    Show-Page 0
} else {
    Show-Page $creatorPageIndex
}

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

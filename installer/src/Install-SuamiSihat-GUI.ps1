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

$script:AppVersion = "1.8.0"

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
    # Anchor page to all 4 edges so it stretches when the form is resized
    $page.Anchor = [Windows.Forms.AnchorStyles]::Top -bor
                   [Windows.Forms.AnchorStyles]::Bottom -bor
                   [Windows.Forms.AnchorStyles]::Left -bor
                   [Windows.Forms.AnchorStyles]::Right
    $page
}

# Anchor style shorthand aliases (used throughout to keep code readable)
$AL   = [Windows.Forms.AnchorStyles]
$TBLR = $AL::Top -bor $AL::Bottom -bor $AL::Left -bor $AL::Right
$TLR  = $AL::Top  -bor $AL::Left  -bor $AL::Right
$BLR  = $AL::Bottom -bor $AL::Left -bor $AL::Right
$TR   = $AL::Top  -bor $AL::Right
$BR   = $AL::Bottom -bor $AL::Right
$BL   = $AL::Bottom -bor $AL::Left

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
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.MinimumSize = New-Object Drawing.Size(780, 660)
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
$form.BackColor = [Drawing.Color]::FromArgb(244, 247, 251)
$form.Font = New-Object Drawing.Font("Segoe UI", 9)

# Taskbar & Form Icon Integration
$projectRoot = Split-Path $installerRoot -Parent
$iconFileCandidates = @(
    (Join-Path $projectRoot "payload\Brand Assets\Logos\ss_favicon\favicon.ico"),
    (Join-Path $installerRoot "assets\app-icon.ico"),
    (Join-Path $projectRoot "payload\Brand Assets\Logos\ss_app_icon\web\favicon.ico")
)
$iconFile = $iconFileCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($iconFile) {
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
$header.Anchor = $TLR
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
$btnNavSettings.Anchor = $TR
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
$headerUpdateBadge.Anchor = $TR
$header.Controls.Add($headerUpdateBadge)

$headerUpdateBadge.Add_Click({
    Show-Page $settingsPageIndex
})


$headerAccent = New-Object Windows.Forms.Panel
$headerAccent.Location = New-Object Drawing.Point(0, 88)
$headerAccent.Size = New-Object Drawing.Size(760, 4)
$headerAccent.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
$headerAccent.Anchor = $TLR
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




# ─────────────────────────────────────────────────────────────────────────────
# MERGED PAGE 2: System Check  (tabs: This PC | Design Apps)
# ─────────────────────────────────────────────────────────────────────────────
$systemCheckPage = New-Page
[void]$pages.Add($systemCheckPage)

$systemCheckTitle = New-Label -Text "System check" -X 24 -Y 16 -Width 670 -Height 34
$systemCheckTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$systemCheckTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$systemCheckPage.Controls.Add($systemCheckTitle)

$machineText = "$($systemInformation.Manufacturer) $($systemInformation.Model)  |  $($systemInformation.Windows)"
$requirementsMachine = New-Label -Text $machineText -X 27 -Y 55 -Width 680 -Height 22
$requirementsMachine.ForeColor = [Drawing.Color]::FromArgb(55, 65, 70)
$systemCheckPage.Controls.Add($requirementsMachine)

$systemCheckTabs = New-Object Windows.Forms.TabControl
$systemCheckTabs.Location = New-Object Drawing.Point(24, 82)
$systemCheckTabs.Size = New-Object Drawing.Size(672, 398)
$systemCheckTabs.Font = New-Object Drawing.Font("Segoe UI", 9)
$systemCheckPage.Controls.Add($systemCheckTabs)

# ── Tab 1: This PC ──────────────────────────────────────────────────────────
$tabThisPC = New-Object Windows.Forms.TabPage
$tabThisPC.Text = "  This PC  "
$tabThisPC.BackColor = [Drawing.Color]::White
[void]$systemCheckTabs.TabPages.Add($tabThisPC)

$requirementsList = New-Object Windows.Forms.ListView
$requirementsList.Location = New-Object Drawing.Point(4, 8)
$requirementsList.Size = New-Object Drawing.Size(658, 300)
$requirementsList.View = "Details"
$requirementsList.FullRowSelect = $true
$requirementsList.GridLines = $true
$requirementsList.HeaderStyle = "Nonclickable"
$requirementsList.ShowItemToolTips = $true
$requirementsList.Font = New-Object Drawing.Font("Segoe UI", 8.5)
[void]$requirementsList.Columns.Add("Status", 55)
[void]$requirementsList.Columns.Add("Component", 105)
[void]$requirementsList.Columns.Add("Detected", 250)
[void]$requirementsList.Columns.Add("SuamiSihat target", 218)
$tabThisPC.Controls.Add($requirementsList)

$requirementsNote = New-Label -Text "Minimum: Windows 10+ 64-bit and 16 GB RAM. Recommended rows guide performance and do not block installation." -X 4 -Y 315 -Width 658 -Height 40
$requirementsNote.ForeColor = [Drawing.Color]::DimGray
$tabThisPC.Controls.Add($requirementsNote)

# ── Tab 2: Design Apps ──────────────────────────────────────────────────────
$tabDesignApps = New-Object Windows.Forms.TabPage
$tabDesignApps.Text = "  Design Apps  "
$tabDesignApps.BackColor = [Drawing.Color]::White
[void]$systemCheckTabs.TabPages.Add($tabDesignApps)

$softwareList = New-Object Windows.Forms.ListView
$softwareList.Location = New-Object Drawing.Point(4, 8)
$softwareList.Size = New-Object Drawing.Size(658, 262)
$softwareList.View = "Details"
$softwareList.FullRowSelect = $true
$softwareList.GridLines = $true
$softwareList.ShowItemToolTips = $true
$softwareList.Font = New-Object Drawing.Font("Segoe UI", 8.5)
[void]$softwareList.Columns.Add("Application", 185)
[void]$softwareList.Columns.Add("Status", 110)
[void]$softwareList.Columns.Add("Installed Version", 130)
[void]$softwareList.Columns.Add("Latest Version", 130)
[void]$softwareList.Columns.Add("Get / Open", 89)
$tabDesignApps.Controls.Add($softwareList)

$softwareNote = New-Label -Text "Shared account: branding@suamisihat.com. Request the password and OTP from the team lead.  Click [Get] on any row to open the vendor download page." -X 4 -Y 276 -Width 534 -Height 34
$softwareNote.ForeColor = [Drawing.Color]::DimGray
$softwareNote.Font = New-Object Drawing.Font("Segoe UI", 7.8)
$tabDesignApps.Controls.Add($softwareNote)

$rescanButton = New-Object Windows.Forms.Button
$rescanButton.Text = "Rescan"
$rescanButton.Location = New-Object Drawing.Point(546, 278)
$rescanButton.Size = New-Object Drawing.Size(116, 32)
$tabDesignApps.Controls.Add($rescanButton)

$softwareContinue = New-Label -Text "You may continue even if optional design software is not installed yet." -X 4 -Y 318 -Width 658 -Height 22
$softwareContinue.ForeColor = [Drawing.Color]::DimGray
$tabDesignApps.Controls.Add($softwareContinue)

# Click the 'Get / Open' column (index 4) to launch vendor download page
$softwareList.Add_MouseDown({
    param($s, $e)
    $hit = $softwareList.HitTest($e.X, $e.Y)
    if ($hit.Item -and $hit.SubItem) {
        $colIndex = $hit.Item.SubItems.IndexOf($hit.SubItem)
        if ($colIndex -eq 4) {
            $url = [string]$hit.Item.Tag
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                Start-Process $url
            }
        }
    }
})

# Switch to Design Apps tab when navigating forward from requirements
$systemCheckTabs.Add_SelectedIndexChanged({
    if ($systemCheckTabs.SelectedIndex -eq 1) {
        $rescanButton.Enabled = $false
        $rescanButton.Text = "Scanning..."
        try { Refresh-SoftwareList } finally {
            $rescanButton.Text = "Rescan"
            $rescanButton.Enabled = $true
        }
    }
})

# ─────────────────────────────────────────────────────────────────────────────
# MERGED PAGE 3: Licence + Configuration
# ─────────────────────────────────────────────────────────────────────────────
$licenceConfigPage = New-Page
[void]$pages.Add($licenceConfigPage)

$licenceConfigTitle = New-Label -Text "Licence & configuration" -X 24 -Y 14 -Width 660 -Height 30
$licenceConfigTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$licenceConfigTitle.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$licenceConfigPage.Controls.Add($licenceConfigTitle)

# EULA box — slightly shorter than before to make room for config below
$licenceText = New-Object Windows.Forms.RichTextBox
$licenceText.Location = New-Object Drawing.Point(25, 50)
$licenceText.Size = New-Object Drawing.Size(670, 200)
$licenceText.ReadOnly = $true
$licenceText.BackColor = [Drawing.Color]::White
$licenceText.Text = Get-Content -LiteralPath $licenceFile -Raw
$licenceConfigPage.Controls.Add($licenceText)

$acceptLicence = New-Object Windows.Forms.CheckBox
$acceptLicence.Text = "I have read and accept the licence agreement."
$acceptLicence.Location = New-Object Drawing.Point(27, 258)
$acceptLicence.Size = New-Object Drawing.Size(620, 24)
$acceptLicence.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$acceptLicence.Enabled = $false   # enabled by scroll-to-bottom (M4.3)
$licenceConfigPage.Controls.Add($acceptLicence)

# Scroll-to-accept gate — enable checkbox once user reaches bottom of EULA
$licenceText.Add_VScroll({
    if (-not $acceptLicence.Enabled) {
        $pos   = $licenceText.GetPositionFromCharIndex($licenceText.TextLength - 1)
        $atEnd = ($pos.Y -le ($licenceText.Height + 40))
        if ($atEnd) { $acceptLicence.Enabled = $true }
    }
})

# ── Installation Options group ───────────────────────────────────────────────
$configGroup = New-Object Windows.Forms.GroupBox
$configGroup.Text = "  Installation Options"
$configGroup.Location = New-Object Drawing.Point(24, 288)
$configGroup.Size = New-Object Drawing.Size(672, 200)
$configGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$licenceConfigPage.Controls.Add($configGroup)

# Row 1: Font choice
$fontLabel = New-Label -Text "Fonts:" -X 12 -Y 26 -Width 60 -Height 22
$fontLabel.Font = New-Object Drawing.Font("Segoe UI", 9)
$configGroup.Controls.Add($fontLabel)

$fontChoice = New-Object Windows.Forms.ComboBox
$fontChoice.Location = New-Object Drawing.Point(74, 23)
$fontChoice.Size = New-Object Drawing.Size(310, 26)
$fontChoice.DropDownStyle = "DropDownList"
[void]$fontChoice.Items.Add("All bundled desktop fonts (recommended)")
[void]$fontChoice.Items.Add("Core brand fonts only")
[void]$fontChoice.Items.Add("Do not install fonts")
$fontChoice.SelectedIndex = 0
$configGroup.Controls.Add($fontChoice)

# Row 2: Brand assets + path
$copyAssets = New-Object Windows.Forms.CheckBox
$copyAssets.Text = "Copy brand-assets folder to:"
$copyAssets.Location = New-Object Drawing.Point(12, 60)
$copyAssets.Size = New-Object Drawing.Size(210, 24)
$copyAssets.Checked = $true
$configGroup.Controls.Add($copyAssets)

$destinationBox = New-Object Windows.Forms.TextBox
$destinationBox.Location = New-Object Drawing.Point(222, 58)
$destinationBox.Size = New-Object Drawing.Size(334, 26)
$destinationBox.Text = $defaultDestination
$configGroup.Controls.Add($destinationBox)

$browseButton = New-Object Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object Drawing.Point(562, 56)
$browseButton.Size = New-Object Drawing.Size(96, 28)
$browseButton.Font = New-Object Drawing.Font("Segoe UI", 9)
$configGroup.Controls.Add($browseButton)

# Row 3: Shortcuts + open-imports
$createWebShortcuts = New-Object Windows.Forms.CheckBox
$createWebShortcuts.Text = "Create Service Dashboard & Internal Assets web shortcuts"
$createWebShortcuts.Location = New-Object Drawing.Point(12, 96)
$createWebShortcuts.Size = New-Object Drawing.Size(470, 24)
$createWebShortcuts.Checked = $true
$configGroup.Controls.Add($createWebShortcuts)

$openImports = New-Object Windows.Forms.CheckBox
$openImports.Text = "Open Affinity/Adobe library files after copying"
$openImports.Location = New-Object Drawing.Point(12, 124)
$openImports.Size = New-Object Drawing.Size(470, 24)
$configGroup.Controls.Add($openImports)

# Row 4: CPM panel (visible only when CPM selected on welcome page)
$cpmConfigPanel = New-Object Windows.Forms.Panel
$cpmConfigPanel.Location = New-Object Drawing.Point(12, 156)
$cpmConfigPanel.Size = New-Object Drawing.Size(648, 32)
$cpmConfigPanel.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
$configGroup.Controls.Add($cpmConfigPanel)

$cpmConfigLabel = New-Label -Text "SS-CAM desktop app will be installed in: $($env:LOCALAPPDATA)\Programs\SuamiSihat\SuamiSihat Creative Assets Management" -X 8 -Y 7 -Width 634 -Height 18
$cpmConfigLabel.Font = New-Object Drawing.Font("Consolas", 7.5)
$cpmConfigLabel.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
$cpmConfigPanel.Controls.Add($cpmConfigLabel)

$reportNote = New-Label -Text "Reports folder is local. No PC information or account password is stored or uploaded." -X 27 -Y 494 -Width 630
$reportNote.ForeColor = [Drawing.Color]::DimGray
$licenceConfigPage.Controls.Add($reportNote)

# Keep these as variables the rest of the script references
$licencePage       = $licenceConfigPage
$fontPage          = $licenceConfigPage
$assetPage         = $licenceConfigPage
$cpmPage           = $licenceConfigPage
$requirementsPage  = $systemCheckPage
$systemPage        = $systemCheckPage

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

$creatorIntro = New-Label -Text "Official SuamiSihat creative project presets with automated folder structure, history tracking & Job ID management." -X 27 -Y 34 -Width 660 -Height 18
$creatorIntro.ForeColor = [Drawing.Color]::FromArgb(100, 110, 125)
$creatorPage.Controls.Add($creatorIntro)

# Card 1: Recent Projects Quick-Launcher Box (M4: upgraded to 5-item dropdown)
$recentGroup = New-Object Windows.Forms.GroupBox
$recentGroup.Text = " Recent Active Projects "
$recentGroup.Location = New-Object Drawing.Point(27, 52)
$recentGroup.Size = New-Object Drawing.Size(667, 60)
$recentGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($recentGroup)

$recentCombo = New-Object Windows.Forms.ComboBox
$recentCombo.Location = New-Object Drawing.Point(15, 18)
$recentCombo.Size = New-Object Drawing.Size(510, 24)
$recentCombo.DropDownStyle = "DropDownList"
$recentCombo.Font = New-Object Drawing.Font("Consolas", 8.5)
$recentCombo.ForeColor = [Drawing.Color]::FromArgb(4, 51, 136)
[void]$recentCombo.Items.Add("No recent projects yet.")
$recentCombo.SelectedIndex = 0
$recentGroup.Controls.Add($recentCombo)

# Keep the old label reference alive so updatePreview doesn't break
$recentInfoLabel = $recentCombo

$recentOpenBtn = New-Object Windows.Forms.Button
$recentOpenBtn.Text = "Open Folder"
$recentOpenBtn.Location = New-Object Drawing.Point(540, 17)
$recentOpenBtn.Size = New-Object Drawing.Size(112, 28)
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

# Top Row: Preset Selection & Target Platform / Specs Selection
$presetLabel = New-Label -Text "Creative Preset:" -X 15 -Y 22 -Width 370
$presetLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($presetLabel)

$targetPlatformLabel = New-Label -Text "Target Platform / Spec:" -X 395 -Y 22 -Width 250
$targetPlatformLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($targetPlatformLabel)

$presetCombo = New-Object Windows.Forms.ComboBox
$presetCombo.Location = New-Object Drawing.Point(15, 42)
$presetCombo.Size = New-Object Drawing.Size(370, 26)
$presetCombo.DropDownStyle = "DropDownList"
@("Graphic & Print Design", "Social Media & E-Commerce", "Video & Motion Graphics", "Brand Identity") | ForEach-Object { [void]$presetCombo.Items.Add($_) }
$presetCombo.SelectedIndex = 0
$paramGroup.Controls.Add($presetCombo)

$targetPlatformCombo = New-Object Windows.Forms.ComboBox
$targetPlatformCombo.Location = New-Object Drawing.Point(395, 42)
$targetPlatformCombo.Size = New-Object Drawing.Size(257, 26)
$targetPlatformCombo.DropDownStyle = "DropDownList"
@(
    "Meta / IG Square (1:1 - 1080x1080 RGB)",
    "TikTok / Reels / Story (9:16 - 1080x1920 RGB)",
    "YouTube Video (16:9 - 1920x1080 / 4K RGB)",
    "E-Commerce / Web Banner (1200x628 RGB)",
    "POSM Print / Banner (CMYK 300 DPI)",
    "General Asset (Custom Specs)"
) | ForEach-Object { [void]$targetPlatformCombo.Items.Add($_) }
$targetPlatformCombo.SelectedIndex = 0
$paramGroup.Controls.Add($targetPlatformCombo)

# Row 2: Year, Sub-Brand, Job ID, Designer Profile, Project Name
$yearLabel = New-Label -Text "Year:" -X 15 -Y 72 -Width 70
$yearLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($yearLabel)

$yearCombo = New-Object Windows.Forms.ComboBox
$yearCombo.Location = New-Object Drawing.Point(15, 92)
$yearCombo.Size = New-Object Drawing.Size(80, 26)
$yearCombo.DropDownStyle = "DropDownList"
$currentYrInt = [int](Get-Date).ToString("yyyy")
(($currentYrInt - 2)..($currentYrInt + 3)) | ForEach-Object { [void]$yearCombo.Items.Add($_) }
$yearCombo.SelectedItem = $currentYrInt
$paramGroup.Controls.Add($yearCombo)

# Sub-Brand Selection
$brandLabel = New-Label -Text "Sub-Brand:" -X 102 -Y 72 -Width 90
$brandLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($brandLabel)

$subBrandCombo = New-Object Windows.Forms.ComboBox
$subBrandCombo.Location = New-Object Drawing.Point(102, 92)
$subBrandCombo.Size = New-Object Drawing.Size(95, 26)
$subBrandCombo.DropDownStyle = "DropDownList"
@("SS", "SSH", "SSC", "SSW", "SSE", "SST") | ForEach-Object { [void]$subBrandCombo.Items.Add($_) }
$subBrandCombo.SelectedIndex = 0
$paramGroup.Controls.Add($subBrandCombo)

# Job ID Code
$jobLabel = New-Label -Text "Job ID:" -X 204 -Y 72 -Width 90
$jobLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($jobLabel)

$jobIdText = New-Object Windows.Forms.TextBox
$jobIdText.Location = New-Object Drawing.Point(204, 92)
$jobIdText.Size = New-Object Drawing.Size(95, 25)
$jobIdText.Text = $script:appState.NextJobNumber
$paramGroup.Controls.Add($jobIdText)

# Active Designer Profile Switcher
$designerProfileLabel = New-Label -Text "Designer Profile:" -X 306 -Y 72 -Width 150
$designerProfileLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($designerProfileLabel)

$designerProfileCombo = New-Object Windows.Forms.ComboBox
$designerProfileCombo.Location = New-Object Drawing.Point(306, 92)
$designerProfileCombo.Size = New-Object Drawing.Size(165, 26)
$designerProfileCombo.DropDownStyle = "DropDownList"
if ($script:appState.Profiles) {
    foreach ($prof in $script:appState.Profiles) { [void]$designerProfileCombo.Items.Add($prof.Name) }
}
if ($designerProfileCombo.Items.Count -eq 0) {
    [void]$designerProfileCombo.Items.Add($script:appState.DesignerName)
}
$designerProfileCombo.SelectedIndex = 0
$paramGroup.Controls.Add($designerProfileCombo)

# Project Name
$nameLabel = New-Label -Text "Project Name:" -X 478 -Y 72 -Width 170
$nameLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($nameLabel)

$projectNameText = New-Object Windows.Forms.TextBox
$projectNameText.Location = New-Object Drawing.Point(478, 92)
$projectNameText.Size = New-Object Drawing.Size(174, 25)
$projectNameText.Text = "POSM_Banner"
$paramGroup.Controls.Add($projectNameText)

# Project Description / Creative Brief Input (Saved as README.md)
$descLabel = New-Label -Text "Project Description / Creative Brief (Markdown - saved as README.md):" -X 15 -Y 122 -Width 610
$descLabel.BackColor = [Drawing.Color]::Transparent
$paramGroup.Controls.Add($descLabel)

$projDescText = New-Object Windows.Forms.TextBox
$projDescText.Multiline = $true
$projDescText.ScrollBars = "Vertical"
$projDescText.Location = New-Object Drawing.Point(15, 142)
$projDescText.Size = New-Object Drawing.Size(637, 44)
$projDescText.Text = "# Creative Brief`r`n- Objective: SuamiSihat Marketing Campaign`r`n- Deliverables: Brand Graphics & Digital Assets"
$paramGroup.Controls.Add($projDescText)

# Drag-to-resize handle — replaces the old expand/collapse toggle
$descResizeHandle = New-Object Windows.Forms.Panel
$descResizeHandle.Location = New-Object Drawing.Point(15, 188)   # directly below projDescText (142+44+2)
$descResizeHandle.Size = New-Object Drawing.Size(637, 6)
$descResizeHandle.BackColor = [Drawing.Color]::FromArgb(200, 210, 230)
$descResizeHandle.Cursor = [Windows.Forms.Cursors]::SizeNS
$paramGroup.Controls.Add($descResizeHandle)
$script:dragStartY = 0
$script:dragStartH = 0

# Options Checkboxes — Y anchored to $script:chkBaseY so they follow the drag handle
$script:chkBaseY = 195
$chkInjectTemplate = New-Object Windows.Forms.CheckBox
$chkInjectTemplate.Text = "Inject Master Canvas"
$chkInjectTemplate.Location = New-Object Drawing.Point(15, $script:chkBaseY)
$chkInjectTemplate.Size = New-Object Drawing.Size(145, 24)
$chkInjectTemplate.Checked = $true
$paramGroup.Controls.Add($chkInjectTemplate)

$comboTemplateExt = New-Object Windows.Forms.ComboBox
$comboTemplateExt.Location = New-Object Drawing.Point(162, 196)
$comboTemplateExt.Size = New-Object Drawing.Size(100, 24)
$comboTemplateExt.DropDownStyle = "DropDownList"
@(".af", ".afdesign", ".psd", ".ai", ".svg") | ForEach-Object { [void]$comboTemplateExt.Items.Add($_) }
$comboTemplateExt.SelectedIndex = 0
$paramGroup.Controls.Add($comboTemplateExt)

$chkExtraRevisions = New-Object Windows.Forms.CheckBox
$chkExtraRevisions.Text = "+ Revisions Folder"
$chkExtraRevisions.Location = New-Object Drawing.Point(275, $script:chkBaseY)
$chkExtraRevisions.Size = New-Object Drawing.Size(135, 24)
$paramGroup.Controls.Add($chkExtraRevisions)

$chkExtraRaw = New-Object Windows.Forms.CheckBox
$chkExtraRaw.Text = "+ RAW Media"
$chkExtraRaw.Location = New-Object Drawing.Point(420, $script:chkBaseY)
$chkExtraRaw.Size = New-Object Drawing.Size(130, 24)
$paramGroup.Controls.Add($chkExtraRaw)

# Workspace Root Location Text Box (Hidden internally, customizable via Settings)
$workspacePathText = New-Object Windows.Forms.TextBox
$workspacePathText.Text = $script:appState.DefaultWorkspace

# M4: Visible workspace root LinkLabel — clicking opens Explorer at root
$workspaceRootLink = New-Object Windows.Forms.LinkLabel
$workspaceRootLink.Location = New-Object Drawing.Point(27, 358)
$workspaceRootLink.Size = New-Object Drawing.Size(667, 18)
$workspaceRootLink.Font = New-Object Drawing.Font("Consolas", 7.5)
$workspaceRootLink.ForeColor = [Drawing.Color]::FromArgb(100, 110, 125)
$workspaceRootLink.Text = "Workspace: $($workspacePathText.Text)"
$workspaceRootLink.LinkColor = [Drawing.Color]::FromArgb(4, 51, 136)
$workspaceRootLink.ActiveLinkColor = [Drawing.Color]::FromArgb(33, 161, 247)
$workspaceRootLink.Add_LinkClicked({
    $root = $workspacePathText.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-Path -LiteralPath $root -PathType Container)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$root`""
    }
})
$creatorPage.Controls.Add($workspaceRootLink)

# NAS / Team Registry status indicator
$nasStatusDot = New-Label -Text "●" -X 27 -Y 378 -Width 16 -Height 18
$nasStatusDot.Font = New-Object Drawing.Font("Segoe UI", 9)
$nasStatusDot.ForeColor = [Drawing.Color]::FromArgb(160, 165, 175)
$creatorPage.Controls.Add($nasStatusDot)

$nasStatusLabel = New-Label -Text "NAS: checking..." -X 45 -Y 378 -Width 280 -Height 18
$nasStatusLabel.Font = New-Object Drawing.Font("Segoe UI", 7.5)
$nasStatusLabel.ForeColor = [Drawing.Color]::FromArgb(120, 125, 135)
$creatorPage.Controls.Add($nasStatusLabel)

$script:UpdateNASStatus = {
    $ws = $workspacePathText.Text.Trim()
    if (Test-NASAvailable -WorkspaceRoot $ws) {
        $nasStatusDot.ForeColor  = [Drawing.Color]::FromArgb(20, 135, 75)   # green
        $poolCount = @($script:appState.LocalJobPool).Count
        $nasStatusLabel.Text = if ($poolCount -gt 0) { "NAS: Online  -  Local pool: $poolCount IDs" } else { "NAS: Online" }
    } else {
        $poolCount = @($script:appState.LocalJobPool).Count
        $nasStatusDot.ForeColor  = if ($poolCount -gt 0) {
            [Drawing.Color]::FromArgb(194, 115, 12)  # orange: offline but pool available
        } else {
            [Drawing.Color]::FromArgb(194, 45, 55)   # red: offline, no pool
        }
        $nasStatusLabel.Text = if ($poolCount -gt 0) {
            "NAS: Offline  •  Pool: $poolCount IDs remaining"
        } else {
            "NAS: Offline  -  No local pool. Connect NAS to continue."
        }
    }
}

# Folder Path Preview Box & 1-Click Clipboard Copy (Feature 1)
$previewGroup = New-Object Windows.Forms.GroupBox
$previewGroup.Text = " Folder Path Preview "
$previewGroup.Location = New-Object Drawing.Point(27, 380)
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
$structureGroup.Location = New-Object Drawing.Point(27, 441)
$structureGroup.Size = New-Object Drawing.Size(667, 125)
$structureGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$creatorPage.Controls.Add($structureGroup)

$structureInfoLabel = New-Label -Text "" -X 15 -Y 18 -Width 637 -Height 100
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
$fontGroup.Location = New-Object Drawing.Point(27, 65)
$fontGroup.Size = New-Object Drawing.Size(667, 95)
$fontGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($fontGroup)

$fontGroupInfo = New-Label -Text "Reinstall or repair official bundled fonts (Poppins, Calibri, Helvetica Neue, Montserrat, FontAwesome Pro, etc.) and sync design libraries." -X 15 -Y 22 -Width 637 -Height 30
$fontGroupInfo.Font = New-Object Drawing.Font("Segoe UI", 9)
$fontGroup.Controls.Add($fontGroupInfo)

$repairFontsBtn = New-Object Windows.Forms.Button
$repairFontsBtn.Text = "Reinstall / Repair Fonts && Brand Assets"
$repairFontsBtn.Location = New-Object Drawing.Point(15, 52)
$repairFontsBtn.Size = New-Object Drawing.Size(270, 32)
$repairFontsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$repairFontsBtn.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$repairFontsBtn.ForeColor = [Drawing.Color]::White
$repairFontsBtn.FlatStyle = "Flat"
$repairFontsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$fontGroup.Controls.Add($repairFontsBtn)

$uninstallSettingsBtn = New-Object Windows.Forms.Button
$uninstallSettingsBtn.Text = "Uninstall App && Shortcuts"
$uninstallSettingsBtn.Location = New-Object Drawing.Point(300, 52)
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
$appGroup.Location = New-Object Drawing.Point(27, 165)
$appGroup.Size = New-Object Drawing.Size(667, 125)
$appGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($appGroup)

$setWorkspaceLabel = New-Label -Text "Default Parent Workspace Directory:" -X 15 -Y 22 -Width 300
$appGroup.Controls.Add($setWorkspaceLabel)

$setWorkspaceText = New-Object Windows.Forms.TextBox
$setWorkspaceText.Location = New-Object Drawing.Point(15, 42)
$setWorkspaceText.Size = New-Object Drawing.Size(520, 27)
$setWorkspaceText.Text = $script:appState.DefaultWorkspace
$appGroup.Controls.Add($setWorkspaceText)

$setWorkspaceBrowseBtn = New-Object Windows.Forms.Button
$setWorkspaceBrowseBtn.Text = "Browse..."
$setWorkspaceBrowseBtn.Location = New-Object Drawing.Point(543, 40)
$setWorkspaceBrowseBtn.Size = New-Object Drawing.Size(107, 31)
$appGroup.Controls.Add($setWorkspaceBrowseBtn)

$setJobLabel = New-Label -Text "Next Job ID Counter (e.g. D0075):" -X 15 -Y 75 -Width 220
$appGroup.Controls.Add($setJobLabel)

$setJobText = New-Object Windows.Forms.TextBox
$setJobText.Location = New-Object Drawing.Point(15, 93)
$setJobText.Size = New-Object Drawing.Size(160, 27)
$setJobText.Text = $script:appState.NextJobNumber
$appGroup.Controls.Add($setJobText)

$saveSettingsBtn = New-Object Windows.Forms.Button
$saveSettingsBtn.Text = "Save Settings"
$saveSettingsBtn.Size = New-Object Drawing.Size(140, 34)
$saveSettingsBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$saveSettingsBtn.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$saveSettingsBtn.ForeColor = [Drawing.Color]::White
$saveSettingsBtn.FlatStyle = "Flat"
$saveSettingsBtn.Cursor = [Windows.Forms.Cursors]::Hand
$saveSettingsBtn.Visible = $false
$saveSettingsBtn.Anchor = $BR
$form.Controls.Add($saveSettingsBtn)

$settingsStatusLabel = New-Label -Text "" -X 185 -Y 95 -Width 465 -Height 24
$settingsStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$appGroup.Controls.Add($settingsStatusLabel)

# Group 3: Designer Profile & Signature
$profileGroup = New-Object Windows.Forms.GroupBox
$profileGroup.Text = " Designer Profile && Signature "
$profileGroup.Location = New-Object Drawing.Point(27, 295)
$profileGroup.Size = New-Object Drawing.Size(667, 185)
$profileGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($profileGroup)

# Row 1: Staff ID | Designer Name | Department | Email
$setStaffIDLabel = New-Label -Text "Staff ID:" -X 15 -Y 22 -Width 70
$profileGroup.Controls.Add($setStaffIDLabel)
$setStaffIDText = New-Object Windows.Forms.TextBox
$setStaffIDText.Location = New-Object Drawing.Point(15, 44)
$setStaffIDText.Size = New-Object Drawing.Size(65, 27)
$setStaffIDText.CharacterCasing = "Upper"
$setStaffIDText.MaxLength = 5
$setStaffIDText.Text = $script:appState.StaffID
$setStaffIDText.Font = New-Object Drawing.Font("Consolas", 10, [Drawing.FontStyle]::Bold)
$profileGroup.Controls.Add($setStaffIDText)

# Designer Name
$setDesignerNameLabel = New-Label -Text "Designer Name:" -X 95 -Y 22 -Width 160
$profileGroup.Controls.Add($setDesignerNameLabel)
$setDesignerNameText = New-Object Windows.Forms.TextBox
$setDesignerNameText.Location = New-Object Drawing.Point(95, 44)
$setDesignerNameText.Size = New-Object Drawing.Size(175, 27)
$setDesignerNameText.Text = $script:appState.DesignerName
$profileGroup.Controls.Add($setDesignerNameText)

# Department
$setDeptLabel = New-Label -Text "Department / Role:" -X 285 -Y 22 -Width 150
$profileGroup.Controls.Add($setDeptLabel)
$setDeptText = New-Object Windows.Forms.TextBox
$setDeptText.Location = New-Object Drawing.Point(285, 44)
$setDeptText.Size = New-Object Drawing.Size(150, 27)
$setDeptText.Text = $script:appState.Department
$profileGroup.Controls.Add($setDeptText)

# Email Address
$setDesignerEmailLabel = New-Label -Text "Email Address:" -X 448 -Y 22 -Width 200
$profileGroup.Controls.Add($setDesignerEmailLabel)
$setDesignerEmailText = New-Object Windows.Forms.TextBox
$setDesignerEmailText.Location = New-Object Drawing.Point(448, 44)
$setDesignerEmailText.Size = New-Object Drawing.Size(200, 27)
$setDesignerEmailText.Text = $script:appState.DesignerEmail
$profileGroup.Controls.Add($setDesignerEmailText)

# Avatar File Path (row 2)
$setAvatarLabel = New-Label -Text "Avatar Profile Image (JPG/PNG/SVG):" -X 15 -Y 108 -Width 380
$profileGroup.Controls.Add($setAvatarLabel)
$setAvatarPathText = New-Object Windows.Forms.TextBox
$setAvatarPathText.Location = New-Object Drawing.Point(15, 130)
$setAvatarPathText.Size = New-Object Drawing.Size(400, 27)
$setAvatarPathText.Text = $script:appState.AvatarPath
$profileGroup.Controls.Add($setAvatarPathText)

$setAvatarBrowseBtn = New-Object Windows.Forms.Button
$setAvatarBrowseBtn.Text = "Browse..."
$setAvatarBrowseBtn.Location = New-Object Drawing.Point(423, 128)
$setAvatarBrowseBtn.Size = New-Object Drawing.Size(85, 29)
$setAvatarBrowseBtn.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$profileGroup.Controls.Add($setAvatarBrowseBtn)

$avatarPictureBox = New-Object Windows.Forms.PictureBox
$avatarPictureBox.Location = New-Object Drawing.Point(530, 108)
$avatarPictureBox.Size = New-Object Drawing.Size(55, 55)
$avatarPictureBox.SizeMode = "Zoom"
$avatarPictureBox.BorderStyle = "FixedSingle"
$profileGroup.Controls.Add($avatarPictureBox)

if ($script:appState.AvatarPath -and (Test-Path -LiteralPath $script:appState.AvatarPath -PathType Leaf)) {
    try { $avatarPictureBox.ImageLocation = $script:appState.AvatarPath } catch {}
}

# Auto-Save Designer Profile on change / leave
$autoSaveProfile = {
    try {
        $script:appState = Save-SuamiSihatAppState `
            -LastProjectPath $script:appState.LastProjectPath `
            -LastProjectName $script:appState.LastProjectName `
            -LastJobNumber $setJobText.Text.Trim() `
            -DefaultWorkspace $setWorkspaceText.Text.Trim() `
            -DesignerName $setDesignerNameText.Text.Trim() `
            -Department $setDeptText.Text.Trim() `
            -DesignerEmail $setDesignerEmailText.Text.Trim() `
            -AvatarPath $setAvatarPathText.Text.Trim() `
            -StaffID $setStaffIDText.Text.Trim()
    } catch {}
}

$setStaffIDText.Add_Leave($autoSaveProfile)
$setDesignerNameText.Add_Leave($autoSaveProfile)
$setDeptText.Add_Leave($autoSaveProfile)
$setDesignerEmailText.Add_Leave($autoSaveProfile)
$setAvatarPathText.Add_Leave($autoSaveProfile)

$setAvatarBrowseBtn.Add_Click({
    $openFile = New-Object Windows.Forms.OpenFileDialog
    $openFile.Filter = "Image Files (*.png;*.jpg;*.jpeg;*.bmp;*.ico;*.svg)|*.png;*.jpg;*.jpeg;*.bmp;*.ico;*.svg|All Files (*.*)|*.*"
    $openFile.Title = "Select Designer Avatar Image"
    if ($openFile.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $setAvatarPathText.Text = $openFile.FileName
        if (Test-Path -LiteralPath $openFile.FileName -PathType Leaf) {
            try { $avatarPictureBox.ImageLocation = $openFile.FileName } catch {}
        }
        & $autoSaveProfile
    }
})

$saveSettingsBtn.Add_Click({
    try {
        $script:appState = Save-SuamiSihatAppState `
            -LastProjectPath $script:appState.LastProjectPath `
            -LastProjectName $script:appState.LastProjectName `
            -LastJobNumber $setJobText.Text.Trim() `
            -DefaultWorkspace $setWorkspaceText.Text.Trim() `
            -DesignerName $setDesignerNameText.Text.Trim() `
            -Department $setDeptText.Text.Trim() `
            -DesignerEmail $setDesignerEmailText.Text.Trim() `
            -AvatarPath $setAvatarPathText.Text.Trim() `
            -StaffID $setStaffIDText.Text.Trim()

        $jobIdText.Text = $script:appState.NextJobNumber
        $workspacePathText.Text = $script:appState.DefaultWorkspace
        $workspaceRootLink.Text = "Workspace: $($script:appState.DefaultWorkspace)"
        $settingsStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $settingsStatusLabel.Text = "Settings auto-saved & applied!"
    } catch {
        $settingsStatusLabel.ForeColor = [Drawing.Color]::Firebrick
        $settingsStatusLabel.Text = "Error saving settings: $($_.Exception.Message)"
    }
})

# Group 4: About & Software Updates
$updateGroup = New-Object Windows.Forms.GroupBox
$updateGroup.Text = " About && Software Updates "
$updateGroup.Location = New-Object Drawing.Point(27, 460)
$updateGroup.Size = New-Object Drawing.Size(667, 160)
$updateGroup.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$settingsPage.Controls.Add($updateGroup)

# Line 1 — Product name + installed version (updated by refreshAppVersionStatus)
$aboutLabel = New-Label -Text "SuamiSihat Creative Assets Management  |  Installed Version: v$($script:AppVersion)" -X 15 -Y 22 -Width 637 -Height 18
$aboutLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$aboutLabel.ForeColor = [Drawing.Color]::FromArgb(30, 41, 59)
$updateGroup.Controls.Add($aboutLabel)

# Line 2 — Exe path (updated by refreshAppVersionStatus)
$aboutExeLabel = New-Label -Text "GitHub: https://github.com/SuamiSihat/SS-Designer-Assets" -X 15 -Y 40 -Width 637 -Height 16
$aboutExeLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
$aboutExeLabel.ForeColor = [Drawing.Color]::FromArgb(100, 110, 125)
$updateGroup.Controls.Add($aboutExeLabel)

# Line 3 — Clickable GitHub link row
$linkSep1 = New-Label -Text "|" -X 128 -Y 60 -Width 10 -Height 16
$linkSep1.ForeColor = [Drawing.Color]::FromArgb(180, 190, 210)
$linkSep1.Font = New-Object Drawing.Font("Segoe UI", 8)
$updateGroup.Controls.Add($linkSep1)

$linkSep2 = New-Label -Text "|" -X 248 -Y 60 -Width 10 -Height 16
$linkSep2.ForeColor = [Drawing.Color]::FromArgb(180, 190, 210)
$linkSep2.Font = New-Object Drawing.Font("Segoe UI", 8)
$updateGroup.Controls.Add($linkSep2)

$linkSep3 = New-Label -Text "|" -X 388 -Y 60 -Width 10 -Height 16
$linkSep3.ForeColor = [Drawing.Color]::FromArgb(180, 190, 210)
$linkSep3.Font = New-Object Drawing.Font("Segoe UI", 8)
$updateGroup.Controls.Add($linkSep3)

$linkGitHub = New-Object Windows.Forms.LinkLabel
$linkGitHub.Text = "GitHub Repository"
$linkGitHub.Location = New-Object Drawing.Point(15, 60)
$linkGitHub.Size = New-Object Drawing.Size(112, 16)
$linkGitHub.Font = New-Object Drawing.Font("Segoe UI Semibold", 8)
$linkGitHub.LinkColor = [Drawing.Color]::FromArgb(4, 51, 136)
$linkGitHub.ActiveLinkColor = [Drawing.Color]::FromArgb(33, 161, 247)
$linkGitHub.Add_LinkClicked({ Start-Process "https://github.com/SuamiSihat/SS-Brand-Assets" })
$updateGroup.Controls.Add($linkGitHub)

$linkReleases = New-Object Windows.Forms.LinkLabel
$linkReleases.Text = "Releases & Downloads"
$linkReleases.Location = New-Object Drawing.Point(140, 60)
$linkReleases.Size = New-Object Drawing.Size(106, 16)
$linkReleases.Font = New-Object Drawing.Font("Segoe UI Semibold", 8)
$linkReleases.LinkColor = [Drawing.Color]::FromArgb(4, 51, 136)
$linkReleases.ActiveLinkColor = [Drawing.Color]::FromArgb(33, 161, 247)
$linkReleases.Add_LinkClicked({ Start-Process "https://github.com/SuamiSihat/SS-Brand-Assets/releases" })
$updateGroup.Controls.Add($linkReleases)

$linkChangelog = New-Object Windows.Forms.LinkLabel
$linkChangelog.Text = "Dev Updates & Commits"
$linkChangelog.Location = New-Object Drawing.Point(260, 60)
$linkChangelog.Size = New-Object Drawing.Size(126, 16)
$linkChangelog.Font = New-Object Drawing.Font("Segoe UI Semibold", 8)
$linkChangelog.LinkColor = [Drawing.Color]::FromArgb(4, 51, 136)
$linkChangelog.ActiveLinkColor = [Drawing.Color]::FromArgb(33, 161, 247)
$linkChangelog.Add_LinkClicked({ Start-Process "https://github.com/SuamiSihat/SS-Brand-Assets/commits/SS-Master" })
$updateGroup.Controls.Add($linkChangelog)

$linkIssues = New-Object Windows.Forms.LinkLabel
$linkIssues.Text = "Report an Issue"
$linkIssues.Location = New-Object Drawing.Point(400, 60)
$linkIssues.Size = New-Object Drawing.Size(100, 16)
$linkIssues.Font = New-Object Drawing.Font("Segoe UI Semibold", 8)
$linkIssues.LinkColor = [Drawing.Color]::FromArgb(194, 65, 12)
$linkIssues.ActiveLinkColor = [Drawing.Color]::FromArgb(220, 100, 40)
$linkIssues.Add_LinkClicked({ Start-Process "https://github.com/SuamiSihat/SS-Brand-Assets/issues/new" })
$updateGroup.Controls.Add($linkIssues)

# Row 4 — Update action row
$btnCheckUpdate = New-Object Windows.Forms.Button
$btnCheckUpdate.Text = "Check for Updates"
$btnCheckUpdate.Location = New-Object Drawing.Point(15, 116)
$btnCheckUpdate.Size = New-Object Drawing.Size(160, 32)
$btnCheckUpdate.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$btnCheckUpdate.ForeColor = [Drawing.Color]::White
$btnCheckUpdate.FlatStyle = "Flat"
$btnCheckUpdate.Cursor = [Windows.Forms.Cursors]::Hand
$updateGroup.Controls.Add($btnCheckUpdate)

$btnInstallUpdate = New-Object Windows.Forms.Button
$btnInstallUpdate.Text = "Install Update"
$btnInstallUpdate.Location = New-Object Drawing.Point(185, 116)
$btnInstallUpdate.Size = New-Object Drawing.Size(140, 32)
$btnInstallUpdate.Font = New-Object Drawing.Font("Segoe UI Semibold", 8.5)
$btnInstallUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
$btnInstallUpdate.ForeColor = [Drawing.Color]::White
$btnInstallUpdate.FlatStyle = "Flat"
$btnInstallUpdate.Cursor = [Windows.Forms.Cursors]::Hand
$btnInstallUpdate.Visible = $false
$updateGroup.Controls.Add($btnInstallUpdate)

$updateStatusLabel = New-Label -Text "" -X 185 -Y 120 -Width 465 -Height 26
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
    $dateCode = "${selYear}${curMonthNum}"

    $rootBase = $workspacePathText.Text.Trim()
    if ($rootBase -match '\\SS-\d{4}$') {
        $rootBase = Split-Path -Parent $rootBase
    }

    $sub = switch -Wildcard ([string]$subBrandCombo.SelectedItem) {
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

    $job = ($jobIdText.Text.Trim() -replace '\s+', '').ToUpper()
    if ($job -notmatch '^[A-Z]') { $job = "D$job" }
    $proj = ($projectNameText.Text.Trim() -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($proj)) { $proj = "Project" }
    
    $folderName = "${dateCode}_${job}_${sub}_${proj}"
    $targetPath = Join-Path (Join-Path (Join-Path $rootBase $yearFolder) $monthFolder) $folderName
    $previewPathLabel.Text = $targetPath

    # M4: Refresh Recent Projects ComboBox (shows up to 5 recent projects)
    $recentCombo.Items.Clear()
    if ($script:appState.RecentProjects -and $script:appState.RecentProjects.Count -gt 0) {
        $maxRecent = [Math]::Min($script:appState.RecentProjects.Count, 5)
        for ($i = 0; $i -lt $maxRecent; $i++) {
            $rp = $script:appState.RecentProjects[$i]
            [void]$recentCombo.Items.Add("$($rp.FolderName)  ($($rp.Created))")
        }
        $recentCombo.SelectedIndex = 0
        $recentOpenBtn.Enabled = $true
    } else {
        [void]$recentCombo.Items.Add("No recent projects yet.")
        $recentCombo.SelectedIndex = 0
        $recentOpenBtn.Enabled = $false
    }
    # M4: Update workspace root link label
    $workspaceRootLink.Text = "Workspace: $($workspacePathText.Text)"
    $b = [char]0x251C + [char]0x2500 + [char]0x2500 + " "
    $e = [char]0x2514 + [char]0x2500 + [char]0x2500 + " "

    $baseFolders = switch -Wildcard ($presetCombo.SelectedItem) {
        "*Social*"  {
            @("Working Files\      (PSD/AF source design files)",
              "Source Assets\      (Photos & reference graphics)",
              "Copywriting\        (Ad text copy & caption files)",
              "Final Exports\      (Exported web & social graphics)")
        }
        "*Video*"   {
            @("Project Files\      (NLE PR/AE/DR timeline files)",
              "Footage\            (Raw video clips & recordings)",
              "Audio\              (SFX & music stems)",
              "Final Exports\      (Master rendered MP4/MOV outputs)")
        }
        "*Brand*"   {
            @("Vector Master\      (SVG & AI master logos)",
              "Brand Guidelines\   (Brand system documentation PDF)",
              "Colour Palettes\    (ASE & AF palette files)",
              "Export Packages\    (ZIP distribution packages)")
        }
        default     {
            @("Artwork Design\     (Working source files: .afdesign, .psd, .ai)",
              "Artwork Mockup\     (Presentation mockups & client previews)",
              "Assets\             (Raw photos, icons, reference materials)",
              "Production\         (Exported outputs: PDF, PNG, SVG)")
        }
    }

    $folderList = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $baseFolders) { $folderList.Add($f) }

    if ($chkExtraRevisions.Checked) {
        $folderList.Add("Client Revisions\   (Client feedback & revision iterations)")
    }
    if ($chkExtraRaw.Checked) {
        $folderList.Add("RAW Media\          (Uncompressed audio stems, 3D models & raw media)")
    }

    $treeLines = @()
    $selectedExt = if ($comboTemplateExt -and $comboTemplateExt.SelectedItem) { [string]$comboTemplateExt.SelectedItem } else { ".afdesign" }
    for ($i = 0; $i -lt $folderList.Count; $i++) {
        $prefixSymbol = if ($i -eq ($folderList.Count - 1)) { $e } else { $b }
        $treeLines += "${prefixSymbol}$($folderList[$i])"
        
        if ($i -eq 0 -and $chkInjectTemplate.Checked) {
            $canvasPreviewName = "${folderName}${selectedExt}"
            $treeLines += "    ${b}${canvasPreviewName}  (Pre-configured brand starter template)"
        }
    }

    $structureInfoLabel.Text = $treeLines -join "`r`n"
}

# Drag-to-resize description box — MouseDown/Move/Up on the grip handle
$descResizeHandle.Add_MouseDown({
    param($s, $e)
    if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $script:dragStartY = [Windows.Forms.Cursor]::Position.Y
        $script:dragStartH = $projDescText.Height
    }
})

$descResizeHandle.Add_MouseMove({
    param($s, $e)
    if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $curY   = [Windows.Forms.Cursor]::Position.Y
        $delta  = $curY - $script:dragStartY
        $newH   = [Math]::Max(28, [Math]::Min(220, $script:dragStartH + $delta))

        $projDescText.Height           = $newH
        $descResizeHandle.Top          = $projDescText.Bottom + 2

        $chkY = $descResizeHandle.Bottom + 4
        $chkInjectTemplate.Top  = $chkY
        $chkExtraRevisions.Top  = $chkY
        $chkExtraRaw.Top        = $chkY

        $paramGroup.Height = $chkY + 30
        $previewGroup.Top  = $creatorPage.Controls | Where-Object { $_ -eq $paramGroup } | ForEach-Object { $_.Bottom + 6 } |
                             Select-Object -First 1
        if ($null -eq $previewGroup.Top -or $previewGroup.Top -eq 0) {
            $previewGroup.Top = $paramGroup.Bottom + 6
        }
        $workspaceRootLink.Top  = $previewGroup.Top - 20
        $structureGroup.Top     = $previewGroup.Bottom + 4
        $structureGroup.Visible = ($newH -le 80)
    }
})

$descResizeHandle.Add_MouseUp({
    param($s, $e)
    # Snap finalize — positions already correct from MouseMove
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

$subBrandCombo.Add_SelectedIndexChanged($updatePreview)
$yearCombo.Add_SelectedIndexChanged($updatePreview)
$comboTemplateExt.Add_SelectedIndexChanged($updatePreview)
$chkInjectTemplate.Add_CheckedChanged({
    $comboTemplateExt.Enabled = $chkInjectTemplate.Checked
    & $updatePreview
})
$chkExtraRevisions.Add_CheckedChanged($updatePreview)
$chkExtraRaw.Add_CheckedChanged($updatePreview)
$jobIdText.Add_TextChanged({
    $val = $jobIdText.Text.Trim()
    # Valid Job ID: one uppercase letter followed by 3-5 digits (e.g. D0075, S0002, V0010)
    if ($val -match '^[A-Z]\d{3,5}$') {
        $jobIdText.BackColor = [Drawing.Color]::White
    } else {
        $jobIdText.BackColor = [Drawing.Color]::FromArgb(254, 226, 226)  # soft red
    }
    & $updatePreview
})
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
    $sub = switch -Wildcard ([string]$subBrandCombo.SelectedItem) {
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

# M4: Recent Projects ComboBox — open selected project in Explorer
$recentOpenBtn.Add_Click({
    if ($script:appState.RecentProjects -and $script:appState.RecentProjects.Count -gt 0) {
        $selIdx = [Math]::Max(0, $recentCombo.SelectedIndex)
        $maxIdx = $script:appState.RecentProjects.Count - 1
        if ($selIdx -gt $maxIdx) { $selIdx = 0 }
        $recentPath = $script:appState.RecentProjects[$selIdx].ProjectPath
        if (Test-Path -LiteralPath $recentPath -PathType Container) {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$recentPath`""
        }
    }
})

# M4: Ctrl+Enter keyboard shortcut for Create Project Folder
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($s, $e)
    if ($script:pageIndex -eq $creatorPageIndex -and $e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::Return) {
        if ($createProjectBtn.Visible -and $createProjectBtn.Enabled) {
            $createProjectBtn.PerformClick()
            $e.Handled = $true
        }
    }
})

$designerProfileCombo.Add_SelectedIndexChanged({
    if ($script:appState.Profiles) {
        $selProfName = [string]$designerProfileCombo.SelectedItem
        $prof = $script:appState.Profiles | Where-Object { $_.Name -eq $selProfName } | Select-Object -First 1
        if ($prof) {
            $setDesignerNameText.Text = $prof.Name
            $setDeptText.Text         = $prof.Department
            $setDesignerEmailText.Text= $prof.Email
            $setAvatarPathText.Text   = $prof.AvatarPath
            if ($prof.AvatarPath -and (Test-Path -LiteralPath $prof.AvatarPath -PathType Leaf)) {
                try { $avatarPictureBox.ImageLocation = $prof.AvatarPath } catch {}
            }
        }
    }
})

# Create Button Action
$createProjectBtn.Add_Click({
    try {
        $extraFolders = @()
        if ($chkExtraRevisions.Checked) { $extraFolders += "Client Revisions" }
        if ($chkExtraRaw.Checked) { $extraFolders += "RAW Media" }

        $selectedDesignerName = if ($designerProfileCombo -and $designerProfileCombo.SelectedItem) {
            [string]$designerProfileCombo.SelectedItem
        } else {
            $setDesignerNameText.Text.Trim()
        }

        # Resolve StaffID for project subfolder routing
        $activeStaffID = $script:appState.StaffID
        if ([string]::IsNullOrWhiteSpace($activeStaffID)) { $activeStaffID = $null }

        # Claim next job ID from NAS or local pool
        $prefix = Get-SuamiSihatJobPrefix -PresetName ([string]$presetCombo.SelectedItem)
        $claimResult = Claim-NextJobID `
            -WorkspaceRoot $workspacePathText.Text.Trim() `
            -JobPrefix $prefix `
            -AppState $script:appState

        if ([string]::IsNullOrWhiteSpace($claimResult.JobID)) {
            throw "Unable to claim a Job ID. Connect to the NAS or wait for pool to refill."
        }

        $jobIdText.Text = $claimResult.JobID
        & $script:UpdateNASStatus

        # Build root path: WorkspaceRoot\{StaffID}\ if StaffID set, else WorkspaceRoot\
        $rootForProject = $workspacePathText.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($activeStaffID)) {
            $rootForProject = Join-Path $rootForProject $activeStaffID
        }

        $result = New-SuamiSihatProjectFolder `
            -RootDirectory $rootForProject `
            -SubBrand $subBrandCombo.SelectedItem `
            -JobNumber $claimResult.JobID `
            -ProjectName $projectNameText.Text.Trim() `
            -PresetType $presetCombo.SelectedItem `
            -Year ([string]$yearCombo.SelectedItem) `
            -Description $projDescText.Text.Trim() `
            -ExtraSubFolders $extraFolders `
            -InjectTemplates:$chkInjectTemplate.Checked `
            -TemplateExtension $comboTemplateExt.SelectedItem `
            -DesignerName $selectedDesignerName `
            -DesignerDept $setDeptText.Text.Trim() `
            -TargetPlatform ([string]$targetPlatformCombo.SelectedItem)

        # Register project in team registry (or queue for offline sync)
        $pendingEntry = @{
            JobID      = $claimResult.JobID
            StaffID    = if ($activeStaffID) { $activeStaffID } else { "" }
            FolderName = $result.FolderName
            Path       = $result.ProjectPath
            PresetType = ([string]$presetCombo.SelectedItem)
            Created    = (Get-Date).ToString("o")
        }
        if ($claimResult.Source -eq "NAS") {
            # Write directly to team registry
            try {
                $reg = Read-TeamRegistry -WorkspaceRoot $workspacePathText.Text.Trim()
                $reg.Projects += $pendingEntry
                Write-TeamRegistry -WorkspaceRoot $workspacePathText.Text.Trim() -Registry $reg
                # Ensure designer is registered on NAS
                if (-not [string]::IsNullOrWhiteSpace($activeStaffID)) {
                    Register-TeamDesigner `
                        -WorkspaceRoot $workspacePathText.Text.Trim() `
                        -StaffID $activeStaffID `
                        -Name $setDesignerNameText.Text.Trim() `
                        -Department $setDeptText.Text.Trim() `
                        -Email $setDesignerEmailText.Text.Trim()
                }
            } catch {}
        } else {
            # Offline: add to pending sync queue
            $pending = if ($script:appState.PendingSync) { [System.Collections.ArrayList]@($script:appState.PendingSync) } else { [System.Collections.ArrayList]@() }
            [void]$pending.Add($pendingEntry)
            $script:appState.PendingSync = @($pending)
        }

        # Save updated app state (pool, pending)
        $script:appState = Save-SuamiSihatAppState `
            -LastProjectPath $result.ProjectPath `
            -LastProjectName $result.FolderName `
            -LastJobNumber $claimResult.JobID `
            -DefaultWorkspace $workspacePathText.Text.Trim() `
            -DesignerName $setDesignerNameText.Text.Trim() `
            -Department $setDeptText.Text.Trim() `
            -DesignerEmail $setDesignerEmailText.Text.Trim() `
            -AvatarPath $setAvatarPathText.Text.Trim() `
            -StaffID $activeStaffID `
            -LocalJobPool @($script:appState.LocalJobPool) `
            -PendingSync @($script:appState.PendingSync)

        $nextPreviewID = $prefix + ([int]($claimResult.JobID -replace '[^0-9]','') + 1).ToString().PadLeft(4,'0')
        $jobIdText.Text = $nextPreviewID
        $setJobText.Text = $nextPreviewID
        & $updatePreview

        $offlineNote = if ($claimResult.Source -ne "NAS") { "  (Offline — will sync when NAS reconnects)" } else { "" }
        $creatorStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $creatorStatusLabel.Text = "Project Created: $($claimResult.JobID)$offlineNote"
        & $script:UpdateNASStatus

        # Open in Explorer
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($result.ProjectPath)`""
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
        # Truncate exe path to keep line 2 to one clean line
        $exeDisplay = $script:installedInfo.ExePath
        if ($exeDisplay.Length -gt 72) { $exeDisplay = $exeDisplay.Substring(0, 69) + '...' }
        $aboutLabel.Text    = "SuamiSihat Creative Assets Management  |  Installed: v$($script:installedInfo.Version)"
        $aboutExeLabel.Text = "Executable: $exeDisplay"
        $btnWelcomeLaunch.Visible = $true
        $btnWelcomeUninstall.Visible = $true
        $chkWelcomeBrandKit.Checked = $true
        $chkWelcomeCPM.Checked = $true
        $tileBrandKit.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
        $tileCPM.BackColor = [Drawing.Color]::FromArgb(240, 245, 255)
    } else {
        $installStatusBadge.Text = "Not Installed  (v$($script:AppVersion) Ready)"
        $installStatusBadge.BackColor = [Drawing.Color]::FromArgb(33, 161, 247)
        $aboutLabel.Text    = "SuamiSihat Creative Assets Management  |  Not Installed"
        $aboutExeLabel.Text = "Run the setup wizard below to install the SuamiSihat brand kit & assets."
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
    # Sync Brand Kit selection with config controls on Licence+Config page
    $copyAssets.Checked = $chkWelcomeBrandKit.Checked
    if (-not $chkWelcomeBrandKit.Checked -and $fontChoice.SelectedIndex -ne 2) { $fontChoice.SelectedIndex = 2 }
    if ($chkWelcomeBrandKit.Checked -and $fontChoice.SelectedIndex -eq 2)      { $fontChoice.SelectedIndex = 0 }
    # Show CPM install path panel only when CPM is selected
    $cpmConfigPanel.Visible = $chkWelcomeCPM.Checked
}
$chkWelcomeBrandKit.Add_CheckedChanged({ & $script:UpdateWelcomeState })
$chkWelcomeCPM.Add_CheckedChanged({ & $script:UpdateWelcomeState })

# Settings Page Handlers
$repairFontsBtn.Add_Click({
    $confirm = [Windows.Forms.MessageBox]::Show(
        "This will reinstall all bundled brand fonts and sync design libraries.`n`nProceed?",
        "Reinstall Fonts & Brand Assets",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [Windows.Forms.DialogResult]::Yes) { return }
    # Configure installer for font-only repair (no assets, no shortcuts)
    $fontChoice.SelectedIndex       = 0    # All bundled fonts
    $copyAssets.Checked             = $false
    $createWebShortcuts.Checked     = $false
    $openImports.Checked            = $false
    Start-Installation
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
            -DefaultWorkspace $setWorkspaceText.Text.Trim() `
            -DesignerName $setDesignerNameText.Text.Trim() `
            -Department $setDeptText.Text.Trim() `
            -DesignerEmail $setDesignerEmailText.Text.Trim() `
            -AvatarPath $setAvatarPathText.Text.Trim()

        $jobIdText.Text = $script:appState.NextJobNumber
        $workspacePathText.Text = $script:appState.DefaultWorkspace
        $workspaceRootLink.Text = "Workspace: $($script:appState.DefaultWorkspace)"

        # Refresh Creator page Designer Profile dropdown
        if ($designerProfileCombo) {
            $curSel = $setDesignerNameText.Text.Trim()
            $designerProfileCombo.Items.Clear()
            if ($script:appState.Profiles) {
                foreach ($prof in $script:appState.Profiles) { [void]$designerProfileCombo.Items.Add($prof.Name) }
            }
            if (-not [string]::IsNullOrWhiteSpace($curSel) -and $designerProfileCombo.Items.Contains($curSel)) {
                $designerProfileCombo.SelectedItem = $curSel
            } elseif ($designerProfileCombo.Items.Count -gt 0) {
                $designerProfileCombo.SelectedIndex = 0
            }
        }

        $settingsStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $settingsStatusLabel.Text = "Settings & Profile saved successfully!"
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

    $script:updateInfo = Get-SuamiSihatLatestRelease -CurrentVersion $script:AppVersion

    if ($script:updateInfo.HasUpdate) {
        $btnCheckUpdate.Text = "Check for Updates"
        $btnCheckUpdate.Enabled = $true
        $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $updateStatusLabel.Text = "New Version Available: v$($script:updateInfo.LatestVersion)!"
        if (-not [string]::IsNullOrWhiteSpace($script:updateInfo.DownloadUrl)) {
            $btnInstallUpdate.Location = New-Object Drawing.Point(185, 116)
            $btnInstallUpdate.Visible = $true
            $updateStatusLabel.Location = New-Object Drawing.Point(335, 120)
            $updateStatusLabel.Width = 315
        }
    } else {
        # Already on latest — disable button and mark as up to date
        $btnCheckUpdate.Text = "Up to Date"
        $btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $btnCheckUpdate.Enabled = $false
        $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
        $updateStatusLabel.Text = "You are running the latest version (v$($script:AppVersion))."
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
$backButton.Size = New-Object Drawing.Size(94, 34)
$form.Controls.Add($backButton)

$cancelButton = New-Object Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Size = New-Object Drawing.Size(94, 34)
$form.Controls.Add($cancelButton)

$nextButton = New-Object Windows.Forms.Button
$nextButton.Text = "Next >"
$nextButton.Size = New-Object Drawing.Size(94, 34)
$nextButton.BackColor = [Drawing.Color]::FromArgb(4, 51, 136)
$nextButton.ForeColor = [Drawing.Color]::White
$nextButton.FlatStyle = "Flat"
$form.Controls.Add($nextButton)
$form.AcceptButton = $nextButton
$form.CancelButton = $cancelButton

# Add creator-page action buttons to form (so they sit in the same row as Close)
$createProjectBtn.Anchor = $BL
$btnClearForm.Anchor = $BL
$creatorStatusLabel.Anchor = $BL
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
$btnSkipFonts.Anchor = $BL
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
$btnOpenApp.Anchor = $BL
$form.Controls.Add($btnOpenApp)

$script:installedInfo = $null
$script:isNewInstall = $true

# Resize handler: keep all three nav buttons pinned to bottom-right, perfectly aligned
function Update-NavButtonLocations {
    $w = $form.ClientSize.Width
    $h = $form.ClientSize.Height
    $btnY = $h - 54

    if ($script:pageIndex -eq $settingsPageIndex) {
        $cancelButton.Location  = New-Object Drawing.Point(($w - 114), $btnY)
        if ($saveSettingsBtn) {
            $saveSettingsBtn.Visible  = $true
            $saveSettingsBtn.Location = New-Object Drawing.Point(($w - 264), $btnY)
        }
        $backButton.Location    = New-Object Drawing.Point(($w - 368), $btnY)
        $nextButton.Visible     = $false
    } elseif ($script:pageIndex -eq $creatorPageIndex) {
        if ($saveSettingsBtn)   { $saveSettingsBtn.Visible = $false }
        $cancelButton.Location = New-Object Drawing.Point(($w - 114), $btnY)
        $backButton.Location   = New-Object Drawing.Point(($w - 218), $btnY)
        $nextButton.Location   = New-Object Drawing.Point(($w - 322), $btnY)
    } elseif ($script:pageIndex -eq $progressPageIndex -and -not $script:setupComplete) {
        if ($saveSettingsBtn)   { $saveSettingsBtn.Visible = $false }
        $cancelButton.Location = New-Object Drawing.Point(($w - 114), $btnY)
        $backButton.Location   = New-Object Drawing.Point(($w - 218), $btnY)
        $nextButton.Location   = New-Object Drawing.Point(($w - 322), $btnY)
    } else {
        if ($saveSettingsBtn)   { $saveSettingsBtn.Visible = $false }
        # Wizard pages (0..3) and finished progress page
        $nextButton.Location   = New-Object Drawing.Point(($w - 114), $btnY)
        $cancelButton.Location = New-Object Drawing.Point(($w - 218), $btnY)
        $backButton.Location   = New-Object Drawing.Point(($w - 322), $btnY)
    }

    if ($btnOpenApp)           { $btnOpenApp.Location       = New-Object Drawing.Point(20, $btnY) }
    if ($btnSkipFonts)         { $btnSkipFonts.Location     = New-Object Drawing.Point(20, $btnY) }
    if ($createProjectBtn)     { $createProjectBtn.Location = New-Object Drawing.Point(20, $btnY) }
    if ($btnClearForm)         { $btnClearForm.Location     = New-Object Drawing.Point(328, $btnY) }
}

$form.Add_Resize({
    Update-NavButtonLocations
})

$folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Choose the parent folder for the SuamiSihat brand assets."
$folderBrowser.ShowNewFolderButton = $true

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400

# Simplified page indices for the 5-step wizard
# Welcome=0, SystemCheck=1, LicenceConfig=2, Review=3, Progress=4
$systemCheckPageIndex  = $pages.IndexOf($systemCheckPage)
$licenceConfigPageIndex = $pages.IndexOf($licenceConfigPage)
$reviewPageIndex       = $pages.IndexOf($reviewPage)
$progressPageIndex     = $pages.IndexOf($progressPage)

# Aliases so existing references to old page indices still resolve
$licencePageIndex      = $licenceConfigPageIndex
$fontPageIndex         = $licenceConfigPageIndex
$assetPageIndex        = $licenceConfigPageIndex
$cpmPageIndex          = $licenceConfigPageIndex
$requirementsPageIndex = $systemCheckPageIndex
$systemPageIndex       = $systemCheckPageIndex

# Simplified wizard routing for the 5-step flow
function Get-NextPageIndex {
    param([int]$Current)
    if ($Current -eq 0)                         { return $systemCheckPageIndex }
    if ($Current -eq $systemCheckPageIndex)     { return $licenceConfigPageIndex }
    if ($Current -eq $licenceConfigPageIndex)   { return $reviewPageIndex }
    return ($Current + 1)
}

function Get-PrevPageIndex {
    param([int]$Current)
    if ($Current -eq $systemCheckPageIndex)     { return 0 }
    if ($Current -eq $licenceConfigPageIndex)   { return $systemCheckPageIndex }
    if ($Current -eq $reviewPageIndex)          { return $licenceConfigPageIndex }
    return ($Current - 1)
}

function Get-WizardStepInfo {
    param([int]$PageIndex)
    # Fixed 5-step sequence: Welcome, System Check, Licence+Config, Review, Progress
    $seq = @(0, $systemCheckPageIndex, $licenceConfigPageIndex, $reviewPageIndex, $progressPageIndex)
    $pos = [Array]::IndexOf($seq, $PageIndex)
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

# Known latest versions — update these when vendors ship new releases
$script:KnownLatestVersions = @{
    "Affinity"             = "2.6.0"
    "Canva"                = "1.100.0"
    "Figma"                = "116.0.0"
    "Adobe Creative Cloud" = "6.6.0"
    "Adobe Photoshop"      = "26.0"
    "Adobe Illustrator"    = "29.0"
    "CapCut"               = "5.0.0"
    "DaVinci Resolve"      = "19.1"
}

function Refresh-SoftwareList {
    $softwareList.Items.Clear()
    $script:softwareInventory = @(Get-DesignSoftwareInventory)
    foreach ($software in $script:softwareInventory) {
        $installedVer = if ([string]::IsNullOrWhiteSpace($software.Version)) { "" } else { $software.Version }
        $latestVer    = if ($script:KnownLatestVersions.ContainsKey($software.Name)) {
                            $script:KnownLatestVersions[$software.Name]
                        } else { "N/A" }

        if (-not $software.Installed) {
            $status      = "Not installed"
            $rowColor    = [Drawing.Color]::FromArgb(140, 148, 160)
            $statusColor = [Drawing.Color]::FromArgb(140, 148, 160)
        } else {
            $isOutdated = $false
            if ($installedVer -and $latestVer -ne "N/A") {
                try {
                    $vInst = [version]($installedVer -replace '[^0-9.]','')
                    $vLat  = [version]($latestVer    -replace '[^0-9.]','')
                    $isOutdated = $vLat -gt $vInst
                } catch { $isOutdated = $false }
            }
            if ($isOutdated) {
                $status      = "Update available"
                $rowColor    = [Drawing.Color]::FromArgb(146, 64, 14)
                $statusColor = [Drawing.Color]::FromArgb(194, 65, 12)
            } else {
                $status      = "Up to date"
                $rowColor    = [Drawing.Color]::FromArgb(4, 51, 136)
                $statusColor = [Drawing.Color]::FromArgb(20, 135, 75)
            }
        }

        $item = New-Object Windows.Forms.ListViewItem($software.Name)
        $item.UseItemStyleForSubItems = $false
        $item.ForeColor = $rowColor

        $siStatus = $item.SubItems.Add($status)
        $siStatus.ForeColor = $statusColor

        $instDisplay = if ($installedVer) { "v$installedVer" } else { "-" }
        $siInstalled = $item.SubItems.Add($instDisplay)
        $siInstalled.ForeColor = if ($software.Installed) {
            [Drawing.Color]::FromArgb(30, 41, 59)
        } else {
            [Drawing.Color]::FromArgb(160, 165, 175)
        }

        $latDisplay = if ($latestVer -ne "N/A") { "v$latestVer" } else { "-" }
        $siLatest = $item.SubItems.Add($latDisplay)
        $siLatest.ForeColor = if ($status -eq "Up to date") {
            [Drawing.Color]::FromArgb(20, 135, 75)
        } elseif ($status -eq "Update available") {
            [Drawing.Color]::FromArgb(194, 65, 12)
        } else {
            [Drawing.Color]::FromArgb(160, 165, 175)
        }

        $getLabel = if ($software.Installed) { "Open" } else { "Get" }
        $siGet = $item.SubItems.Add($getLabel)
        $siGet.ForeColor = if ($software.Installed) {
            [Drawing.Color]::FromArgb(4, 51, 136)
        } else {
            [Drawing.Color]::FromArgb(20, 135, 75)
        }

        # Store download URL in Tag for column-4 click handler
        $item.Tag = $software.DownloadUrl
        $tip = "$($software.Name) - $status"
        if ($installedVer) { $tip += " | Installed: v$installedVer" }
        if ($latestVer -ne "N/A") { $tip += " | Latest: v$latestVer" }
        $tip += " | Click [Get/Open] to visit vendor page"
        $item.ToolTipText = $tip

        [void]$softwareList.Items.Add($item)
    }

    # Auto-detect installed design app extension for Master Canvas
    $hasAffinity = $script:softwareInventory | Where-Object { $_.Name -like "*Affinity*" -and $_.Installed }
    $hasPhotoshop = $script:softwareInventory | Where-Object { $_.Name -like "*Photoshop*" -and $_.Installed }
    $hasIllustrator = $script:softwareInventory | Where-Object { $_.Name -like "*Illustrator*" -and $_.Installed }

    if ($comboTemplateExt) {
        if ($hasAffinity) {
            $comboTemplateExt.SelectedItem = ".af"
        } elseif ($hasPhotoshop) {
            $comboTemplateExt.SelectedItem = ".psd"
        } elseif ($hasIllustrator) {
            $comboTemplateExt.SelectedItem = ".ai"
        }
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
        $cancelButton.Visible = $true
        $createProjectBtn.Visible = $true
        $btnClearForm.Visible = $true
        $creatorStatusLabel.Visible = $true
        $btnNavSettings.Text = "Settings"
        $btnNavSettings.Visible = $true
        Update-NavButtonLocations
        return
    }

    if ($Index -eq $settingsPageIndex) {
        $title.Text = "Creative Assets Management"
        $stepLabel.Text = "Settings and Maintenance"
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Text = "Close"
        $cancelButton.Visible = $true
        $createProjectBtn.Visible = $false
        $btnClearForm.Visible = $false
        $creatorStatusLabel.Visible = $false
        $btnNavSettings.Text = "< Back"
        $btnNavSettings.Visible = $true
        Update-NavButtonLocations
        return
    }

    # Wizard pages: hide creator action buttons and reset bottom bar
    $createProjectBtn.Visible = $false
    $btnClearForm.Visible = $false
    $creatorStatusLabel.Visible = $false
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

    Update-NavButtonLocations

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

# Skip Fonts button — now redundant (font dropdown lives on Licence+Config page)
# Handler kept for compatibility with Show-Page visibility logic
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
    if ($script:pageIndex -eq $licenceConfigPageIndex -and -not $acceptLicence.Checked) {
        [Windows.Forms.MessageBox]::Show(
            "You must accept the licence agreement before continuing.",
            "Licence acceptance required",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    if ($script:pageIndex -eq $licenceConfigPageIndex -and $copyAssets.Checked -and
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
        $nextButton.Enabled = $true
        $nextButton.Add_Click({ $form.Close() })
        # Show Open App button if Creative Project Management was installed
        if ($chkWelcomeCPM.Checked) {
            $btnOpenApp.Visible = $true
        }
        Update-NavButtonLocations
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
                $e.Result = Get-SuamiSihatLatestRelease -CurrentVersion $script:AppVersion
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
                    $btnInstallUpdate.Location = New-Object Drawing.Point(185, 116)
                    $btnInstallUpdate.Visible = $true
                    $updateStatusLabel.Location = New-Object Drawing.Point(335, 120)
                    $updateStatusLabel.Width = 315
                }
            } elseif ($null -ne $e.Result -and -not $e.Result.HasUpdate) {
                # Startup check confirmed: already on latest — mark button as up to date
                $btnCheckUpdate.Text = "Up to Date"
                $btnCheckUpdate.BackColor = [Drawing.Color]::FromArgb(20, 135, 75)
                $btnCheckUpdate.Enabled = $false
                $updateStatusLabel.ForeColor = [Drawing.Color]::FromArgb(20, 135, 75)
                $updateStatusLabel.Text = "You are running the latest version (v$($script:AppVersion))."
            }
        })
        $worker.RunWorkerAsync()
    }
})

Refresh-PCRequirements
Refresh-SoftwareList
$installedInfo = Get-SuamiSihatInstalledVersion

# v1.8.0: Auto-sync pending offline projects and refresh NAS status on startup
try {
    $ws = $script:appState.DefaultWorkspace
    if (-not [string]::IsNullOrWhiteSpace($ws)) {
        $syncCount = Sync-PendingProjects -WorkspaceRoot $ws -AppState $script:appState
        if ($syncCount -gt 0) {
            $script:appState = Save-SuamiSihatAppState `
                -LastProjectPath $script:appState.LastProjectPath `
                -LastProjectName $script:appState.LastProjectName `
                -LastJobNumber $script:appState.LastJobNumber `
                -DefaultWorkspace $ws `
                -DesignerName $script:appState.DesignerName `
                -Department $script:appState.Department `
                -DesignerEmail $script:appState.DesignerEmail `
                -AvatarPath $script:appState.AvatarPath `
                -StaffID $script:appState.StaffID `
                -PendingSync @()
        }
        # Ensure designer folder and registry entry on NAS
        if (-not [string]::IsNullOrWhiteSpace($script:appState.StaffID)) {
            Register-TeamDesigner `
                -WorkspaceRoot $ws `
                -StaffID $script:appState.StaffID `
                -Name $script:appState.DesignerName `
                -Department $script:appState.Department `
                -Email $script:appState.DesignerEmail
        }
        # Refill local pool if empty
        if ((@($script:appState.LocalJobPool).Count -eq 0) -and (Test-NASAvailable -WorkspaceRoot $ws)) {
            $prefix = "D"
            $newPool = Refill-LocalJobPool -WorkspaceRoot $ws -JobPrefix $prefix -PoolSize 5
            if ($newPool.Count -gt 0) {
                $script:appState = Save-SuamiSihatAppState `
                    -LastProjectPath $script:appState.LastProjectPath `
                    -LastProjectName $script:appState.LastProjectName `
                    -LastJobNumber $script:appState.LastJobNumber `
                    -DefaultWorkspace $ws `
                    -DesignerName $script:appState.DesignerName `
                    -Department $script:appState.Department `
                    -DesignerEmail $script:appState.DesignerEmail `
                    -AvatarPath $script:appState.AvatarPath `
                    -StaffID $script:appState.StaffID `
                    -LocalJobPool $newPool
            }
        }
    }
} catch {}
try { & $script:UpdateNASStatus } catch {}
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

# Test script for T4 (Settings Page Minimalist) and T5 (Focus Theme)
param(
    [string]$ProjectRoot = "E:\Dev\Projects\SS-CAM"
)

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-Condition($condition, $message) {
    if ($condition) {
        Write-Host "  [PASS] $message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $message" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "============================================================"
Write-Host "SS-CAM T4 & T5 Verification Suite"
Write-Host "============================================================"

# --- 1. THEME SERVICE ENUM & COLORS VERIFICATION ---
Write-Host "`n[1] ThemeService Registration & Colors"
$themeServicePath = Join-Path $ProjectRoot "src\SS-CAM\Services\ThemeService.cs"
$themeContent = Get-Content $themeServicePath -Raw

Assert-Condition ($themeContent -match "Focus\s*(?:=\s*\d+)?[,\s]") "AppTheme.Focus enum registered"
Assert-Condition ($themeContent -match "GetFocusColors\(\)") "GetFocusColors() implemented"
Assert-Condition ($themeContent -match "theme == AppTheme\.Focus\)\s*return GetFocusColors\(\);") "GetColors() dispatches Focus"
Assert-Condition ($themeContent -match "theme == AppTheme\.Focus\)\s*\?\s*Wpf\.Ui\.Appearance\.ApplicationTheme\.Dark") "ApplyTheme maps Focus to Dark mode"
Assert-Condition ($themeContent -match "theme == AppTheme\.Focus\)\s*accentColor = .*0EA5E9") "Focus theme accent set to #0EA5E9"
Assert-Condition ($themeContent -match "Styles/FocusTheme\.xaml") "SwapResourceDictionary loads Styles/FocusTheme.xaml"
Assert-Condition ($themeContent -match 'SpectrumBarColor\s*=\s*"#(88C0D0|5E81AC)"') "GetNordColors() defines SpectrumBarColor"

# --- 2. THEME RESOURCE DICTIONARIES & COMBOBOX STANDARDS ---
Write-Host "`n[2] Focus Theme & Theme ComboBox Standards"
$focusThemePath = Join-Path $ProjectRoot "src\SS-CAM\Styles\FocusTheme.xaml"
Assert-Condition (Test-Path $focusThemePath) "Styles\FocusTheme.xaml file exists"

$focusThemeContent = Get-Content $focusThemePath -Raw
Assert-Condition ($focusThemeContent -match "TargetType=""\{x:Type ComboBox\}""") "FocusTheme has ComboBox standard style"
Assert-Condition ($focusThemeContent -match "TargetType=""\{x:Type ComboBoxItem\}""") "FocusTheme has ComboBoxItem standard style"
Assert-Condition ($focusThemeContent -match "MinHeight.*36") "FocusTheme ComboBox MinHeight >= 36"
Assert-Condition ($focusThemeContent -match "#0EA5E9") "FocusTheme includes #0EA5E9 brand accent"
Assert-Condition ($focusThemeContent -match "CardBackgroundFillColorDefaultBrush.*#(131B2E|1E293B)") "FocusTheme has slate card background"

$themesToCheck = @("NordTheme.xaml", "CatppuccinTheme.xaml", "RosePineTheme.xaml", "MetamorphosisTheme.xaml")
foreach ($themeFile in $themesToCheck) {
    $tPath = Join-Path $ProjectRoot "src\SS-CAM\Styles\$themeFile"
    $tContent = Get-Content $tPath -Raw
    $hasCombo = ($tContent -match "TargetType=""\{x:Type ComboBox\}""") -and ($tContent -match "MinHeight.*36")
    Assert-Condition $hasCombo "$themeFile has ComboBox standard style (MinHeight >= 36)"
}

# --- 3. CSPROJ REGISTRATION ---
Write-Host "`n[3] CSPROJ Registration"
$csprojPath = Join-Path $ProjectRoot "src\SS-CAM\SS-CAM.csproj"
$csprojContent = Get-Content $csprojPath -Raw
Assert-Condition ($csprojContent -match '<Page Include="Styles\\FocusTheme\.xaml">') "FocusTheme.xaml registered in SS-CAM.csproj as Page"

# --- 4. MAINWINDOW WIRING ---
Write-Host "`n[4] MainWindow Theme Toggle & Styling"
$mainWindowPath = Join-Path $ProjectRoot "src\SS-CAM\MainWindow.xaml.cs"
$mainContent = Get-Content $mainWindowPath -Raw
Assert-Condition ($mainContent -match "nextTheme = AppTheme\.Focus;") "MainWindow OnStatusThemeToggle cycles Nord -> Focus"
Assert-Condition ($mainContent -match "\(theme == AppTheme\.Focus\)\s*\?\s*""Focus""") "MainWindow StatusThemeText formats Focus name"
Assert-Condition ($mainContent -match "theme == AppTheme\.Focus") "MainWindow forceWhiteNavText includes Focus theme"

# --- 5. SETTINGS PAGE MINIMALIST STRUCTURE ---
Write-Host "`n[5] SettingsPage Minimalist Layout & Controls"
$settingsXamlPath = Join-Path $ProjectRoot "src\SS-CAM\Views\SettingsPage.xaml"
$settingsXaml = Get-Content $settingsXamlPath -Raw

Assert-Condition ($settingsXaml -match 'MaxWidth="760"') "SettingsPage has single centered column (MaxWidth=760)"
Assert-Condition ($settingsXaml -match 'x:Key="SettingsSectionHeaderStyle"') "SettingsPage uses reusable section header style"
Assert-Condition ($settingsXaml -match 'HeaderedContentControl Style="\{StaticResource SettingsSectionHeaderStyle\}"') "Section header style is applied across cards"

# Check Rail Buttons
$railButtons = @("RailBtnProfile", "RailBtnWorkspace", "RailBtnAccount", "RailBtnAppearance", "RailBtnModules", "RailBtnMaintenance")
foreach ($rBtn in $railButtons) {
    Assert-Condition ($settingsXaml -match "x:Name=""$rBtn""") "Category rail button $rBtn exists"
}

# Check Category Panels
$categoryPanels = @("CategoryPanelProfile", "CategoryPanelWorkspace", "CategoryPanelAccount", "CategoryPanelAppearance", "CategoryPanelModules", "CategoryPanelMaintenance")
foreach ($cPanel in $categoryPanels) {
    Assert-Condition ($settingsXaml -match "x:Name=""$cPanel""") "Category panel $cPanel exists"
}

# Check Profile Compact & Edit Toggle
Assert-Condition ($settingsXaml -match 'x:Name="BtnToggleEditProfile"') "Profile Edit toggle button exists"
Assert-Condition ($settingsXaml -match 'x:Name="ProfileEditDetailsPanel"') "Profile editable details panel exists"
Assert-Condition ($settingsXaml -match 'x:Name="AvatarEmojiText"') "AvatarEmojiText exists"
Assert-Condition ($settingsXaml -match 'x:Name="AvatarPreviewImg"') "AvatarPreviewImg exists"
Assert-Condition ($settingsXaml -match 'x:Name="ProfileHeaderName"') "ProfileHeaderName exists"
Assert-Condition ($settingsXaml -match 'x:Name="StaffDirectoryCombo"') "StaffDirectoryCombo exists"
Assert-Condition ($settingsXaml -match 'x:Name="DesignerNameInput"') "DesignerNameInput exists"
Assert-Condition ($settingsXaml -match 'x:Name="StaffIdInput"') "StaffIdInput exists"
Assert-Condition ($settingsXaml -match 'x:Name="DepartmentInput"') "DepartmentInput exists"
Assert-Condition ($settingsXaml -match 'x:Name="EmailInput"') "EmailInput exists"
Assert-Condition ($settingsXaml -match 'x:Name="ProfileSaveStatus"') "ProfileSaveStatus exists"

# Check Workspace & Merged Workstation Group
Assert-Condition ($settingsXaml -match 'x:Name="WorkspaceRootInput"') "WorkspaceRootInput exists"
Assert-Condition ($settingsXaml -match 'x:Name="WorkspacePathHint"') "WorkspacePathHint exists"
Assert-Condition ($settingsXaml -match 'Click="OnCreateDesktopShortcut"') "Workstation row Desktop Shortcut exists"
Assert-Condition ($settingsXaml -match 'Click="OnRepairFonts"') "Workstation row Brand Fonts exists"
Assert-Condition ($settingsXaml -match 'Click="OnDeployAssets"') "Workstation row Asset Libraries exists"
Assert-Condition ($settingsXaml -match 'Click="OnCheckUpdates"') "Workstation row Check Updates exists"
Assert-Condition ($settingsXaml -match 'Click="OnManageCategoryPresetsClicked"') "Workstation row Category Presets exists"
Assert-Condition ($settingsXaml -match 'Click="OnOpenWorkstationHealthClicked"') "Workstation row Diagnostics Studio exists"

# Check Account Card
Assert-Condition ($settingsXaml -match 'x:Name="PortalSignedOutPanel"') "PortalSignedOutPanel exists"
Assert-Condition ($settingsXaml -match 'x:Name="PortalSignedInPanel"') "PortalSignedInPanel exists"
Assert-Condition ($settingsXaml -match 'x:Name="PortalChangePasswordPanel"') "PortalChangePasswordPanel exists"
Assert-Condition ($settingsXaml -match 'x:Name="BtnPortalSignIn"') "BtnPortalSignIn exists"

# Check Theme Chips (including Focus)
$themeChips = @("BtnThemeFalconia", "BtnThemeMetamorphosis", "BtnThemeCatppuccin", "BtnThemeRosePine", "BtnThemeNord", "BtnThemeFocus")
foreach ($tChip in $themeChips) {
    Assert-Condition ($settingsXaml -match "x:Name=""$tChip""") "Theme chip $tChip exists"
}

# Check Module Descriptions Trimming & Tooltips
Assert-Condition ($settingsXaml -match 'x:Name="TogglePluginWaktuSolat"') "TogglePluginWaktuSolat exists"
Assert-Condition ($settingsXaml -match 'x:Name="TogglePluginWellbeing"') "TogglePluginWellbeing exists"
Assert-Condition ($settingsXaml -match 'x:Name="TogglePluginQrCode"') "TogglePluginQrCode exists"
Assert-Condition ($settingsXaml -match 'x:Name="TogglePluginRadio"') "TogglePluginRadio exists"
$trimCount = ([regex]::Matches($settingsXaml, 'TextTrimming="CharacterEllipsis"')).Count
Assert-Condition ($trimCount -ge 4) "All 4 module descriptions have TextTrimming='CharacterEllipsis' (found $trimCount)"

# Check Maintenance Expander
Assert-Condition ($settingsXaml -match '<Expander Header="Advanced') "Advanced Expander exists in Maintenance"
Assert-Condition ($settingsXaml -match 'Click="OnResetProfileDefaults"') "OnResetProfileDefaults wired"
Assert-Condition ($settingsXaml -match 'Click="OnClearAllData"') "OnClearAllData wired"

# --- 6. SETTINGS CODE-BEHIND WIRING ---
Write-Host "`n[6] SettingsPage Code-Behind Handlers"
$settingsCsPath = Join-Path $ProjectRoot "src\SS-CAM\Views\SettingsPage.xaml.cs"
$settingsCs = Get-Content $settingsCsPath -Raw

Assert-Condition ($settingsCs -match 'void OnCategoryRailClicked') "OnCategoryRailClicked handler implemented"
Assert-Condition ($settingsCs -match 'void SelectCategory\(string category\)') "SelectCategory() switching implemented"
Assert-Condition ($settingsCs -match 'void OnToggleEditProfileClicked') "OnToggleEditProfileClicked implemented"
Assert-Condition ($settingsCs -match 'void OnSelectFocusTheme') "OnSelectFocusTheme implemented"
Assert-Condition ($settingsCs -match 'void UpdateThemeChips') "UpdateThemeChips implemented"
Assert-Condition ($settingsCs -match 'void ValidateWorkspacePath') "ValidateWorkspacePath implemented"
Assert-Condition ($settingsCs -match 'ThemeService\.ThemeChanged \+= OnThemeChanged') "ThemeService.ThemeChanged event wired"

# --- 7. RUNTIME REFLECTION ON COMPILED BINARY ---
Write-Host "`n[7] Runtime Assembly Reflection"
$exePath = Join-Path $ProjectRoot "src\SS-CAM\bin\Release\SS-CAM.exe"
if (Test-Path $exePath) {
    try {
        $asm = [System.Reflection.Assembly]::LoadFrom($exePath)
        $appThemeType = $asm.GetType("SS_CAM.Services.AppTheme")
        $themeServiceType = $asm.GetType("SS_CAM.Services.ThemeService")
        $themeValues = [System.Enum]::GetValues($appThemeType)
        $getColorMethod = $themeServiceType.GetMethod("GetColors", [System.Reflection.BindingFlags]"Public, Static")

        $allOk = $true
        foreach ($tv in $themeValues) {
            $colors = $getColorMethod.Invoke($null, @($tv))
            if (-not $colors.HeaderBg -or -not $colors.SidebarBg -or -not $colors.SpectrumBarColor) {
                $allOk = $false
                Write-Host "    Theme $tv missing critical token: HeaderBg=$($colors.HeaderBg), SidebarBg=$($colors.SidebarBg), Spectrum=$($colors.SpectrumBarColor)" -ForegroundColor Yellow
            }
        }
        Assert-Condition ($themeValues.Length -eq 6) "AppTheme defines exactly 6 themes: $([string]::Join(', ', $themeValues))"
        Assert-Condition $allOk "All 6 themes return valid tokens with HeaderBg, SidebarBg, SpectrumBarColor"
    } catch {
        Assert-Condition $false "Assembly reflection failed: $($_.Exception.Message)"
    }
}

Write-Host "============================================================"
Write-Host "Total Passed: $passed | Total Failed: $failed"
Write-Host "============================================================"

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}

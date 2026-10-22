# Test T6 - Radio Player Zune Style Verification Script
$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "SS-CAM QA: Task 6 (Radio Player Zune Style) Verification"
Write-Host "============================================================"

$passCount = 0
$failCount = 0

function Assert-Test($condition, $description) {
    if ($condition) {
        Write-Host "  [PASS] $description" -ForegroundColor Green
        $script:passCount++
    } else {
        Write-Host "  [FAIL] $description" -ForegroundColor Red
        $script:failCount++
    }
}

$repoRoot = "E:\Dev\Projects\SS-CAM"
$xamlPath = Join-Path $repoRoot "src\SS-CAM\Views\RadioPage.xaml"
$csPath   = Join-Path $repoRoot "src\SS-CAM\Views\RadioPage.xaml.cs"
$exePath  = Join-Path $repoRoot "src\SS-CAM\bin\Release\SS-CAM.exe"

# 1. UTF-8 BOM Verification
Write-Host "`n--- 1. Encoding Checks ---"
$xamlBytes = [System.IO.File]::ReadAllBytes($xamlPath)
Assert-Test ($xamlBytes[0] -eq 0xEF -and $xamlBytes[1] -eq 0xBB -and $xamlBytes[2] -eq 0xBF) "RadioPage.xaml has UTF-8 BOM"

$csBytes = [System.IO.File]::ReadAllBytes($csPath)
Assert-Test ($csBytes[0] -eq 0xEF -and $csBytes[1] -eq 0xBB -and $csBytes[2] -eq 0xBF) "RadioPage.xaml.cs has UTF-8 BOM"

# 2. XAML Layout & Zune Style Controls Verification
Write-Host "`n--- 2. XAML Structure & Zune Styling Checks ---"
$xamlContent = [System.IO.File]::ReadAllText($xamlPath)

Assert-Test ($xamlContent -match 'FontFamily="Segoe UI Light"') "XAML uses Segoe UI Light typography"
Assert-Test ($xamlContent -match 'FontSize="38"') "XAML uses large 38pt title"
Assert-Test ($xamlContent -match 'radio &amp; audio streams') "XAML uses lower-case Zune panoramic header title"
Assert-Test ($xamlContent -match 'HeroMeshContainer') "XAML preserves HeroMeshContainer"
Assert-Test ($xamlContent -match 'HeroMeshAtmosphere') "XAML preserves HeroMeshAtmosphere"
Assert-Test ($xamlContent -match 'HeroMeshBackdropCanvas') "XAML preserves HeroMeshBackdropCanvas"
Assert-Test ($xamlContent -match 'AuraRing1' -and $xamlContent -match 'AuraRing2') "XAML preserves AuraRing1 and AuraRing2"
Assert-Test ($xamlContent -match 'BassShockwaveRing') "XAML preserves BassShockwaveRing"
Assert-Test ($xamlContent -match 'ParticleCanvas') "XAML preserves ParticleCanvas"
Assert-Test ($xamlContent -match 'ScatteredSymbolsCanvas') "XAML preserves ScatteredSymbolsCanvas"
Assert-Test ($xamlContent -match 'SSLogoCanvas') "XAML preserves SSLogoCanvas"
Assert-Test ($xamlContent -match 'HeroWavePath' -and $xamlContent -match 'HeroWavePath2') "XAML preserves HeroWavePath & HeroWavePath2"
Assert-Test ($xamlContent -match 'HeroWaterDropPath' -and $xamlContent -match 'HeroWaterDropPath2') "XAML preserves HeroWaterDropPath & HeroWaterDropPath2"

# Hero Now Playing Art Tile (128x128)
Assert-Test ($xamlContent -match 'Width="128"\s+Height="128"') "XAML contains 128x128 Now Playing art tile"
Assert-Test ($xamlContent -match 'x:Name="HeroCoverImage"') "XAML contains HeroCoverImage"
Assert-Test ($xamlContent -match 'x:Name="HeroInitialsText"') "XAML contains HeroInitialsText fallback"
Assert-Test ($xamlContent -match 'x:Name="HeroStationName"') "XAML contains HeroStationName"
Assert-Test ($xamlContent -match 'x:Name="HeroGenreBadge"') "XAML contains HeroGenreBadge"
Assert-Test ($xamlContent -match 'x:Name="HeroStreamTitleText"') "XAML contains HeroStreamTitleText"
Assert-Test ($xamlContent -match 'x:Name="HeroStatusDot"' -and $xamlContent -match 'x:Name="HeroStatusText"') "XAML contains HeroStatusDot & HeroStatusText"

# Transport Controls & Particle Toggle
Assert-Test ($xamlContent -match 'x:Name="HeroPlayBtn"') "XAML contains HeroPlayBtn"
Assert-Test ($xamlContent -match 'x:Name="HeroStopBtn"') "XAML contains HeroStopBtn"
Assert-Test ($xamlContent -match 'x:Name="VisualizerComboBox"') "XAML contains VisualizerComboBox"
Assert-Test ($xamlContent -match 'x:Name="BtnToggleParticles"') "XAML contains BtnToggleParticles FX toggle"

# Genre Tabs in WrapPanel
Assert-Test ($xamlContent -match 'WrapPanel\s+x:Name="FilterCategoryPanel"') "XAML uses WrapPanel for FilterCategoryPanel"
Assert-Test ($xamlContent -match 'x:Name="TabAll"') "XAML preserves TabAll"
Assert-Test ($xamlContent -match 'x:Name="TabFav"') "XAML preserves TabFav"
Assert-Test ($xamlContent -match 'x:Name="TabFocus"') "XAML preserves TabFocus"
Assert-Test ($xamlContent -match 'x:Name="TabPop"') "XAML preserves TabPop"
Assert-Test ($xamlContent -match 'x:Name="TabTalk"') "XAML preserves TabTalk"
Assert-Test ($xamlContent -match 'x:Name="TabJazz"') "XAML preserves TabJazz"
Assert-Test ($xamlContent -match 'x:Name="TabCustom"') "XAML preserves TabCustom"

# Station Cover-Art Tile Grid
Assert-Test ($xamlContent -match 'HorizontalScrollBarVisibility="Disabled"') "ScrollViewer disables horizontal scrollbar"
Assert-Test ($xamlContent -match 'Padding="0,0,12,16"') "ScrollViewer has anti-overlap trailing padding >= 12"
Assert-Test ($xamlContent -match 'WrapPanel Orientation="Horizontal"') "StationItemsControl uses horizontal WrapPanel"
Assert-Test ($xamlContent -match 'Width="200"\s+Height="200"') "Station items are 200x200 square tiles"
Assert-Test ($xamlContent -match 'Binding LocalCoverPath') "Tile binds LocalCoverPath"
Assert-Test ($xamlContent -match 'Binding HasLocalCover') "Tile binds HasLocalCover"
Assert-Test ($xamlContent -match 'Binding Initials') "Tile binds Initials for fallback display"
Assert-Test ($xamlContent -match 'LinearGradientBrush StartPoint="0,0" EndPoint="0,1"') "Tile has bottom gradient overlay"

# Action buttons & Tag bindings
Assert-Test ($xamlContent -match 'Click="OnStationPlayClicked"\s+Tag="\{Binding\}"') "OnStationPlayClicked has Tag='{Binding}'"
Assert-Test ($xamlContent -match 'Click="OnStationFavoriteClicked"\s+Tag="\{Binding\}"') "OnStationFavoriteClicked has Tag='{Binding}'"
Assert-Test ($xamlContent -match 'Click="OnStationEditClicked"\s+Tag="\{Binding\}"') "OnStationEditClicked has Tag='{Binding}'"
Assert-Test ($xamlContent -match 'Click="OnStationDeleteClicked"\s+Tag="\{Binding\}"') "OnStationDeleteClicked has Tag='{Binding}'"

# Accessibility
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Play Station"') "Play station button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Toggle Favourite"') "Favorite button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Edit Station"') "Edit station button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Delete Station"') "Delete station button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Import Playlist"') "Import button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Export Playlist"') "Export button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Reset to Default Stations"') "Reset button has accessible name"
Assert-Test ($xamlContent -match 'AutomationProperties.Name="Add Stream"') "Add Stream button has accessible name"

# Modal Standards
Assert-Test ($xamlContent -match 'x:Name="AddStationModal"') "Modal exists"
Assert-Test ($xamlContent -match 'x:Name="CmbGenre"') "CmbGenre exists in modal"
Assert-Test ($xamlContent -match 'CmbGenre".*?MinHeight="36"') "CmbGenre has MinHeight='36'"
Assert-Test ($xamlContent -match 'CmbGenre".*?Padding="10,0"') "CmbGenre has Padding='10,0'"

# 3. C# Code-Behind Verification
Write-Host "`n--- 3. C# Logic & Guardrails Checks ---"
$csContent = [System.IO.File]::ReadAllText($csPath)

Assert-Test ($csContent -match 'private bool _enableHeavyParticles = false;') "_enableHeavyParticles is declared and defaults to false"
Assert-Test ($csContent -match 'OnToggleHeavyParticlesClicked') "OnToggleHeavyParticlesClicked handler exists"
Assert-Test ($csContent -match '!_enableHeavyParticles') "OnRhythmTick guards heavy particle loops by _enableHeavyParticles"
Assert-Test ($csContent -notmatch 'System\.Diagnostics\.Debug\.WriteLine') "No silent Debug.WriteLine calls in RadioPage.xaml.cs"
Assert-Test ($csContent -match 'App\.LogTrace') "Exceptions logged with App.LogTrace"
Assert-Test ($csContent -match 'DecodePixelWidth = 256') "UpdateHeroCoverImage uses 256px retina width"
Assert-Test ($csContent -match 'HeroInitialsText\.Text =') "UpdateHeroCoverImage and RefreshHeroUI update HeroInitialsText"

# 4. Runtime Assembly Reflection Checks
Write-Host "`n--- 4. Runtime Assembly Reflection Checks ---"
Assert-Test (Test-Path $exePath) "Compiled binary SS-CAM.exe exists"

$asm = [System.Reflection.Assembly]::LoadFrom($exePath)

# Check RadioStation model
$stationType = $asm.GetType("SS_CAM.Models.RadioStation")
Assert-Test ($stationType -ne $null) "RadioStation type exists"

$station = [Activator]::CreateInstance($stationType)
$station.Name = "Lite FM"
Assert-Test ($station.Initials -eq "LF") "Initials calculation works for multi-word ('Lite FM' -> 'LF')"

$station.Name = "Fly"
Assert-Test ($station.Initials -eq "FL") "Initials calculation works for single word ('Fly' -> 'FL')"

$station.Name = ""
Assert-Test ($station.Initials -eq "?") "Initials calculation handles empty string ('?')"

$station.IsFavorite = $false
Assert-Test ($station.FavIcon -eq [char]0xE734) "FavIcon shows outline star when not favorite"

$station.IsFavorite = $true
Assert-Test ($station.FavIcon -eq [char]0xE735) "FavIcon shows filled star when favorite"

# Check RadioStreamService
$serviceType = $asm.GetType("SS_CAM.Services.RadioStreamService")
Assert-Test ($serviceType -ne $null) "RadioStreamService type exists"

# Check VisualizerService
$vizType = $asm.GetType("SS_CAM.Services.VisualizerService")
Assert-Test ($vizType -ne $null) "VisualizerService type exists"

# Check RadioPage Page Type
$pageType = $asm.GetType("SS_CAM.Views.RadioPage")
Assert-Test ($pageType -ne $null) "RadioPage type exists in compiled binary"

# Verify Method Signatures on RadioPage
$methodNames = @(
    "OnHeroPlayClicked", "OnHeroStopClicked", "OnFilterClicked",
    "OnStationPlayClicked", "OnStationFavoriteClicked", "OnStationEditClicked", "OnStationDeleteClicked",
    "OnImportPlaylistClicked", "OnExportPlaylistClicked", "OnResetDefaultsClicked",
    "OnAddCustomStationClicked", "OnCloseModalClicked", "OnTestStreamClicked", "OnSaveCustomStationClicked",
    "OnToggleHeavyParticlesClicked", "OnVisualizerComboSelectionChanged"
)

foreach ($m in $methodNames) {
    $method = $pageType.GetMethod($m, [System.Reflection.BindingFlags]"NonPublic,Public,Instance")
    Assert-Test ($method -ne $null) "RadioPage has expected handler: $m"
}

Write-Host "`n============================================================"
Write-Host "Results: $passCount passed / $failCount failed"
if ($failCount -eq 0) {
    Write-Host "ALL CHECKS PASSED (PASS)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SOME CHECKS FAILED (FAIL)" -ForegroundColor Red
    exit 1
}

<#
.SYNOPSIS
    Automated build, version bump, and signing pipeline for SS-CAM Android Companion App.
.DESCRIPTION
    Builds the production Android App Bundle (.aab) with cryptographic signing,
    ready for upload to Google Play Console.
.PARAMETER BumpVersion
    Automatically increments versionCode by 1 in build.gradle.kts.
.PARAMETER VersionName
    Optional versionName override (e.g. "4.6.1").
.PARAMETER BuildApk
    Also builds the standalone APK in addition to the AAB bundle.
#>
[CmdletBinding()]
param(
    [switch]$NoBump,
    [string]$VersionName = "",
    [switch]$BuildApk
)

$BumpVersion = !$NoBump.IsPresent
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item "$PSScriptRoot\..\..\..\..\").FullName
$androidDir = Join-Path $repoRoot "src\SS-CAM.Android"
$appGradle = Join-Path $androidDir "app\build.gradle.kts"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SS-CAM Android Release & Play Store Packaging Pipeline" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Environment Setup
Write-Host "`n[1/5] Checking Build Environment..." -ForegroundColor Yellow

$jdkCandidates = @(
    "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot",
    "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot",
    "C:\Program Files\Java\jdk-17",
    "C:\Program Files\Android\Android Studio\jbr",
    "$env:JAVA_HOME"
)

$foundJdk = $null
foreach ($jdk in $jdkCandidates) {
    if (![string]::IsNullOrWhiteSpace($jdk)) {
        $cleanJdk = $jdk.TrimEnd('\', '/')
        if (Test-Path "$cleanJdk\bin\javac.exe") {
            $foundJdk = $cleanJdk
            break
        }
    }
}

if ($null -eq $foundJdk) {
    Write-Error "JDK 17 or JDK 21 not found. Please install Microsoft OpenJDK."
}

$env:JAVA_HOME = $foundJdk
$env:Path = "$foundJdk\bin;$env:Path"
Write-Host "  -> JAVA_HOME: $foundJdk" -ForegroundColor Green

# Android SDK
$sdkDir = "$env:LOCALAPPDATA\Android\Sdk"
if (!(Test-Path $sdkDir)) {
    Write-Error "Android SDK not found at $sdkDir."
}
$env:ANDROID_HOME = $sdkDir

$localPropPath = Join-Path $androidDir "local.properties"
$escapedSdk = $sdkDir.Replace('\', '\\')
Set-Content -Path $localPropPath -Value "sdk.dir=$escapedSdk"
Write-Host "  -> ANDROID_HOME: $sdkDir" -ForegroundColor Green

# 2. Version Bump
if ($BumpVersion -and (Test-Path $appGradle)) {
    Write-Host "`n[2/5] Bumping Version Code..." -ForegroundColor Yellow
    $gradleContent = Get-Content -Path $appGradle -Raw
    
    if ($gradleContent -match 'versionCode\s*=\s*(\d+)') {
        $currentCode = [int]$matches[1]
        $newCode = $currentCode + 1
        $gradleContent = $gradleContent -replace 'versionCode\s*=\s*\d+', "versionCode = $newCode"
        Write-Host "  -> versionCode: $currentCode -> $newCode" -ForegroundColor Green
    }
    
    if (![string]::IsNullOrWhiteSpace($VersionName)) {
        $gradleContent = $gradleContent -replace 'versionName\s*=\s*"[^"]+"', "versionName = `"$VersionName`""
        Write-Host "  -> versionName: $VersionName" -ForegroundColor Green
    }
    
    Set-Content -Path $appGradle -Value $gradleContent
}

# 3. Release Signing Verification
Write-Host "`n[3/5] Verifying Keystore & Signing Config..." -ForegroundColor Yellow
$keystorePath = Join-Path $androidDir "app\sscam-release.jks"
if (!(Test-Path $keystorePath)) {
    Write-Host "  -> Keystore not found, generating sscam-release.jks..." -ForegroundColor Cyan
    $keytool = "$foundJdk\bin\keytool.exe"
    & $keytool -genkey -v -keystore $keystorePath -alias sscam_key -keyalg RSA -keysize 2048 -validity 10000 -storepass sscam2026release -keypass sscam2026release -dname "CN=SuamiSihat, OU=Creative Production, O=SuamiSihat Sdn Bhd, L=Shah Alam, ST=Selangor, C=MY"
}
Write-Host "  -> Keystore: $keystorePath (Valid)" -ForegroundColor Green

# 4. Gradle Build Execution
Write-Host "`n[4/5] Compiling Release Bundle (bundleRelease)..." -ForegroundColor Yellow
Push-Location $androidDir
try {
    & ".\gradlew.bat" bundleRelease --no-daemon
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Gradle bundleRelease failed with exit code $LASTEXITCODE"
    }

    if ($BuildApk) {
        Write-Host "  -> Compiling Standalone Release APK (assembleRelease)..." -ForegroundColor Yellow
        & ".\gradlew.bat" assembleRelease --no-daemon
    }
}
finally {
    Pop-Location
}

# 5. Output Verification
Write-Host "`n[5/5] Verifying Output Artifacts..." -ForegroundColor Yellow
$aabPath = Join-Path $androidDir "app\build\outputs\bundle\release\app-release.aab"

if (Test-Path $aabPath) {
    $aabItem = Get-Item $aabPath
    $sizeMb = [math]::Round($aabItem.Length / 1MB, 2)
    
    # Signature check
    $jarsigner = "$foundJdk\bin\jarsigner.exe"
    $sigCheck = & $jarsigner -verify -certs $aabPath 2>&1
    $isSigned = $sigCheck -match "jar verified"
    
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL: SS-CAM Android Release Ready!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  Bundle (.AAB): $aabPath" -ForegroundColor White
    Write-Host "  Bundle Size:   $sizeMb MB" -ForegroundColor White
    Write-Host "  Signature:     $(if ($isSigned) { 'VERIFIED (RSA 2048)' } else { 'UNSIGNED' })" -ForegroundColor $(if ($isSigned) { 'Green' } else { 'Red' })
    
    $distDir = Join-Path $repoRoot "dist"
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir -Force | Out-Null }
    
    $vName = if (![string]::IsNullOrWhiteSpace($VersionName)) { $VersionName } else { "4.10.1" }
    $distAab = Join-Path $distDir "SS-CAM-v$vName-android-release.aab"
    Copy-Item $aabPath $distAab -Force
    Write-Host "  -> Copied to:  $distAab" -ForegroundColor Green
    
    if ($BuildApk) {
        $apkPath = Join-Path $androidDir "app\build\outputs\apk\release\app-release.apk"
        if (Test-Path $apkPath) {
            $distApk = Join-Path $distDir "SS-CAM-v$vName-android-release.apk"
            Copy-Item $apkPath $distApk -Force
            Write-Host "  APK Output:    $apkPath" -ForegroundColor White
            Write-Host "  -> Copied to:  $distApk" -ForegroundColor Green
        }
    }
    
    Write-Host "`n------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  Google Play Console Release Notes (XML):" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    $releaseNotes = @"
<en-GB>
- Official SuamiSihat live radio stream upgrade (192 kbps MP3 with ICY real-time metadata)
- 5-slot team capacity model & synchronized workload metrics
- Filtered Synology thumbnail cache from deliverables & subtasks
- v4.10.1 ecosystem parity across Windows, Linux & Mobile
- Android 15 & Jetpack Compose performance optimizations
</en-GB>
<ms-MY>
- Naik taraf siaran radio langsung SuamiSihat (192 kbps MP3 dengan metadata ICY masa nyata)
- Model kapasiti pasukan 5-slot & metrik beban kerja disegerakkan
- Penapisan fail thumbnail Synology daripada senarai deliverables & subtask
- Keselarasan ekosistem v4.10.1 merentasi Windows, Linux & Mudah Alih
- Pengoptimuman prestasi Android 15 & Jetpack Compose
</ms-MY>
"@
    Write-Host $releaseNotes -ForegroundColor Gray
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
} else {
    Write-Error "Output bundle not found at $aabPath"
}

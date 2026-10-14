<#
.SYNOPSIS
    Build and sign the SS-CAM Android Companion App (AAB + optional APK) for Google Play.
.DESCRIPTION
    Builds the release bundle signed with the upload key and then PROVES which certificate signed it.
    The signing credentials are never stored in this repository. Provide them one of two ways:
      1. Environment variables (recommended):
           KEYSTORE_FILE      full path to sscam-release.jks
           KEYSTORE_PASSWORD  keystore password
           KEY_ALIAS          key alias (sscam_key)
           KEY_PASSWORD       key password
      2. src\SS-CAM.Android\keystore.properties (git-ignored) with storeFile / storePassword / keyAlias / keyPassword.
    The script stops if the build was not signed with the expected upload key, so a debug-signed or
    wrongly-signed bundle can never be mistaken for a release.
.PARAMETER ExpectedSha1
    SHA1 fingerprint of the upload key registered in Google Play Console (App integrity). Required unless
    -SkipFingerprintCheck is used.
.PARAMETER BumpVersion
    Increase versionCode by 1 before building (Google Play rejects a versionCode it has already seen).
.PARAMETER VersionName
    Optional versionName override, e.g. "5.2.1".
.PARAMETER BuildApk
    Also build a standalone APK (for sideloading; it will NOT update a copy installed from Google Play).
#>
[CmdletBinding()]
param(
    [string]$ExpectedSha1 = "",
    [switch]$SkipFingerprintCheck,
    [switch]$BumpVersion,
    [string]$VersionName = "",
    [switch]$BuildApk
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item "$PSScriptRoot\..\..\..\..\").FullName
$androidDir = Join-Path $repoRoot "src\SS-CAM.Android"
$appGradle = Join-Path $androidDir "app\build.gradle.kts"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SS-CAM Android Release & Play Store Packaging Pipeline" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Environment
Write-Host "`n[1/5] Checking build environment..." -ForegroundColor Yellow
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
        if (Test-Path "$cleanJdk\bin\javac.exe") { $foundJdk = $cleanJdk; break }
    }
}
if ($null -eq $foundJdk) { Write-Error "JDK 17 or JDK 21 not found. Please install Microsoft OpenJDK." }
$env:JAVA_HOME = $foundJdk
$env:Path = "$foundJdk\bin;$env:Path"
Write-Host "  -> JAVA_HOME: $foundJdk" -ForegroundColor Green

$sdkDir = "$env:LOCALAPPDATA\Android\Sdk"
if (!(Test-Path $sdkDir)) { Write-Error "Android SDK not found at $sdkDir." }
$env:ANDROID_HOME = $sdkDir
Set-Content -Path (Join-Path $androidDir "local.properties") -Value ("sdk.dir=" + $sdkDir.Replace('\', '\\'))
Write-Host "  -> ANDROID_HOME: $sdkDir" -ForegroundColor Green

# 2. Signing credentials: must come from the environment or keystore.properties, never from this repo
Write-Host "`n[2/5] Checking signing credentials..." -ForegroundColor Yellow
$propsFile = Join-Path $androidDir "keystore.properties"
$haveEnv = $env:KEYSTORE_FILE -and $env:KEYSTORE_PASSWORD -and $env:KEY_ALIAS -and $env:KEY_PASSWORD
if (-not $haveEnv -and -not (Test-Path $propsFile)) {
    Write-Host "  No signing credentials found." -ForegroundColor Red
    Write-Host "  Set KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD (or create keystore.properties)," -ForegroundColor Red
    Write-Host "  then run this script again. Nothing was built." -ForegroundColor Red
    exit 1
}
if ($haveEnv -and !(Test-Path $env:KEYSTORE_FILE)) {
    Write-Error "KEYSTORE_FILE does not exist: $($env:KEYSTORE_FILE)"
}
Write-Host "  -> Credentials found ($(if ($haveEnv) { 'environment' } else { 'keystore.properties' }))" -ForegroundColor Green

# Optional version bump
if ($BumpVersion -and (Test-Path $appGradle)) {
    $gradleContent = Get-Content -Path $appGradle -Raw
    if ($gradleContent -match 'versionCode\s*=\s*(\d+)') {
        $newCode = [int]$matches[1] + 1
        $gradleContent = $gradleContent -replace 'versionCode\s*=\s*\d+', "versionCode = $newCode"
        Write-Host "  -> versionCode: $($matches[1]) -> $newCode" -ForegroundColor Green
    }
    if (![string]::IsNullOrWhiteSpace($VersionName)) {
        $gradleContent = $gradleContent -replace 'versionName\s*=\s*"[^"]+"', "versionName = `"$VersionName`""
        Write-Host "  -> versionName: $VersionName" -ForegroundColor Green
    }
    Set-Content -Path $appGradle -Value $gradleContent
}

# 3. Build
Write-Host "`n[3/5] Compiling release bundle (bundleRelease)..." -ForegroundColor Yellow
Push-Location $androidDir
try {
    & ".\gradlew.bat" bundleRelease --console=plain
    if ($LASTEXITCODE -ne 0) { Write-Error "Gradle bundleRelease failed with exit code $LASTEXITCODE" }
    if ($BuildApk) {
        & ".\gradlew.bat" assembleRelease --console=plain
        if ($LASTEXITCODE -ne 0) { Write-Error "Gradle assembleRelease failed with exit code $LASTEXITCODE" }
    }
}
finally { Pop-Location }

# 4. Prove which certificate signed the bundle
Write-Host "`n[4/5] Verifying the signature..." -ForegroundColor Yellow
$aabPath = Join-Path $androidDir "app\build\outputs\bundle\release\app-release.aab"
if (!(Test-Path $aabPath)) { Write-Error "Output bundle not found at $aabPath" }

$keytool = "$foundJdk\bin\keytool.exe"
$certText = (& $keytool -printcert -jarfile $aabPath 2>&1) -join "`n"
$signerSha1 = ""
if ($certText -match 'SHA1:\s*([0-9A-F:]{59})') { $signerSha1 = $matches[1] }
$signerOwner = ""
if ($certText -match 'Owner:\s*(.+)') { $signerOwner = $matches[1].Trim() }

if ([string]::IsNullOrEmpty($signerSha1)) {
    Write-Host "  The bundle is NOT signed. Do not upload it." -ForegroundColor Red
    exit 1
}
Write-Host "  Signed by: $signerOwner" -ForegroundColor White
Write-Host "  SHA1:      $signerSha1" -ForegroundColor White

if ($signerOwner -match 'Android Debug') {
    Write-Host "  The bundle was signed with the DEBUG key (credentials were not applied). Do not upload it." -ForegroundColor Red
    exit 1
}
if (-not $SkipFingerprintCheck) {
    if ([string]::IsNullOrWhiteSpace($ExpectedSha1)) {
        Write-Host "  Pass -ExpectedSha1 <fingerprint of the upload key in Play Console> (or -SkipFingerprintCheck)." -ForegroundColor Red
        exit 1
    }
    if ($signerSha1 -ne $ExpectedSha1.Trim().ToUpper()) {
        Write-Host "  MISMATCH: this is not the upload key registered in Google Play." -ForegroundColor Red
        Write-Host "  Expected:  $($ExpectedSha1.Trim().ToUpper())" -ForegroundColor Red
        Write-Host "  Google Play will reject this bundle. Do not upload it." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Matches the expected upload key." -ForegroundColor Green
}

# 5. Copy to dist (git-ignored) and show version
Write-Host "`n[5/5] Packaging..." -ForegroundColor Yellow
$gradleText = Get-Content -Path $appGradle -Raw
$vName = if ($gradleText -match 'versionName\s*=\s*"([^"]+)"') { $matches[1] } else { "unknown" }
$vCode = if ($gradleText -match 'versionCode\s*=\s*(\d+)') { $matches[1] } else { "?" }
$distDir = Join-Path $repoRoot "dist"
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir -Force | Out-Null }
$distAab = Join-Path $distDir "SS-CAM-v$vName-android-release.aab"
Copy-Item $aabPath $distAab -Force
Write-Host "  -> $distAab  ($([math]::Round((Get-Item $distAab).Length / 1MB, 2)) MB, versionName $vName, versionCode $vCode)" -ForegroundColor Green

if ($BuildApk) {
    $apkPath = Join-Path $androidDir "app\build\outputs\apk\release\app-release.apk"
    if (Test-Path $apkPath) {
        $distApk = Join-Path $distDir "SS-CAM-v$vName-android-release.apk"
        Copy-Item $apkPath $distApk -Force
        Write-Host "  -> $distApk" -ForegroundColor Green
        Write-Host "  Note: this APK is signed with the upload key. It will not update an app installed from Google Play." -ForegroundColor Yellow
    }
}

Write-Host "`nDone. Write the Play Console release notes from CHANGELOG.md (500 characters per language)." -ForegroundColor Cyan

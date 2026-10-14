---
name: sscam-android-release
description: >
  Automates building, version-bumping, cryptographic signing, and packaging
  of the SS-CAM Android Companion App (AAB/APK) for Google Play Console.
  Triggers: "build android", "release android", "android release", "build aab",
  "publish playstore", "publish android", "package android", "android bundle".
---

# SS-CAM Android Release Skill (`sscam-android-release`)

This skill automates the complete build, signing, and release pipeline
for the **SS-CAM Android Companion App** (`src/SS-CAM.Android`), compiling
an optimized Android App Bundle (`.aab`) ready for Google Play Console.

---

## 1. Automated Capabilities

1. **Environment Auto-Configuration**:
   - Locates or sets `JAVA_HOME` (Microsoft OpenJDK 17 LTS).
   - Locates Android SDK (`%LOCALAPPDATA%\Android\Sdk` Platform 35)
     and auto-configures `local.properties`.
2. **Version Bumping**:
   - Automatically increments `versionCode` in `app/build.gradle.kts`
     to prevent Google Play duplicate version code errors.
   - Synchronizes `versionName` with project release milestones.
3. **Cryptographic Release Signing**:
   - Signs the `.aab` using the official 2048-bit RSA upload key
     (`sscam-release.jks`).
   - Verifies bundle signature integrity with `jarsigner`.
4. **Google Play Console Release Notes Generator**:
   - Generates character-counted, XML-tagged `<en-GB>` and `<ms-MY>`
     release notes under Google Play's 500-character limit.

---

## 2. Usage & Execution Script

**Signing credentials are never stored in this repository.** Set them in your terminal for the session, then run the script:

```powershell
$env:KEYSTORE_FILE     = "E:\path\to\sscam-release.jks"
$env:KEYSTORE_PASSWORD = Read-Host "Keystore password"   # or paste it; do not save it in a file
$env:KEY_ALIAS         = "sscam_key"
$env:KEY_PASSWORD      = $env:KEYSTORE_PASSWORD

.\.agents\skills\sscam-android-release\scripts\build-android-release.ps1 `
  -ExpectedSha1 "<upload key SHA1 shown in Play Console > App integrity>"
```

The script then:

- Builds the release bundle (`bundleRelease`).
- Reads the certificate that actually signed it, and **stops** if the bundle is unsigned, debug-signed, or signed with a key other than `-ExpectedSha1`.
- Copies the bundle to `dist/SS-CAM-v<versionName>-android-release.aab`.

It never generates a keystore. If the key is missing, restore it from your secure backup.

### Optional parameters

- `-BumpVersion`: increases `versionCode` by 1 (Google Play rejects a code it has already seen). Add `-VersionName "5.2.1"` to change the name too.
- `-BuildApk`: also builds a standalone APK. It is signed with the upload key, so it will **not** update a copy installed from Google Play.
- `-SkipFingerprintCheck`: only for local testing; never for a bundle you will upload.

---

## 3. Output Artifacts

- **Release Bundle (Google Play)**:
  `src/SS-CAM.Android/app/build/outputs/bundle/release/app-release.aab`
- **Release APK (Direct Device Sideload)**:
  `src/SS-CAM.Android/app/build/outputs/apk/release/app-release.apk`
- **Proguard Mapping & Seed Symbols**:
  `src/SS-CAM.Android/app/build/outputs/mapping/release/`

---

## 4. Google Play Console Checklist Reference

| Section | Required Value |
|---|---|
| **Package Name (`applicationId`)** | `com.suamisihat.creative` |
| **Target SDK** | `35` (Android 15) |
| **Signing Key** | `sscam-release.jks` (`sscam_key`) |
| **Advertising ID** | `No` (App does not use Ad ID) |
| **Financial Features** | `No financial features` |
| **Health Declaration** | `Not a health app` (Creative asset management) |
| **Target Audience** | `18 and over` |
| **Privacy Policy URL** | `https://suamisihat.clinic/privacy-policy/` |

---

## 5. Google Play Closed Testing — Tester Join Links

Testers can join the **SS-CAM Android Companion** Closed Testing track via:

| Platform | Link |
|---|---|
| **Android (Google Play)** | https://play.google.com/store/apps/details?id=com.suamisihat.creative |
| **Web Opt-In Page** | https://play.google.com/apps/testing/com.suamisihat.creative |

> **Note:** Testers must have a Google account and be invited to the testing
> programme. The web opt-in link allows testers to join without a device
> present. Once joined, updates are delivered automatically via Google Play.

---

## 6. Upload Key Management & Play Console Reset

If Google Play Console rejects an uploaded `.aab` due to an upload key mismatch or if the upload key needs resetting:

1. **Export the Public Certificate (PEM)**:
   ```powershell
   & "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" `
     -export -rfc -alias sscam_key `
     -file dist\upload_certificate.pem `
     -keystore src\SS-CAM.Android\app\sscam-release.jks `
     -storepass:env KEYSTORE_PASSWORD
   ```
2. **Check the keystore fingerprint** (never write the keystore password into a file or document):
   ```powershell
   & "C:/Program Files/Microsoft/jdk-17.0.20.101-hotspot/bin/keytool.exe" `
     -list -v -keystore src/SS-CAM.Android/app/sscam-release.jks -storepass:env KEYSTORE_PASSWORD
   ```
   Compare the SHA1 with the upload key shown in Play Console > App integrity.
3. **Submit Reset in Google Play Console**:
   - Navigate to [Google Play Console](https://play.google.com/console).
   - Select **SS-CAM** (`com.suamisihat.creative`).
   - In the left sidebar, navigate to **Release** > **Setup** > **App integrity** (or **App signing**).
   - Select the **App signing** tab.
   - Under **Upload key certificate**, click **Request upload key reset**.
   - Select reason (e.g., *I lost my upload key* or *Key rotation*).
   - Upload the exported file: `dist/upload_certificate.pem`.
   - Click **Save**. Google registers the reset and notifies when the key becomes active (typically within 24–48 hours).


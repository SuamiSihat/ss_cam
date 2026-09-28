# Google Play Console Upload Key Rotation & Git History Cleanup Runbook

## Overview & Background

The Android release keystore (`sscam-release.jks`) and its initial signing passwords were previously tracked in the git repository. 

As an immediate mitigation:
- Hardcoded passwords and keystore references were removed from `build.gradle.kts`.
- Keystore credentials and files are now loaded dynamically from untracked `keystore.properties` or environment variables, falling back to unsigned/debug mode for contributors.
- `src/SS-CAM.Android/app/sscam-release.jks` was untracked from the git index (`git rm --cached`) while being preserved on local disk.
- `.gitignore` was updated to ignore all `*.jks`, `*.keystore`, and `keystore.properties` files.

Because git commit history may still contain the earlier commits, this runbook outlines the required **manual** recovery procedures:
1. **Resetting the Upload Key via Google Play Console** (since Google Play App Signing manages the real end-user delivery key).
2. **Configuring local credentials via `keystore.properties`**.
3. **Purging the compromised keystore and secrets from git history using `git-filter-repo`**.

---

## Phase 1: Google Play Console Upload Key Reset

> [!IMPORTANT]
> Because **Play App Signing** is active for `com.suamisihat.creative`, Google signs the final APK/AAB delivered to users with the Google-managed app signing key. The keystore in this repository is merely the **Upload Key**. Compromise of the upload key does NOT compromise installed apps, but it must be rotated so unauthorized builds cannot be submitted to the Play Console.

### Step 1: Generate a New Replacement Upload Keystore

Generate a new, secure upload keystore using standard Java `keytool`:

```powershell
keytool -genkeypair -v `
  -keystore sscam-upload-new.jks `
  -alias sscam_upload `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -storetype JKS
```

*When prompted, choose a strong, unique passphrase (at least 20 alphanumeric/symbol characters) and record it securely in your team password vault (e.g. 1Password / Bitwarden).*

### Step 2: Export the Public Certificate in PEM Format

Google Play Support requires the public key in standard Privacy Enhanced Mail (`.pem`) format:

```powershell
keytool -exportcert -rfc `
  -keystore sscam-upload-new.jks `
  -alias sscam_upload `
  -file upload_certificate.pem
```

Verify that `upload_certificate.pem` begins with `-----BEGIN CERTIFICATE-----` and ends with `-----END CERTIFICATE-----`.

### Step 3: Submit the Upload Key Reset Request to Google Play Console

1. Sign in to the [Google Play Console](https://play.google.com/console) as an Account Owner or Admin.
2. Select **SS-CAM** (`com.suamisihat.creative`).
3. In the left navigation, go to **Release** > **Setup** > **App integrity**.
4. Select the **App Signing** tab.
5. Under **Upload key certificate**, click **Request upload key reset** (or **Contact Support** if the self-service flow is not enabled for your account tier).
6. Select the reason: *"I lost my upload key or it was compromised"*.
7. Attach the newly generated `upload_certificate.pem` file.
8. Submit the request.

*Google Play Support typically confirms and schedules the key reset within 24 to 48 hours. The notification will state the exact date and UTC time when the new upload key becomes effective.*

---

## Phase 2: Local Keystore & Build Configuration

Once the new keystore is generated, store it securely on your workstation outside of tracked git directories, or in the untracked path `src/SS-CAM.Android/app/sscam-upload-new.jks`.

Create an untracked file `src/SS-CAM.Android/keystore.properties` (or `src/SS-CAM.Android/app/keystore.properties`):

```properties
storeFile=sscam-upload-new.jks
storePassword=YOUR_NEW_SECURE_STORE_PASSWORD
keyAlias=sscam_upload
keyPassword=YOUR_NEW_SECURE_KEY_PASSWORD
```

### CI/CD Environment Variable Alternative
For automated GitHub Actions or Docker CI builds, set the following repository secrets instead of storing a file:
- `KEYSTORE_FILE`: Path to keystore or base64-encoded keystore path.
- `KEYSTORE_PASSWORD`: Keystore master password.
- `KEY_ALIAS`: Alias of the key (e.g., `sscam_upload`).
- `KEY_PASSWORD`: Key password.

---

## Phase 3: Purging History with `git-filter-repo` (Manual Execution)

> [!CAUTION]
> Rewriting git history modifies commit hashes for all commits containing the target path or text.
> **DO NOT** perform this step without coordinating with all repository collaborators first. Ensure all pending feature branches are merged or stashed.

### Prerequisites

Install `git-filter-repo` (recommended official tool replacing obsolete `git filter-branch` and BFG):

```bash
python -m pip install --user git-filter-repo
```

Verify installation:
```bash
git filter-repo --version
```

### Execution Steps

1. **Create a Complete Mirror Backup**:
   ```bash
   git clone --mirror <remote-url> ss-brand-assets-backup.git
   ```

2. **Clone a Clean Dedicated Workspace**:
   ```bash
   git clone <remote-url> ss-brand-assets-cleanup
   cd ss-brand-assets-cleanup
   ```

3. **Remove `sscam-release.jks` from All Past Commits**:
   ```bash
   git filter-repo --path src/SS-CAM.Android/app/sscam-release.jks --invert-paths
   ```

4. **Replace Compromised Password Literals from All Commit Messages & Diffs**:
   Create a replacement dictionary file named `replace-passwords.txt`:
   ```text
   sscam2026release==>[REDACTED]
   ```

   Run the replacement:
   ```bash
   git filter-repo --replace-text replace-passwords.txt
   ```

5. **Re-attach the Remote and Verify Clean State**:
   `git-filter-repo` removes remotes as a safety precaution against accidental push. Inspect the log:
   ```bash
   git log --all --full-history -- "**/sscam-release.jks"
   # Must return 0 commits
   ```

6. **Coordinate & Force-Push**:
   Once verified:
   ```bash
   git remote add origin <remote-url>
   git push origin --force --all
   git push origin --force --tags
   ```

7. **Team Action**:
   Notify all team members to delete their local clones and re-clone fresh copies of the repository.

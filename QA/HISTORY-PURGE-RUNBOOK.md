# Git History Purge & Repository Size Reduction Runbook

> [!CAUTION]
> **MANUAL OPERATIONAL RUNBOOK ONLY — DO NOT RUN AUTOMATICALLY**  
> Rewriting git history modifies commit hashes across the entire repository. This operation must be performed during a scheduled maintenance window in coordination with all contributors.

---

## 1. Objectives

1. **Purge Compromised Secrets & Keystores (Finding C3)**: Completely strip `src/SS-CAM.Android/app/sscam-release.jks` and replace occurrences of plaintext keystore passwords (`SuamiSihat123!`) across historical commit blobs.
2. **Purge Historical Binary Bloat (Finding R1)**: Remove historic commits containing untracked build artifacts (`publish/`, `src/SS-CAM.Web/node_modules/`, `installer/*.zip`, `nuget.exe`), reducing the `.git` pack database from **544 MiB** to **< 50 MiB** (~90% reduction).
3. **Optional Git LFS Migration**: Convert `payload/Brand Assets/Libraries/SuamiSihat Branding.afassets` (43.27 MB) to Git LFS pointer tracking.

---

## 2. Prerequisites & Preparation

1. **Install `git-filter-repo`** (official tool recommended by Git, replacing deprecated `git filter-branch` and BFG):

   ```powershell
   pip install git-filter-repo
   ```

2. **Ensure Clean Working Tree**:
   Make sure all active feature and fix branches are merged or stashed.
3. **Create Fresh Mirror Backup**:

   ```powershell
   git clone --mirror e:\Dev\Projects\SS-Brand-Assets e:\Dev\Projects\SS-Brand-Assets.git-backup
   git -C e:\Dev\Projects\SS-Brand-Assets.git-backup fsck
   ```

---

## 3. Execution Steps

### Step 1: Prepare Password Scrubbing Expressions

Create a temporary expressions file `expressions.txt` to replace compromised credentials across historical commit diffs:

```text
SuamiSihat123!==>REDACTED_HISTORICAL_PASSWORD
```

### Step 2: Run `git-filter-repo`

Run `git-filter-repo` to simultaneously purge binary paths and scrub credential occurrences:

```powershell
cd e:\Dev\Projects\SS-Brand-Assets

# Execute path pruning and text replacement
git-filter-repo `
  --path src/SS-CAM.Android/app/sscam-release.jks `
  --path publish `
  --path installer/SS-CAM-v4.6.0-linux-x64-nav-fix.zip `
  --path src/SS-CAM.Web/node_modules `
  --path src/SS-CAM/packages `
  --path packages `
  --path src/nuget.exe `
  --path nuget.exe `
  --replace-text expressions.txt `
  --invert-paths
```

*Delete `expressions.txt` immediately after execution.*

### Step 3: Optional Git LFS Migration for Affinity Assets

If preserving `payload/Brand Assets/Libraries/SuamiSihat Branding.afassets` under version control:

```powershell
git lfs install
git lfs migrate import --everything --include="*.afassets"
```

### Step 4: Aggressive Garbage Collection

Expire all reflogs and run aggressive packfile pruning:

```powershell
# Expire all reflogs immediately
git reflog expire --expire=now --all

# Force aggressive packfile rebuild and prune unreachable objects
git gc --prune=now --aggressive
```

### Step 5: Verify Repository State

Verify that the pack database has shrunk and historical blobs are gone:

```powershell
# Verify pack size
git count-objects -vH

# Verify keystore is gone from history
git log --all --full-history -- "**/sscam-release.jks"
```

### Step 6: Coordinate Force-Push with Team

1. Re-add the remote origin (cleared by filter-repo as safety precaution):

   ```powershell
   git remote add origin git@github.com:SuamiSihat/ss_cam.git
   ```

2. Force-push rewritten branches and tags:

   ```powershell
   git push origin --force --all
   git push origin --force --tags
   ```

3. Instruct all team members to discard local clones and perform a fresh clone:

   ```powershell
   git clone git@github.com:SuamiSihat/ss_cam.git
   ```

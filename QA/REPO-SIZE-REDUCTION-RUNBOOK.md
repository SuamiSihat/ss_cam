# Git Repository History Size Reduction Runbook

> [!CAUTION]
> **PROPOSAL & MANUAL RUNBOOK ONLY — DO NOT EXECUTE AUTOMATICALLY**  
> Rewriting git history modifies commit SHAs across all branches. This operation requires team-wide communication and explicit scheduling during a maintenance window so all collaborators re-clone cleanly.

---

## 1. Executive Summary & Root Cause Analysis

### Current Repository Pack State
- **Total Pack Size**: **543.83 MiB** (`git count-objects -vH`).
- **Target Pack Size Post-Scrubbing**: **< 50 MiB** (~90% size reduction).

### Top 15 Largest Blobs in Commit History

| SHA | Size (MB) | File Path in History | Historical Revisions |
|---|---|---|---|
| `3cad5de` | 95.89 MB | `publish/linux-x64/SS-CAM.Linux` | Revision 4 |
| `4b2cd44` | 82.52 MB | `publish/linux-x64/SS-CAM.Linux` | Revision 3 |
| `5b178d0` | 82.52 MB | `publish/linux-x64/SS-CAM.Linux` | Revision 2 |
| `43f67ac` | 81.16 MB | `publish/linux-x64/SS-CAM.Linux` | Revision 1 |
| `c770b52` | 43.27 MB | `payload/Brand Assets/Libraries/SuamiSihat Branding.afassets` | Revision 1 |
| `996ac66` | 40.53 MB | `publish/ss-cam-linux-x64.tar.gz` | Revision 3 |
| `5c73bc9` | 40.50 MB | `publish/ss-cam-linux-x64.tar.gz` | Revision 2 |
| `e437574` | 40.50 MB | `publish/ss-cam-linux-x64.tar.gz` | Revision 1 |
| `3d4e5ce` | 39.97 MB | `installer/SS-CAM-v4.6.0-linux-x64-nav-fix.zip` | Revision 1 |
| `05b42fd` | 22.90 MB | `payload/Fonts/.../NotoColorEmoji.ttf` | Revision 1 |
| `b846368` | 12.81 MB | `src/SS-CAM/packages/WPF-UI.3.0.4/WPF-UI.3.0.4.nupkg` | Revision 1 |
| `eb1f583` | 12.56 MB | `FontLibrary/Others/Inter-4.1/Inter.ttc` | Revision 1 |
| `e51d668` | 10.65 MB | `publish/linux-x64/libSkiaSharp.so` | Revision 1 |
| `6c80f44` | 8.08 MB | `nuget.exe` / `src/nuget.exe` | Revision 1 |
| `d61c86a` | 6.93 MB | `src/SS-CAM/packages/.../System.Runtime.nupkg` | Revision 1 |

**Key Takeaway**: Over **500 MB** of the 544 MB repository pack size is dominated by past revisions of standalone build outputs (`publish/`), installers (`installer/*.zip`), packages (`*.nupkg`), and binary design asset libraries (`.afassets`).

---

## 2. Immediate Mitigation (Already Executed)

To stop further repository growth:
1. Files were untracked from the active Git index using `git rm -r --cached`.
2. `.gitignore` was updated with comprehensive patterns (`dist/`, `publish/`, `installer/*.zip`, `*.zip`, `node_modules/`, `nuget.exe`).
3. All files remain physically intact on disk for local building, execution, and development.

---

## 3. Recommended Tool: `git-filter-repo`

The Git documentation officially recommends [`git-filter-repo`](https://github.com/newren/git-filter-repo) over deprecated tools like `git filter-branch` or BFG Repo-Cleaner because it is faster, safer, handles commit signatures/tags correctly, and avoids leaving stale refs.

Install prerequisite (Python 3.8+ required):
```powershell
pip install git-filter-repo
```

---

## 4. Step-by-Step Manual Execution Plan

### Step 1: Create Full Local and Remote Backups
Before touching Git history:
```powershell
# 1. Clone a fresh mirror backup to an external location
git clone --mirror e:\Dev\Projects\SS-Brand-Assets e:\Dev\Projects\SS-Brand-Assets.git-backup

# 2. Verify backup integrity
git -C e:\Dev\Projects\SS-Brand-Assets.git-backup fsck
```

### Step 2: Purge Build Outputs and Binary Packages from History
Run `git-filter-repo` targeting specific bloat paths:

```powershell
cd e:\Dev\Projects\SS-Brand-Assets

# Purge publish/ artifacts, installers, package caches, and standalone nuget executables
git-filter-repo `
  --path publish `
  --path installer/SS-CAM-v4.6.0-linux-x64-nav-fix.zip `
  --path src/SS-CAM.Web/node_modules `
  --path src/SS-CAM/packages `
  --path packages `
  --path src/nuget.exe `
  --path nuget.exe `
  --invert-paths
```

### Step 3: Handle `.afassets` via Git LFS Migration (Optional / Recommended)
If the 43 MB Affinity Assets file (`SuamiSihat Branding.afassets`) should remain tracked under version control without bloating git packfiles:

```powershell
# Convert .afassets history to Git LFS pointers
git lfs install
git lfs migrate import --everything --include="*.afassets"
```

*Note: Ensure GitHub LFS bandwidth/storage quota is activated for the repository before pushing.*

### Step 4: Aggressive Garbage Collection & Pruning
Purge loose objects, reflogs, and unreachable pack data:

```powershell
# Expire all reflogs immediately
git reflog expire --expire=now --all

# Force aggressive packfile rebuild and prune
git gc --prune=now --aggressive
```

### Step 5: Verify Pack Size Reduction
Check the resulting database size:
```powershell
git count-objects -vH
```
*Expected output: `size-pack` will drop from **543.83 MiB** to **< 50 MiB**.*

### Step 6: Coordinate Force-Push to Remotes
Because commit hashes have changed:
1. Re-add origin remote (if cleared by filter-repo):
   ```powershell
   git remote add origin <remote-url>
   ```
2. Notify team members to push any pending work beforehand.
3. Force-push updated branches and tags:
   ```powershell
   git push origin --force --all
   git push origin --force --tags
   ```
4. Collaborators must perform a clean re-clone:
   ```powershell
   git clone <remote-url>
   ```

# Deployment Plan: Web Portal Sidebar Native Apps Download Link Fix

**Target**: `https://creative.suamisihat.myds.me` (Synology NAS Docker container `ss-cam-web-portal`)  
**Branch**: `SS-Master` -> `origin` (`https://github.com/SuamiSihat/ss_cam.git`)  
**Prepared**: 2026-10-21  
**Author**: Antigravity Assistant  

---

## 1. Summary of Changes

### Issue
The "Native Apps (v5.3.0) ↗" download link at the bottom of the Web Portal sidebar was using `color: var(--text-tertiary)` (`rgba(25, 25, 26, 0.35)`), producing near-black text directly on the dark Prussian Blue (`#022057`) sidebar background. This resulted in an unreadable ~1.1:1 contrast ratio.

### Fix Applied
1. **Markup & Typography**:
   - Updated `client/src/App.svelte` to use `color: var(--sidebar-text, #E2E8F0)` (>10:1 contrast ratio, WCAG AAA compliant).
   - Structured label into `sidebar-desktop-text` and right-aligned external indicator `sidebar-desktop-ext` (`↗`).
   - Accented download icon with `var(--brand-accent, #21A1F7)`.
2. **Fluent 2 Pill Geometry**:
   - Converted `.sidebar-desktop-link` to `width: 100%` with `border-radius: 8px` and `rgba(255, 255, 255, 0.05)` background, perfectly matching the visual language of the "Studio idle · Synced" pill directly above it.
3. **Client Distribution Rebuilt**:
   - New production bundle generated: `index-C0-VRldr.js` and `index-BwSA3x41.css` in `client/dist/`.

---

## 2. Pre-Flight Verification Status

| Gate | Check | Status | Details |
|---|---|---|---|
| **Unit & Integration** | `npm test` (`src/SS-CAM.Web`) | **PASS** | 78 passed, 0 failed |
| **Admin Smoketest** | `admin-smoketest.js` | **PASS** | 13 passed, 0 failed |
| **Security Suite** | `security-tests.js` | **PASS** | 43 passed, 0 failed |
| **Dual-Track Governance** | `QA/verify-dual-track.ps1` | **PASS** | Source Guardian 14/14, Doc Leakage, Formats |
| **Client Compilation** | `npm run build:client` | **PASS** | Vite build clean in 17.03s |
| **Live Portal Ping** | `GET /api/status` | **PASS** | v5.3.0 healthy on NAS |

---

## 3. Safety Guardrails

- **Scope Isolation**: Stage and commit **ONLY** `src/SS-CAM.Web/`. Never stage untracked files in other folders.
- **Data Protection**: `src/SS-CAM.Web/data/` contains live credentials and is excluded from git. On the NAS, `data/` is preserved untouched.
- **Zero Force Push**: Never use `git push --force` or `--no-verify`.
- **Pre-deploy Backup**: A timestamped tarball backup of the NAS container directory will be created before updating files.

---

## 4. Execution Pipeline

### Phase 1: Local Git Commit & Push (Windows Workstation)

```powershell
# 1. Stage only Web Portal files (source + dist)
git add src/SS-CAM.Web/

# 2. Commit with standard conventional commit
git commit -m "fix(web): improve sidebar native apps download link contrast and styling"

# 3. Push to canonical branch
git push origin SS-Master
```

*(Alternatively, run `.\.agents\skills\sscam-web-deploy\scripts\deploy-sscam-web.ps1 -CommitMessage "fix(web): improve sidebar native apps download link contrast and styling"`)*

---

### Phase 2: Synology NAS Sync & Container Restart (SSH Session)

Run the following commands in the active SSH session (`harussani@suamisihat.myds.me:2222`):

```bash
cd /volume1/docker/ss-cam-web

# 1. Create safety backup (excluding node_modules and keeping data intact)
sudo tar --exclude=node_modules -czf ../ss-cam-web-backup-$(date +%Y%m%d-%H%M).tar.gz .

# 2. Fetch latest commits from GitHub
if [ ! -d .git ]; then git init && git remote add origin https://github.com/SuamiSihat/ss_cam.git; fi
git fetch origin && git checkout -f -B SS-Master origin/SS-Master

# 3. Sync web assets into Docker working directory
if [ -d 'src/SS-CAM.Web' ]; then cp -rf src/SS-CAM.Web/* .; fi

# 4. Restart Docker container
sudo docker restart ss-cam-web-portal || sudo docker-compose restart
```

---

### Phase 3: Post-Deployment Verification (Workstation)

1. **Automated Health Check**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\.agents\skills\sscam-web-deploy\scripts\deploy-sscam-web.ps1 -VerifyOnly
   ```
2. **Verify Live Bundle Hash**:
   ```powershell
   (Invoke-WebRequest -Uri 'https://creative.suamisihat.myds.me/' -UseBasicParsing).Content | Select-String -Pattern 'assets/index-[A-Za-z0-9_-]+\.js'
   ```
   *Expected output*: `assets/index-C0-VRldr.js` (replaces previous `index-BTKnEkW0.js`).

3. **Browser Check**:
   - Open `https://creative.suamisihat.myds.me/` in a private window or hard-refresh (Ctrl+F5).
   - Verify the "Native Apps (v5.3.0) ↗" pill at the bottom of the sidebar is sharp, crisp white/slate, clearly readable, and highlights on hover.

---

## 5. Rollback Procedure

If any issue arises after container restart:

```bash
cd /volume1/docker/ss-cam-web
# Restore from the pre-deployment backup
LATEST_BACKUP=$(ls -t ../ss-cam-web-backup-*.tar.gz | head -n 1)
sudo tar -xzf "$LATEST_BACKUP" -C . --exclude=./data
sudo docker restart ss-cam-web-portal
```
Then revert the git commit on the local workstation if necessary.

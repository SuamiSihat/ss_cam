# Deploy Plan: Web Portal login fix (missing FluentIcons import)

Target: https://creative.suamisihat.myds.me (Synology NAS, Docker container `ss-cam-web-portal`)
Branch: `SS-Master` -> `origin` (https://github.com/SuamiSihat/ss_cam.git)
Prepared: 2026-10-19

## 1. Why this deploy

Signing in with a default or admin-reset password freezes the login form on "Signing in…".
The server accepts the sign-in and asks for a password change, but the "Choose a new password"
step in `src/SS-CAM.Web/client/src/lib/views/LoginView.svelte` used `<FluentIcons>` without importing it.
The page crashed with `ReferenceError: FluentIcons is not defined`.

Fix (already in the working tree, uncommitted): one line added to LoginView.svelte:

```svelte
import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
```

The client was rebuilt with `npm run build:client`, so `src/SS-CAM.Web/client/dist/` has new hashed bundles
(old bundle live: `index-JoijQ8Cf.js`; the new one has a different hash). No server code changed.

## 2. Already verified (do not skip re-running step 4)

| Check | Result |
|---|---|
| `npm test` in `src/SS-CAM.Web` (main, admin smoke, security: 43 passed) | PASS |
| `QA/verify-dual-track.ps1` (no -Fix) | PASS |
| `npm run build:client` | PASS |
| Live server answers quickly (fake user -> 401 in 0.18s) | PASS |
| Browser check of the "Choose a new password" step | NOT DONE, do it in step 5 |

## 3. Guardrails (read before doing anything)

- Stage only `src/SS-CAM.Web/`. Do NOT commit `QA/STUDIO-DISPLAY-QA.md` (the user's separate, unfinished edit).
  Do not use `git add -A` or `git add .`.
- `src/SS-CAM.Web/data/` is gitignored and holds the live password store. Never copy, delete or overwrite it on the NAS.
- Do not type a real user's password into the live site or API. For the browser check, use a test account
  the user nominates (see step 5).
- Never use `git push --force`. Never use `--no-verify`.
- The NAS steps restart the live portal and briefly sign everyone out of any open request.
  Run them only after the user has said "deploy". If this plan is being executed by an agent, confirm with the user first.
- Stop and report on any failure. Do not retry destructive steps blindly.

## 4. Steps (on the Windows PC, repo root `E:\Dev\Projects\SS-CAM`)

1. Confirm state:
   `git status --short` should show `LoginView.svelte`, rebuilt `client/dist/*`, and `QA/STUDIO-DISPLAY-QA.md` (leave the last one alone).
2. Re-run tests: `cd src/SS-CAM.Web; npm test`. All three suites must pass.
3. Re-run `.\QA\verify-dual-track.ps1` (without -Fix). It must report ALL PASSED.
4. Commit only the web folder:
   ```powershell
   git add src/SS-CAM.Web/
   git commit -m "fix(web): import FluentIcons in LoginView so the change-password step renders"
   git push origin SS-Master
   ```
   Add the attribution line the session requires if committing from Claude Code.
   Alternative: the `sscam-web-deploy` script does steps 1-4 itself (its `git add src/SS-CAM.Web/` is equivalent):
   `powershell -ExecutionPolicy Bypass -File .\.agents\skills\sscam-web-deploy\scripts\deploy-sscam-web.ps1 -CommitMessage "fix(web): import FluentIcons in LoginView so the change-password step renders"`
   Note: that script runs `verify-sscam.ps1 -Fix`, which may modify files; check `git status` afterwards and keep unrelated changes out of the commit.
   The script does NOT touch the NAS. It only prints the NAS commands (step 5).

## 5. NAS deployment (SSH, manual, `harussani@suamisihat.myds.me`, port 2222)

```sh
cd /volume1/docker/ss-cam-web
# Back up app files (data/ is kept as-is; node_modules excluded)
sudo tar --exclude=node_modules -czf ../ss-cam-web-backup-$(date +%Y%m%d-%H%M).tar.gz .
if [ ! -d .git ]; then git init && git remote add origin https://github.com/SuamiSihat/ss_cam.git; fi
git fetch origin && git checkout -f -B SS-Master origin/SS-Master
if [ -d 'src/SS-CAM.Web' ]; then cp -rf src/SS-CAM.Web/* .; fi
sudo docker restart ss-cam-web-portal || sudo docker-compose restart
```

Notes: the container runs `npm install` on start, so allow about 30-60 seconds (compose healthcheck start_period is 30s).
`cp -rf` copies from the repo's web folder, which has no `data/` (it is gitignored), so the live `data/` stays untouched.

## 6. Verification (back on the PC)

1. Automatic check:
   `powershell -ExecutionPolicy Bypass -File .\.agents\skills\sscam-web-deploy\scripts\deploy-sscam-web.ps1 -VerifyOnly`
   Expected: version matches `src/SS-CAM.Web/package.json` and `/api/auth/roster`, `/api/team/roster`, `/api/notes` need sign-in. Result PASS.
2. Confirm the new bundle is live:
   `curl -s https://creative.suamisihat.myds.me/ | grep -o 'assets/index-[A-Za-z0-9_-]*\.js'`
   It must NOT be `index-JoijQ8Cf.js`. If it still is, the container or reverse proxy serves the old copy (restart again, check the volume mount).
3. Browser check, the real fix (use a test account on a default or reset password):
   open `#login` in a private window, hard refresh (Ctrl+Shift+R), sign in.
   Expected: the "Choose a new password" screen appears, and the eye icon toggle on the password field works.
   Console shows no `FluentIcons is not defined`.
   Choose a new password of 10+ characters (not the default): you land on the dashboard.
4. Regression: a normal account signs in straight to the dashboard; a wrong password shows the invalid-credentials message and the button re-enables.

Record each result as PASS / FAIL / PARTIAL / BLOCKED in `QA/` (do not mark PASS unless it was actually observed).

## 7. Rollback

If the portal fails its health check or sign-in is worse than before:
```sh
cd /volume1/docker/ss-cam-web
# restore the tarball made in step 5 (name printed by `ls ../ss-cam-web-backup-*`), keeping data/ intact
sudo tar -xzf ../ss-cam-web-backup-YYYYMMDD-HHMM.tar.gz -C . --exclude=./data
sudo docker restart ss-cam-web-portal
```
Then on the PC, `git revert <fix-commit>` and push, so the repo matches what is live.

## 8. Known remaining gap (separate task, optional)

The login request in `client/src/lib/services/api.ts` has no timeout, so any future hang shows
"Signing in…" forever instead of an error. Suggested follow-up: abort after about 20 seconds and show
"Can't reach the server. Check your connection and try again."

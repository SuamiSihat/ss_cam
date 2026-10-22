---
description: Finish and verify the SS-CAM v5.3.x desktop improvement batch (Archive, QR, startup speed, Settings, Focus theme, Zune Radio, radio stream URL), then build. Run as /sscam-finish.
---

# /sscam-finish

Executes the remaining work for the desktop improvement batch and produces a verified build. Detail for each task lives in `QA/ANTIGRAVITY-HANDOFF.md` (T1 to T6). Read `AGENTS.md` and that file first.

## Rules (binding)
1. One step at a time: do it, verify it, record it, then continue.
2. **Never launch the app against real data.** `App.OnStartup` copies the exe and fonts into the user profile and registers a URI scheme. Run the app only in a throwaway Windows user or VM, with a temp workspace. Never touch the NAS (`\\SSNAS\...`, `Z:\`).
3. **No push, no deploy, no release, no tag.** Local commits only, and only in step 7.
4. Keep UTF-8 BOM on `.cs` and `.xaml`; keep each file's line endings. No silent catches (`App.LogTrace`). No `.Result` or `.Wait()` on the UI thread.
5. Status words only: PASS, FAIL, PARTIAL, BLOCKED, N/A. PASS needs evidence you saw (file listing, log line, screenshot, scan result). "It compiles" is not PASS for a behaviour change.
6. Do not weaken or delete tests. If a step fails twice with an unknown cause, mark it BLOCKED and continue with independent steps.
7. **Stop and ask the owner** before: changing business rules, modifying anything outside `src/SS-CAM*`, `QA/`, `.agents/`, enabling the Archive prune/delete path, or touching real user data.

## Step 0: Baseline
- `git status` and `git log --oneline -10`. Expected: Archive/QR, startup, Settings/Focus and Radio commits exist; uncommitted changes are the radio stream URL edits (`tenant_config.json`, `TenantConfigService.cs`, `RadioStreamService.cs`, Linux `MainViewModel.cs`, Android `StudioRadioScreen.kt`).
- Run `.\.agents\skills\sscam-qa\scripts\run-sscam-qa.ps1 -Build -Configuration Debug`. Record the result. If the build fails, fix that first (smallest change).

## Step 1: Radio stream (`https://radio.suamisihat.myds.me/live.mp3`)
- Probe: `curl -s -o NUL -D - --max-time 10 -H "Icy-MetaData: 1" https://radio.suamisihat.myds.me/live.mp3`. Expect `200` and `audio/mpeg`. On the last check the server accepted the connection and sent nothing, so this may be BLOCKED (stream source offline). Report it; do not change the URL.
- Confirm no remaining `radio.suamisihat.myds.me/listen` or `/live"` in `src/` (grep). The migration in `RadioStreamService.LoadStations` must rewrite saved old URLs.
- Duplicate: "Corporate Radio" (`GetCorporateRadioStation`) and the pinned "SuamiSihat Radio Official" now share one URL. **Ask the owner** whether to remove the Core preset (it is a tenant URL inside Core code). Default: leave as is.

## Step 2: Archive (handoff T1): audit what is committed
Check each against the code; implement only what is missing:
1. Filter handlers guarded (`IsLoaded`). 2. `EstimateDirectorySize` off the UI thread. 3. `ArchivableProjectItem` raises `INotifyPropertyChanged`. 4. Empty workspace root shows an empty state with a route to Settings. 5. `ArchiveVaultService` logs via `App.LogTrace`, `CopyOnly` stays true.
Runtime proof (temp workspace only): open the page, archive a dummy project, confirm files under `_Archive/yyyy/yyyyMM_Month` with matching counts and sizes, a `_archive_catalog.jsonl` line, source untouched, and no new `crash_log.txt` entry.

## Step 3: QR Studio (handoff T2): audit and prove
Audit: errors logged and shown inline (no blank 21x21 fallback), Diamond/Classy implemented or hidden, SVG matches bitmap (logo, radius, gradient angle), dead encoder code removed only if no callers.
Proof: URL, vCard and WiFi codes render; PNG and SVG exports exist, decode with a QR reader (phone or `zxing`), and match visually; every shape with and without logo. If the real original failure was never reproduced, say so.

## Step 4: Startup and build speed (handoff T3): audit and measure
Audit items 1 to 9 in the handoff. Note which are done in code. Remaining likely items: `ngen install` in `installer/Build-Installer.ps1`, `/m` and `/t:Build` (not `/t:Rebuild`) and vswhere in the QA runner, unused references, duplicate `tenant_config.json` (Content plus EmbeddedResource), Costura skipped in Debug. Do not migrate to SDK-style csproj.
Measure (record numbers in `QA/09-PERFORMANCE.md`): clean build time, incremental build time, cold start to first frame, second launch (payload copy skipped, verify by file timestamps), and start with the NAS unreachable (window appears and stays responsive).

## Step 5: Settings, Focus theme, Radio UI: runtime verification (handoff T4 to T6)
Settings: every control behaves as before (save profile, workspace path and presets, sign in/out, module toggles update the sidebar, payload actions, reset dialogs confirm first); Tab order, focus, accessible names; narrow width.
Theme: cycle all six themes; no unreadable text; ComboBoxes render (including the Staff ComboBox); choice persists across restart.
Radio: play, stop, favourite, add, edit, delete, import, export; visualizer reacts; bottom bar in sync; stations without covers show initials; horizontal scroll never overlaps content.
Screenshot each page into `QA/screenshots/` (create if missing).

## Step 6: Release build
- `run-sscam-qa.ps1 -Build -Configuration Release`. Then `.\QA\verify-dual-track.ps1 -Fix` and `.\QA\verify-sscam.ps1` if present.
- Build the installer with `installer/Build-Installer.ps1` only if the owner asked for installer output in this run; otherwise N/A. Never publish.
- Linux (`src/SS-CAM.Linux`) and Android (`src/SS-CAM.Android`): compile-check only if the toolchain is installed (`dotnet build`, `gradlew assembleDebug`); otherwise BLOCKED. Do not run the Android release/signing skill.

## Step 7: Record and commit locally
- Append results to `QA/10-FIX-LOG.md` (what changed, evidence) and `QA/PHASE-LOG.md` (row per step: files, commands, result, not verified). Keep the old `/listen` entries in the log as history; add one new entry for `live.mp3`.
- Commit locally, grouped: (a) radio stream URL, (b) any fixes from steps 2 to 4, (c) QA docs. Trailer: `Co-Authored-By: Antigravity <noreply@google.com>`. **Do not push.**

## Final report (print this table, then stop)
| Step | Status | Evidence | Not verified / notes |
|---|---|---|---|
Include the build output path, the commit hashes, and every BLOCKED item with the reason. Ask the owner about the Corporate Radio duplicate and any other open decision.

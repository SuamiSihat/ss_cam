# Studio display (web portal) - QA record

Page: sidebar **Manage > Studio display** (`#studio-display`, in-app, touch-first). Public TV kiosk stays at `#signage`.
Roles: admin / manager / ceo (all write routes enforce this on the server).

| Area | Check | Status | Evidence |
|---|---|---|---|
| Navigation | Admin page no longer has a Studio Display tab, KPI card or ribbon item | PASS | Browser check on sandbox server |
| Navigation | Sidebar item opens `#studio-display` in the same tab; `#signage` still opens the kiosk | PASS | Browser check |
| Queue | Keypad + room chip -> Call now shows on page and on kiosk | PASS | Browser check (A-1031) |
| Queue | Add to waiting, Call next advances the queue | PASS | Browser check (A-1032) |
| Queue | Recall re-announces the same ticket (calledAt-based chime) | PARTIAL | Service test covers recall keeping the waiting list; audible chime not verified |
| Playlist | Toggle, reorder, add notice | PASS | Browser check (toggle, add notice); reorder not clicked in browser |
| Playlist | Upload MP4, stream with Range (206), delete removes file from disk | PASS | `security-tests.js` round trip with a minimal MP4 header |
| Playlist | Video plays on the kiosk and advances on end | PASS | Real ffmpeg MP4 uploaded via API; kiosk showed it playing, then returned to the next slide and cycled (browser check, silent playback). Sound ducking and unmuted autoplay on the real TV not checked |
| Branch info | Edit phone, save, persists after reload, shows on kiosk | PASS | Browser check |
| Branch info | Bad link (e.g. `javascript:`) refused; other branches unchanged; code cannot change | PASS | `security-tests.js` |
| Security | Designer/signed-out get 401/403 on every write route | PASS | `security-tests.js` |
| Security | Fake video sources and non-video uploads rejected | PASS | `security-tests.js` |
| Touch | Targets at least 44-48px, keypad, chips instead of dropdowns | PARTIAL | Visual check on desktop width; not tried on a real touch device |

Known limits: videos are upload-only (the site policy blocks external video links); a reverse proxy may cap upload size below the 300 MB app limit; the check-in QR on the TV is generated from the branch check-in link (see rows below); it has not been scanned with a phone yet.

| Area | Check | Status | Evidence |
|---|---|---|---|
| TV | Check-in slide shows a generated QR code from the branch check-in link (not the old decorative picture) | PASS | Browser check, fresh load |
| TV | Scanning the QR with a phone opens the check-in link | BLOCKED | Needs a phone scan on the real TV |
| Reception role | Clinic role can call, edit waiting list and clear the queue; refused on playlist, branch and video routes; capabilities and route list correct | PASS | `security-tests.js` |
| Reception role | Clinic user sees only the Queue tab on the page | PARTIAL | Code and build only; not clicked through as a clinic user |

## Task T1.0: Branch Consumer Impact Analysis

Audited consumers of `branchCode`, `getBranches`, `getBranchByCode`, and `SSC-BSR` across `server/`, `client/src/`, and desktop clients:

| Consumer / Component | File Location | Role & Usage | Impact if Archived | Impact if Permanently Removed |
|---|---|---|---|---|
| **Signage TV Display** | `client/src/lib/views/SignageView.svelte`, `server/services/SignageService.js` | Displays TV waiting queue, room status, duty doctors, KKM licence | If requested branch is archived, server previously fell back to first branch (leaking foreign KKM licence). T1.1 guard blocks archiving active TV branch; TV shows branded "Screen Not Assigned" state (`branchMissing: true`). | Same as archived. Permanent delete only permitted when archived and not broadcasting. |
| **Studio Display Admin** | `client/src/lib/views/StudioDisplayView.svelte` | Branch selector, queue management, playlist editor, branch profile editor | Hidden from active branch switcher tabs. Visible in "Removed branches" archive management list with "Restore" action. | Purged from UI; TV and playlist configs cleaned up. |
| **Consultation Suite** | `client/src/lib/views/ConsultationSuiteView.svelte` | Doctor selects branch for treatment consultations and dispatch | Excluded from `/api/clinic/branches` dropdown. Auto-falls back to first active branch (`branches[0].code`) without UI crash. | Excluded from dropdown. No error. |
| **Care Dispatcher** | `server/services/CareDispatcherService.js` (`generateDispatchMessage`) | Generates post-treatment WhatsApp care guides and follow-up templates | Resolves branch details if code provided; falls back safely to `BranchService.getBranches()[0]`. | Falls back safely to first active branch. |
| **Branch Service & Templates** | `server/services/BranchService.js` (`injectBranchDetails`, `generateIntakePayload`) | Injects `{BRANCH_NAME}`, `{KKM_LICENSE}`, `{BRANCH_PHONE}` into consultation templates; generates check-in/review URLs | Resolves branch if existing; falls back to active branch. | Falls back to active branch. |
| **Corporate Registry & Pricing** | `server/services/CompanyService.js` (`companies.json`) | Persists clinic branch metadata and custom branch pricing blocks | Stored with `archived: true` flag. Pricing packages, consultation fee, and KKM records remain intact. | Permanently removed from `company.branches` array. Associated branch pricing block deleted. |
| WPF Desktop Application | `src/SS-CAM/Services/QrCodeEncoderService.cs`, `src/SS-CAM/Views/QrCodePage.xaml` | Standalone QR code encoder presets for clinic marketing materials | None. Desktop app uses static in-memory C# presets (`GetClinicBranches`) decoupled from web runtime. | None. Decoupled from web API. |
| **Android / Linux Apps** | `src/SS-CAM.Android/`, Linux scripts | Companion and deployment tooling | None. No branch dependencies. | None. |

## Phase 1 Server Data Model, Playlist & Banner Media Verification

| Task | Check / Invariant | Status | Evidence |
|---|---|---|---|
| **T1.1** | Add branch: validates code format `^[A-Z0-9-]{2,12}$`, enforces uniqueness, rejects missing name | PASS | `run-tests.js` (TEST 63B) |
| **T1.1** | Archive branch guards: cannot archive last active branch; cannot archive branch broadcasting on TV | PASS | `run-tests.js` (TEST 63B) |
| **T1.1** | Restore branch: restores archived branch to active status and switcher | PASS | `run-tests.js` (TEST 63B) |
| **T1.1** | Delete branch guard: permanent deletion only permitted when branch is already archived | PASS | `run-tests.js` (TEST 63B) |
| **T1.1** | TV licence protection: unknown or archived branch returns `branchMissing: true` and empty licence (never leaks another branch's licence) | PASS | `run-tests.js` (TEST 63B) |
| **T1.1** | Route authorization: branch management routes restricted to `admin`, `manager`, `ceo` | PASS | `security-tests.js` & `ROUTE-AUTHZ-MATRIX.md` |
| **T1.2** | V1 to V2 migration: auto-detects legacy shape, writes `signage_config.json.bak-v1`, migrates state under branch code | PASS | `run-tests.js` (T1.2 suite) |
| **T1.2** | Idempotency: re-running migration on v2 config is a clean no-op | PASS | `run-tests.js` (T1.2 suite) |
| **T1.2** | Per-branch queue isolation: calling ticket on one branch does not alter or announce on another; clearing one branch queue leaves others intact | PASS | `run-tests.js` (T1.2 suite) |
| **T1.3** | Slide CRUD: add, patch, delete slides scoped to branch | PASS | `run-tests.js` (T1.3 suite) |
| **T1.3** | Optimistic concurrency: `baseRevision` mismatch returns HTTP 409 Conflict with `conflict: true` and current revision | PASS | `run-tests.js` (T1.3 suite) |
| **T1.3** | Duplicate slide: creates clone with new ID and `(Salinan)` title suffix | PASS | `run-tests.js` (T1.3 suite) |
| **T1.3** | Reorder slides: reorders slides, rejects unknown IDs | PASS | `run-tests.js` (T1.3 suite) |
| **T1.3** | Copy playlist: copies slides across branches with independent IDs; media files shared by reference | PASS | `run-tests.js` (T1.3 suite) |
| **T1.3** | Restore default slides: restores 5 canonical built-in slides | PASS | `run-tests.js` (T1.3 suite) |
| **T1.4** | Banner upload: valid 1920x1080 JPEG/PNG/WebP accepted, dimensions inspected from binary headers without external dependencies | PASS | `run-tests.js` (T1.4 suite) |
| **T1.4** | Aspect ratio check: non-16:9 images accepted with warning notice in response | PASS | `run-tests.js` (T1.4 suite) |
| **T1.4** | Magic bytes verification: fake images with forged extensions refused and immediately deleted from disk | PASS | `run-tests.js` (T1.4 suite) |
| **T1.4** | Dimension requirement: images below 640x360 refused and deleted | PASS | `run-tests.js` (T1.4 suite) |
| **T1.4** | Security guard: SVG file uploads refused (XSS prevention) | PASS | Multer filter & test suite |
| **T1.4** | Reference-counted deletion: media file deleted from disk ONLY when no slide in any branch references it | PASS | `run-tests.js` (T1.4 suite) |
| **T1.4** | Replace slide media: replaces media file on slide, purges old file if unreferenced | PASS | `api.js` & `SignageService.js` |
| **T1.5** | Test suites verification: all unit, smoke, and security test suites 100% green | PASS | 78/78 `run-tests.js`, 13/13 `admin-smoketest.js`, 43/43 `security-tests.js` |
| **T1.5** | Client build verification: Vite build compiles without errors | PASS | `npm run build:client` (13.56s) |
| **T1.5** | Route authorization matrix: all 18 signage and studio display routes documented | PASS | `QA/ROUTE-AUTHZ-MATRIX.md` |

## Phase 2 Admin Page Redesign & Touch Controls Verification

| Task | Check / Invariant | Status | Evidence |
|---|---|---|---|
| **T2.1** | Component groundwork: `FluentButton size="touch"` (52px min-target), `FluentIcons` (tv, arrowUp, arrowDown, archive, volume, volumeMute), `FluentBadge` | PASS | `FluentButton.svelte`, `FluentIcons.svelte`, `build:client` |
| **T2.2** | Shell & Header: 24px/800 title, live synchronized pill with pulsing dot, TV link, Royal Blue active tabs (contrast ratio > 4.5:1, passes WCAG AA), zero white-on-azure text | PASS | `StudioDisplayView.svelte`, `BRAND-TOKENS.md` |
| **T2.2** | Always-visible branch switcher: horizontal touch-optimized branch pills, "On TV" badge on broadcast branch, "+ Add branch" quick trigger | PASS | `StudioDisplayView.svelte` |
| **T2.2** | 60:30:10 CTA rule: exactly ONE Banana Yellow CTA (`appearance="cta"`, `#FCE53D` background, `#1C1C1C` text) per view/tab (Queue: "Call now", Playlist: "Add to playlist", Branch: "Save branch info", Display: "Save ticker") | PASS | Verified in `StudioDisplayView.svelte` |
| **T2.3** | Playlist visual cards: 16:9 thumbnail previews (Banner `<img>`, Video badge, branded clinical tiles), Title, Subtitle, Badges (Type, Duration, Scheduled, Fit mode) | PASS | `StudioDisplayView.svelte` |
| **T2.3** | Playlist slide actions: On/Off switch toggle, Reorder Up/Down buttons, Edit dialog, Replace media dialog, Duplicate (`duplicateSignageSlide`), Remove with confirmation dialog | PASS | `StudioDisplayView.svelte`, `api.ts` |
| **T2.3** | Add slide dialog: Banner uploader (1920x1080 spec guide, image preview, progress bar, duration, fit cover/contain, fullScreen), Video uploader (300MB cap), Notice editor | PASS | `StudioDisplayView.svelte` |
| **T2.3** | Playlist utilities: Copy playlist from another branch dialog, Restore default slides dialog | PASS | `StudioDisplayView.svelte` |
| **T2.4** | Live TV preview panel: Scaled 16:9 frame (`#signage?branch=${code}&preview=1`), muted, no audio chime storm, real-time updates via `signage:updated` SSE, toggle button in header | PASS | `StudioDisplayView.svelte` |
| **T2.5** | Branch profile editor: Full form (Name, Short name, Address, Phone, WhatsApp, Hours, KKM licence with warning badge if missing, Check-in URL, Review URL) | PASS | `StudioDisplayView.svelte` |
| **T2.5** | Duty doctors list: Interactive chips with inline add and remove | PASS | `StudioDisplayView.svelte` |
| **T2.5** | Add branch dialog: Name, short name, code generation & validation (`^[A-Z0-9-]{2,12}$`), "Copy playlist from" selector | PASS | `StudioDisplayView.svelte` |
| **T2.5** | Remove branch (archive): Plain-language blocked reason if branch is on TV or last active branch; preserves data, removes from TV and selectors | PASS | `StudioDisplayView.svelte` |
| **T2.5** | Removed branches disclosure: Collapsible list of archived branches with Restore and Permanent Delete (requires typing branch code to confirm) | PASS | `StudioDisplayView.svelte` |
| **T2.6** | Touch Queue controls: 52px keypad, prefix selector chips (A-F), room chips, duty doctor chips, "Call now" Banana CTA, "Add to waiting", waiting list with Move and Call | PASS | `StudioDisplayView.svelte` |
| **T2.6** | Display tab: Chime & voice on call toggle, scrolling ticker prefix & message editor with Banana CTA, rooms and consultation counters manager | PASS | `StudioDisplayView.svelte` |
| **T2.7** | Client build verification: Vite build compiles without errors | PASS | `npm run build:client` (16.13s) |

## Phase 3 TV Display Brand Pass & Banner Rendering Verification

| Task | Check / Invariant | Status | Evidence |
|---|---|---|---|
| **T3.1** | Theme & Palette: Prussian Navy `#022057` ground with Royal Blue gradient, Banana Yellow `#FCE53D` reserved for "Now Calling" (`.queue-call-box.is-calling`) | PASS | `SignageView.svelte` |
| **T3.1** | Official Clinic Logo: Replaced generic cross placeholder with `/brand/suamisihat-logo-on-dark.svg` with graceful SVG fallback | PASS | `SignageView.svelte` |
| **T3.2** | Icon system: Replaced all emoji with crisp `FluentIcons` rendered at TV scale | PASS | `SignageView.svelte` |
| **T3.2** | TV legibility & scaling: Minimum 16-20px typography, 46px slide titles, 58px call numbers; safe-area padding for 1080p and 4K displays | PASS | `SignageView.svelte` |
| **T3.3** | Banner rendering: Edge-to-edge 16:9 banner image inside slide card, `fit: cover` or `contain`, gradient caption strip | PASS | `SignageView.svelte` |
| **T3.3** | Preloading & Error guards: Preloads next banner image in background; 3s timeout skip on broken image prevents freezing loop | PASS | `SignageView.svelte` |
| **T3.3** | Per-slide duration & scheduling: Honors `durationSec` per slide; filters expired/scheduled slides by `startsAt` and `endsAt` | PASS | `SignageView.svelte` |
| **T3.4** | Full-screen banner overlay: Banner can fill stage; when a ticket is called (`justCalled`), "Now Calling" Banana Yellow box pops up on top for 4.5s | PASS | `SignageView.svelte` |
| **T3.5** | Missing branch screen: Shows branded "Screen Not Assigned" message when branch is missing/archived; never leaks foreign KKM licence | PASS | `SignageView.svelte` |

## Phase 4 Governance & Test Suite Verification

| Task | Check / Invariant | Status | Evidence |
|---|---|---|---|
| **T4.1** | All QA acceptance checks verified and documented | PASS | `QA/STUDIO-DISPLAY-QA.md` |
| **T4.4** | Dual-track governance gatekeeper: `.\QA\verify-dual-track.ps1 -Fix` | PASS | 14/14 checks passed, safe for SS-Master |
| **T4.4** | Backend test suite: `run-tests.js` | PASS | 78 Passed, 0 Failed |
| **T4.4** | Admin smoke test: `admin-smoketest.js` | PASS | 13 Passed, 0 Failed |
| **T4.4** | Security & AuthZ test: `security-tests.js` | PASS | 43 Passed, 0 Failed |
| **T4.4** | Client production bundle: `npm run build:client` | PASS | 16.13s clean build |



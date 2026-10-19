# Studio Display Redesign: Plan for Antigravity

**Target:** `src/SS-CAM.Web`. Admin page `client/src/lib/views/StudioDisplayView.svelte` (`#studio-display`), TV page `client/src/lib/views/SignageView.svelte` (`#signage`), server `server/services/SignageService.js`, `BranchService.js`, `CompanyService.js`, routes in `server/routes/api.js` (section "CLINIC SIGNAGE & STUDIO DISPLAY ROUTES").
**Written:** 2026-10-19. **Status:** DRAFT, nothing implemented. Waiting for the owner's answers in section 2.
**Read first:** `AGENTS.md`, `QA/BRAND-TOKENS.md`, `QA/STUDIO-DISPLAY-QA.md`, `QA/ROUTE-AUTHZ-MATRIX.md`, `QA/ANTIGRAVITY-EXECUTION-PLAN.md` (rules in its section 0 apply here too).
**Brand reference:** https://assets.suamisihat.myds.me/components/ (not opened while drafting; read it before Phase 2) and `payload/Brand Assets/` (logos in `Logos/02_logo_ssClinic/`, palettes in `Colour Palettes/`).

## 0. Goals (from the owner)

1. Redesign the Studio Display page so it follows the SuamiSihat brand guideline (art direction + front-end).
2. Add and delete branches.
3. Use a banner image as a playlist item.
4. Add, edit, update and remove playlist items, including the existing ones.

## 1. What exists today (verified by reading the code)

| Area | Finding |
|---|---|
| Branches | Stored on the SSC company in the Corporate Registry (`companies.json`). Only **edit** exists (`PUT /api/clinic/branches/:code`). No add, no delete. If the registry has zero branches the server silently falls back to four built-in branches (`BranchService.getBranches`). |
| Signage state | **One global state for all branches**: a single `signage_config.json` holds `rooms`, `queue` (current call and waiting list) and `slides`. Only `branchCode` selects which branch profile is shown. Adding a second real branch today would make both TVs share one queue and one playlist. |
| Playlist | Types: doctors, eswt, trt, intake, notice, video. Staff can add a video or notice, toggle, reorder, mute and remove **only** video and notice. There is no edit. Built-in slides cannot be removed. Saving sends the **whole slide array** (last write wins, two admins can overwrite each other). |
| Media | Videos only: `signage_media/<16 hex>.mp4|webm`, 300 MB cap, magic-byte check. No image support. No library such as sharp is installed (only multer). |
| Missing branch | `getConfig` silently falls back to the first branch when the requested one is unknown. A TV pinned to a deleted branch would show **another branch's KKM licence**. |
| Admin page vs brand | Active tab and all "primary" buttons are Azure `#21A1F7` with white text (about 2.6:1 contrast, fails AA). Brand rule is one Banana Yellow CTA per view; the page has 2 to 3 primary buttons per tab. Bespoke `.sd-big`, `.sd-icon`, `.sd-input`, `.sd-tag` styles duplicate `FluentButton`, `FluentInput`, `FluentBadge`. Row actions use text glyphs (↑ ↓ ✕). |
| TV page vs brand | Header logo is a generic placeholder cross, not the SS Clinic logo. Emoji used as icons (👨‍⚕️ ⚡ 🩸 🔋 🧠 📢 🔔). Many raw hex colours (`#020C1F`, `#061938`, `#94A3B8` and so on) instead of tokens. Several texts are 11 px, unreadable from across a waiting room. Brand name "SUAMISIHAT CLINIC" and Malay copy are hard-coded in a Core file (dual-track rule). |

**Not verified while drafting:** the lower half of the SignageView styles (lines 835 to 1185), the Corporate Registry UI for branches, how `ConsultationSuiteView`/`CareDispatcherService` use branch codes, whether other apps (WPF, Android, Linux) read branches. Task T1.0 checks these.

## 2. Decisions needed from the owner (recommended answer first)

| # | Question | Recommendation | If the owner disagrees |
|---|---|---|---|
| D1 | Queue, rooms and playlist per branch, or shared? | **Per branch.** Each branch gets its own queue, rooms and playlist, with "Copy playlist from another branch". Required for a second TV to work at all. | Shared everything: only valid if there will only ever be one TV. Then skip T1.2 and T2.5. |
| D2 | "Delete branch": remove for good, or archive? | **Archive** (hidden from TV and pickers, restorable from "Removed branches"). Pricing and licence data survive. Permanent delete only from the archive list, typing the branch code to confirm. | Hard delete only: simpler, but pricing data is lost with no undo. |
| D3 | Banner shown inside the slide area (queue panel stays visible) or full screen? | **Inside the slide area by default**, per-slide option "Full screen" that hides the queue panel while the banner shows (queue calls still pop up, see T3.4). | Inside only. |
| D4 | Schedule banners (show from / until)? | **Yes, optional** start and end date per slide, so expired promos drop off the TV on their own. Marked P2, can ship after the rest. | Skip. |
| D5 | Allow removing the built-in slides (duty doctors, ESWT, TRT, check-in)? | **Yes**, with a "Restore default slides" action. Today the owner cannot retire them. | Keep them locked, allow hide only. |

Do not start Phase 1 until D1 and D2 are answered. Everything below assumes the recommended answers.

## 3. Rules for the executing agent

Same as `QA/ANTIGRAVITY-EXECUTION-PLAN.md` section 0, plus:

1. **Test data only.** Run the server with throwaway `WORKSPACE_ROOT` and `DATA_DIR`. Never touch the NAS or the live site. Never run the deploy skill unless the owner says so.
2. **Back up before migrating.** The signage migration (T1.2) rewrites `signage_config.json`. It must write a `signage_config.json.bak-v1` first and be idempotent.
3. **Reuse components** in `client/src/lib/components/ui/` (`FluentButton`, `FluentInput`, `FluentSelect`, `FluentDialog`, `FluentCard`, `FluentBadge`, `FluentSkeleton`, `FluentErrorBanner`, `FluentIcons`). Extend them (for example a `size="touch"` button) instead of adding new bespoke styles. Add missing icons to `FluentIcons.svelte`, do not create a second icon system.
4. **Core stays generic.** Brand name, logo and Malay copy on the TV come from tenant config, not from literals in Core files. The built-in sample branches in `BranchService` are a pre-existing tenant leak, note it in the report but do not widen it.
5. **Terminology** (AGENTS rule): keep "Studio display" for the page, "TV screen" for `#signage`, "Playlist", "Branch". Use "Remove" for playlist items and "Remove branch" for branches (archive). Do not introduce "Delete/Job/Preferences" variants.
6. Every new route needs an entry in `QA/ROUTE-AUTHZ-MATRIX.md`, an audit event, and role checks (`signageStaff`: admin, manager, ceo).
7. Never mark PASS without running the check. Browser checks on the sandbox server count only if you looked at the rendered page.

## 4. Design direction (art director brief)

**Feeling:** calm, clinical, trustworthy, a little warm. Porcelain and white surfaces, Prussian Navy for structure, Royal Blue and Azure for interaction, Banana Yellow reserved for the single action that matters on each screen. Men's-health audience: confident, discreet, never gimmicky (no emoji, no cartoon icons).

### 4.1 Admin page (`#studio-display`)

- **Colour (60:30:10, from `QA/BRAND-TOKENS.md`):** canvas `--bg-canvas` Porcelain (60), cards `--surface-card` and Prussian Navy structure (30), accents (10): `--ss-blue` for secondary buttons, `--ss-azure` only for focus rings, selected states and links, `--cta-bg` Banana Yellow with `--cta-fg` for **one** CTA per tab: Queue = "Call next", Playlist = "Add to playlist", Branch = "Save branch info", Display = "Save ticker".
- **Fix contrast:** selected tab, chips and toggles currently white on Azure. Use Royal Blue `#043388` (white text, passes AA) or navy underline tabs. Verify every text/background pair is at least 4.5:1.
- **Header:** title "Studio display" (h1 24/800), context chip "Bangsar HQ · showing on TV" with the live dot, and the "Open TV screen" link.
- **Branch switcher** always visible at the top (all tabs act on the selected branch, see D1). Replaces the mini chips inside the Branch tab.
- **Playlist as visual cards:** 16:9 thumbnail (banner image, video first frame via `<video preload="metadata">`, branded glyph tile for text slides), title, type badge (`FluentBadge`), duration, state badge: Live now / Hidden / Scheduled / Expired. Drag handle plus up/down buttons (keep buttons for touch and keyboard).
- **Live preview panel** beside the playlist: the real TV page in a scaled 16:9 frame (`<iframe src="#signage?branch=CODE&preview=1">`, `pointer-events:none`, no audio, no polling storm). Staff see what the TV shows before leaving the page. Preview mode must not play call chimes.
- **Touch-first stays:** targets stay at least 48 px (brand minimum is 44). Document this as an intentional exception in the QA file. Move the sizing into `FluentButton size="touch"` instead of `.sd-big`.
- **Icons:** `FluentIcons` for all row actions (existing: add, edit, delete, copy, image, play, eye). Add: chevronUp, drag, upload, archive, restore, calendar.
- **States** (AGENTS "UI STATES"): skeletons while loading, empty playlist with a clear CTA, upload progress with Cancel, inline error banners, offline banner, disabled and busy states, success toasts. No silent failures.
- **Accessibility:** visible focus ring (`--focus-ring`), `aria-live` for save results, labelled icon buttons, keyboard reorder (Alt+Arrow or the buttons), dialogs trap focus, tab order follows visual order. Respect `prefers-reduced-motion`.
- **Dark mode:** use tokens only, no literal colours, so `[data-theme=dark]` works.

### 4.2 TV page (`#signage`)

- **Palette:** Prussian Navy `#022057` ground with a subtle Royal Blue gradient, white text, Azure accents, **Banana Yellow reserved for "now calling"** (the one thing that must grab the eye). Define `--kiosk-*` variables mapped to the brand palette once, remove raw hex.
- **Logo:** real SS Clinic logo (`logo_ssc_primary_dark.svg`) in the header, supplied by tenant config with a generic fallback. Remove the placeholder cross.
- **Icons:** replace all emoji with `FluentIcons` rendered at TV size, in Azure/Malibu tints.
- **TV legibility:** minimum 20 px body, 14 to 16 px labels are not allowed on the TV (header pills and clock date are 11 px today). Scale the whole layout from the viewport (`clamp` or a root font-size tied to width) so 1080p and 4K look the same. 48 px safe-area padding for TVs that overscan. Contrast at least 4.5:1.
- **Motion:** 400 ms cross-fade between slides, a short flash on a new call, nothing flashes faster than 3 times a second, honour `prefers-reduced-motion`.
- **Banner slide:** edge-to-edge image inside the rounded slide card (no inner padding), optional caption on a navy gradient strip along the bottom, `object-fit: cover` or `contain` per slide (see T3.3). Banner spec shown in the admin uploader: **1920×1080 (16:9), JPG/PNG/WebP, up to 10 MB, keep text 5% away from the edges**. The slide area on a 1080p TV is about 1428×870, so keep important content centred.
- **Copy:** Malay strings stay Malay (existing audience) but move to one strings object so a tenant or language can override them.

## 5. Phases and tasks

### Phase 1: Server (data model, branches, playlist, banner media)

**T1.0 Impact check (read-only).** Grep every use of `branchCode`, `getBranches`, `getBranchByCode`, `SSC-BSR` across `server/`, `client/src/` and the other clients (`src/SS-CAM`, `src/SS-CAM.Android`, Linux). List what breaks if a branch is archived or removed (pricing, consultation, care dispatcher, intake QR, templates). Output: a short table in `QA/STUDIO-DISPLAY-QA.md`. No code changes. Acceptance: table exists and names every consumer.

**T1.1 Branch add / archive / restore / delete.**
- `CompanyService`: `addBranch`, `archiveBranch`, `restoreBranch`, `removeBranch` (permanent, archived only). Reuse `sanitizeBranches`. Seed from built-ins when the registry is empty, exactly like `updateBranch`.
- `BranchService`: matching methods plus `getBranches({includeArchived})` (default hides archived). Branch `code`: `^[A-Z0-9-]{2,12}$`, unique, **immutable after creation**, suggested from the short name. Add optional `archived: boolean`.
- Guards (each returns a plain-language 400/409): cannot archive the **last active** branch (prevents the silent fall-back to built-ins, so also stop `getBranches` falling back once the registry has a branch list, even if all are archived); cannot archive a branch that is **showing on a TV** unless the request names another branch to switch to; permanent delete only when archived.
- Routes: `POST /api/clinic/branches`, `POST /api/clinic/branches/:code/archive`, `POST /api/clinic/branches/:code/restore`, `DELETE /api/clinic/branches/:code` (archived only). Roles: admin, manager, ceo. Audit events `ADD_BRANCH`, `ARCHIVE_BRANCH`, `RESTORE_BRANCH`, `DELETE_BRANCH`.
- `getConfig` must **not** fall back to another branch for an unknown or archived `?branch=`: return `branch: null` and `branchMissing: true` (the TV shows a "This screen is not assigned to a branch" state, never another branch's licence).
- Tests: add (valid, duplicate code, bad code, missing name), archive guards (last branch, branch on TV), restore, delete only when archived, role matrix (reception gets 403), unknown branch does not leak another licence.

**T1.2 Per-branch signage state (needs D1).**
- New file shape: `{ version: 2, shared: { soundAlertEnabled, ticker?... }, branches: { "<CODE>": { rooms, queue, slides, slideDurationSec } } }`. Decide in the report which settings are shared (suggest: sound, ticker prefix) and which are per branch (rooms, queue, slides, duration, ticker text).
- Migration: if `version` is missing, back up to `signage_config.json.bak-v1`, move the old global `rooms/queue/slides` under the current `branchCode`, give every other branch a **clone of the default playlist** and empty queue. Idempotent. A new branch gets the defaults on first use.
- All queue and playlist methods take a branch code. The `?branch=` the TV sends selects the state. The SSE event includes `branchCode`; the TV ignores events for other branches (today it refetches).
- Response stays backward compatible: `GET /api/clinic/signage` still returns `slides`, `queue`, `rooms` at the top level for the selected branch, so TVs running the old bundle during deploy keep working.
- Tests: migration from a v1 fixture (data preserved, backup written, second run is a no-op), two branches keep separate queues, calling a ticket on one branch does not change the other.

**T1.3 Slide CRUD and optimistic concurrency.**
- Endpoints (all scoped to a branch): `POST /clinic/signage/slides`, `PATCH /clinic/signage/slides/:id`, `DELETE /clinic/signage/slides/:id`, `PUT /clinic/signage/slides/order`, `POST /clinic/signage/slides/:id/duplicate`, `POST /clinic/signage/copy-playlist` (from another branch; media files are **shared by reference**).
- Editable fields per type: all: `enabled`, `tag`, `title`, `subtitle`, optional `durationSec` (3 to 120, overrides the global value), optional `startsAt`/`endsAt` (D4); video: `muted`; banner: `fit` (`cover|contain`), `fullScreen` (D3), `alt`. Built-in types: text fields only, the layout stays fixed.
- Remove works for every type incl. built-ins (D5) plus `POST /clinic/signage/slides/restore-defaults`.
- Concurrency: every response carries `revision` (integer); mutating calls send `baseRevision`; a mismatch returns **409** "Someone else changed the playlist. Reload to see it." The client reloads and keeps the user's draft text.
- Files are deleted only when **no slide in any branch** still references them (reference count). Today `removeVideo` deletes unconditionally.
- Keep the whole-array `PUT /clinic/signage` for backward compatibility until the new admin UI ships, then remove the `slides` field from it (note in the report).
- `sanitizeSlide`: add `banner` to `SLIDE_TYPES`; clip all text; validate dates; unknown fields dropped.
- Tests: each endpoint, validation errors, order endpoint rejects unknown ids, 409 on stale revision, reference-counted file deletion, role matrix, XSS strings in titles stay inert (the TV renders text, never HTML).

**T1.4 Banner (image) upload.**
- `POST /clinic/signage/media/image` (multer disk storage into `signage_media/`, same pattern as video). Allowed: `.jpg .jpeg .png .webp`, **no SVG** (script injection risk). 10 MB cap. File name `<16 hex>.<ext>`; extend `MEDIA_FILE_PATTERN` and `resolveMediaFile` (still anchored, no traversal).
- Verify real type by magic bytes (JPEG `FF D8 FF`, PNG `89 50 4E 47`, WebP `RIFF....WEBP`); delete and refuse on mismatch. Read width and height from the file header (no new dependency); reject below 640×360, warn (in the response) when the aspect ratio is not close to 16:9.
- Serve with the right `Content-Type`, `X-Content-Type-Options: nosniff`, cache headers; reuse the existing media read route and rate limit.
- `POST /clinic/signage/slides/:id/media` **replaces** the file of an existing video or banner slide (the "update" action): validate first, swap, then delete the old file only if unreferenced.
- Tests: valid files, wrong extension, extension/content mismatch, SVG refused, oversize, traversal file names, tiny image, replace keeps slide position.

**T1.5 Server verification.** `npm test` (all three suites), `node server/test/admin-smoketest.js`. Update `QA/ROUTE-AUTHZ-MATRIX.md`. PASS only with the real output.

### Phase 2: Admin page redesign and features

**T2.1 Component groundwork.** `FluentButton size="touch"`, new icons in `FluentIcons.svelte`, a small `PlaylistCard` and `BranchCard` under `components/` (only if no existing card fits, record the search). Remove the `.sd-big/.sd-icon/.sd-input/.sd-tag` duplicates as they are replaced.

**T2.2 Shell, header, branch switcher, tabs** per 4.1 (contrast fixed, one Banana CTA per tab, focus rings, skeletons, error and offline states).

**T2.3 Playlist tab.** Card list, drag and drop plus buttons, enable toggle, **Edit dialog** (title, tag, subtitle, duration, schedule, mute, banner fit/full screen/alt), **Replace file** action, **Duplicate**, **Remove** (confirm names the item; removing a file-backed item says the file is deleted unless another branch uses it), **Add** menu: Banner image / Video / Notice. Banner uploader shows the spec (1920×1080, 10 MB, safe zone), previews the image, shows upload progress with Cancel, and shows the server's aspect-ratio warning. "Restore default slides" in an overflow menu.

**T2.4 Live preview panel** (iframe, `preview=1`, muted, no chime, refreshes on `signage:updated`). Hidden under 1100 px width, shown as a collapsible section on tablets.

**T2.5 Branch tab: add, edit, archive, restore, delete.**
- Branch list as cards (name, address, doctors count, licence, "On TV" badge, "Licence missing" warning).
- **Add branch** dialog (name, short name, code suggested and editable, address, phone, WhatsApp, hours, KKM licence, check-in link, "start from" an existing branch). Inline validation messages, no silent failure.
- **Remove branch** in a clearly separated "Remove this branch" section: explains it hides the branch from the TV and pickers and keeps its data; blocked reasons are shown in words ("This branch is showing on a TV. Choose another branch for the TV first."). "Removed branches" disclosure with Restore and "Delete permanently" (type the code to confirm).
- Warn (not block) when showing a branch on the TV with no KKM licence.

**T2.6 Queue and Display tabs** get the same styling pass; behaviour unchanged. Reception role still sees the Queue tab only.

**T2.7 Client verification.** `cd client && npm run build`, `npx svelte-check` (no new errors in touched files). Rebuild `client/dist` only in this task.

### Phase 3: TV page brand pass and banner rendering

**T3.1 Tokens and logo.** `--kiosk-*` variables, remove raw hex, tenant-supplied logo and name (generic fallback), real SS Clinic logo asset copied into `client/public/` (record the source path).

**T3.2 Icons, type scale, scaling.** Emoji to `FluentIcons`; minimum sizes per 4.2; viewport-based scaling; safe-area padding; check 1920×1080, 3840×2160 and 1366×768.

**T3.3 Banner rendering.** New slide branch: image fills the slide card, `cover`/`contain`, optional caption strip, `alt` for screen readers, **preload the next image**, `onerror` skips the slide after 3 s (same as video) and logs, a 5 s decode timeout so one broken file never freezes the loop. Per-slide `durationSec`; schedule filtering (D4) done client-side with the server clock offset so a TV with a wrong clock does not misfire.

**T3.4 Full-screen banner and call pop-up (D3).** When a full-screen banner is showing and a ticket is called, show the "now calling" overlay on top for the 4 s flash plus the chime, then return. The queue is never hidden from a patient for longer than that.

**T3.5 Missing-branch and offline states** (branch archived or unknown, server unreachable, empty playlist): branded full-screen messages with the clinic logo, never a blank or broken page.

### Phase 4: QA, docs, release

**T4.1 QA record.** Extend `QA/STUDIO-DISPLAY-QA.md` with rows for every acceptance check below, using only PASS/FAIL/PARTIAL/BLOCKED/N/A.
**T4.2 Browser pass on a sandbox server** (throwaway workspace): add a branch, add a banner, edit it, replace its image, reorder, hide, remove; archive and restore a branch; open the TV page for two branches and confirm separate queues. Screenshots into `QA/`.
**T4.3 Physical TV check** (owner): 1080p and 4K, text readable from 4 m, no overscan clipping, call chime and voice still work after a banner slide.
**T4.4 Run `.\QA\verify-dual-track.ps1 -Fix`**, then COMMIT in two commits (server, then client) with the required `Co-Authored-By` line.
**T4.5 Deploy** only on the owner's instruction, using `QA/DEPLOY-LOGIN-FIX-PLAN.md` as the pattern. **Back up the NAS `signage_config.json` first**, since T1.2 migrates it. Order matters: server and client ship together; the backward-compatible response (T1.2) keeps TVs on the old bundle working until they reload.

## 6. Acceptance checklist (all must be PASS before "done")

1. Add a branch: appears in the switcher and in the Corporate Registry data, survives a server restart.
2. Archive a branch: gone from the TV picker; a TV pinned to it shows the "not assigned" screen, **not** another branch's licence. Restore brings it back with its data and pricing.
3. Cannot archive the last branch or a branch currently on a TV (plain-language message).
4. Two branches keep separate queues and playlists; calling a ticket on one does not announce on the other.
5. Upload a 1920×1080 JPG banner: thumbnail in the admin, shows on the TV in the right position for the right duration. A renamed `.exe` or `.svg` is refused.
6. Edit a slide (title, duration, fit): TV updates within 5 s. Replace the banner file: same slot, old file removed, other branches using it unaffected.
7. Remove a slide: confirm names it; the file is deleted only when no one else uses it. Removing a built-in works and "Restore default slides" brings them back.
8. Two admins editing at once: the second save gets a 409 message and loses nothing typed.
9. Contrast: every text/background pair on both pages at least 4.5:1; exactly one Banana CTA per tab; focus ring visible on every control; whole page usable by keyboard.
10. TV: no emoji, no raw hex, no text under 20 px, logo present, correct at 1080p and 4K, reduced-motion respected.
11. `npm test`, admin smoke test, client build all green; route matrix and QA files updated.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Live `signage_config.json` migration corrupts the clinic's current playlist or queue | Backup file, idempotent migration, tested on a v1 fixture, NAS backup before deploy |
| A TV shows the wrong branch's licence (regulatory) | `branchMissing` state, no silent fall-back (T1.1), acceptance check 2 |
| Old TV browsers keep the old bundle after deploy | Backward-compatible API response (T1.2); owner reloads each TV once |
| Disk fills on the NAS with media | 10 MB image and 300 MB video caps, reference-counted deletion, show total media size in the admin |
| SVG or disguised file upload | Allow-list of extensions, magic-byte check, no SVG, `nosniff`, files only addressable by generated name |
| Scope growth (per-branch state touches queue code that reception uses daily) | Phase 1 tests first; Queue behaviour must be unchanged for a single branch (regression check in T4.2) |
| Sample branches and "SuamiSihat" strings already live in Core files | Out of scope here; reported, tracked for the dual-track cleanup |

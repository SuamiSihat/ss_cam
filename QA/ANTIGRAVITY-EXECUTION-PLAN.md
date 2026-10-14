# Web Portal Remediation: Execution Plan for Antigravity

**Target:** `src/SS-CAM.Web` (Svelte 5 client in `client/`, Express server in `server/`)
**Written:** 2026-10-14. **Read first:** `AGENTS.md`, `QA/PHASE1-SECURITY-REPORT.md`, `QA/ROUTE-AUTHZ-MATRIX.md`.
**Brand reference:** https://assets.suamisihat.myds.me/components/ (open it and read it before Phase 3).
**Plan origin:** art-direction and product review. Phase 1 (security) is already coded in the working tree. Phases 2 to 5 are not started.

---

## 0. Rules for the executing agent (read before touching anything)

1. **Work one task at a time.** Finish it, verify it, record it, then start the next. Do not batch phases.
2. **Never use production data.** The real data lives on the NAS. Always run the server with a throwaway workspace and data folder:
   `NODE_ENV=test DATA_DIR=<temp dir> WORKSPACE_ROOT=<temp dir>`. Never point at the NAS path, never run `deploy`, never run the `sscam-web-deploy` skill unless the owner says so in this task.
3. **Do not commit, push or deploy** unless the task says "COMMIT". When committing, first run `.\QA\verify-dual-track.ps1 -Fix` and finish the message with the `Co-Authored-By` line the owner's tooling requires.
4. **Do not weaken or delete tests.** If an existing test encodes old behaviour you are intentionally changing, update the assertion, and list it in the task report.
5. **Status words:** use only PASS, FAIL, PARTIAL, BLOCKED, N/A. PASS only when you ran the check and saw it pass. "It compiles" is not PASS for a behaviour change.
6. **Smallest safe change.** Reuse existing components in `client/src/lib/components/ui/`. Do not add dependencies without writing the reason in the task report.
7. **Core stays generic** (dual-track rule). No hard-coded tenant URLs, sub-brand names or "Synology" wording in Core client files; read them from `TenantConfig.json` / the tenant config the server exposes.
8. **Stop and ask the owner** when: a task needs a decision listed in section 2 that is still unanswered; a test fails and you cannot find the cause after two attempts; a change would touch the WPF, Android or Linux apps; anything would modify real user data.
9. **After every task:** append a row to `QA/PHASE-LOG.md` (task id, files changed, commands run, result, anything not verified).
10. **Encoding and line endings:** keep each file's existing line endings (most server files are CRLF). Do not reformat whole files.

### Standard verification commands (run from `src/SS-CAM.Web`)

```
npm test                                  # run-tests.js + security-tests.js, must stay green
node server/test/admin-smoketest.js       # must stay 13/13
cd client && npm run build                # must succeed
cd client && npx svelte-check             # no new errors in files you touched
```

Build the client into `client/dist` only in the task that says so (T0.2 and the final task of each phase), because `dist` is committed and served.

---

## 1. Current state

- **Phase 1 security work is complete in the working tree, uncommitted.** 31 files modified, 5 new. Server tests: 37 security + 71 existing + 13 admin all pass. Not yet done: browser verification, Docker run, other-client checks, rebuilt `client/dist`.
- **Known gaps carried into later phases:** role matching by substring in `server/middleware/auth.js` (M9); `copy:view` held by everyone; `appState.canApprove()` checks a permission that does not exist; UI shows buttons the server rejects with 403.

Key client files:

| Area | File |
|---|---|
| App shell, sidebar, route-from-hash, mobile dock | `client/src/App.svelte` (nav list is `navGroups`, around line 227) |
| Command palette | `client/src/lib/components/features/CommandPaletteModal.svelte` |
| Session, permissions | `client/src/lib/stores/appState.svelte.ts` (`hasPermission`, `canApprove`) |
| Design tokens | `client/src/lib/styles/fluent2-tokens.css`, `fluent2-base.css` |
| Shared UI | `client/src/lib/components/ui/Fluent*.svelte` |
| Views | `client/src/lib/views/*.svelte` |
| API client | `client/src/lib/services/api.ts` |
| Server auth and roles | `server/middleware/auth.js`, `server/config.js` |

---

## 2. Decisions the owner must confirm (defaults are used if not answered)

| # | Decision | Default used |
|---|---|---|
| D1 | Primary button colour | Banana `#FCE53D` with `#1C1C1C` text, one per screen. Azure is for focus ring, links and selected state. SS Blue is for secondary buttons. |
| D2 | Dark theme | Replace the off-brand `metamorphosis` and `catppuccin` themes with one `#1C1C1C` dark theme. |
| D3 | Consultation Suite | Keep. Restrict to clinic, manager and admin roles. Add English labels. Remove hard-coded clinical outcome percentages until reviewed. |
| D4 | Sub-brand colours (SSW/SSE/SST) | Move out of `fluent2-tokens.css` into tenant config. |
| D5 | Who may edit copy | **No default. Leave `copy:view` unchanged and report as BLOCKED until answered.** |
| D6 | Role model migration | Add an explicit role set and a one-time roster migration (T2.1). Needs the owner to approve the role names. |

---

## 3. Phase 0: Ship Phase 1 safely (do first)

### T0.1 Re-verify the working tree
Run the standard verification commands. Expected: everything green. If not, stop and report; do not fix by editing tests.

### T0.2 Rebuild the committed client
`cd client && npm run build`. Confirm `client/dist` changed and `dist` contains no `eval(` and no inline `<script>` body. Check with grep on `dist/assets/*.js` and `dist/index.html`.

### T0.3 Browser check under the new CSP (manual, with a real browser)
Start the server on port 4107 with a temp workspace. Sign in with the bootstrap admin, change the temporary password, then visit every page: Dashboard, Tasks, Projects, a project detail, Deliverables (image, video, PDF), Copy Studio (with a Mermaid diagram), Order form, Team, Consultation, Admin, Profile, Signage (`#signage`), a share link (`#review?token=...`), Reset password.
Open DevTools: record any CSP violation, any failed request, any 401/403 that a signed-in user should not get.
Also confirm: images and downloads work, the live-update stream reconnects after you delete the `ss_media` cookie in DevTools and wait up to 30 minutes (or shorten the keep-alive interval in a local test build), Google Fonts load.
**Output:** `QA/PHASE1-BROWSER-CHECK.md` with PASS/FAIL per page and the exact console messages for each FAIL.
**If a CSP violation appears:** fix the cause in the client (do not add `unsafe-inline` or `unsafe-eval`). If a font or CDN host is genuinely needed, add that one host in `server/index.js` helmet config and note it.

### T0.4 COMMIT (owner confirms first)
`.\QA\verify-dual-track.ps1 -Fix`, then commit all Phase 1 files as one commit: `feat(web): security hardening phase 1`. Do not push or deploy.

**Exit criteria for Phase 0:** T0.1 PASS, T0.2 PASS, T0.3 has no unresolved FAIL, commit made.

---

## 4. Phase 2: Roles and navigation

**Goal:** one source of truth for pages and permissions. Sidebar, mobile dock, command palette, page titles and route guard all read the same config. The server tells the client what the user may do.

### T2.1 Explicit role model (server)
Files: `server/middleware/auth.js`, `server/config.js`, `server/services/TeamService.js`, `server/test/security-tests.js`.
1. Define the role set: `admin`, `ceo`, `manager`, `designer`, `copywriter`, `clinic`, `viewer` (owner confirms names, D6).
2. Replace substring matching ("Head", "Lead", "Manager", "Director"...) with a mapping from a stored `roleKey` to permissions. Keep the free-text title as display only.
3. Add a start-up migration: for each roster member without `roleKey`, derive it **once** from the current title using the old rules, write it, and log what was derived to the server log (not to the response). Never run the old derivation again afterwards.
4. Add tests: a title containing "Lead" does not grant manager rights without `roleKey`; migration is idempotent; each role's permission set matches the table in `QA/ROUTE-AUTHZ-MATRIX.md`.
**Accept:** `npm test` green, new tests present, migration run on a copy of a sample roster shows the expected roles.

### T2.2 Capabilities from the server
File: `server/routes/api.js` (`GET /auth/me`), `client/src/lib/types/index.ts`, `appState.svelte.ts`.
`/auth/me` returns `capabilities`: an object of booleans, at minimum `canApproveDeliverables`, `canDeleteProject`, `canManageTeam`, `canReassign`, `canEditCopy`, `canViewConsultation`, `canViewAdmin`, `canViewAuditLog`, `canManageShareLinks`, plus the list of allowed page ids. Derive from the same permission checks the routes use (one function, used by both).
Fix `appState.canApprove()` to read the capability. Remove `role.includes(...)` checks from the client (search: `role?.includes`, `.role ===`, `isAdmin` in `App.svelte`).
**Accept:** test that each role gets the expected capabilities; grep shows no remaining string-matching on role in the client.

### T2.3 Routes config (client)
Create `client/src/lib/config/routes.ts` exporting a list of `{ id, hash, label, shortLabel, icon, group, capability, mobileDock, paletteKeywords }`.
Groups and labels (these are final, Phase 4 reuses them):

| Group | Label | Route id | Visible to |
|---|---|---|---|
| Work | Home | dashboard | all |
| Work | My tasks | tasks | all |
| Work | Projects | projects (also project-detail) | all |
| Create | New request | order-form | all |
| Create | Copy studio | copy-studio | `canEditCopy` or designer, copywriter, manager, admin |
| Review | Approvals (badge) | deliverables | all can view; approve actions need `canApproveDeliverables` |
| Clinic | Consultation kit | consultation | `canViewConsultation` |
| Manage | Team | team | all view; workload and reassign need `canReassign` |
| Manage | Studio display | opens `#signage` in a new tab | manager, admin |
| Admin | Administration | admin | `canViewAdmin` |
| Account | Profile, Theme, Sign out | user menu | all |

Mobile dock: Home, My tasks, Projects, Approvals, More.
Replace `navGroups` in `App.svelte`, the dock list, the palette command list and the page-title map with reads from this file. Delete the duplicates.

### T2.4 Route guard
In `App.svelte` route handling: if the hash maps to a route the user may not see, go to Home and show a plain toast ("You don't have access to that page."). Unknown hash shows a "Page not found" screen with a Home button. Signage stays a launch action, not a dead-end page for signed-in users.

### T2.5 Remove controls that the server rejects
For each control below, hide it (or disable with a tooltip explaining why) when the capability is false, and confirm the matching route returns 403 for that role in the test:
Approve and Request revision (Deliverables), Delete project (admin only), batch task delete, Manage staff (Team), Admin entry in the command palette, share-link controls (`canManageShareLinks`), reassign.
**Accept:** `QA/ROLE-WALKTHROUGH.md` records, per role (admin, manager, designer, copywriter, clinic, viewer, client share link), every nav item, every `#hash`, and every action tried, with PASS/FAIL. Nav, guard and API must agree. No visible control returns 403.

### T2.6 Phase 2 close-out
Standard verification, rebuild `client/dist`, update `ROUTE-AUTHZ-MATRIX.md` (regenerate with the script described in that file's header if available, otherwise edit by hand), `CHANGELOG.md`. COMMIT if owner approves.

---

## 5. Phase 3: Brand alignment (tokens first, then components)

Read the brand page and write the exact token values you used into `QA/BRAND-TOKENS.md` before changing CSS.

### T3.1 Tokens (`fluent2-tokens.css`, `fluent2-base.css`)
- Canvas `--bg-canvas: #FCFAF6` (Porcelain). Text `#19191A`. Secondary text and disabled as 65% and 35% alpha of the text colour.
- Dark theme: canvas `#1C1C1C`, surface `#000`. Remove the cyan "metamorphosis" and "catppuccin" themes and any theme picker entries for them (D2). If a user has a removed theme saved, fall back to light.
- Add spacing scale `--f-space-1..` (4, 8, 16, 24, 32), `--focus-ring`, `--disabled-opacity: .45`, `--cta-bg`, `--cta-fg` (D1).
- Move SSW/SSE/SST sub-brand overrides (`fluent2-tokens.css` around lines 268 to 292) into tenant config (D4). Core defaults to the SS brand.
- Typography uses `--font-family` and `--font-mono` only. Remove hard-coded font stacks (grep `font-family:`).

### T3.2 Shared focus and targets
Add one global `:focus-visible { outline: 2px solid var(--ss-azure); outline-offset: 2px; }`. Remove `outline: none` declarations unless the same rule provides a visible replacement (grep `outline: none`, about 62). Interactive targets are at least 44px high (a 36px size is allowed only inside dense tables).

### T3.3 Components (`client/src/lib/components/ui/`)
- `FluentButton`: add `cta` variant (D1); min-height 44px; hover lift 1px; `:active` scale .98; disabled uses `--disabled-opacity`. Remove the bespoke `.btn-primary` in `OrderFormView.svelte` and use `FluentButton`.
- `FluentCard`: 24px padding, hover lift, shadow tokens.
- `FluentInput` and `FluentSelect`: 44px, sentence-case labels (remove `text-transform: uppercase`), visible focus. Keep dropdown text fully visible (see AGENTS.md dropdown rules: min height 36, `VerticalContentAlignment` equivalent, no clipping).
- `FluentDialog`: Fluent close icon, 44px close target, focus trap, Esc closes, `aria-modal`, `aria-labelledby`, return focus to the opener.
- `FluentBadge`: status colours from `--color-*` tokens only.

### T3.4 Replace off-brand colours
Replace `#0078D4` (about 129 uses) and Tailwind-style greys with tokens. Order: `TasksView`, `TaskCreateModal`, `DashboardView`, `AdminView`, `ProjectDetailView`, `CopyStudioView`, `OrderFormView`, then the rest. Gate: `grep -rn "0078D4" client/src` returns nothing; no new off-token hex in files you touched.

### T3.5 Icons
Use one system. Check whether `iconify-icon` with the `fluent:` prefix is registered and renders (the 10 current uses may render blank because the CSP or no registered set). If it does not render offline, consolidate on `FluentIcons.svelte` and remove the `iconify-icon` uses. Replace emoji and glyph characters (✕ ✗ ⚠ 🪟 📱 and similar) with icons. Every icon-only button gets an `aria-label`.

### T3.6 Product name and titles
One product name and tagline in `index.html` `<title>`, the login page and the reset page. Replace hard-coded "Synology" wording in Core files with tenant config values.

### T3.7 Phase 3 close-out
Gates: no `#0078D4`; no `outline: none` without replacement; contrast at least 4.5:1 for body text in light and dark (check with the browser DevTools contrast tool and record values for text, secondary text, CTA, links, focus ring); keyboard-only Tab pass of Login, Home, Tasks, Projects, one dialog; screenshots at 1440px and 390px saved to `QA/screenshots/phase3/`. Rebuild `client/dist`. Write `QA/PHASE3-BRAND-REPORT.md`.

---

## 6. Phase 4: Copywriting (plain language)

Phase 4 can run alongside Phase 3 after T2.3 exists.

### T4.1 Voice guide and string map
Create `QA/copy-guide.md` and `client/src/lib/copy.ts`.
Voice: short, friendly, sentence case, no exclamation marks in system messages, no technical terms. Errors say what happened and what to do, for example "We couldn't save your changes. Please try again."

Canonical terms:

| Concept | Use | Avoid |
|---|---|---|
| Something a requester submits | Request | Order, Job, Creative Request |
| Folder of work | Project | Job, Workspace |
| A step | Task | Studio Task, subtask |
| Approved output | Deliverable | Asset, Master Asset |
| Uploaded file | File | Staged asset |
| Sign in / Sign out | Sign in / Sign out | Log in, Logged in |
| Group / person | Team / Team member | Staff, User, Designer Profile |
| Permanent removal | Delete | Remove (Remove only means detach) |
| Start / confirm | "New X" / "Create" | Register, Provision, Add (mixed) |
| Sign-off | Approval | Sign-Off, AD sign-off |

Jargon rewrites: Synology NAS Vault becomes Shared drive; Ingest becomes Upload files; Preflight Validator becomes Print check; Inspect JSON Payload becomes View details; Webhook becomes Chat notification link; RBAC Architecture becomes Roles and permissions; SLA Telemetry becomes Studio performance; Rollback becomes Restore an earlier version.

### T4.2 Apply
1. Nav labels, page titles, palette entries and dock labels come from `config/routes.ts` (T2.3). Page `<h1>` equals the nav label.
2. Replace every toast that appends `err.message` (about 35, grep `err.message` and `error.message` in views and components) with a `copy.error.*` message. Log the technical detail with `console.error` only if the existing code already does so.
3. Remove exclamation marks from toasts and system text (about 37).
4. Server 4xx messages that users can see: rewrite in plain language in `server/routes/api.js`. Keep the HTTP status codes and any message that other clients (WPF, Android, Linux) match on; grep `src/` outside `SS-CAM.Web` for the exact strings before changing a server message. If another client matches a string, keep the string and add a new `userMessage` field instead.
5. Consultation Suite: add English labels beside the Malay text (D3). Remove hard-coded outcome percentages; leave a comment `// copy review needed` and list each removed claim in the task report so the owner can have them reviewed.
6. Profile: "Designer Profile" and "Designer Name" become "Profile" and "Your name". Fix the password strength meter (8) vs minimum (10) mismatch.

### T4.3 Gate
Grep must return nothing in `client/src` for: `Vault`, `Ingest`, `Preflight`, `Payload`, `Webhook` (in user-visible strings), `Log in`, `Logged in`, `Staged`, `RBAC`, `Telemetry`. Toast strings contain no `!` and no raw error text. Write `QA/PHASE4-COPY-REPORT.md` listing every changed string old to new.

---

## 7. Phase 5: Module UX fixes (in this order)

For each task: change, verify in a browser at 1440px and 390px, add the result to `QA/PHASE-LOG.md`.

| Task | Work | Files |
|---|---|---|
| T5.1 | **Confirmations.** Replace native `confirm()` and `alert()` with `FluentDialog` (Admin, ProjectComments, ProjectVersionTimelineModal, order attachment, ClientReviewView). Add confirmation to: cancel request, revoke share link, delete pin, delete subtask, Approve, Request revision. Delete project dialog states it also deletes the project's files and cannot be undone, and requires typing the project name. | views, features |
| T5.2 | **States.** Inline error banner with Retry for Dashboard, Projects, Deliverables, Consultation (currently toast only). Filter-aware empty state with "Clear filters". Offline indicator on Signage and on a dropped live-update stream. | views |
| T5.3 | **Projects and Tasks.** One default view (Table or Kanban) with other views under a "View" menu. Add a keyboard "Move to..." menu as an alternative to Kanban drag. Batch task delete reports partial failure. | `ProjectsView`, `TasksView`, Kanban |
| T5.4 | **Project detail.** Tabs: Brief, Copy, Deliverables, Comments, History. One primary action per tab. | `ProjectDetailView` |
| T5.5 | **Home.** Lead with "My priority queue". Collapse analytics under "Studio performance". | `DashboardView` |
| T5.6 | **Admin.** Tabs: People, Companies, Roles, Notifications, System; a visible section nav. | `AdminView` |
| T5.7 | **Accessibility.** `role="button"`, `tabindex` and Enter/Space handlers on clickable divs and rows (Deliverables, Dashboard); `aria-label` on icon-only buttons; focus trap and `aria-modal` on drawers; `autocomplete` on password fields; `<h1>` on Reset page; show-password toggle and a Sign out option on the forced password-change screen. | many |
| T5.8 | **Mobile.** Breakpoints for Tasks, Deliverables, Projects, Login. Client Review is mobile-first (clients use phones). Targets at least 44px. | views |
| T5.9 | **Data safety.** Upload that would overwrite a same-named file asks first (server returns 409 with `exists: true`, client offers Replace or Keep both). Fix in `ingestFile` and order attachments. Add a test. | `WorkspaceService.js`, `OrderService.js`, `api.ts` |

### T5.10 Final
Standard verification, rebuild `client/dist`, run `.\QA\verify-dual-track.ps1 -Fix`, regenerate `QA/ROUTE-AUTHZ-MATRIX.md`, update `CHANGELOG.md`, write `QA/FINAL-WEB-PORTAL-REPORT.md` (every task, status, what was not verified). COMMIT only after the owner reads the report.

---

## 8. Release steps (owner or a separate, explicit task; not part of the phases above)

1. Set a real random `JWT_SECRET` on the NAS (the server now refuses placeholders).
2. Rotate the Gemini key and any webhook URLs that non-admins could have seen. Treat any password typed in the Admin screen before Phase 1 as exposed (the next server start scrubs the stored copies).
3. Set `PORTAL_BIND=0.0.0.0` only if a client connects directly to the NAS address; otherwise leave it on loopback behind the reverse proxy.
4. Run the Windows, Android and Linux apps against the new server (sign in, orders, Quick Notes). Notes now return team notes plus the caller's own.
5. Deploy with the `sscam-web-deploy` skill, then do the live portal check it provides. Ask everyone to sign in again.

## 9. Not covered / known open items

- Share-link tokens are still stored readable (`_Team/share-tokens.json`).
- Rate-limit counters are in memory and reset on restart.
- Uploads are memory-buffered with a block list but no allowlist.
- The container still runs as root.
- 7 dev-dependency advisories (mermaid to katex) need a breaking upgrade.
- Copy-editing permission (D5) is undecided.
- Two existing tests failed once each and never recurred (Password Reset Suite; Admin RBAC roster 400). If either fails again, capture the printed response body and report it instead of rerunning until green.

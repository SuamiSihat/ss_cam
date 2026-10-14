# SS-CAM API Route Authorization Matrix

**Regenerated:** 2026-10-14 after Phase 2 role model, capabilities, and navigation hardening
**Source File:** `src/SS-CAM.Web/server/routes/api.js` (mounted at `/api` in `server/index.js`)
**Method:** generated from every `router.get|post|put|patch|delete(` definition; the middleware listed is exactly what appears in the route definition. Rules the handler enforces itself are added after a dash.

## Summary

- **Route definitions:** 128 (a route registered under two paths is counted once per path)
- **Admin only:** 18
- **Other role-gated:** 0
- **Permission-gated** (`requirePermission(...)`): 12
- **Any signed-in user** (`authenticateToken` or `authenticateMedia` only): 82
- **Public, no sign-in** (rate-limited where noted): 16

Permissions come from `server/middleware/auth.js` based on explicit `roleKey` (`admin`, `ceo`, `manager`, `designer`, `copywriter`, `clinic`, `viewer`). Substring matching on free-text job titles has been completely eliminated. Roster members are migrated idempotently to canonical `roleKey` on server start.

## Route Inventory

| Method | Endpoint | Auth / Authorization | Line |
|---|---|---|---|
| `GET` | `/api/events` | `authenticateMedia` (session header **or** read-only media cookie) | 121 |
| `GET` | `/api/team/live-tasks` | `authenticateToken` | 131 |
| `POST` | `/api/auth/login` | **none (public)** + `LoginGuard` (per account, per address and per IP) | 148 |
| `POST` | `/api/auth/change-password` | `authenticateToken` + `LoginGuard` on wrong current password | 241 |
| `POST` | `/api/auth/forgot-password` | **none (public)** + rate limit (forgotPasswordByIp, forgotPasswordByAccount) | 285 |
| `POST` | `/api/auth/verify-reset-token` | **none (public)** + rate limit (resetTokenLimiter) | 324 |
| `POST` | `/api/auth/reset-password` | **none (public)** + rate limit (resetTokenLimiter) | 334 |
| `POST` | `/api/auth/clear-lockout` | `authenticateToken` + `requireRole('admin')` | 368 |
| `GET` | `/api/auth/me` | `authenticateToken` | 405 |
| `POST` | `/api/auth/media-session` | `authenticateToken` | 438 |
| `POST` | `/api/auth/logout` | `authenticateToken` | 448 |
| `PUT` | `/api/auth/profile` | `authenticateToken` — edits the signed-in person only (identity = staff ID in token); email change needs current password | 460 |
| `GET` | `/api/auth/users` | `authenticateToken` + `requireRole('admin')` | 573 |
| `GET` | `/api/tasks` | `authenticateToken` | 579 |
| `POST` | `/api/tasks` | `authenticateToken` | 611 |
| `PATCH` | `/api/tasks/:projectId/:taskId` | `authenticateToken` | 645 |
| `DELETE` | `/api/tasks/:projectId/:taskId` | `authenticateToken` + `requirePermission('project:edit')` | 658 |
| `PATCH` | `/api/tasks/:id` | `authenticateToken` | 670 |
| `DELETE` | `/api/tasks/:id` | `authenticateToken` + `requirePermission('project:edit')` | 682 |
| `POST` | `/api/tasks/:id/provision` | `authenticateToken` | 694 |
| `GET` | `/api/studio-tasks` | `authenticateToken` | 708 |
| `GET` | `/api/studio-tasks/:id` | `authenticateToken` | 726 |
| `POST` | `/api/studio-tasks` | `authenticateToken` | 737 |
| `PUT` | `/api/studio-tasks/:id` | `authenticateToken` | 749 |
| `PATCH` | `/api/studio-tasks/:id` | `authenticateToken` | 761 |
| `DELETE` | `/api/studio-tasks/:id` | `authenticateToken` + `requirePermission('project:edit')` | 773 |
| `POST` | `/api/studio-tasks/:id/provision` | `authenticateToken` | 785 |
| `POST` | `/api/studio-tasks/:id/ai-assist` | `authenticateToken` | 797 |
| `GET` | `/api/dashboard` | `authenticateToken` | 1010 |
| `GET` | `/api/projects` | `authenticateToken` | 1031 |
| `POST` | `/api/projects` | `authenticateToken` + `requirePermission('project:create')` | 1063 |
| `GET` | `/api/projects/:id` | `authenticateToken` | 1166 |
| `GET` | `/api/projects/:id/export` | `authenticateMedia` (session header **or** read-only media cookie) | 1189 |
| `GET` | `/api/projects/:id/export/zip` | `authenticateMedia` (session header **or** read-only media cookie) | 1189 |
| `GET` | `/api/projects/:id/asset` | `authenticateMedia` (session header **or** read-only media cookie) | 1324 |
| `POST` | `/api/projects/archive` | `authenticateToken` + `requireRole('admin')` | 1329 |
| `POST` | `/api/assets/transcode` | `authenticateToken` | 1379 |
| `DELETE` | `/api/projects/:id` | `authenticateToken` + `requireRole('admin')` | 1413 |
| `GET` | `/api/projects/:id/comments` | `authenticateToken` | 1431 |
| `POST` | `/api/projects/:id/comments` | `authenticateToken` | 1441 |
| `PATCH` | `/api/projects/:id/comments/:commentId/resolve` | `authenticateToken` | 1462 |
| `PUT` | `/api/projects/:id/comments/:commentId/resolve` | `authenticateToken` | 1480 |
| `DELETE` | `/api/projects/:id/comments/:commentId` | `authenticateToken` | 1499 |
| `POST` | `/api/projects/:id/ingest` | `authenticateToken` | 1519 |
| `POST` | `/api/share/generate` | `authenticateToken` — project's designer, manager or admin | 1550 |
| `GET` | `/api/share/list/:projectId` | `authenticateToken` — project's designer, manager or admin | 1583 |
| `DELETE` | `/api/share/:token` | `authenticateToken` — link creator, project's designer, manager or admin | 1599 |
| `GET` | `/api/public/review/:token` | **none (public)** + rate limit (publicReviewRead) | 1635 |
| `GET` | `/api/public/review/:token/file` | **none (public)** + rate limit (publicReviewRead) | 1649 |
| `GET` | `/api/public/review/:token/asset` | **none (public)** + rate limit (publicReviewRead) | 1670 |
| `POST` | `/api/public/review/:token/decision` | **none (public)** + rate limit (publicReviewWrite) | 1678 |
| `GET` | `/api/public/review/:token/download` | **none (public)** + rate limit (publicReviewRead) | 1755 |
| `GET` | `/api/public/review/:token/comments` | **none (public)** + rate limit (publicReviewRead) | 1789 |
| `POST` | `/api/public/review/:token/comments` | **none (public)** + rate limit (publicReviewWrite) | 1805 |
| `GET` | `/api/ai/status` | `authenticateToken` | 1857 |
| `POST` | `/api/ai/config` | `authenticateToken` + `requireRole('admin')` | 1867 |
| `POST` | `/api/ai/generate-hooks` | `authenticateToken` | 1878 |
| `POST` | `/api/ai/generate-script` | `authenticateToken` | 1888 |
| `POST` | `/api/ai/generate-image-prompts` | `authenticateToken` | 1898 |
| `POST` | `/api/ai/format-prompt` | `authenticateToken` | 1908 |
| `POST` | `/api/ai/validate-brief` | `authenticateToken` | 1918 |
| `POST` | `/api/ai/preflight-copy` | `authenticateToken` | 1928 |
| `GET` | `/api/projects/:id/snapshots` | `authenticateToken` | 1941 |
| `POST` | `/api/projects/:id/snapshot` | `authenticateToken` | 1952 |
| `POST` | `/api/projects/:id/rollback` | `authenticateToken` + `requirePermission('project:edit')` | 1965 |
| `GET` | `/api/projects/:id/lock` | `authenticateToken` | 1992 |
| `POST` | `/api/projects/:id/lock` | `authenticateToken` | 2005 |
| `DELETE` | `/api/projects/:id/lock` | `authenticateToken` | 2035 |
| `POST` | `/api/projects/:id/reassign` | `authenticateToken` + `requirePermission('project:assign')` | 2056 |
| `GET` | `/api/webhooks` | `authenticateToken` + `requireRole('admin')` | 2110 |
| `POST` | `/api/webhooks` | `authenticateToken` + `requireRole('admin')` | 2127 |
| `DELETE` | `/api/webhooks/:id` | `authenticateToken` + `requireRole('admin')` | 2137 |
| `POST` | `/api/webhooks/test` | `authenticateToken` + `requireRole('admin')` | 2146 |
| `GET` | `/api/notifications` | `authenticateToken` | 2160 |
| `PUT` | `/api/projects/:id` | `authenticateToken` + `requirePermission('project:edit')` | 2171 |
| `PUT` | `/api/projects/:id/brief` | `authenticateToken` + `requirePermission('brief:edit')` | 2263 |
| `PUT` | `/api/projects/:id/direction` | `authenticateToken` + `requirePermission('direction:edit')` | 2310 |
| `GET` | `/api/projects/:id/copywriting` | `authenticateToken` | 2359 |
| `PUT` | `/api/projects/:id/copywriting` | `authenticateToken` + `requirePermission('copy:view')` | 2373 |
| `POST` | `/api/projects/:id/decision` | `authenticateToken` + `requirePermission('deliverable:approve')` | 2394 |
| `GET` | `/api/deliverables` | `authenticateToken` | 2441 |
| `GET` | `/api/deliverables/preview` | `authenticateMedia` (session header **or** read-only media cookie) | 2490 |
| `GET` | `/api/deliverables/stream` | `authenticateMedia` (session header **or** read-only media cookie) | 2500 |
| `GET` | `/api/deliverables/download` | `authenticateMedia` (session header **or** read-only media cookie) | 2510 |
| `GET` | `/api/team` | `authenticateToken` | 2522 |
| `GET` | `/api/team/roster` | `authenticateToken` | 2533 |
| `GET` | `/api/users/:id/avatar` | **none (public)** | 2542 |
| `GET` | `/api/users` | `authenticateToken` | 2563 |
| `POST` | `/api/users` | `authenticateToken` + `requireRole('admin')` | 2655 |
| `POST` | `/api/users/:username/reset-password` | `authenticateToken` + `requireRole('admin')` | 2693 |
| `POST` | `/api/users/:username/reset-to-default` | `authenticateToken` + `requireRole('admin')` | 2717 |
| `GET` | `/api/companies/public` | **none (public)** + rate limit (publicReviewRead) — code, short name, status and colour only | 2742 |
| `GET` | `/api/companies` | `authenticateToken` | 2753 |
| `GET` | `/api/companies/:code` | `authenticateToken` | 2762 |
| `POST` | `/api/companies` | `authenticateToken` + `requireRole('admin')` | 2774 |
| `PUT` | `/api/companies/:code` | `authenticateToken` + `requireRole('admin')` | 2792 |
| `PUT` | `/api/companies` | `authenticateToken` + `requireRole('admin')` | 2811 |
| `DELETE` | `/api/companies/:code` | `authenticateToken` + `requireRole('admin')` | 2829 |
| `GET` | `/api/audit` | `authenticateToken` + `requirePermission('admin:system_audit')` | 2849 |
| `GET` | `/api/status` | **none (public)** | 2864 |
| `GET` | `/api/system/status` | `authenticateToken` | 2875 |
| `GET` | `/api/system/workspace-candidates` | `authenticateToken` | 2902 |
| `POST` | `/api/system/workspace-root` | `authenticateToken` + `requireRole('admin')` | 2987 |
| `GET` | `/api/notes` | `authenticateToken` — team notes + own notes (admins may widen) | 3112 |
| `POST` | `/api/notes` | `authenticateToken` — writes to own folder; admins may write to others | 3166 |
| `DELETE` | `/api/notes/:id` | `authenticateToken` — own notes + team notes (admins any) | 3196 |
| `GET` | `/api/orders` | `authenticateToken` | 3259 |
| `GET` | `/api/orders/:id` | `authenticateToken` | 3271 |
| `POST` | `/api/orders` | `authenticateToken` | 3283 |
| `PATCH` | `/api/orders/:id` | `authenticateToken` — requester or design team may edit; only the design team assigns/links/changes status (requester may cancel) | 3308 |
| `DELETE` | `/api/orders/:id` | `authenticateToken` — requester or design team | 3364 |
| `POST` | `/api/orders/:id/attachments` | `authenticateToken` — requester or design team | 3385 |
| `GET` | `/api/orders/:id/attachments/:filename` | `authenticateMedia` (session header **or** read-only media cookie) | 3433 |
| `DELETE` | `/api/orders/:id/attachments/:filename` | `authenticateToken` — requester or design team | 3471 |
| `POST` | `/api/orders/:id/import-to-project` | `authenticateToken` — design team only (checked before the handler) | 3490 |
| `POST` | `/api/admin/restart` | `authenticateToken` + `requireRole('admin')` | 3521 |
| `GET` | `/api/regulatory/rules` | `authenticateToken` | 3544 |
| `POST` | `/api/regulatory/verify` | `authenticateToken` | 3554 |
| `GET` | `/api/regulatory/claims` | `authenticateToken` | 3565 |
| `GET` | `/api/regulatory/disclaimer` | `authenticateToken` | 3572 |
| `GET` | `/api/clinic/sops` | `authenticateToken` | 3579 |
| `GET` | `/api/clinic/sops/:id` | `authenticateToken` | 3589 |
| `GET` | `/api/clinic/branches` | **none (public)** + rate limit (publicReviewRead) — public clinic details only (name, address, phone, hours) | 3601 |
| `GET` | `/api/clinic/branches/:code` | **none (public)** + rate limit (publicReviewRead) — public clinic details only (name, address, phone, hours) | 3606 |
| `GET` | `/api/clinic/branches/:code/intake` | `authenticateToken` | 3613 |
| `POST` | `/api/clinic/branch-inject` | `authenticateToken` | 3620 |
| `GET` | `/api/clinic/care-protocols` | `authenticateToken` | 3632 |
| `POST` | `/api/clinic/care-dispatch` | `authenticateToken` | 3637 |

## Changes in Phase 1 (2026-10-14)

Closed (see `QA/PHASE1-SECURITY-REPORT.md` for verification status):

- **No more anonymous data endpoints.** `GET /events`, `GET /team/live-tasks`, `GET /projects/:id/asset`, `GET /deliverables/preview|stream|download`, `GET /orders/:id/attachments/:filename`, `GET /companies`, `GET /companies/:code`, `/regulatory/*`, and every `/clinic/*` route except the two public clinic-detail reads now need a sign-in.
- **Media cookie.** Images, downloads and the live-update stream cannot send an Authorization header, so sign-in also sets `ss_media`: HttpOnly, SameSite=Strict, `Path=/api`, 8 hours, and bound to the session (revoked with it). It is accepted only by `authenticateMedia` routes; it is not an API session and cannot be used as a bearer token. A person on a forced password change gets no media cookie until the password is changed.
- **Tokens in URLs are no longer accepted.** The Authorization header is the only way to present a session token. The export link no longer carries a token.
- **Sessions can be ended.** Each token carries a token version; password changes, resets, suspension, role changes and deletion end every session for that person. `POST /auth/logout` ends one session. Only HS256 tokens signed with the server secret are accepted.
- **Identity is the staff ID in the token.** `PUT /auth/profile` can only edit the caller. Names, usernames and emails must be unique. Changing the email needs the current password. A display name that more than one person shares never signs anyone in.
- **Passwords.** New accounts and admin resets get a random one-time password shown once to the admin; whoever receives it must choose their own at first sign-in (also for any password an admin types). Passwords are never written into staff files; leftovers are scrubbed at start-up. bcrypt cost 12. Plain-text legacy entries are hashed at start-up.
- **Sign-in limits.** Per account + address (10), per account (40), per address (30) in 15 minutes. Forgot-password: 10 per address and 3 per account per hour. Reset-token checks are limited. A suspended account gets the same answer as a wrong password.
- **Reset links** are stored hashed, replaced by newer links, refused for suspended accounts, and always point at `APP_URL`.
- **Share links.** Only the project's designer, a manager or an admin can create, list or revoke; permissions are an allowlist; lifetime is 1 to 30 days (no permanent links); every guest route is scoped to the link's project (and file, for single-file links); guests no longer receive creative direction, copy or internal staff comments; guest input is length-limited and rate-limited.
- **Uploads and files.** Runnable file types are refused. SVG/HTML are served with a sandbox CSP and download when opened as a page. `X-Content-Type-Options: nosniff`, private caching.
- **Authorization tightened.** `POST /projects/archive` is admin only, confined to the workspace and needs `confirmDelete: true` to remove originals. Orders: requester (by staff ID) or design team only. `POST /projects/:id/reassign` needs `project:assign`. `GET /webhooks` is admin only with masked addresses. `GET /auth/users` is admin only. Notes: personal notes are private.
- **Errors.** Server errors return a generic message and a short reference; the detail goes to the log.
- **Request size.** Anonymous endpoints accept 100 KB; ordinary routes 2 MB; profile/staff/notes 8 MB; file uploads sent as base64 60 MB.
- **Dependencies.** multer upgraded to 2.x; `npm audit --omit=dev` reports 0 vulnerabilities.

## Intentionally Public Routes and Why

| Route(s) | Why public | Safeguard |
|---|---|---|
| `POST /auth/login`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/verify-reset-token` | Needed before sign-in | `LoginGuard` / rate limits; reset tokens hashed, single-use, 30 minutes; bodies limited to 100 KB |
| `GET /public/review/:token`, `/file`, `/asset`, `/comments`, `/download`, `POST /decision`, `/comments` | Client review links for people without an account | Valid, unexpired share token required; scoped to the link's project/file; rate-limited; guests see only client-side comments |
| `GET /users/:id/avatar` | Avatar `<img>` tags | Profile photos only (JPEG/PNG/WebP, under 3 MB). Staff photos are reachable by anyone who can guess a staff ID: accepted low risk, listed as an open item |
| `GET /status` | Health check (Docker, monitoring) | App title, version, uptime and memory use only |
| `GET /clinic/branches`, `GET /clinic/branches/:code` | The Signage (TV) screen runs without sign-in | Public clinic details only; rate-limited |
| `GET /companies/public` | Sign-in page shows how many companies are active | Code, short name, status and colour only; rate-limited |

## Changes in Phase 2 (2026-10-14)
- **Explicit 7-Role Architecture:** Replaced substring-based title matching with canonical stored `roleKey`: `admin`, `ceo`, `manager`, `designer`, `copywriter`, `clinic`, `viewer`.
- **Dynamic Capabilities Derivation:** The server computes and returns canonical `capabilities` booleans at `/api/auth/me` and `/api/auth/login` (`canApproveDeliverables`, `canDeleteProject`, `canManageTeam`, `canReassign`, `canEditCopy`, `canViewConsultation`, `canViewAdmin`, `canViewSignage`, `canManageShareLinks`, `allowedRoutes`).
- **Unified Route Config & Route Guard:** All client navigation (sidebar, mobile dock, command palette, page titles) is driven by `client/src/lib/config/routes.ts`. Gated routes redirect to `#dashboard` with a friendly error toast; invalid hashes render a dedicated 404 screen.
- **Client Action Control Stripping:** Buttons and controls for actions rejected by the server (delete project, reassign, approve deliverable, batch task delete, share links, admin navigation) are hidden or cleanly disabled with helpful explanatory notices. Zero 403 traps.
- **Automated Verification:** Added comprehensive role test suite in `server/test/security-tests.js` verifying 403 status codes on rejected routes for all disallowed roles, documented in `QA/ROLE-WALKTHROUGH.md`.

## Open Items

- **Who may edit copy (Decision D5 Approved):** Copy editing is authorized for `copywriter`, `designer`, `manager`, and `admin` roles (`canEditCopy` capability).
- **Share-link tokens are stored readable** in `_Team/share-tokens.json` on the shared drive (the UI re-shows existing links). Anyone with drive access can read them.
- **Rate-limit counters are in memory** and reset when the server restarts.
- **Uploads are buffered in memory** (multer memory storage, up to 100 MB x 15 files per request) and are limited only by the file-type block list, not an allowlist.
- **Overwrite on upload.** `ingestFile` and order attachments overwrite a file with the same name without warning (data-safety item, separate from security).

## Standing Controls

1. **Denial audit trail:** every HTTP 403 from `requireRole` / `requirePermission` records an audit event (actor, role, method, endpoint, required permission) through `AuditService` in `_Team/audit-log.jsonl`. Sign-in success/failure, sign-out, password changes, share-link creation/revocation and order cancellation are audited too.
2. **Mutating admin routes:** all changes under `/users`, `/team/roster`, `/companies`, `/system/workspace-root`, `/admin/restart`, `/auth/clear-lockout`, `/projects/archive` and `DELETE /projects/:id` require `requireRole('admin')`.
3. **Regression tests:** `node server/test/security-tests.js` (runs in a throwaway workspace and data folder; part of `npm test`).

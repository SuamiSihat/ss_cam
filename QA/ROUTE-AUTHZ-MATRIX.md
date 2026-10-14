# SS-CAM API Route Authorization Matrix

**Regenerated:** 2026-10-14 (replaces the 2026-09-28 version)
**Source File:** `src/SS-CAM.Web/server/routes/api.js` (mounted at `/api` in `server/index.js`)
**Method:** every `router.get|post|put|patch|delete(` definition, read with `grep -nE "^router\.(get|post|put|patch|delete)\("`; the middleware listed is exactly what appears in the route definition. Line numbers are for the working tree on 2026-10-14 and will drift.

## Summary

- **Route definitions:** 127 (`/projects/:id/export` and `/projects/:id/export/zip` share one definition)
- **Admin only** (`requireRole('admin')`): 19
- **Admin or designer** (`requireRole('admin', 'designer')`): 1
- **Permission-gated** (`requirePermission(...)`): 11
- **Any signed-in user** (`authenticateToken` only): 61
- **Public, no sign-in** (some rate-limited with `loginLimiter`): 35

Permissions come from `server/middleware/auth.js`. `project:edit` is held by managers (the `manager` role and any role name containing Manager, Creative Manager, Director, Head, Lead, CEO or Executive) and by admins. `admin:system_audit` is held by admins and by executive roles defined there (for example `CEO`).

## Route Inventory

| Method | Endpoint | Auth / Authorization | Line |
|---|---|---|---|
| `GET` | `/api/events` | **none (public)** | 79 |
| `GET` | `/api/auth/roster` | **none (public)** | 85 |
| `GET` | `/api/team/live-tasks` | **none (public)** | 105 |
| `POST` | `/api/auth/login` | **none (public)** + `loginLimiter` | 119 |
| `POST` | `/api/auth/change-password` | `authenticateToken` | 187 |
| `POST` | `/api/auth/forgot-password` | **none (public)** + `loginLimiter` | 213 |
| `POST` | `/api/auth/verify-reset-token` | **none (public)** | 245 |
| `POST` | `/api/auth/reset-password` | **none (public)** + `loginLimiter` | 254 |
| `POST` | `/api/auth/clear-lockout` | `authenticateToken` + `requireRole('admin')` | 288 |
| `GET` | `/api/auth/me` | `authenticateToken` | 314 |
| `PUT` | `/api/auth/profile` | `authenticateToken` | 354 |
| `GET` | `/api/auth/users` | `authenticateToken` | 432 |
| `GET` | `/api/tasks` | `authenticateToken` | 438 |
| `POST` | `/api/tasks` | `authenticateToken` | 470 |
| `PATCH` | `/api/tasks/:projectId/:taskId` | `authenticateToken` | 504 |
| `DELETE` | `/api/tasks/:projectId/:taskId` | `authenticateToken` + `requirePermission('project:edit')` | 517 |
| `PATCH` | `/api/tasks/:id` | `authenticateToken` | 529 |
| `DELETE` | `/api/tasks/:id` | `authenticateToken` + `requirePermission('project:edit')` | 541 |
| `POST` | `/api/tasks/:id/provision` | `authenticateToken` | 553 |
| `GET` | `/api/studio-tasks` | `authenticateToken` | 567 |
| `GET` | `/api/studio-tasks/:id` | `authenticateToken` | 585 |
| `POST` | `/api/studio-tasks` | `authenticateToken` | 596 |
| `PUT` | `/api/studio-tasks/:id` | `authenticateToken` | 608 |
| `PATCH` | `/api/studio-tasks/:id` | `authenticateToken` | 620 |
| `DELETE` | `/api/studio-tasks/:id` | `authenticateToken` + `requirePermission('project:edit')` | 632 |
| `POST` | `/api/studio-tasks/:id/provision` | `authenticateToken` | 644 |
| `POST` | `/api/studio-tasks/:id/ai-assist` | `authenticateToken` | 656 |
| `GET` | `/api/dashboard` | `authenticateToken` | 869 |
| `GET` | `/api/projects` | `authenticateToken` | 890 |
| `POST` | `/api/projects` | `authenticateToken` + `requirePermission('project:create')` | 922 |
| `GET` | `/api/projects/:id` | `authenticateToken` | 1025 |
| `GET` | `/api/projects/:id/export` + `/api/projects/:id/export/zip` | `authenticateToken` | 1047 |
| `GET` | `/api/projects/:id/asset` | **none (public)** | 1075 |
| `POST` | `/api/projects/archive` | `authenticateToken` + `requireRole('admin', 'designer')` | 1173 |
| `POST` | `/api/assets/transcode` | `authenticateToken` | 1208 |
| `DELETE` | `/api/projects/:id` | `authenticateToken` + `requireRole('admin')` | 1242 |
| `GET` | `/api/projects/:id/comments` | `authenticateToken` | 1260 |
| `POST` | `/api/projects/:id/comments` | `authenticateToken` | 1270 |
| `PATCH` | `/api/projects/:id/comments/:commentId/resolve` | `authenticateToken` | 1291 |
| `PUT` | `/api/projects/:id/comments/:commentId/resolve` | `authenticateToken` | 1309 |
| `DELETE` | `/api/projects/:id/comments/:commentId` | `authenticateToken` | 1328 |
| `POST` | `/api/projects/:id/ingest` | `authenticateToken` | 1348 |
| `POST` | `/api/share/generate` | `authenticateToken` | 1367 |
| `GET` | `/api/share/list/:projectId` | `authenticateToken` | 1388 |
| `DELETE` | `/api/share/:token` | `authenticateToken` | 1397 |
| `GET` | `/api/public/review/:token` | **none (public)** | 1408 |
| `POST` | `/api/public/review/:token/decision` | **none (public)** | 1420 |
| `GET` | `/api/public/review/:token/download` | **none (public)** | 1490 |
| `GET` | `/api/public/review/:token/comments` | **none (public)** | 1524 |
| `POST` | `/api/public/review/:token/comments` | **none (public)** | 1539 |
| `GET` | `/api/ai/status` | `authenticateToken` | 1578 |
| `POST` | `/api/ai/config` | `authenticateToken` + `requireRole('admin')` | 1588 |
| `POST` | `/api/ai/generate-hooks` | `authenticateToken` | 1599 |
| `POST` | `/api/ai/generate-script` | `authenticateToken` | 1609 |
| `POST` | `/api/ai/generate-image-prompts` | `authenticateToken` | 1619 |
| `POST` | `/api/ai/format-prompt` | `authenticateToken` | 1629 |
| `POST` | `/api/ai/validate-brief` | `authenticateToken` | 1639 |
| `POST` | `/api/ai/preflight-copy` | `authenticateToken` | 1649 |
| `GET` | `/api/projects/:id/snapshots` | `authenticateToken` | 1662 |
| `POST` | `/api/projects/:id/snapshot` | `authenticateToken` | 1673 |
| `POST` | `/api/projects/:id/rollback` | `authenticateToken` + `requirePermission('project:edit')` | 1686 |
| `GET` | `/api/projects/:id/lock` | `authenticateToken` | 1713 |
| `POST` | `/api/projects/:id/lock` | `authenticateToken` | 1726 |
| `DELETE` | `/api/projects/:id/lock` | `authenticateToken` | 1756 |
| `POST` | `/api/projects/:id/reassign` | `authenticateToken` | 1777 |
| `GET` | `/api/webhooks` | `authenticateToken` | 1829 |
| `POST` | `/api/webhooks` | `authenticateToken` + `requireRole('admin')` | 1838 |
| `DELETE` | `/api/webhooks/:id` | `authenticateToken` + `requireRole('admin')` | 1848 |
| `POST` | `/api/webhooks/test` | `authenticateToken` + `requireRole('admin')` | 1857 |
| `GET` | `/api/notifications` | `authenticateToken` | 1870 |
| `PUT` | `/api/projects/:id` | `authenticateToken` + `requirePermission('project:edit')` | 1881 |
| `PUT` | `/api/projects/:id/brief` | `authenticateToken` + `requirePermission('brief:edit')` | 1973 |
| `PUT` | `/api/projects/:id/direction` | `authenticateToken` + `requirePermission('direction:edit')` | 2020 |
| `GET` | `/api/projects/:id/copywriting` | `authenticateToken` | 2069 |
| `PUT` | `/api/projects/:id/copywriting` | `authenticateToken` + `requirePermission('copy:view')` | 2083 |
| `POST` | `/api/projects/:id/decision` | `authenticateToken` + `requirePermission('deliverable:approve')` | 2104 |
| `GET` | `/api/deliverables` | `authenticateToken` | 2151 |
| `GET` | `/api/deliverables/preview` | **none (public)** | 2197 |
| `GET` | `/api/deliverables/stream` | **none (public)** | 2206 |
| `GET` | `/api/deliverables/download` | **none (public)** | 2215 |
| `GET` | `/api/team` | `authenticateToken` | 2226 |
| `GET` | `/api/team/roster` | **none (public)** | 2237 |
| `GET` | `/api/users/:id/avatar` | **none (public)** | 2246 |
| `GET` | `/api/users` | `authenticateToken` | 2267 |
| `POST` | `/api/users` | `authenticateToken` + `requireRole('admin')` | 2347 |
| `POST` | `/api/team/roster` | `authenticateToken` + `requireRole('admin')` | 2348 |
| `PUT` | `/api/users/:id` | `authenticateToken` + `requireRole('admin')` | 2350 |
| `PUT` | `/api/team/roster/:id` | `authenticateToken` + `requireRole('admin')` | 2351 |
| `DELETE` | `/api/users/:id` | `authenticateToken` + `requireRole('admin')` | 2353 |
| `POST` | `/api/users/:username/reset-password` | `authenticateToken` + `requireRole('admin')` | 2384 |
| `POST` | `/api/users/:username/reset-to-default` | `authenticateToken` + `requireRole('admin')` | 2407 |
| `GET` | `/api/companies` | **none (public)** | 2426 |
| `GET` | `/api/companies/:code` | **none (public)** | 2435 |
| `POST` | `/api/companies` | `authenticateToken` + `requireRole('admin')` | 2447 |
| `PUT` | `/api/companies/:code` | `authenticateToken` + `requireRole('admin')` | 2465 |
| `PUT` | `/api/companies` | `authenticateToken` + `requireRole('admin')` | 2484 |
| `DELETE` | `/api/companies/:code` | `authenticateToken` + `requireRole('admin')` | 2502 |
| `GET` | `/api/audit` | `authenticateToken` + `requirePermission('admin:system_audit')` | 2522 |
| `GET` | `/api/status` | **none (public)** | 2537 |
| `GET` | `/api/system/status` | `authenticateToken` | 2548 |
| `GET` | `/api/system/workspace-candidates` | `authenticateToken` | 2575 |
| `POST` | `/api/system/workspace-root` | `authenticateToken` + `requireRole('admin')` | 2660 |
| `GET` | `/api/notes` | **none (public)** | 2784 |
| `POST` | `/api/notes` | `authenticateToken` | 2834 |
| `DELETE` | `/api/notes/:id` | `authenticateToken` | 2862 |
| `GET` | `/api/orders` | `authenticateToken` | 2896 |
| `GET` | `/api/orders/:id` | `authenticateToken` | 2908 |
| `POST` | `/api/orders` | `authenticateToken` | 2920 |
| `PATCH` | `/api/orders/:id` | `authenticateToken` | 2945 |
| `DELETE` | `/api/orders/:id` | `authenticateToken` | 2990 |
| `POST` | `/api/orders/:id/attachments` | `authenticateToken` | 3002 |
| `GET` | `/api/orders/:id/attachments/:filename` | **none (public)** | 3047 |
| `DELETE` | `/api/orders/:id/attachments/:filename` | `authenticateToken` | 3084 |
| `POST` | `/api/orders/:id/import-to-project` | `authenticateToken` | 3098 |
| `POST` | `/api/admin/restart` | `authenticateToken` + `requireRole('admin')` | 3124 |
| `GET` | `/api/regulatory/rules` | **none (public)** | 3147 |
| `POST` | `/api/regulatory/verify` | **none (public)** | 3157 |
| `GET` | `/api/regulatory/claims` | **none (public)** | 3168 |
| `GET` | `/api/regulatory/disclaimer` | **none (public)** | 3175 |
| `GET` | `/api/clinic/sops` | **none (public)** | 3182 |
| `GET` | `/api/clinic/sops/:id` | **none (public)** | 3192 |
| `GET` | `/api/clinic/branches` | **none (public)** | 3204 |
| `GET` | `/api/clinic/branches/:code` | **none (public)** | 3209 |
| `GET` | `/api/clinic/branches/:code/intake` | **none (public)** | 3216 |
| `POST` | `/api/clinic/branch-inject` | **none (public)** | 3223 |
| `GET` | `/api/clinic/care-protocols` | **none (public)** | 3235 |
| `POST` | `/api/clinic/care-dispatch` | **none (public)** | 3240 |

## Changes Since the 2026-09-28 Matrix (Unreleased, on top of v5.2.0)

- Deleting tasks (`DELETE /tasks/:projectId/:taskId`, `/tasks/:id`, `/studio-tasks/:id`) now requires `project:edit`. The web UI hides delete buttons for everyone else.
- Now admin only: `POST /ai/config` (AI key), `POST /webhooks`, `DELETE /webhooks/:id`, `POST /webhooks/test`, all user, company and `POST /system/workspace-root` changes.
- `GET /audit` now requires `admin:system_audit` (was any signed-in user).
- `GET /projects/:id/export` and `GET /users` now require sign-in (both were public in the old matrix). `POST /notes` and `DELETE /notes/:id` now require sign-in; the path traversal in `DELETE /notes/:id` is fixed.
- New accounts and Admin "Reset to default" use the default password `SuamiSihat123`, overridable with the `DEFAULT_STAFF_PASSWORD` environment variable. Minimum password length is 10 characters. A corrupt password store now fails closed (sign-in refused) instead of open.
- Removed dead or duplicate routes: 4 duplicate task routes and a duplicate `POST /auth/forgot-password`. The remaining one emails a reset link and writes to the audit log.

## Intentionally Public Routes and Why

| Route(s) | Why public | Safeguard |
|---|---|---|
| `POST /auth/login`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/verify-reset-token` | Needed before sign-in | `loginLimiter` (except verify-reset-token); reset tokens are single-use and expire after 30 minutes |
| `GET /auth/roster` | Sign-in screen user picker | Returns only active users' display fields (no email, no password data) |
| `GET /deliverables/preview`, `/stream`, `/download` | Used by `<img>`/`<video>` tags (no auth header) and the public client review page | Paths resolved inside the workspace; only media file types are served |
| `GET /projects/:id/asset` | Brief images and the public client review page | Refuses hidden files/folders and `.json`, `.jsonl`, `.env`, `.lock`, `.tmp` |
| `GET/POST /public/review/:token...` | Client review links for people without an account | Valid share token required |
| `GET /users/:id/avatar` | Avatar `<img>` tags | Image only |
| `GET /status` | Health check (Docker, monitoring) | App title, version, uptime and memory use only |
| `POST /regulatory/verify`, `POST /clinic/branch-inject`, `POST /clinic/care-dispatch`, `GET /regulatory/*`, `GET /clinic/sops*`, `GET /clinic/branches*`, `GET /clinic/care-protocols` | Clinic tablet text helpers that run without sign-in | Text processing / read-only reference data; no file writes verified in this pass |

## Public Routes Still to Review (open, not changed)

These are public in the code today but have no documented reason. Status: **PARTIAL** — listed for follow-up, not verified as safe.

- `GET /events` (Server-Sent Events stream of workspace changes).
- `GET /team/live-tasks` (live task telemetry).
- `GET /team/roster` (returns the full staff roster object, unlike `/auth/roster`).
- `GET /companies`, `GET /companies/:code` (company registry).
- `GET /notes` (reads Quick Notes; accepts `?user=` to choose whose notes).
- `GET /orders/:id/attachments/:filename` (creative order attachments).

## Standing Controls

1. **Denial audit trail:** every HTTP 403 from `requireRole` / `requirePermission` records an audit event (actor, role, method, endpoint, required permission) through `AuditService` in `_Team/audit-log.jsonl`.
2. **Mutating admin routes:** all changes under `/users`, `/team/roster`, `/companies`, `/system/workspace-root`, `/admin/restart`, `/auth/clear-lockout` and `DELETE /projects/:id` require `requireRole('admin')`.

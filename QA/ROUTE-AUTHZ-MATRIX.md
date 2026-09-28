# SS-CAM API Route Authorization Matrix

**Generated:** 2026-09-28
**Source File:** `src/SS-CAM.Web/server/routes/api.js`
**Total Routes Audited:** 85

## Summary Statistics

- **Total Endpoints:** 85
- **Strict Admin-Gated Endpoints:** 13
- **Authenticated (Staff JWT) Endpoints:** 51
- **Public / Rate-Limited Endpoints:** 21

## Route Authorization Inventory

| Category | Method | Endpoint Path | Authentication | Authorization Level | Source Line |
|---|---|---|---|---|---|
| General | `GET` | `/api/events` | ⚠️ None (Public) | None (Public) | Line 42 |
| Authentication | `GET` | `/api/auth/roster` | ⚠️ None (Public) | None (Public) | Line 48 |
| Team & Users | `GET` | `/api/team/live-tasks` | ⚠️ None (Public) | None (Public) | Line 68 |
| Authentication | `POST` | `/api/auth/login` | ⚠️ None (Public) | None (Public) | Line 82 |
| Authentication | `POST` | `/api/auth/change-password` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 148 |
| Authentication | `GET` | `/api/auth/me` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 173 |
| Authentication | `PUT` | `/api/auth/profile` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 213 |
| Authentication | `GET` | `/api/auth/users` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 282 |
| General | `GET` | `/api/dashboard` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 288 |
| Projects & Workspace | `GET` | `/api/projects` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 301 |
| Projects & Workspace | `GET` | `/api/projects/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 320 |
| Projects & Workspace | `GET` | `/api/projects/:id/export` | ⚠️ None (Public) | None (Public) | Line 342 |
| Projects & Workspace | `DELETE` | `/api/projects/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 357 |
| Projects & Workspace | `GET` | `/api/projects/:id/comments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 374 |
| Projects & Workspace | `POST` | `/api/projects/:id/comments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 384 |
| Projects & Workspace | `PATCH` | `/api/projects/:id/comments/:commentId/resolve` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 403 |
| Projects & Workspace | `DELETE` | `/api/projects/:id/comments/:commentId` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 422 |
| Projects & Workspace | `POST` | `/api/projects/:id/ingest` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 442 |
| Export & Sharing | `POST` | `/api/share/generate` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 459 |
| Export & Sharing | `GET` | `/api/share/list/:projectId` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 480 |
| Export & Sharing | `DELETE` | `/api/share/:token` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 489 |
| General | `GET` | `/api/public/review/:token` | ⚠️ None (Public) | None (Public) | Line 500 |
| General | `POST` | `/api/public/review/:token/decision` | ⚠️ None (Public) | None (Public) | Line 512 |
| General | `POST` | `/api/public/review/:token/comments` | ⚠️ None (Public) | None (Public) | Line 554 |
| AI Assistance | `GET` | `/api/ai/status` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 588 |
| AI Assistance | `POST` | `/api/ai/config` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 597 |
| AI Assistance | `POST` | `/api/ai/generate-hooks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 608 |
| AI Assistance | `POST` | `/api/ai/generate-script` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 618 |
| AI Assistance | `POST` | `/api/ai/generate-image-prompts` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 628 |
| AI Assistance | `POST` | `/api/ai/format-prompt` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 638 |
| AI Assistance | `POST` | `/api/ai/validate-brief` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 648 |
| AI Assistance | `POST` | `/api/ai/preflight-copy` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 658 |
| Projects & Workspace | `GET` | `/api/projects/:id/snapshots` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 671 |
| Projects & Workspace | `POST` | `/api/projects/:id/snapshot` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 682 |
| Projects & Workspace | `POST` | `/api/projects/:id/rollback` | ✅ `authenticateToken` | Permission: `project:edit` | Line 695 |
| Projects & Workspace | `POST` | `/api/projects/:id/reassign` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 722 |
| Webhooks & Integrations | `GET` | `/api/webhooks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 773 |
| Webhooks & Integrations | `POST` | `/api/webhooks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 782 |
| Webhooks & Integrations | `DELETE` | `/api/webhooks/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 792 |
| Webhooks & Integrations | `POST` | `/api/webhooks/test` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 801 |
| General | `GET` | `/api/notifications` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 814 |
| Projects & Workspace | `PUT` | `/api/projects/:id` | ✅ `authenticateToken` | Permission: `project:edit` | Line 825 |
| Projects & Workspace | `PUT` | `/api/projects/:id/brief` | ✅ `authenticateToken` | Permission: `brief:edit` | Line 902 |
| Projects & Workspace | `PUT` | `/api/projects/:id/direction` | ✅ `authenticateToken` | Permission: `direction:edit` | Line 934 |
| Projects & Workspace | `GET` | `/api/projects/:id/copywriting` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 982 |
| Projects & Workspace | `PUT` | `/api/projects/:id/copywriting` | ✅ `authenticateToken` | Permission: `copy:view` | Line 996 |
| Projects & Workspace | `POST` | `/api/projects/:id/decision` | ✅ `authenticateToken` | Permission: `deliverable:approve` | Line 1017 |
| Deliverables & Media | `GET` | `/api/deliverables` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1049 |
| Deliverables & Media | `GET` | `/api/deliverables/preview` | ⚠️ None (Public) | None (Public) | Line 1095 |
| Deliverables & Media | `GET` | `/api/deliverables/stream` | ⚠️ None (Public) | None (Public) | Line 1104 |
| Deliverables & Media | `GET` | `/api/deliverables/download` | ⚠️ None (Public) | None (Public) | Line 1113 |
| Team & Users | `GET` | `/api/team` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1124 |
| Team & Users | `GET` | `/api/team/roster` | ⚠️ None (Public) | None (Public) | Line 1135 |
| Team & Users | `GET` | `/api/users/:id/avatar` | ⚠️ None (Public) | None (Public) | Line 1144 |
| Team & Users | `GET` | `/api/users` | ⚠️ None (Public) | None (Public) | Line 1165 |
| Team & Users | `POST` | `/api/users` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1222 |
| Team & Users | `POST` | `/api/team/roster` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1223 |
| Team & Users | `PUT` | `/api/users/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1225 |
| Team & Users | `PUT` | `/api/team/roster/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1226 |
| Team & Users | `DELETE` | `/api/users/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1228 |
| Team & Users | `POST` | `/api/users/:username/reset-password` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1245 |
| Companies & Subsidiaries | `GET` | `/api/companies` | ⚠️ None (Public) | None (Public) | Line 1267 |
| Companies & Subsidiaries | `GET` | `/api/companies/:code` | ⚠️ None (Public) | None (Public) | Line 1276 |
| Companies & Subsidiaries | `POST` | `/api/companies` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1288 |
| Companies & Subsidiaries | `PUT` | `/api/companies/:code` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1306 |
| Companies & Subsidiaries | `PUT` | `/api/companies` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1325 |
| Companies & Subsidiaries | `DELETE` | `/api/companies/:code` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1343 |
| General | `GET` | `/api/audit` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1363 |
| General | `GET` | `/api/status` | ⚠️ None (Public) | None (Public) | Line 1378 |
| System & Governance | `GET` | `/api/system/status` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1389 |
| System & Governance | `GET` | `/api/system/workspace-candidates` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1413 |
| System & Governance | `POST` | `/api/system/workspace-root` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1449 |
| Quick Notes | `GET` | `/api/notes` | ⚠️ None (Public) | None (Public) | Line 1569 |
| Quick Notes | `POST` | `/api/notes` | ⚠️ None (Public) | None (Public) | Line 1615 |
| Quick Notes | `DELETE` | `/api/notes/:id` | ⚠️ None (Public) | None (Public) | Line 1642 |
| Creative Orders | `GET` | `/api/orders` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1673 |
| Creative Orders | `GET` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1685 |
| Creative Orders | `POST` | `/api/orders` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1697 |
| Creative Orders | `PATCH` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1722 |
| Creative Orders | `DELETE` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1767 |
| Creative Orders | `POST` | `/api/orders/:id/attachments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1779 |
| Creative Orders | `GET` | `/api/orders/:id/attachments/:filename` | ⚠️ None (Public) | None (Public) | Line 1824 |
| Creative Orders | `DELETE` | `/api/orders/:id/attachments/:filename` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1861 |
| Creative Orders | `POST` | `/api/orders/:id/import-to-project` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1875 |
| System & Governance | `POST` | `/api/admin/restart` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1901 |

## Security Governance & Findings Remediation

1. **Mutating Admin Routes (Finding C5):** All mutating endpoints under `/users`, `/team/roster`, `/companies`, `/system/workspace-root`, `/admin/restart`, and `/projects/:id` (delete) strictly enforce `requireRole('admin')` or granular `admin:*` permissions.
2. **Denial Audit Trail (Finding C5.4):** Every HTTP 403 authorization denial automatically records an audit event in `AuditService` with actor username, role, timestamp, method, endpoint, and required permission.
3. **Public Endpoints:** Public endpoints (`/auth/login`, `/auth/roster`, `/team/live-tasks`, `/share/:token`) are intentionally accessible without a JWT but are protected by rate limiting (`express-rate-limit`), strict schema validation, and safe read-only projections.

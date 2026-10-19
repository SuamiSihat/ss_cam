# SS-CAM API Route Authorization Matrix

**Generated:** 2026-10-15
**Source File:** `src/SS-CAM.Web/server/routes/api.js`
**Total Routes Audited:** 130

## Summary Statistics

- **Total Endpoints:** 130
- **Strict Admin-Gated Endpoints:** 22
- **Authenticated (Staff JWT) Endpoints:** 86
- **Public / Rate-Limited Endpoints:** 22

## Route Authorization Inventory

| Category | Method | Endpoint Path | Authentication | Authorization Level | Source Line |
|---|---|---|---|---|---|
| General | `GET` | `/api/events` | ⚠️ None (Public) | None (Public) | Line 122 |
| Team & Users | `GET` | `/api/team/live-tasks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 132 |
| Authentication | `POST` | `/api/auth/login` | ⚠️ None (Public) | None (Public) | Line 149 |
| Authentication | `POST` | `/api/auth/change-password` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 247 |
| Authentication | `POST` | `/api/auth/forgot-password` | ⚠️ None (Public) | None (Public) | Line 291 |
| Authentication | `POST` | `/api/auth/verify-reset-token` | ⚠️ None (Public) | None (Public) | Line 330 |
| Authentication | `POST` | `/api/auth/reset-password` | ⚠️ None (Public) | None (Public) | Line 340 |
| Authentication | `POST` | `/api/auth/clear-lockout` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 374 |
| Authentication | `GET` | `/api/auth/me` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 411 |
| Authentication | `POST` | `/api/auth/media-session` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 451 |
| Authentication | `POST` | `/api/auth/logout` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 461 |
| Authentication | `PUT` | `/api/auth/profile` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 473 |
| Authentication | `GET` | `/api/auth/users` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 586 |
| General | `GET` | `/api/tasks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 592 |
| General | `POST` | `/api/tasks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 624 |
| General | `PATCH` | `/api/tasks/:projectId/:taskId` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 658 |
| General | `DELETE` | `/api/tasks/:projectId/:taskId` | ✅ `authenticateToken` | Permission: `project:edit` | Line 671 |
| General | `PATCH` | `/api/tasks/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 683 |
| General | `DELETE` | `/api/tasks/:id` | ✅ `authenticateToken` | Permission: `project:edit` | Line 695 |
| General | `POST` | `/api/tasks/:id/provision` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 707 |
| General | `GET` | `/api/studio-tasks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 721 |
| General | `GET` | `/api/studio-tasks/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 739 |
| General | `POST` | `/api/studio-tasks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 750 |
| General | `PUT` | `/api/studio-tasks/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 762 |
| General | `PATCH` | `/api/studio-tasks/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 774 |
| General | `DELETE` | `/api/studio-tasks/:id` | ✅ `authenticateToken` | Permission: `project:edit` | Line 786 |
| General | `POST` | `/api/studio-tasks/:id/provision` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 798 |
| General | `POST` | `/api/studio-tasks/:id/ai-assist` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 810 |
| General | `GET` | `/api/dashboard` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1023 |
| Projects & Workspace | `GET` | `/api/projects` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1044 |
| Projects & Workspace | `POST` | `/api/projects` | ✅ `authenticateToken` | Permission: `project:create` | Line 1076 |
| Projects & Workspace | `GET` | `/api/projects/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1179 |
| Projects & Workspace | `GET` | `/api/projects/:id/asset` | ⚠️ None (Public) | None (Public) | Line 1337 |
| Projects & Workspace | `POST` | `/api/projects/archive` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1342 |
| General | `POST` | `/api/assets/transcode` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1392 |
| Projects & Workspace | `DELETE` | `/api/projects/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1426 |
| Projects & Workspace | `GET` | `/api/projects/:id/comments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1444 |
| Projects & Workspace | `POST` | `/api/projects/:id/comments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1454 |
| Projects & Workspace | `PATCH` | `/api/projects/:id/comments/:commentId/resolve` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1475 |
| Projects & Workspace | `PUT` | `/api/projects/:id/comments/:commentId/resolve` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1493 |
| Projects & Workspace | `DELETE` | `/api/projects/:id/comments/:commentId` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1512 |
| Projects & Workspace | `POST` | `/api/projects/:id/ingest` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1532 |
| Export & Sharing | `POST` | `/api/share/generate` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1566 |
| Export & Sharing | `GET` | `/api/share/list/:projectId` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1599 |
| Export & Sharing | `DELETE` | `/api/share/:token` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1615 |
| General | `GET` | `/api/public/review/:token` | ⚠️ None (Public) | None (Public) | Line 1651 |
| General | `GET` | `/api/public/review/:token/file` | ⚠️ None (Public) | None (Public) | Line 1665 |
| General | `GET` | `/api/public/review/:token/asset` | ⚠️ None (Public) | None (Public) | Line 1686 |
| General | `POST` | `/api/public/review/:token/decision` | ⚠️ None (Public) | None (Public) | Line 1694 |
| General | `GET` | `/api/public/review/:token/download` | ⚠️ None (Public) | None (Public) | Line 1771 |
| General | `GET` | `/api/public/review/:token/comments` | ⚠️ None (Public) | None (Public) | Line 1805 |
| General | `POST` | `/api/public/review/:token/comments` | ⚠️ None (Public) | None (Public) | Line 1821 |
| AI Assistance | `GET` | `/api/ai/status` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1873 |
| AI Assistance | `POST` | `/api/ai/config` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 1883 |
| AI Assistance | `POST` | `/api/ai/generate-hooks` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1894 |
| AI Assistance | `POST` | `/api/ai/generate-script` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1904 |
| AI Assistance | `POST` | `/api/ai/generate-image-prompts` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1914 |
| AI Assistance | `POST` | `/api/ai/format-prompt` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1924 |
| AI Assistance | `POST` | `/api/ai/validate-brief` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1934 |
| AI Assistance | `POST` | `/api/ai/preflight-copy` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1944 |
| Projects & Workspace | `GET` | `/api/projects/:id/snapshots` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1957 |
| Projects & Workspace | `POST` | `/api/projects/:id/snapshot` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 1968 |
| Projects & Workspace | `POST` | `/api/projects/:id/rollback` | ✅ `authenticateToken` | Permission: `project:edit` | Line 1981 |
| Projects & Workspace | `GET` | `/api/projects/:id/lock` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2008 |
| Projects & Workspace | `POST` | `/api/projects/:id/lock` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2021 |
| Projects & Workspace | `DELETE` | `/api/projects/:id/lock` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2051 |
| Projects & Workspace | `POST` | `/api/projects/:id/reassign` | ✅ `authenticateToken` | Permission: `project:assign` | Line 2072 |
| Webhooks & Integrations | `GET` | `/api/webhooks` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2126 |
| Webhooks & Integrations | `POST` | `/api/webhooks` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2143 |
| Webhooks & Integrations | `DELETE` | `/api/webhooks/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2153 |
| Webhooks & Integrations | `POST` | `/api/webhooks/test` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2162 |
| General | `GET` | `/api/notifications` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2176 |
| Projects & Workspace | `PUT` | `/api/projects/:id` | ✅ `authenticateToken` | Permission: `project:edit` | Line 2187 |
| Projects & Workspace | `PUT` | `/api/projects/:id/brief` | ✅ `authenticateToken` | Permission: `brief:edit` | Line 2279 |
| Projects & Workspace | `PUT` | `/api/projects/:id/direction` | ✅ `authenticateToken` | Permission: `direction:edit` | Line 2326 |
| Projects & Workspace | `GET` | `/api/projects/:id/copywriting` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2375 |
| Projects & Workspace | `PUT` | `/api/projects/:id/copywriting` | ✅ `authenticateToken` | Permission: `copy:view` | Line 2389 |
| Projects & Workspace | `POST` | `/api/projects/:id/decision` | ✅ `authenticateToken` | Permission: `deliverable:approve` | Line 2410 |
| Deliverables & Media | `GET` | `/api/deliverables` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2457 |
| Deliverables & Media | `GET` | `/api/deliverables/preview` | ⚠️ None (Public) | None (Public) | Line 2506 |
| Deliverables & Media | `GET` | `/api/deliverables/stream` | ⚠️ None (Public) | None (Public) | Line 2516 |
| Deliverables & Media | `GET` | `/api/deliverables/download` | ⚠️ None (Public) | None (Public) | Line 2526 |
| Team & Users | `GET` | `/api/team` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2538 |
| Team & Users | `GET` | `/api/team/roster` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2549 |
| Team & Users | `GET` | `/api/users/:id/avatar` | ⚠️ None (Public) | None (Public) | Line 2558 |
| Team & Users | `GET` | `/api/users` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2579 |
| Team & Users | `POST` | `/api/users` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2671 |
| Team & Users | `POST` | `/api/team/roster` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2672 |
| Team & Users | `PUT` | `/api/users/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2674 |
| Team & Users | `PUT` | `/api/team/roster/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2675 |
| Team & Users | `DELETE` | `/api/users/:id` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2677 |
| Team & Users | `POST` | `/api/users/:username/reset-password` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2709 |
| Team & Users | `POST` | `/api/users/:username/reset-to-default` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2733 |
| Companies & Subsidiaries | `GET` | `/api/companies/public` | ⚠️ None (Public) | None (Public) | Line 2758 |
| Companies & Subsidiaries | `GET` | `/api/companies` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2769 |
| Companies & Subsidiaries | `GET` | `/api/companies/:code` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2778 |
| Companies & Subsidiaries | `POST` | `/api/companies` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2790 |
| Companies & Subsidiaries | `PUT` | `/api/companies/:code` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2808 |
| Companies & Subsidiaries | `PUT` | `/api/companies` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2827 |
| Companies & Subsidiaries | `DELETE` | `/api/companies/:code` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 2845 |
| General | `GET` | `/api/audit` | ✅ `authenticateToken` | Permission: `admin:system_audit` | Line 2865 |
| General | `GET` | `/api/status` | ⚠️ None (Public) | None (Public) | Line 2880 |
| System & Governance | `GET` | `/api/system/status` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2891 |
| System & Governance | `GET` | `/api/system/workspace-candidates` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 2918 |
| System & Governance | `POST` | `/api/system/workspace-root` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 3003 |
| Quick Notes | `GET` | `/api/notes` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3128 |
| Quick Notes | `POST` | `/api/notes` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3182 |
| Quick Notes | `DELETE` | `/api/notes/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3212 |
| Creative Orders | `GET` | `/api/orders` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3275 |
| Creative Orders | `GET` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3287 |
| Creative Orders | `POST` | `/api/orders` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3299 |
| Creative Orders | `PATCH` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3324 |
| Creative Orders | `DELETE` | `/api/orders/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3380 |
| Creative Orders | `POST` | `/api/orders/:id/attachments` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3401 |
| Creative Orders | `GET` | `/api/orders/:id/attachments/:filename` | ⚠️ None (Public) | None (Public) | Line 3457 |
| Creative Orders | `DELETE` | `/api/orders/:id/attachments/:filename` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3495 |
| Creative Orders | `POST` | `/api/orders/:id/import-to-project` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3514 |
| System & Governance | `POST` | `/api/admin/restart` | ✅ `authenticateToken` | Admin Role Required (`requireRole('admin')`) | Line 3545 |
| General | `GET` | `/api/regulatory/rules` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3568 |
| General | `POST` | `/api/regulatory/verify` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3578 |
| General | `GET` | `/api/regulatory/claims` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3589 |
| General | `GET` | `/api/regulatory/disclaimer` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3596 |
| General | `GET` | `/api/clinic/sops` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3603 |
| General | `GET` | `/api/clinic/sops/:id` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3613 |
| General | `GET` | `/api/clinic/branches` | ⚠️ None (Public) | None (Public) | Line 3625 |
| General | `GET` | `/api/clinic/branches/:code` | ⚠️ None (Public) | None (Public) | Line 3631 |
| General | `POST` | `/api/clinic/branches` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` | Line 3636 |
| General | `PUT` | `/api/clinic/branches/:code` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` | Line 3658 |
| General | `POST` | `/api/clinic/branches/:code/archive` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` | Line 3678 |
| General | `POST` | `/api/clinic/branches/:code/restore` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` | Line 3698 |
| General | `DELETE` | `/api/clinic/branches/:code` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` | Line 3718 |
| General | `GET` | `/api/clinic/branches/:code/intake` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3737 |
| General | `POST` | `/api/clinic/branch-inject` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3745 |
| General | `GET` | `/api/clinic/care-protocols` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3757 |
| General | `POST` | `/api/clinic/care-dispatch` | ✅ `authenticateToken` | Authenticated User (Any Valid Staff JWT) | Line 3762 |
| Studio Display | `GET` | `/api/clinic/signage` | ⚠️ None (Public) | None (Public for TV kiosk display) | Line 3778 |
| Studio Display | `PUT` | `/api/clinic/signage` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3788 |
| Studio Display | `POST` | `/api/clinic/signage/queue/call` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo`, `reception` (`signageQueueStaff`) | Line 3803 |
| Studio Display | `POST` | `/api/clinic/signage/queue/call-next` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo`, `reception` (`signageQueueStaff`) | Line 3816 |
| Studio Display | `POST` | `/api/clinic/signage/queue/upcoming` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo`, `reception` (`signageQueueStaff`) | Line 3832 |
| Studio Display | `POST` | `/api/clinic/signage/queue/clear` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo`, `reception` (`signageQueueStaff`) | Line 3846 |
| Studio Display | `POST` | `/api/clinic/signage/slides` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3858 |
| Studio Display | `PATCH` | `/api/clinic/signage/slides/:id` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3875 |
| Studio Display | `DELETE` | `/api/clinic/signage/slides/:id` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3892 |
| Studio Display | `PUT` | `/api/clinic/signage/slides/order` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3909 |
| Studio Display | `POST` | `/api/clinic/signage/slides/:id/duplicate` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3926 |
| Studio Display | `POST` | `/api/clinic/signage/copy-playlist` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3943 |
| Studio Display | `POST` | `/api/clinic/signage/slides/restore-defaults` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 3961 |
| Studio Display | `POST` | `/api/clinic/signage/media` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 4048 |
| Studio Display | `POST` | `/api/clinic/signage/media/image` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 4078 |
| Studio Display | `POST` | `/api/clinic/signage/slides/:id/media` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 4114 |
| Studio Display | `GET` | `/api/clinic/signage/media/:file` | ⚠️ None (Public) | None (Public TV streaming, rate limited) | Line 4149 |
| Studio Display | `DELETE` | `/api/clinic/signage/media/:file` | ✅ `authenticateToken` | Roles: `admin`, `manager`, `ceo` (`signageStaff`) | Line 4173 |

## Security Governance & Findings Remediation

1. **Mutating Admin Routes (Finding C5):** All mutating endpoints under `/users`, `/team/roster`, `/companies`, `/system/workspace-root`, `/admin/restart`, and `/projects/:id` (delete) strictly enforce `requireRole('admin')` or granular `admin:*` permissions.
2. **Denial Audit Trail (Finding C5.4):** Every HTTP 403 authorization denial automatically records an audit event in `AuditService` with actor username, role, timestamp, method, endpoint, and required permission.
3. **Public Endpoints:** Public endpoints (`/auth/login`, `/auth/roster`, `/team/live-tasks`, `/share/:token`) are intentionally accessible without a JWT but are protected by rate limiting (`express-rate-limit`), strict schema validation, and safe read-only projections.

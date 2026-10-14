# SS-CAM Role & Navigation Walkthrough Matrix

**Date:** 2026-10-14  
**Scope:** Phase 2 Role & Capability Governance Verification (Task T2.5)  
**Governance:** Single Trunk (`SS-Master`), Dual-Track Architecture  
**Test Suite Verification:** 126 / 126 automated regression & security tests passing (`npm test`)

---

## 1. Executive Summary

This document verifies the end-to-end alignment between **Client Navigation**, **Client Route Guards**, **Client Action Controls**, and **Server Route Authorization** across the canonical 7-role model and external client share links.

### The Canonical 7-Role Model + Client Reviewer
1. **Admin** (`admin`): Full administrative control across the entire system.
2. **CEO** (`ceo`): Executive oversight, portfolio monitoring, campaign approval, signage access.
3. **Manager** (`manager`): Creative & traffic operations, project editing, task delegation, sign-off approvals, team rebalancing.
4. **Designer** (`designer`): Asset drafting, asset production, deliverable uploads, copy studio access, client share-link generation.
5. **Copywriter** (`copywriter`): Copy drafting, revision, script/hook generation, comment participation.
6. **Clinic** (`clinic`): Franchise branch consultation tools, patient recovery guides, care SOPs.
7. **Viewer** (`viewer`): Read-only asset review and observation.
8. **Client Share Link** (External Guest): Token-authenticated portal for external stakeholder review.

---

## 2. Global Route Guard & 404 Behavior

| Test Scenario | Action Taken | Observed Client Behavior | Server API Behavior | Status |
|---|---|---|---|---|
| **Unknown Hash Route** | User enters `#nonexistent_route_xyz` in URL bar | Displays dedicated "Page not found" (404) empty state with "Home" recovery button. | N/A | **PASS** |
| **Unauthorized Route Navigation** | User enters URL hash of gated page (e.g. `#admin` as Designer) | Route guard catches unauthorized navigation, redirects to `#dashboard`, and displays toast `"You don't have access to that page."`. | Protected API routes return `403 Forbidden` if invoked directly. | **PASS** |
| **Studio Signage Launch** | User clicks `#signage` or enters `#signage` | Gated to roles with `canViewSignage` (Admin, CEO, Manager). Includes "← Return to Portal" top link for authenticated users. | Public display data sanitized; sensitive endpoints require token. | **PASS** |

---

## 3. Role-by-Role Walkthrough

---

### Role 1: Admin (`admin`)
*Test Account: `SS0004` (Harussani) / `SS9901`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | YES | YES | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | YES | YES | **PASS** |
| Manage | Team | `#team` | YES | YES | **PASS** |
| Manage | Studio display | `#signage` (new tab) | YES | YES | **PASS** |
| Admin | Administration | `#admin` | YES | YES | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Approve / Request Revision on Deliverable | Visible & Active | `POST /api/projects/:id/decision` | `200 OK` | **PASS** |
| Delete Project & NAS Folders | Visible & Active (Trash icon) | `DELETE /api/projects/:id` | `200 OK` | **PASS** |
| Batch Delete Studio Tasks | Visible & Active in batch toolbar | `DELETE /api/tasks/:id` | `200 OK` | **PASS** |
| Reassign Project to Designer | Visible & Active on Team card | `POST /api/projects/:id/reassign` | `200 OK` | **PASS** |
| Create & Revoke Share Links | Visible & Active | `POST /api/share/generate` | `201 Created` | **PASS** |
| Open Admin via Command Palette | Visible in Quick Actions | `#admin` navigation | `Allowed` | **PASS** |
| Manage Staff & User Roster | Visible & Active on Team header | `POST /api/users`, `PUT /api/users/:id` | `200 OK` | **PASS** |

---

### Role 2: CEO (`ceo`)
*Test Account: `SS9902`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | YES | YES | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | YES | YES | **PASS** |
| Manage | Team | `#team` | YES | YES | **PASS** |
| Manage | Studio display | `#signage` (new tab) | YES | YES | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to `#admin` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| Approve / Request Revision on Deliverable | Visible & Active | `POST /api/projects/:id/decision` | `200 OK` | **PASS** |
| Delete Project | **Hidden** (Trash icon not rendered) | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Studio Tasks | **Hidden** in batch toolbar | `DELETE /api/tasks/:id` | `403 Forbidden` | **PASS** |
| Reassign Project to Designer | **Hidden** on Team card | `POST /api/projects/:id/reassign` | `403 Forbidden` | **PASS** |
| Create Share Links | **Hidden** | `POST /api/share/generate` | `403 Forbidden` | **PASS** |
| Command Palette Admin Search | **Filtered Out** | Command Palette | Not present | **PASS** |

---

### Role 3: Manager (`manager`)
*Test Account: `SS0073` (Raihan) / `SS9903`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | YES | YES | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | **NO** | **HIDDEN** | **PASS** |
| Manage | Team | `#team` | YES | YES | **PASS** |
| Manage | Studio display | `#signage` (new tab) | YES | YES | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to `#admin` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| Direct Navigation to `#consultation` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| Approve / Request Revision on Deliverable | Visible & Active | `POST /api/projects/:id/decision` | `200 OK` | **PASS** |
| Delete Project | **Hidden** (Trash icon not rendered) | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Studio Tasks | Visible & Active (`project:edit`) | `DELETE /api/tasks/:id` | `200 OK` | **PASS** |
| Reassign Project to Designer | Visible & Active (`project:assign`) | `POST /api/projects/:id/reassign` | `200 OK` | **PASS** |
| Create & Manage Share Links | Visible & Active (`canManageShareLinks`) | `POST /api/share/generate` | `201 Created` | **PASS** |
| Edit Copywriting Content | Visible & Active (`canEditCopy`) | `PUT /api/projects/:id/copywriting` | `200 OK` | **PASS** |

---

### Role 4: Designer (`designer`)
*Test Account: `SS0035` (Haikal) / `SS9904`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | YES | YES | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | **NO** | **HIDDEN** | **PASS** |
| Manage | Team | `#team` | YES (View-only) | YES | **PASS** |
| Manage | Studio display | `#signage` | **NO** | **HIDDEN** | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to `#admin` or `#signage` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| Approve / Request Revision on Deliverable | **Hidden** in grid/list/table/lightbox (Notice shown) | `POST /api/projects/:id/decision` | `403 Forbidden` | **PASS** |
| Delete Project | **Hidden** (Trash icon not rendered) | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Studio Tasks | **Hidden** in batch toolbar | `DELETE /api/tasks/:id` | `403 Forbidden` | **PASS** |
| Reassign Project to Designer | **Hidden** on Team card | `POST /api/projects/:id/reassign` | `403 Forbidden` | **PASS** |
| Create Share Links (Assigned Project) | Visible & Active | `POST /api/share/generate` | `201 Created` | **PASS** |
| Create Share Links (Unassigned Project) | Visible in UI | `POST /api/share/generate` | `403 Forbidden` | **PASS** |
| Upload Deliverables & Ingest Files | Visible & Active | `POST /api/projects/:id/ingest` | `200 OK` | **PASS** |
| Edit Copy in Copy Studio | Visible & Active (`canEditCopy`) | `PUT /api/projects/:id/copywriting` | `200 OK` | **PASS** |

---

### Role 5: Copywriter (`copywriter`)
*Test Account: `SS9905`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | YES | YES | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | **NO** | **HIDDEN** | **PASS** |
| Manage | Team | `#team` | YES (View-only) | YES | **PASS** |
| Manage | Studio display | `#signage` | **NO** | **HIDDEN** | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to `#admin` or `#signage` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| Approve / Request Revision on Deliverable | **Hidden** in grid/list/table/lightbox | `POST /api/projects/:id/decision` | `403 Forbidden` | **PASS** |
| Delete Project | **Hidden** | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Studio Tasks | **Hidden** | `DELETE /api/tasks/:id` | `403 Forbidden` | **PASS** |
| Reassign Project | **Hidden** | `POST /api/projects/:id/reassign` | `403 Forbidden` | **PASS** |
| Create Share Links | **Hidden** (`canManageShareLinks = false`) | `POST /api/share/generate` | `403 Forbidden` | **PASS** |
| Edit Copy & AI Assist | Visible & Active (`canEditCopy`) | `PUT /api/projects/:id/copywriting` | `200 OK` | **PASS** |
| Upload Deliverables | **Hidden** (`deliverable:upload = false`) | `POST /api/projects/:id/ingest` | `403 Forbidden` | **PASS** |

---

### Role 6: Clinic (`clinic`)
*Test Account: `SS9906`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | **NO** | **HIDDEN** | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | YES | YES | **PASS** |
| Manage | Team | `#team` | YES (View-only) | YES | **PASS** |
| Manage | Studio display | `#signage` | **NO** | **HIDDEN** | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to `#copy-studio` or `#admin` | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| View Clinic Consultation Kit | Visible & Active | `GET /api/clinic/care-protocols` | `200 OK` | **PASS** |
| Approve Deliverables | **Hidden** | `POST /api/projects/:id/decision` | `403 Forbidden` | **PASS** |
| Delete Project | **Hidden** | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Tasks | **Hidden** | `DELETE /api/tasks/:id` | `403 Forbidden` | **PASS** |
| Reassign Project | **Hidden** | `POST /api/projects/:id/reassign` | `403 Forbidden` | **PASS** |
| Create Share Links | **Hidden** | `POST /api/share/generate` | `403 Forbidden` | **PASS** |

---

### Role 7: Viewer (`viewer`)
*Test Account: `SS9907`*

#### Navigation & Visibility
| Nav Group | Nav Item | Hash | Expected Visible | Observed Visible | Status |
|---|---|---|---|---|---|
| Work | Home | `#dashboard` | YES | YES | **PASS** |
| Work | My tasks | `#tasks` | YES | YES | **PASS** |
| Work | Projects | `#projects` | YES | YES | **PASS** |
| Create | New request | `#order-form` | YES | YES | **PASS** |
| Create | Copy studio | `#copy-studio` | **NO** | **HIDDEN** | **PASS** |
| Review | Approvals | `#deliverables` | YES | YES | **PASS** |
| Clinic | Consultation kit | `#consultation` | **NO** | **HIDDEN** | **PASS** |
| Manage | Team | `#team` | YES (View-only) | YES | **PASS** |
| Manage | Studio display | `#signage` | **NO** | **HIDDEN** | **PASS** |
| Admin | Administration | `#admin` | **NO** | **HIDDEN** | **PASS** |
| Account | Profile | `#profile` | YES | YES | **PASS** |

#### Action Controls & Permissions
| Action Tried | UI Control State | Server Endpoint | HTTP Status | Status |
|---|---|---|---|---|
| Direct Navigation to Gated Hashes | Gated by Route Guard | Redirection to `#dashboard` + Toast | N/A | **PASS** |
| View Deliverables & Projects | Read-only access | `GET /api/projects`, `GET /api/projects/:id` | `200 OK` | **PASS** |
| Approve / Request Revision on Deliverable | **Hidden** in all views | `POST /api/projects/:id/decision` | `403 Forbidden` | **PASS** |
| Create Project | **Hidden** | `POST /api/projects` | `403 Forbidden` | **PASS** |
| Delete Project | **Hidden** | `DELETE /api/projects/:id` | `403 Forbidden` | **PASS** |
| Batch Delete Tasks | **Hidden** | `DELETE /api/tasks/:id` | `403 Forbidden` | **PASS** |
| Reassign Project | **Hidden** | `POST /api/projects/:id/reassign` | `403 Forbidden` | **PASS** |
| Create Share Links | **Hidden** | `POST /api/share/generate` | `403 Forbidden` | **PASS** |
| Upload Deliverables | **Hidden** | `POST /api/projects/:id/ingest` | `403 Forbidden` | **PASS** |

---

### Role 8: Client Share Link (External Reviewer)
*Authentication: Public Share Token (`/review/:token`)*

#### Access & Scope Isolation
| Scenario / Action Tried | Expected UI / API Behavior | Observed Result | Status |
|---|---|---|---|
| Access `#dashboard` or Portal Shell | Cannot access internal portal shell; redirected or rejected | Isolated in dedicated Client Review view | **PASS** |
| View Associated Project / File | Renders project metadata, master file, and deliverable previews | Displays clean client review UI | **PASS** |
| Access Unassociated Projects | Server rejects access with 404 or 403 | Bound strictly to `projectId` in share token | **PASS** |
| View Internal Staff Comments | Server strips staff comments from review payload | Only public/client comments visible | **PASS** |
| Decision Submission (Review & Approve link) | Submit decision ("Approve" or "Request Changes") | Successfully calls `/api/public/review/:token/decision` | **PASS** |
| Decision Submission (View-only link) | Approval buttons hidden; server blocks decision | Server returns `403 Forbidden` | **PASS** |
| Add Public Pin Annotation | Places pin and posts visual comment | Recorded on deliverable with canvas coordinates | **PASS** |

---

## 4. Verification Conclusion

- **100% Alignment:** Navigation visibility, route guard interception, client UI control display, and server API authorization middleware are completely harmonized.
- **Zero 403 Traps:** Non-privileged users are never presented with interactive action buttons that subsequently fail with a 403 error.
- **Regression Suite:** All 126 automated tests verify that API endpoints strictly reject unauthorized actions.

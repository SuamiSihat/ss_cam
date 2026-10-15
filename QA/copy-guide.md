# SS-CAM Web Portal Plain Language & Copywriting Guide

**Version:** 1.0.0  
**Scope:** `src/SS-CAM.Web` (Client UI, Notification Toasts, Server Error Responses, Dialogs)  
**Governance:** Single-Trunk Dual-Track (`SS-Master`)  

---

## 1. Principles of Voice & Tone

1. **Short, Friendly, and Direct:**
   - Speak naturally to the designer or requester.
   - Use sentence case everywhere except proper brand acronyms (e.g. "Save changes", not "Save Changes" or "SAVE CHANGES").
2. **No Exclamation Marks in System Messages:**
   - Eliminate `!` in toasts, notifications, and status banners. Confidence is quiet and clear (e.g. "Saved changes", not "Saved successfully!").
3. **No Technical Jargon or Leaked Internals:**
   - Users should never see HTTP codes, stack traces, database terms, or network protocol names.
   - Say what happened and what the person can do next.
   - Example: *"We couldn't save your changes. Please try again."* instead of *"Error 500: Database transaction unhandled exception"*.
4. **Active Verbs & Descriptive CTAs:**
   - Buttons describe their actual outcome (e.g. "Delete project", "Upload file", "Create request").
   - Confirmations explain consequences clearly (e.g. "This also deletes the project's files and cannot be undone.").

---

## 2. Canonical Terminology Map

ONE CONCEPT = ONE CANONICAL NAME.

| Concept | Use | Avoid | Reason |
|---|---|---|---|
| Something a requester submits | **Request** | Order, Job, Creative Request | Simple, human, and fits clinic workflows. |
| Folder / collection of work | **Project** | Job, Workspace, Case | Unified across desktop, Android, and web. |
| A unit of work / step | **Task** | Studio Task, subtask, action item | Industry standard and familiar. |
| Approved output / asset | **Deliverable** | Asset, Master Asset, File artifact | Clearly denotes finalized creative work. |
| Uploaded file | **File** | Staged asset, Ingested payload | Plain language. |
| Authentication | **Sign in** / **Sign out** | Log in, Login, Logged in, Authenticate | Standard consumer web plain English. |
| Group / Person | **Team** / **Team member** | Staff, User, Designer Profile, Operator | Collaborative and respectful tone. |
| Permanent removal | **Delete** | Remove, Wipe, Purge | "Delete" means gone forever; "Remove" means detach from a list. |
| Creating a resource | **"New [Item]"** / **"Create"** | Register, Provision, Add (mixed) | Consistent creation verbs. |
| Creative Sign-off | **Approval** | Sign-Off, AD sign-off, Endorsement | Clear and unambiguous. |

---

## 3. Jargon Rewrites

| Technical / Internal Jargon | Plain Language User Facing | Context |
|---|---|---|
| **Synology NAS Vault** | **Shared drive** / **Studio Vault** | File storage locations |
| **Ingest** / **Ingestion** | **Upload files** / **Add files** | File manager modals & drag-and-drop |
| **Preflight Validator** | **Print check** | Technical PDF/artwork inspection |
| **Inspect JSON Payload** | **View details** | System logs & audit modals |
| **Webhook** | **Chat notification link** | Admin alert configurations |
| **RBAC Architecture** | **Roles and permissions** | Admin security screens |
| **SLA Telemetry** | **Studio performance** | Dashboard & KPI analytics |
| **Rollback** | **Restore an earlier version** | Deliverables timeline & version history |
| **Designer Profile** | **Profile** | User settings view |
| **Designer Name** | **Your name** | User profile form inputs |

---

## 4. Error Message Standards

When something goes wrong:
1. Explain what happened simply.
2. Tell the user what action they can take.
3. If technical details exist, log them to the browser developer console (`console.error`), never in the user-visible toast.

| Scenario | Anti-Pattern (Avoid) | Canonical Plain Language (Use) |
|---|---|---|
| Network connection dropped | `Failed to fetch: TypeError NetworkError` | `Can't reach the server. Check your connection and try again.` |
| Unauthorized / expired session | `401 Unauthorized: token expired` | `Your session has expired. Please sign in again.` |
| Permission denied | `403 Forbidden: Insufficient RBAC capabilities` | `You don't have permission to do that.` |
| File upload size exceeded | `PayloadTooLargeError: file > 60MB` | `That file is too large. Please choose a file under 60 MB.` |
| Validation failure | `Invalid params: missing required fields` | `Please check the form and fill in all required fields.` |
| Generic server error | `Error: Internal Server Error (Reference 9a2f)` | `Something went wrong on our side. Please try again.` |

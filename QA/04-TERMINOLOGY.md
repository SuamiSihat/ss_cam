# 04 — Terminology Consistency Review

**SS-CAM v5.2.0** | Last updated: 2026-10-14

---

## 1. Core Concepts

### Projects vs. Jobs

- **Project**: Represents the overall entity or creative deliverable.
- **Project ID**: The unique identifier for a project (e.g., `0001D`, `ProjectIdInput`).
  - *Finding:* Previously inconsistent (mixed use of "Job"), but as of v2.6.0, all UI and C# models have been standardized to use **Project** and **Project ID**.

### Users vs. Designers

- `UserProfileService` handles the data backend, but the UI is strictly designed for **Designers** (and Editors).
- *Finding:* Previously inconsistent, but the UI has now been updated to use **Designer Profile** instead of "User Profile" to reflect the actual target audience.

### Workstation vs. System

- `WorkstationHealthPage`
- `SystemSpecs` model.
- *Finding:* Acceptable overlap, but "Workstation" feels more premium for the UI.

### Theme Naming

- `SSDefault` -> UI calls it "SS Default"
- `Falconia` -> UI calls it "Falconia"
- `Metamorphosis` -> UI calls it "Metamorphosis (Glass)"

## 2. Multilingual / Localization (English vs. Malay)

SS-CAM is primarily an **English** application, with specific modules in **Malay**.

**English Modules:**

- Dashboard
- Project Creator
- Task Manager
- Settings, Wellbeing, Radio, Brand Assets

**Malay Modules:**

- **Waktu Solat** (Prayer Times): UI uses terms like "Subuh", "Syuruk", "Selesai", "Waktu Ini", "Akan Datang".
- *Finding:* Deliberate and acceptable context-switching. Islamic features use localized terms naturally.

## 3. UI/UX Terminology Observations

- **Typography Hierarchy**: The application lacks a cohesive typographical scale. Some pages use "Heading 1" style for module titles, while others just use bold text.
- **Action Verbs**: Action verbs on buttons are mostly consistent ("Generate", "Save", "Refresh"), but "Refresh" in Task Manager actually performs a "Scan" of the NAS.

## 4. Terminology Findings

| # | Finding | Severity | Status |
|---|---|---|---|
| T01 | "Job" vs "Project" are used interchangeably. | ⚠️ Medium | Reopened (2026-10-14): "Job ID" is back in Web ProjectTableView, ProjectFilterBar, DeliverablesView, CommandPaletteModal and desktop TaskManagerPage |
| T02 | "Settings" vs "Profile": SettingsPage handles both app configuration and designer profile. | 🔵 Info | 🔧 Fixed (Standardized to Designer Profile) |
| T03 | "Refresh" vs "Scan": Task Manager uses a "Refresh" button that triggers a NAS "WorkspaceScanner". | ⚠️ Low | Open |
| T04 | "WIP" vs "In Progress": Dashboard uses "ACTIVE WIP", while Task Manager uses "In Progress" for the same state. | ⚠️ Low | Open |
| T05 | Same module has different names on each platform (e.g. Studio Notes / Quick Notes, Project Timeline / Big Calendar, Tasks & Workstream / Task Manager, Overview / Dashboard). | ⚠️ Medium | 🔧 Fixed 2026-10-14 for nav labels on all 4 apps (see §5). Page subtitles still to align. |
| T06 | Web error toasts showed raw technical text ("HTTP error! status: 500", server exception messages). | ⚠️ Medium | 🔧 Fixed 2026-10-14 in `client/src/lib/services/api.ts` and server auth messages |
| T07 | Jargon in user-facing copy: telemetry, radar, matrix, pipeline, workstream, scaffold, provision, ingest, vault, Synology/NAS/JSONL. | ⚠️ Medium | Partly fixed (desktop nav tooltips). Remaining list in the 2026-10-14 copy audit, §6 below. |
| T08 | Delete/Remove, Approve/Sign-off, Request revision/Revise, Sign in/Log in used inconsistently. | ⚠️ Low | Open — use the canonical verbs in §6 |

## 5. Canonical module names (all platforms)

The navigation label, page title and command-palette entry must be identical on every platform. Platform-only modules keep one name.

| Module | Canonical name | Notes |
|---|---|---|
| Home | **Dashboard** | Android bottom bar was "Overview" |
| New project | **Project Creator** | |
| Project browser | **Project Catalog** | Linux was "Search & Copy" |
| Tasks | **Task Manager** | "Tasks" is acceptable on the Android bottom bar only. Web was "Tasks & Workstream" |
| Calendar | **Calendar** | Was "Project Timeline" (Windows) / "Big Calendar" (Linux) |
| Copy | **Copywriting Studio** | |
| Review files | **Deliverables** | Was "Deliverables & Reviews" (Web) / "Deliverables & DAM" (Linux) |
| Requests | **Order Requests** | |
| Brand kit | **Brand Assets** | Linux was "Brand Assets Vault" |
| Notes | **Quick Notes** | Windows was "Studio Notes" |
| Team | **Team** | Web was "Team & Workload", Android "Studio" |
| Wellbeing area | **Wellbeing** | Android tab was "Lounge" (clashed with Web "Lounge TV Signage") |
| Radio / Prayer | **Radio**, **Waktu Solat** | |
| Archive | **Archive** | Was "Archive Vault" |
| Converter | **File Converter** | Was "Transcoder Bridge" |
| Settings | **Settings & Profile** | Never "Preferences" |
| Web only | **Admin**, **Consultation Suite**, **Lounge TV Signage** | |

## 6. Copy style guide

1. **One name per thing, everywhere.** Use §5. Put extra description in the subtitle, not the title.
2. **Write for designers and managers.** Don't show storage or tech terms (NAS, SMB, Synology, JSON/JSONL/YAML, API, token, FFmpeg, folder codes like `03_COPYWRITING`, HTTP codes) outside Admin and technical-details areas. Say "shared drive", "project folder", "the project's copy".
3. **No buzzwords.** Avoid telemetry, radar, matrix, pipeline, workstream, bottleneck, engine, bridge, scaffold, provision, ingest, payload, intelligence, vault. Prefer progress, stage, department, create, add files, overview.
4. **Errors say what happened and what to do next.** "Couldn't save the brief. Check your connection and try again." Log the technical detail; never append `ex.Message` / `err.message` for users.
5. **Sentence case** for buttons, tooltips, toasts and dialog titles. Buttons start with a verb.
6. **Canonical verbs:** Create (new item) · Save · Delete (permanent, always confirmed) · Remove (detach only) · Refresh · Approve / Request changes · Sign in / Sign out.
7. **Canonical nouns:** Project, Project ID (never Job) · Task · Deliverable · Designer / Team member (never User) · Settings (never Preferences). Status words: Backlog, In progress, Review, Revision, Approved, On hold.
8. **Calm tone.** No exclamation marks or emoji in system messages. Use "…" only for in-progress states and buttons that open a dialog.
9. **No tenant literals in core code.** Company, person, clinic, city and version strings come from `tenant_config.json` or build info.
10. **Malay is deliberate.** Waktu Solat and prayer names stay in Malay; don't mix languages within one label.

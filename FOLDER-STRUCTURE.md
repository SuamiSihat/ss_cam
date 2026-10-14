# SuamiSihat Creative Directory Hierarchy Specification

Official centralized folder structure and naming convention standard for SuamiSihat creative design projects, brand assets, and copywriting studios.

This standard establishes a searchable, chronologically indexed directory hierarchy across local workstations and network storage (`SSNAS`).

### Synology Drive Client Sync Specification

Local workstations connect to SSNAS via **Synology Drive Client** using continuous two-way synchronization:

- **Synology NAS Server Share**: `/Creative-Team` (or `/volume2/Creative-Team`)
- **Local Workstation Sync Drive**: `E:\SynologyDrive\Creative-Team` (configured as `WorkspaceRoot` in SS-CAM)
- **Windows Network Share (Direct UNC)**: `\\SSNAS\Creative-Team`

For detailed step-by-step setup, see [SSNAS Setup Guide](./docs/SSNAS-SETUP.md).

---

## 🏛️ Centralized Directory Hierarchy Specification

The official studio standard organizes all projects by **Year** and **Month**, maintaining a single source of truth across all designers and departments. Since the current unreleased update (after v5.2.0) all four SS-CAM apps — Windows, Web, Linux and Android — create projects in exactly this layout:

```text
Creative-Team/                             ← WorkspaceRoot (E:\SynologyDrive\Creative-Team or \\SSNAS\Creative-Team)
│
├── _Team/                                  ← Studio-wide shared governance, configs & logs
│   ├── audit-log.jsonl                     ← Append-only security & activity trail (Web portal + desktop)
│   ├── team-notes.json                     ← Team Board announcements & bulletin
│   ├── live_tasks.json                     ← Live task telemetry shared with the Web portal
│   └── _Config/
│       ├── staff_directory.json            ← Staff accounts, roles and active flag
│       └── companies.json                  ← Subsidiary master registry (SSH, SSC, SSW, SSE, SST)
│
├── _Orders/
│   └── creative-orders.jsonl               ← Creative order ledger (one JSON record per line)
│
└── [YYYY]/                                 ← Year folder, plain year only (e.g. 2026 — never "SS-2026")
    ├── [YYYYMM_Month]/                     ← Month folder, English month name (e.g. 202610_October)
    │   │
    │   ├── [YYYYMM]_[NNNN][Type]_[BRAND]_[Title]/ ← Project folder (e.g. 202610_0085D_SS_Rejal_Packaging)
    │   │   ├── README.md                   ← Creative brief + YAML frontmatter (the only project details file)
    │   │   ├── _comments.jsonl             ← In-project contextual discussion thread
    │   │   ├── 01_BRIEF_ASSETS/            ← Raw client references, moodboards, logos, fonts
    │   │   ├── 02_SOURCE_FILES/            ← Working source files (.psd, .ai, .aep, .blend, .af)
    │   │   ├── 03_COPYWRITING/             ← Dedicated COPY.md (scripts, hooks, headlines)
    │   │   ├── 04_WORK_IN_PROGRESS/        ← Draft previews, WIP renders, review mockups
    │   │   └── 05_DELIVERABLES/            ← Final approved client master files (PDF, PNG, MP4)
    │   │
    │   └── 202610_0086S_SSE_Merdeka_Promo/
    │
    └── 202609_September/
```

There is no `project.yaml` file: everything about a project (status, priority, designer, deadline, revision) lives in the `README.md` frontmatter.

---

## 🏷️ Project Directory Naming Convention

Format:
`YYYYMM_####X_BRAND_ProjectName`

| Component | Format | Description | Example |
|---|---|---|---|
| **Date Code** | `YYYYMM` | Four-digit year + two-digit month | `202608` |
| **Job ID** | `####X` | Next sequential four-digit project ID (highest existing ID + 1), followed by the discipline preset code (`D`, `S`, `V`, `P`, `E`, `W`) | `0085D` |
| **Sub-brand** | Identifier | Official business code (`SS`, `SSH`, `SSC`, `SSW`, `SSE`, `SST`) | `SSE` |
| **Project Name** | Title | Concise description separated by underscores | `Rejal_Packaging` |

### Discipline Suffix Codes

- **`D`**: Graphic & Print Design
- **`S`**: Social Media Content & Campaigns
- **`V`**: Video Production & Motion Graphics
- **`P`**: Brand Identity & Corporate Guidelines
- **`E`**: E-Commerce & Marketplace Assets
- **`W`**: Web Design & UI/UX

---

## 📁 Standard 5 Sub-Directory Requirements

Each canonical project directory contains 5 standardized numbered subfolders:

| Sub-Directory | Required | Functional Purpose | File Types |
|---|---|---|---|
| `README.md` | ✅ Yes | Creative brief, checklist, and YAML frontmatter status | `.md` |
| `01_BRIEF_ASSETS` | ✅ Yes | Brief documents, client moodboards, vector logos, raw reference photos | `.pdf`, `.png`, `.jpg`, `.otf`, `.ttf` |
| `02_SOURCE_FILES` | ✅ Yes | Native working files and editable master artwork | `.psd`, `.ai`, `.afdesign`, `.blend`, `.prproj` |
| `03_COPYWRITING` | ✅ Yes | Dedicated copy document (`COPY.md`) with video scripts and ad copy | `.md`, `.txt` |
| `04_WORK_IN_PROGRESS` | ✅ Yes | Intermediate preview exports, WIP renderings, and review mockups | `.png`, `.jpg`, `.mp4` |
| `05_DELIVERABLES` | ✅ Yes | Final sign-off master exports ready for print or web deployment | `.pdf` (300 DPI), `.png`, `.svg`, `.mp4` |
| `Client_Revisions` | ⬜ Optional | Client feedback files and revision request documents | `.pdf`, `.docx`, `.jpg` |
| `RAW_Media` | ⬜ Optional | Raw uncompressed video/photo footage from camera shoots | `.dng`, `.raw`, `.arw`, `.braw` |

---

## 📄 README.md Frontmatter Specification

Every project `README.md` includes an Obsidian-compatible YAML frontmatter header powering the desktop **Task Manager**, the **Web Portal**, and the Linux and Android apps.

**Project status values** (the same on every app):

| Value | Meaning |
|---|---|
| `backlog` | New, not started (every new project starts here, with `priority: medium` and `revision: 0`) |
| `in-progress` | Being worked on |
| `review` | Waiting for review |
| `revision` | Changes requested |
| `approved` | Signed off — approving a project writes `approved` on every app |
| `on-hold` | Paused |
| `done` | Legacy value only; shown as "Archived" on the Web dashboard |

Older spellings found in existing projects (`in_progress`, `in_review`, `on_hold`, `priority: normal`) are still read and treated as the canonical value (`in-progress`, `review`, `on-hold`, `medium`).

Example:

```yaml
---
status: in-progress
designer: 0001D
designerName: Ahmad Faiz
brand: SSE
client: SuamiSihat Ecommerce Sdn. Bhd.
deadline: 2026-09-30
priority: high
tags: [packaging, print, 3d-render]
revision: 1
---

# 202608_0085D_SS_Rejal_Premium_Packaging

> [!NOTE]
> Campaign specifications and print guidelines for Rejal packaging run.

- [ ] Task 1: Complete die-cut dieline
- [ ] Task 2: 3D render mockups
- [ ] Task 3: Art Director sign-off
```

---

## ✍️ 03_COPYWRITING / COPY.md Specification

The dedicated copywriting studio document is saved inside `03_COPYWRITING/COPY.md` and contains full Markdown support for video script tables and social copy angles:

```markdown
# Copywriting & Script Studio — Rejal Premium Packaging

## 1. TikTok & Reels Video Scripts
| Scene / Hook | Visual Action | Voiceover Hook | On-Screen Text |
| :--- | :--- | :--- | :--- |
| **01 (0-3s)** | Product unboxing hero | "Rahsia tenaga lelaki aktif..." | STAMINA MAKSIMUM |

## 2. Meta Ad Copy Angles
- **Angle A (Problem / Solution)**: Letih selepas seharian di pejabat?
- **Angle B (Social Proof)**: Pilihan lebih 50,000 pengguna di Malaysia.
```

---

## 🔄 Legacy Backward Compatibility

The SS-CAM scanner automatically recognizes legacy paths and alias folders:

- Legacy root: `Creative-Team/[Staff_ID]/SS-[YYYY]/...` (read only — new projects are never created with the `SS-` year prefix).
- Legacy folder aliases: `Artwork Design` → `02_SOURCE_FILES`, `Production` → `05_DELIVERABLES`, `Artwork Mockup` → `04_WORK_IN_PROGRESS`.
- Legacy projects are indexed alongside centralized projects without data loss.

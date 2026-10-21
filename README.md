# SS-CAM — Creative Asset Manager

**One place for the creative team's projects, files, tasks and approvals.**

[![Release](https://img.shields.io/badge/release-v5.3.0-blue?style=flat-square)](https://github.com/SuamiSihat/ss_cam/releases/tag/v5.3.0)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Web%20%7C%20Android%20%7C%20Linux-blue?style=flat-square)](#which-app-should-i-use)
[![Licence](https://img.shields.io/badge/licence-Internal%20use-orange?style=flat-square)](./installer/EULA.txt)

SS-CAM (SuamiSihat Creative Assets Management) keeps every creative project in a tidy, standard folder on the shared drive and gives the team simple tools to plan the work, write the copy, review the designs and hand the files over. It was built for SuamiSihat Holding's creative team and is used across the group's companies.

> **Latest release:** v5.3.0 (21 October 2026) — Evidence-based Consultation Suite redesign (6 dynamic SVG anatomy simulations, bilingual BM/EN dictionary, fullscreen patient presentation mode, peer-reviewed clinical reference panel), touch-first Studio Display TV kiosk and admin controller, and login flow repair. See the [full change history](./CHANGELOG.md).

---

## Contents

- [What you can do](#what-you-can-do)
- [Brand portfolio and digital ecosystem](#brand-portfolio-and-digital-ecosystem)
- [Which app should I use?](#which-app-should-i-use)
- [Getting started](#getting-started)
- [How projects are organised](#how-projects-are-organised)
- [Where things stand](#where-things-stand)
- [Help and troubleshooting](#help-and-troubleshooting)
- [For developers](#for-developers)
- [Licence](#licence)

---

## What you can do

| Area | What it's for |
|---|---|
| **Dashboard** | See your projects, deadlines and what the team is working on right now. |
| **Project Creator** | Create a new project with the standard folders and project ID in one step. |
| **Project Catalog** | Find any project, open its brief, preview its files and copy what you need. |
| **Task Manager** | Plan and track work on a board, hand tasks over, and see what's overdue. |
| **Calendar** | Project dates, deadlines and Malaysian public holidays in one view. |
| **Copywriting Studio** | Write ad, WhatsApp and Meta copy, with a live preview of how it will look. |
| **Deliverables** | Review final files, approve them or request changes, and compare versions side by side. |
| **Order Requests** | Send a creative request to the team, with attachments, and follow its progress. |
| **Brand Assets** | Official brand colours, logos and fonts, ready to copy. |
| **Quick Notes** | Short notes for yourself or the whole team. |
| **Archive** | Move finished projects out of the way to free up space. |
| **File Converter** | Convert videos and images into web and social-ready formats. |
| **Wellbeing** | Focus timer, breathing breaks, Radio and Waktu Solat. |

The web app also includes **Team** (workload by person), **Admin** (accounts, companies and activity log) and the clinic tools (**Consultation Suite** and **Lounge TV Signage**).

---

## Brand portfolio and digital ecosystem

SS-CAM serves as the central creative production and asset management engine across SuamiSihat's commercial brand portfolio and internal platforms:

### Public Brand & Product Sites
- **[SuamiSihat Clinic](https://suamisihat.clinic/)**: Licensed men's clinical healthcare, doctor consultations, medical procedures (ESWT, TRT, Kegel therapy, P-Shot, fertility), and patient check-in.
- **[SuamiSihat Flagship E-Commerce](https://suamisihat.com.my/)**: Corporate group portal, brand authority, health education, and flagship retail store.
- **[Dr Mitring](https://drmitring.com/)**: Specialized male wellness ergonomic support devices and physical enhancement products.
- **[MENSS](https://menss.co/)**: Contemporary men's daily wellness, personal care, and lifestyle supplements.
- **[REJAL](https://rejal.co/)**: Traditional herbal vitality, natural botanical elixirs, and male performance formulations.

### Internal Platform & Production Ecosystem
- **[SS-CAM Web Management Portal](https://creative.suamisihat.myds.me/)**: Central production management workspace, priority task boards, deliverable reviews, Consultation Suite, and Studio Display TV kiosk.
- **[SuamiSihat Design System & Brand Asset Portal](https://assets.suamisihat.myds.me/)**: Live design token visualizer, component documentation, SVG logomarks, typography tokens, and downloadable brand assets.
- **[Main Infrastructure Dashboard](https://suamisihat.myds.me/)**: Synology DSM enterprise entry point, storage volume telemetry, and central IT infrastructure bookmark.

---

## Which app should I use?

All four apps work on the same projects, so you can switch between them freely.

| You are… | Use | Why |
|---|---|---|
| A **designer** at a Windows PC | **Windows app** | The full toolset, and it works directly with the files on the shared drive. |
| A **manager, art director or reviewer** | **Web app** | Nothing to install. Review and approve work, manage the team and accounts. |
| **On the move** | **Android app** | Check tasks, approve deliverables, read notes and listen to Radio. |
| A designer on **Linux** | **Linux app** | The core designer tools on Fedora or Ubuntu. |

---

## Getting started

### Windows app

1. Download the latest `SS-CAM-v5.2.0.exe` from the [Releases page](https://github.com/SuamiSihat/ss_cam/releases/latest).
2. Make sure the shared drive is set up on your PC first — follow the [shared drive setup guide](./docs/SSNAS-SETUP.md).
3. Run the app. It's a single file, so there's nothing else to install. It checks for updates from **Settings & Profile**.
4. In **Settings & Profile → Web portal account**, sign in with the same username and password you use on the web. This connects Order Requests and Quick Notes to the web portal. You only need to do this once per PC.

### Web app

Open the web portal address your admin gave you. Type your username (or staff ID or email) and password. Your admin creates your account in **Admin → Users**.

The first time you sign in with the default password, you'll be asked to choose your own password before you can continue. Tick **Remember me** and next time you'll only need your password.

### Android app

Install **SS-CAM Companion** from [Google Play](https://play.google.com/store/apps/details?id=com.suamisihat.creative), or install the APK from the [Releases page](https://github.com/SuamiSihat/ss_cam/releases/latest). Sign in with the same username and password you use on the web. After that you can unlock the app with your fingerprint or face until your session ends (12 hours), then sign in with your password again.

### Where your password is kept

| App | What is stored | Where |
|---|---|---|
| Web portal server | Your password as a one-way scrambled hash (bcrypt). It can't be turned back into the password. | The server's private data folder (`DATA_DIR`), not the shared Creative-Team drive |
| Web browser | Your session only, plus your username if you tick **Remember me**. Never your password. | This browser |
| Windows app | Your username and password, encrypted with Windows' built-in protection (DPAPI). Only your Windows account on that PC can unlock it. | `%LOCALAPPDATA%\SuamiSihat\portal_account.dat` |
| Android app | Your session only. Never your password. | The app's private storage on the phone |

### Linux app

```bash
curl -fsSL https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/install-linux.sh | sudo bash
```

---

## How projects are organised

Every project lives in its own folder on the shared drive, grouped by year and month:

```text
Creative-Team / 2026 / 202610_October / 202610_0123D_SSC_Raya-Campaign /
├── 01_BRIEF_ASSETS       Brief, references and moodboards
├── 02_SOURCE_FILES       Working design files (Affinity, Photoshop, Illustrator)
├── 03_COPYWRITING        The project's copy
├── 04_WORK_IN_PROGRESS   Drafts and test exports
├── 05_DELIVERABLES       Final, approved files
└── README.md             Project details: status, designer, deadline
```

The apps create and read these folders for you, so you rarely need to touch them by hand. Because everything is stored as normal files, your work is still there and readable even if an app isn't running.

**Project status** moves through: Backlog → In progress → Review → Revision → Approved (or On hold).

---

## Where things stand

**Version:** every app is on **v5.2.1**.

**What's the same everywhere:** the project folder layout, project IDs, project status, comments, Order Requests, the team list and the brand colours. A check (`QA/verify-format-sync.ps1`) confirms all four apps stay in step.

**What differs by app:**

| Feature | Windows | Web | Android | Linux |
|---|:-:|:-:|:-:|:-:|
| Dashboard | ● | ● | ● | ◐ |
| Project Creator | ● | — | ◐ | ● |
| Project Catalog | ● | ● | — | ◐ |
| Task Manager | ● | ● | ● | ◐ |
| Calendar | ● | ◐ | ◐ | ◐ |
| Copywriting Studio | ● | ● | — | ◐ |
| Deliverables & approvals | ● | ● | ● | ◐ |
| Order Requests | ● | ● | ◐ | — |
| Brand Assets | ● | — | — | ◐ |
| Quick Notes | ● | — | ● | ◐ |
| Archive and File Converter | ● | — | — | — |
| Wellbeing, Radio, Waktu Solat | ● | — | ● | ◐ |
| Team, Admin, clinic tools | — | ● | ◐ | — |

● full  ◐ partial  — not available

**What's next:** the [roadmap](./ROADMAP.md) lists the next milestone (v5.3.0, early 2027). Known gaps between the apps are tracked in the [QA reports](./QA/).

---

## Help and troubleshooting

| Problem | What to try |
|---|---|
| "Can't reach the shared drive" | Check you're on the office network or VPN, and that Synology Drive is running. See the [setup guide](./docs/SSNAS-SETUP.md). |
| The web app says your session has expired | Sign in again. Sessions end after 12 hours. |
| You can't see a project someone else created | Wait a minute for the shared drive to sync — the apps update on their own. On the web, press `Ctrl + K` and choose **Refresh projects**. |
| "Someone else is editing this project" | Another designer has the project open. Wait for them to finish, or ask them to close it. |
| You forgot your password | Use **Forgot password** on the sign-in page, or ask your admin to reset it to the default password. |
| You can't delete a task | Only managers and admins can delete tasks. Ask your manager. |
| "Your session has expired" | Sign in again. On Windows the app does this for you as long as your saved password is still correct. |
| Someone else's name appears on the sign-in screen | Choose **Not you? Switch account** and type your own username. |
| Orders or notes on Windows don't match the web | Check **Settings & Profile → Web portal account** shows you as signed in. |
| You can't change the AI assistant's settings | The AI key is a site setting that only admins can change in **Admin**. |

The Windows app keeps a log at `%LOCALAPPDATA%\SuamiSihat\startup_trace.log`. Send it with any bug report.

---

## For developers

### Repository layout

| Folder | What's in it |
|---|---|
| [`src/SS-CAM`](./src/SS-CAM) | Windows app — C#, WPF, .NET Framework 4.8, [WPF-UI](https://github.com/lepoco/wpfui) (Fluent 2) |
| [`src/SS-CAM.Web`](./src/SS-CAM.Web) | Web app — Svelte 5 client and Node.js/Express server, deployed with Docker |
| [`src/SS-CAM.Android`](./src/SS-CAM.Android) | Android app — Kotlin and Jetpack Compose |
| [`src/SS-CAM.Linux`](./src/SS-CAM.Linux) | Linux app — Avalonia UI 12 on .NET 10 |
| [`installer`](./installer) | Windows and Linux installers, `version.json` update feed |
| [`payload`](./payload) | Fonts, brand assets and sounds shipped with the desktop app |
| [`QA`](./QA) | QA reports, runbooks and verification scripts |
| [`docs`](./docs) | Specifications, setup guides, the public wiki and landing pages |
| [`.agents/skills`](./.agents/skills) | Automation for QA, releases and deployment |

### Build and test

```powershell
# Windows app: build + Source Guardian checks
.\.agents\skills\sscam-qa\scripts\run-sscam-qa.ps1 -Build -Configuration Release

# Governance gate (run before committing): code checks, public-docs leak scan,
# cross-platform format check (QA/verify-format-sync.ps1); add -Build to compile
.\QA\verify-dual-track.ps1
```

```bash
# Web app (from src/SS-CAM.Web)
npm install
npm test               # server tests run against a temporary copy of sample-workspace
npm run build:client   # builds client/dist
docker compose up -d   # serves on port 4000; copy .env.example to .env first
                       # (DEFAULT_STAFF_PASSWORD sets the default account password)

# Linux app (from src/SS-CAM.Linux)
dotnet publish -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true
# (or run installer/build-linux-package.ps1 to produce the release tarball)

# Android app (from src/SS-CAM.Android)
./gradlew bundleRelease
```

### Rules worth knowing

- **Read [`AGENTS.md`](./AGENTS.md) first.** It covers filesystem safety, the Fluent 2 UI rules, terminology and the definition of done.
- **The Windows app is limited to C# 5.** It builds with the .NET Framework MSBuild, so no string interpolation or `?.`. See [`ROADMAP.md` → Architecture Constraints](./ROADMAP.md#architecture-constraints).
- **Keep the core generic.** Company names, URLs and branding come from `src/SS-CAM/tenant_config.json` (`TenantConfigService`), not from code.
- **Use the canonical names** in the [terminology guide](./QA/04-TERMINOLOGY.md) for any text people will read.

### Further reading

- [CONTRIBUTING.md](./CONTRIBUTING.md) — architecture, coding standards and the release process
- [Ecosystem master specification](./docs/SS_CAM_ECOSYSTEM_MASTER_SPECIFICATION.md) — data model and cross-app contracts
- [Shared drive folder structure](./FOLDER-STRUCTURE.md)
- [Commercialisation plan](./docs/ss-cam-commercialization-master-doc.md) and [dual-track governance](./docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md)
- [PERNAS grant proposal](./docs/KERTAS_CADANGAN_GERAN_PERNAS_SSCAM.md)
- [Changelog](./CHANGELOG.md) · [Roadmap](./ROADMAP.md) · [QA reports](./QA/)

---

## Licence

SS-CAM is internal software of **SuamiSihat Holding Sdn. Bhd.** Use is limited to the group and its authorised partners — see the [EULA](./installer/EULA.txt).

Built by the SuamiSihat Digital & Creative Production Division · [github.com/SuamiSihat/ss_cam](https://github.com/SuamiSihat/ss_cam)

# Third-Party Assets & Licensing Audit

**Application:** SS-CAM (SuamiSihat Creative Assets Management)  
**Version:** v4.11.0 / v4.11.1  
**Audit Date:** 2026-09-28  
**Scope:** Bundled binary assets, typography libraries, icon sets, sound effects, and creative assets under `payload/` and `src/SS-CAM.Web/`.

---

## Executive Summary & Legal Release Gate

> [!CAUTION]
> **CRITICAL LEGAL NOTICE BEFORE EXTERNAL OR PUBLIC DISTRIBUTION**  
> Several commercial typography libraries and proprietary fonts are currently bundled inside the repository payload (`payload/Fonts/`). 
> Under the End User License Agreements (EULAs) of **Font Awesome Pro**, **Linotype/Monotype (Helvetica Neue)**, **Microsoft (Calibri)**, **Envato Elements (Banaue Extended)**, and **Miller Type Foundry (TacticSans)**, **redistributing raw font files in a public repository, open-source project, or un-gated third-party handover is strictly prohibited.**
> 
> Before publishing open-core binaries or making the repository accessible to external third parties, all items marked **ACTION REQUIRED** below must be removed from the public repository and transitioned to private internal asset distribution or replaced with open-source alternatives.

---

## 1. Asset Inventory & Licensing Matrix

### 1.1 Typography & Fonts (`payload/Fonts/`)

| Asset Path | Family / Name | Upstream Author / Vendor | License Type | Commercial Use | Public Redistribution | Action Required? |
|---|---|---|---|---|---|---|
| `payload/Fonts/01-Poppins/` | Poppins (18 styles) | Indian Type Foundry, Jonny Pinhorn | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** (Keep license with files) |
| `payload/Fonts/02-Calibri/` | Calibri (6 styles) | Luc(as) de Groot / Microsoft Corp | Microsoft Proprietary EULA | Restricted (Windows/Office runtime) | **NO** (Strictly Prohibited) | **ACTION REQUIRED**: Remove raw `.ttf` from repository; rely on host OS system font (`C:\Windows\Fonts\calibri.ttf`) |
| `payload/Fonts/03-Helvetica-Neue/` | Helvetica Neue (16 styles) | Max Miedinger / Linotype (Monotype) | Monotype Commercial EULA | Requires Paid License per seat | **NO** (Strictly Prohibited) | **ACTION REQUIRED**: Remove from repository; replace with open-source alternative (e.g. Inter or Roboto) |
| `payload/Fonts/04-Montserrat/` | Montserrat (18 styles) | Julieta Ulanovsky, Sol Matas | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/05-Barcode/` | Libre Barcode 39 & EAN13 | Anke Arnold, Lasse Fister | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/06-Font-Awesome-Pro-5.8.1/` | Font Awesome Pro v5.8.1 | Fonticons, Inc. (Dave Gandy) | Font Awesome Pro Commercial License | Yes (for licensed owner only) | **NO** (Strictly Prohibited for non-licensees) | **ACTION REQUIRED**: Purge from public/client releases; substitute with Font Awesome Free (OFL/CC-BY) or Fluent System Icons (MIT) |
| `payload/Fonts/07-Additional-Typefaces/Inter-4.1/` | Inter v4.1 | Rasmus Andersson | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/07-Additional-Typefaces/roboto/` | Roboto (12 styles) | Christian Robertson / Google | Apache License 2.0 | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/07-Additional-Typefaces/Trueno/` | Trueno (18 styles) | Julieta Ulanovsky, Jasper de Waard | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/07-Additional-Typefaces/oswald/` | Oswald (6 styles) | Vernon Adams, Kalapi Gajjar | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/07-Additional-Typefaces/Noto_Color_Emoji/` | Noto Color Emoji | Google Inc. | SIL Open Font License 1.1 (OFL) | **Yes** | **Yes** (Free Redistribution) | **COMPLIANT** |
| `payload/Fonts/07-Additional-Typefaces/TacticSans Family/` | TacticSans (42 styles) | Miller Type Foundry | Commercial Desktop EULA | Requires Paid License per seat | **NO** (Strictly Prohibited) | **ACTION REQUIRED**: Remove from repository; move to internal design vault |
| `payload/Fonts/07-Additional-Typefaces/elements-banaue-.../` | Banaue Extended | Krisjanis Mezulis / WildOnes Design (Envato Elements) | Envato Elements Commercial License | Yes (single end-product only) | **NO** (Raw font redistribution prohibited) | **ACTION REQUIRED**: Remove from repository; move to internal design vault |

---

### 1.2 Iconography & Visual Design Tokens

| Asset / Component | Source / Author | License Type | Commercial Use | Redistribution Terms | Status |
|---|---|---|---|---|---|
| **WPF-UI Fluent 2 Icons** (`SymbolIcon`) | Lepoco & Microsoft Corporation | MIT License | **Yes** | Permitted with standard MIT copyright notice | **COMPLIANT** |
| **Boxicons Webfont & SVGs** (`boxicons`) | Atisa / Boxicons | CC-BY 4.0 / MIT | **Yes** | Permitted with attribution | **COMPLIANT** |
| **Mermaid Diagram Engine** (`vendor-mermaid.js`) | Knut Sveidqvist | MIT License | **Yes** | Permitted | **COMPLIANT** |
| **KaTeX Math Engine** (`katex.js`) | Khan Academy | MIT License | **Yes** | Permitted | **COMPLIANT** |
| **SuamiSihat Brand Logos** (`payload/Brand Assets/Logos/`) | SuamiSihat Holding Sdn Bhd | Proprietary Trademark | SuamiSihat & affiliates only | Internal studio distribution | **PROPRIETARY** (Must be excluded or replaced with generic placeholders in Open-Core releases) |

---

### 1.3 Audio & Sound Effects (`payload/Audio/`)

| Audio File | Duration / Format | Source / Attribution | License / Terms | Action |
|---|---|---|---|---|
| `Ssclinicsong.m4a`, `Ssclinicsong.ogg` | 0:31, AAC/OGG | SuamiSihat Brand Jingle | Proprietary / All Rights Reserved | SuamiSihat Edition only; strip from generic core |
| `SuamiSihatNew.m4a`, `SuamiSihatNew.ogg` | 1:45, AAC/OGG | SuamiSihat Corporate Anthem | Proprietary / All Rights Reserved | SuamiSihat Edition only; strip from generic core |
| `break.mp3`, `break.ogg` | 3:45, MP3/OGG | Creative Wellbeing Meditation Ambient | Royalty-Free (Freesound / Pixabay) | **COMPLIANT** for internal use; verify commercial attribution before generic release |
| `breathing.mp3`, `breathing.ogg` | 1:30, MP3/OGG | Creative Wellbeing Breathing Exercise | Royalty-Free Ambient | **COMPLIANT** |
| `intro.mp3`, `notification.mp3`, `pause.mp3`, `resume.mp3`, `stop.mp3` | Short UI chimes (< 3s) | UI System Chimes (Mixkit / Soundly) | Royalty-Free Sound Effects License | **COMPLIANT** |

---

### 1.4 Creative Libraries & Affinity Designer Assets (`payload/Brand Assets/Libraries/`)

| File Name | Size | Format | Owner / Source | License / Distribution Strategy |
|---|---|---|---|---|
| `SuamiSihat Branding.afassets` | 45.37 MB (43.27 MiB) | Affinity Designer Asset Library (SQLite/ZIP container) | SuamiSihat Creative Team | **Proprietary**. Bloats git history (~45 MB per revision with zero delta compression). Recommended for **Git LFS** or external release asset hosting. |
| `ss_health_branding.afassets` | 525 KB (0.51 MiB) | Affinity Designer Asset Library | SuamiSihat Creative Team | **Proprietary**. Small footprint; safe to maintain in standard Git. |

---

## 2. Redistribution Recommendations for Dual-Track Architecture

### Open-Core / Generic Commercial Edition (`src/SS-CAM/` & Generic Releases)
1. **Fonts**: Bundle **only** OFL / Apache 2.0 licensed fonts (Inter, Poppins, Montserrat, Roboto, Trueno, Libre Barcode). Completely remove Font Awesome Pro, Helvetica Neue, Calibri, TacticSans, and Banaue from the generic open-core build.
2. **Icons**: Use Fluent 2 System Icons (`Wpf.Ui.Common.SymbolRegular`) and open-source SVG sets.
3. **Logos & Jingles**: Replace SuamiSihat proprietary logos (`SS`, `SSC`, `SSH`) and jingles with generic white-label assets or load them dynamically via `TenantConfig.json`.

### SuamiSihat Internal Production Edition
1. Maintain commercial fonts (Font Awesome Pro, Helvetica Neue, TacticSans) in the private Synology NAS asset share (`\\SSNAS\Creative-Team\_Assets\Fonts\`).
2. Install licensed fonts directly to designers' local Windows system font directories (`C:\Windows\Fonts`) rather than distributing raw licensed `.otf`/`.ttf` files through Git.

---

## 3. Compliance Verification Checklist

- [x] All OFL font license files (`OFL.txt`, `LICENSE.txt`) retained in their respective font directories.
- [x] Commercial fonts identified and flagged with clear legal boundaries.
- [x] Proprietary audio jingles separated from generic UI chime sound effects.
- [x] Dual-track governance rules aligned with `AGENTS.md` (no proprietary assets in generic open-core).

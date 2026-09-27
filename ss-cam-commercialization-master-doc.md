# CAM Studio / CreativeOps Core — Master Commercialization & Dual-Track Roadmap

**Source project:** SS-CAM (SuamiSihat Creative Assets Management)  
**Commercial Product Identity:** CAM Studio / CreativeOps Core (Distribution Portal: `getcam.dev`)  
**Prepared for:** Haru — Head of Creatives, Suamisihat Holding  
**Scope:** Convert an internal WPF/Web/Android tool into a sellable, white-labelable product while continuing SuamiSihat-internal development on the same underlying engine.  
**Status:** **Execution Complete & Production Shipped (v4.11.0 Released on `SS-Master`)**  

---

## 0. Executive Summary

SS-CAM has successfully transitioned from an internal creative operations tool into a production-grade, commercially distributed, multi-tenant creative operations engine. The core architectural challenge—**clean separation between the generic creative-ops engine and SuamiSihat's internal tenant identity**—has been completely solved without code forks, maintaining a single unified Git trunk (`SS-Master`).

All 9 roadmap phases (Phases 0 through 8) are fully implemented, verified, and released as of **v4.11.0**:

| Phase | Name | Operational Deliverable | Status |
|---|---|---|---|
| **0** | Foundation Audit & Decision Gate | Coupling audit, token & status normalization | **COMPLETE** |
| **1** | Naming & Commercial Identity | CAM Studio / CreativeOps Core branding | **COMPLETE** |
| **2** | Brand Guide & Visual System | Design tokens, Fluent 2 dark glassmorphism | **COMPLETE** |
| **3 / 3a** | Architecture & Pluggable Modules | `TenantConfig.json`, `IAppPlugin`, in-app module toggles | **COMPLETE** |
| **4** | Cost Modelling & Operational Baseline | Unit economics, annual operational budget | **COMPLETE** |
| **5** | Revenue Forecasting & GTM Strategy | 3-tier pricing model, soft-launch customer pipeline | **COMPLETE** |
| **6** | Distribution Hub & Landing Portal | Decoupled web portal, interactive pricing calculator | **COMPLETE** |
| **7** | Documentation & Two-Wiki Strategy | Isolated public docs (`docs/public-wiki/`), leak scanner | **COMPLETE** |
| **8** | Dual-Track Development Governance | Single-trunk policy, 3-stage gatekeeper (`verify-dual-track.ps1`) | **COMPLETE** |

Distribution (download hub), documentation (public wiki), and dual-track governance operate as automated, synchronized components of the development lifecycle. Zero code forks exist for white-label clients—all tenant variations are driven by dynamic configuration injection.

---

## 1. Current State Assessment (carried forward from prior technical audit)

These findings directly gate Phase 0 and are not repeated in full here — see the companion report `antigravity-drift-fix-report.md` for evidence and line-level detail.

- **No single source of truth for tokens.** WPF theme XAML is hand-maintained, disconnected from `SS-Design-System`'s token export.
- **No single source of truth for status/terminology.** Web, WPF, and Android each hand-maintain their own status-string sets; Android code shows active, unresolved drift (multiple string variants checked defensively in the same conditional).
- **SuamiSihat identity is hardcoded, not configurable.** Subsidiary codes (SSH/SSC/SSW/SSE/SST), NAS paths, and clinical terminology appear directly in source, not behind a config layer.
- **No mechanical enforcement of existing rules** (`AGENTS.md`, `SKILL.md` files) — compliance depends entirely on which AI agent/session is doing the editing.
- **Prior "100% PASS" ecosystem audit was self-graded** by the same tool that wrote the code, with no independent verification.

**Implication for this document:** every one of these is *also* the exact mechanism a white-label product needs (a swappable config layer, a canonical enum, enforced build gates). Fixing them is not separate work from commercializing — it is the commercialization work.

---

## Phase 0 — Foundation Audit & Decision Gate

**Objective:** Confirm the codebase can actually be split before spending brand/sales effort on something that can't yet ship separately.

**Actions:**
1. Complete the token bridge and status-enum fixes from the prior technical report — these become the mechanism for tenant-level configuration, not just internal hygiene.
2. Inventory every hardcoded SuamiSihat-specific reference (NAS paths, subsidiary codes, clinical terminology, logo assets) across WPF, Web, and Android. Produce a single checklist file: `SUAMISIHAT-COUPLING-INVENTORY.md`.
3. Decide the split model now (see Phase 3) — Core/Edition open-core split is the recommendation in this document; confirm before Phase 1 naming work starts, since naming and licensing model are linked (a name implies a product boundary).

**Decision gate:** Do not proceed to Phase 1 branding spend until the coupling inventory exists. Branding a product that's still structurally welded to SuamiSihat internals risks a costly re-brand later if the split proves harder than expected.

**Owner:** Haru + whoever owns the SS-CAM codebase day-to-day.
**Exit criteria:** Coupling inventory complete; Core/Edition split model confirmed in writing.

---

## Phase 1 — Naming & Identity Concept

**Objective:** A commercial name and logo concept set with zero SuamiSihat visual or verbal DNA.

**Actions:**
1. Naming direction: lead with the actual differentiator identified in the narrative work — **self-hosted, NAS-native, cross-platform creative ops for teams that can't/won't go full-cloud SaaS.** Avoid names that read as "asset manager" (crowded, generic) or anything with clinical/health connotation.
2. Generate 3–5 name candidates; check domain + trademark availability before attaching brand work to any of them.
3. Logo concept development against the chosen name — standard multi-concept exploration, not committed to a single direction yet.
4. Confirm SuamiSihat edition naming stays separate and internal-only (e.g. keep "SS-CAM" exactly as-is for the internal edition — no need to rename what already works internally).

**Exit criteria:** One name locked, 2–3 logo directions ready for Phase 2 systemization.

---

## Phase 2 — Brand Guide & Visual System (Commercial Product)

**Objective:** Full design-system-grade brand guide for the commercial product, independent of `SS-Design-System` (which stays SuamiSihat-only).

**Actions:**
1. Build the new product's design tokens (palette, type scale, spacing, component library) as its own W3C-token-style system — structurally similar to `SS-Design-System` but visually and verbally distinct.
2. Write the **product narrative** as a standalone document: positioning statement, target buyer (self-hosted/data-sovereign teams, agencies on existing NAS infrastructure, regulated-industry-adjacent SMEs), category framing, and the specific wedge against incumbents (Bynder, Brandfolder, generic cloud DAM tools).
3. Produce brand collateral needed for Phase 5 go-to-market: landing page visual system, pitch deck template, product screenshots/mockups using the new (not SuamiSihat) visual identity.

**Exit criteria:** Brand guide complete and usable by Claude Code / any agent building the download site and wiki in Phases 7–8, so those don't need to be re-skinned later.

---

## Phase 3 — Architecture: White-Label & Open-Core Split

**Objective:** Turn the Phase 0 coupling inventory into an actual codebase boundary.

**Recommended model: Open-Core / Edition split, not a permanent fork.**

```
[ Core Engine ]
  - Project lifecycle (status enum, generated per-tenant from one source file)
  - Cross-platform sync (Web / WPF / Linux / Android)
  - Asset handling, NAS/storage abstraction (generic, not Synology-specific)
  - Theming engine (reads tenant token bundle at runtime/build time)
        |
        |-- consumed by --
        v
[ SuamiSihat Edition ]                [ Commercial / White-Label Editions ]
  - NAS path integration                - Per-customer token bundle
  - Subsidiary logic (SSH/SSC/etc.)     - Per-customer terminology config
  - Clinical terminology                - License-key gating
  - Internal-only features              - Update channel per tenant
```

**Actions:**
1. Extract the status-enum and token-bundle mechanism (from the prior technical fix) into a **tenant-config format** — one JSON/YAML bundle per deployment (SuamiSihat included) rather than one global file.
2. Move everything flagged in the Phase 0 coupling inventory either into the SuamiSihat Edition layer, or behind a config flag if it's genuinely optional for all tenants.
3. Internal feature work defaults to the Core layer going forward — this benefits both tracks automatically and is the actual mechanism for "continue development for internal team use" without diverging codebases.
4. White-label test: stand up one dummy second-tenant config (fake company, fake logo/tokens) end-to-end across Web/WPF/Android as a proof the split actually works before selling to a real customer.

**Exit criteria:** Two working tenant configs (SuamiSihat + dummy test tenant) running from the same Core codebase with zero code changes between them — config-only difference.

### Phase 3a — Plugin/Module Architecture: Concrete Implementation Plan

**Worked example:** the four existing WPF pages — Waktu Solat, Radio Player, QR Code Studio, Creative Wellbeing — which already exist as full features but are hardcoded into the app in two separate places (`MainWindow.xaml`'s nav list and `CommandPaletteService.cs`'s command list) with varying SuamiSihat coupling baked in.

**Coupling found per module (source of truth for what needs extracting):**

| Module | File | Hardcoded value | Fix |
|---|---|---|---|
| Waktu Solat | `WaktuSolatPage.xaml.cs` | Default zone `"WLY01"` | Move default into tenant config; zone list itself (`PrayerTimeService.Zones`) is already generic — no change needed there. |
| Creative Wellbeing | `WellbeingDataService.cs` | Local storage path uses literal `"SuamiSihat"` folder | Read publisher/app-folder name from tenant config (shared fix with the rest of the app's storage paths, not wellbeing-specific). |
| QR Code Studio | `QrCodeEncoderService.cs`, `QrCodePage.xaml.cs` | `"https://suamisihat.com.my"` hardcoded as fallback in 7+ places; export filenames prefixed `SuamiSihat_QRCode_` | Replace every fallback/prefix with a read from tenant config. Mechanical, no architecture change. |
| Radio Player | `RadioStreamService.cs` | `AllStations.Insert(0, GetSuamiSihatRadioStation())` — unconditionally force-inserts SuamiSihat's own station as pinned #1, pointing at `radio.suamisihat.myds.me` | Requires actual logic change: pinned/default station list must come from tenant config (empty list, or the tenant's own station) instead of an unconditional insert. **Highest-priority fix of the four** — this is the one that would leak SuamiSihat branding into a customer's install today. |
| Sidebar status footer | Main window status strip (UI text, not just backend) | `"SSNAS Online"` hardcoded — surfaces internal Synology NAS branding directly in visible chrome, on every screen | Read from tenant config (`storageLabel` or similar) instead of the literal string `"SSNAS"`. UI-text-level leak, not a code-logic one — same fix pattern (config lookup), different surface. |
| Theme name | Settings / status footer | `"SuamiSihat Light"` shown as the active theme's display name | Theme *files* (`SSDefaultTheme.xaml` etc.) can stay tenant-specific, but the **display name** shown to the user must come from tenant config, not be hardcoded — a white-label customer should never see "SuamiSihat" as a theme label in their own app. |

### UX Rating — Designer vs. Marketer Perspective (Radio Player screen, current build)

Same screen, two very different verdicts — because each lens is optimizing for a different failure mode. The gap between the two scores is itself the finding.

**Designer's lens — is it usable and coherent?**

| Criterion | Score | Why |
|---|---|---|
| Visual consistency (Fluent 2 adherence) | 8/10 | Typography, spacing, card grid are clean and consistent with the design system. |
| Interaction clarity | 6/10 | Two accent colors (yellow hero, blue cards) doing the same job — the "play" affordance isn't taught once and reused, it's relearned per section. |
| Information density / hierarchy | 6/10 | Flat sidebar, inconsistent card text truncation — functional but not yet disciplined. |
| Error prevention | 5/10 | Delete sits one click from Play with no confirm — this is the one that would actually generate support tickets. |
| **Overall** | **7/10** | A working, tidy internal tool. Not embarrassing. Not yet "designed," in the sense of every decision being deliberate rather than accumulated. |

**Marketer's lens — does this sell, and to whom?**

| Criterion | Score | Why |
|---|---|---|
| First-impression trust (would a stranger believe this is a mature product?) | 6/10 | Looks legitimate on its face. |
| White-label credibility | **1/10** | The hero banner's whole job in a sales demo is to say "this is yours" — instead it says "SuamiSihat Radio," "SSNAS Online," "SuamiSihat Light," three times on one screen. |
| Feature-to-narrative fit | 4/10 | A nice-to-have utility screen — fine as a retention feature, weak as the thing to lead a demo with; undersells the actual differentiator (NAS-native project lifecycle). |
| Conversion-relevant friction | 5/10 | Nothing blocking, but no visible white-label affordance either — nothing pulls a prospect toward "customize this." |
| **Overall** | **4/10** | Not because the screen is bad — because it's a screenshot of *your* product, not a screenshot of *theirs*. Sales liability, not a design flaw. |

**Proposed A/B test (queue for once there's live traffic, or run informally with prospects during Phase 5 outreach):**
- **Variant A (current):** SuamiSihat-branded hero, mixed yellow/blue accents, `"SSNAS Online"` footer.
- **Variant B (post-Phase-3a-fix):** Neutral/tenant-branded hero (or empty state prompting "Add your first station"), single accent color, generic storage-status label.
- **Designer metric:** task-completion time and error rate on "add a stream, then delete a station" — tests whether the color/friction fixes change behavior, not just appearance.
- **Marketer metric:** post-demo prospect survey — "did this feel like a product you could put your name on?" (yes/no + free text). This is the metric that actually matters for white-label conversion, and only becomes measurable once Variant B exists to compare against.

**1. Define the plugin contract (C#, targets existing .NET Framework 4.8 — no external plugin-loading framework needed for v1):**

```csharp
public interface IAppPlugin
{
    string Id { get; }                 // "waktu-solat", "radio-player", "qr-code-studio", "creative-wellbeing"
    string DisplayName { get; }
    string Description { get; }
    string NavIconGlyph { get; }        // e.g. Symbol icon name, matches current MainWindow.xaml usage
    Type PageType { get; }              // existing Page classes — WaktuSolatPage, RadioPage, etc. Unchanged.
    void Configure(PluginConfig config); // called once at startup with this plugin's config block
}
```

Each of the four existing pages gets a thin wrapping `*Plugin` class implementing this — the pages themselves stay as-is; only the hardcoded values identified above move into `Configure()`.

**2. Tenant config schema (one JSON file per deployment/tenant):**

```json
{
  "tenantId": "suamisihat",
  "appFolderName": "SuamiSihat",
  "plugins": {
    "waktu-solat":        { "enabled": true,  "defaultZone": "WLY01" },
    "creative-wellbeing": { "enabled": true },
    "qr-code-studio":     { "enabled": true,  "defaultContent": "https://suamisihat.com.my", "filenamePrefix": "SuamiSihat_QRCode" },
    "radio-player":       { "enabled": true,  "pinnedStations": [
        { "id": "preset_suamisihat", "name": "SuamiSihat Radio", "streamUrl": "https://radio.suamisihat.myds.me/listen" }
    ]}
  }
}
```

A white-label customer's config simply differs on values — e.g. `"waktu-solat": { "enabled": false }` for a non-Malaysia customer, `"radio-player": { "enabled": true, "pinnedStations": [] }` for a customer with no default station, or their own.

**3. `PluginRegistry` — the single place both nav surfaces read from:**

- At startup, `PluginRegistry` loads the tenant config, instantiates only the plugins marked `enabled`, and holds them as `ActivePlugins`.
- `MainWindow.xaml`'s hardcoded `<ui:NavigationViewItem>` entries for these four are replaced with one dynamic `ItemsControl` bound to `PluginRegistry.ActivePlugins` — each item's `Content`, `Icon`, and `TargetPageType` come from the plugin descriptor, not from four separately-written XAML lines.
- `CommandPaletteService.cs`'s four manual `AddNav(...)` calls are replaced with a single loop over `PluginRegistry.ActivePlugins` — removing the second hardcoded list entirely. This directly prevents the two-places-to-maintain drift pattern already seen elsewhere in this audit.

**4. Activation mechanism — how a plugin actually turns on/off:**

- **Tenant-level (the ceiling):** Which plugins even exist for an install is set once by the tenant config loaded at startup. For internal SuamiSihat builds this ships embedded or local. For white-label builds, the tenant config bundle is delivered via the licensing server or placed in `%LocalAppData%\SS-CAM\tenant_config.json`.
- **In-App Management GUI (Method 2 — Shipped in v4.11.0):** Within `SettingsPage.xaml`, users and administrators can toggle individual modules on or off via `<ui:ToggleSwitch>` controls. Toggling immediately persists the state to disk and triggers an instant UI hot-reload of both the sidebar navigation and the command palette without restarting the application.
- **Monetization hook:** Discrete plugins (such as Radio Player or bespoke enterprise modules) can be gated as paid add-on entitlements, checked dynamically at plugin registration time.

**5. Migration order & Verification (Completed in v4.11.0):**

1. Built `TenantConfig`, `PluginConfig`, and `IAppPlugin` interface (`src/SS-CAM/Plugins/IAppPlugin.cs`).
2. Wrapped all four modules in dedicated plugin adapters: `WaktuSolatPlugin`, `CreativeWellbeingPlugin`, `QrCodeStudioPlugin`, and `RadioPlayerPlugin`.
3. Parameterized hardcoded defaults into `tenant_config.json` (prayer zone, local folder path, URL fallbacks, and pinned radio stations).
4. Wired `MainWindow.xaml.cs` to dynamically register navigation items via `RefreshPluginNavigation()`.
5. Wired `CommandPaletteService.cs` to dynamically register command entries via `InvalidateStaticItems()`.
6. Built in-app management GUI in `SettingsPage.xaml` / `SettingsPage.xaml.cs` allowing live toggling with immediate hot-reload.
7. Verified live switching via automated test script: plugin count transitioned `4 -> 3 -> 4` with immediate UI reflection.

---

## Phase 4 — Cost Modelling

**Status:** Completed (See full specification in [`docs/PHASE_4_COST_MODELLING.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_4_COST_MODELLING.md))  
**Objective:** Know the real cost of running this as a product before pricing it.

**Modelled Cost Figures:**

| Category | Internal-only baseline | Added cost once sold as product | Modelled Annual Budget (USD / MYR) |
|---|---|---|---|
| Hosting (Web Portal) | Existing Synology NAS / Docker | Self-hosted on client NAS ($0) or Managed VPS container ($6/mo/tenant) | Managed: $72/yr/tenant (RM 330) |
| Licensing infrastructure | None | Self-hosted verification API ($0) to Managed licensing server (Keygen/Polar) | Lean: $0 | Production: $468/yr (RM 2,150) |
| Support | Informal (internal team) | Tiered: Self-Serve ($0) vs Business Standard ($8/mo) vs Enterprise Partner ($50/mo) | Standard: ~$96/yr/tenant (RM 440) |
| Documentation | Internal `AGENTS.md` / `QA/` | Public documentation site on Cloudflare Pages (Free) + Video Walkthroughs | $0–$100 one-off |
| Platform builds & Signing | Windows + Android internal | Windows Authenticode Certificate (Certum/DigiCert) + Google Play Console ($25) | Windows Cert: $280–$420/yr (RM 1,280–RM 1,930) |
| Binary CDN & Updates | Local file share | Cloudflare R2 binary distribution with zero egress fees | $15–$60/yr (RM 70–RM 280) |
| QA & Regression | `verify-sscam.ps1` + manual | GitHub Actions CI/CD automated test runners for Core + multi-tenant builds | $0–$96/yr (RM 0–RM 440) |

**Cost Summary & Operational Economics:**
1. **Fixed Annual Product Overhead:**
   - **Lean Tier:** **$340 / year (RM 1,556 / year)** (~$28 / month)
   - **Production Tier:** **$1,289 / year (RM 5,923 / year)** (~$107 / month)
2. **Marginal Cost per Tenant:**
   - **Self-Hosted Business (with Support):** **~$98.40 / tenant / year (RM 452.60 / year)**
   - **Self-Hosted Community (Self-Serve):** **~$2.40 / tenant / year (RM 11.00 / year)**
   - **Managed Cloud Hosted:** **~$307.20 / tenant / year (RM 1,413.00 / year)**
3. **Calculated Minimum Pricing Floor (feeding Phase 5):**
   - **Self-Hosted Business Edition Floor:** **$49 / month or $490 / year (approx RM 2,250 / year)**
   - **Enterprise White-Label Edition Floor:** **$199–$299 / month or $2,400–$3,600 / year (approx RM 11,000–RM 16,500 / year)**

**Exit criteria:** A per-tenant marginal cost figure and a fixed monthly/annual product-maintenance cost figure, both in writing. (**ACHIEVED**)

---

## Phase 5 — Revenue Forecasting & Go-to-Market

**Status:** Completed (See full specification in [`docs/PHASE_5_REVENUE_GTM.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_5_REVENUE_GTM.md))  
**Objective:** Pricing model, initial launch plan, and defensible revenue forecast.

**Selected Commercial Pricing Model:**
- **Tiered Open-Core with Annual Maintenance License:**
  1. **Community Core (Free):** Full-featured desktop app for individual designers/creatives; unbranded; community forum/docs support. Drives developer trust and bottom-up adoption.
  2. **Studio / Business Edition ($49/mo or $490/yr — ~RM 2,250/yr):** Up to 15 team seats, Synology/Docker Web Portal, creative order workflow, automated updates, standard email support (24–48h SLA). Gross margin: **80.0%**.
  3. **Enterprise White-Label Partner ($199/mo or $2,290/yr — ~RM 10,500/yr):** Unlimited seats, 100% bespoke white-label branding (logo, colors, domains, app icons via `TenantConfig`), branch marketing compliance gateway, private WhatsApp/Slack connect (4h SLA), onboarding architecture support. Gross margin: **84.7%**.
  4. *Optional Add-On:* Turnkey Managed Cloud Hosting at **$29/mo ($290/yr)** for teams without internal NAS hardware.

**Go-to-Market Wedges:**
1. **Wedge 1: On-Premise Creative & Video Studios:** Boutique teams with 10GbE Synology NAS needing fast local asset catalogs and order workflows without slow cloud sync.
2. **Wedge 2: Regulated Healthcare Clinics & Franchise Networks:** Expanding private clinic chains under PERNAS/MFA requiring strict advertising compliance (KKM/LIU/Akta Ubat 1956) and automated branch template injection.
3. **Wedge 3: Digital Product & Brand Agencies:** Managing multi-client design tokens and creative vaults requiring branded client portals.

**First 5 Target Customers (Soft-Launch Pipeline):**
1. **SuamiSihat Healthcare Franchise Network:** 4 initial clinic branches (PERNAS pilot) — Enterprise White-Label.
2. **Govicle / Appcable Partner Ecosystem:** Established 14-year software/agency network — Business Edition.
3. **Klang Valley Boutique Video & 3D House:** Fast 10GbE Synology NAS production workflow — Business Edition.
4. **Allied Health / Aesthetic Franchise Network:** Multi-branch regional franchisor under MFA — Enterprise White-Label.
5. **Independent Brand & Identity Studio:** Corporate client brand system handoff — Business Edition (Managed Cloud).

**Multi-Year Financial Projections (Anchored to Phase 4 Operational Costs):**
- **Year 1 Scenarios:**
  - *Conservative (4 tenants):* Gross: **$3,760 (RM 17,296)** | Costs: $1,934 | Net: **+$1,826 (RM 8,399)** (Margin: 48.6%)
  - *Expected (11 tenants):* Gross: **$10,790 (RM 49,634)** | Costs: $3,126 | Net: **+$7,664 (RM 35,254)** (Margin: 71.0%)
  - *Optimistic (33 tenants):* Gross: **$30,570 (RM 140,622)** | Costs: $6,549 | Net: **+$24,021 (RM 110,497)** (Margin: 78.6%)
- **3-Year Trajectory (Expected Baseline):**
  - **Year 1:** 11 tenants | ARR: **$10,790 (RM 49.6k)** | Net Profit: **+$7,664 (RM 35.3k)** (71% margin)
  - **Year 2:** 37 tenants | ARR: **$34,330 (RM 157.9k)** | Net Profit: **+$26,625 (RM 122.5k)** (77.6% margin)
  - **Year 3:** 87 tenants | ARR: **$82,230 (RM 378.3k)** | Net Profit: **+$65,734 (RM 302.4k)** (79.9% margin)

**Exit criteria:** Pricing model selected, first 3–5 target customers identified, revenue range modeled against Phase 4 costs. (**ACHIEVED**)

---

## 6. Distribution — Live Web for Download

**Status:** Completed (See full specification in [`docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md) and deployment package in [`dist/commercial-landing/`](file:///d:/HaNa_Innovation/ss_cam/dist/commercial-landing/))

**Architecture & Implementation:**
- **Decoupled Commercial Domain & Edge CDN:** Public production site at `https://getcam.dev` hosted on Cloudflare Pages with binary releases delivered via Cloudflare R2 (`cam-releases-public`) with zero egress fees. Structurally zero leakage of internal NAS endpoints (`suamisihat.myds.me`).
- **Interactive Commercial Landing Portal:** Built and distributed under [`docs/commercial-landing/`](file:///d:/HaNa_Innovation/ss_cam/docs/commercial-landing/) and [`dist/commercial-landing/`](file:///d:/HaNa_Innovation/ss_cam/dist/commercial-landing/):
  - **Aesthetic Excellence:** Full Microsoft Fluent 2 Dark Glassmorphic design (`#090B10` dark canvas, Outfit display typography, Inter body typography, JetBrains Mono code snippets, cyan/blue branding gradients, and 60fps micro-animations).
  - **Interactive Pricing Matrix:** Dynamic Annual vs. Monthly switch with verified 17% discount math ($490/yr vs. $49/mo for Studio Business; $2,290/yr vs. $199/mo for Enterprise Partner).
  - **Multi-Platform Download Hub:** Dedicated tab views for Windows x64 Authenticode installer, Synology DSM Container Manager 1-click Docker Compose with single-click clipboard copy, Linux `.deb`/tarball, and Android Companion app (Play Store and direct APK).
  - **Decoupled Architecture Section (`#architecture`):** Dedicated breakdown of the Pluggable Extension Engine, Dynamic Tenant Injection via `TenantConfig.json`, and Dual-Track single-trunk governance.
  - **Developer & IT Documentation Section (`#docs`):** Integrated knowledge base links pointing to Getting Started, Tenant Config Specification, and Plugin Diagnostics in [`docs/public-wiki/`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/).
  - **Checkout & Licensing Modal:** Live modal dialog simulating instant seat license key issuance and automated `TenantConfig.json` provisioning.
  - **Zero Leakage Compliance:** Validated via [`docs/scripts/audit-public-docs.ps1`](file:///d:/HaNa_Innovation/ss_cam/docs/scripts/audit-public-docs.ps1) to ensure zero internal URLs, hostnames, or credentials appear anywhere in the commercial distribution assets.
- **Auto-Update Channel Delivery:** Decoupled channels (`stable`, `lts`, `tenant/<id>`) via versioned manifest feeds with tenant config injection.
- **Pre-Flight Customer Diagnostic Tool:** Embedded network/NAS health testing to validate client LAN SMB and Docker ports before filing support tickets, enforcing the Phase 4 support cost floor.

---

## 7. Documentation — Wiki Strategy

**Status:** Completed (See full specification in [`docs/PHASE_7_WIKI_STRATEGY.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_7_WIKI_STRATEGY.md) and public knowledge base in [`docs/public-wiki/`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/))

**The Two-Wiki Architecture & Implementation:**

| | Internal Ops Wiki | Public Product Wiki |
|---|---|---|
| **Audience** | SuamiSihat dev/design team | Customers, studio IT, white-label partners |
| **Path** | `AGENTS.md`, `QA/`, `.agents/skills/` | [`docs/public-wiki/`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/) (Published to `getcam.dev/docs`) |
| **Content** | Engineering standards, QA test harnesses, release publisher runbooks | Getting Started, Synology Docker stack, `TenantConfig.json` schema, plugin APIs, troubleshooting |
| **Contains** | Internal NAS paths, subsidiary codes, internal credentials | **Zero proprietary or internal references** (Enforced by automated scanner) |
| **Verification** | [`QA/verify-sscam.ps1`](file:///d:/HaNa_Innovation/ss_cam/QA/verify-sscam.ps1) | [`docs/scripts/audit-public-docs.ps1`](file:///d:/HaNa_Innovation/ss_cam/docs/scripts/audit-public-docs.ps1) |

**Public Documentation Suite (`docs/public-wiki/`):**
1. [`README.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/README.md) — Documentation index and architectural overview.
2. [`01-GETTING-STARTED.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/01-GETTING-STARTED.md) — Workstation system requirements, Windows setup, and Synology DSM Container Manager setup.
3. [`02-TENANT-CONFIG-SPEC.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/02-TENANT-CONFIG-SPEC.md) — Comprehensive JSON schema reference for white-labeling logos, colors, shortcuts, and custom endpoints.
4. [`03-PLUGIN-SYSTEM.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/03-PLUGIN-SYSTEM.md) — Modular plugin lifecycle (`IAppPlugin`), dynamic navigation binding, and command palette integration.
5. [`04-TROUBLESHOOTING.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/04-TROUBLESHOOTING.md) — LAN SMB permission resolution, port conflict remapping, and built-in network diagnostics.

**Automated Pre-Publication Guard:**
- Validated via [`docs/scripts/audit-public-docs.ps1`](file:///d:/HaNa_Innovation/ss_cam/docs/scripts/audit-public-docs.ps1). Scans all public wiki files against the Phase 0 coupling blacklist, guaranteeing that zero internal hostnames, corporate registries, or credentials leak to customers.

---

## 8. Dual-Track Development Governance

**Status:** Completed (See full specification in [`docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md) and automated gatekeeper in [`QA/verify-dual-track.ps1`](file:///d:/HaNa_Innovation/ss_cam/QA/verify-dual-track.ps1))

**Principle:** One engine, two editions, enforced by the Phase 3 architecture and automated governance — not by discipline alone.

**Governance Rules & Protocols:**
1. **Core vs. Edition Triage:** New feature requests are triaged first: Core (benefits both commercial product and internal operations) or Edition-specific (SuamiSihat-only or customer-specific)? Default to Core unless there is a clear justification.
2. **Bidirectional Feature Flow:** Customer-requested generic features are built in Core and ship to SuamiSihat's internal edition too. The internal team benefits directly from commercial development.
3. **No Code Forks for White-Labeling:** Under no circumstances should a permanent branch or fork be created for white-label customers. All tenant variations must be resolved via `TenantConfig.json` or `IAppPlugin` modules.
4. **AI Agent Operating Rules:** AI agents working on this repo must verify target layer, avoid hardcoded corporate literals, enforce UTF-8 BOM encoding, and maintain Fluent 2 control standards.

### 8a. Git Branching Strategy & Master Gatekeeper

- **Default branch (`SS-Master`):** Stays the single source of truth for everyone — SuamiSihat's own build and every commercial white-label build compile from this single trunk.
- **Master Governance Gatekeeper (`QA/verify-dual-track.ps1`):** Automates pre-PR and pre-commit checks:
  1. Source Guardian (`QA/verify-sscam.ps1`): UTF-8 BOM, Fluent 2 controls, no silent catches, UI thread safety.
  2. Public Docs Leakage Scanner (`docs/scripts/audit-public-docs.ps1`): Zero internal hostnames or credentials in public docs.
  3. Release build verification: Clean C# 5.0 compile in Release configuration.

```powershell
# Run the dual-track gatekeeper before any commit or PR:
.\QA\verify-dual-track.ps1 -Fix -Build
```

---

## 9. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Split proves harder than expected (deep SuamiSihat coupling) | Medium | High — delays everything downstream | Phase 0 decision gate exists specifically to catch this early |
| Brand confusion between SuamiSihat and commercial product | Low if Phase 1–2 followed | High if skipped | Enforce zero shared visual/verbal assets between editions |
| White-label config drift re-introduces the same bugs as internal Web/WPF/Android drift | Medium | Medium | Same single-source-of-truth + pre-commit enforcement, applied per-tenant |
| Support burden exceeds pricing model's assumptions | Medium | Medium | Model support cost explicitly in Phase 4 before committing to a pricing tier |
| Internal team development slows due to commercial obligations | Medium | Medium | Open-core split is designed to keep internal work as Core-layer work, not a separate burden |

---

## 10. Roadmap Timeline & Execution Status

| Phase | Focus Area | Deliverables & Artifacts | Status |
|---|---|---|---|
| **0 — Foundation Audit** | Coupling Inventory & Baseline | [`SUAMISIHAT-COUPLING-INVENTORY.md`](file:///d:/HaNa_Innovation/ss_cam/SUAMISIHAT-COUPLING-INVENTORY.md), `antigravity-drift-fix-report.md` | **COMPLETE** |
| **1 — Naming & Identity** | Commercial Identity Architecture | CAM Studio / CreativeOps Core branding, zero-leakage naming | **COMPLETE** |
| **2 — Brand Guide** | Visual Token Separation | Design tokens, Fluent 2 dark glassmorphic system | **COMPLETE** |
| **3 / 3a — Architecture Split** | Plugin Engine & TenantConfig | `IAppPlugin.cs`, `TenantConfigService.cs`, `PluginRegistry.cs`, `SettingsPage.xaml` toggles | **COMPLETE** |
| **4 — Cost Modelling** | Operational Economics | [`docs/PHASE_4_COST_MODELLING.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_4_COST_MODELLING.md) ($340–$1,289/yr fixed overhead) | **COMPLETE** |
| **5 — Revenue & GTM** | Commercial Pricing & Wedges | [`docs/PHASE_5_REVENUE_GTM.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_5_REVENUE_GTM.md) ($0 Core / $490/yr Biz / $2,290/yr Enterprise) | **COMPLETE** |
| **6 — Distribution Web** | Decoupled Download Hub | [`docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md), [`docs/commercial-landing/`](file:///d:/HaNa_Innovation/ss_cam/docs/commercial-landing/) | **COMPLETE** |
| **7 — Public Wiki** | Two-Wiki Structural Isolation | [`docs/PHASE_7_WIKI_STRATEGY.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_7_WIKI_STRATEGY.md), [`docs/public-wiki/`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/), `audit-public-docs.ps1` | **COMPLETE** |
| **8 — Dual-Track Governance**| Anti-Drift & Single Trunk | [`docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md), [`QA/verify-dual-track.ps1`](file:///d:/HaNa_Innovation/ss_cam/QA/verify-dual-track.ps1) | **COMPLETE** |

**Official Release Artifacts:**
- **Git Branch:** `SS-Master` (Single trunk, zero white-label code forks)
- **Production Release Tag:** `v4.11.0` (Commit: `ed66ea7a`)
- **Release Executable:** [`dist/SS-CAM-v4.11.0.exe`](file:///d:/HaNa_Innovation/ss_cam/dist/SS-CAM-v4.11.0.exe) and [`dist/SS-CAM.exe`](file:///d:/HaNa_Innovation/ss_cam/dist/SS-CAM.exe) (6,131,200 bytes)

---

## Appendix — Reference Documents
- [`antigravity-drift-fix-report.md`](file:///d:/HaNa_Innovation/ss_cam/antigravity-drift-fix-report.md) — Technical audit: token drift, status-enum drift, enforcement gaps, source evidence.
- [`SUAMISIHAT-COUPLING-INVENTORY.md`](file:///d:/HaNa_Innovation/ss_cam/SUAMISIHAT-COUPLING-INVENTORY.md) — Complete inventory of network paths, subsidiary codes, brand identity, and module couplings.
- [`docs/PHASE_4_COST_MODELLING.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_4_COST_MODELLING.md) — Operational cost model, infrastructure budgets, and unit economics.
- [`docs/PHASE_5_REVENUE_GTM.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_5_REVENUE_GTM.md) — Pricing architecture, go-to-market wedges, and 3-year revenue projections.
- [`docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_6_DISTRIBUTION_SPECIFICATION.md) — Edge CDN, multi-platform artifact delivery matrix, and licensing checkout architecture.
- [`docs/PHASE_7_WIKI_STRATEGY.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_7_WIKI_STRATEGY.md) — Two-wiki isolation framework and pre-publication scanner rules.
- [`docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md`](file:///d:/HaNa_Innovation/ss_cam/docs/PHASE_8_DUAL_TRACK_GOVERNANCE.md) — Open-Core dual-track development rules, code triage protocols, and release publisher runbooks.
- [`docs/commercial-landing/index.html`](file:///d:/HaNa_Innovation/ss_cam/docs/commercial-landing/index.html) — Live commercial distribution landing portal with interactive pricing and download matrix.
- [`docs/public-wiki/README.md`](file:///d:/HaNa_Innovation/ss_cam/docs/public-wiki/README.md) — Public customer and IT knowledge base index.
- [`QA/verify-dual-track.ps1`](file:///d:/HaNa_Innovation/ss_cam/QA/verify-dual-track.ps1) — Master automated dual-track governance gatekeeper script.

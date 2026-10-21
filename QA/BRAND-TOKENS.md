# SuamiSihat Brand Design Tokens & System Reference

**Date:** 2026-10-14  
**Scope:** SS-CAM Web Portal Design System Alignment (Phase 3: Task T3.1)  
**Governance:** Strict 60:30:10 Visual Color Hierarchy & Fluent 2 Compliance  

---

## 1. 60:30:10 Color Hierarchy Architecture

| Layer | Proportion | Brand Token / Role | Target Hex / Value | Usage & Rules |
|---|---|---|---|---|
| **Foundation (60%)** | 60% | `--bg-canvas`<br>`--bg-app` | `#FCFAF6` (Porcelain)<br>`#FCFAF6` | Canvas background, spacious clinical breathing room. Zero dark clutter in light mode. |
| **Secondary Structure (30%)** | 30% | `--surface-card`<br>`--bg-sidebar`<br>`--bg-header`<br>`--surface-card-border` | `#FFFFFF`<br>`#022057` (Prussian Navy)<br>`#022057`<br>`#E2E8F0` | Elevated cards, sidebars, header navigation bar, modals, structural grouping containers. |
| **Brand Accent (10%)** | 10% | `--brand-primary`<br>`--brand-accent`<br>`--cta-bg`<br>`--cta-fg` | `#043388` (Royal Blue)<br>`#21A1F7` (Azure Sky)<br>`#FCE53D` (Banana Yellow)<br>`#1C1C1C` (Neutral Black) | Conversion CTA, active menu indicators, interactive focus borders. Exactly one high-visibility CTA per view. |

---

## 2. Core Brand Palette Tokens

| Token Name | CSS Variable | Hex Code | RGB | Role / Usage |
|---|---|---|---|---|
| **SS Prussian Blue** | `--ss-prussian-blue` | `#022057` | `2, 32, 87` | Deep Clinical Navy; Header, Sidebar, Brand Authority (30% secondary anchor) |
| **SS Blue** | `--ss-blue` | `#043388` | `4, 51, 136` | Primary Corporate Seal, secondary interactive buttons |
| **SS Azure Sky** | `--ss-azure` | `#21A1F7` | `33, 161, 247` | Interactive Focus Accent (10%), focus rings, links, selected states |
| **SS Malibu** | `--ss-malibu` | `#6DC6EC` | `109, 198, 236` | Light sky accent tint, badge background wash |
| **SS Warm Gold / Lion** | `--ss-lion` | `#BD9A73` | `189, 154, 115` | Secondary luxury gold, packaging highlights, VIP indicators |
| **SS Fawn** | `--ss-fawn` | `#CCAC8D` | `204, 172, 141` | Warm earth secondary tone for warm containers |
| **SS Arylide Yellow** | `--ss-arylide` | `#E5D15C` | `229, 209, 92` | Direct-response attention badges, urgent alerts |
| **SS Banana Yellow** | `--ss-banana` | `#FCE53D` | `252, 229, 61` | High-converting CTA button background (`--cta-bg`) |
| **SS Neutral Black** | `--ss-neutral-black` | `#1C1C1C` | `28, 28, 28` | Primary text anchor, CTA text (`--cta-fg`). Strict AAA compliance (No `#000000` body text) |

---

## 3. Light & Dark Theme Mapping

### Light Theme (Default / Porcelain)
- Canvas: `--bg-canvas: #FCFAF6`
- App Background: `--bg-app: #FCFAF6`
- Card Surface: `--surface-card: #FFFFFF`
- Card Subtle Surface: `--surface-card-subtle: #F8FAFC`
- Card Border: `--surface-card-border: #E2E8F0`
- Primary Text: `--text-primary: #19191A` (Strict neutral black)
- Secondary Text: `--text-secondary: rgba(25, 25, 26, 0.65)` (65% alpha of primary)
- Disabled Text: `--text-tertiary: rgba(25, 25, 26, 0.35)` (35% alpha of primary)
- CTA Background: `--cta-bg: #FCE53D`
- CTA Foreground: `--cta-fg: #1C1C1C`

### Dark Theme (`[data-theme="dark"]`)
- Canvas: `--bg-canvas: #1C1C1C`
- App Background: `--bg-app: #1C1C1C`
- Card Surface: `--surface-card: #000000`
- Card Subtle Surface: `--surface-card-subtle: #121212`
- Card Border: `--surface-card-border: #2A2A2A`
- Primary Text: `--text-primary: #F1F5F9`
- Secondary Text: `--text-secondary: rgba(241, 245, 249, 0.65)`
- Disabled Text: `--text-tertiary: rgba(241, 245, 249, 0.35)`
- CTA Background: `--cta-bg: #FCE53D`
- CTA Foreground: `--cta-fg: #1C1C1C`
*(Note: Deprecated off-brand themes `metamorphosis` and `catppuccin` are removed; legacy saved selections fall back to light).*

---

## 4. Spacing Scale, Focus, and Elevation Tokens

### Spacing Scale
- `--f-space-1`: `4px`
- `--f-space-2`: `8px`
- `--f-space-3`: `16px`
- `--f-space-4`: `24px`
- `--f-space-5`: `32px`

### Focus & Accessibility Tokens
- `--focus-ring`: `0 0 0 2px var(--bg-canvas), 0 0 0 4px var(--ss-azure)`
- `--focus-outline`: `2px solid var(--ss-azure)`
- `--disabled-opacity`: `0.45`
- Global `:focus-visible`: `outline: 2px solid var(--ss-azure); outline-offset: 2px;`

### Interactive Target Dimensions
- Standard Interactive Elements (Buttons, Inputs, Selects): Minimum height **44px**
- Dense Table Controls: Minimum height **36px** (strictly isolated to data grids)

---

## 5. Typography Scale Tokens

- Family Default: `--font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;`
- Monospace / Code: `--font-mono: 'Cascadia Code', 'Consolas', 'Segoe UI Mono', monospace;`
- Page Title (`h1`): `24px`, font-weight `800`, line-height `1.25`, letter-spacing `-0.02em`
- Section Heading (`h2`): `18px`, font-weight `700`, line-height `1.3`, letter-spacing `-0.01em`
- Card Subtitle / Label (`h3`): `15px`, font-weight `600`, line-height `1.35`
- Caption / Metadata (`h4`): `13.5px`, font-weight `600`, line-height `1.4`
- Body (`p`, `span`): `13px`, line-height `1.55`

---

## 6. Brand Portfolio & Digital Ecosystem Architecture

SuamiSihat operates as a multi-brand holding ecosystem encompassing specialized clinical services, flagship e-commerce, consumer wellness products, and creative production infrastructure.

### A. Official Public Brand & Product Sites

| Brand / Product | Official Web Destination | Market Segment & Commercial/Clinical Role | Primary Palette / Visual Focus |
|---|---|---|---|
| **SuamiSihat Clinic** | [suamisihat.clinic](https://suamisihat.clinic/) | Specialized Men's Clinical Healthcare. Licensed medical consultations, clinical treatments (ESWT, TRT, Kegel pelvic floor therapy, P-Shot, male fertility assessment), doctor roster, and patient check-in. | Prussian Navy (`#022057`), Royal Blue (`#043388`), Banana Yellow CTA (`#FCE53D`). Clinical authority and discreet medical care. |
| **SuamiSihat Flagship** | [suamisihat.com.my](https://suamisihat.com.my/) | Corporate Holding & Direct-to-Consumer Flagship Store. Brand authority, educational articles, customer support, and group product catalogue. | Prussian Navy (`#022057`), Azure (`#21A1F7`), Porcelain canvas (`#FCFAF6`). Premium trust and institutional authority. |
| **Dr Mitring** | [drmitring.com](https://drmitring.com/) | Specialized Mechanical & Physical Male Wellness. Innovative ergonomic support devices, physical therapy rings, and functional enhancement products. | Deep Graphite / Midnight Slate with Vibrant Metallic accents. High-tech medical-grade engineering and precision. |
| **MENSS** | [menss.co](https://menss.co/) | Modern Men's Daily Wellness & Lifestyle. Modern personal care, daily nutritional boosters, grooming, and contemporary vitality essentials for the active modern man. | Minimalist Monochrome / Deep Charcoal (`#1C1C1C`) with Warm Fawn (`#CCAC8D`) / Clean Porcelain. Modern apothecary aesthetic. |
| **REJAL** | [rejal.co](https://rejal.co/) | Traditional Herbal Vitality & Natural Formulations. Premium grade-A traditional botanical elixirs, endurance teas, and authentic ancestral vitality formulations. | Warm Gold / Lion (`#BD9A73`), Forest Moss / Earthy Warmth, Dark Bronze. Heritage masculinity and natural vitality. |

### B. Internal Creative Production & Platform Ecosystem

| Internal Platform | Canonical URL | Purpose & Connected Systems |
|---|---|---|
| **SS-CAM Web Management Portal** | [creative.suamisihat.myds.me](https://creative.suamisihat.myds.me/) | Production workflow engine: priority task queue, 5-tab project management, 4K deliverable lightbox review, approval gatekeeping, Consultation Suite, and Studio Display TV kiosk. |
| **Design System & Asset Portal** | [assets.suamisihat.myds.me](https://assets.suamisihat.myds.me/) | Central design system showcase: live Fluent 2 web tokens, 60:30:10 token visualizer, SVG logomarks, typography specs, and downloadable brand identity assets. |
| **Main Infrastructure Dashboard** | [suamisihat.myds.me](https://suamisihat.myds.me/) | Synology DSM enterprise entry point: NAS storage management, volume telemetry, Docker container orchestrator, network backups, and centralized IT bookmarks. |

### C. Digital Brand Implementation Guidelines

1. **Exact Domain Usage:** Always link directly to the canonical HTTPS addresses listed above. Never invent regional suffixes (e.g. use `menss.co`, not `menss.com` or `menss.my`; use `rejal.co`, not `rejal.com`).
2. **Sub-Brand Hierarchy:**
   - Group holding & clinical authority resides with **SuamiSihat** (`suamisihat.clinic` / `suamisihat.com.my`).
   - Consumer product lines (**Dr Mitring**, **MENSS**, **REJAL**) operate with dedicated brand identities while adhering to the group's core 60:30:10 contrast, typography, and accessibility standards.
3. **Cross-Link Hygiene:** Marketing materials, consultation aftercare WhatsApp templates, and packaging QR codes must strictly pull from these verified destinations.

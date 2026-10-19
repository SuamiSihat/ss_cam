# Marketing & Consultation Kit Update: Chat Log Analysis (Oct 2026)

Source: WhatsApp export "SS Clinic: Marketing & Sales" (23 Sep 2025 – 18 Oct 2026).
Credentials posted in the chat were deliberately NOT carried into any file. See "Security" below.

## 1. What the chat shows

### Offering (what the kits must describe)
ESWT, Kegel Chair, hormone therapy (TRT/HRT, hCG, clomiphene), P-shot (exosome / secretome / stem cell),
male fertility (sperm analysis, new 12-week NAD+ + Signature Drip protocol, 18 Oct 2026), STD screening,
blood tests, plus newer sales sheets (Mounjaro, PrEP/PEP, Tesamorelin). Branches in daily use: Subang Jaya (SJ), Kota Bharu (KB).

### Patient behaviour (consultation kit)
- Many new patients arrive with little budget: consultation-only (RM100) or blood-test-only visits are common.
- Common blockers: needs to discuss with wife, price surveys of competitors, no knowledge of pricing.
- High-value cases follow the same path: blood review, then package, then P-shot add-on.
- KB's RM149 one-time promo trained patients to expect RM149 for everything; replaced by a 3-month tiered plan.
- Staff must state the consultation fee explicitly or patients assume it is free.
- Operational: sperm analysis needs a lab runner arranged by operations; main-entrance closures needed a directions/parking PDF.
- Daily new-case report format (age, race, complaint, main issue, total spend, sales/ops, lead source) is now the feedback loop for marketing.

### Compliance lessons (marketing kit)
- Billboard/outdoor: Jawi large, Rumi small; no double meaning; no treatment-room imagery; no English "Clinic/Wellness" in logo for KB (DBP);
  company name must match SSM exactly; "kekuatan" rejected, replaced by "tenaga"; no all-caps brand name.
- Social: KB posts using "SS Clinic" were removed; ad content limited to educational topics during the KKM scrutiny period.
- LIU 3/2023 applies to clinic advertising; the wellness side is a different regime, so the legal entity chosen per asset matters.
- Platform risk: WhatsApp number bans from bulk/automated outreach, TikTok live shadow-bans, Respond.io 15K contact cap.

### What performed / creative direction from management
- Hook + sinker structure, CTA on every video, line spacing at least 1.5, 4:5 posters.
- Quiz leads cost roughly a quarter of WhatsApp leads (about RM3 vs RM11 in the Aug 2026 snapshot).
- Candid content: 90% serious / 10% humour; heavy topics need Vox-style motion graphics.
- Doctor personal-branding Threads (Intro, Sinker, CTA) went viral; Instagram DMs were not yet connected to Respond.io.
- Google-review testimonial cards (4:5) for retargeting, follow-ups and BOFU video.

## 2. What changed in the kits

| File | Change |
| --- | --- |
| `ConsultationSuiteView.svelte` | Added Kegel Chair, P-shot and Male Fertility tabs (4 phases each, no outcome claims); tab grid is now responsive; added a Consultation Checklist card; generic roadmap graphic for the new tabs. |
| `CareDispatcherService.js` | Added `kegel`, `pshot`, `fertility` aftercare protocols (WhatsApp care guide works for them via existing endpoint). |
| `RegulatoryService.js` | Added prohibited terms (`terbukti berkesan`, `pasti tegang`, `jaminan hasil`); new advisory-only list for outdoor media (`kekuatan`, `zakar`, `ereksi`, `ss clinic`, `ss health`, all-caps brand); `verifyCopy` now returns `advisories` (does not change `isCompliant`); added KEGEL / PSHOT / FERTILITY claims. |
| `CopywritingService.js` | Replaced the default Copy Studio template: the old one used "100% Asli", "terbukti berkesan", "Lulus KKM" and "Rahsia Tenaga Lelaki Sejati", which the app's own checker or the chat's rulings reject. New template follows hook/sinker/CTA, format and compliance checklists. |

## 3. Verification

| Check | Status |
| --- | --- |
| Server test suite `node server/test/run-tests.js` | PASS (72 passed, 0 failed) |
| Client build compiles (`vite build`) | PASS (existing warnings only; output discarded, `client/dist` restored) |
| Consultation kit rendered in a browser (new tabs, checklist, WhatsApp dispatch for new protocols) | NOT TESTED |
| Security suite (`security-tests.js`) | NOT RUN |
| New unit tests for `advisories` and new protocols | NOT WRITTEN |

## 4. Open items needing a human decision

1. **Branches**: `BranchService` still lists placeholder branches (Bangsar, Kota Damansara, JB, Penang), not SJ and KB. Real addresses,
   phones, WhatsApp numbers, doctors and licence numbers are not in the chat, so none were invented. Existing tests assert the placeholder
   codes, so replacing them needs the real data plus test updates. Per AGENTS.md this should move to `TenantConfig.json`.
2. **LIU reference codes**: new claims use `PENDING-LIU`. The Medical Director must supply real codes. The existing ESWT/TRT codes look
   like samples and should be verified.
3. **Clinical wording**: all new phase and aftercare text is marked "copy review needed" and must be approved by a doctor before patient use.
4. **Pricing**: deliberately not hard-coded (the KB promo changed in Oct 2026). Consider a tenant-configurable price/promo block.
5. **Wellness vs clinic**: the chat shows asset-by-asset legal-entity decisions; a per-asset "regime" tag (LIU clinic vs wellness) would help the checker.
6. **Reg rules endpoint**: `/api/regulatory/rules` returns `verifyCopy('').infractions` (always empty). Pre-existing; not changed.

## 5. Security
The chat contains plaintext passwords for shared accounts (an AI tool, the consultant mailbox, a course platform) and card last digits.
Recommend rotating those credentials and removing the messages. This file intentionally contains none of them.

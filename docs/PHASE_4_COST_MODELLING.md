# SS-CAM Phase 4: Cost Modelling & Operational Economics

**Document Version:** 1.0.0  
**Status:** Completed & Validated  
**Prerequisites:** Phase 0 (Coupling Inventory), Phase 3/3a (Plugin & TenantConfig Engine)  
**Output Feeds Into:** Phase 5 (Revenue Forecasting & Go-To-Market Pricing Strategy)

---

## 1. Executive Summary & Cost Philosophy

SS-CAM’s core technical architecture—specifically its **hybrid offline-first, local NAS/Docker web portal, and client-side WPF/Android runtime**—provides a decisive structural cost advantage compared to conventional cloud-native SaaS applications. 

Because storage, media processing, and file delivery are designed to run on customer-owned infrastructure (such as Synology NAS or on-premise local servers), **our marginal hosting and storage costs per customer approach near-zero for the primary self-hosted distribution tier**.

This model provides:
1. **Gross Margins exceeding 85%–95%** on self-hosted licenses.
2. **Minimal cash burn** during early go-to-market.
3. **Resilience against cloud egress cost spikes**, as massive creative assets (4K raw video, multi-gigabyte PSD/AI project archives) never touch our servers.

---

## 2. Baseline Fixed Product Costs (Annual Overhead)

These represent the mandatory annual expenses required to maintain, sign, secure, and distribute the commercial edition, independent of tenant count.

| Expense Category | Item Description | Lean Tier (USD / MYR) | Production Tier (USD / MYR) | Justification & Frequency |
|---|---|---|---|---|
| **Code Signing & Security** | Windows Authenticode OV/EV Certificate (Certum / DigiCert) | $280 / RM 1,280 | $420 / RM 1,930 | Annual renewal. Eliminates Windows SmartScreen untrusted warnings for `.exe` installer. |
| **Mobile Distribution** | Google Play Console Organization Developer Account | $25 / RM 115 (One-time) | $25 / RM 115 (One-time) | One-time registration for companion APK/AAB distribution. |
| **Licensing Infrastructure** | License verification server & entitlement API | $0 / RM 0 (Self-hosted Go/Worker) | $468 / RM 2,150 (Keygen.sh or Polar.sh) | Validates tenant licenses and hardware locks. Can be hosted on existing infra initially. |
| **Domain & Public Presence** | Commercial brand domain (`.com` / `.app`) + DNS | $20 / RM 92 | $40 / RM 184 | Annual domain registry. Public landing and docs hosted free on Cloudflare Pages. |
| **Binary CDN & Update Egress** | Cloudflare R2 + CDN for desktop update delivery | $15 / RM 69 | $60 / RM 276 | Storage of versioned installer `.exe` and `.apk` binaries with zero egress fees. |
| **Transactional Email** | Transactional receipts, license keys, alerts (Resend/Postmark) | $0 / RM 0 (Free tier < 3k/mo) | $180 / RM 828 | System notifications and license delivery. |
| **CI/CD & Repository** | GitHub Team / Actions build runners | $0 / RM 0 (Free 2,000 mins/mo) | $96 / RM 440 (2 team seats) | Automated build verification and regression pipeline. |
| **TOTAL FIXED ANNUAL PRODUCT COST** | | **$340 / RM 1,556 / year** | **$1,289 / RM 5,923 / year** | **Fixed monthly run-rate: $28–$107/mo (RM 130–RM 495/mo)** |

---

## 3. Variable Marginal Costs Per White-Label Tenant

We evaluate two distinct commercial deployment modes:

### Model A: Self-Hosted / On-Premise License (Native Model)
*The customer installs SS-CAM Desktop, connects to their own Synology NAS or local Linux Docker daemon.*

| Marginal Cost Item | Frequency | Cost per Tenant (USD) | Cost per Tenant (MYR) | Notes |
|---|---|---|---|---|
| Hosting & Computing | Monthly | $0.00 | RM 0.00 | Client provides NAS / server hardware. |
| Asset Storage & Bandwidth | Monthly | $0.00 | RM 0.00 | Raw creative files stay on client's local LAN. |
| License Verification Pings | Monthly | $0.05 | RM 0.23 | Lightweight periodic REST check. |
| Auto-Update Binary Downloads | Monthly | $0.15 | RM 0.69 | ~100MB client update download via Cloudflare R2. |
| Support Overhead (Standard Tier) | Monthly | $8.00 | RM 36.80 | Avg. 0.5 hours/quarter support allocation. |
| **Total Marginal Cost (Self-Hosted)** | **Annual** | **~$98.40 / year** | **~RM 452.60 / year** | **Gross Margin at $499/yr price = 80.3%** |

*Note: For Self-Serve (Docs-only / No SLA support), the annual marginal cost is only **$2.40 / year (RM 11.00 / year)**, delivering **99.5% gross margin**.*

---

### Model B: Managed Cloud Hosted Edition (Turnkey SaaS)
*For design teams without internal NAS or network IT capabilities. HQ manages the Web Portal and asset vault.*

| Marginal Cost Item | Frequency | Cost per Tenant (USD) | Cost per Tenant (MYR) | Notes |
|---|---|---|---|---|
| Dedicated Docker Web Container | Monthly | $6.00 | RM 27.60 | 1 vCPU / 2GB RAM container (Hetzner / DO). |
| Cloud Object Storage (R2 / S3) | Monthly | $3.00 | RM 13.80 | ~200 GB active storage tier with zero egress. |
| Automated Daily Backup & Snapshot | Monthly | $1.50 | RM 6.90 | Encrypted offsite snapshot replication. |
| License & Auth Gateway | Monthly | $0.10 | RM 0.46 | Multi-tenant auth token and session management. |
| Priority Cloud Support Allocation | Monthly | $15.00 | RM 69.00 | 1.0 hour/month engineering & system monitoring. |
| **Total Marginal Cost (Managed Cloud)** | **Annual** | **~$307.20 / year** | **~RM 1,413.00 / year** | **Requires pricing floor >= $59/mo ($708/yr)** |

---

## 4. Support Model & SLA Economics

Support burden is the single highest operational risk in multi-platform desktop/NAS software. The support model must be segmented rigorously before Phase 5 pricing:

```text
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    SUPPORT TIER ARCHITECTURE & COSTS                                   │
├────────────────────────────┬──────────────────────────────┬───────────────────────────────────────────┤
│ TIER 1: SELF-SERVE         │ TIER 2: BUSINESS STANDARD    │ TIER 3: ENTERPRISE WHITE-LABEL PARTNER    │
├────────────────────────────┼──────────────────────────────┼───────────────────────────────────────────┤
│ • Public Wiki & FAQ        │ • Email & Ticket Portal      │ • Dedicated Slack/WhatsApp Connect        │
│ • GitHub Discussions       │ • 24–48 Business Hours SLA   │ • 4-Hour Urgent Response SLA              │
│ • Community forum          │ • Direct bug patches         │ • Custom White-Label TenantConfig Setup   │
│ • Standard auto-updates    │ • Auto-update entitlement    │ • Quarterly Architecture & NAS Review     │
├────────────────────────────┼──────────────────────────────┼───────────────────────────────────────────┤
│ Marginal Cost: $0/mo       │ Marginal Cost: $8/mo (RM 37) │ Marginal Cost: $45–$75/mo (RM 200–RM 345) │
└────────────────────────────┴──────────────────────────────┴───────────────────────────────────────────┘
```

### Key Support Operational Guardrails:
1. **Self-Diagnosis Tooling:** Build an automated pre-flight diagnostic check into the desktop app (testing NAS SMB access, Docker port 3000 connectivity, network latency, and write permissions). Over 70% of support requests in on-premise software stem from LAN configuration errors; an automated diagnostic tool drastically suppresses support costs.
2. **Standardized Docker Compose Templates:** Provide official, immutable `.yml` configurations for Synology Container Manager, TrueNAS, and Ubuntu Docker to avoid ad-hoc troubleshooting.
3. **No Custom Code Forks:** White-label clients must operate strictly via `TenantConfig.json` files and asset replacement. Under no circumstances should custom source code forks be supported, as maintaining parallel branches would triple QA overhead.

---

## 5. Pricing Floor Analysis (Minimum Viable Price)

To guarantee profitability, the commercial pricing floor must cover:
$$\text{Price Floor} = \text{Marginal Support Cost} + \left( \frac{\text{Fixed Annual Overhead}}{\text{Target Tenant Volume}} \right) + \text{Target Profit Margin}$$

Assuming a conservative launch volume of **10 initial tenants**:

### Scenario A: Self-Hosted Business Edition (10 Tenants)
- Fixed Cost Allocation: $\$1,289 / 10 = \$128.90$ / tenant / year
- Variable Marginal Cost: $\$98.40$ / tenant / year
- Total Cost of Delivery: **$227.30 / year (RM 1,045 / year)**
- **Absolute Minimum Price Floor (Break-even):** $20/month or $230/year.
- **Recommended Price Floor (60%+ Margin):** **$49/month or $490/year (approx RM 2,250/year)**.

### Scenario B: Enterprise White-Label Partner (Franchise / Agency)
- Dedicated Setup & Token Engineering: ~8 hours one-time (RM 600 cost)
- Annual Dedicated Support & Updates: ~$600 / year (RM 2,760 / year)
- Fixed Cost Contribution: ~$200 / year
- Total Cost of Delivery: **~$800–$1,000 / year**
- **Recommended Enterprise Floor:** **$199–$299/month ($2,388–$3,588/year or RM 10,900–RM 16,500/year)**, yielding an **80%+ gross margin**.

---

## 6. Phase 4 Exit Criteria Checklist

- [x] **Comprehensive cost categorization** (Hosting, Licensing, Support, Signing, QA, CDN) completed.
- [x] **Baseline fixed annual product run-rate** calculated:
  - Lean tier: **$340 / year (RM 1,556 / year)**
  - Production enterprise tier: **$1,289 / year (RM 5,923 / year)**
- [x] **Per-tenant marginal cost** modeled for both Self-Hosted ($98.40/yr supported; $2.40/yr self-serve) and Managed Cloud ($307.20/yr).
- [x] **Support tier SLA matrix and cost impact** established.
- [x] **Commercial price floors** ($490/yr for Business, $2,400+/yr for Enterprise) mathematically established to feed directly into Phase 5.

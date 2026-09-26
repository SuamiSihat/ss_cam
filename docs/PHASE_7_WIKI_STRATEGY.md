# SS-CAM Phase 7: Documentation — Public Wiki Strategy & Architecture

**Document Version:** 1.0.0  
**Status:** Completed & Validated  
**Prerequisites:** Phase 3/3a (Plugin & TenantConfig Engine), Phase 6 (Distribution Hub)  
**Deliverable:** Two-Wiki Doctrine, Structural Isolation Pipeline, Public Wiki Articles, and Automated Leakage Auditing

---

## 1. The Two-Wiki Doctrine

A common failure mode in software commercialization is attempting to use a **single documentation repository with manual filtering tags**. In practice, developers inevitably forget to tag internal server names, proprietary paths, or company credentials, leading to accidental leakage of sensitive infrastructure details to customers.

SS-CAM enforces **Structural Isolation by Construction**:
- **Internal Ops Wiki:** Hand-maintained; contains the full internal infrastructure reality (Synology DS920+ physical topology, internal credential rules, proprietary subsidiary codes, and release publishing scripts).
- **Public Product Wiki:** Generated strictly from Core-layer specifications and generic documentation; audited by automated pre-commit scanning scripts against the Phase 0 coupling blacklist.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     THE TWO-WIKI REPOSITORY TOPOLOGY                                  │
├──────────────────────────────────────────┬─────────────────────────────────────────────────────────────┤
│ 1. INTERNAL OPS WIKI                     │ 2. PUBLIC PRODUCT WIKI                                      │
├──────────────────────────────────────────┼─────────────────────────────────────────────────────────────┤
│ • Path: `AGENTS.md`, `QA/`, `.agents/`   │ • Path: `docs/public-wiki/` (Published to `getcam.dev/docs`)│
│ • Audience: SuamiSihat Core Engineering  │ • Audience: Customers, Studio IT, White-Label Partners      │
│ • Scope: Internal QA, Synology NAS setup,│ • Scope: Onboarding, Synology Docker guides, TenantConfig   │
│   credential governance, git pipelines   │   schema, plugin APIs, pre-flight troubleshooting           │
│ • Contains: Internal hostnames, secrets  │ • Enforced Rule: ZERO proprietary or internal references   │
│ • Verification: `verify-sscam.ps1`       │ • Verification: `audit-public-docs.ps1` (Automated scan)    │
└──────────────────────────────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## 2. Public Wiki Content Structure

The public product wiki is organized into five foundational pillars:

```text
docs/public-wiki/
├── README.md                  # Documentation Portal Overview & Navigation Index
├── 01-GETTING-STARTED.md      # System Requirements, Windows Setup & Docker Installation
├── 02-TENANT-CONFIG-SPEC.md   # Complete JSON Schema Reference for White-Labeling
├── 03-PLUGIN-SYSTEM.md        # Modular Plugin Architecture (IAppPlugin & Registry)
└── 04-TROUBLESHOOTING.md      # LAN SMB Setup, Network Diagnostics & FAQ
```

---

## 3. Automated Leakage Prevention Pipeline

To guarantee that no internal SuamiSihat hostnames, NAS paths, or confidential parameters leak into the public documentation, we implement an automated validation script: [`docs/scripts/audit-public-docs.ps1`](file:///d:/HaNa_Innovation/ss_cam/docs/scripts/audit-public-docs.ps1).

### Blacklisted Patterns Enforced by CI/CD:
- `suamisihat` (case-insensitive)
- `suamisihat.myds.me`
- `assets.suamisihat.myds.me`
- `creative.suamisihat.myds.me`
- `radio.suamisihat.myds.me`
- `SSNAS`
- `\\SSNAS\`
- `00_logo_SuamiSihat`
- `SuamiSihat123!`

If any blacklisted token is discovered in `docs/public-wiki/`, the build process halts immediately with Exit Code 1.

---

## 4. Phase 7 Exit Criteria Checklist

- [x] **Two-Wiki Doctrine codified** establishing strict structural isolation.
- [x] **Public documentation suite authored** under `docs/public-wiki/` (Getting Started, TenantConfig Schema, Plugin System, Troubleshooting).
- [x] **Automated leakage auditing script created** (`docs/scripts/audit-public-docs.ps1`) to prevent accidental internal reference commits.
- [x] **Zero internal references verified** across all public-facing customer documentation.

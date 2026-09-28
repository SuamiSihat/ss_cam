# SS-CAM FIX LOG

## Fix: Phase 5 — Verification & Release Preparation (Branch: fix/p5-release) — 2026-09-28
- **Ecosystem Test Suite & Build Verification (Task 5.1)**:
  - Executed full automated verification across all platforms:
    - **Combined Web Suite (`npm test`)**: **56 Passed, 0 Failed (100% PASS)** (49 unit/integration + 7 admin smoketests).
    - **Source Guardian (`QA/verify-sscam.ps1 -Fix`)**: **13 passed, 0 warned, 0 failed (100% PASS)**.
    - **Master Dual-Track Gatekeeper (`QA/verify-dual-track.ps1 -Fix -Build`)**: **3/3 Stages PASS** (Source Guardian, Public Documentation Leakage Check, and WPF MSBuild Release Compile producing `src/SS-CAM/bin/Release/SS-CAM.exe` — 6,126,592 bytes).
    - **Android Companion App**: `./gradlew.bat assembleDebug` **PASS** (`BUILD SUCCESSFUL in 1s`, 35 tasks up-to-date); `./gradlew.bat assembleRelease` **PASS** (`BUILD SUCCESSFUL in 2m 15s`, 46 tasks executed; release APK compiled cleanly with dynamic fallback to debug/unsigned mode when keystore is omitted).
    - **Linux Desktop (Avalonia)**: Formally documented as **BLOCKED** on this host build machine due to missing .NET 10 SDK / `dotnet` executable on PATH (documented risk).
    - **Web Client Vite Bundle**: `npm run build:client` **PASS** (2,267 modules transformed in 15.83s producing clean `dist/` bundle).
- **Human Staging Verification Runbook (Task 5.2)**:
  - Authored `QA/STAGING-VERIFICATION-RUNBOOK.md` detailing the isolated staging environment setup on port 3001 with 5 mandatory release gate verification checks (empty password 401, default password 401, old secret token 401, Designer RBAC 403 with `SECURITY_ACCESS_DENIED` audit logging, and 6th-attempt login rate limiting 429).
- **Human Production Deployment & Monitoring Runbook (Task 5.3)**:
  - Authored `QA/PRODUCTION-DEPLOYMENT-RUNBOOK.md` detailing Synology NAS Docker deployment prerequisites, config backups, `.env` parameterization, container pull/rebuild, incognito smoke tests, and 48-hour `audit-log.jsonl` stream monitoring.
- **Canonical Release Version Synchronization to 4.11.1 (Task 5.4)**:
  - Synchronized release version **`4.11.1`** across all ecosystem metadata:
    - `installer/version.json`: `"version": "4.11.1"`
    - `src/SS-CAM/Properties/AssemblyInfo.cs`: `AssemblyVersion("4.11.1.0")`, `AssemblyFileVersion("4.11.1.0")`
    - `src/SS-CAM.Linux/SS-CAM.Linux.csproj`: `<Version>4.11.1</Version>`
    - `src/SS-CAM.Web/package.json`: `"version": "4.11.1"`
    - `src/SS-CAM.Web/server/config.js`: `VERSION: '4.11.1'`
    - `src/SS-CAM.Android/app/build.gradle.kts`: `versionName = "4.11.1"`, `versionCode = 4111`
- **Comprehensive Changelog & Release Notes (Task 5.5)**:
  - Updated `CHANGELOG.md` with an exhaustive entry for `[4.11.1] - 2026-09-28` detailing security hardening, RBAC enforcement, repository hygiene, code quality improvements, and verification results across all five remediation phases.
  - Documented exact `git tag -a v4.11.1 -m "..."` release tagging command for human execution.
- **Test Teardown Libuv Handle Cleanup (Task 5.6)**:
  - Resolved Windows libuv handle teardown assertion in `src/SS-CAM.Web/server/test/admin-smoketest.js` by adding an asynchronous event-loop tick (`setTimeout(100ms)`) before process exit, ensuring `admin-smoketest.js` exits with status code 0 cleanly.

## Fix: Phase 4 — Dependencies and Code Quality (Branch: fix/p4-quality) — 2026-09-28
- **Safe Dependency Vulnerability Remediation (Task 4.1, N1)**:
  - Executed safe, non-breaking `npm audit fix` in `src/SS-CAM.Web`.
  - Resolved high-severity vulnerability in `js-yaml` (Prototype Pollution via Merge Keys) and moderate-severity vulnerabilities in `qs`, `body-parser`, `express`, and `devalue`.
  - Intentionally rejected `npm audit fix --force` to prevent breaking changes to `@sveltejs/vite-plugin-svelte@3.1.2` (which requires `vite@^5` and is incompatible with `vite@^8`).
- **Silent Catch Block Elimination Across All Platforms (Task 4.2, Q1)**:
  - Audited and eliminated empty/silent `catch {}` blocks across the repository, replacing them with structured diagnostic logging:
    - **WPF (3 instances)**: `MainWindow.xaml.cs` (lines 1149, 1212) and `Services/RadioStreamService.cs` (line 1447) updated with `System.Diagnostics.Debug.WriteLine`.
    - **Linux Avalonia (17 instances across 10 files)**: `ClipboardService.cs`, `CopywritingDesktopService.cs`, `CreativeOrderService.cs`, `MalaysiaHolidayService.cs`, `QuickNoteService.cs`, `RadioStreamService.cs`, `WellbeingDataService.cs`, `WorkspaceScanner.cs`, `WorkstationHealthService.cs`, `MainViewModel.cs` updated with `Debug.WriteLine`.
    - **Web Services & Scripts (44+ instances across 15 files)**: `config.js`, `routes/api.js`, `CompanyService.js`, `CopywritingService.js`, `DeliverableService.js`, `ExportService.js`, `FrontmatterService.js`, `GeminiService.js`, `OrderService.js`, `ShareService.js`, `SnapshotService.js`, `TeamService.js`, `WebhookService.js`, `WorkspaceService.js`, `reset-portal-data.js` updated with structured `console.debug`.
  - Scanner verification confirmed: **WPF catches: 0, Linux catches: 0, Web non-test catches: 0**.
- **Synchronous Method Deprecation in PrayerTimeService (Task 4.3, T1)**:
  - Marked synchronous `FetchToday(string zone)` in `src/SS-CAM/Services/PrayerTimeService.cs` with `[Obsolete("FetchToday synchronously blocks the caller. Use FetchTodayAsync instead.", false)]`.
  - Prevents UI thread freezes and thread pool starvation while maintaining binary backward compatibility.
- **Cross-Platform Version Alignment (Task 4.4, V1)**:
  - Aligned all sub-projects to release version **`4.11.0`**:
    - `src/SS-CAM.Linux/SS-CAM.Linux.csproj` (`<Version>` bumped from `4.10.2` to `4.11.0`).
    - `src/SS-CAM.Web/package.json` (`"version"` bumped from `4.10.2` to `4.11.0`).
    - `src/SS-CAM.Web/server/config.js` (`VERSION` constant bumped from `4.9.0` to `4.11.0`).
  - Confirmed parity with `installer/version.json` (4.11.0), `src/SS-CAM/Properties/AssemblyInfo.cs` (4.11.0.0), and `src/SS-CAM.Android/app/build.gradle.kts` (4.11.0 / versionCode 33).
- **Svelte {@html} Audit & DOMPurify Hardening (Task 4.5, X1)**:
  - Audited all Svelte components rendering raw HTML via `{@html}`:
    - `src/SS-CAM.Web/client/src/lib/components/markdown/MermaidViewer.svelte`: Set Mermaid configuration `securityLevel: 'strict'` and wrapped SVG output with `DOMPurify.sanitize(svg, { USE_PROFILES: { svg: true } })`.
    - `src/SS-CAM.Web/client/src/lib/views/CopyStudioView.svelte`: Sanitized `formatWhatsAppText` output with `DOMPurify.sanitize(formatted, { ALLOWED_TAGS: ['strong', 'em', 'del', 'br', 'i', 'b'], ALLOWED_ATTR: [] })`.
  - Client bundle compiled cleanly: `npm run build:client` transformed 2,267 modules in 16.53s.
- **Authorized Project Creation Endpoint (Task 4.6, A1)**:
  - Implemented `POST /api/projects` in `src/SS-CAM.Web/server/routes/api.js` protected with `authenticateToken` and `requirePermission('project:create')`.
  - Added `'project:create'` permission to `designer`, `copywriter`, `user`, `Designer`, `Copywriter` in `auth.js`.
  - Implemented canonical project directory scaffolding (`01_BRIEF_ASSETS`, `02_SOURCE_FILES`, `03_COPYWRITING`, `04_WORK_IN_PROGRESS`, `05_DELIVERABLES`), `README.md` with YAML frontmatter, `COPY.md`, workspace cache rescan, audit logging (`PROJECT_CREATED`), and SSE event broadcast (`project:created`).
  - Added automated test #49 to `src/SS-CAM.Web/server/test/run-tests.js` validating unauthenticated rejection (401), invalid payload validation (400), and successful project scaffolding (201).
- **Source Guardian Web Security Checks (Task 4.7, G1)**:
  - Extended `QA/verify-sscam.ps1` with 3 automated web security verification checks:
    - Check 11: Web Production JWT_SECRET Enforcement (scans `config.js` for `NODE_ENV === 'production'` and `process.exit(1)`).
    - Check 12: Web RBAC Canonical Role Matching (scans `routes/api.js` to ensure no loose `role.includes('admin')` calls exist).
    - Check 13: Web Rate Limiting on Login (scans `routes/api.js` for `rateLimit` protection on `/auth/login`).
  - Source Guardian execution: **13 passed / 0 warned / 0 failed (100% PASS)**.
- **Documentation & QA Report Alignment (Task 4.8, W1)**:
  - Updated `QA/FINAL-QA-REPORT.md` to document the 56 passing automated test assertions, 13 Source Guardian checks, and security remediations across Phases 1–4.
- **Docker Compose Production Hardening (Task 4.9, D1)**:
  - Updated `src/SS-CAM.Web/docker-compose.yml` to execute `npm install --omit=dev` before starting the production server, ensuring devDependencies are not installed in production containers.
- **Verified Automated Test Execution (`server/test/run-tests.js`, `server/test/admin-smoketest.js`)**:
  - `POST /api/projects: unauthenticated returns 401, missing fields returns 400, valid payload creates directory scaffold and returns 201`: **PASS**
  - Total `run-tests.js`: **49 Passed, 0 Failed (100% PASS)**
  - Total `admin-smoketest.js`: **7 Passed, 0 Failed (100% PASS)**
  - Total Automated Suite: **56 Passed, 0 Failed (100% PASS)**
  - Source Guardian: `verify-sscam.ps1 -Fix`: **13 passed, 0 warned, 0 failed (100% PASS)**
  - Client Build: `npm run build:client`: **PASS (16.53s)**

## Fix: Phase 3 — Secrets, Repository & Asset Hygiene (Branch: fix/p3-repo) — 2026-09-28
- **Android Keystore Security & Dynamic Signing (Task 3.1, C3)**:
  - Untracked release keystore `src/SS-CAM.Android/app/sscam-release.jks` from git index (`git rm --cached`) while preserving the binary on local disk for local developer use (`Test-Path` returned `True`).
  - Rewrote `src/SS-CAM.Android/app/build.gradle.kts` signing configuration: eliminated hardcoded plaintext passwords (`storePassword`, `keyPassword`).
  - Implemented dynamic signing credential resolution order: local `keystore.properties` (root or app directory) -> environment variables (`KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) -> graceful fallback to debug signing configuration with an informative lifecycle warning log so open-source contributors can build without keys.
  - Added glob patterns for `*.jks`, `*.keystore`, and `keystore.properties` / `**/keystore.properties` to `.gitignore`.
  - Created `QA/KEY-ROTATION-RUNBOOK.md` detailing the Google Play Console upload key reset procedure via Play App Integrity / App Signing with `keytool -genkeypair` and PEM certificate export (`keytool -exportcert -rfc`).
  - Verified Android build: `./gradlew.bat assembleDebug` passed (`BUILD SUCCESSFUL in 17s`, 35 actionable tasks up-to-date).
- **Untrack Ignored Files & Binaries from Git Index (Task 3.2, R1)**:
  - Untracked build outputs, dependencies, and binaries from git tracking via `git rm -r --cached`:
    - `src/SS-CAM.Web/node_modules/` (1,013 files)
    - `src/SS-CAM.Web/client/dist/` (18 files)
    - `publish/` (5 Linux binaries and tarballs, ~136 MB total including 96 MB `SS-CAM.Linux` binary)
    - `installer/*.zip` (1 zip, ~40 MB `SS-CAM-v4.6.0-linux-x64-nav-fix.zip`)
    - `src/nuget.exe` (1 standalone binary, 8 MB)
  - Verified physical disk persistence: all files remain 100% physically intact on disk via PowerShell `Test-Path` (`True`).
  - Confirmed `.gitignore` comprehensively ignores `node_modules/`, `dist/`, `publish/`, `installer/*.zip`, `*.zip`, and `nuget.exe`.
- **Affinity Designer Assets (`.afassets`) Strategy (Task 3.3, R1)**:
  - Evaluated `payload/Brand Assets/Libraries/SuamiSihat Branding.afassets` (43.27 MB / 45.37 MB on disk). Confirmed that proprietary binary zip/SQLite structure produces full ~43 MB uncompressed history bloat per revision with zero delta compression.
  - Recommended Git LFS tracking (`git lfs track "*.afassets"`) or external distribution via GitHub Releases for large proprietary creative asset bundles.
- **Third-Party Asset Licensing Audit (Task 3.4, L1)**:
  - Created `docs/THIRD-PARTY-ASSETS.md` cataloging bundled fonts, audio, icons, and libraries.
  - Flagged critical legal redistribution prohibitions: Font Awesome Pro 5.8.1 (commercial license strictly prohibits public redistribution of font binaries/SVGs), commercial typography (Helvetica Neue, Calibri, TacticSans, Banaue Extended).
  - Provided mitigation roadmap: replace commercial fonts with open-source Google Fonts (Inter, Outfit, Plus Jakarta Sans) and switch Font Awesome Pro to Font Awesome Free (SIL OFL 1.1 / MIT).
- **Git History Purge & Size Reduction Runbook (Task 3.5, R1)**:
  - Created `QA/HISTORY-PURGE-RUNBOOK.md` detailing the operational procedure to purge historical secrets, keystores, and oversized binaries from git history using `git-filter-repo`.
  - Documented exact commands, safety backups, verification checks, force-push coordination, and collaborator recovery steps.
- **Verification & Parity Results**:
  - Android Build: `./gradlew.bat assembleDebug` **PASS** (17s).
  - Web Unit Suite: `node server/test/run-tests.js` **48 Passed, 0 Failed (100% PASS)**.
  - Web Admin Smoketest: `node server/test/admin-smoketest.js` **7 Passed, 0 Failed (100% PASS)**.
  - Source Guardian: `verify-sscam.ps1 -Fix` verified.

## Fix: Phase 2 — Authorization & RBAC Hardening (Branch: fix/p2-authz) — 2026-09-28
- **Route Authorization Audit (Task 2.1)**:
  - Created `QA/scripts/generate-route-authz-matrix.js` and generated `QA/ROUTE-AUTHZ-MATRIX.md`. Audited all 85 Express routes in `src/SS-CAM.Web/server/routes/api.js`.
  - Categorized all routes into public (unauthenticated), authenticated staff, and admin-only endpoints.
- **Canonical Role Matching & Elimination of Loose Substrings (Task 2.2 & 2.3, C5)**:
  - Added granular admin permissions (`admin:users`, `admin:roles`, `admin:companies`, `admin:system`, `admin:projects`, `admin:system_audit`) to `ROLE_PERMISSIONS` in `auth.js`.
  - Implemented and exported `hasCanonicalRole(user, targetRole)` with exact match logic (`admin`, `administrator`), rejecting substring bypasses (`admin_assistant`, `subadmin`, etc.).
  - Replaced all ad-hoc `role.includes('admin')` substring checks across `src/SS-CAM.Web/server/routes/api.js` with `requireRole('admin')` and `hasCanonicalRole`.
- **Handler Unification & Backward Compatibility (Task 2.4)**:
  - Merged `/users` and `/team/roster` handler logic into canonical `handleCreateStaffUser` and `handleUpdateStaffUser` in `routes/api.js`.
  - Both routes preserved for API backward compatibility across desktop, mobile, and web clients (per `AGENTS.md` KEEP/MERGE/REMOVE/DIFFERENTIATE governance).
- **Last-Admin Protection & Anti-Escalation (Task 2.5)**:
  - Implemented last-admin check in `handleUpdateStaffUser` and `DELETE /api/users/:id`: rejects deactivation (`active: false`), demotion (removing admin role), or deletion if `activeAdmins.length <= 1` with HTTP 400 (`Cannot deactivate or demote the last remaining administrator account.` / `Cannot delete the last remaining administrator account.`).
  - Anti-escalation in `PUT /api/auth/profile`: non-admin callers cannot alter their own `role` or `roles`; attempted privilege escalation is discarded while safe profile fields (name, email, department) are updated.
  - Self-service password changes gated via dedicated `POST /api/auth/change-password` requiring `currentPassword` validation and minimum 10-character complexity.
- **Structured Audit Logging for Access Denials (Task 2.6)**:
  - Every HTTP 403 response in `requireRole` and `requirePermission` logs structured `SECURITY_ACCESS_DENIED` and `SECURITY_PERMISSION_DENIED` events to `AuditService` with actor, endpoint, and required role/permission.
- **Client-Side UX Gating (Task 2.7)**:
  - Gated Administration sidebar link and profile menu in `App.svelte` using derived `isAdmin` state. Clarified gating as UX only; real security is enforced strictly by backend API middleware.
- **Verified Automated Test Execution (`server/test/run-tests.js`, `server/test/admin-smoketest.js`)**:
  - `Last-admin protection: cannot deactivate, demote, or delete the last active administrator`: **PASS**
  - `Anti-escalation: non-admin caller cannot modify role or roles via PUT /api/auth/profile`: **PASS**
  - `Self-service password change: enforces current password verification and 10-char complexity`: **PASS**
  - `Canonical role matching: fuzzy roles like admin_assistant or subadmin are rejected from admin routes`: **PASS**
  - `Admin RBAC: Designer gets 403 on mutating routes and logs to AuditService; Admin gets 200`: **PASS**
  - Total `run-tests.js`: **48 Passed, 0 Failed (100% PASS)**
  - Total `admin-smoketest.js`: **7 Passed, 0 Failed (100% PASS)**
  - Total Automated Suite: **55 Passed, 0 Failed (100% PASS)**
- **Client Build Verification**:
  - `npm run build:client`: **PASS** (Vite built 2,267 modules in 16.01s generating valid `dist/` bundle).

## Fix: Phase 1 — Authentication Hardening (Branch: fix/p1-auth) — 2026-09-28
- **Password Verification & Bcrypt Lazy Migration (Task 1.1, C1)**:
  - `src/SS-CAM.Web/server/middleware/auth.js`: Rewrote `verifyUserPassword` to immediately reject empty, whitespace, null, or non-string passwords with `false`.
  - Removed all shared default password fallbacks (`SuamiSihat123!` / `DEFAULT_PASSWORD`).
  - Implemented `bcryptjs.compareSync` for hashed credentials.
  - Implemented automatic lazy upgrade: existing plaintext passwords matching input are dynamically upgraded to bcrypt hashes (`bcrypt.hashSync(password, 10)`) and saved atomically on first successful authentication.
- **Emergency Admin Bootstrap Recovery (Task 1.2)**:
  - `src/SS-CAM.Web/server/middleware/auth.js`: Integrated `ADMIN_BOOTSTRAP_PASSWORD`. Honored strictly when NO admin user has an existing password in the credential store.
  - Once any admin password entry exists, `ADMIN_BOOTSTRAP_PASSWORD` is completely ignored, eliminating environment variable hijacking risks while preventing permanent lockouts on fresh deployments.
- **Production `JWT_SECRET` Hardening (Task 1.3, C2)**:
  - `src/SS-CAM.Web/server/config.js`: Enforced that when `NODE_ENV=production`, the server strictly halts execution (`process.exit(1)`) if `JWT_SECRET` is missing, empty, or shorter than 32 characters.
  - `src/SS-CAM.Web/docker-compose.yml`: Parameterized `${JWT_SECRET:?JWT_SECRET must be configured in .env}` and configured `DATA_DIR=/app/data`.
  - `src/SS-CAM.Web/.env.example`: Created comprehensive environment variable documentation template.
  - `.gitignore`: Guaranteed `.env` and `data/` directories are ignored while allowing `.env.example`.
- **Isolated Credential Storage `DATA_DIR` (Task 1.4, C4)**:
  - `src/SS-CAM.Web/server/config.js`, `src/SS-CAM.Web/server/middleware/auth.js`: Redirected `getPasswordStorePath()` from shared workspace (`<WORKSPACE_ROOT>/_Team/_Config/user_passwords.json`) to isolated `DATA_DIR` (default `./data/user_passwords.json`).
  - Added safe automated one-time migration: copies existing passwords to `DATA_DIR` and archives the legacy workspace file with `.migrated.<timestamp>` extension without data loss.
- **Password Reset Complexity & UI Default Removal (Task 1.5)**:
  - `src/SS-CAM.Web/server/routes/api.js`: Enforced minimum 10-character password requirement on `POST /api/users/:username/reset-password` and `handleCreateStaffUser`. Missing or $< 10$ character passwords return HTTP 400.
  - `src/SS-CAM.Web/client/src/lib/views/AdminView.svelte`: Updated user account provisioning and password reset modal validation and labels to enforce minimum 10 characters (`min 10 chars`). All pre-filled default passwords eliminated.
- **Rate Limiting & Credential Enumeration Protection (Task 1.6, H1, H4)**:
  - `src/SS-CAM.Web/server/routes/api.js`: Rate-limited `POST /api/auth/login` using `express-rate-limit` (5 failed attempts per 15 minutes; returns HTTP 429 on 6th attempt).
  - Normalized login failure response to identical HTTP 401 `{ error: 'Invalid credentials. Please verify your username and password.' }` for both unknown users and incorrect passwords.
  - Implemented dummy `bcrypt.compareSync` on unknown user lookups to mitigate side-channel timing analysis.
- **Strict CORS, 1MB Body Limit & Helmet Security Headers (Task 1.7, H1)**:
  - `src/SS-CAM.Web/server/index.js`: Integrated `helmet` with Content Security Policy tuned specifically for Svelte client, Vite bundle assets, and Mermaid SVG/web worker diagram rendering.
  - Enforced 1MB request body limit (`express.json({ limit: '1mb' })`).
  - Enforced CORS allowlist against `config.ALLOWED_ORIGINS` with desktop/mobile client support.
- **Token Lifetime Formalization (Task 1.8)**:
  - Formalized **12-hour session lifetime** (`JWT_EXPIRES_IN=12h`) in `config.js` and `auth.js`, replacing the overly permissive 7-day token duration.
- **Verified Automated Test Execution (`server/test/run-tests.js`, `server/test/admin-smoketest.js`)**:
  - `Authentication security: empty password -> 401, default password -> 401, correct password -> 200, with bcrypt lazy migration`: **PASS**
  - `Login enumeration protection: non-existent user and wrong password return identical HTTP 401 error`: **PASS**
  - `Admin bootstrap password: honored only when no admin password exists; ignored once set`: **PASS**
  - `Production configuration security: server exits non-zero without strong JWT_SECRET (>= 32 chars) when NODE_ENV=production`: **PASS** (verified empty secret, 24-char secret, and valid 64-char secret)
  - `Login rate limiting: 6th rapid failed login on /auth/login returns HTTP 429`: **PASS**
  - `Password reset security: explicit newPassword of min 10 chars enforced`: **PASS**
  - `DATA_DIR migration: legacy workspace password file is migrated to DATA_DIR and archived`: **PASS**
  - `Security headers & body limit: Helmet sets nosniff CSP and >1MB payload returns 413`: **PASS**
  - `JWT configuration: token lifetime is configured to 12 hours`: **PASS**
  - Total `run-tests.js`: **44 Passed, 0 Failed (100% PASS)**
  - Total `admin-smoketest.js`: **7 Passed, 0 Failed (100% PASS)**
  - Total Automated Suite: **51 Passed, 0 Failed (100% PASS)**
- **Client Build Verification**:
  - `npm run build:client`: **PASS** (Vite built 2,267 modules in 21.30s generating valid `dist/` bundle).

## Fix: Untrack Ignored Files, Parity Cleanup & History Size Reduction Proposal — 2026-09-28 (Branch: fix/untrack-ignored-files)
- **Untracked Ignored Files from Git Index (`git rm -r --cached`)**:
  - `src/SS-CAM.Web/node_modules/`: 1,013 files removed from git tracking.
  - `src/SS-CAM.Web/client/dist/`: 18 pre-compiled Vite bundle files removed from git tracking.
  - `publish/`: 5 Linux binaries and tarballs (including 96 MB `SS-CAM.Linux` and 40 MB `ss-cam-linux-x64.tar.gz`) removed from git tracking.
  - `installer/*.zip`: 1 archive (`installer/SS-CAM-v4.6.0-linux-x64-nav-fix.zip`, ~40 MB) removed from git tracking.
  - `src/nuget.exe`: 8 MB standalone binary removed from git tracking.
  - Disk persistence: Verified all files remain 100% physically intact on disk via `Test-Path` (`True`).
- **`.gitignore` Parity Overhaul**:
  - Expanded root `.gitignore` to comprehensively cover `dist/`, `**/dist/`, `publish/`, `**/publish/`, `installer/*.zip`, `*.zip`.
  - Confirmed working directory cleanliness: no untracked file clutter (`??`) introduced by the cache removal.
- **Affinity Assets (`.afassets`) Git LFS Decision (Proposal)**:
  - `payload/Brand Assets/Libraries/SuamiSihat Branding.afassets` (43.27 MB): Recommended for **Git LFS** or external release distribution. Proprietary binary zip/SQLite structure produces full ~43 MB uncompressed history bloat per revision with zero delta compression.
  - `payload/Brand Assets/Libraries/ss_health_branding.afassets` (0.51 MB): Kept in standard Git (minimal 510 KB size does not warrant LFS quota consumption).
- **History Reduction Runbook (`QA/REPO-SIZE-REDUCTION-RUNBOOK.md`)**:
  - Analyzed commit history pack database (543.83 MiB total, ~500 MB in top 15 blobs).
  - Drafted comprehensive manual operational runbook with `git-filter-repo` syntax, reflog expiry, and aggressive pruning instructions for user execution.
- **Build Verifications (Clean Checkout Simulation)**:
  - `npm ci` in sandbox workspace (`QA/TestWorkspace`): **PASS** (Clean install from `package-lock.json`, 358 packages added in 12s).
  - `npm run build:client` in `src/SS-CAM.Web`: **PASS** (Vite built 2,267 modules in 17.64s producing valid `dist/` bundle).
  - `msbuild src\SS-CAM\SS-CAM.csproj`: **PASS** (`SS-CAM -> src/SS-CAM/bin/Debug/SS-CAM.exe` compiled cleanly with exit code 0).

## Fix: Android Keystore Security & Signing Hardening — 2026-09-28 (Branch: fix/android-keystore-security)
- **Untracked Release Keystore (`src/SS-CAM.Android/app/sscam-release.jks`)**:
  - Untracked the release keystore binary from the git index (`git rm --cached`) while preserving the actual keystore file intact on local disk (`Test-Path` returned `True`).
- **Gitignore Protection (`.gitignore`)**:
  - Added glob patterns for `*.jks`, `*.keystore`, and `keystore.properties` / `**/keystore.properties` to ensure local keystores and signing secret property files are never committed to git.
- **Dynamic Signing Configuration & Contributor Fallback (`src/SS-CAM.Android/app/build.gradle.kts`)**:
  - Removed hardcoded plaintext passwords (`storePassword`, `keyPassword`) from the Gradle Kotlin DSL build script.
  - Implemented dynamic credential resolution checking `keystore.properties` (in root project or app directory) followed by environment variables (`KEYSTORE_FILE` / `RELEASE_STORE_FILE`, `KEYSTORE_PASSWORD` / `RELEASE_STORE_PASSWORD`, `KEY_ALIAS` / `RELEASE_KEY_ALIAS`, `KEY_PASSWORD` / `RELEASE_KEY_PASSWORD`).
  - Added graceful fallback to `signingConfigs.getByName("debug")` with an informative Gradle lifecycle log when credentials or keystore files are missing, ensuring contributors without signing keys can build seamlessly.
- **Key Rotation & Git History Cleanup Runbook (`QA/KEY-ROTATION-RUNBOOK.md`)**:
  - Created a detailed manual guide outlining:
    - Phase 1: Google Play Console upload key reset procedure (via App Signing / Play App Integrity) with `keytool -genkeypair` and PEM certificate export (`keytool -exportcert -rfc`).
    - Phase 2: Local `keystore.properties` configuration and security best practices.
    - Phase 3: Manual git commit history scrubbing steps using `git-filter-repo` to purge historical blobs and scrub plaintext password occurrences.
- **Test Execution & Verification Results**:
  - `./gradlew.bat assembleDebug` without `keystore.properties`: **PASS** (`BUILD SUCCESSFUL in 3s`, 35 actionable tasks executed/up-to-date; confirms release signing config falls back cleanly).
  - Environment variable credentials evaluation test: **PASS** (`BUILD SUCCESSFUL in 1s`, loads signing credentials when configured).
  - Local keystore disk persistence verification: **PASS** (`Test-Path src/SS-CAM.Android/app/sscam-release.jks` returned `True`).
  - Keystore untracked status verification: **PASS** (deleted in git index, untracked from repository).

## Fix: Admin RBAC Hardening & Mutating Route Protection — 2026-09-28 (Branch: fix/admin-rbac-hardening)
- **Role & Permission Middleware (`src/SS-CAM.Web/server/middleware/auth.js`)**:
  - Implemented and exported `requireRole(...allowedRoles)` middleware enforcing canonical role validation (`admin`, `administrator`).
  - Refactored `requirePermission(permission)`: eliminated loose substring checks (`isAdminOrLead` matching "manager", "lead", "head", "director", etc.) and replaced with canonical admin role verification.
  - Replaced `low.includes('admin')` in `getUserPermissions` and `verifyUserPassword` with canonical role matching.
  - Integrated audit logging: every access denial (HTTP 403) automatically appends a structured `SECURITY_ACCESS_DENIED` or `SECURITY_PERMISSION_DENIED` entry to `AuditService` with actor, role, endpoint, and required role/permission.
- **Mutating Admin Routes Protection (`src/SS-CAM.Web/server/routes/api.js`)**:
  - Protected all mutating admin endpoints with `requireRole('admin')`:
    - `POST /api/users`, `PUT /api/users/:id`, `DELETE /api/users/:id`
    - `POST /api/users/:username/reset-password`
    - `POST /api/team/roster`, `PUT /api/team/roster/:id`
    - `POST /api/companies`, `PUT /api/companies/:code`, `PUT /api/companies`, `DELETE /api/companies/:code`
    - `POST /api/system/workspace-root`
    - `POST /api/admin/restart`
    - `DELETE /api/projects/:id`
  - Merged duplicate handler implementations for `/users` and `/team/roster` into unified canonical functions `handleCreateStaffUser` and `handleUpdateStaffUser` (per `AGENTS.md` KEEP/MERGE/REMOVE/DIFFERENTIATE governance: merged backend logic while preserving both endpoints for client backward compatibility).
  - Replaced manual `role.includes('admin')` substring checks in `/system/workspace-root`, `/admin/restart`, and `/projects/:id`.
- **Client-Side UX Gating (`src/SS-CAM.Web/client/src/App.svelte`)**:
  - Added reactive `isAdmin` check derived from `appState.currentUser`.
  - Filtered `navGroups` so the `System & Governance` section (Administration link) is hidden from non-admin users in the sidebar.
  - Gated the Administration item in the user profile dropdown menu with `{#if isAdmin}`.
  - Clarified gating as UX only; real security is enforced strictly by the backend API.
- **Test Execution & Verification Results**:
  - `server/test/run-tests.js`: **39/39 PASS** (including: Designer token receives 403 on all 11 mutating admin endpoints; AuditService records `SECURITY_ACCESS_DENIED` logs for each denial; Admin token receives 200 on all mutating admin endpoints).
  - `server/test/admin-smoketest.js`: **7/7 PASS**.
  - Total automated test suite: **46 Passed, 0 Failed (100% PASS)**.

## Fix: Authentication & Security Hardening — 2026-09-28 (Branch: fix/auth-security-hardening)
- **Password Verification & Bcrypt Hashing Overhaul (`src/SS-CAM.Web/server/middleware/auth.js`)**:
  - Eliminated empty password bypass and removed the hardcoded shared default password across all authentication logic.
  - Upgraded password storage to `bcryptjs` (salt rounds: 10).
  - Implemented lazy migration: existing legacy plaintext passwords in `user_passwords.json` validate on first login and are immediately hashed to bcrypt format and saved.
  - Implemented emergency admin bootstrap recovery path: if an admin user has no entry in `user_passwords.json`, they can authenticate on first run using `process.env.ADMIN_BOOTSTRAP_PASSWORD`. On success, it is hashed and saved to disk.
  - Enforced minimum 8-character length on all password updates.
- **Production Configuration & Secret Enforcement (`src/SS-CAM.Web/server/config.js`, `docker-compose.yml`, `.gitignore`)**:
  - Enforced that when `NODE_ENV=production`, the server strictly halts execution (`process.exit(1)`) if `JWT_SECRET` is missing or empty.
  - Added `.env` exclusion rules to `.gitignore`.
  - Exported `ALLOWED_ORIGINS` configured via `process.env.ALLOWED_ORIGINS` with secure local development and production portal defaults.
- **Password Reset Security (`src/SS-CAM.Web/server/routes/api.js`)**:
  - Removed fallback to default password on `POST /api/users/:username/reset-password`.
  - Strictly requires an explicit `newPassword` of at least 8 characters.
- **Client Security Hardening (`src/SS-CAM.Web/client/src/lib/views/AdminView.svelte`)**:
  - Removed all pre-filled default passwords from state, account provisioning form, and password reset modals.
  - Enforced mandatory temporary password entry (minimum 8 characters) during user creation and password resets.
- **Rate Limiting, CORS & Body Limits (`src/SS-CAM.Web/server/index.js`, `routes/api.js`)**:
  - Added `express-rate-limit` on `POST /api/auth/login` (5 attempts / 15 minutes, returning HTTP 429 Too Many Requests on the 6th attempt).
  - Restricted CORS origin to `config.ALLOWED_ORIGINS` while allowing originless requests (native desktop app, curl, mobile app).
  - Reduced JSON and URL-encoded request body size limits from 50MB to 1MB (preserving multer limits for file uploads).
- **Test Execution & Verification Results**:
  - `server/test/run-tests.js`: **38/38 PASS** (including: empty password -> 401, default password -> 401, correct password -> 200, bcrypt lazy migration -> PASS, production exit without JWT_SECRET -> PASS, 6th rapid login attempt -> 429 PASS, password reset length validation -> PASS).
  - `server/test/admin-smoketest.js`: **7/7 PASS**.
  - Total automated test suite: **45 Passed, 0 Failed (100% PASS)**.

## v4.11.0 — 2026-09-27 (Dual-Track Commercialization Architecture, Multi-Tenant Plugin Engine & Open-Core Governance)
- **Modular Multi-Tenant Plugin Engine (`IAppPlugin`, `PluginRegistry`)**:
  - Abstracted auxiliary features (`WaktuSolatPlugin`, `RadioPlayerPlugin`, `QrCodeStudioPlugin`, `CreativeWellbeingPlugin`) into self-contained plugins implementing canonical `IAppPlugin` interface.
  - Dynamically registers navigation items in `MainWindow.xaml.cs` and Command Palette launcher (`CommandPaletteService.cs`) based on tenant capability enablement.
  - Added in-app **Pluggable Modules** management card in `SettingsPage.xaml` with Fluent 2 `<ui:ToggleSwitch>` controls and immediate hot-reload (`MainWindow.RefreshPluginNavigation()`) without requiring app restart.
- **Dynamic Tenant Configuration Engine (`TenantConfigService`)**:
  - Implemented `TenantConfig.cs` and `TenantConfigService.cs` supporting dynamic corporate branding, brand color palettes (`brandPrimary`, `brandTint`, `brandNavy`), custom endpoints, and category presets without binary recompilation.
  - Neutralized proprietary SuamiSihat literals across 20+ WPF views and services with generic enterprise fallbacks.
- **Commercial Distribution & Public Knowledge Base Suite (Phases 4–7)**:
  - Authored financial cost models (`docs/PHASE_4_COST_MODELLING.md`) and commercial pricing tiers (`docs/PHASE_5_REVENUE_GTM.md`).
  - Built Fluent 2 dark glassmorphic commercial landing portal (`docs/commercial-landing/`) featuring an interactive pricing tier switcher ($0 Community Core, $490/yr Studio Business, $2,290/yr Enterprise White-Label).
  - Published clean, isolated customer documentation (`docs/public-wiki/`) and automated leakage detection scanner (`docs/scripts/audit-public-docs.ps1`).
- **Dual-Track Single-Trunk Governance (`QA/verify-dual-track.ps1`)**:
  - Created automated 3-stage pre-flight gatekeeper validating Source Guardian compliance, zero public reference leakage, and Release build compilation.
  - Codified dual-track open-core governance in `AGENTS.md` and `.agents/AGENTS.md`.
- **End-to-End Release Verification**:
  - Dual-Track Master Gatekeeper: 3/3 Stages PASS (100%).
  - Web Portal Test Suite: 34/34 PASS.
  - Windows Desktop MSBuild: PASS (`dist/SS-CAM-v4.11.0.exe` & `dist/SS-CAM.exe` — 6,126,592 bytes).

## v4.10.2 — 2026-09-26 (Cross-Platform 4-Date Schema Synchronization, Brief Attachment Handover & Universal Markdown Studio)
- **Universal 4-Date Temporal Schema Synchronization**:
  - Aligned Web Portal, Windows Desktop, Linux Avalonia Desktop, and Android Companion App on the canonical 4-date schema: `createdDate`, `startDate`, `deadline`, and auto-calculated `duration`.
  - Added robust date parsing across all platforms handling both ISO-8601 timestamps and date-only strings without timezone offset drift.
  - Implemented automatic duration calculation in `CreativeOrder.cs`, `ProjectStatusItem.cs`, `order-service.js`, and `Models.kt`.
- **Order Attachment Ingestion & Project Brief Handover**:
  - Implemented multi-file drag-and-drop attachment upload on Web Management Portal storing files under `_Orders/<orderId>/`.
  - Windows Desktop (`CreativeOrderService.cs`): Added automatic enrichment scanning `_Orders/<orderId>/` and handover to project briefs (`01_Brief_and_Copy/Brief_Assets/`).
  - Generated clickable Markdown tables and hyperlinks in `01_Brief_and_Copy/COPY.md` pointing to brief assets.
  - Populated `README.md` YAML frontmatter with full order reference and 4-date metadata.
- **Universal Markdown Editor Toolbars**:
  - Integrated full Markdown editing toolbars (H1-H3, Bold, Italic, Lists, Checklists, Blockquotes, Code, Links, Images, Tables) into Web Management Portal (`CreativeOrdersView.svelte`, `CopywritingStudioView.svelte`) and Desktop (`CopywritingPage.xaml`).
- **End-to-End Verification**:
  - Created `QA/verify_order_handshake.ps1` verifying order ingestion, project generation, attachment handover, frontmatter parsing, and status updates (30/30 PASS).
  - Web Portal Test Suite: 34/34 PASS.
  - Source Guardian: 9 passed, 0 failed.
  - Windows Desktop MSBuild: PASS (`dist/SS-CAM-v4.10.2.exe`).
  - Linux Desktop `dotnet build`: PASS (`net10.0` 0 errors).
  - Android Companion App Gradle: PASS (`compileDebugKotlin` 0 errors).

- **Studio Notes Navigation Crash Resolution (`QuickNotePage.xaml`, `QuickNotePage.xaml.cs`)**:
  - **Premature SelectionChanged Elimination**: Removed `IsSelected="True"` from `CmbSort` in XAML. In WPF, child items with `IsSelected="True"` fire `SelectionChanged` immediately during BAML parsing before following controls like `NotesList` are created, causing `ApplyNoteFilter()` to fail on null references. Default selection is now assigned safely during `OnPageLoaded`.
  - **WPF-UI SymbolRegular Enum Correction**: Corrected invalid `Symbol="FullScreen24"` on `BtnToggleZen` to `Symbol="FullScreenMaximize24"`.
  - **Lifecycle & Null Guards**: Added `if (!IsLoaded || ...) return;` guards to `OnSortChanged`, `OnSearchNotesChanged`, `OnCategoryChanged`, `OnPriorityChanged`, and `OnNoteSelected`. Added `if (_notes == null || NotesList == null) return;` and null check on `TxtNoteCount` inside `ApplyNoteFilter()`.
  - **Dropdown Standard & Token Cleanup**: Enforced `Height="36" MinHeight="36"` on `CmbSort`, `CmbCategory`, and `CmbPriority`, widened category/priority selectors to 135px, and replaced undefined resource token `SubtitleBackgroundFillColorDefaultBrush` with canonical `CardBackgroundFillColorSecondaryBrush`.
- **Project Creator Category Presets (`ProjectCreatorPage.xaml`, `ProjectCreatorPage.xaml.cs`)**:
  - Added dedicated `Video Shooting` category preset with automatic deliverables scaffolding and task presets.
  - Enforced ComboBox height standards (`MinHeight="36"`) and vertical alignment across creator forms.
- **SS-CAM Web Portal Deliverables & Preview Enhancements (`deliverables-view.js`, `task-detail-modal.js`, `api.js`)**:
  - Filtered out Synology system files (`SYNOFILE_THUMB_*`) and `@eaDir` metadata folders from deliverables and file previews.
  - Enabled direct image preview modals and file download actions for deliverables and subtasks.
  - Corrected Harussani workload metrics calculation and capacity modeling with clear UI guidance.
- **SS-CAM Linux Native Desktop Package Synchronization (`SS-CAM.Linux.csproj`, `MainViewModel.cs`, `build-linux-package.ps1`, `install-linux.sh`, `version.json`)**:
  - Updated Linux Avalonia UI application version and csproj to `v4.10.1` (`<Version>4.10.1</Version>`, `_appVersion = "v4.10.1-linux"`).
  - Synchronized installer scripts (`install-linux.sh`, `install.sh`, `docs/install-linux.sh`, `docs/install.sh`) to reference `v4.10.1`.
  - Rebuilt and packaged the Linux self-contained single-file binary: generated `dist/SS-CAM-v4.10.1-linux-x64.tar.gz` (40.53 MB) and mirrored to `publish/ss-cam-linux-x64.tar.gz` and `dist/ss-cam-linux-x64.tar.gz`.
  - Executed Linux smoke & coverage test suite: 74 passed, 0 warned, 0 failed (100% pass rate).
- **SS-CAM Android Companion App Upgrade & Signing (`build.gradle.kts`, `SettingsProfileScreen.kt`, `TeamHubScreen.kt`, `ManageProjectBottomSheet.kt`, `build-android-release.ps1`)**:
  - Bumped Android version codes to `versionCode = 4101` and `versionName = "4.10.1"`.
  - Updated hardcoded UI version badges and footer in `SettingsProfileScreen.kt` to `v4.10.1 (Build 4101)`.
  - Aligned team capacity model in `TeamHubScreen.kt` with canonical 5-slot standard (`assignedCount / 5.0f * 100%`).
  - Filtered Synology thumbnail cache files (`SYNOFILE_THUMB_*` and `@eaDir`) from `ManageProjectBottomSheet.kt`.
  - Compiled, Proguard-minified, and RSA-signed Android App Bundle (`dist/SS-CAM-v4.10.1-android-release.aab` — 5.76 MB) and standalone release APK (`dist/SS-CAM-v4.10.1-android-release.apk` — 3.24 MB).
- **Verification**:
  - Source Guardian: PASS (9 passed, 1 warned, 0 failed; UTF-8 BOM enforced on all files).
  - MSBuild Release: PASS (`SS-CAM.exe` compiled cleanly).
  - Linux Native Release Build: PASS (`SS-CAM.Linux` net10.0 self-contained single-file x64 binary compiled and packaged).
  - Android Release Build: PASS (`bundleRelease` and `assembleRelease` passed with verified RSA 2048 signing).
  - Runtime STA Instantiation: QuickNotePage instantiated cleanly with 0 exceptions (`Page Title: Quick Notes & Markdown Studio`).

## v4.10.1 — 2026-09-15 (Official SuamiSihat Radio Stream Upgrade & Native M3U/M3U8 Playlist Engine)
- **Assembly Version**: `4.10.1.0`
- **Official SuamiSihat Radio Live Stream Migration (`RadioStreamService.cs`, `MainViewModel.cs`, `StudioRadioScreen.kt`)**:
  - Migrated primary stream endpoint from `https://dj.suamisihat.myds.me/listen/suamisihat-radio/radio.mp3` to `https://radio.suamisihat.myds.me/listen` (broadcasting 192 kbps MP3 with embedded ICY real-time metadata).
  - Implemented automatic local configuration migration in `RadioStreamService.LoadStations()`: existing user presets in `%LOCALAPPDATA%\SuamiSihat\radio_config.json` pointing to legacy links or shortcodes are seamlessly upgraded to the new endpoint on launch.
  - Synchronized stream URLs across Linux desktop client (`MainViewModel.cs`) and Android companion app (`StudioRadioScreen.kt`).
  - Streamlined Android live track title extraction in `StudioRadioScreen.kt` to extract directly from the live ICY stream metadata with zero network delay.
- **Native M3U / M3U8 Playlist Engine (`PlaylistHelper`, `RadioStreamService.cs`, `RadioPage.xaml`)**:
  - **Direct M3U/M3U8 Stream Playback & Resolution**: Implemented `PlaylistHelper.ResolveStreamUrl` to identify and resolve `.m3u`, `.m3u8`, and `.pls` links (or query parameters) to the active media stream.
  - **Dynamic Proxy Redirection**: In `LocalAudioProxy.ProcessRequest`, detects `audio/x-mpegurl`, `application/x-mpegurl`, or playlist text bodies returned by stream servers and automatically resolves and redirects to the underlying audio stream, preventing WPF `MediaPlayer` codec crashes.
  - **Enhanced M3U / M3U8 Parsing & Relative URL Handling**: Comprehensive `#EXTINF` metadata parser supporting duration, title, `tvg-name`, `group-title` (genre categorization), and `tvg-logo` / `logo` cover image URLs. Automatically resolves relative paths within playlists against the source file or base URL (`PlaylistHelper.ResolveAbsoluteUri`).
  - **Station Playlist Export**: Added `ExportPlaylistFile` in `RadioStreamService.cs` generating clean, standardized `#EXTM3U` playlists. Added an **Export** button with Segoe Fluent Icon `&#xE74E;` in `RadioPage.xaml` toolbar (`OnExportPlaylistClicked` in `RadioPage.xaml.cs`) allowing designers to backup or export station collections to `.m3u` / `.m3u8` files via a standard `SaveFileDialog`.
  - **Online Playlist Import & Stream Testing**: Added `ImportPlaylistUrl` for fetching and importing M3U/PLS playlists directly from web URLs. Enhanced `TestStreamUrl` to resolve M3U stream links and verify audio stream connectivity with clear UI feedback (`M3U stream verified! (audio/mpeg)`).
- **QA & Verification Status**:
  - Desktop Build: MSBuild Release clean build PASS (`SS-CAM.exe` v4.10.1).
  - Source Guardian: 8 passed / 1 warned / 0 failed (UTF-8 BOM enforced on all files).
  - Live Stream Verification: Verified `https://radio.suamisihat.myds.me/listen` (audio/mpeg 200 OK).
  - M3U Engine: Verified parsing, generation, relative path resolution, and stream testing.

## v4.10.0 — 2026-09-14 (Smart Drag-and-Drop Vault Ingester, Myers LCS Diff Engine & AI Brief Intelligence)
- **Assembly Version**: `4.10.0.0`
- **Android Version**: `versionCode = 4100`, `versionName = "4.10.0"`
- **Web Portal Version**: `4.10.0`
- **Smart Drag-and-Drop Vault Ingester (`SmartIngesterService.cs`)**:
  - Automatically identifies file extensions and folder names to sort dropped external files into canonical 5-folder structure (`01_BRIEF_ASSETS`, `02_SOURCE_FILES`, `03_COPYWRITING`, `04_WORK_IN_PROGRESS`, `05_DELIVERABLES`).
  - Recursive directory traversal with flattening and folder creation.
  - Non-destructive collision safety (`_1`, `_2`) preventing overwrite of existing project assets.
  - Multi-surface integration across Desktop: `ProjectCreatorPage.xaml` (staged asset card), `SearchCopyPage.xaml` (project catalog cards drop target), and `TaskManagerPage.xaml.cs` (Kanban task card drop target).
- **Myers LCS Markdown Diff Engine (`TextDiffService.cs`, `MarkdownDiffDialog.xaml`)**:
  - Implemented Myers LCS difference algorithm for line-by-line comparison with edit distance, change classification (`Equal`, `Insert`, `Delete`, `Modify`), and LCS similarity score.
  - Automatic snapshot generation (`YYYYMMDD_HHmmss_COPY.md` / `README.md`) in `archive/` or `.snapshots/` on save.
  - Rich Fluent 2 `<ui:FluentWindow>` comparison dialog with Before/After revision selector, metric badges (similarity score, insertions/deletions), Side-by-Side and Unified views, and clipboard copying.
  - Integrated into `CopywritingPage.xaml` and `SearchCopyPage.xaml`.
- **AI Brief Intelligence & Style Preflight Assistant (`GeminiDesktopService.cs`, `GeminiService.js`, `api.js`)**:
  - Dual engine: online Google Gemini 1.5 REST queries using credentials from NAS `_Team/ai-config.json` + robust offline heuristic fallback.
  - Brief Completeness Validator (`ValidateBriefAsync`): scores project briefs (0-100), identifies missing specifications (deliverables, aspect ratio, target audience, brand tokens), and delivers Art Director recommendations.
  - Copywriting Style & Compliance Preflight (`PreflightCopyAsync`): audits hook strength, readability, and scans against KKM / LIU regulatory claims with actionable alternatives.
  - REST endpoints exposed on Web Portal: `POST /api/ai/validate-brief` and `POST /api/ai/preflight-copy`.
- **Notion & Evernote Inspired Quick Notes Studio (`QuickNoteService.cs`, `QuickNotePage.xaml`, `QuickNotePage.xaml.cs`)**:
  - **Notion-Style Header & Property Matrix**:
    - Interactive 12-emoji page icon picker (`BtnPageIcon`, `MenuIconPicker`) reflecting across page header and sidebar note cards.
    - Inline borderless note title editor (`TxtNoteTitle`) synchronized bidirectionally with note Markdown `# Title`.
    - Compact property matrix bar: Category tag dropdown (`General`, `Brief`, `Meeting`, `Idea`, `Copywriting`, `Tasks`, `Feedback`), Priority pill (`Normal`, `Medium (P1)`, `High (P2)`), Pinned toggle, relative timestamps ("Edited today, 11:42"), reading time ("X min read"), word count, and character metrics.
    - Distraction-Free Focus / Zen Mode (`BtnToggleZen`) with 1-click sidebar collapse for immersive drafting.
  - **Evernote-Inspired Sidebar & Note Cards**:
    - Instant search with clear `(✕)` button (`BtnClearSearch`).
    - 6 filter chips: `All`, `📌 Pin`, `⚡ High`, `☑️ Tasks`, `💡 Ideas`, `📋 Briefs`.
    - Sort selector: `Recently Edited`, `Date Created`, `Title (A-Z)`, `Priority`.
    - Rich card template: circular icon badge, bold title, 2-line snippet, category tag pill, relative timestamp, task progress pill (`✓ 2/4`), and priority pill (`P1`, `P2`).
  - **Notion-Style Block Formatting & Callout Inserters**:
    - 4 Notion Callout blocks: Blue Note (`[!NOTE]`), Green Pro-Tip (`[!TIP]`), Amber Regulatory Warning (`[!WARNING]`), Red Critical Alert (`[!DANGER]`).
    - 1-click Markdown Table template generator with deliverables, specs, and status columns.
    - Task checklist checkbox (`- [ ]`), bullet lists, numbered lists, blockquotes, code blocks, horizontal rules, links, and image tags.
    - 3-Way Mode Segmented Switcher (`Split`, `Edit`, `Preview`) with live side-by-side FlowDocument rendering.
    - Export options: Plain clean text for WhatsApp/Slack, Raw Markdown clipboard copying, and `.md` file export dialog.
  - **Creative Starter Templates & Onboarding Empty State**:
    - 4-card interactive starter grid on empty workspace: Creative Brief (Notion Standard), Meeting Sync, 3-Hook Ad Matrix, and Mind Drop.
    - 100% backward-compatible YAML frontmatter storage (`icon:`, `category:`, `pinned:`, `priority:`).
- **QA & Verification Status**:
  - Desktop Build: MSBuild Release clean build PASS (`SS-CAM.exe` output).
  - Source Guardian: 8 passed / 1 warned / 0 failed (UTF-8 BOM enforced on all files).
  - Web Test Suite: 34 passed / 0 failed (100%).
  - Web Admin Smoketest: 7 passed / 0 failed (100%).

## v4.9.0 — 2026-09-11 (Visual Project Timeline & Gantt Inspector Drawer, Live Studio Workstream Telemetry, Command Palette v3.5.1 & Tri-Platform Parity)
- **Assembly Version**: `4.9.0.0`
- **Android Version**: `versionCode = 490`, `versionName = "4.9.0"`
- **Web Portal Version**: `4.9.0`
- **Visual Project Timeline & Gantt Inspector Drawer (`CalendarPage.xaml`, `CalendarPage.xaml.cs`, `ProjectGanttView.svelte`)**:
  - Right-docked 440px `ProjectDetailDrawer` opened by clicking project name or timeline bar in Gantt chart, or "Inspect" in day cards.
  - Interactive Start Date and Deadline calendar pickers with automatic bidirectional duration sync in days (`{N}d`) and quick extension pills (`+1d`, `+3d`, `+1w`).
  - Malaysian Off-Day Conflict Alert (`MalaysiaHolidayService.IsOffDay`) detecting weekends and national public holidays with a 1-click **"Fix Off-Day Conflict"** auto-reschedule button.
  - Deliverables & Subtask Checklist Manager with `{Done}/{Total} (X%)` progress bar, 1-click status cycling (`Draft` ➔ `In Progress` ➔ `Done`), and inline editing.
  - Direct persistence to `README.md` YAML frontmatter via `FrontmatterService.WriteStatus`.
  - Visual Subtask Status Indicators: `[✓ X/Y • Z pts]` completion badges on Gantt left column (turns green on completion) and `✓ X/Y` pill badge on timeline bars (Desktop & Web).
- **Live Studio Telemetry & Workstream Pulse Across Ecosystem (`TeamService.js`, `LiveTaskSyncService.cs`, `DeskCompanionMode.kt`, `TeamHubScreen.kt`)**:
  - Implemented `GET /api/team/live-tasks` reading `<WorkspaceRoot>/_Team/live_tasks.json` with UTF-8 BOM safety and 16-hour session freshness filter.
  - Connected Chokidar file watcher to broadcast real-time Server-Sent Events (`live_tasks:updated`) across all connected browser clients upon filesystem mutation.
  - Added Live Workstream Card in `DashboardView.svelte` with real-time ticking stopwatches and designer initials.
  - Added ambient Header Studio Pulse Pill in `App.svelte` (`● {N} in Studio` / `● Studio Idle`) with dropdown flyout previewing active tasks, workstation machine IDs, and direct 1-click project navigation.
  - Connected `SscamApiService.getLiveTasks()` to `ProjectCacheManager` with disk persistence and automatic polling in Android app.
  - Upgraded Standby Desk Companion Mode (`DeskCompanionMode.kt`) with infinite pulsing Emerald telemetry ticker (`● N IN STUDIO • DESIGNER: TASK`) and active workstation focus cards.
  - Added elevated `LIVE STUDIO WORKSTREAM` card section in Android `TeamHubScreen.kt`.
- **Master Brand System v3.5.1 & Command Palette Alignment (`CommandPaletteModal.svelte`, `BrandHubScreen.kt`)**:
  - Upgraded Web Command Palette to 5 reactive category filter tabs (`All Results`, `Projects`, `Brand Colors`, `Copywriting Hooks`, `Studio Actions`).
  - Standardized all 16 official Single-Source-of-Truth tokens (Core Blues, Luxury Golds, Canary Yellows, Canvases, Semantic Status, Grayscale 80) across Web and Android Brand Hub.
  - Added dual-action copying (Click for HEX, <kbd>Shift</kbd> + Click for CSS variable `var(--ss-blue)`).
  - Embedded direct-response copywriting hooks directory with 1-click copying for headlines, body, and CTAs.
- **Packaging Deliverables & Creative Orders Intake (`DashboardCompanionScreen.kt`, `OrderFormView.svelte`, `Models.kt`)**:
  - Added packaging dieline types (`pkg_box_sleeve`, `pkg_label`) with 300 DPI CMYK and die-cut bleed specs.
  - Added strategic `tier_0` (`🗓️ Low / Pipeline`) priority tier across Web and Android Order Creation modals.
  - Standardized physical substrate chips (`Art Card 260/310gsm`, `Mirrorkote Gloss`, `Synthetic Vinyl`) and millimetre dimension inputs.
- **Packaging & Release Deliverables**:
  - Windows Desktop: `dist/SS-CAM-v4.9.0.exe` (5.99 MB single-file) and `dist/SS-CAM.exe`.
  - Android Companion: `app-release.aab` (6.03 MB, RSA 2048 Signed) and `app-release.apk` (3.39 MB).
  - Web Portal: Production assets compiled cleanly to `src/SS-CAM.Web/client/dist/`.
  - Test Suite: 34/34 tests passing with 0 failures.
  - GitHub Release: v4.9.0 Published with artifacts as Latest.

## v4.8.1 — 2026-09-10 (Global Studio Command Palette `Ctrl + K`, Art Director 60-30-10 Polish, Live Work Session Stopwatch & Status Indicator, Creative Operations Upgrade)
- **Assembly Version**: `4.8.1.0`
- **Creative Operations & Intake Architecture Upgrade (`OrderFormView.svelte`, `OrderService.js`, `CreativeOrder.cs`)**:
  - Implemented Low Priority / Pipeline Tier (`tier_0`) with automated +21 day minimum delivery date threshold.
  - Replaced flat format list with segmented 2-step Digital Screen vs. Print & Packaging channel selectors, custom dimensions, and physical substrates/laminations.
  - Added full request editing capability (Option A permission governance) with automatic locking upon backlog acceptance or cancellation.
  - Renamed intake status from "Completed" to "Added to Backlog" across Web, Windows WPF, and Linux Avalonia clients.
  - Removed duplicate "Lifecycle Actions" from expanded detail card, consolidating actions into canonical table row.
  - Stripped UTF-8 BOM (`\uFEFF`) in Node.js JSONL parsers to prevent Windows/.NET interoperability parse failures.
  - Purged all legacy demo seed orders from NAS ledgers and temporary attachment storage.
- **Global Studio Command Palette (`Ctrl + K`) (`CommandPaletteService.cs`, `MainWindow.xaml`, `MainWindow.xaml.cs`)**:
  - Global modal launcher accessible via <kbd>Ctrl</kbd> + <kbd>K</kbd>, top header spotlight search trigger, and sidebar search trigger.
  - Multi-category indexing and scoring engine across:
    - 15 Navigation Views (`Dashboard`, `Project Creator`, `Order Requests`, `Search & Copy`, `Copywriting Studio`, `Brand Assets`, `Task Manager`, `Big Calendar`, `Quick Notes`, `Creative Wellbeing`, `Waktu Solat`, `Radio Player`, `QR Code Studio`, `Workstation Health`, `Settings`).
    - Master Brand System v3.5.1 color tokens with real-time visual color swatch badges and 1-click clipboard copy.
    - Copywriting marketing hooks and high-converting CTAs.
    - Live workspace project discovery from Synology NAS / local storage.
    - Studio system actions (Toggle Theme, Play/Pause Radio, Start/Pause Timer, Rescan NAS, Open Explorer).
  - Arrow key navigation, <kbd>Enter</kbd> execution, <kbd>Esc</kbd> dismissal.
- **Art Director 60-30-10 Color Scheme & Layout Polish (`MainWindow.xaml`, Fluent 2 Styling)**:
  - Strict adherence to 60:30:10 rule:
    - 60% calm canvas (`ApplicationPageBackgroundThemeBrush`).
    - 30% structural surfaces (`CardBackgroundFillColorDefaultBrush`, `CardStrokeColorDefaultBrush`).
    - 10% intentional brand accent (`FluentBrand80`, `#21A1F7`) and status emerald (`#10B981`) for CTAs and focus indicators.
  - Centered header title bar strip with integrated spotlight search trigger (`Ctrl + K`) and live work status pill.
- **Live Designer Work Session Stopwatch & Status Indicator (`WorkSessionTrackerService.cs`, `MainWindow.xaml`, `MainWindow.xaml.cs`)**:
  - Live activity stopwatch and project status pill in header bar (`[ 🟢 0085D_SS_Rejal • 01:42:15 • Working ]`).
  - Interactive timer popover drawer with big digital timer display (`00 : 00 : 00`), project selector ComboBox, session notes, and playback controls.
  - **Active Project Filter by Designer (`CmbPopoverDesignerFilter`)**:
    - Integrated inline designer filter dropdown right beside the `ACTIVE PROJECT` label in the popover drawer.
    - Populates all studio designers (`"All Designers"`, `Harussani`, `Brand`, `Rejal`, etc.) from staff directory and workspace folders.
    - Automatically defaults to the currently logged-in designer profile, immediately filtering the project list to that designer's active projects.
    - Switching designers instantaneously filters the project dropdown without blocking the UI thread or triggering unintended project switches (`_popoverUpdating` guard).
  - Periodic and on-change crash-recovery checkpointing to `%LOCALAPPDATA%\SS-CAM\work_session.json` with 16-hour session recovery.
  - Synchronized with sidebar footer active work indicator and live team broadcaster.
- **Comprehensive Dropdown Overlap & Cropping Resolution across All Views**:
  - Added default `<Style TargetType="{x:Type ComboBox}">` and `ComboBoxItem` in `Styles/Fluent2Styles.xaml` enforcing `MinHeight="36"`, `VerticalContentAlignment="Center"`, and `Padding="10,0"`.
  - Replaced default access-key content presenters with explicit `<ItemTemplate>` utilizing `<ui:TextBlock Text="{Binding}" VerticalAlignment="Center"/>` in `MainWindow.xaml` (`CmbPopoverProjectPicker`), eliminating mnemonic underscore stripping (e.g. `202609_0017W_SS_...` losing underscores and shifting baselines) and vertical text baseline slicing.
  - Standardized height (`36px`) and comfortable padding (`10,0`) across:
    - `TaskManagerPage.xaml`: Search query input, Designer, Status, Priority, and Sort ComboBoxes; added horizontal `<ScrollViewer>` to top filter bar preventing dropdown squishing on compact viewports; verified Task Inspector drawer dropdowns (`DetailStatus`, `DetailPriority`, `DetailDesigner`).
    - `SearchCopyPage.xaml`: Batch action dropdowns (`BatchStatusCmb`, `BatchPriorityCmb`) and Task Inspector metadata dropdowns (`InspectorStatusCmb`, `InspectorPriorityCmb`).
    - `CalendarPage.xaml`: Search query input, Designer filter, and Status filter.
    - `WaktuSolatPage.xaml`: Prayer zone dropdown (`ZoneCombo`) and format toggle button.
    - `ProjectCreatorPage.xaml`: Template extension selector (`TemplateExtensionComboBox`).
    - `OrderRequestsPage.xaml`: Entity filter (`CmbEntityFilter`) and Assignee filter (`CmbAssignee`).
    - `VisualDiffDialog.xaml`: Before asset (`CmbBeforeAsset`), After asset (`CmbAfterAsset`), and comparison controls.
- **Studio Real-Time Live Tasks & Work Telemetry (`LiveTaskSyncService.cs`)**:
  - Multi-workstation synchronization via shared ledger at `<WorkspaceRoot>\_Team\live_tasks.json` with local `%LOCALAPPDATA%\SS-CAM\_Team\` fallback.
  - 4-second non-blocking background polling and 15-second active heartbeat broadcasts.
  - Instant studio desktop toast notification (`NotificationService.Show("Team Designer Active", "{Designer} has started working on '{Project}'")`) whenever another designer begins or resumes work on a project task.
- **Main Dashboard Real-Time Live Task Stream (`DashboardPage.xaml`, `DashboardPage.xaml.cs`)**:
  - Embedded "Live Studio Tasks (Real-Time Work Stream)" card container above Recent Projects.
  - Pulsing emerald active indicator badge (`{N} Active`).
  - Designer avatar circles with initials, formatted author and staff ID, status pills ("Working Now" in emerald, "Paused" in amber).
  - 1-second live digital stopwatch ticker updating elapsed duration (`00 : 42 : 18`) without blocking UI.
  - "View Project" direct navigation action into Project Catalog.
  - Clean idle workstation card fallback when all team members are inactive.
- **Source Guardian & Code Cleanliness**:
  - Enforced UTF-8 BOM across all `.cs` and `.xaml` files.
  - Replaced high-byte Unicode characters in XAML attributes with XML entities (`&#x2191;`, `&#x2193;`, `&#x21B5;`).
  - Source Guardian audit: 7 passed, 2 pre-existing warnings, 0 failed.
- **Release Verification**:
  - Compiled MSBuild Release binary (`dist/SS-CAM.exe` at 5.52 MB).
  - Passed all automated service unit tests (`QA/scripts/test_v481_services.ps1`).
  - Passed full project regression suite (`QA/run_tests.ps1`).
  - Verified live desktop execution and responsive process lifecycle.

---

## v4.8.0 — 2026-09-09 (Interactive Visual Asset Revision Diff Slider, Copywriting Studio Live Preview & Cross-Platform Avatar Sync)
- **Assembly Version**: `4.8.0.0` / Android `versionCode = 480`, `versionName = "4.8.0"`
- **Interactive Visual Asset Revision Diff Inspector (`VisualDiffService.cs`, `VisualDiffDialog.xaml`, `VisualDiffDialog.xaml.cs`)**:
  - Standalone Fluent 2 comparison inspector extending `<ui:FluentWindow>` with `DynamicResource` tokens.
  - 5 interactive comparison modes: Vertical Split swipe, Horizontal Split swipe, Side-by-Side dual view, Opacity Blend onion skin (0%–100%), and 32bpp Euclidean RGB Pixel Difference mapping in high-visibility magenta (`#FF007F`).
  - Automated revision pair detection (`DetectRevisionPairs`) scanning project folders (`04_DELIVERABLES`, `Client_Revisions`, `01_CREATIVE`) for version suffixes (`_v1` → `_v2`, `draft` → `final`) with active file priority sorting.
  - Lock-free image metadata extraction preventing Windows file locks.
  - Synchronized lockstep zoom (0.1x–10.0x) and pan; keyboard shortcuts (<kbd>←</kbd> / <kbd>→</kbd>, <kbd>Space</kbd>, <kbd>Esc</kbd>).
  - Integrated into `SearchCopyPage` Assets Gallery ribbon, Task Inspector Revision ribbon, and gallery double-click event.
- **Copywriting Studio Split-View Live Preview & Formatting Engine (`CopywritingDesktopService.cs`, `CopywritingPage.xaml`, `CopywritingPage.xaml.cs`)**:
  - Live side-by-side Markdown editor and rendered preview with 150ms debounced synchronization.
  - Sub-mode switcher: FlowDocument (`[ Doc ]`), WhatsApp broadcast chat simulation (`[ WhatsApp ]`), Meta Ad feed sponsored post (`[ Meta Ad ]`), and dual view (`[ Both ]`).
  - WhatsApp inline parsing (`*bold*`, `_italic_`, `~strike~`, monospace) and automatic OG link preview cards with title, domain, and thumbnail.
  - Meta Ad headline extraction, dynamic CTA inference (`Send Message`, `Order Now`, `Shop Now`), and interactive `... See more` truncation.
  - 1-click clipboard exporters for WhatsApp broadcast copy and structured Meta Ads Manager payload.
- **Cross-Platform Avatar & User Profile Synchronization (`TeamService.js`, `api.js`, `UserProfileModels.cs`, `UserProfileService.cs`)**:
  - Dedicated binary file storage inside `_Team/Users/{staffId}/avatar.jpg` and `profile.json`.
  - Lightweight reference index in `staff_directory.json` (`avatarUrl: "/api/users/{staffId}/avatar"`).
  - Binary streaming endpoint `GET /api/users/:id/avatar` with MIME type headers and caching.
  - C# `StaffDirectoryItem` camelCase `[JsonProperty]` serialization and bi-directional auto-sync in `UserProfileService.LoadProfile()`.
- **Source Guardian & Code Cleanliness**:
  - Replaced raw high-byte Unicode characters with XML entities (`&#x2122;`, `&#x26A0;`, `&#x1F1F2;&#x1F1FE;`) in `CopywritingPage.xaml` and `CalendarPage.xaml`.
  - Source Guardian audit passed with 7 passed, 2 warned, 0 failed.
- **Release Verification**:
  - Rebuilt WPF Desktop single-file executable (`dist/SS-CAM-v4.8.0.exe` and canonical `dist/SS-CAM.exe` at 5.88 MB).
  - Rebuilt Web Portal production client bundle (2,253 modules transformed in 8.15s).
  - Passed 30/30 backend automated tests.

---

## v4.7.0 — 2026-09-09 (Velocity Navigation Engine, Canva Creative Cloud Bridge, Per-User Team Storage & Visual Timeline Alignment)
- **Assembly Version**: `4.7.0.0` / Android `versionCode = 471`, `versionName = "4.7.0"`
- **High-Velocity Desktop Navigation Engine (`MainWindow.xaml`, `WorkspaceScanner.cs`, `DashboardModels.cs`)**:
  - Configured `NavigationCacheMode="Required"` across all 15 navigation views in the desktop application. Tab navigation is now instantaneous (0 ms), retaining active state, scroll position, search filters, and loaded view models without re-inflating XAML BAML trees.
  - Eliminated synchronous recursive `Directory.GetDirectories` crawling on the UI thread in `DashboardPage.xaml.cs`.
  - Shifted `ActiveWipProjects` computation to the background thread in `WorkspaceScanner.ScanAsync` and surfaced directly via `DashboardSnapshot`.
  - Converted synchronous folder scans in `CalendarPage.xaml.cs` and `TaskManagerPage.xaml.cs` to non-blocking `await Task.Run(...)`.
  - Converted directory search in `OrderRequestsPage.xaml.cs` to asynchronous execution to eliminate UI stutter when selecting order cards.
  - Resolved `System.InvalidCastException` in `OrderRequestsPage.xaml` by extracting `ContextMenu` into a statically referenced page resource (`OrderCardContextMenu`).
- **Canva Creative Cloud Bridge in Project Creator (`ProjectCreatorPage.xaml`, `ProjectCreatorPage.xaml.cs`)**:
  - Integrated dedicated **Canva Creative Cloud Bridge** card in the desktop Project Creator.
  - Added **"Create on Canva (Auto-size)"** 1-click launcher opening Canva pre-configured with exact pixel/mm dimensions (`https://www.canva.com/create/?width={w}&height={h}&unit={px|mm}`).
  - Added `CanvaUrlInput` field with **"Test Link"** button for pasting design URLs and `"Canva (.url)"` to starter canvas extension selector.
  - Automatic scaffolding of `02_SOURCE/Open_In_Canva.url` Windows Internet Shortcut file, enabling 1-click browser launching.
  - Added `canva_url` frontmatter persistence, Task Manager teal `[CANVA]` pill badge, and Web `FrontmatterPanel.svelte` launcher.
- **Per-User Team Storage Architecture & Binary Avatar Streaming (`TeamService.js`, `api.js`, `UserProfileModels.cs`, `UserProfileService.cs`)**:
  - Transitioned from monolithic Base64 string embedding in `staff_directory.json` to dedicated physical binary file storage inside `_Team/Users/{staffId}/avatar.jpg` and `profile.json`.
  - Sanitized `staff_directory.json` into a lightweight reference index (`avatarUrl: "/api/users/{staffId}/avatar"`), eliminating JSON bloat.
  - Implemented high-performance binary streaming route `GET /api/users/:id/avatar` with MIME type detection and HTTP cache control headers.
  - Resolved C# desktop `StaffDirectoryItem` serialization by adding missing fields (`Username`, `AvatarUrl`, `Roles`, `Password`) with explicit `[JsonProperty("...")]` camelCase mappings, preventing authentication credential loss.
  - Added bi-directional auto-sync in desktop `UserProfileService.LoadProfile()` (automatically uploading local `%LOCALAPPDATA%` avatars to NAS `_Team/Users/{staffId}/avatar.jpg`) and `SyncAvatarToNas()` for instant updates.
  - Updated all Web views (`ProfileView`, `TeamView`, `DashboardView`, `ProjectKanbanView`, `ProjectTableView`, `ProjectDetailView`) to prioritize `avatarUrl || avatar` over browser `localStorage`.
- **Big Calendar Timeline Day Headers & Public Holiday Color Standard (`MalaysiaHolidayService.cs`, `CalendarPage.xaml.cs`)**:
  - Standardized all 7 day headers across the Gantt timeline to uniform 3-letter abbreviations: `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun` (via `MalaysiaHolidayService.GetDayLetter`).
  - Restricted red text highlight (`#DC2626`) strictly to official Malaysia Public Holidays (`holiday != null`).
  - Styled Sunday and Saturday weekend days in clean neutral slate (`#64748B`), perfectly aligning with the "Weekend (Sat/Sun Off-Day)" guide.
- **Ecosystem Test Suite & Build Verification**:
  - Verified 30/30 passing Web Portal test suite.
  - Rebuilt WPF Desktop executable using MSBuild 4.8 in Release mode (`dist/SS-CAM-v4.7.0.exe` and `dist/SS-CAM.exe` at 5.70 MB).

---

## v4.6.2 — 2026-09-08 (NAS Temporary Attachment Vault, Designer Task Handover, Web Multi-File Upload & Desktop Auto-Ingestion)
- **Assembly Version**: `4.6.2.0` / Android `versionCode = 466`, `versionName = "4.6.2"`
- **Desktop Task Ownership Handover & Reassignment (`TaskManagerPage.xaml`, `TaskManagerPage.xaml.cs`)**:
  - Added `DetailDesigner` editable ComboBox and `BtnDetailHandover` ("Hand Over Task") button in Row 6 of the Detail Drawer metadata grid.
  - Added right-click Kanban card context menu with dynamic "Hand Over Task To..." submenu pre-populated with active team members (`staff_directory.json`).
  - Seamless frontmatter persistence (`designer: <name>`) to `README.md`, instant notification dispatch, and real-time board/filter refreshing.
- **Synology NAS `_Orders` Temporary Attachment Vault**:
  - Implemented dedicated temporary intake directory `\\SSNAS\Creative-Team\_Orders\<ORDER_ID>\` acting as an asset staging vault for creative requests prior to project folder creation.
  - Safe underscore prefix (`_Orders`) ensures directory scanners (`WorkspaceScanner.cs`, `WorkspaceService.js`) ignore temporary folders and never collide with year containers (`2026/`).
  - Automatic JSON-Lines sync to `_Orders/creative-orders.jsonl` on the NAS with fallback redundancy.
- **Web Portal Multi-File Upload Dropzone (`OrderFormView.svelte`, `api.js`)**:
  - Integrated modern Fluent 2 drag-and-drop file uploader in the "New Creative Request" modal supporting multiple attachments up to 50MB per file (PNG, JPG, WebP, PDF, PSD, AI, ZIP, MP4, DOCX).
  - Attached files stream to the server via `multipart/form-data` or base64 JSON payload and are written safely into the order's NAS vault.
- **Role Detection & Action Visibility Fix (`OrderFormView.svelte`)**:
  - Fixed role check bug where users with composite roles like `"Admin, Designer"` (e.g. Harussani) had action buttons, status dropdowns, and designer assignment controls hidden.
  - Enhanced role matcher to check composite role strings, token arrays, and case-insensitivity.
- **Order Details Drawer & Attachment Actions (`OrderFormView.svelte`)**:
  - Added "Attached Reference Files" section listing all files with sizes, upload timestamps, and direct actions.
  - 👁️ Preview / open media in browser, ⬇️ Download original file, and ❌ Safe delete.
  - 📋 **"Copy NAS Folder Path"**: Copies `\\SSNAS\Creative-Team\_Orders\<ORDER_ID>` directly to clipboard for opening in Windows File Explorer.
  - ➕ Upload additional reference files into the order vault at any time.
  - 📥 **"Copy All Attachments to Project (01_BRIEF_ASSETS)"**: 1-click action to copy all staged assets into the linked project's brief folder on the NAS.
- **Desktop Project Creator Order Discovery & Ingestion (`ProjectCreatorPage.xaml`, `ProjectCreatorPage.xaml.cs`, `CreativeOrderService.cs`)**:
  - Added `LinkedOrderComboBox` to the desktop Project Creator page, automatically discovering pending orders from `_Orders/creative-orders.jsonl` with live attachment counts (`[📎 N files]`).
  - Added **Sync** button for instant order list refreshing.
  - Selecting an order automatically populates the project title, selects the matching sub-brand, populates the brief remarks with requester information, and displays an attachment count badge.
  - Generating the project folder automatically copies all files from `_Orders/<ORDER_ID>/` into `targetDir\01_BRIEF_ASSETS\`, sets `order_id: <ORDER_ID>` in `README.md` frontmatter, and updates order status to `in_progress`.
- **Ecosystem Test Suite & Build Verification**:
  - Added Test 30 to Web Portal test suite verifying NAS attachment save, list, download, and project ingestion (30/30 passed, 100%).
  - Verified Source Guardian (9/9 passed), compiled Release desktop binary (`5.42 MB`), and executed post-build Smoke Test suite cleanly.

---

## v4.6.1 — 2026-09-04 (Cross-Platform Creative Orders Real-Time Sync, Order Requests Scaffolding Engine & Desktop Startup Resilience)
- **Assembly Version**: `4.6.1.0` / Android `versionCode = 462`, `versionName = "4.6.1"`
- **Cross-Platform Creative Orders Real-Time Sync**:
  - Unified Desktop (Windows WPF & Linux Avalonia) with Web Portal (`/api/orders`) using direct live REST API calls.
  - Automatic JWT authentication and live queue fetching ensuring Desktop, Web Portal, and Android Companion app display identical active orders in real time.
  - Dual-layer persistence: live cloud orders are automatically cached to the local Synology NAS ledger (`_Team\Orders\creative-orders.jsonl`) for offline resilience.
  - Instant bidirectional status propagation: converting or updating an order on Desktop immediately issues an HTTP `PATCH /api/orders/{id}` to the central cloud API.
- **Desktop 1-Click Project Scaffolding Engine**:
  - Implemented `CreativeOrderService.ConvertOrderToProjectAsync` calculating next canonical project ID (`NNNNX`), generating standard 4-folder project vaults (`01_Brief_and_Copy`, `02_Source_Assets`, `03_Artwork_Design`, `04_Final_Exports`), auto-generating `01_Brief_and_Copy/COPY.md` containing the requester's script, and writing `README.md` with YAML frontmatter linking the order ID.
- **Desktop Startup Sequence & Splash Screen Hang Resolution**:
  - Resolved WPF-UI icon symbol clash by updating `ClipboardTasklist24` to `ClipboardTask24`.
  - Replaced synchronous PowerShell shortcut child process with fast in-process `WScript.Shell` COM registration.
  - Set application shutdown mode to `OnLastWindowClose` with explicit `MainWindow.Closed` process termination guards.
  - Added diagnostic file logging (`%LOCALAPPDATA%\SuamiSihat\startup_trace.log`) and individual `try/catch` safety guards across all `MainWindow.OnLoaded` initialization routines.
- **Desktop Task Manager Kanban Overdue Suppression**:
  - Implemented `IsCompletedStatus` checking (`done`, `approved`, `completed`).
  - Strict suppression of `[Overdue ...d]` badge (`IsOverdue = false`, `DeadlineBadgeBackground = Transparent`), rendering deadlines in emerald green (`#10B981`) text.
  - Excluded completed projects from the top metric glance "URGENT / OVERDUE" counter in `TaskManagerPage.xaml.cs`.
  - Neutralized queue age indicator (`AgeBadgeColor`) to `#64748B` on finished projects.
- **Frontmatter YAML String Sanitization**:
  - Auto-strip surrounding quotes (`"..."` / `'...'`) from frontmatter values in `FrontmatterService.cs` so ISO timestamp strings parse properly into clean `yyyy-MM-dd` dates.
  - Applied parity update to Linux Avalonia desktop model `SS-CAM.Linux/Models/ProjectStatusItem.cs`.
- **Web Portal Creative Direction Matrix Preview & Header Toggle**:
  - Refactored `ProjectDetailView.svelte` to default to formatted read-only preview cards with visual concept highlights, demographic cards, and live color swatch chips.
  - Relocated action button into top-right header with Edit / Save / Cancel toggle states.
  - Aligned backend API `PUT /projects/:id/direction` to persist `visual_concept`, `color_palette`, and `target_audience` into `README.md`.
- **Web Portal Markdown Editor Auto-Wrapping**:
  - Removed `max-height: 720px` restriction in `MarkdownEditor.svelte` so editor card expands to fit document content without cutting off text.
  - Defaulted editor mode to Preview (`preview`) with sticky toolbar.
- **Shared Team Board Test Isolation**:
  - Guarded `ApprovalService.postTeamNotification` from posting test items (`9998A`) to live `\\SSNAS\Creative-Team\_Team\team-notes.json` during unit and DOM test runs.
  - Purged legacy test notes from the NAS shared JSON.
- **Build & Multi-Platform Quality Suite**:
  - Source Guardian: 9/9 PASS.
  - Web Portal Test Suite: 29/29 PASS.
  - Linux Avalonia Release: 0 warnings, 0 errors, packaged to `dist/SS-CAM-v4.6.1-linux-x64.tar.gz`.
  - Android Companion App: versionCode 462, 2048-bit RSA signed AAB & APK in `dist/`.
  - Windows Desktop: Release executable compiled and verified at `dist/SS-CAM-v4.6.1.exe`.

---

## v4.6.0-linux — 2026-09-02 (Linux Port — Full Feature Parity with Windows v4.6.0)
- **Scope**: Complete rebuild of SS-CAM.Linux (Avalonia 11 / .NET 10) to match all 14 pages and backend logic of Windows WPF v4.6.0.
- **Architecture**: Replaced StackPanel-based navigation with ContentControl + NavigateTo(key) pattern. Single MainViewModel drives all 15 views.
- **Services added**: `RadioStreamService` (mpv subprocess), `PrayerTimeService` (JAKIM waktusolat.app API), `QuickNoteService` (JSON persistence), `WorkstationHealthService` (/proc + df + which), `WorkspaceService`.
- **Models added**: `ProjectStatusItem`, `QuickNoteItem`, `RadioStationItem`, `SoftwareCheckItem`, `CalendarModels` (CalendarDay, CalendarWeekRow), `PrayerTimeRow`.
- **Views created**: All 15 page AXAML + code-behind files covering the full 14-module sidebar.
- **MainViewModel**: Complete rewrite — 19 RelayCommands, async clock task, prayer time row builder, calendar month navigation, NAS status check, QR generation via BitmapByteQRCode, workstation health async rescan.
- **MainWindow**: Rebuilt 14-item sidebar in 4 groups (Creative Workspace / Task & Planning / Studio Tools / System), footer status bar with NAS indicator + radio mini-player + live clock.
- **Build**: 0 errors, 0 warnings after resolving CS1503, CS0103, CS1061, AVLN2000 (×2), AVLN5001 (×3), MVVMTK0034 (×2), CS0618.
- **QA Baseline**: Source Guardian 9/9 PASS. Linux coverage check: 23/23 PASS.

---

## v4.6.0 — 2026-09-01 (Beta Release — Preflight Quality Auditor, Android Bento Telemetry, Persistent Caching, Live Radio Streaming & Desk Standby Mode)
- **Assembly Version**: `4.6.0.0` / Android `versionCode = 460`, `versionName = "4.6.0"`
- **Desktop Preflight Quality Auditor (`PreflightValidatorService.cs`)**: Automated 5-folder vault hierarchy audit, YAML frontmatter validation, `COPY.md` script length checks, deliverable file inspection, and canonical asset naming validation with 1-Click Auto-Fix scaffolding.
- **Android 2×2 Bento KPI Telemetry (`DashboardCompanionScreen.kt`)**: Zero-scroll telemetry grid with instant touch filtering for Active Tasks, Due Projects, Active Brands, and NAS Assets.
- **Android Left Severity Accent Strips (`CommonComponents.kt`)**: 4.5dp rounded status indicator strips (🔴 Crimson for Urgent, 🟠 Amber for High, 🟡 Gold for Standard, 🟢 Green for Done) on Task Review cards.
- **Android Persistent Local Caching & Zero-Mock Flow (`ProjectCacheManager`, `MainActivity.kt`)**: Local JSON serialization in `SharedPreferences` enabling instant 0ms offline launch without dummy placeholder data.
- **Live Stream Radio Metadata Engine**: Implemented `LiveStreamMetadataFetcher` for AzuraCast API, Laut.fm, Plaza One, SomaFM, and universal ICY header byte chunk parsing (`icy-metaint`) with real-time station track titles on `TopAppBar` equalizer pill and cassette deck ribbon.
- **Ss-Hero Animated Splash Screen**: Implemented dynamic particle wave canvas backdrop with ambient glow, vector SuamiSihat logomark, and Biometric PIN lock gateway.
- **Interactive Fluent Markdown Viewer**: Implemented high-performance Markdown parser in Compose supporting interactive task checkbox state toggling and direct disk/memory persistence.
- **Standby Desk Companion Mode**: Full-screen OLED black standby clock with focus sprint timer, focus progress rings, and landscape/portrait orientation adaptation.
- **Material You Monochromatic Iconography**: Added adaptive launcher icons and monochrome drawables for Android 13+.
- **Source Guardian & Quality Suite**: 9/9 checks passed (Encoding, Fluent 2, Data Safety, Thread Safety).
- **Physical Device Wireless Verification**: Built and verified over ADB TLS on physical TECNO KL8 device and Android emulator.

---

## v4.5.1 — 2026-08-30 (Cross-Platform Ecosystem Synchronization & Major Stable Release)
- **Assembly Version**: `4.5.1.0`
- **Windows Desktop Client**: Compiled single-file portable executable (`dist/SS-CAM-v4.5.1.exe`), 100% theme-adaptive DynamicResource tokens in `WellbeingPage.xaml`, and UTF-8 BOM compliance.
- **Web Management Portal**: Resolved desktop mobile bottom dock rendering defect, hardened theme persistence in `appState.svelte.ts`, zero-emoji Fluent 2 design system with 45+ SVG icons, and 28/28 passing test suite.
- **Android Companion App**: Null-safe `ManageProjectBottomSheet.kt`, bottom navigation standardization (`Overview`, `Tasks`, `Studio`, `Lounge`), and successful Gradle debug build (`assembleDebug`).
- **Source Guardian & Quality Suite**: 9/9 checks passed, 100% test coverage.

---

## v4.5.0 — 2026-08-28 (Master Brand System v3.5.1 Integration & Brand Assets Vault Modernization)
- **Assembly Version**: `4.5.0.0`
- **Master Brand System Integration**: Synchronized with official SuamiSihat Master Brand System Guide v3.5.1 with Two-Layer System Architecture.
- **Multi-Format Color Matrix**: Added Primary, Secondary Warm, Foundation, and Semantic palettes (`#107C10`, `#D83B01`, `#A80000`) and calibrated 7-stop grayscale with corrected Grey 90 (`#3C3C3B`).
- **Live Specification Inspector**: Real-time readout of HEX, RGB, CMYK, BAL/RAL Standard, and Pantone PMS with 1-click copy buttons.
- **5 Operating Corporate Sub-Brands Hub**: Dedicated cards and 1-click Explorer folder launchers for SS Health, SS Clinic, SS Wellness, SS Ecommerce, and SS Technology.
- **Master Logo Surface Contrast Previewer**: Interactive stage switcher for Light Porcelain, Dark Void, and Prussian Blue validating the HSL L ≥ 50% lightness rule.
- **4-Tier Typography Scale Reference**: Visual hierarchy guidelines for Poppins, Montserrat, Helvetica Neue, and Calibri.
- **Source Guardian & Smoke Tests**: 9/9 checks passed; 100% smoke test pass rate.

---

## v4.4.3 — 2026-08-27 (Radio Visualizer Overhaul & Station Upgrades)
- **Assembly Version**: `4.4.3.0`
- **Dynamic Real-Time Playback Gating**: Mars symbols and logomarks automatically hide (`Opacity = 0.0`) when radio is stopped/idle, smoothly fading in on active playback.
- **Song Wavelength & Beat Modulation**: Particles oscillate along sinusoidal wavelength across canvas width; beat kicks trigger size pulse (+35%) and upward acceleration.
- **Cross-Mode Visualizer Architecture**: Unlinked backdrop particles from `HeroMesh` so they animate seamlessly across `WaterDrop`, `Waveform`, `SpectrumBars`, and `HeroMesh`.
- **Curated Radio Presets**: Replaced `CITYPlus FM` with `Nightwave Plaza` (Synthwave) and `SomaFM: Groove Salad` (Ambient/Chill).
- **Calendar Malaysia Public Holidays**: Added full Malaysia public holidays schedule into calendar event dispatcher.
- **Copywriting Studio Rich FlowDocument Mode**: Script canvas renders FlowDocument formatted markdown preview by default with smooth edit toggle.

---

## v4.4.2 — 2026-08-27 (Art Director Polish & Live Ad/WhatsApp Preview Engine)
- **Assembly Version**: `4.4.2.0`
- **Copywriting Studio Split-View Live Preview**: Built real-time 3-mode segmented switcher (`Split Preview`, `Rendered Doc`, `Editor Only`) with dual-pane layout.
- **WhatsApp Live Chat Bubble Simulation**: Real-time rendering of formatted WhatsApp broadcast copy (`*bold*`, emojis, live timestamp, double checkmarks).
- **Meta Ad Primary Text Preview**: Real-time mock rendering of sponsored feed ad with official brand avatar, headline, and `[Send Message]` CTA button.
- **Creative Snippet & Hook Drawer**: 1-click insertion chips for viral frameworks (TikTok 3-Hook, Meta PAS, Neubrutalist, Retro Story) and instant snippets (WhatsApp link, Promo Voucher, KKM Disclaimer, 100% Original Halal Guarantee, Urgency Timer).
- **Status Pill Badge**: Dynamic status indicator (`[● Ready / NAS Synced / Unsaved Changes]`).
- **Typographic Rhythm & Overlines**: Standardized overlines (`11px Bold CharacterSpacing="50"` in `FluentBrand80`) for visual hierarchy.

---

## v4.4.1 — 2026-08-26 (Maintenance & Enhancement Release — PUBLISHED)
- **GitHub Release**: PUBLISHED (`v4.4.1` set as Latest on SuamiSihat/ss_cam)
- **Documentation**: Updated (CHANGELOG.md, ROADMAP.md, QA suite headers aligned to v4.4.1)
- **Source Guardian**: PASS (9/9 checks passed)
- **Web Test Suite**: PASS (20/20 tests passed)
- **Wiki**: N/A (wiki update deferred)

### Features
- **Official SuamiSihat Radio Stream**: Integrated live stream (`https://dj.suamisihat.myds.me/listen/suamisihat-radio/radio.mp3`) as pinned `#1` preset in `RadioStreamService.cs` with migration preservation.
- **Deep Month-Container Vault Discovery**: Updated directory matching regex to bypass intermediate month containers (`202608_August`) across `WorkspaceScanner.cs`, `WorkloadSlaService.cs`, and `CopywritingPage.xaml.cs`.
- **Dynamic Project ID Counter Calculation**: Multi-tier directory scan in `ProjectCreatorPage.xaml.cs` to accurately compute sequential job IDs across containers and year vaults.
- **Copywriting Studio Rich FlowDocument Rendering**: Integrated `MarkdownHelper.ToFlowDocument` into `CopywritingPage.xaml.cs` with default rendered preview and icon-only Preview/Edit mode toggles (`Eye24` / `Edit24`).
- **Catalog Designer Filtering Sanitization**: Filtered out raw system folders (`#recycle`, `2026`) and mapped projects to team members via `UserProfileService.GetStaffDirectory()` and `ResolveProjectDesigner`.
- **UI Text Clipping Remediation**: Standardized ComboBox heights and paddings in `SearchCopyPage.xaml`.

### Fixes
- **Dashboard Workload Year Bug**: Fixed `ComputeDesignerWorkloads` erroneously returning year folder names (`2026`) as designer names. Overhauled to use staff directory + `ResolveProjectDesigner`.
- **Manager Role Exclusion — Metrics & Filters**: Added `IsDesignerOrAdminRole` predicate; excluded Manager / CEO / Executive roles from Dashboard capacity radar (Desktop & Web), all designer filter dropdowns (`WorkspaceScanner.GetDesignerFolders`, `TaskManagerPage`, `CalendarPage`), Web metrics (`WorkspaceService.js`, `TeamService.js`).
- **Mouse Wheel Scrolling Restored (All 15 Pages)**: Added global `OnGlobalPreviewMouseWheel` on `MainWindow` NavigationView (walks visual tree). Per-page `PreviewMouseWheel` wire-up on 10 previously broken pages. Kanban board gains horizontal wheel scroll support.

---

## v4.4.0 — 2026-08-20 (Designer Workload Heatmaps & Creative SLA Analytics)
- **GitHub Release**: PUBLISHED (`v4.4.0` set as Latest on SuamiSihat/ss_cam)
- **Designer Workload & Capacity Radar**: Integrated `WorkloadSlaService.cs` and `DashboardPage.xaml` radar grid computing real-time designer capacity scores and bandwidth statuses (`Optimal`, `High Load`, `At Capacity`).
- **Creative SLA Turnaround Telemetry**: Added First-Time Right %, Average Turnaround Days, and Average Revision Rounds tracking.
- **Web Portal Analytics**: Extended `WorkspaceService.js` and `DashboardView.svelte` with capacity progress bars and SLA analytics cards.
- **Source Guardian**: PASS (9/9 checks passed).
- **Test Suite**: PASS (20/20 web tests passed, MSBuild Release build passed).

---

## v4.3.0 — 2026-08-20 (Asset Export, Packaging & Naming Engine)
- **1-Click Creative Handover Packaging**: Built `ExportPackagingService.cs` and `ExportService.js` with auto-generated `HANDOVER_SUMMARY.html`.
- **Canonical Asset Naming & Sanitizer**: Built `AssetNamingService.cs` canonical validator and batch sanitizer.
- **Source Guardian & Build**: PASS (9/9 checks, 19/19 tests).

---

## v4.2.0 — 2026-08-20 (Desktop NAS Sync & Batch Operations + Web Real-Time SSE)
- **Desktop NAS File Watcher & Thumbnail Engine**: Built `WorkspaceWatcherService.cs` and `ThumbnailCacheService.cs`.
- **Desktop Batch Operations & Virtualization**: Extended `SearchCopyPage.xaml` with multi-select ribbon and virtualization.
- **Web Real-Time SSE Feed & Video Range Streaming**: Built `SseService.js` and HTTP 206 partial content range requests in `DeliverableService.js`.

---

## v4.1.0 — 2026-08-19 (Desktop Feature Parity & Studio Overhaul)
- **Desktop Copywriting Studio**: Built `CopywritingPage.xaml` and `CopywritingDesktopService.cs`.
- **Contextual Discussions & Comments Engine**: Built `ProjectCommentService.cs` for `_comments.jsonl`.
- **ClickUp 3.0-Style 2-Column Task Workspace**: Upgraded `SearchCopyPage.xaml`.

---

## v4.0.0 — 2026-08-18 (Centralized Vault Hierarchy & Web Management Portal)
- Unified Year-first hierarchy (`Creative-Team/[YYYY]/[YYYYMM_Month]/[ProjectFolder]`).
- Built Svelte 5 + Node.js Web Management Portal (`SS-CAM.Web`).

---

### Added & Refined Modules
- **Metamorphosis Theme Surface Opacity (`MetamorphosisTheme.xaml`)**: Replaced all semi-transparent white card background brushes (`#26FFFFFF`, `#14FFFFFF`) with solid opaque deep space navy surface colors (`#0F1A3A`, `#142045`), eliminating background text bleed-through on overlay drawers (`DayDetailPanel`) and cards.
- **Input & Control Surfaces**: Replaced transparent control fills with solid navy control fills (`#0C1633` input background, `#14224B` control fill) and updated border stroke tokens (`#1E2E5C`, `#243977`).
- **Web Portal Alignment (`fluent2-tokens.css`)**: Set `--glass-bg` to `#0F1A3A` for `[data-theme="metamorphosis"]`.
- **Automated Quality Attestation**: Source Guardian audit 100% PASS (9/9 checks).

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe` / `dist/SS-CAM-v3.6.1.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v3.6.0 — 2026-08-17 (Fluent UI Web & Data Visualization Release)
- **Fluent UI Web Integration**: Incorporated official Microsoft Fluent UI Web token custom properties (`--colorNeutralBackground1`, `--colorBrandBackground`) and `sscam-fluentui-web` skill guidelines.
- **3-Tier F-Pattern Dashboard**: Built 5-KPI Strategic Summary Bar, Production Stage Pipeline Velocity Flow, and Designer Capacity Heatmap in `DashboardView.js`.
- **Copywriting AI Presets**: Built TikTok Hooks, Facebook Problem/Solution Angles, and Product Packaging Benefit Claims presets in `CopyStudioView.js`.

---

## v3.5.0 — 2026-08-17 (In-App Project Brief Editor, Workspace Designer Scoping & Repository Hygiene)

### Added & Refined Modules
- **In-App Project Brief Markdown Editor (`SearchCopyPage`)**: Live editing and saving of project `README.md` and YAML frontmatter directly inside the Search & Copy catalog pane with Markdown formatting toolbar (Headings, Bold, Italic, Code, List) and real-time feedback via `NotificationService`.
- **Workspace Designer Scoping**: Dynamic discovery and dropdown filtering across designer workspaces (`0001D`, `0002S`, etc.) on local and Synology NAS shares.
- **Minimal Brand Assets & Swatch Inspector**: Minimal 2-column layout with tabbed Primary/Secondary/Neutrals swatches and live HEX/RGB/CMYK/Pantone inspector.
- **Repository Hygiene & Architecture Cleanup**: Eliminated redundant root build binaries, old log files, and obsolete scratch files. Updated `.gitignore` to prevent test workspaces and ephemeral files from dirtying the working tree.
- **Automated Source Guardian Validation**: 100% PASS on UTF-8 BOM, Fluent 2 standards, thread and data safety.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe` / `dist/SS-CAM-v3.5.0.exe`).
- Smoke Test: PASS (`tests/SmokeTest.ps1` — 100% clean instantiation).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v3.5.0-linux — 2026-08-14 (Fedora Linux Native Desktop Port)
- **Linux Platform**: Native Avalonia UI (.NET 8) desktop app scaffolded (`src/SS-CAM.Linux/`).
- **Target OS & NAS**: Fedora Linux (GNOME / Wayland) & Synology Drive Client (`~/SynologyDrive/`).
- **Windows Safety**: Existing Windows WPF application (`src/SS-CAM/`) remained 100% untouched.
- **Source Guardian**: PASS (9/9 automated checks passed).
- **Git Housekeeper**: Cleaned temporary build artifacts, restored UTF-8 BOM, and pushed to `origin/SS-Master`.

---

## v3.4.0 — 2026-08-13 (Starter Canvas Engine, Category Filtering & Calendar Quick Status Actions)

### Added & Refined Modules
- **Starter Canvas Engine**: Integrated `.af`, `.psd`, and `.ai` starter canvas format generation with default Affinity Designer format support (`.af`) and 2026 industry platform specs.
- **Project Creator Presets & Dynamic Category Filtering**: Added Rollup Bunting (80x200cm), Trifold A4 Brochure, A5 Leaflet, and Web Design category presets. Dynamically filters target platform options and highlights visual cards based on category.
- **Search & Copy Category Filter**: Added category filter dropdown in `SearchCopyPage` for dynamic asset and copy snippet filtering.
- **Creative Calendar Quick Status Actions**: Integrated direct project status actions (`In Progress`, `Review`, `Done`) inside `CalendarPage.xaml.cs` day detail view overlay with automatic frontmatter synchronization.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v3.3.0 — 2026-08-13 (Fluent 2 Splash, Notification & Clipboard Services Release)

### Added & Refined Modules
- **Fluent 2 Startup Splash Window (`SplashWindow`)**: Branded Fluent 2 startup splash screen with smooth progress initialization, animated branding visual, and background service loading.
- **Centralized Notification & Clipboard Services (`NotificationService`, `ClipboardService`)**: Toast notification dispatcher for background tasks, copy events, and file system warnings alongside safe non-blocking clipboard helpers.
- **Task Manager Queue & Parser Upgrades**: Expanded drawer sorting options, date sorting refinements, and frontmatter parser enhancements for Markdown rendering.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v3.2.0 — 2026-08-12 (Big Calendar & Task Manager Upgrade Release)

### Added & Refined Modules
- **Big Calendar Module (`CalendarPage`)**: Native 7×6 monthly calendar timetable displaying project creation start dates and campaign deadlines as color-coded chips, Friday Solat indicators, interactive Day Detail Overlay inspector, and month navigation.
- **Task Manager Queue Management**: `created:` frontmatter tag support, auto-inferring legacy project creation dates (`InferCreatedDate`), queue age display (`📅 14d in queue`), FIFO Queue Order sorting (`Oldest First`), and `Created Date` drawer editor.
- **SSNAS Synology Drive Setup Guide**: Created official setup guide (`docs/SSNAS-SETUP.md`).

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v3.1.2 — 2026-08-12 (Multi-User NAS Isolation Release)

### Multi-User NAS Scoping & Isolation
- **User Scoped Config Files**: Personal configs (`user_profile_{username}.json`, `theme_config_{username}.json`, `Notes_{username}/`) are automatically isolated per designer on shared NAS folders.
- **Shared Team Resources**: Category presets (`category_presets.json`) and Team Board announcements (`_Team\team-notes.json`) remain team-wide shared.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).
- GitHub Release: PUBLISHED (v3.1.2 set as Latest on SuamiSihat/ss_cam).

---

## v3.1.1 — 2026-08-12 (NAS Settings & Preferences Auto-Sync Release)

### Native NAS Settings Auto-Sync
- **`NasConfigSyncService`**: Implemented timestamp-aware auto-sync for `user_profile.json`, `theme_config.json`, `category_presets.json`, and `Notes/` directory to `<WorkspaceRoot>\_Team\_Config\`.
- **Multi-PC Seamless Sync**: Setting changes on PC 1 automatically update NAS config files; PC 2 auto-detects and loads newer NAS config on launch.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).
- GitHub Release: PUBLISHED (v3.1.1 set as Latest on SuamiSihat/ss_cam).

---

## v3.1.0 — 2026-08-12 (QR Code Studio & Audio Visualizer Release)

### QR Code Generator & Studio Visualizer Upgrades
- **QR Code Studio Module**: Added `QrCodePage.xaml` / `QrCodeEncoderService.cs` supporting URL, Plain Text, Wi-Fi, and VCard payload types with brand palette customization, high-res PNG file export, and Clipboard copying.
- **Sound Engineer Studio Visualizer**: Upgraded `VisualizerService` with floating Mars symbols (♂), SuamiSihat crest particle physics, peak-reactive motion, and watermark removal.
- **Radio & Audio Studio**: Enhanced `RadioPage` layout, spectrum feedback, and station controls.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).
- GitHub Release: PUBLISHED (v3.1.0 set as Latest on SuamiSihat/ss_cam).
- Documentation: Updated (README, ROADMAP, CHANGELOG, QA Suite aligned to v3.1.0).

---

## v3.0.1 — 2026-08-12 (Art Director Full QA Run)

### Sidebar Navigation & Footer Collapse
- **Categorized Navigation**: Grouped all 11 application modules into 5 logical categories (`OVERVIEW`, `CREATION & ASSETS`, `PRODUCTIVITY`, `WELLBEING & FAITH`, `SYSTEM`) using `ui:NavigationViewItemHeader` and `ui:NavigationViewItemSeparator`.
- **Adaptive Footer Collapse**: `OnNavigationPaneOpened` / `OnNavigationPaneClosed` handlers hide status text and switch bottom player to compact mode when sidebar collapses.
- **Footer Icon Centering**: Status icons correctly centered in compact collapsed mode.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).
- GitHub Release: PUBLISHED (v3.0.1 set as Latest on SuamiSihat/ss_cam).
- Documentation: Updated (README, FINAL-QA-REPORT, QA/README, 10-FIX-LOG aligned to v3.0.1).

---

## v3.0.0 — 2026-08-12 (Major Release)

### Major UI/UX & Settings Module Overhaul
- **Settings & Profile Revamp**: Rebuilt `SettingsPage.xaml` with Fluent 2 two-column grid, section icon badges, interactive theme swatches (Falconia, Metamorphosis, Catppuccin, Rosé Pine, Nord), workstation payload installer, category preset management, and reset action rows.
- **Theme Engine Expansion**: Added 3 new switchable theme profiles (`Catppuccin`, `RosePine`, `Nord`) to `SettingsPage.xaml.cs` and `ThemeService.cs`.
- **Navigation Safety**: Relocated Settings item to `MenuItems` in `MainWindow.xaml` to eliminate hit-test collisions.
- **100% Clean Source Guardian & Encoding**: Fixed non-ASCII characters with XML entities, restored UTF-8 BOM, and verified zero undefined `DynamicResource` tokens.

### Verification
- Release Build: PASS (`SS-CAM-v3.0.0.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v2.6.3 — 2026-08-11 (Art-Director & Architecture Audit Remediation)

### Phase P0: Git Hygiene & Core Logic Fixes
- **Binary Untracking**: Un-tracked ~50 MB of binary files (`src/SS-CAM/packages/`, `SS-CAM-v2.6.1.exe`, `nuget.exe`) from Git tracking.
- **Regex Capture Fix**: Updated `ProjectPattern` in `WorkspaceScanner.cs` to `^(\d{6})_([A-Z0-9]+)(?:_([A-Z0-9_-]+))?` to parse job and brand codes.
- **Hardcoded Path Clean**: Removed machine-specific `e:\Dev\...` path fallback from `PayloadInstallerService.cs`.

### Phase P1: Async Network & Timer Leak Prevention
- **Async Network Fetch**: Replaced synchronous `HttpWebRequest` in `PrayerTimeService.cs` with static `HttpClient` singleton and `FetchTodayAsync`.
- **UI Responsiveness**: Made `WaktuSolatPage.xaml.cs` fetch asynchronous to eliminate 2–9s UI thread freezes.
- **Timer Leak Fixes**: Added `Unloaded` handlers to stop `DispatcherTimer` instances on `WaktuSolatPage`, `WellbeingPage`, and `DesignTokensPage`.
- **Dark Mode Repair**: Fixed hardcoded hex avatar border colors in `SettingsPage.xaml` using `{DynamicResource FluentBrand80}` and `{DynamicResource FluentBrand70}`.

### Phase P2: UI/UX Token & Icon Standardization
- **Dynamic Surface Tokens**: Converted hardcoded white backgrounds in `SearchCopyPage.xaml`, `QuickNotePage.xaml`, `TaskManagerPage.xaml`, and `ProjectCreatorPage.xaml` to `{DynamicResource TextControlBackground}` and card tokens.
- **Icon Vector Migration**: Replaced raw text emojis in `ProjectCreatorPage.xaml` with vector Segoe Fluent icons (`&#xE713;`, `&#xE8B7;`, `&#xE8EA;`, `&#xE8B2;`, `&#xE749;`).
- **Control Template Target**: Fixed `ControlTemplate TargetType="ui:Button"` in `DesignTokensPage.xaml`.

### Phase P3: Synology NAS & Diagnostics Safety
- **NAS File Lock Resilience**: Added 3-attempt exponential backoff retry loop for `IOException` in `TeamBoardService.Save`.
- **MAX_PATH Protection**: Added 240-character path validation to `ProjectGeneratorService.cs`.
- **Diagnostic Logging**: Replaced all silent `catch {}` blocks across `PrayerTimeService`, `ThemeService`, `ProjectCreatorPage`, `SearchCopyPage`, and `MainWindow` with `Debug.WriteLine` logging.

### Verification
- Release Build: PASS (`src/SS-CAM/bin/Release/SS-CAM.exe`).
- Source Guardian: PASS with 9/9 passed, 0 warnings, 0 fails (`verify-sscam.ps1`).

---

## v2.6.1 — 2026-08-11 (Header Title Rebranding & Persistent SS Blue Wavelength Player)

### Key Updates & Fixes
- **Header Title Rebranding**: Rebranded app title to `SS Creative Assets Management` with a 100% full-width `#022057` SuamiSihat deep blue TitleBar strip, transparent window caption buttons (`— 🗖 ✕`), and native window dragging (`DragMove`).
- **Persistent SS Blue Bottom Radio Player Bar**:
  - Full SuamiSihat deep blue background (`#022057`) with `#043388` accent border.
  - **Fluid Wavelength Vector Audio Visualizer**: 60 FPS real-time vector path visualizer (`StreamGeometry`) featuring a 4-stop gradient stroke (`#60A5FA` → `#38BDF8` → `#34D399` → `#818CF8`) and ambient gradient fill under the wave curve.
  - **Station Cover Image**: Integrated station cover art image loader (`BitmapImage`) supporting local/remote artwork with seamless emoji fallback.
  - **Aligned Now-Playing Layout**: Aligned Station Name + Emerald Green `LIVE` Pill on Line 1, and `NOW PLAYING:` tag + track subtext on Line 2, centered vertically alongside the 40x40 cover image.
- **Top Hero Featured Radio Player Banner**: Refactored `RadioPage.xaml` into a 4-row layout featuring a Top Hero Featured Station Banner, eliminating player redundancy.
- **Strict Equal-Height Dashboard KPI Grid**: Enforced `UniformGrid Rows="2" Columns="4" Height="224"` with `VerticalAlignment="Stretch"` on all 8 KPI widgets for 100% uniform cell heights across all rows.
- **Sidebar Cleanup**: Removed redundant radio status text from left navigation sidebar footer (`PaneFooter`).

### Verification
- Release Build: PASS (`bin\Release\SS-CAM.exe`).
- Source Guardian: PASS with 0 FAIL findings (`verify-sscam.ps1`).
- Package Executables: `SS-CAM-v2.6.1.exe` and `dist\SS-CAM-v2.6.1.exe` verified.

---

### Phase 1 — UI/UX Modernization
- **Dashboard Enhancements**: Updated metric cards with relative time calculations ("Today", "2 days ago") and replaced GroupBox containers with elevated `<ui:Card>` components.
- **Project Creator Polish**: Replaced all GroupBox containers with Fluent 2 `<ui:Card>` wrappers and migrated text emojis to `ui:SymbolIcon` vector icons.

### Phase 2 — High-Impact Workflow Automation
- **Deep App Bridge**: Added dynamic canvas launcher button ("Open in Photoshop / Illustrator / Affinity") to Project Creator success UI.
- **One-Click Project Finalizer**: Added "Finalize & Archive..." feature to Search & Copy inspector. Automatically locates and compresses `04_Production`/`_Deliverables` and `01_Artwork_Design`/`_Raw_Assets` into standardized ZIP archives.
- **Dependencies**: Added `System.IO.Compression` and `System.IO.Compression.FileSystem` assembly references.

### Phase 3 — Visual Tools & Assets Management
- **Global Brand Kit Quick-Tray**: Added `🎨 Brand Kit` title bar button and popover tray with 1-click HEX swatch clipboard copying accessible anywhere in the app.
- **Visual Asset Lightbox**: Upgraded image previewer in Search & Copy to a dark Fluent 2 Lightbox modal (`#0B1120`) displaying pixel dimensions, file size, format badges, and action controls.
- **Visual Version Control Timeline View**: Added `Timeline` mode tab to Search & Copy inspector. Scans project directory and renders chronological revision timeline with color-coded status badges (`Revision`, `Production`, `Master Canvas`, `Asset`).

### Verification
- Debug Build: PASS (`SS-CAM -> bin\Debug\SS-CAM.exe`).
- Source Guardian: PASS with zero FAIL findings (`verify-sscam.ps1`).
- Package Executable: [`SS-CAM-v2.6.2-Phase3.exe`](file:///e:/Dev/Projects/SS-Brand-Assets/SS-CAM-v2.6.2-Phase3.exe) generated and verified.

## Unreleased — 2026-08-11 (SS Default Theme and Title Bar)

### P1 — High

- **BUG-11** SS Default applied WPF-UI Dark mode despite declaring a light canvas and card palette. It now applies Light mode, restoring the intended light content surface while retaining the SS navy navigation pane and blue title bar.

### P2 — Medium

- **BUG-12** Title bar header content was allowed to measure to its content width, leaving a large left gap before the navigation toggle. The title bar header now stretches through the supported WPF-UI content-alignment properties; the explicit toggle inset was also removed.

### P3 — Low

- **BUG-13** Replaced all silent `catch {}` blocks with diagnostic logging, including best-effort cleanup paths, so recoverable failures remain traceable without changing existing fallback behaviour.
- **BUG-14** Replaced raw Unicode title-bar tooltip characters with XML entities to prevent source encoding regressions.

### Verification

- Debug build: PASS.
- Source Guardian: PASS with no warnings.
- Visual desktop confirmation: BLOCKED; the available desktop-capture session could not initialize.

## v2.6.0 — 2026-08-11 (Smoke Test Bug Fix Release)

### P0 — Critical

- **BUG-01** `FrontmatterService.ParseFrontmatter` — `return null` on unclosed frontmatter block replaced with `return result`. Task Manager now correctly reads projects whose README.md has missing closing `---`.

### P1 — High

- **BUG-02** Version string mismatch — `CurrentVersion`, `AssemblyVersion`, window title, and CHANGELOG all aligned to v2.6.0.
- **BUG-03** `OnStatusThemeToggle` — wired to the Theme row in `MainWindow.xaml` via `MouseLeftButtonDown` + `Cursor="Hand"` + ToolTip. Theme cycling from sidebar footer is now functional.
- **BUG-03** Orphaned handlers `OnOpenGithub` and `OnOpenAboutWindow` removed from `MainWindow.xaml.cs` (no XAML targets existed).
- **BUG-04** Dead fields `isSidebarExpanded` and `_lastActiveNavBtn` removed from `MainWindow.xaml.cs`. Compiler warnings eliminated.

### P2 — Medium

- **BUG-05** `workspaceRoot` default changed from `D:\Testing` to `string.Empty` in `DashboardPage`, `SearchCopyPage`, and `ProjectCreatorPage`. Unconfigured installs no longer silently scan a non-existent path.
- **BUG-06** `TeamBoardService.GetNotesPath` now guards against creating `_Team` folder on an inaccessible or unconfigured `workspaceRoot` (returns `null`). `Save()` checks for `null` path and returns `false` immediately. Fixes silent local write when NAS is offline.
- **BUG-07** `WorkstationHealthPage.OnRescanSoftwareClicked` — dynamic count from `ScanInstalledDesignSoftware()` with correct pluralisation replaces hardcoded "11 packages".
- **BUG-08** `DashboardPage._httpClient` — singleton `static readonly HttpClient` replaces per-fetch `new HttpClient()` inside `using`. Eliminates socket exhaustion risk.
- **BUG-09** `QuickNotePage.RenderPreview` — added `###` H3 branch (`FontSize=14, SemiBold`) before `##` and `#` checks to fix check-order collision.

### P3 — Low

- **BUG-10** `FrontmatterService` — `ReadStatus` and `WriteStatus` silent `catch {}` replaced with `catch (Exception ex) { Debug.WriteLine(...) }`.
- **BUG-10** `TeamBoardService` — `LoadNotes`, `Save`, and `GetNotesPath` silent `catch {}` replaced with `Debug.WriteLine` logging. `using System.Diagnostics` added to both services.

---

## P0: Component Refactoring (MainWindow & Fluent 2 UI)

- Migrated legacy Sidebar to `Wpf.Ui NavigationView`.
- Refactored `MainWindow.xaml` and `MainWindow.xaml.cs`.
- Converted all 117 `<Button>` instances to `<ui:Button>` across 11 XAML Pages.
- Converted all `<TextBlock>` instances to `<ui:TextBlock>` across all Pages.
- Globally configured `Wpf.Ui.Appearance.Accent` to use Brand Cyan.

## P1 & P2: Backend Reliability

- Implemented `JsonPersistenceHelper.cs` to eliminate serialization crashes and duplication.
- Refactored `UserProfileService.cs` and `ThemeService.cs` to use the helper.
- Hardened `PrayerTimeService.cs` to enforce TLS 1.2 and use a 10s timeout to prevent UI freezes.
- Added NAS Pre-flight checks (`Directory.Exists`) to `ProjectGeneratorService.cs` and `WorkspaceScanner.cs`.

## P1: Creative Wellbeing & Biometric Suite Overhaul (v4.4.4)

- **Biometric Radar Mathematical Label Positioning**:
  - Replaced hardcoded text offsets with dynamic quadrant-specific text measurement (`Measure(Size)`), resolving label-polygon overlap across all 5 axes (`Energy`, `Focus`, `Rest`, `Pressure`, `Flow`).
- **Biometric Flow Calibrator**:
  - Integrated 1–5 baseline rating system for Vitality, Cognitive Lock, and Perceived Stress with standardized Segoe UI Variable typography.
- **Hydration Tracker & Full-Height Balance**:
  - Fixed empty top/bottom whitespace by normalizing Fluent 2 card padding and wave container height.
- **Dynamic 30-Day Heatmap**:
  - Standardized day coordinate math, day labels (`Mon`, `Wed`, `Fri`), and high-contrast theme-aware 0-minute day tiles.



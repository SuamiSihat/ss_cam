# Phase 1 Security Report: Web Portal

**Date:** 2026-10-14
**Scope:** `src/SS-CAM.Web` (server, client, Docker files). Source of the findings: a read-only code review earlier the same day. Plan: `C:\Users\brand\.claude\plans\federated-twirling-wave.md`.
**Status key:** PASS = verified by a test or a live run described below. PARTIAL = fixed in part, or the code change is made but one part could not be checked here. BLOCKED = needs a decision or access I do not have. N/A = not applicable.

## How it was verified

| Check | Result |
|---|---|
| `node server/test/security-tests.js` (new; throwaway workspace and data folder) | **PASS** 37 / 37 |
| `node server/test/run-tests.js` (existing suite) | **PASS** 71 / 71 (see note on two one-off failures) |
| `node server/test/admin-smoketest.js` (existing) | **PASS** 13 / 13 (4 assertions updated, see below) |
| Client compiles (`vite build` into a scratch folder) and `svelte-check` shows no errors in the changed files | **PASS** |
| Real server (`server/index.js`, port 4107, temp data): headers, 413 on a 200 KB sign-in body, bootstrap sign-in → forced password change → new session → media cookie → live stream → sign-out | **PASS** |
| `npm audit --omit=dev` | **PASS** 0 vulnerabilities (was 3: 1 critical, 2 high) |
| The same tests against the original code | Run once; all 18 tests that existed then failed (some only because the new functions did not exist, so this proves the tests exercise new behaviour, not that each one isolates a single old bug) |

**Two one-off failures.** In one run the existing "Password Reset Suite" test failed, and in another "Admin RBAC … POST /api/team/roster got 400". Neither reproduced in the next 14 runs of the suite (the response body is now printed in that assertion so a recurrence shows its cause). I did not find a cause. Status: **PARTIAL** (not explained).

**Existing tests changed.** The Gemini test asserted the old 6-character key prefix (now last four only). Four admin smoke-test assertions fetched `/companies` and `/projects/:id/asset` without signing in; they now sign in and also assert that an anonymous request is refused. No test was removed or weakened.

## Findings

| ID | Finding | Status | Evidence / note |
|---|---|---|---|
| C1 | Live-update stream and data endpoints readable without sign-in | **PASS** | Tests "C1 …" (anonymous = 401 on 14 routes and the stream; cookie opens media and the stream only; revoked session ends the cookie). Live run confirmed 401/200. |
| C2 | Account takeover by choosing a look-alike name | **PASS** | Test "C2 …": renaming to another person's name is refused (409); a body naming another staff ID edits only the caller. Ambiguous names never sign anyone in. |
| H1 | Admin password edits stored in plain text, returned and broadcast | **PASS** | Test "H1 …": not in roster, profile file or response. Start-up scrub removes older leftovers (test). **Action for you:** the real roster and profile files on the NAS may already contain passwords; the scrub runs when the server next starts. Treat any password typed in the Admin screen before this fix as exposed. |
| H2 | Stored XSS through uploaded SVG | **PARTIAL** | Server: sandbox CSP, nosniff and download-on-open verified by test; runnable types blocked on upload (test). CSP `script-src 'self'` only: verified in the live header and the built client has no inline script or `eval`. **Not verified in a browser** that every page still renders under the stricter CSP (see Not verified). |
| H3 | Weak brute-force limits | **PASS** | Tests "H3 …": per-account lock shared across username/name, colleagues unaffected, admin unlock, one address spraying many accounts is stopped. Counters are in memory (reset on restart). Docker publishing is loopback by default (not run, see H9). |
| H4 | Default and seeded passwords | **PASS** | New accounts and every admin-typed or generated password force a change; random one-time password shown once; plain-text store hashed at start-up (tests). `DEFAULT_STAFF_PASSWORD` is kept only so people still on the old shared default are forced to change it. |
| H5 | Sessions cannot be ended; token in URL | **PASS** | Tests: password change, suspension, sign-out end sessions; `?token=` refused; only HS256 accepted. |
| H6 | Weak share-link controls | **PARTIAL** | Tests cover manage rights, allowlist, 30-day cap, scoping to project and single file, guest data trimmed, view-only enforced, guest limits. Not done: tokens are still stored readable (needed to re-show links in the UI). |
| H7 | Any designer can write anywhere / delete projects via archive | **PASS** | Test "H7 …". |
| H8 | Placeholder JWT secret accepted | **PASS** | Test "H8 …": placeholder, repetitive and short secrets stop start-up in production; `.env.example` is blank. |
| H9 | Docker hardening | **PARTIAL** | Changed: loopback-only publishing (configurable with `PORTAL_BIND`), `no-new-privileges`, `--ignore-scripts`, `.dockerignore`. **Not run** (no Docker here). Not changed: the container still runs as root with the app folder mounted (switching user could break file access on the NAS) and `npm install` still runs at start. |
| M1 | Email HTML injection | **PASS** | Test "M1 …". |
| M2 | Reset-link weaknesses | **PASS** | Tests "M2 …": hashed at rest, newer link replaces older, single-use, suspended accounts refused, email masked, host from configuration. |
| M3 | Password hashing / policy | **PARTIAL** | bcrypt cost 12 (4 under test). Length rule (10) unchanged; no breached-password list. |
| M4 | Webhook SSRF and exposure | **PASS** | Test "M4 …": https only, chat services must use their own hosts, private/metadata addresses refused (DNS result checked at send time, no redirects, 10 s timeout), list is admin-only and masked. `WEBHOOK_ALLOWED_HOSTS` allows an internal gateway deliberately. |
| M5 | Gemini key handling | **PARTIAL** | Key sent in a header, model name validated, provider error text no longer returned, only last four shown (test). The key is still stored readable in `_Team/ai-config.json`; use the `GEMINI_API_KEY` environment variable to avoid that. |
| M6 | Error messages leak internals | **PASS** | Test "M6 …" and live run (generic message plus a short reference; detail in the log). |
| M7 | Upload and body limits | **PARTIAL** | Body limits verified live (413). File-type block list tested. Uploads remain memory-buffered and there is no allowlist. |
| M8 | Coarse authorization | **PARTIAL** | Tested: orders, import-to-project, reassign, notes, share links, archive, `/auth/users`, webhooks. Not changed (needs a decision): who may edit copy; many task/studio-task routes still allow any signed-in person. |
| M9 | Role names granted by substring | **BLOCKED** | Real staff rely on it today (roster roles are free-text titles). Needs the Phase 2 role model plus a roster migration. |
| M10 | Dependencies | **PARTIAL** | multer 2.x; production audit clean. 7 advisories remain in dev/build tools (mermaid → katex, which is bundled into the client); fixing needs a breaking upgrade. |
| M11 | Markdown / CSS injection | **PARTIAL** | Wikilink values escaped, `style` forbidden in the sanitiser (image width now an attribute). Compiles; **not exercised in a browser**. |
| L1 | Audit gaps | **PASS** | Sign-in success/failure, sign-out, password change, share-link create/revoke, order cancel are audited. The audit file is still plain JSONL on the shared drive (not tamper-evident). |
| L2 | CORS/CSP defaults | **PASS** | Production default allows only `APP_URL`; credentials off; Google Fonts allowed explicitly. |

## Not verified (do before release)

1. **Browser check under the new CSP.** Load every page (Dashboard, Projects, Deliverables with an image, video and PDF, Copy Studio with Mermaid, Admin, Signage, a share-review link, Login) and watch the console for CSP violations. Fonts depend on `fonts.googleapis.com` being allowed.
2. **Images, downloads and live updates in a real browser** after sign-in: the media cookie, the 30-minute renewal and the live-stream reconnect after the cookie expires. Only the server side was exercised.
3. **Other clients against the new server:** the Windows app (portal sign-in, orders, Quick Notes), Android, and Linux. They use the Authorization header, so they should be unaffected, but none was run. Notes now return only team notes and the caller's own.
4. **Docker:** `docker compose up` with `PORTAL_BIND` unset, confirm the reverse proxy still reaches port 4000 on the NAS and nothing else needs the LAN address.
5. **Deployment steps:** set a real random `JWT_SECRET` (the server now refuses placeholders); rotate the Gemini key and the webhook addresses if they were ever visible to non-admins; ask everyone to sign in again (sessions from before this release are still accepted until they expire, then the version check applies from the next password change).
6. **Rebuild `client/dist`** (it is committed and served by the portal). I built into a scratch folder only, so `dist` is unchanged.

## Behaviour changes people will notice

- Signing in with an admin-set or temporary password asks for a new password first.
- Admin "Reset password" and "Add team member" show a one-time temporary password in a message that stays until dismissed.
- Changing your email address on the Profile page asks for your current password.
- Share links can last at most 30 days (the "No expiration" option was removed).
- A suspended account now sees the normal "wrong username or password" message at sign-in.
- Guests on a review link no longer see internal creative direction, copy or staff comments.
- Signing out ends the session on the server.

## Changes outside the security scope worth knowing about

- None to behaviour. One data-safety issue was noticed and left alone: uploads overwrite a same-named file without warning (see Open Items in `ROUTE-AUTHZ-MATRIX.md`).

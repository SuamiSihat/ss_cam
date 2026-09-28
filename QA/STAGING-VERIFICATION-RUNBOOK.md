# SS-CAM v4.11.1 Staging Verification Runbook (Task 5.2)

**Audience:** Human QA / Release Operator  
**Target Release:** v4.11.1  
**Release Gate Requirement:** Phases 0 to 2 are the release gate. Do not host for third parties or deploy to production until staging checks pass.

---

## 1. Staging Environment Setup

Launch the staging server on an isolated port (e.g. `3001`) with a sandbox workspace copy:

```bash
# In src/SS-CAM.Web
cd src/SS-CAM.Web

# Set staging environment variables
export PORT=3001
export NODE_ENV=staging
export JWT_SECRET="staging-strong-secret-key-at-least-32-chars-long-12345"
export WORKSPACE_ROOT="./sample-workspace"
export DATA_DIR="./staging-data"

# Launch staging server
node server/index.js
```

Verify server startup in logs:
```
[Server] Listening on http://0.0.0.0:3001
[Config] Workspace: .../sample-workspace
[Config] Data Dir: .../staging-data
```

---

## 2. Release Gate Manual Verification Checklist

Execute the following 5 checks against `http://localhost:3001`:

### Check 1: Empty & Whitespace Password Rejection
- **Action:** Attempt login with an existing username and an empty/blank password.
  ```bash
  curl -s -i -X POST http://localhost:3001/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"harussani","password":""}'
  ```
- **Expected Result:**
  - HTTP Status: `401 Unauthorized`
  - Response body: `{"error":"Invalid credentials. Please verify your username and password."}`

### Check 2: Shared Default Password Rejection
- **Action:** Attempt login with the legacy default password (`SuamiSihat123!`).
  ```bash
  curl -s -i -X POST http://localhost:3001/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"harussani","password":"SuamiSihat123!"}'
  ```
- **Expected Result:**
  - HTTP Status: `401 Unauthorized` (unless the user has explicitly and intentionally set their password to that string).

### Check 3: Forged / Old Secret JWT Rejection
- **Action:** Submit an API request with a JWT token signed with an invalid or outdated secret.
  ```bash
  curl -s -i -X GET http://localhost:3001/api/auth/me \
    -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
  ```
- **Expected Result:**
  - HTTP Status: `401 Unauthorized`
  - Response body: `{"error":"Token verification failed or expired"}`

### Check 4: Designer Role Authorization Denial (RBAC)
- **Action:** Authenticate as a staff member with role `Designer` (e.g., token from valid login) and attempt an administrative mutation:
  ```bash
  curl -s -i -X POST http://localhost:3001/api/users \
    -H "Authorization: Bearer <DESIGNER_JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"username":"malicious_user","role":"admin"}'
  ```
- **Expected Result:**
  - HTTP Status: `403 Forbidden`
  - Response body: `{"error":"Access denied: insufficient administrative privileges"}`
  - Audit Trail Verification: Inspect `_Team/audit-log.jsonl` (or staging data log) — confirm an entry was recorded with `action: "SECURITY_ACCESS_DENIED"`.

### Check 5: Brute-Force Rate Limiting
- **Action:** Send 6 rapid failed login attempts within 15 minutes:
  ```bash
  for i in {1..6}; do
    curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:3001/api/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"harussani","password":"wrongpassword"}';
  done
  ```
- **Expected Result:**
  - Attempts 1–5: `401`
  - Attempt 6: `429 Too Many Requests`
  - Response body on 6th attempt: `{"error":"Too many failed login attempts. Please wait 15 minutes before trying again."}`

---

## 3. Sign-Off Criteria

| Item | Result | Sign-Off Date | Operator |
|---|---|---|---|
| Check 1: Empty password 401 | [ ] PASS | | |
| Check 2: Default password 401 | [ ] PASS | | |
| Check 3: Old secret token 401 | [ ] PASS | | |
| Check 4: Designer gets 403 on admin routes | [ ] PASS | | |
| Check 5: 6th failed login gets 429 | [ ] PASS | | |

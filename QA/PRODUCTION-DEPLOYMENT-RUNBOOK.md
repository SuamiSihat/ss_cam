# SS-CAM v4.11.1 Production Deployment & 48-Hour Monitoring Runbook (Task 5.3)

**Audience:** System Administrator / Production Operations  
**Target Release:** v4.11.1  
**Target Platform:** Synology NAS Docker Environment (`creative.suamisihat.myds.me`)

---

## 1. Safety & Data Protection Prerequisites

Before deploying any container updates or restarting services, complete the following safety steps:

1. **Workspace Snapshot / Backup**:
   Create a timestamped backup of the current workspace config and credentials:

   ```bash
   # On the NAS host or admin workstation
   mkdir -p /volume1/backups/sscam-pre-4.11.1-$(date +%Y%m%d_%H%M%S)
   cp -r /volume1/Creative-Team/_Team/_Config /volume1/backups/sscam-pre-4.11.1-*/
   ```

2. **Password Store Backup**:
   If an existing `user_passwords.json` exists in `_Team/_Config/` or local `data/`:

   ```bash
   cp /volume1/Creative-Team/_Team/_Config/user_passwords.json /volume1/backups/sscam-pre-4.11.1-*/user_passwords.json.bak
   ```

---

## 2. Production Environment Configuration

1. **Verify or Generate `.env`**:
   Ensure `src/SS-CAM.Web/.env` contains strong production credentials:

   ```ini
   NODE_ENV=production
   PORT=4000
   HOST=0.0.0.0
   # Strong random secret at least 32 characters long
   JWT_SECRET="generate-a-cryptographically-secure-random-string-min-32-chars-long"
   JWT_EXPIRES_IN=12h
   WORKSPACE_ROOT=/volume1/Creative-Team
   DATA_DIR=/app/data
   ALLOWED_ORIGINS=https://creative.suamisihat.myds.me
   # Optional: set emergency bootstrap password if fresh setup
   # ADMIN_BOOTSTRAP_PASSWORD="TemporaryEmergencyAdminPassword123!"
   ```

2. **Verify Docker Compose Configuration**:
   Ensure `src/SS-CAM.Web/docker-compose.yml` mounts the isolated data directory:

   ```yaml
   volumes:
     - /volume1/Creative-Team:/volume1/Creative-Team
     - sscam-web-data:/app/data
   ```

---

## 3. Deployment Procedure

1. **Pull and Rebuild Container**:

   ```bash
   cd src/SS-CAM.Web
   docker compose pull
   docker compose down
   docker compose up -d --build
   ```

2. **Verify Container Status & Logs**:

   ```bash
   docker compose ps
   docker compose logs -f sscam-web
   ```

   Confirm startup banner:

   ```text
   [Config] NODE_ENV: production
   [Config] Production JWT_SECRET verified (length >= 32).
   [Config] DATA_DIR configured: /app/data
   [Server] Listening on http://0.0.0.0:4000
   ```

---

## 4. Production Smoke Test

Immediately following container startup, perform a smoke test:

1. Navigate to `https://creative.suamisihat.myds.me` in an incognito browser.
2. Verify brand login screen loads without CSP errors in browser console.
3. Authenticate with an administrator account (e.g. `harussani`).
4. Confirm navigation to Admin portal, Project Management, and Creative Orders.
5. In `AdminView.svelte`, verify user roster and company hierarchy load cleanly.

---

## 5. 48-Hour Audit Log Monitoring

During the initial 48-hour release window, monitor the audit stream for anomalous behavior:

```bash
# Monitor live audit stream
tail -f /volume1/Creative-Team/_Team/audit-log.jsonl | grep -E "SECURITY_ACCESS_DENIED|LOGIN_FAILED|SECURITY_PERMISSION_DENIED"
```

### Action Thresholds

- **`SECURITY_ACCESS_DENIED`**: Investigated if repeated from non-administrative staff.
- **Multiple `LOGIN_FAILED` in short succession**: Verify rate limiting triggers HTTP 429.
- **`PASSWORD_MIGRATED`**: Expected as active users log in and their legacy plaintext passwords are upgraded to bcrypt hashes.

---

## 6. Git Tagging & Release Handover (Human Execution)

Once staging verification and production smoke tests are satisfied:

```bash
# On the release branch (fix/p5-release or after merging to staging / SS-Master)
git tag -a v4.11.1 -m "Release v4.11.1: Security Hardening, RBAC Enforcement & Repository Hygiene Remediation"
git push origin v4.11.1
```

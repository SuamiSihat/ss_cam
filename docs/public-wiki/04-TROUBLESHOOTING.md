# Troubleshooting & Network Diagnostics

This guide covers common network, filesystem, and Docker configuration challenges when deploying CAM Studio in an on-premise studio environment.

---

## 1. Built-in Diagnostic Pre-Flight Tool

CAM Studio includes an automated diagnostics tool under **Settings > Network Diagnostics**:
- **Test 1: LAN SMB Throughput:** Measures local read/write IOPS against the configured storage vault.
- **Test 2: Web Portal REST API:** Sends an HTTP healthcheck ping to `http://<nas-ip>:3000/api/health`.
- **Test 3: File Permissions:** Verifies that the current Windows user possesses write, create, and rename permissions on the destination creative directories.

---

## 2. Common Issues & Solutions

### A. Windows SmartScreen "Untrusted Publisher" Warning
- **Cause:** Fresh releases or community builds that have not accumulated high reputation on Microsoft SmartScreen telemetry.
- **Resolution:** Commercial edition builds are digitally signed with an Authenticode EV/OV certificate. If you are evaluating a community pre-release, click **More Info** > **Run Anyway**.

### B. "Network Path Not Found" or Vault Disconnection
- **Symptom:** Workspace items show offline or file saves fail.
- **Causes & Fixes:**
  1. **Sleep / Wake Disconnect:** Windows may spin down SMB network adapters on sleep. In Device Manager, uncheck *"Allow the computer to turn off this device to save power"* on your Ethernet adapter.
  2. **UNC Path Resolution:** If `\\NAS-SERVER\vault` fails due to NetBIOS or mDNS drops, use the static IP instead (e.g., `\\192.168.1.100\vault`).
  3. **SMB Version:** Ensure SMB2/SMB3 is enabled on your Synology NAS (**Control Panel > File Services > SMB > Advanced Settings**). Do not use SMB1.

### C. Docker Web Portal "Port 3000 Already in Use"
- **Cause:** Another service on your Synology NAS or server is bound to port 3000 (e.g., Grafana or AdGuard).
- **Resolution:** In your `docker-compose.yml`, remap the host port:
  ```yaml
  ports:
    - "3080:3000"
  ```
  Then update `endpoints.portalUrl` in your `TenantConfig.json` to point to port 3080.

### D. File Locking During Myers LCS Diffing
- **Symptom:** An error occurs stating *"The process cannot access the file because it is being used by another process"*.
- **Resolution:** CAM Studio opens files with `FileShare.ReadWrite` to allow non-intrusive diff comparisons while editors have files open in Photoshop or Premiere. If another tool holds an exclusive file lock, close the saving application or pause third-party cloud sync tools (e.g., Dropbox/Drive) on that directory.

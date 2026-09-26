# Getting Started with CAM Studio

This guide walks you through installing CAM Studio on your desktop workstations and deploying the team Web Portal onto your local Synology NAS or Linux server.

---

## 1. System Requirements

### Workstation (Windows Desktop)
- **Operating System:** Windows 10 (version 1903+) or Windows 11 (64-bit).
- **Runtime:** .NET Framework 4.8 or higher.
- **Hardware:** 
  - Dual-core 2.0 GHz CPU or faster.
  - Minimum 4 GB RAM (8 GB+ recommended for large multi-gigabyte PSD/AI project archives).
  - 250 MB free disk space for desktop workstation files.
- **Network:** 1GbE LAN connection (10GbE strongly recommended for high-bitrate 4K video workflows).

### Server / NAS (Web Portal & Sync Daemon)
- **Supported Platforms:** 
  - Synology NAS running DSM 7.0+ with Container Manager / Docker installed.
  - QNAP NAS with Container Station.
  - Ubuntu 20.04+ / Debian 11+ / TrueNAS SCALE.
- **Resources:** 1 vCPU, 1 GB RAM, and persistent storage volume for creative assets.

---

## 2. Windows Workstation Installation

1. Download the latest installer `CAM-Studio-Setup.exe` from the [Commercial Download Hub](https://getcam.dev/#download).
2. Double-click the installer to launch the setup wizard.
3. Choose your installation directory (default: `%LocalAppData%\Programs\CAM-Studio\`).
4. Select optional desktop shortcuts and click **Install**.
5. Launch **CAM Studio**. On first launch, the application will initialize your local workspace and display the pre-flight setup assistant.

---

## 3. Synology NAS 1-Click Docker Setup

To enable multi-user order tracking, team cataloging, and web-based asset sharing, deploy the companion Web Portal onto your Synology NAS:

1. Open **DSM** and launch **Container Manager** (or Docker).
2. Go to **Project** > **Create**.
3. Set Project Name to `cam-studio`.
4. Set Path to `/volume1/docker/cam-studio`.
5. Paste the following `docker-compose.yml`:

```yaml
version: '3.8'

services:
  cam-portal:
    image: ghcr.io/product/cam-portal:latest
    container_name: cam-studio-portal
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - NODE_ENV=production
      - TENANT_CONFIG=/app/config/tenant_config.json
      - STORAGE_PATH=/app/vault
    volumes:
      - /volume1/Creative-Vault:/app/vault
      - /volume1/docker/cam-studio/config:/app/config:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

6. Click **Next** and **Done** to launch the container.
7. Access the Web Portal in your browser at `http://<your-nas-ip>:3000`.

---

## 4. Workstation Connection to NAS

1. In the CAM Studio desktop app, navigate to **Settings > Storage & Network**.
2. Under **Local Creative Vault**, select your mapped network drive or UNC path (e.g., `Z:\Creative-Vault` or `\\NAS-SERVER\Creative-Vault`).
3. Under **Web Portal URL**, enter `http://<your-nas-ip>:3000`.
4. Click **Test Connection**. A green indicator confirms successful handshake.

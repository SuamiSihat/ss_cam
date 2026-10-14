# SuamiSihat Coupling Inventory (Phase 0)

This document is an inventory of every hardcoded SuamiSihat-specific reference across the SS-CAM codebase (WPF, Web, and Android). To complete the Core/Edition split, each of these must be migrated into a tenant configuration file or relegated to the SuamiSihat Edition layer.

## 1. Network & NAS Paths

- **`creative.suamisihat.myds.me`**
  - Android: `TeamHubScreen.kt`, `SettingsProfileScreen.kt`, `SscamApiService.kt`, `MainActivity.kt` (Base API URLs and sync messages)
  - WPF: `CreativeOrderService.cs`, `QuickNoteService.cs`, `OrderRequestsPage.xaml.cs`
    - [RESOLVED 2026-10-14] `CreativeOrderService.cs` and `QuickNoteService.cs` no longer use a hard-coded user name: they use `PortalAuthService` (Windows sign-in in Settings, password encrypted with DPAPI). Without a signed-in account, orders fall back to the NAS ledger (`_Orders/creative-orders.jsonl`).
  - Web: `WebhookService.js`
- **`assets.suamisihat.myds.me`**
  - Web: [RESOLVED 2026-10-14] The legacy web client (`client/js/views/AdminView.js`, `LoginView.js`) that held these links has been removed.
  - WPF: `VisualizerService.cs`, `DesignTokensPage.xaml.cs`, `BrandAssetsPage.xaml.cs` (Fluent CSS URL, Hero Mesh)
- **`radio.suamisihat.myds.me`**
  - Android: `StudioRadioScreen.kt`
  - WPF: `RadioStreamService.cs` (Insert at index 0, hardcoded preset checking)
- **NAS SMB/Physical Paths**
  - Web: `\\SSNAS\Creative-Team` hardcoded in `reset-portal-data.js` and referenced in `OrderService.js`.
  - [RESOLVED] Status strings checking for `SSNAS Online` in WPF UI.

## 2. Subsidiary Codes & Corporate Registry

- **WPF:** `CategoryPresetService.cs` contains hardcoded categories for:
  - `SSH - SuamiSihat Holding`
  - `SSC - SuamiSihat Care`
  - `SSW - SuamiSihat Wellness`
  - `SSE - SuamiSihat E-Commerce`
  - `SST - SuamiSihat Technology`
- **Web:** `AdminView.svelte` and `run-tests.js` define full corporate registries:
  - Menara SuamiSihat, Kuala Lumpur addresses
  - Contact emails (e.g., `holding@suamisihat.com`)
  - Default password for new accounts and Admin "Reset to default": `SuamiSihat123` (in `server/routes/api.js`). [DECIDED 2026-10-14] Kept by explicit owner decision for the SuamiSihat edition; other tenants override it with the `DEFAULT_STAFF_PASSWORD` environment variable (documented in `.env.example`). Minimum password length is 10 characters everywhere.
  - Hardcoded email suffix `@suamisihat.com`

## 3. Brand Identity & Visual Assets

- **Web:**
  - [RESOLVED 2026-10-14] `brand-svgs.js` ("Official SuamiSihat Brand Vector Logomark") was part of the removed legacy web client.
  - `App.svelte`: Direct references to `brand/suamisihat-logo-on-dark.svg` and `brand/ss-logomark.svg`
  - Hardcoded links to the Play Store page for "SuamiSihat Creative Portal"
  - Titles containing "SUAMISIHAT CREATIVE CAMPAIGN PROMPT"
- **WPF:**
  - `CopywritingDesktopService.cs`: Generates copy explicitly mentioning "SuamiSihat"
  - `PayloadInstallerService.cs`: Generates shortcut links specifically to SuamiSihat services.
  - Hardcoded theme name "SuamiSihat Light".

## 4. Module-Specific Couplings (WPF)

- **Radio Player:** [RESOLVED] `GetSuamiSihatRadioStation()` in `RadioStreamService.cs` unconditionally force-inserts the official radio station into the stream list.
- **Waktu Solat:** [RESOLVED] Default zone is hardcoded to `WLY01` (Kuala Lumpur/Putrajaya) in `WaktuSolatPage.xaml.cs`.
- **Creative Wellbeing:** [RESOLVED] Local storage path uses literal `"SuamiSihat"` folder.
- **Update check:** [RESOLVED 2026-10-14] The GitHub repository used for update checks is read from `TenantConfig.UpdateRepository` (SuamiSihat edition: `SuamiSihat/ss_cam`) instead of a literal in the code.
- **QR Code Studio:** [RESOLVED] Default fallback URL is `https://suamisihat.com.my` and export files are prefixed with `SuamiSihat_QRCode_`.

## Next Steps

In accordance with the **[PRODUCT] Master Documentation**, this inventory fulfills the Phase 0 prerequisite. These items must be abstracted into a config-driven layer (`TenantConfig`) or moved into a dedicated SuamiSihat Edition to enable the Open-Core commercialization split.

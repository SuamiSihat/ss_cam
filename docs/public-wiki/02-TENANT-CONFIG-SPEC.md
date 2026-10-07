# Tenant Configuration Specification (`TenantConfig.json`)

The **Tenant Configuration Engine** allows creative agencies, enterprises, and franchise networks to fully rebrand CAM Studio and customize operational URLs, design tokens, and category presets without touching source code or rebuilding binaries.

---

## 1. File Location & Precedence

When CAM Studio initializes, it resolves tenant configuration in the following order:

1. **Explicit Command-Line Flag:** `--tenant-config "C:\Path\To\tenant_config.json"`
2. **Local Application Directory:** `%LocalAppData%\CAM-Studio\tenant_config.json`
3. **Application Installation Directory:** `<AppDir>\tenant_config.json`
4. **Embedded Default Fallback:** Built-in generic configuration.

---

## 2. Complete JSON Schema Reference

```json
{
  "$schema": "https://getcam.dev/schemas/v1/tenant-config.json",
  "tenantId": "agency_acme",
  "brandName": "Acme Creative Studio",
  "appTitle": "Acme Studio Workstation",
  "appFolderName": "AcmeStudio",
  
  "endpoints": {
    "portalUrl": "http://192.168.1.100:3000",
    "assetPortalUrl": "http://192.168.1.100:3000/assets",
    "companyUrl": "https://acmecreative.com",
    "supportUrl": "https://acmecreative.com/support"
  },

  "theme": {
    "brandPrimary": "#0078D4",
    "brandTint": "#0F0078D4",
    "brandNavy": "#0F172A",
    "accentColor": "#00B4D8",
    "logoPath": "assets/branding/logo.svg",
    "iconPath": "assets/branding/icon.ico"
  },

  "plugins": {
    "ProjectCreator": { "enabled": true },
    "CreativeOrders": { "enabled": true },
    "QrCodeStudio": {
      "enabled": true,
      "defaultContent": "https://acmecreative.com",
      "filenamePrefix": "Acme_QR_"
    },
    "CopywritingStudio": { "enabled": true },
    "CreativeWellbeing": { "enabled": true },
    "AudioFeedback": { "enabled": true }
  },

  "categories": [
    { "code": "BRAND", "name": "Brand Identity & Guidelines" },
    { "code": "VIDEO", "name": "4K Video & Motion Graphics" },
    { "code": "CAMPAIGN", "name": "Marketing & Social Campaigns" },
    { "code": "PRINT", "name": "Packaging & Print Collateral" }
  ]
}
```

---

## 3. Field Definitions

| Property | Type | Required | Description |
|---|---|---|---|
| `tenantId` | String | Yes | Unique alphanumeric identifier for the tenant. |
| `brandName` | String | Yes | Display name of the studio/organization. |
| `appTitle` | String | Yes | Workstation window title bar prefix. |
| `endpoints.portalUrl` | String (URL) | Yes | Base URL to the companion Web Portal on local NAS or cloud. |
| `endpoints.companyUrl` | String (URL) | No | Official website URL shown in external navigation links. |
| `theme.brandPrimary` | String (Hex) | Yes | Primary brand color token used for buttons, active items, and badges. |
| `theme.brandNavy` | String (Hex) | No | Sidebar and titlebar dark chrome background. |
| `plugins.<Name>.enabled` | Boolean | Yes | Controls whether the module appears in navigation and command palette. |
| `categories` | Array | No | Dynamic category presets loaded into Project Creator dropdowns. |

---

## 4. Deploying Custom Brand Assets

Place your custom vector SVG logomark in the same folder as `tenant_config.json`:

- `logo_light.svg` (displayed on dark sidebar)
- `logo_dark.svg` (displayed on light canvas)
- `favicon.ico` (workstation icon)

The desktop shell will automatically bind these vector assets into the header and about dialog upon launch.

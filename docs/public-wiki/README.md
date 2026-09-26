# CAM Studio Documentation & Knowledge Base

Welcome to the official technical documentation for **CAM Studio (Creative Asset Management)**.

CAM Studio is a studio-grade, privacy-first creative operations and asset management suite designed to run directly on customer-owned infrastructure (Windows Desktop Workstations, Synology NAS / Linux Docker servers, and Android companion devices).

---

## Documentation Sections

1. [**Getting Started & Installation**](01-GETTING-STARTED.md)  
   Hardware prerequisites, Windows 10/11 desktop workstation installation, and Synology NAS / Linux Docker 1-click stack deployment.

2. [**Tenant Configuration Schema (`TenantConfig.json`)**](02-TENANT-CONFIG-SPEC.md)  
   Complete JSON specification for customizing brand logos, color tokens, portal URLs, category presets, and subsidiary codes without code recompilation.

3. [**Plugin Architecture & Modularity**](03-PLUGIN-SYSTEM.md)  
   Overview of the `IAppPlugin` interface, lifecycle hooks, and how to dynamically enable or disable features across the desktop shell.

4. [**Troubleshooting & Network Diagnostics**](04-TROUBLESHOOTING.md)  
   Resolving LAN SMB file permissions, Synology Container Manager connectivity, SmartScreen validation, and performance optimization.

---

## Core Philosophy

- **100% Offline-First:** Your raw media and creative projects never touch external cloud servers. All asset transformations, cataloging, and Myers LCS diffing happen locally at line speed.
- **Unified Brand System:** Driven by Microsoft Fluent 2 design tokens, ensuring perfect visual hierarchy across light, dark, and custom brand themes.
- **Enterprise Modularity:** Enable only the workflows your studio needs via configuration-driven plugins.

<script lang="ts">
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface ColorSwatch {
    name: string;
    token: string;
    hex: string;
    rgb: string;
    hsl: string;
    usage: string;
    isDarkText?: boolean;
  }

  interface BrandGroup {
    id: string;
    title: string;
    description: string;
    colors: ColorSwatch[];
  }

  const brandGroups: BrandGroup[] = [
    {
      id: 'core',
      title: 'Canonical 60:30:10 Palette',
      description: 'Authoritative primary surfaces, typography, and accent highlights for SuamiSihat CAM and client portals.',
      colors: [
        { name: 'Porcelain (60% Light Canvas)', token: '--color-porcelain', hex: '#FCFAF6', rgb: '252, 250, 246', hsl: '40°, 40%, 98%', usage: 'Page background & light canvas', isDarkText: true },
        { name: 'Charcoal (60% Dark Canvas)', token: '--color-charcoal', hex: '#1C1C1C', rgb: '28, 28, 28', hsl: '0°, 0%, 11%', usage: 'Dark surface & dark background', isDarkText: false },
        { name: 'Prussian Blue (30% Primary)', token: '--color-prussian-blue', hex: '#022057', rgb: '2, 32, 87', hsl: '219°, 95%, 17%', usage: 'Primary brand, headers, cards, chrome', isDarkText: false },
        { name: 'White Surface (30% Surface)', token: '--color-white', hex: '#FFFFFF', rgb: '255, 255, 255', hsl: '0°, 0%, 100%', usage: 'Elevated card surface & modals', isDarkText: true },
        { name: 'Banana Yellow (10% High-Impact CTA)', token: '--color-banana', hex: '#FCE53D', rgb: '252, 229, 61', hsl: '53°, 97%, 61%', usage: 'Action buttons, status banners, calls to action', isDarkText: true },
        { name: 'Azure Tint (Interactive Highlight)', token: '--color-ss-azure', hex: '#21A1F7', rgb: '33, 161, 247', hsl: '204°, 93%, 55%', usage: 'Focus rings, active states, tags, pills', isDarkText: true }
      ]
    },
    {
      id: 'semantic',
      title: 'Clinical & Status Semantics',
      description: 'Strict status signaling used in production, deliverables review, and queue management.',
      colors: [
        { name: 'Emerald Success', token: '--color-emerald', hex: '#107C41', rgb: '16, 124, 65', hsl: '147°, 77%, 27%', usage: 'Approved, Completed, Live', isDarkText: false },
        { name: 'Amber Caution', token: '--color-amber', hex: '#D83B01', rgb: '216, 59, 1', hsl: '16°, 99%, 43%', usage: 'Revision requested, Stuck, Warning', isDarkText: false },
        { name: 'Rose Critical', token: '--color-rose', hex: '#C42B1C', rgb: '196, 43, 28', hsl: '5°, 66%, 44%', usage: 'Blocked, Offline, Severe Error', isDarkText: false },
        { name: 'Prussian Tint Light', token: '--brand-tint', hex: '#E8F1FC', rgb: '232, 241, 252', hsl: '213°, 77%, 95%', usage: 'Info badges, selected table rows', isDarkText: true }
      ]
    },
    {
      id: 'subbrands',
      title: 'Sub-Brand Accents',
      description: 'Authorized subsidiary color codes mapped from TenantConfig.json.',
      colors: [
        { name: 'SuamiSihat Clinical', token: '--brand-clinical', hex: '#022057', rgb: '2, 32, 87', hsl: '219°, 95%, 17%', usage: 'Main clinical brand & medical devices', isDarkText: false },
        { name: 'Falconia Creative Studio', token: '--brand-falconia', hex: '#E29547', rgb: '226, 149, 71', hsl: '30°, 73%, 58%', usage: 'Design studio, video media, motion', isDarkText: true },
        { name: 'Metamorphosis Academy', token: '--brand-metamorphosis', hex: '#008272', rgb: '0, 130, 114', hsl: '173°, 100%, 25%', usage: 'Training, internal education & workshops', isDarkText: false },
        { name: 'SuamiSihat Labs', token: '--brand-labs', hex: '#4F52B2', rgb: '79, 82, 178', hsl: '238°, 42%, 50%', usage: 'R&D, lab diagnostics, trial batches', isDarkText: false }
      ]
    }
  ];

  let selectedGroup = $state('core');
  let copiedHex = $state<string | null>(null);

  function copyColor(color: ColorSwatch, format: 'hex' | 'rgb' | 'token') {
    let val = color.hex;
    if (format === 'rgb') val = `rgb(${color.rgb})`;
    if (format === 'token') val = `var(${color.token})`;

    navigator.clipboard.writeText(val).then(() => {
      copiedHex = color.hex;
      appState.addToast(`Copied ${val} (${color.name}) to clipboard`, 'success', 'Copied');
      setTimeout(() => {
        if (copiedHex === color.hex) copiedHex = null;
      }, 2500);
    }).catch(() => {
      appState.addToast('Could not copy color to clipboard', 'error');
    });
  }

  const typographyScale = [
    { level: 'Display Hero', size: '32px / 2rem', weight: '800 (Extrabold)', sample: 'Empowering Men\'s Health Across Malaysia' },
    { level: 'Page Title', size: '24px / 1.5rem', weight: '700 (Bold)', sample: 'Brand Assets & Design Tokens' },
    { level: 'Section Heading', size: '18px / 1.125rem', weight: '600 (Semibold)', sample: 'Canonical 60:30:10 Visual Hierarchy' },
    { level: 'Body Regular', size: '14px / 0.875rem', weight: '400 (Regular)', sample: 'SuamiSihat Creative Asset Management desktop and cloud portal.' },
    { level: 'Caption / Meta', size: '12px / 0.75rem', weight: '500 (Medium)', sample: 'HEX · RGB · HSL · Tokens · Version 3.5.1 SSoT' }
  ];
</script>

<div class="brand-assets-page">
  <!-- Header -->
  <header class="page-header">
    <div class="header-left">
      <div class="header-icon-wrap">
        <FluentIcons name="colorPalette" size="24" color="var(--brand-primary, #022057)" />
      </div>
      <div>
        <h1 class="page-title">Brand assets & identity vault</h1>
        <p class="page-subtitle">Authoritative design tokens, multi-format color palettes, typography scale, and vector assets.</p>
      </div>
    </div>
    <div class="header-actions">
      <div class="brand-version-badge" title="Single Source of Truth">
        <FluentIcons name="checkmark" size="14" color="var(--color-emerald, #107C41)" />
        <span>Brand System v3.5.1 (SSoT)</span>
      </div>
    </div>
  </header>

  <!-- Group Tabs -->
  <div class="palette-tabs" role="tablist">
    {#each brandGroups as group}
      <button
        type="button"
        role="tab"
        aria-selected={selectedGroup === group.id}
        class="tab-btn"
        class:active={selectedGroup === group.id}
        onclick={() => (selectedGroup = group.id)}
      >
        {group.title}
      </button>
    {/each}
  </div>

  <!-- Swatch Grid -->
  {#each brandGroups as group}
    {#if selectedGroup === group.id}
      <section class="group-section">
        <p class="group-desc">{group.description}</p>
        <div class="swatches-grid">
          {#each group.colors as color}
            <FluentCard class="swatch-card">
              <div class="swatch-preview" style="background-color: {color.hex}; color: {color.isDarkText ? '#1C1C1C' : '#FFFFFF'};">
                <span class="swatch-hex-pill">{color.hex}</span>
                {#if copiedHex === color.hex}
                  <span class="copied-badge">Copied!</span>
                {/if}
              </div>
              <div class="swatch-body">
                <div class="swatch-name-row">
                  <h3 class="swatch-name">{color.name}</h3>
                </div>
                <div class="swatch-token-code"><code>var({color.token})</code></div>
                <div class="swatch-usage">{color.usage}</div>
                <div class="swatch-actions">
                  <button type="button" class="copy-pill-btn" onclick={() => copyColor(color, 'hex')} title="Copy HEX value">
                    HEX
                  </button>
                  <button type="button" class="copy-pill-btn" onclick={() => copyColor(color, 'rgb')} title="Copy RGB value">
                    RGB
                  </button>
                  <button type="button" class="copy-pill-btn" onclick={() => copyColor(color, 'token')} title="Copy CSS variable">
                    Token
                  </button>
                </div>
              </div>
            </FluentCard>
          {/each}
        </div>
      </section>
    {/if}
  {/each}

  <!-- Typography Hierarchy Section -->
  <section class="typography-section">
    <div class="section-header">
      <h2 class="section-title">Typography scale & hierarchy</h2>
      <p class="section-sub">Standard typography tokens applied across Windows Desktop, Web Portal, and Android Companion.</p>
    </div>
    <FluentCard class="type-card">
      <div class="type-table">
        <div class="type-row header">
          <span class="col-level">Hierarchy Level</span>
          <span class="col-size">Font Size</span>
          <span class="col-weight">Weight</span>
          <span class="col-sample">Sample Rendering</span>
        </div>
        {#each typographyScale as item}
          <div class="type-row">
            <span class="col-level font-semibold">{item.level}</span>
            <span class="col-size"><code>{item.size}</code></span>
            <span class="col-weight">{item.weight}</span>
            <span class="col-sample sample-text" style="font-size: {item.size.split(' ')[0]};">{item.sample}</span>
          </div>
        {/each}
      </div>
    </FluentCard>
  </section>

  <!-- Vector Logo Marks -->
  <section class="logos-section">
    <div class="section-header">
      <h2 class="section-title">Official vector brand marks</h2>
      <p class="section-sub">Scalable SVG vectors and mark variants for digital and print production.</p>
    </div>
    <div class="logos-grid">
      <FluentCard class="logo-card">
        <div class="logo-box dark-bg">
          <svg width="48" height="48" viewBox="0 0 100 100" fill="none">
            <rect width="100" height="100" rx="20" fill="#022057" />
            <path d="M30 35C30 28 36 24 45 24C55 24 60 29 60 35C60 48 30 46 30 62C30 72 38 76 50 76C62 76 70 70 70 60" stroke="#FCE53D" stroke-width="10" stroke-linecap="round" />
          </svg>
        </div>
        <div class="logo-info">
          <h4>SuamiSihat Primary Mark (Navy/Gold)</h4>
          <p>Canonical mark for dark containers, video intros, and primary cards.</p>
        </div>
      </FluentCard>

      <FluentCard class="logo-card">
        <div class="logo-box light-bg">
          <svg width="48" height="48" viewBox="0 0 100 100" fill="none">
            <rect width="100" height="100" rx="20" fill="#FCFAF6" stroke="#E2E8F0" stroke-width="2" />
            <path d="M30 35C30 28 36 24 45 24C55 24 60 29 60 35C60 48 30 46 30 62C30 72 38 76 50 76C62 76 70 70 70 60" stroke="#022057" stroke-width="10" stroke-linecap="round" />
          </svg>
        </div>
        <div class="logo-info">
          <h4>SuamiSihat Minimalist Mono (Porcelain)</h4>
          <p>Monochrome vector mark for light document headers, prints, and invoices.</p>
        </div>
      </FluentCard>
    </div>
  </section>
</div>

<style>
  .brand-assets-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 24px;
    max-width: 1320px;
    margin: 0 auto;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .header-icon-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--brand-tint, #E8F1FC);
  }

  .page-title {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .page-subtitle {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 3px 0 0 0;
  }

  .brand-version-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 20px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
  }

  .palette-tabs {
    display: flex;
    gap: 8px;
    border-bottom: 2px solid var(--border-subtle, #E2E8F0);
    padding-bottom: 2px;
  }

  .tab-btn {
    padding: 10px 18px;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: none;
    border: none;
    border-bottom: 3px solid transparent;
    cursor: pointer;
    transition: all 0.15s ease;
    border-radius: 4px 4px 0 0;
  }

  .tab-btn:hover {
    color: var(--brand-primary, #022057);
    background: rgba(2, 32, 87, 0.04);
  }

  .tab-btn.active {
    color: var(--brand-primary, #022057);
    border-bottom-color: var(--brand-primary, #022057);
  }

  .group-section {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .group-desc {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 0;
  }

  .swatches-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
  }

  :global(.swatch-card) {
    overflow: hidden;
    padding: 0 !important;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border-subtle, #E2E8F0);
    transition: transform 0.15s ease, box-shadow 0.15s ease;
  }

  :global(.swatch-card:hover) {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
  }

  .swatch-preview {
    height: 100px;
    padding: 12px;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    position: relative;
  }

  .swatch-hex-pill {
    padding: 3px 8px;
    border-radius: 6px;
    background: rgba(0, 0, 0, 0.25);
    color: #FFFFFF;
    font-family: monospace;
    font-size: 12px;
    font-weight: 700;
  }

  .copied-badge {
    padding: 3px 8px;
    border-radius: 6px;
    background: #107C41;
    color: #FFFFFF;
    font-size: 11px;
    font-weight: 700;
  }

  .swatch-body {
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    background: var(--surface-card, #FFFFFF);
  }

  .swatch-name {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .swatch-token-code code {
    font-size: 11px;
    color: var(--brand-primary, #022057);
    background: var(--brand-tint, #E8F1FC);
    padding: 2px 6px;
    border-radius: 4px;
  }

  .swatch-usage {
    font-size: 12px;
    color: var(--text-secondary, #64748B);
    line-height: 1.4;
    min-height: 34px;
  }

  .swatch-actions {
    display: flex;
    gap: 6px;
    margin-top: 6px;
    padding-top: 8px;
    border-top: 1px solid var(--border-subtle, #E2E8F0);
  }

  .copy-pill-btn {
    flex: 1;
    padding: 6px 0;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary, #64748B);
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .copy-pill-btn:hover {
    color: var(--brand-primary, #022057);
    border-color: var(--brand-primary, #022057);
    background: var(--brand-tint, #E8F1FC);
  }

  /* Typography */
  .typography-section, .logos-section {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .section-title {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .section-sub {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 2px 0 0 0;
  }

  .type-table {
    display: flex;
    flex-direction: column;
  }

  .type-row {
    display: grid;
    grid-template-columns: 160px 140px 140px 1fr;
    gap: 16px;
    padding: 12px 16px;
    align-items: center;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .type-row.header {
    background: var(--surface-bg, #F8FAFC);
    font-size: 12px;
    font-weight: 700;
    color: var(--text-secondary, #64748B);
    text-transform: uppercase;
  }

  .col-sample {
    color: var(--text-primary, #1C1C1C);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Logos */
  .logos-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
    gap: 16px;
  }

  :global(.logo-card) {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px !important;
    border: 1px solid var(--border-subtle, #E2E8F0);
  }

  .logo-box {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 68px;
    height: 68px;
    border-radius: 12px;
    flex-shrink: 0;
  }

  .logo-box.dark-bg {
    background: #022057;
  }

  .logo-box.light-bg {
    background: #FCFAF6;
    border: 1px solid #E2E8F0;
  }

  .logo-info h4 {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0 0 4px 0;
  }

  .logo-info p {
    font-size: 12px;
    color: var(--text-secondary, #64748B);
    margin: 0;
  }

  @media (max-width: 768px) {
    .type-row {
      grid-template-columns: 1fr;
      gap: 6px;
    }
    .type-row.header {
      display: none;
    }
  }
</style>

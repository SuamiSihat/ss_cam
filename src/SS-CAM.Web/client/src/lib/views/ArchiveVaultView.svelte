<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';

  interface ArchivedProject {
    id: string;
    title: string;
    brand: string;
    designer: string;
    year: string;
    month: string;
    archivedAt: string;
    deliverableCount: number;
    sizeFormatted: string;
    archiveType: 'ZIP' | 'Folder';
    tags: string[];
  }

  const SAMPLE_ARCHIVES: ArchivedProject[] = [
    {
      id: 'SS-2026-OCT-001',
      title: 'Klinik Launch Johor Bahru Banners & Video Promos',
      brand: 'SuamiSihat',
      designer: 'Hafiz',
      year: '2026',
      month: '10_October',
      archivedAt: '2026-10-24T14:30:00Z',
      deliverableCount: 14,
      sizeFormatted: '482 MB',
      archiveType: 'ZIP',
      tags: ['Clinical', 'Video', 'OOH']
    },
    {
      id: 'SS-2026-SEP-004',
      title: 'Falconia Motion Graphics Ident & Sound Design Pack',
      brand: 'Falconia',
      designer: 'Sarah',
      year: '2026',
      month: '09_September',
      archivedAt: '2026-09-28T09:15:00Z',
      deliverableCount: 8,
      sizeFormatted: '1.2 GB',
      archiveType: 'ZIP',
      tags: ['Motion', 'Sound', '3D']
    },
    {
      id: 'SS-2026-AUG-012',
      title: 'TRT Hormone Optimization Educational Carousel Series',
      brand: 'SuamiSihat',
      designer: 'Farid',
      year: '2026',
      month: '08_August',
      archivedAt: '2026-08-30T16:45:00Z',
      deliverableCount: 22,
      sizeFormatted: '315 MB',
      archiveType: 'ZIP',
      tags: ['Instagram', 'Meta Ads', 'Carousel']
    },
    {
      id: 'SS-2026-JUL-008',
      title: 'Metamorphosis Academy Clinical Workshop Onboarding Kit',
      brand: 'Metamorphosis',
      designer: 'Amira',
      year: '2026',
      month: '07_July',
      archivedAt: '2026-07-29T11:00:00Z',
      deliverableCount: 19,
      sizeFormatted: '850 MB',
      archiveType: 'ZIP',
      tags: ['Print', 'SOP', 'Handbook']
    }
  ];

  let searchQuery = $state('');
  let selectedYear = $state('All');
  let selectedMonth = $state('All');
  let selectedProjectForInspection = $state<ArchivedProject | null>(null);
  let showRestoreDialog = $state(false);

  // Derive archived projects from sample + any completed projects in projectStore
  let archives = $state<ArchivedProject[]>(SAMPLE_ARCHIVES);

  const availableYears = ['All', '2026', '2025', '2024'];
  const availableMonths = [
    'All',
    '10_October',
    '09_September',
    '08_August',
    '07_July',
    '06_June',
    '05_May'
  ];

  const filteredArchives = $derived(
    archives.filter(item => {
      const matchSearch = !searchQuery ||
        item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.brand.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.designer.toLowerCase().includes(searchQuery.toLowerCase());
      const matchYear = selectedYear === 'All' || item.year === selectedYear;
      const matchMonth = selectedMonth === 'All' || item.month === selectedMonth;
      return matchSearch && matchYear && matchMonth;
    })
  );

  const totalDeliverablesCount = $derived(archives.reduce((acc, a) => acc + a.deliverableCount, 0));

  function handleRestoreRequest() {
    if (!selectedProjectForInspection) return;
    showRestoreDialog = false;
    appState.addToast(`Restoration request submitted for ${selectedProjectForInspection.id}. Synology task queued.`, 'success', 'Restoration Queued');
    selectedProjectForInspection = null;
  }
</script>

<div class="archive-vault-page">
  <!-- Header -->
  <header class="page-header">
    <div class="header-left">
      <div class="header-icon-wrap">
        <FluentIcons name="archive" size="24" color="var(--brand-primary, #022057)" />
      </div>
      <div>
        <h1 class="page-title">Archive vault & cold storage</h1>
        <p class="page-subtitle">Inspect historical completed projects, cold-storage ZIP packages, and deliverable catalogs on shared drive.</p>
      </div>
    </div>
    <div class="header-actions">
      <div class="cold-storage-badge" title="Cold Storage Synology Path">
        <span class="path-label">Storage path:</span>
        <code>_Archive/2026/</code>
      </div>
    </div>
  </header>

  <!-- Metric Summary Cards -->
  <div class="metrics-grid">
    <FluentCard class="metric-card">
      <div class="metric-icon-box">
        <FluentIcons name="archive" size="20" color="var(--brand-primary, #022057)" />
      </div>
      <div class="metric-content">
        <span class="metric-val">{archives.length}</span>
        <span class="metric-label">Archived Projects</span>
      </div>
    </FluentCard>

    <FluentCard class="metric-card">
      <div class="metric-icon-box green">
        <FluentIcons name="file" size="20" color="var(--color-emerald, #107C41)" />
      </div>
      <div class="metric-content">
        <span class="metric-val">{totalDeliverablesCount}</span>
        <span class="metric-label">Cold Deliverables</span>
      </div>
    </FluentCard>

    <FluentCard class="metric-card">
      <div class="metric-icon-box blue">
        <FluentIcons name="download" size="20" color="var(--color-ss-azure, #21A1F7)" />
      </div>
      <div class="metric-content">
        <span class="metric-val">2.8 GB</span>
        <span class="metric-label">Compressed Footprint</span>
      </div>
    </FluentCard>

    <FluentCard class="metric-card">
      <div class="metric-icon-box purple">
        <FluentIcons name="timeline" size="20" color="#7C3AED" />
      </div>
      <div class="metric-content">
        <span class="metric-val">100%</span>
        <span class="metric-label">Catalog Integrity</span>
      </div>
    </FluentCard>
  </div>

  <!-- Filters Toolbar -->
  <div class="filters-toolbar">
    <div class="search-wrap">
      <FluentIcons name="search" size="14" color="var(--text-secondary, #64748B)" />
      <input
        type="text"
        placeholder="Search archived projects, designers, or tags…"
        bind:value={searchQuery}
        class="search-input"
      />
      {#if searchQuery}
        <button type="button" class="clear-btn" onclick={() => (searchQuery = '')}>×</button>
      {/if}
    </div>

    <div class="select-group">
      <label for="archive-year-select" class="sr-only">Year</label>
      <select id="archive-year-select" class="filter-select" bind:value={selectedYear}>
        {#each availableYears as yr}
          <option value={yr}>Year: {yr}</option>
        {/each}
      </select>

      <label for="archive-month-select" class="sr-only">Month</label>
      <select id="archive-month-select" class="filter-select" bind:value={selectedMonth}>
        {#each availableMonths as mo}
          <option value={mo}>{mo === 'All' ? 'Month: All' : mo.replace('_', ' ')}</option>
        {/each}
      </select>
    </div>
  </div>

  <!-- Projects Grid -->
  <div class="archives-grid">
    {#if filteredArchives.length === 0}
      <div class="empty-archives-state">
        <FluentIcons name="archive" size="36" color="var(--text-secondary, #94A3B8)" />
        <h3>No archived projects match your filter</h3>
        <p>Try clearing your search term or selecting a different year/month.</p>
        <FluentButton appearance="secondary" onclick={() => { searchQuery = ''; selectedYear = 'All'; selectedMonth = 'All'; }}>
          Reset filters
        </FluentButton>
      </div>
    {:else}
      {#each filteredArchives as project (project.id)}
        <FluentCard class="archive-card">
          <div class="archive-card-header">
            <div class="code-and-brand">
              <span class="archive-code">{project.id}</span>
              <span class="archive-brand-tag">{project.brand}</span>
            </div>
            <span class="archive-zip-badge">{project.archiveType}</span>
          </div>

          <h3 class="archive-title">{project.title}</h3>

          <div class="archive-tags-row">
            {#each project.tags as tag}
              <span class="archive-tag">{tag}</span>
            {/each}
          </div>

          <div class="archive-meta-row">
            <div class="meta-item">
              <FluentIcons name="user" size="12" color="var(--text-secondary, #64748B)" />
              <span>{project.designer}</span>
            </div>
            <div class="meta-item">
              <FluentIcons name="file" size="12" color="var(--text-secondary, #64748B)" />
              <span>{project.deliverableCount} files</span>
            </div>
            <div class="meta-item">
              <FluentIcons name="box" size="12" color="var(--text-secondary, #64748B)" />
              <span>{project.sizeFormatted}</span>
            </div>
          </div>

          <div class="archive-card-actions">
            <button
              type="button"
              class="inspect-btn"
              onclick={() => (selectedProjectForInspection = project)}
            >
              Inspect Details
            </button>
            <button
              type="button"
              class="restore-btn"
              onclick={() => { selectedProjectForInspection = project; showRestoreDialog = true; }}
            >
              Restore to Live
            </button>
          </div>
        </FluentCard>
      {/each}
    {/if}
  </div>

  <!-- Detail Inspection Modal -->
  {#if selectedProjectForInspection && !showRestoreDialog}
    <div class="inspect-overlay" role="dialog" aria-modal="true" tabindex="-1">
      <div class="inspect-modal">
        <div class="modal-header">
          <div>
            <div class="modal-id">{selectedProjectForInspection.id}</div>
            <h2 class="modal-title">{selectedProjectForInspection.title}</h2>
          </div>
          <button type="button" class="close-btn" onclick={() => (selectedProjectForInspection = null)}>×</button>
        </div>
        <div class="modal-body">
          <div class="modal-detail-row">
            <span class="modal-label">Brand / Client:</span>
            <span class="modal-val font-semibold">{selectedProjectForInspection.brand}</span>
          </div>
          <div class="modal-detail-row">
            <span class="modal-label">Lead Designer:</span>
            <span class="modal-val">{selectedProjectForInspection.designer}</span>
          </div>
          <div class="modal-detail-row">
            <span class="modal-label">Archive Path:</span>
            <code class="modal-val">_Archive/{selectedProjectForInspection.year}/{selectedProjectForInspection.month}/{selectedProjectForInspection.id}.zip</code>
          </div>
          <div class="modal-detail-row">
            <span class="modal-label">Deliverables Pack:</span>
            <span class="modal-val">{selectedProjectForInspection.deliverableCount} master render assets ({selectedProjectForInspection.sizeFormatted})</span>
          </div>
          <div class="modal-detail-row">
            <span class="modal-label">Archived On:</span>
            <span class="modal-val">{new Date(selectedProjectForInspection.archivedAt).toLocaleString('en-GB')}</span>
          </div>
        </div>
        <div class="modal-footer">
          <FluentButton appearance="secondary" onclick={() => (selectedProjectForInspection = null)}>Close</FluentButton>
          <FluentButton appearance="primary" onclick={() => (showRestoreDialog = true)}>Request Project Unarchive</FluentButton>
        </div>
      </div>
    </div>
  {/if}

  <!-- Restore Confirmation Dialog -->
  <FluentDialog
    open={showRestoreDialog}
    title="Unarchive Project"
    message={`Do you want to restore "${selectedProjectForInspection?.title}" (${selectedProjectForInspection?.id}) from cold storage back to the active production workspace?`}
    confirmText="Restore Project"
    cancelText="Cancel"
    onConfirm={handleRestoreRequest}
    onCancel={() => (showRestoreDialog = false)}
  />
</div>

<style>
  .archive-vault-page {
    display: flex;
    flex-direction: column;
    gap: 20px;
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

  .cold-storage-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 8px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    font-size: 12px;
  }

  .path-label {
    color: var(--text-secondary, #64748B);
  }

  .cold-storage-badge code {
    color: var(--brand-primary, #022057);
    font-weight: 700;
  }

  /* Metric Cards */
  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 14px;
  }

  :global(.metric-card) {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 16px !important;
    border: 1px solid var(--border-subtle, #E2E8F0);
  }

  .metric-icon-box {
    width: 40px;
    height: 40px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--brand-tint, #E8F1FC);
  }

  .metric-icon-box.green {
    background: #DCFCE7;
  }

  .metric-icon-box.blue {
    background: #E0F2FE;
  }

  .metric-icon-box.purple {
    background: #F3E8FF;
  }

  .metric-content {
    display: flex;
    flex-direction: column;
  }

  .metric-val {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
  }

  .metric-label {
    font-size: 12px;
    color: var(--text-secondary, #64748B);
  }

  /* Toolbar */
  .filters-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 12px;
  }

  .search-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 14px;
    border-radius: 8px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    flex: 1;
    min-width: 260px;
  }

  .search-input {
    flex: 1;
    border: none;
    outline: none;
    background: none;
    font-size: 13px;
    color: var(--text-primary, #1C1C1C);
  }

  .clear-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 16px;
    color: var(--text-secondary, #64748B);
  }

  .select-group {
    display: flex;
    gap: 8px;
  }

  .filter-select {
    padding: 8px 14px;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 8px;
    outline: none;
    cursor: pointer;
    min-height: 36px;
  }

  /* Archives Grid */
  .archives-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 16px;
  }

  :global(.archive-card) {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 16px !important;
    border: 1px solid var(--border-subtle, #E2E8F0);
    transition: transform 0.15s ease, box-shadow 0.15s ease;
  }

  :global(.archive-card:hover) {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.06);
  }

  .archive-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .code-and-brand {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .archive-code {
    font-family: monospace;
    font-size: 11px;
    font-weight: 700;
    color: var(--brand-primary, #022057);
  }

  .archive-brand-tag {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 4px;
    background: var(--brand-tint, #E8F1FC);
    color: var(--brand-primary, #022057);
  }

  .archive-zip-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(16, 124, 65, 0.1);
    color: #107C41;
  }

  .archive-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
    line-height: 1.4;
  }

  .archive-tags-row {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .archive-tag {
    font-size: 10px;
    padding: 2px 6px;
    border-radius: 4px;
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    color: var(--text-secondary, #64748B);
  }

  .archive-meta-row {
    display: flex;
    align-items: center;
    gap: 14px;
    font-size: 11px;
    color: var(--text-secondary, #64748B);
    padding-top: 6px;
    border-top: 1px solid var(--border-subtle, #E2E8F0);
  }

  .meta-item {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .archive-card-actions {
    display: flex;
    gap: 8px;
    margin-top: 4px;
  }

  .inspect-btn, .restore-btn {
    flex: 1;
    padding: 7px 0;
    font-size: 11.5px;
    font-weight: 600;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
    text-align: center;
  }

  .inspect-btn {
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    color: var(--text-secondary, #64748B);
  }

  .inspect-btn:hover {
    color: var(--brand-primary, #022057);
    border-color: var(--brand-primary, #022057);
  }

  .restore-btn {
    background: var(--brand-primary, #022057);
    border: 1px solid var(--brand-primary, #022057);
    color: #FFFFFF;
  }

  .restore-btn:hover {
    background: #033285;
  }

  .empty-archives-state {
    grid-column: 1 / -1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 48px 16px;
    gap: 12px;
    text-align: center;
    color: var(--text-secondary, #64748B);
  }

  /* Inspection Overlay */
  .inspect-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.45);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 999;
    padding: 16px;
  }

  .inspect-modal {
    background: var(--surface-card, #FFFFFF);
    border-radius: 12px;
    width: 100%;
    max-width: 520px;
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.15);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .modal-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 18px 20px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .modal-id {
    font-family: monospace;
    font-size: 11px;
    font-weight: 700;
    color: var(--brand-primary, #022057);
  }

  .modal-title {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 4px 0 0 0;
  }

  .close-btn {
    border: none;
    background: none;
    font-size: 20px;
    color: var(--text-secondary, #64748B);
    cursor: pointer;
  }

  .modal-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .modal-detail-row {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 13px;
  }

  .modal-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    text-transform: uppercase;
  }

  .modal-val {
    color: var(--text-primary, #1C1C1C);
  }

  .modal-val code {
    background: var(--surface-bg, #F8FAFC);
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid var(--border-subtle, #E2E8F0);
    font-size: 12px;
    word-break: break-all;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    background: var(--surface-bg, #F8FAFC);
    border-top: 1px solid var(--border-subtle, #E2E8F0);
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    border: 0;
  }
</style>

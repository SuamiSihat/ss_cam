<script lang="ts">
  import { projectStore } from '$lib/stores/projectStore.svelte';

  const brands = ['all', 'SS', 'SSH', 'SSC', 'SSW', 'SSE', 'SST'];
  const statuses = [
    { id: 'all', label: 'All Statuses' },
    { id: 'review', label: 'Review Queue' },
    { id: 'in-progress', label: 'In Progress' },
    { id: 'revision', label: 'Revision Required' },
    { id: 'approved', label: 'Approved & Done' },
    { id: 'backlog', label: 'Backlog' },
    { id: 'on-hold', label: 'On Hold' }
  ];

  const sortOptions: { id: 'date' | 'jobId' | 'title' | 'priority'; icon: string; label: string }[] = [
    { id: 'date', icon: '📅', label: 'Sort by Date' },
    { id: 'jobId', icon: '#️⃣', label: 'Sort by Job ID' },
    { id: 'title', icon: '🔤', label: 'Sort by Name' },
    { id: 'priority', icon: '🔥', label: 'Sort by Priority' }
  ];

  let searchQuery = $state(projectStore.activeFilters.query || '');
  let debounceTimeout: any = null;

  function handleSearchInput(e: Event) {
    const val = (e.target as HTMLInputElement).value;
    searchQuery = val;
    if (debounceTimeout) clearTimeout(debounceTimeout);
    debounceTimeout = setTimeout(() => {
      projectStore.setFilter('query', val);
    }, 120);
  }

  function handleClearSearch() {
    searchQuery = '';
    if (debounceTimeout) clearTimeout(debounceTimeout);
    projectStore.setFilter('query', '');
  }

  const hasActiveFilters = $derived.by(() => {
    const f = projectStore.activeFilters;
    return f.status !== 'all' || f.brand !== 'all' || f.designer !== 'all' || f.mediaType !== 'all' || f.query.trim() !== '';
  });
</script>

<div class="filter-bar">
  <!-- Search input -->
  <div class="search-box">
    <svg width="14" height="14" viewBox="0 0 24 24" fill="var(--text-tertiary)"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
    <input
      type="text"
      placeholder="Search by ID, title, designer or tags..."
      value={searchQuery}
      oninput={handleSearchInput}
    />
    {#if searchQuery}
      <button class="clear-search-btn" onclick={handleClearSearch}>✕</button>
    {/if}
  </div>

  <!-- Filter Dropdowns Row -->
  <div class="filter-dropdowns">
    <!-- Status -->
    <select
      class="filter-select"
      value={projectStore.activeFilters.status}
      onchange={(e) => projectStore.setFilter('status', (e.target as HTMLSelectElement).value)}
      aria-label="Filter by status"
    >
      {#each statuses as s}
        <option value={s.id}>{s.label}{s.id === 'review' && projectStore.pendingReviewCount > 0 ? ` (${projectStore.pendingReviewCount})` : ''}</option>
      {/each}
    </select>

    <!-- Designer -->
    <select
      class="filter-select"
      value={projectStore.activeFilters.designer}
      onchange={(e) => projectStore.setFilter('designer', (e.target as HTMLSelectElement).value)}
      aria-label="Filter by designer"
    >
      <option value="all">All Designers</option>
      {#each projectStore.uniqueDesigners as d}
        <option value={d}>{d}</option>
      {/each}
    </select>

    <!-- Media Type -->
    <select
      class="filter-select"
      value={projectStore.activeFilters.mediaType}
      onchange={(e) => projectStore.setFilter('mediaType', (e.target as HTMLSelectElement).value)}
      aria-label="Filter by media type"
    >
      <option value="all">All Media Types</option>
      {#each projectStore.uniqueMediaTypes as mt}
        <option value={mt}>{mt}</option>
      {/each}
    </select>

    <!-- Brand -->
    <select
      class="filter-select"
      value={projectStore.activeFilters.brand}
      onchange={(e) => projectStore.setFilter('brand', (e.target as HTMLSelectElement).value)}
      aria-label="Filter by brand"
    >
      {#each brands as b}
        <option value={b}>{b === 'all' ? 'All Brands' : b}</option>
      {/each}
    </select>
  </div>

  <!-- Sort Buttons (icon-only) + Reset -->
  <div class="sort-actions">
    {#each sortOptions as opt}
      <button
        type="button"
        class="sort-icon-btn"
        class:active={projectStore.sortBy === opt.id}
        onclick={() => projectStore.setSortBy(opt.id)}
        title={`${opt.label}${projectStore.sortBy === opt.id ? (projectStore.sortDir === 'asc' ? ' ↑' : ' ↓') : ''}`}
        aria-label={opt.label}
      >
        <span class="sort-emoji">{opt.icon}</span>
        {#if projectStore.sortBy === opt.id}
          <span class="sort-dir-arrow">{projectStore.sortDir === 'asc' ? '↑' : '↓'}</span>
        {/if}
      </button>
    {/each}

    {#if hasActiveFilters}
      <button type="button" class="reset-btn" onclick={() => { projectStore.resetFilters(); searchQuery = ''; }} title="Reset all filters">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17.65 6.35A7.958 7.958 0 0012 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0112 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>
      </button>
    {/if}
  </div>
</div>

<style>
  .filter-bar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
    margin-bottom: 20px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg);
    padding: 10px 14px;
    box-shadow: var(--shadow-sm);
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md);
    padding: 6px 12px;
    flex: 1;
    min-width: 200px;
  }

  .search-box input {
    border: none;
    background: transparent;
    font-size: 13px;
    color: var(--text-primary);
    width: 100%;
    outline: none;
  }

  .clear-search-btn {
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    font-size: 11px;
  }

  .filter-dropdowns {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .filter-select {
    height: 34px;
    min-width: 130px;
    padding: 0 28px 0 10px;
    font-family: inherit;
    font-size: 12.5px;
    font-weight: 600;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-primary);
    outline: none;
    cursor: pointer;
    appearance: none;
    -webkit-appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1l4 4 4-4' stroke='%23888' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
    transition: border-color 0.15s;
  }

  .filter-select:focus {
    border-color: var(--brand-accent);
  }

  .sort-actions {
    display: flex;
    align-items: center;
    gap: 4px;
    margin-left: auto;
  }

  .sort-icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 1px;
    width: 32px;
    height: 32px;
    border: 1px solid transparent;
    border-radius: 6px;
    background: transparent;
    cursor: pointer;
    transition: all 0.14s;
    position: relative;
    font-size: 14px;
  }

  .sort-icon-btn:hover {
    background: var(--surface-card-subtle);
    border-color: var(--surface-card-border);
  }

  .sort-icon-btn.active {
    background: var(--brand-accent-subtle, rgba(0, 120, 212, 0.12));
    border-color: var(--brand-accent);
  }

  .sort-emoji {
    font-size: 13px;
    line-height: 1;
  }

  .sort-dir-arrow {
    position: absolute;
    bottom: 1px;
    right: 2px;
    font-size: 8px;
    font-weight: 900;
    color: var(--brand-accent);
    line-height: 1;
  }

  .reset-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    background: transparent;
    cursor: pointer;
    color: var(--text-secondary);
    transition: all 0.14s;
  }

  .reset-btn:hover {
    background: rgba(239, 68, 68, 0.12);
    border-color: #EF4444;
    color: #EF4444;
  }
</style>

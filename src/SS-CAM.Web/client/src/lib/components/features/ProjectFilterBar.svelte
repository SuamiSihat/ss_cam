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

  const sortOptions: { id: 'date' | 'jobId' | 'title' | 'priority'; label: string; tooltip: string }[] = [
    { id: 'date', label: 'Date', tooltip: 'Date Modified' },
    { id: 'jobId', label: 'ID', tooltip: 'Job ID' },
    { id: 'title', label: 'Name', tooltip: 'Alphabetical Name' },
    { id: 'priority', label: 'Priority', tooltip: 'Campaign Priority' }
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
    <svg class="search-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="11" cy="11" r="8"/>
      <line x1="21" y1="21" x2="16.65" y2="16.65"/>
    </svg>
    <input
      type="text"
      placeholder="Search by ID, title, designer or tags..."
      value={searchQuery}
      oninput={handleSearchInput}
    />
    {#if searchQuery}
      <button type="button" class="clear-search-btn" onclick={handleClearSearch} title="Clear search">✕</button>
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

  <!-- Minimalist Fluent 2 Sort Segmented Control + Clear Filters -->
  <div class="sort-actions">
    <div class="sort-segmented" role="group" aria-label="Sort projects">
      {#each sortOptions as opt}
        <button
          type="button"
          class="sort-pill-btn"
          class:active={projectStore.sortBy === opt.id}
          onclick={() => projectStore.setSortBy(opt.id)}
          title={`Sort by ${opt.tooltip}${projectStore.sortBy === opt.id ? (projectStore.sortDir === 'asc' ? ' (Ascending)' : ' (Descending)') : ''}`}
          aria-label={`Sort by ${opt.tooltip}`}
        >
          {#if opt.id === 'date'}
            <!-- Calendar Icon -->
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
            </svg>
          {:else if opt.id === 'jobId'}
            <!-- Number / Hash Icon -->
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="4" y1="9" x2="20" y2="9"/>
              <line x1="4" y1="15" x2="20" y2="15"/>
              <line x1="10" y1="3" x2="8" y2="21"/>
              <line x1="16" y1="3" x2="14" y2="21"/>
            </svg>
          {:else if opt.id === 'title'}
            <!-- Alphabetical Sort Icon -->
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 6h7M3 12h5M3 18h3"/>
              <path d="M15 15l3 3 3-3"/>
              <path d="M18 6v12"/>
            </svg>
          {:else if opt.id === 'priority'}
            <!-- Priority Flame Icon -->
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>
            </svg>
          {/if}

          {#if projectStore.sortBy === opt.id}
            <svg class="sort-arrow-icon" class:asc={projectStore.sortDir === 'asc'} width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="6 9 12 15 18 9"/>
            </svg>
          {/if}
        </button>
      {/each}
    </div>

    {#if hasActiveFilters}
      <button
        type="button"
        class="reset-btn"
        onclick={() => { projectStore.resetFilters(); searchQuery = ''; }}
        title="Reset all active filters and search"
        aria-label="Reset all filters"
      >
        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="18" y1="6" x2="6" y2="18"/>
          <line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
        <span>Clear</span>
      </button>
    {/if}
  </div>
</div>

<style>
  .filter-bar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
    margin-bottom: 18px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg, 10px);
    padding: 8px 12px;
    box-shadow: var(--shadow-sm);
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 6px);
    padding: 0 10px;
    height: 34px;
    flex: 1 1 170px;
    min-width: 150px;
    max-width: 280px;
    transition: border-color 0.15s ease;
  }
  .search-box:focus-within {
    border-color: var(--brand-accent, #0078D4);
  }
  .search-icon {
    color: var(--text-tertiary);
    flex-shrink: 0;
  }
  .search-box input {
    border: none;
    background: transparent;
    font-size: 12.5px;
    color: var(--text-primary);
    width: 100%;
    outline: none;
    font-family: inherit;
  }
  .search-box input::placeholder {
    color: var(--text-tertiary);
  }
  .clear-search-btn {
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    font-size: 11px;
    padding: 2px 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .clear-search-btn:hover {
    color: var(--text-primary);
    background: rgba(0,0,0,0.06);
  }

  .filter-dropdowns {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
  }

  .filter-select {
    height: 34px;
    min-width: 105px;
    padding: 0 24px 0 9px;
    font-family: inherit;
    font-size: 12px;
    font-weight: 500;
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
    transition: border-color 0.15s, background-color 0.15s;
  }
  .filter-select:hover {
    border-color: var(--text-tertiary);
  }
  .filter-select:focus {
    border-color: var(--brand-accent, #0078D4);
  }

  .sort-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-left: auto;
  }

  /* ─── Fluent 2 Minimalist Segmented Sort Control ─── */
  .sort-segmented {
    display: inline-flex;
    align-items: center;
    background: var(--bg-app, #F1F5F9);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
    height: 34px;
    box-sizing: border-box;
  }

  .sort-pill-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 3px;
    height: 28px;
    padding: 0 8px;
    border: 1px solid transparent;
    border-radius: 4px;
    background: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.12s ease;
    font-family: inherit;
    font-size: 11px;
    font-weight: 500;
  }
  .sort-pill-btn:hover {
    color: var(--text-primary);
    background: rgba(0, 0, 0, 0.04);
  }
  .sort-pill-btn.active {
    background: var(--surface-card, #FFFFFF);
    color: var(--brand-primary, #0078D4);
    border-color: var(--surface-card-border, #E2E8F0);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
    font-weight: 600;
  }
  .sort-pill-btn svg {
    flex-shrink: 0;
  }

  .sort-arrow-icon {
    margin-left: 1px;
    transition: transform 0.18s cubic-bezier(0.16, 1, 0.3, 1);
    opacity: 0.85;
  }
  .sort-arrow-icon.asc {
    transform: rotate(180deg);
  }

  /* ─── Reset Filter Button ─── */
  .reset-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    height: 34px;
    padding: 0 10px;
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    background: var(--surface-card-subtle);
    cursor: pointer;
    color: var(--text-secondary);
    font-size: 11.5px;
    font-weight: 500;
    transition: all 0.14s ease;
    font-family: inherit;
  }
  .reset-btn:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: rgba(239, 68, 68, 0.4);
    color: #EF4444;
  }
</style>

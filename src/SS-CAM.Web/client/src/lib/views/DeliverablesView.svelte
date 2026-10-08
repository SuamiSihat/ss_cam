<script lang="ts">
  import { onMount } from 'svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { DeliverableItem } from '$lib/types';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import DeliverableLightbox from '$lib/components/features/DeliverableLightbox.svelte';
  import VaultIngesterModal from '$lib/components/features/VaultIngesterModal.svelte';
  import BatchResizerModal from '$lib/components/features/BatchResizerModal.svelte';
  import ShareLinkModal from '$lib/components/features/ShareLinkModal.svelte';
  import PreflightValidatorModal from '$lib/components/features/PreflightValidatorModal.svelte';

  let selectedDeliverable = $state<DeliverableItem | null>(null);
  let lightboxOpen = $state<boolean>(false);
  let showIngesterModal = $state<boolean>(false);
  let ingestTargetProject = $state<any>(null);

  // Modals for Resizer, Share Links, & Preflight
  let showResizerModal = $state<boolean>(false);
  let resizerTargetDeliverable = $state<DeliverableItem | null>(null);
  let showShareModal = $state<boolean>(false);
  let shareTargetProject = $state<any>(null);
  let showPreflightModal = $state<boolean>(false);
  let preflightTargetDeliverable = $state<DeliverableItem | null>(null);

  // DAM Filters & View Mode
  let filterStatus = $state<string>('all');
  let searchQuery = $state<string>('');
  let rawSearchInput = $state<string>('');
  let searchDebounceTimer: any = null;
  let searchInputRef = $state<HTMLInputElement | null>(null);
  let filterBrand = $state<string>('all');
  let filterMediaClass = $state<string>('all');
  let filterAspectRatio = $state<string>('all');
  let viewMode = $state<'grid' | 'table'>('grid');
  let groupByProject = $state<boolean>(true);
  let collapsedGroups = $state<Record<string, boolean>>({});

  function toggleGroup(projectId: string) {
    collapsedGroups[projectId] = !collapsedGroups[projectId];
  }

  function handleSearchChange(e: Event) {
    const val = (e.target as HTMLInputElement).value;
    rawSearchInput = val;
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(() => {
      searchQuery = val;
    }, 120);
  }

  function handleClearSearch() {
    rawSearchInput = '';
    searchQuery = '';
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  }

  function resetAllFilters() {
    filterStatus = 'all';
    searchQuery = '';
    rawSearchInput = '';
    filterBrand = 'all';
    filterMediaClass = 'all';
    filterAspectRatio = 'all';
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  }

  const hasActiveFilters = $derived(
    filterStatus !== 'all' ||
    searchQuery.trim().length > 0 ||
    filterBrand !== 'all' ||
    filterMediaClass !== 'all' ||
    filterAspectRatio !== 'all'
  );

  function handleGlobalKeydown(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      const activeTag = (document.activeElement as HTMLElement)?.tagName;
      if (activeTag !== 'INPUT' && activeTag !== 'TEXTAREA') {
        e.preventDefault();
        searchInputRef?.focus();
      }
    }
  }

  onMount(() => {
    projectStore.loadDeliverables();
    window.addEventListener('keydown', handleGlobalKeydown);
    return () => {
      window.removeEventListener('keydown', handleGlobalKeydown);
    };
  });

  function openLightbox(d: DeliverableItem) {
    selectedDeliverable = d;
    lightboxOpen = true;
  }

  function openResizer(d: DeliverableItem) {
    resizerTargetDeliverable = d;
    showResizerModal = true;
  }

  function openShare(d: DeliverableItem) {
    const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
    const project = projectStore.projects.find(p => p.id === projId || p.jobId === projId) || {
      id: projId,
      title: d.project?.title || d.projectTitle || 'Creative Deliverables'
    };
    shareTargetProject = project;
    showShareModal = true;
  }

  function openPreflight(d: DeliverableItem) {
    preflightTargetDeliverable = d;
    showPreflightModal = true;
  }

  const filteredDeliverables = $derived(
    projectStore.deliverables.filter(d => {
      const status = d.status || 'pending';
      const brand = d.project?.brand || d.projectBrand || 'SS';
      const filename = d.filename || '';
      const projTitle = d.project?.title || d.projectTitle || '';
      const jobId = d.project?.jobId || d.projectJobId || '';
      const designer = d.project?.designer || d.projectDesigner || '';
      const mediaClass = d.mediaClass || (d.isVideo ? 'video_master' : d.isPdf ? 'print_pdf' : 'raster_image');
      const ratio = d.aspectRatioEstimate || 'standard';

      if (filterStatus !== 'all' && status !== filterStatus) return false;
      if (filterBrand !== 'all' && brand !== filterBrand) return false;
      if (filterMediaClass !== 'all' && mediaClass !== filterMediaClass) return false;
      if (filterAspectRatio !== 'all' && ratio !== filterAspectRatio) return false;

      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const matches = filename.toLowerCase().includes(q) ||
                        projTitle.toLowerCase().includes(q) ||
                        jobId.toLowerCase().includes(q) ||
                        designer.toLowerCase().includes(q);
        if (!matches) return false;
      }

      return true;
    })
  );

  interface ProjectDeliverableGroup {
    projectId: string;
    jobId: string;
    brand: string;
    title: string;
    designer: string;
    status: string;
    folderName?: string;
    deliverables: DeliverableItem[];
    totalSizeBytes: number;
  }

  const groupedDeliverables = $derived.by<ProjectDeliverableGroup[]>(() => {
    const map = new Map<string, ProjectDeliverableGroup>();
    for (const d of filteredDeliverables) {
      const pId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId || 'unassigned';
      if (!map.has(pId)) {
        const proj = projectStore.projects.find(p => p.id === pId || p.jobId === pId);
        map.set(pId, {
          projectId: pId,
          jobId: proj?.jobId || d.project?.jobId || d.projectJobId || '0000',
          brand: proj?.brand || d.project?.brand || d.projectBrand || 'SS',
          title: proj?.title || d.project?.title || d.projectTitle || 'Creative Deliverables',
          designer: proj?.designer || d.project?.designer || d.projectDesigner || 'Unassigned',
          status: proj?.status || d.status || 'in-progress',
          folderName: proj?.folderName || '',
          deliverables: [],
          totalSizeBytes: 0
        });
      }
      const group = map.get(pId)!;
      group.deliverables.push(d);
      group.totalSizeBytes += (d.sizeBytes || 0);
    }
    const groups = Array.from(map.values());
    for (const g of groups) {
      g.deliverables.sort((a, b) => (a.filename || '').localeCompare(b.filename || '', undefined, { numeric: true, sensitivity: 'base' }));
    }
    return groups;
  });

  const pendingCount = $derived(projectStore.deliverables.filter(d => (d.status || 'pending') === 'pending').length);
  const revisionCount = $derived(projectStore.deliverables.filter(d => d.status === 'revision').length);
  const approvedCount = $derived(projectStore.deliverables.filter(d => d.status === 'approved').length);
  const availableBrands = $derived(Array.from(new Set(projectStore.deliverables.map(d => d.project?.brand || d.projectBrand || 'SS'))).filter(Boolean));

  // Vault Telemetry & Distribution
  const totalStorageBytes = $derived(
    projectStore.deliverables.reduce((acc, d) => acc + (d.sizeBytes || 0), 0)
  );

  const formattedTotalStorage = $derived.by(() => {
    if (totalStorageBytes >= 1024 * 1024 * 1024) {
      return (totalStorageBytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
    }
    return (totalStorageBytes / (1024 * 1024)).toFixed(1) + ' MB';
  });

  const imageCount = $derived(
    projectStore.deliverables.filter(d => d.isImage || d.previewType === 'image' || (!d.isVideo && !d.isPdf && ['PNG', 'JPG', 'JPEG', 'WEBP'].includes(d.format?.toUpperCase()))).length
  );
  const videoCount = $derived(
    projectStore.deliverables.filter(d => d.isVideo || d.previewType === 'video' || ['MP4', 'MOV', 'WEBM'].includes(d.format?.toUpperCase())).length
  );
  const docCount = $derived(
    projectStore.deliverables.filter(d => d.isPdf || d.previewType === 'pdf' || ['PDF', 'AI', 'PSD'].includes(d.format?.toUpperCase())).length
  );

  const imagePct = $derived(projectStore.deliverables.length > 0 ? (imageCount / projectStore.deliverables.length) * 100 : 0);
  const videoPct = $derived(projectStore.deliverables.length > 0 ? (videoCount / projectStore.deliverables.length) * 100 : 0);
  const docPct = $derived(projectStore.deliverables.length > 0 ? (docCount / projectStore.deliverables.length) * 100 : 0);

  // 1-Click Fast Sign-Off Actions
  async function handleQuickApprove(e: MouseEvent, d: DeliverableItem) {
    e.stopPropagation();
    const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
    if (!projId) return;
    try {
      await ApiClient.submitDecision(projId, { decision: 'approved', deliverableId: d.id });
      appState.addToast(`Deliverable "${d.filename}" approved!`, 'success', 'Sign-Off Recorded');
      await projectStore.loadDeliverables();
    } catch (err: any) {
      appState.addToast(err?.message || 'Failed to record approval', 'critical', 'Approval Error');
    }
  }

  async function handleQuickRevision(e: MouseEvent, d: DeliverableItem) {
    e.stopPropagation();
    const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
    if (!projId) return;
    try {
      await ApiClient.submitDecision(projId, { decision: 'revision_requested', deliverableId: d.id });
      appState.addToast(`Revision requested for "${d.filename}"`, 'warning', 'Revision Logged');
      await projectStore.loadDeliverables();
    } catch (err: any) {
      appState.addToast(err?.message || 'Failed to record revision', 'critical', 'Revision Error');
    }
  }

  async function handleQuickCopyShareLink(e: MouseEvent, d: DeliverableItem) {
    e.stopPropagation();
    const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
    if (!projId) return;
    try {
      const res = await ApiClient.getOrCreateProjectShare(projId);
      if (res && res.shareUrl) {
        await navigator.clipboard.writeText(res.shareUrl);
        appState.addToast('Client review link copied to clipboard!', 'success', 'Share Link');
      } else {
        openShare(d);
      }
    } catch {
      openShare(d);
    }
  }
</script>

<div class="deliverables-view-container">
  <!-- View Header -->
  <div class="view-header">
    <div class="header-left">
      <div class="header-tag">
        <span class="badge-accent">Synology Vault</span>
        <span class="header-meta">{projectStore.deliverables.length} Master Outputs</span>
      </div>
      <h1 class="view-title">Deliverables &amp; Reviews</h1>
      <p class="view-subtitle">Inspect, approve, and sign off creative outputs across marketing campaigns in real time.</p>
    </div>

    <div class="header-actions">
      <FluentButton 
        appearance="primary" 
        size="sm" 
        onclick={() => { 
          ingestTargetProject = projectStore.projects[0] || null; 
          showIngesterModal = true; 
        }}
      >
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
          <polyline points="17 8 12 3 7 8"></polyline>
          <line x1="12" y1="3" x2="12" y2="15"></line>
        </svg>
        <span style="margin-left: 5px;">Ingest Deliverables</span>
      </FluentButton>

      <FluentButton appearance="secondary" size="sm" onclick={() => projectStore.loadDeliverables()}>
        <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z"/>
        </svg>
        <span style="margin-left: 5px;">Refresh</span>
      </FluentButton>
    </div>
  </div>

  <!-- Production Vault Telemetry Ribbon -->
  <div class="vault-telemetry-ribbon">
    <div class="telemetry-kpi-group">
      <button class="kpi-pill {filterStatus === 'all' ? 'active' : ''}" onclick={() => filterStatus = 'all'} title="View all deliverables">
        <span class="kpi-label">All Masters</span>
        <span class="kpi-count">{projectStore.deliverables.length}</span>
        <span class="kpi-footprint-badge">{formattedTotalStorage}</span>
      </button>
      <button class="kpi-pill pill-pending {filterStatus === 'pending' ? 'active' : ''}" onclick={() => filterStatus = 'pending'} title="Filter pending review">
        <span class="status-dot dot-pending"></span>
        <span class="kpi-label">Pending</span>
        <span class="kpi-count count-pending">{pendingCount}</span>
      </button>
      <button class="kpi-pill pill-revision {filterStatus === 'revision' ? 'active' : ''}" onclick={() => filterStatus = 'revision'} title="Filter revision requested">
        <span class="status-dot dot-revision"></span>
        <span class="kpi-label">Revision</span>
        <span class="kpi-count count-revision">{revisionCount}</span>
      </button>
      <button class="kpi-pill pill-approved {filterStatus === 'approved' ? 'active' : ''}" onclick={() => filterStatus = 'approved'} title="Filter approved deliverables">
        <span class="status-dot dot-approved"></span>
        <span class="kpi-label">Approved</span>
        <span class="kpi-count count-approved">{approvedCount}</span>
      </button>
    </div>

    <!-- Media Distribution Segmented Bar -->
    {#if projectStore.deliverables.length > 0}
      <div class="telemetry-distribution-card">
        <div class="dist-meta">
          <span class="dist-title">Format Distribution</span>
          <span class="dist-legend">
            <span class="legend-dot img-dot"></span> Images ({imageCount})
            <span class="legend-dot vid-dot"></span> Videos ({videoCount})
            <span class="legend-dot doc-dot"></span> Docs ({docCount})
          </span>
        </div>
        <div class="dist-bar-track">
          <div class="dist-bar-fill img-fill" style="width: {imagePct}%" title="Images: {imageCount} ({imagePct.toFixed(0)}%)"></div>
          <div class="dist-bar-fill vid-fill" style="width: {videoPct}%" title="Videos: {videoCount} ({videoPct.toFixed(0)}%)"></div>
          <div class="dist-bar-fill doc-fill" style="width: {docPct}%" title="Documents: {docCount} ({docPct.toFixed(0)}%)"></div>
        </div>
      </div>
    {/if}
  </div>

  <!-- Filter & Search Toolbar -->
  <div class="deliverable-toolbar">
    <div class="search-box">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8"></circle>
        <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
      </svg>
      <input
        bind:this={searchInputRef}
        type="text"
        placeholder="Filter deliverables by filename, job ID, designer..."
        value={rawSearchInput}
        oninput={handleSearchChange}
      />
      {#if rawSearchInput}
        <button class="clear-search" onclick={handleClearSearch} title="Clear search">✕</button>
      {/if}
      <kbd class="search-kbd" title="Press Ctrl+K to quick filter">Ctrl K</kbd>
    </div>

    <div class="filter-group">
      <!-- Media Class Filter -->
      <select bind:value={filterMediaClass} class="clean-select" aria-label="Filter Media Class">
        <option value="all">Format: All</option>
        <option value="raster_image">Images (PNG, JPG)</option>
        <option value="video_master">Videos (MP4, MOV)</option>
        <option value="print_pdf">PDF / Print</option>
        <option value="vector_graphics">Vectors (SVG, AI)</option>
      </select>

      <!-- Aspect Ratio Filter -->
      <select bind:value={filterAspectRatio} class="clean-select" aria-label="Filter Aspect Ratio">
        <option value="all">Ratio: All</option>
        <option value="1:1">1:1 Square</option>
        <option value="9:16">9:16 Vertical</option>
        <option value="16:9">16:9 Landscape</option>
        <option value="4:5">4:5 Portrait</option>
      </select>

      <!-- Brand Filter -->
      <select bind:value={filterBrand} class="clean-select" aria-label="Filter Brand">
        <option value="all">Brand: All ({availableBrands.length})</option>
        {#each availableBrands as b}
          <option value={b}>{b}</option>
        {/each}
      </select>

      <!-- Reset Filters Pill -->
      {#if hasActiveFilters}
        <button class="filter-reset-btn" onclick={resetAllFilters} title="Reset all active filters">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"></path>
            <path d="M3 3v5h5"></path>
          </svg>
          <span>Reset Filters</span>
        </button>
      {/if}

      <!-- Group By Toggle -->
      <div class="view-mode-toggle" title="Grouping Mode">
        <button 
          class="mode-btn {groupByProject ? 'active' : ''}" 
          onclick={() => groupByProject = true} 
          title="Group by Project Folder"
        >
          <FluentIcons name="folder" size={13} />
        </button>
        <button 
          class="mode-btn {!groupByProject ? 'active' : ''}" 
          onclick={() => groupByProject = false} 
          title="Flat Asset List"
        >
          <FluentIcons name="box" size={13} />
        </button>
      </div>

      <!-- View Mode Toggle -->
      <div class="view-mode-toggle">
        <button class="mode-btn {viewMode === 'grid' ? 'active' : ''}" onclick={() => viewMode = 'grid'} title="Grid Card View">
          <FluentIcons name="grid" size={13} />
        </button>
        <button class="mode-btn {viewMode === 'table' ? 'active' : ''}" onclick={() => viewMode = 'table'} title="Metadata Table View">
          <FluentIcons name="table" size={13} />
        </button>
      </div>
    </div>
  </div>

  <!-- Main Deliverables Content -->
  {#if projectStore.isLoading && projectStore.deliverables.length === 0}
    <div class="state-card">
      <div class="spinner-large"></div>
      <p class="state-title">Scanning Synology Vault Deliverables...</p>
      <p class="state-desc">Indexing high-resolution renders, mockups, and PDFs from active campaigns.</p>
    </div>
  {:else if filteredDeliverables.length === 0}
    <div class="state-card empty-state">
      <div class="empty-icon-box">
        <FluentIcons name="folder" size={36} color="rgba(255,255,255,0.2)" />
      </div>
      <p class="state-title">No deliverables match the active filter</p>
      <p class="state-desc">Try clearing your search query or selecting "All Deliverables".</p>
      <FluentButton appearance="secondary" size="sm" onclick={() => { filterStatus = 'all'; searchQuery = ''; filterBrand = 'all'; filterMediaClass = 'all'; filterAspectRatio = 'all'; }}>
        Reset Filters
      </FluentButton>
    </div>
  {:else if viewMode === 'grid'}
    {#if groupByProject}
      <!-- ═══════════ GROUPED BY PROJECT FOLDER ═══════════ -->
      <div class="project-groups-container">
        {#each groupedDeliverables as group (group.projectId)}
          {@const isCollapsed = !!collapsedGroups[group.projectId]}
          <div class="project-group-card">
            <!-- Group Header Bar -->
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="group-header" onclick={() => toggleGroup(group.projectId)}>
              <div class="group-header-left">
                <span class="chevron-arrow {isCollapsed ? 'collapsed' : ''}">▾</span>
                <div class="group-folder-icon">
                  <FluentIcons name="folder" size={15} color="var(--brand-accent, #0078D4)" />
                </div>
                <span class="group-job-badge">{group.jobId}</span>
                <span class="group-brand-badge">{group.brand}</span>
                <h3 class="group-title">{group.title}</h3>
                <span class="group-status-pill status-{group.status}">
                  <span class="badge-dot"></span>
                  {group.status}
                </span>
              </div>

              <div class="group-header-right" onclick={(e) => e.stopPropagation()}>
                <span class="group-meta-summary">
                  <strong>{group.deliverables.length}</strong> file{group.deliverables.length === 1 ? '' : 's'} · {(group.totalSizeBytes / (1024 * 1024)).toFixed(2)} MB · {group.designer}
                </span>

                <button 
                  class="group-action-btn" 
                  onclick={() => appState.navigate('project-detail', { id: group.projectId })}
                  title="Open Project Workspace"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path>
                    <polyline points="15 3 21 3 21 9"></polyline>
                    <line x1="10" y1="14" x2="21" y2="3"></line>
                  </svg>
                  <span>Workspace</span>
                </button>

                <a 
                  href={ApiClient.getProjectExportUrl(group.projectId, 'all')} 
                  download="{group.jobId}_deliverables.zip"
                  class="group-action-btn"
                  title="Download Project Handover ZIP"
                >
                  <FluentIcons name="download" size={12} />
                  <span>ZIP</span>
                </a>
              </div>
            </div>

            <!-- Group Deliverables Grid -->
            {#if !isCollapsed}
              <div class="group-content">
                <div class="deliverables-grid">
                  {#each group.deliverables as d (d.id || d.filename)}
                    <!-- svelte-ignore a11y_click_events_have_key_events -->
                    <!-- svelte-ignore a11y_no_static_element_interactions -->
                    <div class="del-card-wrapper" onclick={() => openLightbox(d)}>
                      <div class="del-card">
                        <!-- Preview Box -->
                        <div class="del-preview-box">
                          {#if (d.isImage || d.previewType === 'image') && d.previewUrl}
                            <img
                              src={d.previewUrl}
                              alt={d.filename}
                              loading="lazy"
                              onerror={(e) => {
                                (e.currentTarget as HTMLElement).style.display = 'none';
                              }}
                            />
                          {:else if d.isVideo || d.previewType === 'video'}
                            <div class="doc-sheet video-sheet">
                              <div class="sheet-icon-circle video-circle">
                                <FluentIcons name="video" size={20} />
                              </div>
                              <span class="sheet-type-tag">VIDEO MASTER</span>
                            </div>
                          {:else if d.isPdf || d.previewType === 'pdf'}
                            <div class="doc-sheet pdf-sheet">
                              <div class="sheet-icon-circle pdf-circle">
                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                                  <polyline points="14 2 14 8 20 8"></polyline>
                                  <line x1="16" y1="13" x2="8" y2="13"></line>
                                  <line x1="16" y1="17" x2="8" y2="17"></line>
                                  <polyline points="10 9 9 9 8 9"></polyline>
                                </svg>
                              </div>
                              <span class="sheet-type-tag">PDF DOCUMENT</span>
                            </div>
                          {:else}
                            <div class="doc-sheet generic-sheet">
                              <div class="sheet-icon-circle generic-circle">
                                <FluentIcons name="file" size={20} />
                              </div>
                              <span class="sheet-type-tag">{(d.ext || d.extension || (d.filename ? d.filename.split('.').pop() : '') || 'FILE').replace('.', '').toUpperCase()}</span>
                            </div>
                          {/if}

                          <!-- Status Tag Overlay Top Left -->
                          <span class="preview-status-badge status-{(d.status || 'pending')}">
                            <span class="badge-dot"></span>
                            {(d.status || 'pending')}
                          </span>

                          <!-- Format / Ratio Badge Top Right -->
                          <span class="format-badge">
                            {d.format || (d.ext ? d.ext.toUpperCase().replace('.', '') : 'ASSET')}
                            {#if d.aspectRatioEstimate && d.aspectRatioEstimate !== 'standard'}
                              · {d.aspectRatioEstimate}
                            {/if}
                          </span>
                        </div>

                        <!-- Card Body -->
                        <div class="del-body">
                          <h3 class="del-title" title={d.filename}>{d.filename}</h3>

                          <div class="del-footer-row">
                            <span class="meta-designer">
                              <FluentIcons name="user" size={11} />
                              <span>{d.project?.designer || d.projectDesigner || 'Unassigned'}</span>
                            </span>
                            <span class="meta-size">{d.sizeBytes ? (d.sizeBytes / (1024 * 1024)).toFixed(2) : '0.00'} MB</span>
                          </div>

                          <!-- Quick Action Bar -->
                          <div class="del-actions" onclick={(e) => e.stopPropagation()}>
                            <button class="action-btn-pill" onclick={() => openLightbox(d)} title="Open Fullscreen Inspector">
                              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                <circle cx="12" cy="12" r="3"></circle>
                              </svg>
                              <span>Inspect</span>
                            </button>

                            <div class="action-icons-right">
                              {#if (d.status || 'pending') !== 'approved'}
                                <button class="tool-icon-btn action-approve" title="1-Click Approve Master" onclick={(e) => handleQuickApprove(e, d)}>
                                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                                </button>
                              {/if}
                              {#if (d.status || 'pending') !== 'revision'}
                                <button class="tool-icon-btn action-revision" title="1-Click Request Revision" onclick={(e) => handleQuickRevision(e, d)}>
                                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                                </button>
                              {/if}
                              {#if d.isImage || d.previewType === 'image'}
                                <button class="tool-icon-btn" title="Smart Social Resizer" onclick={() => openResizer(d)}>
                                  <FluentIcons name="vector" size={13} />
                                </button>
                                <button class="tool-icon-btn" title="Print Preflight Validator" onclick={() => openPreflight(d)}>
                                  <FluentIcons name="printer" size={13} />
                                </button>
                              {/if}
                              <button class="tool-icon-btn" title="Quick Copy Client Review Link" onclick={(e) => handleQuickCopyShareLink(e, d)}>
                                <FluentIcons name="link" size={13} />
                              </button>
                              {#if d.downloadUrl}
                                <a href={d.downloadUrl} download={d.filename} class="tool-icon-btn" title="Download Master File">
                                  <FluentIcons name="download" size={13} />
                                </a>
                              {/if}
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {:else}
      <!-- ═══════════ FLAT LIST GRID ═══════════ -->
      <div class="deliverables-grid">
        {#each filteredDeliverables as d (d.id || d.filename)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div class="del-card-wrapper" onclick={() => openLightbox(d)}>
            <div class="del-card">
              <!-- Preview Box -->
              <div class="del-preview-box">
                {#if (d.isImage || d.previewType === 'image') && d.previewUrl}
                  <img
                    src={d.previewUrl}
                    alt={d.filename}
                    loading="lazy"
                    onerror={(e) => {
                      (e.currentTarget as HTMLElement).style.display = 'none';
                    }}
                  />
                {:else if d.isVideo || d.previewType === 'video'}
                  <div class="doc-sheet video-sheet">
                    <div class="sheet-icon-circle video-circle">
                      <FluentIcons name="video" size={20} />
                    </div>
                    <span class="sheet-type-tag">VIDEO MASTER</span>
                  </div>
                {:else if d.isPdf || d.previewType === 'pdf'}
                  <div class="doc-sheet pdf-sheet">
                    <div class="sheet-icon-circle pdf-circle">
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                        <polyline points="14 2 14 8 20 8"></polyline>
                        <line x1="16" y1="13" x2="8" y2="13"></line>
                        <line x1="16" y1="17" x2="8" y2="17"></line>
                        <polyline points="10 9 9 9 8 9"></polyline>
                      </svg>
                    </div>
                    <span class="sheet-type-tag">PDF DOCUMENT</span>
                  </div>
                {:else}
                  <div class="doc-sheet generic-sheet">
                    <div class="sheet-icon-circle generic-circle">
                      <FluentIcons name="file" size={20} />
                    </div>
                    <span class="sheet-type-tag">{(d.ext || d.extension || (d.filename ? d.filename.split('.').pop() : '') || 'FILE').replace('.', '').toUpperCase()}</span>
                  </div>
                {/if}

                <!-- Status Tag Overlay Top Left -->
                <span class="preview-status-badge status-{(d.status || 'pending')}">
                  <span class="badge-dot"></span>
                  {(d.status || 'pending')}
                </span>

                <!-- Format / Ratio Badge Top Right -->
                <span class="format-badge">
                  {d.format || (d.ext ? d.ext.toUpperCase().replace('.', '') : 'ASSET')}
                  {#if d.aspectRatioEstimate && d.aspectRatioEstimate !== 'standard'}
                    · {d.aspectRatioEstimate}
                  {/if}
                </span>
              </div>

              <!-- Card Body -->
              <div class="del-body">
                <div class="del-top-meta">
                  <span class="job-tag">{d.project?.jobId || d.projectJobId || '0000'}</span>
                  <span class="brand-tag">{d.project?.brand || d.projectBrand || 'SS'}</span>
                  <span class="proj-title-trunc" title={d.project?.title || d.projectTitle || ''}>
                    {d.project?.title || d.projectTitle || 'Creative Asset'}
                  </span>
                </div>

                <h3 class="del-title" title={d.filename}>{d.filename}</h3>

                <div class="del-footer-row">
                  <span class="meta-designer">
                    <FluentIcons name="user" size={11} />
                    <span>{d.project?.designer || d.projectDesigner || 'Unassigned'}</span>
                  </span>
                  <span class="meta-size">{d.sizeBytes ? (d.sizeBytes / (1024 * 1024)).toFixed(2) : '0.00'} MB</span>
                </div>

                <!-- Quick Action Bar -->
                <div class="del-actions" onclick={(e) => e.stopPropagation()}>
                  <button class="action-btn-pill" onclick={() => openLightbox(d)} title="Open Fullscreen Inspector">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                      <circle cx="12" cy="12" r="3"></circle>
                    </svg>
                    <span>Inspect</span>
                  </button>

                  <div class="action-icons-right">
                    {#if (d.status || 'pending') !== 'approved'}
                      <button class="tool-icon-btn action-approve" title="1-Click Approve Master" onclick={(e) => handleQuickApprove(e, d)}>
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                      </button>
                    {/if}
                    {#if (d.status || 'pending') !== 'revision'}
                      <button class="tool-icon-btn action-revision" title="1-Click Request Revision" onclick={(e) => handleQuickRevision(e, d)}>
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                      </button>
                    {/if}
                    {#if d.isImage || d.previewType === 'image'}
                      <button class="tool-icon-btn" title="Smart Social Resizer" onclick={() => openResizer(d)}>
                        <FluentIcons name="vector" size={13} />
                      </button>
                      <button class="tool-icon-btn" title="Print Preflight Validator" onclick={() => openPreflight(d)}>
                        <FluentIcons name="printer" size={13} />
                      </button>
                    {/if}
                    <button class="tool-icon-btn" title="Quick Copy Client Review Link" onclick={(e) => handleQuickCopyShareLink(e, d)}>
                      <FluentIcons name="link" size={13} />
                    </button>
                    {#if d.downloadUrl}
                      <a href={d.downloadUrl} download={d.filename} class="tool-icon-btn" title="Download Master File">
                        <FluentIcons name="download" size={13} />
                      </a>
                    {/if}
                  </div>
                </div>
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  {:else}
    <!-- Compact Metadata Table Mode -->
    <div class="dam-table-card">
      <table class="dam-table">
        <thead>
          <tr>
            <th>Preview</th>
            <th>Filename</th>
            <th>Project / Job ID</th>
            <th>Format</th>
            <th>Aspect Ratio</th>
            <th>Size</th>
            <th>Status</th>
            <th style="text-align:right;">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredDeliverables as d}
            <tr onclick={() => openLightbox(d)} class="table-row-clickable">
              <td class="table-thumb-col">
                {#if (d.isImage || d.previewType === 'image') && d.previewUrl}
                  <img src={d.previewUrl} alt={d.filename} class="table-thumb" />
                {:else if d.isVideo}
                  <span class="table-icon-pill">
                    <FluentIcons name="video" size={12} />
                    <span style="margin-left: 3px;">Video</span>
                  </span>
                {:else if d.isPdf}
                  <span class="table-icon-pill">
                    <FluentIcons name="file" size={12} color="#EF4444" />
                    <span style="margin-left: 3px;">PDF</span>
                  </span>
                {:else}
                  <span class="table-icon-pill">
                    <FluentIcons name="folder" size={12} />
                    <span style="margin-left: 3px;">File</span>
                  </span>
                {/if}
              </td>
              <td><span class="table-filename">{d.filename}</span></td>
              <td>
                <div class="table-proj-info">
                  <span class="job-id-sm">{d.project?.jobId || d.projectJobId || 'JOB'}</span>
                  <span class="proj-title-sm">{d.project?.title || d.projectTitle || ''}</span>
                </div>
              </td>
              <td><span class="format-badge">{d.format || d.ext}</span></td>
              <td><span class="ratio-badge">{d.aspectRatioEstimate || 'Auto'}</span></td>
              <td><span class="size-text">{d.sizeBytes ? (d.sizeBytes / (1024 * 1024)).toFixed(2) : '0.00'} MB</span></td>
              <td><span class="status-badge status-{(d.status || 'pending')}">{(d.status || 'pending').toUpperCase()}</span></td>
              <td style="text-align:right;" onclick={(e) => e.stopPropagation()}>
                <div class="table-actions">
                  {#if (d.status || 'pending') !== 'approved'}
                    <button class="tool-icon-btn action-approve" title="1-Click Approve Master" onclick={(e) => handleQuickApprove(e, d)}>
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </button>
                  {/if}
                  {#if (d.status || 'pending') !== 'revision'}
                    <button class="tool-icon-btn action-revision" title="1-Click Request Revision" onclick={(e) => handleQuickRevision(e, d)}>
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                    </button>
                  {/if}
                  {#if d.isImage || d.previewType === 'image'}
                    <button class="tool-icon-btn" title="Social Resizer" onclick={() => openResizer(d)}>
                      <FluentIcons name="vector" size={13} />
                    </button>
                    <button class="tool-icon-btn" title="Print Preflight" onclick={() => openPreflight(d)}>
                      <FluentIcons name="printer" size={13} />
                    </button>
                  {/if}
                  <button class="tool-icon-btn" title="Quick Copy Client Review Link" onclick={(e) => handleQuickCopyShareLink(e, d)}>
                    <FluentIcons name="link" size={13} />
                  </button>
                  {#if d.downloadUrl}
                    <a href={d.downloadUrl} download={d.filename} class="tool-icon-btn" title="Download Master File">
                      <FluentIcons name="download" size={13} />
                    </a>
                  {/if}
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}

  <!-- Review & Approval Lightbox Modal -->
  <DeliverableLightbox
    deliverable={selectedDeliverable}
    bind:open={lightboxOpen}
    onClose={() => lightboxOpen = false}
    onApprove={async (d) => {
      const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
      if (projId) {
        await ApiClient.submitDecision(projId, { decision: 'approved', deliverableId: d.id });
        appState.addToast(`Deliverable "${d.filename}" approved!`, 'success', 'Sign-Off Recorded');
        await projectStore.loadDeliverables();
      }
    }}
    onRevision={async (d) => {
      const projId = d.project?.id || d.projectId || d.project?.jobId || d.projectJobId;
      if (projId) {
        await ApiClient.submitDecision(projId, { decision: 'revision_requested', deliverableId: d.id });
        appState.addToast(`Revision requested for "${d.filename}"`, 'warning', 'Revision Logged');
        await projectStore.loadDeliverables();
      }
    }}
  />

  <!-- Vault Ingester Modal -->
  <VaultIngesterModal
    bind:open={showIngesterModal}
    projectId={ingestTargetProject?.id}
    projectTitle={ingestTargetProject?.title}
    onSuccess={() => projectStore.loadDeliverables()}
  />

  <!-- Batch Resizer Modal -->
  <BatchResizerModal
    bind:open={showResizerModal}
    deliverable={resizerTargetDeliverable}
    projectTitle={resizerTargetDeliverable?.project?.title || resizerTargetDeliverable?.projectTitle}
  />

  <!-- Share Link Modal -->
  <ShareLinkModal
    bind:open={showShareModal}
    projectId={shareTargetProject?.id}
    projectTitle={shareTargetProject?.title}
  />

  <!-- Print Preflight Validator Modal -->
  <PreflightValidatorModal
    bind:open={showPreflightModal}
    deliverable={preflightTargetDeliverable}
    projectTitle={preflightTargetDeliverable?.project?.title || preflightTargetDeliverable?.projectTitle}
  />
</div>

<style>
  .deliverables-view-container {
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding-bottom: 40px;
  }

  .view-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    flex-wrap: wrap;
    gap: 16px;
  }

  .header-tag {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 6px;
  }

  .badge-accent {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    background: rgba(4, 51, 136, 0.15);
    color: var(--brand-accent);
    padding: 3px 8px;
    border-radius: var(--radius-sm);
    border: 1px solid rgba(33, 161, 247, 0.3);
  }

  .header-meta {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-tertiary);
  }

  .view-title {
    font-size: 24px;
    font-weight: 800;
    color: var(--text-primary);
    margin: 0;
  }

  .view-subtitle {
    font-size: 13px;
    color: var(--text-secondary);
    margin-top: 4px;
  }

  /* Production Vault Telemetry Ribbon */
  .vault-telemetry-ribbon {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 12px;
    padding: 10px 14px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03);
  }

  .telemetry-kpi-group {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .kpi-pill {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 13px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 20px;
    cursor: pointer;
    font-size: 12.5px;
    font-weight: 600;
    color: var(--text-secondary);
    transition: all 0.15s ease;
  }

  .kpi-pill:hover {
    background: var(--surface-card);
    border-color: var(--brand-accent);
    color: var(--text-primary);
  }

  .kpi-pill.active {
    background: var(--brand-tint, rgba(0, 120, 212, 0.08));
    border-color: var(--brand-accent, #0078D4);
    color: var(--brand-primary, #0078D4);
  }

  .kpi-count {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    padding: 1px 7px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 700;
  }
  .count-pending { color: #F59E0B; }
  .count-revision { color: #EF4444; }
  .count-approved { color: #10B981; }

  .kpi-footprint-badge {
    font-size: 11px;
    font-weight: 700;
    font-family: var(--font-mono, monospace);
    color: var(--brand-accent);
    background: rgba(33, 161, 247, 0.12);
    padding: 1px 6px;
    border-radius: 6px;
    margin-left: 2px;
  }

  .status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    display: inline-block;
  }
  .dot-pending { background: #F59E0B; }
  .dot-revision { background: #EF4444; }
  .dot-approved { background: #10B981; }

  .telemetry-distribution-card {
    display: flex;
    flex-direction: column;
    gap: 5px;
    min-width: 240px;
  }

  .dist-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    gap: 12px;
  }

  .dist-title {
    font-weight: 700;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .dist-legend {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 600;
  }

  .legend-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    display: inline-block;
  }
  .img-dot { background: #0078D4; }
  .vid-dot { background: #7C3AED; }
  .doc-dot { background: #DC2626; }

  .dist-bar-track {
    height: 6px;
    width: 100%;
    background: var(--surface-card-subtle);
    border-radius: 4px;
    overflow: hidden;
    display: flex;
  }

  .dist-bar-fill {
    height: 100%;
    transition: width 0.3s ease;
  }
  .img-fill { background: #0078D4; }
  .vid-fill { background: #7C3AED; }
  .doc-fill { background: #DC2626; }

  /* Toolbar */
  .deliverable-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
  }

  .search-box {
    flex: 1;
    min-width: 260px;
    height: 36px;
    min-height: 36px;
    box-sizing: border-box;
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 0 12px;
    color: var(--text-secondary);
    transition: border-color 0.15s;
  }
  .search-box:focus-within {
    border-color: var(--brand-accent);
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.15);
  }

  .search-box input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    color: var(--text-primary);
    font-size: 13px;
  }

  .clear-search {
    background: transparent;
    border: none;
    color: var(--text-tertiary);
    cursor: pointer;
    font-size: 11px;
    padding: 2px 4px;
  }
  .clear-search:hover {
    color: var(--text-primary);
  }

  .search-kbd {
    font-family: inherit;
    font-size: 10.5px;
    font-weight: 700;
    color: var(--text-tertiary);
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    padding: 2px 5px;
    pointer-events: none;
    user-select: none;
  }

  .filter-group {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .clean-select {
    height: 36px;
    line-height: 36px;
    min-height: 36px;
    padding: 0 12px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 12.5px;
    font-weight: 600;
    outline: none;
    cursor: pointer;
    box-sizing: border-box;
    transition: all 0.12s;
  }
  .clean-select:hover {
    border-color: var(--brand-accent);
  }
  .clean-select:focus {
    border-color: var(--brand-accent);
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.15);
  }

  .filter-reset-btn {
    height: 36px;
    min-height: 36px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 0 12px;
    background: var(--brand-tint, rgba(0, 120, 212, 0.08));
    border: 1px solid var(--brand-accent);
    border-radius: 8px;
    color: var(--brand-accent);
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    box-sizing: border-box;
    transition: all 0.12s ease;
  }
  .filter-reset-btn:hover {
    background: var(--brand-accent);
    color: #FFFFFF;
  }

  .view-mode-toggle {
    display: flex;
    align-items: center;
    height: 36px;
    box-sizing: border-box;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    overflow: hidden;
    padding: 2px;
  }

  .mode-btn {
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    border-radius: 6px;
    color: var(--text-tertiary);
    cursor: pointer;
    transition: all 0.12s;
  }
  .mode-btn:hover { color: var(--text-primary); }
  .mode-btn.active {
    background: var(--brand-tint, rgba(0, 120, 212, 0.1));
    color: var(--brand-primary, #0078D4);
    border: 1px solid rgba(0, 120, 212, 0.2);
  }

  /* Project Groups */
  .project-groups-container {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .project-group-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    transition: all 0.15s ease;
  }
  .project-group-card:hover {
    border-color: rgba(0, 120, 212, 0.35);
  }

  .group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 14px;
    background: var(--surface-card-subtle, #F8FAFC);
    border-bottom: 1px solid var(--surface-card-border);
    cursor: pointer;
    user-select: none;
    transition: background 0.12s;
    gap: 12px;
    flex-wrap: wrap;
  }
  .group-header:hover {
    background: var(--surface-card-hover, rgba(0, 120, 212, 0.04));
  }

  .group-header-left {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    flex: 1;
    min-width: 280px;
  }

  .chevron-arrow {
    font-size: 13px;
    color: var(--text-tertiary);
    transition: transform 0.2s ease;
    display: inline-block;
    width: 14px;
    text-align: center;
  }
  .chevron-arrow.collapsed {
    transform: rotate(-90deg);
  }

  .group-folder-icon {
    display: flex;
    align-items: center;
  }

  .group-job-badge {
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    font-weight: 800;
    color: var(--brand-accent, #0078D4);
    background: var(--brand-tint, rgba(0, 120, 212, 0.1));
    padding: 1px 5px;
    border-radius: 4px;
  }

  .group-brand-badge {
    font-size: 10.5px;
    font-weight: 700;
    color: var(--text-secondary);
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    padding: 1px 5px;
    border-radius: 4px;
  }

  .group-title {
    font-size: 13.5px;
    font-weight: 800;
    color: var(--text-primary);
    margin: 0;
    letter-spacing: -0.2px;
  }

  .group-status-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    padding: 2px 7px;
    border-radius: 12px;
  }

  .group-header-right {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .group-meta-summary {
    font-size: 11.5px;
    color: var(--text-tertiary);
    font-weight: 500;
  }

  .group-action-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-primary);
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    cursor: pointer;
    text-decoration: none;
    transition: all 0.12s;
  }
  .group-action-btn:hover {
    background: var(--brand-tint, rgba(0, 120, 212, 0.1));
    color: var(--brand-primary, #0078D4);
    border-color: var(--brand-accent, #0078D4);
  }

  .group-content {
    padding: 12px;
  }

  /* Grid & Cards */
  .deliverables-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 14px;
  }

  .del-card-wrapper {
    cursor: pointer;
  }

  .del-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 10px;
    padding: 10px;
    transition: all 0.15s ease;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    display: flex;
    flex-direction: column;
    height: 100%;
  }
  .del-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
    border-color: var(--brand-accent, #0078D4);
  }

  .del-preview-box {
    height: 145px;
    background: var(--surface-card-subtle, #F8FAFC);
    border-radius: 8px;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    margin-bottom: 8px;
    border: 1px solid var(--surface-card-border);
  }

  .del-preview-box img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.25s ease;
  }
  .del-card:hover .del-preview-box img {
    transform: scale(1.04);
  }

  .doc-sheet {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    height: 100%;
    transition: all 0.2s ease;
  }
  .pdf-sheet {
    background: linear-gradient(180deg, rgba(239, 68, 68, 0.05) 0%, rgba(239, 68, 68, 0.12) 100%);
  }
  .video-sheet {
    background: linear-gradient(180deg, rgba(124, 58, 237, 0.05) 0%, rgba(124, 58, 237, 0.12) 100%);
  }
  .generic-sheet {
    background: linear-gradient(180deg, rgba(100, 116, 139, 0.05) 0%, rgba(100, 116, 139, 0.12) 100%);
  }

  .sheet-icon-circle {
    width: 42px;
    height: 42px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.12);
    transition: transform 0.2s ease;
  }
  .del-card:hover .sheet-icon-circle {
    transform: scale(1.08) translateY(-2px);
  }
  .pdf-circle {
    background: #DC2626;
    color: #FFFFFF;
  }
  .video-circle {
    background: #7C3AED;
    color: #FFFFFF;
  }
  .generic-circle {
    background: #475569;
    color: #FFFFFF;
  }

  .sheet-type-tag {
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 0.6px;
    color: var(--text-secondary);
  }

  .preview-status-badge {
    position: absolute;
    top: 6px;
    left: 6px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 2px 7px;
    border-radius: 20px;
    backdrop-filter: blur(8px);
    display: inline-flex;
    align-items: center;
    gap: 4px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
  }

  .preview-status-badge .badge-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: currentColor;
  }

  .status-approved { background: rgba(16, 185, 129, 0.92); color: #FFFFFF; }
  .status-revision { background: rgba(239, 68, 68, 0.92); color: #FFFFFF; }
  .status-pending { background: rgba(245, 158, 11, 0.92); color: #FFFFFF; }

  .format-badge {
    position: absolute;
    top: 6px;
    right: 6px;
    font-size: 9.5px;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(0, 0, 0, 0.7);
    color: #F8FAFC;
    border: 1px solid rgba(255, 255, 255, 0.2);
    backdrop-filter: blur(8px);
  }

  .del-body {
    display: flex;
    flex-direction: column;
    gap: 3px;
    flex: 1;
  }

  .del-top-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
  }

  .job-tag {
    font-family: var(--font-mono, monospace);
    font-weight: 700;
    color: var(--brand-accent, #0078D4);
    background: var(--brand-tint, rgba(0, 120, 212, 0.08));
    padding: 1px 5px;
    border-radius: 4px;
  }

  .brand-tag {
    font-weight: 700;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    padding: 1px 5px;
    border-radius: 4px;
  }

  .proj-title-trunc {
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
  }

  .del-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin: 1px 0;
  }

  .del-footer-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 11px;
    color: var(--text-tertiary);
    font-weight: 500;
    padding: 3px 0 6px 0;
  }

  .meta-designer {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .del-actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 6px;
    border-top: 1px solid var(--surface-card-border);
    margin-top: auto;
  }

  .action-btn-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
    color: var(--brand-primary, #0078D4);
    background: var(--brand-tint, rgba(0, 120, 212, 0.08));
    border: 1px solid rgba(0, 120, 212, 0.2);
    cursor: pointer;
    transition: all 0.12s;
  }
  .action-btn-pill:hover {
    background: var(--brand-primary, #0078D4);
    color: #FFFFFF;
  }

  .action-icons-right {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .tool-icon-btn {
    width: 32px;
    height: 32px;
    min-width: 32px;
    min-height: 32px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 6px;
    color: var(--text-secondary, #475569);
    cursor: pointer;
    text-decoration: none;
    box-sizing: border-box;
    padding: 0;
    transition: all 0.15s ease;
  }
  .tool-icon-btn :global(svg) {
    display: block;
    fill: currentColor;
  }
  .tool-icon-btn:hover {
    background: var(--brand-tint, rgba(33, 161, 247, 0.12));
    color: var(--brand-primary, #043388);
    border-color: var(--brand-accent, #21A1F7);
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(4, 51, 136, 0.08);
  }
  .tool-icon-btn:active {
    transform: translateY(0);
    box-shadow: none;
  }
  .tool-icon-btn.action-approve:hover {
    background: rgba(16, 185, 129, 0.15);
    color: #10B981;
    border-color: #10B981;
  }
  .tool-icon-btn.action-revision:hover {
    background: rgba(239, 68, 68, 0.15);
    color: #EF4444;
    border-color: #EF4444;
  }

  /* State Cards */
  .state-card {
    text-align: center;
    padding: 60px 20px;
    background: var(--surface-card);
    border: 1px dashed var(--surface-card-border);
    border-radius: var(--radius-lg);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }

  .empty-icon {
    font-size: 40px;
    margin-bottom: 4px;
  }

  .state-title {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
  }

  .state-desc {
    font-size: 13px;
    color: var(--text-secondary);
    max-width: 420px;
    margin-bottom: 12px;
  }

  .ratio-pill {
    position: absolute;
    top: 8px;
    left: 8px;
    background: rgba(0, 0, 0, 0.75);
    color: #38BDF8;
    font-size: 9px;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid rgba(56, 189, 248, 0.4);
    font-family: monospace;
  }

  /* DAM Table */
  .dam-table-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 12px;
    overflow-x: auto;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03);
  }

  .dam-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    text-align: left;
  }

  .dam-table th {
    padding: 12px 16px;
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-tertiary);
  }

  .dam-table td {
    padding: 10px 16px;
    border-bottom: 1px solid var(--surface-card-border);
    color: var(--text-secondary);
    vertical-align: middle;
  }

  .table-row-clickable {
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .table-row-clickable:hover {
    background: var(--surface-card-subtle);
  }

  .table-thumb-col { width: 50px; }
  .table-thumb {
    width: 40px;
    height: 40px;
    object-fit: cover;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
  }
  .table-icon-pill {
    font-size: 10px;
    font-weight: 700;
    padding: 3px 7px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    color: var(--text-secondary);
    display: inline-flex;
    align-items: center;
  }

  .table-filename { font-weight: 700; color: var(--text-primary); }
  .table-proj-info { display: flex; flex-direction: column; gap: 2px; }
  .job-id-sm { font-size: 11px; font-weight: 800; color: var(--brand-accent); font-family: var(--font-mono, monospace); }
  .proj-title-sm { font-size: 11px; color: var(--text-tertiary); }

  .format-badge, .ratio-badge {
    font-size: 10px;
    font-weight: 800;
    padding: 2px 6px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    font-family: var(--font-mono, monospace);
    color: var(--text-secondary);
  }
  .ratio-badge { color: var(--brand-accent); }

  .status-badge {
    font-size: 10px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 4px;
    letter-spacing: 0.5px;
  }
  .status-badge.status-pending { background: rgba(245, 158, 11, 0.15); color: #F59E0B; }
  .status-badge.status-revision { background: rgba(239, 68, 68, 0.15); color: #EF4444; }
  .status-badge.status-approved { background: rgba(16, 185, 129, 0.15); color: #10B981; }

  .table-actions { display: flex; align-items: center; justify-content: flex-end; gap: 6px; }
</style>

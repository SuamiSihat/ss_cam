<script lang="ts">
  import { onMount } from 'svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import { getErrorMessage } from '$lib/copy';
  import type { Project } from '$lib/types';
  import ProjectFilterBar from '$lib/components/features/ProjectFilterBar.svelte';
  import ProjectKanbanView from '$lib/components/features/ProjectKanbanView.svelte';
  import ProjectGanttView from '$lib/components/features/ProjectGanttView.svelte';
  import ProjectCalendarView from '$lib/components/features/ProjectCalendarView.svelte';
  import ProjectTableView from '$lib/components/features/ProjectTableView.svelte';
  import ProjectGraphView from '$lib/components/features/ProjectGraphView.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentErrorBanner from '$lib/components/ui/FluentErrorBanner.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  type ViewMode = 'graph' | 'kanban' | 'gantt' | 'calendar' | 'table';

  let defaultView = $state<ViewMode>(
    (typeof localStorage !== 'undefined' && (localStorage.getItem('ss_cam_default_project_view') as ViewMode)) || 'kanban'
  );

  let viewMode = $state<ViewMode>(
    (typeof localStorage !== 'undefined' && (localStorage.getItem('ss_cam_project_view') as ViewMode)) || defaultView
  );

  let isViewMenuOpen = $state<boolean>(false);

  let projectToDelete = $state<Project | null>(null);
  let showDeleteModal = $state<boolean>(false);
  let isDeleting = $state<boolean>(false);
  let deleteConfirmName = $state<string>('');

  // Feature 7: Bulk select state
  let bulkMode = $state<boolean>(false);
  let selectedIds = $state<Set<string>>(new Set());
  let isBulkUpdating = $state<boolean>(false);

  // Feature 3: Hover quick-action popover state
  let hoverStatusCard = $state<string | null>(null);

  function toggleBulkMode() {
    bulkMode = !bulkMode;
    selectedIds = new Set();
  }

  function toggleSelect(id: string) {
    const next = new Set(selectedIds);
    if (next.has(id)) next.delete(id); else next.add(id);
    selectedIds = next;
  }

  function selectAll() {
    selectedIds = new Set(projectStore.filteredProjects.map((p: any) => p.id));
  }

  async function bulkSetStatus(status: string) {
    if (selectedIds.size === 0) return;
    isBulkUpdating = true;
    const ids = Array.from(selectedIds);
    try {
      await Promise.all(ids.map(id => ApiClient.updateProject(id, { status } as any)));
      await projectStore.loadProjects(true);
      appState.addToast(`${ids.length} project${ids.length > 1 ? 's' : ''} set to "${status}".`, 'success', 'Bulk update');
      selectedIds = new Set();
      bulkMode = false;
    } catch (err: any) {
      appState.addToast(getErrorMessage(err, 'Bulk update failed. Please try again.'), 'error');
    } finally {
      isBulkUpdating = false;
    }
  }

  async function quickSetStatus(id: string, status: string, e: Event) {
    e.stopPropagation();
    hoverStatusCard = null;
    try {
      await ApiClient.updateProject(id, { status } as any);
      await projectStore.loadProjects(true);
      appState.addToast(`Status updated to "${status}".`, 'success');
    } catch (err: any) {
      appState.addToast(getErrorMessage(err, 'We couldn\'t update the project status. Please try again.'), 'error');
    }
  }

  const isAdminUser = $derived.by(() => {

    return appState.currentUser?.capabilities?.canDeleteProject ?? false;
  });

  function setViewMode(mode: ViewMode) {
    viewMode = mode;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ss_cam_project_view', mode);
    }
  }

  function saveAsDefaultView() {
    defaultView = viewMode;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ss_cam_default_project_view', viewMode);
      localStorage.setItem('ss_cam_project_view', viewMode);
    }
    const viewLabels: Record<ViewMode, string> = {
      graph: 'Graph View',
      kanban: 'Kanban Board',
      gantt: 'Gantt Timeline',
      calendar: 'Calendar View',
      table: 'Data Table'
    };
    appState.addToast(`Saved ${viewLabels[viewMode]} as your default view.`, 'success');
  }

  function handleDeleteRequest(project: Project) {
    projectToDelete = project;
    deleteConfirmName = '';
    showDeleteModal = true;
  }

  async function confirmDeleteProject() {
    if (!projectToDelete) return;
    const requiredName = (projectToDelete.title || projectToDelete.jobId || projectToDelete.id).trim();
    if (deleteConfirmName.trim().toLowerCase() !== requiredName.toLowerCase()) {
      appState.addToast('Please type the exact project name to confirm deletion.', 'warning');
      return;
    }
    isDeleting = true;
    try {
      await ApiClient.deleteProject(projectToDelete.id);
      appState.addToast(`Project ${projectToDelete.jobId || projectToDelete.title} deleted.`, 'success');
      showDeleteModal = false;
      projectToDelete = null;
      deleteConfirmName = '';
      await projectStore.loadProjects();
      await projectStore.loadDashboard();
    } catch (err: any) {
      appState.addToast(getErrorMessage(err, 'We couldn\'t delete the project. Please try again.'), 'error');
    } finally {
      isDeleting = false;
    }
  }

  onMount(() => {
    projectStore.loadProjects();
    // Feature 2: Apply filter params from KPI card navigation (Dashboard → Projects)
    const params = appState.routeParams;
    if (params.status) {
      projectStore.setFilter('status', params.status);
    } else if (params.isOverdue) {
      projectStore.setFilter('status', 'overdue');
    }
    // Clear params after consuming so back-navigation resets default view
    appState.routeParams = {};

    function handleClickOutside(e: MouseEvent) {
      const target = e.target as HTMLElement;
      if (!target.closest('.more-views-wrapper')) {
        isViewMenuOpen = false;
      }
    }
    window.addEventListener('click', handleClickOutside);
    return () => {
      window.removeEventListener('click', handleClickOutside);
    };
  });
</script>

<div class="projects-container">
  {#if projectStore.errorProjects}
    <FluentErrorBanner
      title="Unable to load projects"
      message={projectStore.errorProjects}
      retryLabel="Reload Projects"
      onRetry={() => projectStore.loadProjects()}
    />
  {/if}

  <!-- View Header & View Switcher -->
  <div class="view-header">
    <div class="header-titles">
      <h1 class="view-title">Projects</h1>
      <p class="view-subtitle">Browse creative assets, campaign folders, briefs, and schedules.</p>
    </div>

    <!-- View Controls & Default Action -->
    <div class="view-controls-wrap">
      <!-- Segmented View Mode Switcher -->
      <div class="view-switcher-segmented">
        <button
          type="button"
          class="seg-view-btn"
          class:is-active={viewMode === 'kanban'}
          onclick={() => setViewMode('kanban')}
          title="Kanban Pipeline Board"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M4 4h4v16H4V4zm6 0h4v10h-4V4zm6 0h4v13h-4V4z"/>
          </svg>
          <span>Kanban</span>
        </button>

        <button
          type="button"
          class="seg-view-btn"
          class:is-active={viewMode === 'table'}
          onclick={() => setViewMode('table')}
          title="High Density Data Table"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <path d="M3 3h18v18H3V3zm2 4v3h14V7H5zm0 5v3h14v-3H5zm0 5v2h14v-2H5z"/>
          </svg>
          <span>Table</span>
        </button>

        <div class="more-views-wrapper">
          <button
            type="button"
            class="seg-view-btn more-views-btn"
            class:is-active={['graph', 'gantt', 'calendar'].includes(viewMode)}
            onclick={() => (isViewMenuOpen = !isViewMenuOpen)}
            aria-haspopup="menu"
            aria-expanded={isViewMenuOpen}
            title="Switch View"
          >
            <span>View ▾</span>
          </button>

          {#if isViewMenuOpen}
            <div class="views-dropdown-menu" role="menu">
              <button
                type="button"
                class="dropdown-item"
                class:active={viewMode === 'graph'}
                onclick={() => { setViewMode('graph'); isViewMenuOpen = false; }}
                role="menuitem"
              >
                <FluentIcons name="graph" size={13} />
                <span style="margin-left: 8px;">Graph View</span>
              </button>
              <button
                type="button"
                class="dropdown-item"
                class:active={viewMode === 'gantt'}
                onclick={() => { setViewMode('gantt'); isViewMenuOpen = false; }}
                role="menuitem"
              >
                <FluentIcons name="gantt" size={13} />
                <span style="margin-left: 8px;">Gantt Timeline</span>
              </button>
              <button
                type="button"
                class="dropdown-item"
                class:active={viewMode === 'calendar'}
                onclick={() => { setViewMode('calendar'); isViewMenuOpen = false; }}
                role="menuitem"
              >
                <FluentIcons name="calendar" size={13} />
                <span style="margin-left: 8px;">Calendar</span>
              </button>
            </div>
          {/if}
        </div>
      </div>

      <!-- Save Default View Action Button -->
      {#if viewMode === defaultView}
        <div class="default-view-badge" title="This view is set as your default opening view for Project Catalog">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>
          <span>Default View</span>
        </div>
      {:else}
        <button
          type="button"
          class="save-default-btn"
          onclick={saveAsDefaultView}
          title="Save {viewMode.toUpperCase()} as your default opening view"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
          <span>Save as Default</span>
        </button>
      {/if}
      <!-- Feature 7: Bulk Select Mode Toggle (graph fallback grid view only) -->
    </div>
  </div>

  <!-- Shared Filter Bar -->
  <ProjectFilterBar />

  <!-- Dynamic View Render -->
  {#if projectStore.isLoading && projectStore.projects.length === 0}
    <div class="loading-box">
      <div class="loading-spinner-orbit"></div>
      <span>Syncing Projects with Studio Workspace...</span>
    </div>
  {:else if projectStore.filteredProjects.length === 0}
    <div class="empty-box">
      <div class="empty-emoji">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="rgba(4,51,136,0.25)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
          <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
          <line x1="12" y1="11" x2="12" y2="17"/><line x1="9" y1="14" x2="15" y2="14"/>
        </svg>
      </div>
      {#if projectStore.hasActiveFilters}
        <h3>No projects match your current filters</h3>
        <p>Try clearing your search query, status, or brand filters to see all projects.</p>
        <button type="button" class="empty-clear-btn" onclick={() => projectStore.resetFilters()}>
          <FluentIcons name="close" size={13} />
          <span style="margin-left: 6px;">Clear all filters</span>
        </button>
      {:else}
        <h3>No projects found</h3>
        <p>Submit a new creative request to start a production project on the shared drive.</p>
        <button class="empty-cta-btn" onclick={() => appState.navigate('order-form')}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
          New Request
        </button>
      {/if}
    </div>

  {:else if viewMode === 'graph'}
    <ProjectGraphView
      projects={projectStore.filteredProjects}
    />
  {:else if viewMode === 'kanban'}
    <ProjectKanbanView
      projects={projectStore.filteredProjects}
      {isAdminUser}
      onDelete={handleDeleteRequest}
    />
  {:else if viewMode === 'gantt'}
    <ProjectGanttView
      projects={projectStore.filteredProjects}
    />
  {:else if viewMode === 'calendar'}
    <ProjectCalendarView
      projects={projectStore.filteredProjects}
    />
  {:else if viewMode === 'table'}
    <ProjectTableView
      projects={projectStore.filteredProjects}
      {isAdminUser}
      onDelete={handleDeleteRequest}
    />
  {:else}
    <!-- Feature 7: Bulk Select Toolbar -->
  {#if bulkMode}
  <div class="bulk-action-bar" role="toolbar" aria-label="Bulk project actions">
    <span class="bulk-count">{selectedIds.size} of {projectStore.filteredProjects.length} selected</span>
    <button type="button" class="bulk-sel-all-btn" onclick={selectAll} disabled={isBulkUpdating}>Select All</button>
    <div class="bulk-status-actions">
      {#each [['in-progress','In Progress'],['review','In Review'],['approved','Approved'],['on-hold','On Hold']] as [s, label]}
        <button type="button" class="bulk-status-btn bulk-s-{s}" onclick={() => bulkSetStatus(s)} disabled={selectedIds.size === 0 || isBulkUpdating}>{label}</button>
      {/each}
    </div>
    {#if isBulkUpdating}<span class="bulk-spinner">Updating…</span>{/if}
    <button type="button" class="bulk-cancel-btn" onclick={toggleBulkMode}>
      <FluentIcons name="close" size={12} /> Cancel
    </button>
  </div>
  {/if}

  <!-- Default Cards Grid View -->
    <div class="projects-grid">
      {#each projectStore.filteredProjects as p (p.id)}
        <div
          class="project-card-wrapper"
          onclick={() => appState.navigate('project-detail', { id: p.id })}
          role="button"
          tabindex="0"
          onkeydown={(e) => e.key === 'Enter' && appState.navigate('project-detail', { id: p.id })}
        >
          <FluentCard hoverLift padding="16px">
            <div class="card-top">
              <div class="job-id-wrap">
                <span class="job-id-chip">{p.jobId || p.id}</span>
                {#if isAdminUser}
                  <button
                    type="button"
                    class="card-quick-delete-btn"
                    title="Delete project & all subfolders"
                    onclick={(e) => {
                      e.stopPropagation();
                      handleDeleteRequest(p);
                    }}
                  >
                    <FluentIcons name="delete" size={13} />
                  </button>
                {/if}
              </div>
              <div class="badges-row">
                <FluentBadge type="brand" value={p.brand || 'SS'} />
                <FluentBadge type="status" value={p.status} />
              </div>
            </div>

            <a
              href="#project-detail/{encodeURIComponent(p.id)}"
              class="project-card-title"
              onclick={(e) => { e.stopPropagation(); appState.navigate('project-detail', { id: p.id }); }}
            >
              {p.title}
            </a>

            <div class="meta-rows">
              <div class="meta-row">
                <span class="meta-key">Designer:</span>
                <span class="meta-val">{p.designer || 'Unassigned'}</span>
              </div>
              <div class="meta-row">
                <span class="meta-key">Deadline:</span>
                <span class="meta-val" class:is-overdue={p.isOverdue}>{p.deadline || 'None'}</span>
              </div>
            </div>

            {#if p.tags && p.tags.length > 0}
              <div class="card-tags">
                {#each p.tags.slice(0, 3) as t}
                  <span class="tag-pill">{t}</span>
                {/each}
                {#if p.tags.length > 3}
                  <span class="tag-more">+{p.tags.length - 3}</span>
                {/if}
              </div>
            {/if}
          <!-- Feature 3: Hover quick status actions -->
          <div class="card-hover-actions" role="group" aria-label="Quick status actions">
            {#each [['in-progress','▶','In Progress'],['review','👁','Review'],['approved','✓','Approved'],['on-hold','⏸','Hold']] as [qs,icon,qlabel]}
              <button type="button" class="qa-btn qa-{qs}" title="Set: {qlabel}" onclick={(e) => quickSetStatus(p.id, qs, e)}>{icon}</button>
            {/each}
            <button type="button" class="qa-btn qa-open" title="Open" onclick={(e) => { e.stopPropagation(); appState.navigate('project-detail', { id: p.id }); }}>→</button>
          </div>
          <!-- Feature 7: Bulk select checkbox overlay -->
          {#if bulkMode}
          <label class="bulk-check-wrap" onclick={(e) => e.stopPropagation()} aria-label="Select {p.title}">
            <input type="checkbox" checked={selectedIds.has(p.id)} onchange={() => toggleSelect(p.id)} />
          </label>
          {/if}
                    </FluentCard>
        </div>
      {/each}
    </div>
  {/if}

  <!-- Admin Delete Confirmation Dialog -->
  <FluentDialog
    bind:open={showDeleteModal}
    title="Delete Project & Files"
    confirmText="Permanently Delete"
    confirmAppearance="danger"
    loading={isDeleting}
    onConfirm={confirmDeleteProject}
    onClose={() => { showDeleteModal = false; projectToDelete = null; deleteConfirmName = ''; }}
  >
    <div class="delete-dialog-body">
      <div class="delete-warning-banner">
        <div class="warning-title">
          <FluentIcons name="warning" size={16} color="#EF4444" />
          <span style="margin-left: 6px;">Irreversible action</span>
        </div>
        <p class="warning-text">
          This will permanently delete the project directory and <strong>all 5 subfolders and files</strong> on the shared drive. This action cannot be undone:
        </p>
        <ul class="subfolder-list">
          <li><code>01_BRIEF_ASSETS/</code></li>
          <li><code>02_SOURCE_FILES/</code></li>
          <li><code>03_COPYWRITING/</code></li>
          <li><code>04_WORK_IN_PROGRESS/</code></li>
          <li><code>05_DELIVERABLES/</code></li>
        </ul>
      </div>
      {#if projectToDelete}
        <div class="delete-target-info">
          <span class="target-label">Target Project:</span>
          <span class="target-val"><strong>{projectToDelete.jobId || projectToDelete.id}</strong> — {projectToDelete.title}</span>
        </div>
        <div class="delete-confirm-prompt" style="margin-top: 14px;">
          <label for="delete-project-name-input" class="confirm-input-label" style="display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; color: var(--text-primary);">
            To confirm, type the project name <code>{projectToDelete.title || projectToDelete.jobId || projectToDelete.id}</code> below:
          </label>
          <input
            id="delete-project-name-input"
            type="text"
            class="form-input"
            bind:value={deleteConfirmName}
            placeholder="Type project name here..."
            style="width: 100%; box-sizing: border-box; padding: 8px 12px; border: 1px solid var(--border-stroke); border-radius: 4px; background: var(--bg-card); color: var(--text-primary); font-size: 13px;"
          />
        </div>
      {/if}
    </div>
  </FluentDialog>
</div>

<style>
  .projects-container {
    display: flex;
    flex-direction: column;
    gap: 16px;
    width: 100%;
    flex: 1;
    min-height: 0;
  }

  .view-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    gap: 16px;
    flex-wrap: wrap;
  }

  .view-title {
    font-size: 24px;
    font-weight: 800;
    color: var(--text-primary, #111827);
    margin: 0;
  }

  .view-subtitle {
    font-size: 13px;
    color: var(--text-secondary, #6B7280);
    margin: 4px 0 0 0;
  }

  .view-controls-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  /* ─── View Mode Switcher Segmented Control ─── */
  .view-switcher-segmented {
    display: flex;
    align-items: center;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    padding: 3px;
    border-radius: 8px;
    gap: 2px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  }

  .save-default-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    color: var(--text-secondary, #6B7280);
    padding: 6px 12px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
    transition: all 0.15s ease;
  }

  .save-default-btn:hover {
    background: rgba(0, 120, 212, 0.08);
    border-color: var(--ss-azure);
    color: var(--ss-azure);
  }

  .default-view-badge {
    display: flex;
    align-items: center;
    gap: 5px;
    background: rgba(16, 124, 65, 0.08);
    border: 1px solid rgba(16, 124, 65, 0.25);
    color: #107C41;
    padding: 6px 12px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    user-select: none;
  }

  .seg-view-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    border: none;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #6B7280);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .seg-view-btn:hover {
    color: var(--text-primary, #111827);
    background: rgba(0, 0, 0, 0.04);
  }

  .seg-view-btn.is-active {
    background: var(--brand-accent);
    color: #FFFFFF;
    box-shadow: 0 1px 3px rgba(0, 120, 212, 0.3);
  }

  .more-views-wrapper {
    position: relative;
    display: inline-block;
  }

  .views-dropdown-menu {
    position: absolute;
    top: calc(100% + 6px);
    right: 0;
    z-index: 100;
    min-width: 170px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    border-radius: var(--radius-md, 8px);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
    padding: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .views-dropdown-menu .dropdown-item {
    display: flex;
    align-items: center;
    width: 100%;
    padding: 8px 12px;
    background: transparent;
    border: none;
    border-radius: 6px;
    font-size: 13px;
    color: var(--text-primary, #111827);
    cursor: pointer;
    text-align: left;
    transition: background var(--transition-fast);
  }

  .views-dropdown-menu .dropdown-item:hover {
    background: rgba(0, 0, 0, 0.05);
  }

  .views-dropdown-menu .dropdown-item.active {
    background: rgba(4, 51, 136, 0.1);
    color: var(--brand-accent);
    font-weight: 600;
  }

  /* ─── Cards Grid ─── */
  .projects-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
  }

  .project-card-wrapper {
    cursor: pointer;
  }

  .card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 10px;
  }

  .job-id-chip {
    font-family: monospace;
    font-weight: 800;
    font-size: 13px;
    color: var(--brand-accent);
  }

  .badges-row {
    display: flex;
    gap: 4px;
  }

  .project-card-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary, #111827);
    margin-bottom: 12px;
    line-height: 1.35;
    display: block;
    text-decoration: none;
    cursor: pointer;
    transition: color 0.15s ease;
  }

  .project-card-title:hover {
    color: var(--brand-accent);
    text-decoration: underline;
  }

  .meta-rows {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 12.5px;
    margin-bottom: 12px;
  }

  .meta-row {
    display: flex;
    justify-content: space-between;
  }

  .meta-key { color: var(--text-secondary, #6B7280); }
  .meta-val { font-weight: 600; color: var(--text-primary, #111827); }
  .is-overdue { color: #EF4444; font-weight: 800; }

  .card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    padding-top: 8px;
    border-top: 1px solid var(--surface-card-border, #E5E7EB);
  }

  .tag-pill {
    font-size: 11px;
    padding: 1px 6px;
    background: var(--surface-card-subtle, #F3F4F6);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    border-radius: 9999px;
    color: var(--text-secondary, #6B7280);
  }

  .tag-more {
    font-size: 10.5px;
    color: var(--text-tertiary, #9CA3AF);
  }

  .loading-box {
    text-align: center;
    padding: 60px 0;
    color: var(--text-secondary, #6B7280);
    font-size: 14px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .loading-spinner-orbit {
    width: 28px;
    height: 28px;
    border: 3px solid rgba(0, 120, 212, 0.2);
    border-top-color: var(--ss-azure);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .empty-box {
    text-align: center;
    padding: 60px 24px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    border-radius: 12px;
  }

  .empty-emoji {
    font-size: 40px;
    margin-bottom: 8px;
  }

  .empty-box h3 {
    margin: 0 0 4px 0;
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary, #111827);
  }

  .empty-box p {
    margin: 0;
    font-size: 13px;
    color: var(--text-secondary, #6B7280);
  }
  .empty-cta-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 16px;
    padding: 9px 18px;
    background: var(--brand-primary);
    color: #FFFFFF;
    border: none;
    border-radius: var(--radius-md);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background var(--transition-fast), transform var(--transition-fast);
    letter-spacing: 0.02em;
  }
  .empty-cta-btn:hover {
    background: var(--brand-secondary);
    transform: translateY(-1px);
  }
  .empty-clear-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 16px;
    padding: 8px 16px;
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #111827);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    border-radius: var(--radius-md);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast);
  }
  .empty-clear-btn:hover {
    background: rgba(0, 0, 0, 0.05);
    border-color: var(--brand-accent);
  }

  .job-id-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .card-quick-delete-btn {
    background: transparent;
    border: none;
    cursor: pointer;
    font-size: 12px;
    opacity: 0.5;
    padding: 2px 4px;
    border-radius: 4px;
    transition: opacity 0.15s, background 0.15s;
  }

  .card-quick-delete-btn:hover {
    opacity: 1;
    background: rgba(196, 43, 28, 0.12);
  }

  /* ═══ DELETE DIALOG ═════════════════════════════════════════════ */
  .delete-dialog-body {
    display: flex;
    flex-direction: column;
    gap: 14px;
    color: var(--text-primary, #111827);
  }
  .delete-warning-banner {
    background: rgba(196, 43, 28, 0.08);
    border: 1px solid #C42B1C;
    border-radius: 8px;
    padding: 14px;
  }
  .warning-title {
    font-weight: 700;
    font-size: 0.95rem;
    color: #C42B1C;
    margin-bottom: 6px;
  }
  .warning-text {
    font-size: 0.85rem;
    color: var(--text-primary, #111827);
    margin: 0 0 8px 0;
    line-height: 1.4;
  }
  .subfolder-list {
    margin: 0;
    padding-left: 18px;
    font-size: 0.8rem;
    color: var(--text-secondary, #6B7280);
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .subfolder-list code {
    font-family: monospace;
    color: #C42B1C;
    background: rgba(196, 43, 28, 0.06);
    padding: 1px 4px;
    border-radius: 3px;
  }
  .delete-target-info {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 12px;
    background: var(--surface-card-subtle, #F9FAFB);
    border: 1px solid var(--surface-card-border, #E5E7EB);
    border-radius: 8px;
    font-size: 0.88rem;
  }
  .target-label {
    font-weight: 600;
    color: var(--text-secondary, #6B7280);
  }
  .target-val {
    color: var(--text-primary, #111827);
  }

  /* Mobile Responsive Breakpoints (WCAG 2.5.8 touch targets >= 44x44px) */
  @media (max-width: 768px) {
    .view-header {
      flex-direction: column;
      align-items: stretch;
      gap: 12px;
    }
    .view-controls-wrap {
      width: 100%;
      justify-content: space-between;
    }
    .view-switcher-segmented {
      flex: 1;
      justify-content: space-around;
    }
    .seg-view-btn {
      flex: 1;
      justify-content: center;
      min-height: 44px;
      padding: 8px 10px;
    }
    .save-default-btn,
    .default-view-badge {
      min-height: 44px;
      box-sizing: border-box;
    }
    .filter-bar {
      flex-direction: column;
      align-items: stretch;
      gap: 10px;
    }
    .filter-group {
      width: 100%;
      flex-direction: column;
    }
    .filter-select,
    .search-input {
      width: 100%;
      min-height: 44px;
      font-size: 14px;
      box-sizing: border-box;
    }
  }

  @media (max-width: 480px) {
    .projects-container {
      padding: 12px 10px;
    }
    .view-title {
      font-size: 20px;
    }
    .projects-grid {
      grid-template-columns: 1fr;
      gap: 12px;
    }
    .project-card-wrapper {
      width: 100%;
    }
    .filter-select,
    .search-input {
      font-size: 16px; /* Prevents auto-zoom on iOS mobile */
    }
    .empty-cta-btn,
    .empty-clear-btn {
      min-height: 44px;
      width: 100%;
      justify-content: center;
    }
  }
</style>

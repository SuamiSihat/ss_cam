<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { StudioTask, StudioTaskStatus, ProjectPriority } from '$lib/types';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import TaskCreateModal from '$lib/components/features/TaskCreateModal.svelte';
  import TaskDetailDrawer from '$lib/components/features/TaskDetailDrawer.svelte';

  let tasks = $state<StudioTask[]>([]);
  let stats = $state<{
    total: number;
    byStatus: Record<string, number>;
    byPriority: Record<string, number>;
    byBrand?: Record<string, number>;
    overdue: number;
  }>({
    total: 0,
    byStatus: { backlog: 0, 'in-progress': 0, review: 0, done: 0, converted: 0 },
    byPriority: { urgent: 0, high: 0, medium: 0, low: 0 },
    overdue: 0
  });

  let isLoading = $state(true);
  let viewMode = $state<'kanban' | 'table'>('kanban');
  let brandFilter = $state('all');
  let priorityFilter = $state('all');
  let statusFilter = $state('all');
  let myTasksOnly = $state(false);
  let searchQuery = $state('');
  let isCreateModalOpen = $state(false);

  // Selected task for detail drawer inspection & editing
  let selectedTask = $state<StudioTask | null>(null);
  let isDetailDrawerOpen = $state(false);

  // Drag and drop state
  let draggedTaskId = $state<string | null>(null);
  let dragOverCol = $state<string | null>(null);

  let staffRoster = $state<any[]>([]);

  const columns: { id: StudioTaskStatus; label: string; icon: string; color: string }[] = [
    { id: 'backlog', label: 'Backlog / Intake', icon: '📋', color: '#64748B' },
    { id: 'in-progress', label: 'In Progress', icon: '⚡', color: '#0284C7' },
    { id: 'review', label: 'Review & QA', icon: '🔍', color: '#8B5CF6' },
    { id: 'done', label: 'Approved & Done', icon: '✅', color: '#10B981' }
  ];

  const brandChips = ['all', 'SS', 'SSH', 'SSC', 'SSW', 'SSE', 'SST'];
  const priorityChips = ['all', 'urgent', 'high', 'medium', 'low'];

  async function loadTasks() {
    isLoading = true;
    try {
      const res = await ApiClient.getStudioTasks();
      if (res && Array.isArray(res.tasks)) {
        tasks = res.tasks;
      }
      if (res && res.stats) {
        stats = res.stats;
      }
    } catch (err: any) {
      console.warn('[TasksView] loadTasks error:', err.message);
      appState.addToast(`Failed to load tasks: ${err.message}`, 'error');
    } finally {
      isLoading = false;
    }
  }

  async function loadRoster() {
    try {
      const res = await ApiClient.getStaffRoster();
      if (res && Array.isArray(res.roster)) {
        staffRoster = res.roster;
      }
    } catch (err) {
      console.debug('Failed to load roster:', err);
    }
  }

  onMount(() => {
    loadTasks();
    loadRoster();

    const onTasksChanged = () => {
      loadTasks();
    };

    window.addEventListener('task:created', onTasksChanged);
    window.addEventListener('task:updated', onTasksChanged);
    window.addEventListener('task:deleted', onTasksChanged);
    window.addEventListener('studio-task:created', onTasksChanged);
    window.addEventListener('studio-task:updated', onTasksChanged);
    window.addEventListener('studio-task:deleted', onTasksChanged);
    window.addEventListener('workspace:updated', onTasksChanged);

    return () => {
      window.removeEventListener('task:created', onTasksChanged);
      window.removeEventListener('task:updated', onTasksChanged);
      window.removeEventListener('task:deleted', onTasksChanged);
      window.removeEventListener('studio-task:created', onTasksChanged);
      window.removeEventListener('studio-task:updated', onTasksChanged);
      window.removeEventListener('studio-task:deleted', onTasksChanged);
      window.removeEventListener('workspace:updated', onTasksChanged);
    };
  });

  const currentUsername = $derived(
    (appState.currentUser?.username || appState.currentUser?.name || appState.currentUser?.staffId || '').toLowerCase()
  );

  const filteredTasks = $derived.by(() => {
    let list = tasks;

    if (brandFilter !== 'all') {
      list = list.filter(t => (t.brand || 'SS').toUpperCase() === brandFilter.toUpperCase());
    }

    if (priorityFilter !== 'all') {
      list = list.filter(t => (t.priority || 'medium').toLowerCase() === priorityFilter.toLowerCase());
    }

    if (statusFilter !== 'all') {
      list = list.filter(t => (t.status || 'backlog').toLowerCase() === statusFilter.toLowerCase());
    }

    if (myTasksOnly) {
      list = list.filter(t => {
        const u = currentUsername;
        return (
          (t.assignee || '').toLowerCase() === u ||
          (t.assigneeName || '').toLowerCase().includes(u)
        );
      });
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(t =>
        (t.title || '').toLowerCase().includes(q) ||
        (t.id || '').toLowerCase().includes(q) ||
        (t.description || '').toLowerCase().includes(q) ||
        (t.assigneeName || '').toLowerCase().includes(q) ||
        (t.tags || []).some(tag => tag.toLowerCase().includes(q))
      );
    }

    return list;
  });

  function getTasksByColumn(statusId: StudioTaskStatus) {
    if (statusId === 'done') {
      // Include converted tasks in done column or dedicated indicator
      return filteredTasks.filter(t => t.status === 'done' || t.status === 'converted');
    }
    return filteredTasks.filter(t => t.status === statusId);
  }

  function openTaskDetail(task: StudioTask) {
    selectedTask = task;
    isDetailDrawerOpen = true;
  }

  function handleTaskUpdated(updatedTask: StudioTask) {
    tasks = tasks.map(t => (t.id === updatedTask.id ? updatedTask : t));
    if (selectedTask?.id === updatedTask.id) {
      selectedTask = updatedTask;
    }
  }

  function handleTaskDeleted(deletedId: string) {
    tasks = tasks.filter(t => t.id !== deletedId);
    if (selectedTask?.id === deletedId) {
      selectedTask = null;
      isDetailDrawerOpen = false;
    }
  }

  function handleTaskCreated(newTask: StudioTask) {
    tasks = [newTask, ...tasks];
    loadTasks(); // refresh stats
  }

  // Drag and Drop
  function handleDragStart(e: DragEvent, task: StudioTask) {
    draggedTaskId = task.id;
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', task.id);
    }
  }

  function handleDragOver(e: DragEvent, colId: string) {
    e.preventDefault();
    if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
    dragOverCol = colId;
  }

  function handleDragLeave(colId: string) {
    if (dragOverCol === colId) dragOverCol = null;
  }

  async function handleDrop(e: DragEvent, newStatus: StudioTaskStatus) {
    e.preventDefault();
    dragOverCol = null;
    if (!draggedTaskId) return;

    const task = tasks.find(t => t.id === draggedTaskId);
    if (!task || task.status === newStatus) {
      draggedTaskId = null;
      return;
    }

    // Optimistic UI update
    const oldStatus = task.status;
    task.status = newStatus;

    try {
      const res = await ApiClient.updateStudioTask(task.id, { status: newStatus });
      handleTaskUpdated(res.task);
      appState.addToast(`Moved ${task.id} to ${newStatus}`, 'success');
    } catch (err: any) {
      task.status = oldStatus;
      appState.addToast(`Failed to update status: ${err.message}`, 'error');
    } finally {
      draggedTaskId = null;
    }
  }

  function isOverdue(dueDate?: string, status?: string): boolean {
    if (!dueDate || status === 'done' || status === 'converted') return false;
    try {
      const d = new Date(dueDate);
      const now = new Date();
      now.setHours(0, 0, 0, 0);
      return d < now;
    } catch {
      return false;
    }
  }

  function formatDueDate(iso?: string): string {
    if (!iso) return '';
    try {
      const d = new Date(iso);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    } catch {
      return iso;
    }
  }
</script>

<div class="tasks-page-container">
  <!-- ═══ HEADER ROW ════════════════════════════════════════════════ -->
  <header class="tasks-page-header">
    <div class="header-left">
      <h1 class="page-title">Tasks &amp; Workstream</h1>
      <p class="page-subtitle">
        Pre-production studio task management. Ideate, track, and provision concepts into NAS workspaces.
      </p>
    </div>

    <div class="header-right">
      <FluentButton appearance="primary" onclick={() => (isCreateModalOpen = true)}>
        <span class="btn-icon">＋</span> New Task
      </FluentButton>
    </div>
  </header>

  <!-- ═══ SUMMARY METRICS BAR ═══════════════════════════════════════ -->
  <div class="metrics-bar">
    <div class="metric-card">
      <span class="metric-label">TOTAL TASKS</span>
      <span class="metric-val">{tasks.length}</span>
    </div>

    <div class="metric-card">
      <span class="metric-label">📋 BACKLOG</span>
      <span class="metric-val">{tasks.filter(t => t.status === 'backlog').length}</span>
    </div>

    <div class="metric-card in-progress">
      <span class="metric-label">⚡ IN PROGRESS</span>
      <span class="metric-val">{tasks.filter(t => t.status === 'in-progress').length}</span>
    </div>

    <div class="metric-card review">
      <span class="metric-label">🔍 IN REVIEW</span>
      <span class="metric-val">{tasks.filter(t => t.status === 'review').length}</span>
    </div>

    <div class="metric-card done">
      <span class="metric-label">✅ COMPLETED</span>
      <span class="metric-val">{tasks.filter(t => t.status === 'done' || t.status === 'converted').length}</span>
    </div>

    <div class="metric-card vault">
      <span class="metric-label">🏛️ NAS PROVISIONED</span>
      <span class="metric-val">{tasks.filter(t => t.status === 'converted' || !!t.projectId).length}</span>
    </div>

    {#if tasks.some(t => isOverdue(t.dueDate, t.status))}
      <div class="metric-card overdue">
        <span class="metric-label">⚠️ OVERDUE</span>
        <span class="metric-val">{tasks.filter(t => isOverdue(t.dueDate, t.status)).length}</span>
      </div>
    {/if}
  </div>

  <!-- ═══ CONTROLS & FILTER BAR ═════════════════════════════════════ -->
  <div class="controls-bar">
    <!-- View Switcher -->
    <div class="segmented-control">
      <button
        class="seg-btn"
        class:active={viewMode === 'kanban'}
        onclick={() => (viewMode = 'kanban')}
        title="Kanban Board View"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <path d="M4 4h4v16H4V4zm6 0h4v10h-4V4zm6 0h4v16h-4V4z"/>
        </svg>
        <span>Board</span>
      </button>
      <button
        class="seg-btn"
        class:active={viewMode === 'table'}
        onclick={() => (viewMode = 'table')}
        title="Dense Table / List View"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
          <path d="M3 4h18v2H3V4zm0 7h18v2H3v-2zm0 7h18v2H3v-2z"/>
        </svg>
        <span>Table</span>
      </button>
    </div>

    <!-- Brand Filter Chips -->
    <div class="filter-chips-wrap">
      <span class="filter-group-lbl">Brand:</span>
      {#each brandChips as b}
        <button
          class="chip-btn"
          class:active={brandFilter === b}
          onclick={() => (brandFilter = b)}
        >
          {b === 'all' ? 'All' : b}
        </button>
      {/each}
    </div>

    <!-- Priority Filter -->
    <div class="filter-chips-wrap">
      <span class="filter-group-lbl">Priority:</span>
      {#each priorityChips as p}
        <button
          class="chip-btn"
          class:active={priorityFilter === p}
          onclick={() => (priorityFilter = p)}
        >
          {p === 'all' ? 'All' : p.charAt(0).toUpperCase() + p.slice(1)}
        </button>
      {/each}
    </div>

    <!-- My Tasks Toggle -->
    <button
      class="chip-btn my-tasks-toggle"
      class:active={myTasksOnly}
      onclick={() => (myTasksOnly = !myTasksOnly)}
    >
      👤 My Tasks Only
    </button>

    <!-- Search Input -->
    <div class="search-box">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" class="search-ico">
        <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
      </svg>
      <input
        type="text"
        placeholder="Search title, ID, concept, tags, assignee…"
        bind:value={searchQuery}
        class="search-input"
      />
      {#if searchQuery}
        <button class="clear-search-btn" onclick={() => (searchQuery = '')}>✕</button>
      {/if}
    </div>
  </div>

  <!-- ═══ MAIN WORKSPACE VIEW ═══════════════════════════════════════ -->
  {#if isLoading && tasks.length === 0}
    <div class="loading-state">
      <div class="spinner"></div>
      <span>Loading studio workstream tasks…</span>
    </div>
  {:else if filteredTasks.length === 0}
    <div class="empty-state">
      <div class="empty-icon">📝</div>
      <h3>No tasks found</h3>
      <p>
        {#if tasks.length === 0}
          Start organizing pre-production activities by creating your first studio task.
        {:else}
          No tasks match the selected filters. Reset filters or create a new task.
        {/if}
      </p>
      <FluentButton appearance="primary" onclick={() => (isCreateModalOpen = true)}>
        Create First Task
      </FluentButton>
    </div>
  {:else if viewMode === 'kanban'}
    <!-- ═══ KANBAN BOARD ═══ -->
    <div class="kanban-grid">
      {#each columns as col}
        {@const colTasks = getTasksByColumn(col.id)}
        <div
          class="kanban-column"
          class:drag-over={dragOverCol === col.id}
          ondragover={(e) => handleDragOver(e, col.id)}
          ondragleave={() => handleDragLeave(col.id)}
          ondrop={(e) => handleDrop(e, col.id)}
          role="region"
          aria-label="{col.label} column"
        >
          <!-- Column Header -->
          <div class="col-header" style="border-top-color: {col.color};">
            <div class="col-title-wrap">
              <span class="col-icon">{col.icon}</span>
              <span class="col-title">{col.label}</span>
              <span class="col-counter">{colTasks.length}</span>
            </div>
          </div>

          <!-- Cards Container -->
          <div class="col-cards">
            {#each colTasks as task (task.id)}
              <!-- svelte-ignore a11y_click_events_have_key_events -->
              <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
              <div
                class="task-card"
                class:is-overdue={isOverdue(task.dueDate, task.status)}
                class:is-converted={task.status === 'converted' || !!task.projectId}
                draggable="true"
                ondragstart={(e) => handleDragStart(e, task)}
                onclick={() => openTaskDetail(task)}
                onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openTaskDetail(task); } }}
                role="button"
                tabindex="0"
                aria-label="Inspect task {task.id}: {task.title}"
              >
                <!-- Card Top: ID, Brand, Priority, Action -->
                <div class="card-top-row">
                  <div class="card-top-left">
                    <span class="task-id-tag">{task.id}</span>
                    <FluentBadge type="brand" value={task.brand || 'SS'} />
                  </div>
                  <div class="card-top-right">
                    <FluentBadge type="priority" value={task.priority || 'medium'} />
                    <button
                      type="button"
                      class="card-open-btn"
                      onclick={(e) => { e.stopPropagation(); openTaskDetail(task); }}
                      title="Inspect task details"
                    >
                      Open ↗
                    </button>
                  </div>
                </div>

                <!-- Card Title -->
                <h4 class="card-title">{task.title}</h4>

                <!-- Description Snippet -->
                {#if task.description}
                  <p class="card-desc-snippet">{task.description}</p>
                {/if}

                <!-- Tags Row -->
                {#if task.tags && task.tags.length > 0}
                  <div class="card-tags-row">
                    {#each task.tags.slice(0, 3) as tag}
                      <span class="tag-pill">#{tag}</span>
                    {/each}
                    {#if task.tags.length > 3}
                      <span class="tag-more">+{task.tags.length - 3}</span>
                    {/if}
                  </div>
                {/if}

                <!-- Card Footer: Assignee, Due Date, Provisioned Badge -->
                <div class="card-footer-row">
                  <div class="assignee-wrap" title="Assigned to {task.assigneeName || task.assignee || 'Unassigned'}">
                    <div
                      class="assignee-avatar"
                      style="background: {task.assigneeAvatarColor || '#0078D4'};"
                    >
                      {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                    </div>
                    <span class="assignee-name">{task.assigneeName || task.assignee || 'Unassigned'}</span>
                  </div>

                  <div class="card-footer-right">
                    {#if task.status === 'converted' || task.projectId}
                      <span class="vault-indicator" title="Scaffolded on Synology NAS: {task.jobId || task.projectId}">
                        🏛️ {task.jobId || 'NAS'}
                      </span>
                    {/if}

                    {#if task.dueDate}
                      <span class="due-date-pill" class:overdue={isOverdue(task.dueDate, task.status)}>
                        📅 {formatDueDate(task.dueDate)}
                      </span>
                    {/if}
                  </div>
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>
  {:else}
    <!-- ═══ DENSE TABLE VIEW ═══ -->
    <div class="table-container">
      <table class="studio-table">
        <thead>
          <tr>
            <th style="width: 100px;">Task ID</th>
            <th>Title &amp; Concept</th>
            <th style="width: 80px;">Brand</th>
            <th style="width: 150px;">Assignee</th>
            <th style="width: 100px;">Priority</th>
            <th style="width: 120px;">Status</th>
            <th style="width: 110px;">Due Date</th>
            <th style="width: 130px;">NAS Vault</th>
            <th style="width: 80px; text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredTasks as task (task.id)}
            <tr
              class="table-row"
              onclick={() => openTaskDetail(task)}
              onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openTaskDetail(task); } }}
              role="button"
              tabindex="0"
              aria-label="Inspect task {task.id}: {task.title}"
            >
              <td class="id-cell">
                <span class="task-id-tag">{task.id}</span>
              </td>
              <td class="title-cell">
                <div class="tbl-title">{task.title}</div>
                {#if task.description}
                  <div class="tbl-snippet">{task.description.substring(0, 60)}…</div>
                {/if}
              </td>
              <td>
                <FluentBadge type="brand" value={task.brand || 'SS'} />
              </td>
              <td>
                <div class="tbl-assignee">
                  <div
                    class="assignee-avatar sm"
                    style="background: {task.assigneeAvatarColor || '#0078D4'};"
                  >
                    {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                  </div>
                  <span>{task.assigneeName || task.assignee || 'Unassigned'}</span>
                </div>
              </td>
              <td>
                <FluentBadge type="priority" value={task.priority || 'medium'} />
              </td>
              <td>
                <span class="status-cell-pill status-{task.status}">
                  {task.status}
                </span>
              </td>
              <td class="date-cell">
                {#if task.dueDate}
                  <span class:overdue-text={isOverdue(task.dueDate, task.status)}>
                    {formatDueDate(task.dueDate)}
                  </span>
                {:else}
                  <span class="empty-val">—</span>
                {/if}
              </td>
              <td>
                {#if task.status === 'converted' || task.projectId}
                  <span class="vault-cell-badge">
                    🏛️ {task.jobId || 'NAS'}
                  </span>
                {:else}
                  <span class="pre-prod-cell-badge">Pre-Production</span>
                {/if}
              </td>
              <td style="text-align: right;">
                <button
                  type="button"
                  class="tbl-open-btn"
                  onclick={(e) => { e.stopPropagation(); openTaskDetail(task); }}
                >
                  Inspect ↗
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<!-- Task Create Modal -->
<TaskCreateModal
  bind:isOpen={isCreateModalOpen}
  onClose={() => (isCreateModalOpen = false)}
  onCreated={handleTaskCreated}
/>

<!-- Task Detail Drawer -->
<TaskDetailDrawer
  bind:open={isDetailDrawerOpen}
  task={selectedTask}
  {staffRoster}
  onClose={() => { isDetailDrawerOpen = false; selectedTask = null; }}
  onUpdated={handleTaskUpdated}
  onDeleted={handleTaskDeleted}
/>

<style>
  .tasks-page-container {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 24px;
    max-width: 1800px;
    margin: 0 auto;
    width: 100%;
    min-height: calc(100vh - 60px);
  }

  /* ═══ HEADER ═══════════════════════════════════════════════════ */
  .tasks-page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 12px;
  }

  .page-title {
    font-size: 24px;
    font-weight: 800;
    color: var(--text-primary);
    margin: 0;
    letter-spacing: -0.3px;
  }

  .page-subtitle {
    font-size: 13px;
    color: var(--text-secondary);
    margin: 4px 0 0 0;
  }

  .btn-icon {
    font-weight: 800;
    margin-right: 4px;
  }

  /* ═══ METRICS BAR ═══════════════════════════════════════════════ */
  .metrics-bar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: 10px;
  }

  .metric-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 8px);
    padding: 10px 14px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    box-shadow: var(--shadow-sm);
    transition: all 0.15s ease;
  }
  .metric-card:hover {
    border-color: var(--brand-accent);
    transform: translateY(-1px);
    box-shadow: var(--shadow-md);
  }

  .metric-label {
    font-size: 10.5px;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: var(--text-tertiary);
  }

  .metric-val {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
    font-family: var(--font-mono, monospace);
  }

  .metric-card.in-progress .metric-val { color: var(--color-info, #0284C7); }
  .metric-card.review .metric-val { color: var(--color-purple, #9333EA); }
  .metric-card.done .metric-val { color: var(--color-success, #059669); }
  .metric-card.vault .metric-val { color: var(--color-warning, #D97706); }
  .metric-card.overdue .metric-val { color: var(--color-danger, #DC2626); }

  /* ═══ CONTROLS & FILTERS ════════════════════════════════════════ */
  .controls-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 8px);
    padding: 10px 14px;
    box-shadow: var(--shadow-sm);
  }

  .segmented-control {
    display: flex;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-sm, 6px);
    padding: 2px;
  }

  .seg-btn {
    border: none;
    background: none;
    color: var(--text-secondary);
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 11px;
    font-size: 12px;
    font-weight: 600;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .seg-btn:hover {
    color: var(--text-primary);
  }
  .seg-btn.active {
    background: var(--brand-primary);
    color: #FFFFFF;
    box-shadow: var(--shadow-sm);
  }

  .filter-chips-wrap {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: wrap;
  }

  .filter-group-lbl {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-tertiary);
    margin-right: 2px;
  }

  .chip-btn {
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 11.5px;
    font-weight: 600;
    padding: 4px 9px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .chip-btn:hover {
    background: var(--surface-card-hover);
    color: var(--text-primary);
  }
  .chip-btn.active {
    background: var(--brand-primary);
    border-color: var(--brand-primary);
    color: #FFFFFF;
    box-shadow: var(--shadow-sm);
  }

  .my-tasks-toggle.active {
    background: var(--color-success, #10B981);
    border-color: var(--color-success, #10B981);
    color: #FFFFFF;
    box-shadow: var(--shadow-sm);
  }

  .search-box {
    margin-left: auto;
    position: relative;
    display: flex;
    align-items: center;
    min-width: 240px;
  }

  .search-ico {
    position: absolute;
    left: 10px;
    color: var(--text-tertiary);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    min-height: 34px;
    padding: 6px 28px 6px 30px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-primary);
    font-size: 12.5px;
    transition: all 0.15s ease;
  }
  .search-input:focus {
    outline: none;
    border-color: var(--brand-accent);
    background: var(--surface-card);
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.2);
  }

  .clear-search-btn {
    position: absolute;
    right: 8px;
    border: none;
    background: none;
    color: var(--text-tertiary);
    cursor: pointer;
    font-size: 11px;
    padding: 2px 4px;
  }

  /* ═══ KANBAN GRID ═══════════════════════════════════════════════ */
  .kanban-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    align-items: start;
  }

  @media (max-width: 1200px) {
    .kanban-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 768px) {
    .kanban-grid {
      grid-template-columns: 1fr;
    }
  }

  .kanban-column {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 10px;
    display: flex;
    flex-direction: column;
    min-height: 600px;
    transition: all 0.15s ease;
    box-shadow: var(--shadow-sm);
  }
  .kanban-column.drag-over {
    border-color: var(--brand-accent);
    background: var(--brand-tint);
  }

  .col-header {
    border-top: 3px solid #64748B;
    border-top-left-radius: 9px;
    border-top-right-radius: 9px;
    padding: 12px 14px;
    background: var(--surface-card);
    border-bottom: 1px solid var(--surface-card-border);
  }

  .col-title-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .col-icon { font-size: 14px; }
  .col-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .col-counter {
    margin-left: auto;
    font-size: 11px;
    font-weight: 800;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    color: var(--text-secondary);
    padding: 2px 7px;
    border-radius: 9999px;
  }

  .col-cards {
    padding: 10px 12px 24px 10px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    flex: 1;
    overflow-y: auto;
  }

  /* ═══ TASK CARD ═════════════════════════════════════════════════ */
  .task-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    cursor: pointer;
    transition: all 0.15s ease;
    user-select: none;
    box-shadow: var(--shadow-sm);
  }
  .task-card:hover {
    border-color: var(--brand-accent);
    transform: translateY(-2px);
    box-shadow: var(--shadow-md);
  }
  .task-card:focus {
    outline: none;
    border-color: var(--brand-primary);
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.25);
  }

  .task-card.is-overdue {
    border-left: 3px solid #EF4444;
  }
  .task-card.is-converted {
    border-left: 3px solid #F59E0B;
  }

  .card-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .card-top-left {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .card-top-right {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .card-open-btn {
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.15s ease;
    line-height: 1.4;
  }
  .card-open-btn:hover {
    background: var(--brand-primary);
    border-color: var(--brand-primary);
    color: #FFFFFF;
  }

  .task-id-tag {
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    font-weight: 800;
    color: var(--brand-primary);
    background: var(--brand-tint);
    border: 1px solid rgba(4, 51, 136, 0.15);
    padding: 2px 6px;
    border-radius: 4px;
  }

  .card-title {
    font-size: 13.5px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
    line-height: 1.4;
  }

  .card-desc-snippet {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .card-tags-row {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }

  .tag-pill {
    font-size: 10px;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    padding: 2px 6px;
    border-radius: 4px;
  }
  .tag-more {
    font-size: 10px;
    color: var(--text-tertiary);
  }

  .card-footer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 6px;
    border-top: 1px solid var(--surface-card-border);
    font-size: 11px;
  }

  .assignee-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .assignee-avatar {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 9px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .assignee-avatar.sm {
    width: 20px;
    height: 20px;
    font-size: 8.5px;
  }

  .assignee-name {
    color: var(--text-secondary);
    font-weight: 600;
    max-width: 100px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .card-footer-right {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .vault-indicator {
    font-size: 10.5px;
    font-weight: 700;
    color: #B45309;
    background: #FEF3C7;
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid #FCD34D;
  }

  .due-date-pill {
    font-size: 10.5px;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    padding: 2px 6px;
    border-radius: 4px;
  }
  .due-date-pill.overdue {
    color: var(--color-danger, #EF4444);
    background: var(--color-danger-bg, #FEF2F2);
    border: 1px solid var(--color-danger-border, #FECACA);
  }

  /* ═══ DENSE TABLE VIEW ══════════════════════════════════════════ */
  .table-container {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    overflow-x: auto;
    box-shadow: var(--shadow-sm);
  }

  .studio-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    text-align: left;
  }

  .studio-table thead {
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
  }

  .studio-table th {
    padding: 10px 14px;
    font-size: 11px;
    font-weight: 800;
    color: var(--text-secondary);
    letter-spacing: 0.4px;
  }

  .table-row {
    border-bottom: 1px solid var(--surface-card-border);
    cursor: pointer;
    transition: all 0.12s ease;
  }
  .table-row:hover {
    background: var(--surface-card-hover);
  }

  .studio-table td {
    padding: 10px 14px;
    vertical-align: middle;
  }

  .tbl-title {
    font-weight: 700;
    color: var(--text-primary);
  }
  .tbl-snippet {
    font-size: 11.5px;
    color: var(--text-secondary);
    margin-top: 2px;
  }

  .tbl-assignee {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-secondary);
  }

  .status-cell-pill {
    display: inline-block;
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 9999px;
    text-transform: capitalize;
  }
  .status-cell-pill.status-backlog {
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    border: 1px solid var(--surface-card-border);
  }
  .status-cell-pill.status-in-progress {
    background: var(--color-info-bg, #EFF6FF);
    color: var(--color-info, #0284C7);
    border: 1px solid var(--color-info-border, #BFDBFE);
  }
  .status-cell-pill.status-review {
    background: var(--color-purple-bg, #F5F3FF);
    color: var(--color-purple, #9333EA);
    border: 1px solid var(--color-purple-border, #DDD6FE);
  }
  .status-cell-pill.status-done {
    background: var(--color-success-bg, #ECFDF5);
    color: var(--color-success, #059669);
    border: 1px solid var(--color-success-border, #A7F3D0);
  }
  .status-cell-pill.status-converted {
    background: var(--color-warning-bg, #FFFBEB);
    color: var(--color-warning, #D97706);
    border: 1px solid var(--color-warning-border, #FDE68A);
  }

  .overdue-text {
    color: var(--color-danger, #DC2626);
    font-weight: 700;
  }

  .vault-cell-badge {
    font-size: 11px;
    font-weight: 700;
    color: #B45309;
    background: #FEF3C7;
    padding: 3px 8px;
    border-radius: 6px;
    border: 1px solid #FCD34D;
  }

  .pre-prod-cell-badge {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    padding: 3px 8px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
  }

  .tbl-open-btn {
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 11.5px;
    font-weight: 700;
    padding: 4px 9px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.12s ease;
  }
  .tbl-open-btn:hover {
    background: var(--brand-primary);
    border-color: var(--brand-primary);
    color: #FFFFFF;
  }

  /* ═══ EMPTY & LOADING STATES ════════════════════════════════════ */
  .empty-state {
    padding: 60px 20px;
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    background: var(--surface-card);
    border: 1px dashed var(--surface-card-border);
    border-radius: 12px;
  }
  .empty-icon { font-size: 40px; }
  .empty-state h3 {
    margin: 0;
    font-size: 17px;
    color: var(--text-primary);
  }
  .empty-state p {
    margin: 0;
    font-size: 13px;
    color: var(--text-secondary);
    max-width: 440px;
  }

  .loading-state {
    padding: 60px 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 14px;
    color: var(--text-secondary);
  }

  .spinner {
    width: 28px;
    height: 28px;
    border: 3px solid var(--surface-card-border);
    border-top-color: var(--brand-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>

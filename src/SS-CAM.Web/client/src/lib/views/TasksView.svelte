<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import { ApiClient } from '$lib/services/api';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import TaskCreateModal from '$lib/components/features/TaskCreateModal.svelte';

  interface TaskItem {
    id: string;
    name: string;
    role: 'copywriter' | 'designer' | 'manager' | 'reviewer';
    assignee: string;
    assigneeName: string;
    status: 'draft' | 'in-progress' | 'review' | 'done';
    weight: number;
    channel: string;
    specs?: string;
    notes?: string;
    deliverableId?: string;
    linkedFile?: string;
    createdAt?: string;
    updatedAt?: string;

    projectId: string;
    projectJobId: string;
    projectTitle: string;
    projectBrand: string;
    projectStatus: string;
    projectPriority: string;
    projectDeadline?: string;
    projectDesigner?: string;
    projectManager?: string;
    isOverdue?: boolean;
    daysRemaining?: number;
  }

  let tasks = $state<TaskItem[]>([]);
  let stats = $state<{ total: number; byStatus: any; byRole: any; overdue: number }>({
    total: 0,
    byStatus: { draft: 0, 'in-progress': 0, review: 0, done: 0 },
    byRole: { copywriter: 0, designer: 0, manager: 0 },
    overdue: 0
  });

  let isLoading = $state<boolean>(true);
  let viewMode = $state<'kanban' | 'table'>('kanban');
  let roleFilter = $state<string>('all');
  let myTasksOnly = $state<boolean>(false);
  let searchQuery = $state<string>('');
  let isCreateModalOpen = $state<boolean>(false);
  let draggedTaskId = $state<string | null>(null);
  let dragOverCol = $state<string | null>(null);

  const columns = [
    { id: 'draft', label: 'Intake / Backlog', icon: '📋', color: '#64748B' },
    { id: 'in-progress', label: 'In Progress', icon: '⚡', color: '#0284C7' },
    { id: 'review', label: 'Review & QA', icon: '🔍', color: '#8B5CF6' },
    { id: 'done', label: 'Approved & Done', icon: '✅', color: '#10B981' }
  ];

  async function loadTasks() {
    isLoading = true;
    try {
      const res = await ApiClient.getTasks();
      if (res && Array.isArray(res.tasks)) {
        tasks = res.tasks;
        if (res.stats) stats = res.stats;
      }
    } catch (err: any) {
      appState.addToast(`Failed to load tasks: ${err.message}`, 'error');
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    loadTasks();
    if (!projectStore.projects || projectStore.projects.length === 0) {
      projectStore.loadProjects();
    }

    // Real-time listener
    const closeSse = ApiClient.initEventStream((event, data) => {
      if (event === 'task:created' || event === 'task:updated' || event === 'task:deleted' || event === 'project:updated') {
        loadTasks();
      }
    });

    return () => {
      if (typeof closeSse === 'function') closeSse();
    };
  });

  const currentUsername = $derived(
    (appState.currentUser?.username || appState.currentUser?.name || '').toLowerCase()
  );

  const filteredTasks = $derived.by(() => {
    let list = tasks;

    if (roleFilter !== 'all') {
      list = list.filter(t => t.role === roleFilter);
    }

    if (myTasksOnly) {
      list = list.filter(t => 
        (t.assignee || '').toLowerCase() === currentUsername ||
        (t.assigneeName || '').toLowerCase().includes(currentUsername)
      );
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(t =>
        t.name.toLowerCase().includes(q) ||
        t.projectId.toLowerCase().includes(q) ||
        t.projectTitle.toLowerCase().includes(q) ||
        t.assigneeName.toLowerCase().includes(q) ||
        t.channel.toLowerCase().includes(q)
      );
    }

    return list;
  });

  function getTasksByColumn(statusId: string) {
    return filteredTasks.filter(t => t.status === statusId);
  }

  // Drag and Drop
  function handleDragStart(e: DragEvent, task: TaskItem) {
    draggedTaskId = task.id;
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', `${task.projectId}:::${task.id}`);
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

  async function handleDrop(e: DragEvent, newStatus: string) {
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
    task.status = newStatus as any;

    try {
      await ApiClient.updateTask(task.projectId, task.id, { status: newStatus });
      appState.addToast(`Moved "${task.name}" to ${newStatus}`, 'success');
    } catch (err: any) {
      task.status = oldStatus;
      appState.addToast(`Failed to update status: ${err.message}`, 'error');
    } finally {
      draggedTaskId = null;
    }
  }

  async function cycleStatus(task: TaskItem) {
    const cycle = ['draft', 'in-progress', 'review', 'done'];
    const nextIdx = (cycle.indexOf(task.status) + 1) % cycle.length;
    const nextStatus = cycle[nextIdx];
    const oldStatus = task.status;
    task.status = nextStatus as any;

    try {
      await ApiClient.updateTask(task.projectId, task.id, { status: nextStatus });
    } catch (err: any) {
      task.status = oldStatus;
      appState.addToast(`Error updating status: ${err.message}`, 'error');
    }
  }

  function openInCopyStudio(task: TaskItem) {
    // Select project and navigate to copy-studio
    projectStore.selectProject(task.projectId);
    appState.navigate('copy-studio');
  }

  function openProjectDetail(task: TaskItem) {
    projectStore.selectProject(task.projectId);
    appState.navigate('project-detail', { id: task.projectId });
  }

  async function deleteTask(task: TaskItem) {
    if (!confirm(`Delete task "${task.name}" from project ${task.projectId}?`)) return;
    try {
      await ApiClient.deleteTask(task.projectId, task.id);
      tasks = tasks.filter(t => t.id !== task.id);
      appState.addToast(`Task deleted.`, 'info');
    } catch (err: any) {
      appState.addToast(`Failed to delete: ${err.message}`, 'error');
    }
  }
</script>

<div class="tasks-workspace">
  <!-- ═══ HEADER BAR ════════════════════════════════════════════════ -->
  <header class="tasks-header">
    <div class="header-titles">
      <div class="title-with-pill">
        <h1 class="page-title">Tasks &amp; Creative Workstream</h1>
        <span class="engine-badge">CLICKUP ENGINE &bull; DUAL-TRACK</span>
      </div>
      <p class="page-subtitle">
        Collaborative task management for Copywriters, Designers &amp; Managers &mdash; unified by Designer Project IDs.
      </p>
    </div>

    <div class="header-actions">
      <FluentButton appearance="subtle" onclick={loadTasks} disabled={isLoading}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" class:spinning={isLoading} style="margin-right:6px;">
          <path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z"/>
        </svg>
        Refresh
      </FluentButton>

      <FluentButton appearance="primary" onclick={() => (isCreateModalOpen = true)}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" style="margin-right:6px;">
          <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
        </svg>
        New Task
      </FluentButton>
    </div>
  </header>

  <!-- ═══ TOOLBAR: VIEWS & FILTERS ═════════════════════════════════ -->
  <div class="tasks-toolbar">
    <!-- View Mode Switcher -->
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
        <span>List</span>
      </button>
    </div>

    <!-- Quick Role Filter Chips -->
    <div class="filter-chips">
      <button
        class="chip-btn"
        class:active={roleFilter === 'all'}
        onclick={() => (roleFilter = 'all')}
      >
        All Roles ({tasks.length})
      </button>
      <button
        class="chip-btn"
        class:active={roleFilter === 'copywriter'}
        onclick={() => (roleFilter = 'copywriter')}
      >
        ✍️ Copywriters ({stats.byRole.copywriter || 0})
      </button>
      <button
        class="chip-btn"
        class:active={roleFilter === 'designer'}
        onclick={() => (roleFilter = 'designer')}
      >
        🎨 Designers ({stats.byRole.designer || 0})
      </button>
      <button
        class="chip-btn my-tasks-toggle"
        class:active={myTasksOnly}
        onclick={() => (myTasksOnly = !myTasksOnly)}
      >
        👤 My Tasks Only
      </button>
    </div>

    <!-- Search Input -->
    <div class="search-box">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" class="search-ico">
        <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
      </svg>
      <input
        type="text"
        placeholder="Filter by title, Project ID, or assignee…"
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
      <span>Loading collaborative tasks…</span>
    </div>
  {:else if filteredTasks.length === 0}
    <div class="empty-state">
      <div class="empty-icon">📝</div>
      <h3>No tasks match your filter</h3>
      <p>Create a new task linked to any creative project or reset filters to see all tasks.</p>
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

          <!-- Cards Scroll Container -->
          <div class="col-cards">
            {#each colTasks as task (task.id)}
              <div
                class="task-card"
                class:is-overdue={task.isOverdue && task.status !== 'done'}
                draggable="true"
                ondragstart={(e) => handleDragStart(e, task)}
                role="listitem"
              >
                <!-- Card Header: Project Badge & Role -->
                <div class="card-top-row">
                  <button
                    class="project-id-pill"
                    onclick={() => openProjectDetail(task)}
                    title="View project: {task.projectTitle} [{task.projectId}]"
                  >
                    🎯 {task.projectJobId || task.projectId}
                  </button>

                  <span class="role-badge {task.role}">
                    {task.role === 'copywriter' ? '✍️ Copy' : task.role === 'designer' ? '🎨 Design' : '📋 Task'}
                  </span>
                </div>

                <!-- Task Title -->
                <div class="card-title-row">
                  <button class="task-title-btn" onclick={() => cycleStatus(task)} title="Click to advance status">
                    {task.name}
                  </button>
                </div>

                <!-- Channel & Weight -->
                <div class="card-meta-row">
                  {#if task.channel}
                    <span class="channel-pill">{task.channel.replace('_', ' ')}</span>
                  {/if}
                  <span class="weight-pill">{task.weight || 1} pts</span>
                  {#if task.isOverdue && task.status !== 'done'}
                    <span class="overdue-pill">⚠️ Overdue</span>
                  {/if}
                </div>

                <!-- Project Title Reference -->
                <div class="card-project-context" title={task.projectTitle}>
                  📁 {task.projectTitle}
                </div>

                <!-- Footer: Assignee & Action Launcher -->
                <div class="card-footer-row">
                  <div class="assignee-wrap" title="Assigned to {task.assigneeName || task.assignee}">
                    <div class="assignee-avatar">
                      {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                    </div>
                    <span class="assignee-name">{task.assigneeName || task.assignee}</span>
                  </div>

                  <!-- Context Action Button -->
                  <div class="card-actions">
                    {#if task.role === 'copywriter'}
                      <button
                        class="btn-studio-jump copy"
                        onclick={() => openInCopyStudio(task)}
                        title="Jump directly to Copy Studio for this project"
                      >
                        ✍️ Copy Studio
                      </button>
                    {:else}
                      <button
                        class="btn-studio-jump view"
                        onclick={() => openProjectDetail(task)}
                        title="View project assets & deliverables"
                      >
                        🎨 View
                      </button>
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
    <!-- ═══ CLICKUP DENSE TABLE / LIST VIEW ═══ -->
    <div class="table-container">
      <table class="clickup-table">
        <thead>
          <tr>
            <th style="width: 140px;">Status</th>
            <th>Task Name</th>
            <th style="width: 180px;">Linked Project ID</th>
            <th style="width: 110px;">Role</th>
            <th style="width: 140px;">Assignee</th>
            <th style="width: 90px;">Weight</th>
            <th style="width: 120px;">Deadline</th>
            <th style="width: 130px; text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredTasks as task (task.id)}
            <tr class="table-row">
              <!-- Status Cell -->
              <td>
                <button
                  class="status-pill status-{task.status}"
                  onclick={() => cycleStatus(task)}
                  title="Click to cycle status"
                >
                  <span class="status-dot"></span>
                  <span>{task.status.replace('-', ' ')}</span>
                </button>
              </td>

              <!-- Name -->
              <td class="task-name-cell">
                <span class="table-task-name">{task.name}</span>
                {#if task.notes}
                  <span class="table-task-notes" title={task.notes}>{task.notes}</span>
                {/if}
              </td>

              <!-- Project ID -->
              <td>
                <button
                  class="project-id-pill"
                  onclick={() => openProjectDetail(task)}
                  title="[{task.projectId}] {task.projectTitle}"
                >
                  🎯 {task.projectJobId || task.projectId}
                </button>
              </td>

              <!-- Role -->
              <td>
                <span class="role-badge {task.role}">
                  {task.role === 'copywriter' ? '✍️ Copy' : task.role === 'designer' ? '🎨 Design' : '📋 Task'}
                </span>
              </td>

              <!-- Assignee -->
              <td>
                <div class="assignee-wrap">
                  <div class="assignee-avatar">
                    {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                  </div>
                  <span class="assignee-name">{task.assigneeName || task.assignee}</span>
                </div>
              </td>

              <!-- Weight -->
              <td>
                <span class="weight-pill">{task.weight || 1} pts</span>
              </td>

              <!-- Deadline -->
              <td>
                {#if task.projectDeadline}
                  <span class="deadline-text" class:overdue={task.isOverdue && task.status !== 'done'}>
                    {task.projectDeadline}
                  </span>
                {:else}
                  <span class="deadline-text muted">&mdash;</span>
                {/if}
              </td>

              <!-- Action -->
              <td style="text-align: right;">
                <div class="table-action-group">
                  {#if task.role === 'copywriter'}
                    <button
                      class="btn-studio-jump copy"
                      onclick={() => openInCopyStudio(task)}
                      title="Open in Copywriting Studio"
                    >
                      ✍️ Copy
                    </button>
                  {:else}
                    <button
                      class="btn-studio-jump view"
                      onclick={() => openProjectDetail(task)}
                      title="View Project"
                    >
                      🎨 View
                    </button>
                  {/if}

                  <button
                    class="btn-row-delete"
                    onclick={() => deleteTask(task)}
                    title="Delete task"
                  >
                    ✕
                  </button>
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<!-- Modal -->
<TaskCreateModal
  isOpen={isCreateModalOpen}
  onClose={() => (isCreateModalOpen = false)}
  onCreated={() => loadTasks()}
/>

<style>
  .tasks-workspace {
    display: flex;
    flex-direction: column;
    gap: 16px;
    height: 100%;
    padding: 20px;
    box-sizing: border-box;
    overflow-y: auto;
  }

  .tasks-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    flex-wrap: wrap;
  }

  .header-titles {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .title-with-pill {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .page-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text-primary, #ffffff);
    margin: 0;
  }

  .engine-badge {
    font-size: 0.65rem;
    font-weight: 800;
    letter-spacing: 0.08em;
    padding: 3px 8px;
    background: rgba(59, 130, 246, 0.15);
    color: #60a5fa;
    border: 1px solid rgba(59, 130, 246, 0.3);
    border-radius: 9999px;
  }

  .page-subtitle {
    font-size: 0.85rem;
    color: var(--text-muted, #94a3b8);
    margin: 0;
  }

  .header-actions {
    display: flex;
    gap: 10px;
  }

  /* ═══ TOOLBAR ═══ */
  .tasks-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
    background: var(--card-bg, rgba(30, 41, 59, 0.6));
    border: 1px solid var(--border-color, rgba(255, 255, 255, 0.08));
    padding: 8px 12px;
    border-radius: 10px;
  }

  .segmented-control {
    display: flex;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
  }

  .seg-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    background: transparent;
    border: none;
    color: var(--text-muted, #94a3b8);
    font-size: 0.8rem;
    font-weight: 600;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.15s;
  }

  .seg-btn.active {
    background: #2563eb;
    color: #ffffff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
  }

  .filter-chips {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }

  .chip-btn {
    padding: 5px 10px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--text-muted, #cbd5e1);
    font-size: 0.78rem;
    font-weight: 500;
    border-radius: 9999px;
    cursor: pointer;
    transition: all 0.15s;
  }

  .chip-btn:hover {
    background: rgba(255, 255, 255, 0.1);
  }

  .chip-btn.active {
    background: rgba(59, 130, 246, 0.2);
    border-color: #3b82f6;
    color: #93c5fd;
    font-weight: 600;
  }

  .chip-btn.my-tasks-toggle.active {
    background: rgba(16, 185, 129, 0.2);
    border-color: #10b981;
    color: #6ee7b7;
  }

  .search-box {
    display: flex;
    align-items: center;
    position: relative;
    min-width: 220px;
  }

  .search-ico {
    position: absolute;
    left: 10px;
    color: var(--text-muted, #94a3b8);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    padding: 6px 28px 6px 30px;
    font-size: 0.8rem;
    color: #ffffff;
  }

  .search-input:focus {
    outline: none;
    border-color: #3b82f6;
  }

  .clear-search-btn {
    position: absolute;
    right: 8px;
    background: transparent;
    border: none;
    color: #94a3b8;
    cursor: pointer;
    font-size: 0.75rem;
  }

  /* ═══ KANBAN GRID ═══ */
  .kanban-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    flex: 1;
    min-height: 480px;
  }

  @media (max-width: 1100px) {
    .kanban-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 650px) {
    .kanban-grid {
      grid-template-columns: 1fr;
    }
  }

  .kanban-column {
    display: flex;
    flex-direction: column;
    background: var(--card-bg, rgba(30, 41, 59, 0.4));
    border: 1px solid var(--border-color, rgba(255, 255, 255, 0.06));
    border-radius: 10px;
    overflow: hidden;
    transition: background 0.15s, border-color 0.15s;
  }

  .kanban-column.drag-over {
    background: rgba(59, 130, 246, 0.08);
    border-color: #3b82f6;
  }

  .col-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 14px;
    background: rgba(0, 0, 0, 0.2);
    border-top: 3px solid #64748b;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  .col-title-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .col-title {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--text-primary, #ffffff);
  }

  .col-counter {
    font-size: 0.7rem;
    font-weight: 700;
    background: rgba(255, 255, 255, 0.1);
    color: #cbd5e1;
    padding: 2px 6px;
    border-radius: 9999px;
  }

  .col-cards {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 10px;
    overflow-y: auto;
    flex: 1;
  }

  /* ═══ TASK CARD ═══ */
  .task-card {
    background: var(--card-surface, #1e293b);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    cursor: grab;
    transition: transform 0.15s, box-shadow 0.15s, border-color 0.15s;
  }

  .task-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
    border-color: rgba(255, 255, 255, 0.2);
  }

  .task-card.is-overdue {
    border-left: 3px solid #ef4444;
  }

  .card-top-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 6px;
  }

  .project-id-pill {
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 0.72rem;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 600;
    color: #93c5fd;
    cursor: pointer;
    text-align: left;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 140px;
  }

  .project-id-pill:hover {
    background: rgba(59, 130, 246, 0.2);
    border-color: #3b82f6;
  }

  .role-badge {
    font-size: 0.68rem;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 4px;
  }

  .role-badge.copywriter {
    background: rgba(139, 92, 246, 0.2);
    color: #c4b5fd;
    border: 1px solid rgba(139, 92, 246, 0.4);
  }

  .role-badge.designer {
    background: rgba(16, 185, 129, 0.2);
    color: #6ee7b7;
    border: 1px solid rgba(16, 185, 129, 0.4);
  }

  .role-badge.manager {
    background: rgba(245, 158, 11, 0.2);
    color: #fcd34d;
    border: 1px solid rgba(245, 158, 11, 0.4);
  }

  .task-title-btn {
    background: transparent;
    border: none;
    color: #ffffff;
    font-size: 0.88rem;
    font-weight: 600;
    line-height: 1.35;
    text-align: left;
    padding: 0;
    cursor: pointer;
  }

  .task-title-btn:hover {
    color: #60a5fa;
  }

  .card-meta-row {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
  }

  .channel-pill {
    font-size: 0.68rem;
    text-transform: capitalize;
    background: rgba(255, 255, 255, 0.05);
    color: #94a3b8;
    padding: 2px 6px;
    border-radius: 4px;
  }

  .weight-pill {
    font-size: 0.68rem;
    background: rgba(255, 255, 255, 0.05);
    color: #cbd5e1;
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
  }

  .overdue-pill {
    font-size: 0.68rem;
    background: rgba(239, 68, 68, 0.2);
    color: #fca5a5;
    border: 1px solid rgba(239, 68, 68, 0.4);
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 700;
  }

  .card-project-context {
    font-size: 0.72rem;
    color: var(--text-muted, #94a3b8);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .card-footer-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding-top: 8px;
    margin-top: 2px;
  }

  .assignee-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .assignee-avatar {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #3b82f6;
    color: #ffffff;
    font-size: 0.65rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .assignee-name {
    font-size: 0.75rem;
    color: #cbd5e1;
  }

  .btn-studio-jump {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 0.72rem;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: all 0.15s;
  }

  .btn-studio-jump.copy {
    background: rgba(139, 92, 246, 0.25);
    color: #c4b5fd;
    border: 1px solid rgba(139, 92, 246, 0.4);
  }

  .btn-studio-jump.copy:hover {
    background: #7c3aed;
    color: #ffffff;
  }

  .btn-studio-jump.view {
    background: rgba(59, 130, 246, 0.2);
    color: #93c5fd;
    border: 1px solid rgba(59, 130, 246, 0.3);
  }

  .btn-studio-jump.view:hover {
    background: #2563eb;
    color: #ffffff;
  }

  /* ═══ TABLE VIEW ═══ */
  .table-container {
    background: var(--card-bg, rgba(30, 41, 59, 0.6));
    border: 1px solid var(--border-color, rgba(255, 255, 255, 0.08));
    border-radius: 10px;
    overflow-x: auto;
  }

  .clickup-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .clickup-table th {
    text-align: left;
    padding: 10px 14px;
    background: rgba(0, 0, 0, 0.25);
    color: var(--text-muted, #94a3b8);
    font-weight: 600;
    font-size: 0.75rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .clickup-table td {
    padding: 12px 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    vertical-align: middle;
  }

  .table-row:hover {
    background: rgba(255, 255, 255, 0.03);
  }

  .status-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    border-radius: 9999px;
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: capitalize;
    border: 1px solid transparent;
    cursor: pointer;
  }

  .status-draft {
    background: rgba(100, 116, 139, 0.2);
    color: #94a3b8;
    border-color: rgba(100, 116, 139, 0.3);
  }

  .status-in-progress {
    background: rgba(2, 132, 199, 0.2);
    color: #38bdf8;
    border-color: rgba(2, 132, 199, 0.3);
  }

  .status-review {
    background: rgba(139, 92, 246, 0.2);
    color: #c4b5fd;
    border-color: rgba(139, 92, 246, 0.3);
  }

  .status-done {
    background: rgba(16, 185, 129, 0.2);
    color: #6ee7b7;
    border-color: rgba(16, 185, 129, 0.3);
  }

  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: currentColor;
  }

  .task-name-cell {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .table-task-name {
    color: #ffffff;
    font-weight: 600;
  }

  .table-task-notes {
    font-size: 0.72rem;
    color: var(--text-muted, #94a3b8);
    max-width: 280px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .deadline-text {
    font-size: 0.78rem;
    color: #cbd5e1;
  }

  .deadline-text.overdue {
    color: #ef4444;
    font-weight: 700;
  }

  .table-action-group {
    display: flex;
    justify-content: flex-end;
    gap: 6px;
  }

  .btn-row-delete {
    background: transparent;
    border: none;
    color: #94a3b8;
    padding: 4px 6px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
  }

  .btn-row-delete:hover {
    color: #ef4444;
    background: rgba(239, 68, 68, 0.1);
  }

  /* Loading & Empty */
  .loading-state, .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    text-align: center;
    gap: 12px;
    color: var(--text-muted, #94a3b8);
  }

  .empty-icon {
    font-size: 3rem;
  }

  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid rgba(255, 255, 255, 0.1);
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .spinning {
    animation: spin 0.8s linear infinite;
  }
</style>

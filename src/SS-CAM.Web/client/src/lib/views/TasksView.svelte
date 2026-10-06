<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { 
    StudioTask, 
    StudioTaskStatus, 
    ProjectPriority, 
    TaskDecisionStatus, 
    TaskSubtask 
  } from '$lib/types';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
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
  
  // 4-View Switcher: board | list | table | timeline
  let viewMode = $state<'board' | 'list' | 'table' | 'timeline'>('board');
  
  // Group By: status | workstream | priority
  let groupBy = $state<'status' | 'workstream' | 'priority'>('status');

  // Filters
  let brandFilter = $state('all');
  let priorityFilter = $state('all');
  let statusFilter = $state('all');
  let workstreamFilter = $state('all');
  let myTasksOnly = $state(false);
  let searchQuery = $state('');
  
  let isCreateModalOpen = $state(false);

  // Selected task for detail drawer
  let selectedTask = $state<StudioTask | null>(null);
  let isDetailDrawerOpen = $state(false);

  // Expanded subtasks in List View (set of task IDs)
  let expandedTaskIds = $state<Record<string, boolean>>({});

  // Drag and drop state
  let draggedTaskId = $state<string | null>(null);
  let dragOverCol = $state<string | null>(null);

  let staffRoster = $state<any[]>([]);

  const columns: { id: StudioTaskStatus; label: string; icon: string; color: string }[] = [
    { id: 'backlog', label: 'Backlog / Intake', icon: 'file', color: '#64748B' },
    { id: 'in-progress', label: 'In Progress', icon: 'bolt', color: '#0284C7' },
    { id: 'review', label: 'Review & QA', icon: 'search', color: '#8B5CF6' },
    { id: 'done', label: 'Approved & Done', icon: 'checkCircle', color: '#10B981' }
  ];

  const brandChips = ['all', 'SS', 'SSH', 'SSC', 'SSW', 'SSE', 'SST'];
  const priorityChips = ['all', 'urgent', 'high', 'medium', 'low'];
  const workstreamChips = [
    'all',
    'Packaging',
    'Signage',
    'Copywriting',
    'Motion & Video',
    'Digital & Social',
    'Brand Asset',
    '3D Rendering'
  ];

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

    if (workstreamFilter !== 'all') {
      list = list.filter(t => (t.workstream || 'General').toLowerCase() === workstreamFilter.toLowerCase());
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
        (t.workstream || '').toLowerCase().includes(q) ||
        (t.description || '').toLowerCase().includes(q) ||
        (t.assigneeName || '').toLowerCase().includes(q) ||
        (t.decisionSummary || '').toLowerCase().includes(q) ||
        (t.tags || []).some(tag => tag.toLowerCase().includes(q))
      );
    }

    return list;
  });

  // Grouping logic for Board / List
  const groupedSections = $derived.by(() => {
    if (groupBy === 'workstream') {
      const groups: Record<string, StudioTask[]> = {};
      workstreamChips.filter(w => w !== 'all').forEach(ws => { groups[ws] = []; });
      groups['Other'] = [];

      filteredTasks.forEach(task => {
        const ws = task.workstream || 'Other';
        if (!groups[ws]) groups[ws] = [];
        groups[ws].push(task);
      });

      return Object.entries(groups)
        .filter(([_, items]) => items.length > 0)
        .map(([label, items]) => ({
          id: label,
          label,
          color: '#0284C7',
          tasks: items
        }));
    } else if (groupBy === 'priority') {
      const pOrder: ProjectPriority[] = ['urgent', 'high', 'medium', 'low'];
      const pColors: Record<string, string> = {
        urgent: '#EF4444',
        high: '#F97316',
        medium: '#0284C7',
        low: '#64748B'
      };
      return pOrder.map(p => ({
        id: p,
        label: p.toUpperCase(),
        color: pColors[p] || '#64748B',
        tasks: filteredTasks.filter(t => (t.priority || 'medium') === p)
      }));
    }

    // Default: Group by Status
    return columns.map(col => ({
      id: col.id,
      label: col.label,
      color: col.color,
      tasks: col.id === 'done' 
        ? filteredTasks.filter(t => t.status === 'done' || t.status === 'converted')
        : filteredTasks.filter(t => t.status === col.id)
    }));
  });

  function getTasksByColumn(statusId: StudioTaskStatus) {
    if (statusId === 'done') {
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
    loadTasks();
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

  // Quick Inline Status Update from Table / List
  async function handleInlineStatusChange(task: StudioTask, newStatus: StudioTaskStatus) {
    if (task.status === newStatus) return;
    const oldStatus = task.status;
    task.status = newStatus;
    try {
      const res = await ApiClient.updateStudioTask(task.id, { status: newStatus });
      handleTaskUpdated(res.task);
      appState.addToast(`Updated ${task.id} status to ${newStatus}`, 'success');
    } catch (err: any) {
      task.status = oldStatus;
      appState.addToast(`Status update failed: ${err.message}`, 'error');
    }
  }

  // Inline Subtask Toggle from List View
  async function handleInlineSubtaskToggle(task: StudioTask, subtaskId: string) {
    const updatedSubtasks = (task.subtasks || []).map(s => 
      s.id === subtaskId ? { ...s, completed: !s.completed } : s
    );
    task.subtasks = updatedSubtasks;
    try {
      const res = await ApiClient.updateStudioTask(task.id, { subtasks: updatedSubtasks });
      handleTaskUpdated(res.task);
    } catch (err: any) {
      console.warn('Subtask toggle error:', err.message);
    }
  }

  function toggleListExpand(taskId: string) {
    expandedTaskIds[taskId] = !expandedTaskIds[taskId];
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

  function formatTimeline(start?: string, due?: string): string {
    if (!start && !due) return '—';
    const opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' };
    try {
      if (start && due) {
        const s = new Date(start).toLocaleDateString('en-US', opts);
        const d = new Date(due).toLocaleDateString('en-US', opts);
        return `${s} – ${d}`;
      }
      if (due) {
        return `Due ${new Date(due).toLocaleDateString('en-US', opts)}`;
      }
      return `Started ${new Date(start!).toLocaleDateString('en-US', opts)}`;
    } catch {
      return due || start || '—';
    }
  }

  function getSubtasksMeta(subtasks?: TaskSubtask[]) {
    if (!subtasks || subtasks.length === 0) return { total: 0, completed: 0, percent: 0 };
    const total = subtasks.length;
    const completed = subtasks.filter(s => s.completed).length;
    return {
      total,
      completed,
      percent: Math.round((completed / total) * 100)
    };
  }

  function getBlockers(task: StudioTask) {
    if (!task.blockedBy || task.blockedBy.length === 0) return [];
    return tasks.filter(t => task.blockedBy?.includes(t.id) && t.status !== 'done' && t.status !== 'converted');
  }

  // 14-Day Timeline computation for Gantt View
  const timelineDates = $derived.by(() => {
    const dates: Date[] = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    // 3 days back, 11 days forward
    for (let i = -2; i < 12; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() + i);
      dates.push(d);
    }
    return dates;
  });

  function getGanttBarStyle(task: StudioTask, dates: Date[]) {
    if (!dates || dates.length === 0) return { left: '0%', width: '0%', visible: false };
    const minTime = dates[0].getTime();
    const maxTime = dates[dates.length - 1].getTime() + 86400000;
    const totalDuration = maxTime - minTime;

    const start = task.startDate ? new Date(task.startDate).getTime() : (task.dueDate ? new Date(task.dueDate).getTime() - 86400000 * 2 : minTime);
    const due = task.dueDate ? new Date(task.dueDate).getTime() + 86400000 : start + 86400000 * 3;

    if (due < minTime || start > maxTime) {
      return { left: '0%', width: '100%', visible: true, outOfBounds: true };
    }

    const clampStart = Math.max(start, minTime);
    const clampDue = Math.min(due, maxTime);

    const left = ((clampStart - minTime) / totalDuration) * 100;
    const width = Math.max(((clampDue - clampStart) / totalDuration) * 100, 3);

    return {
      left: `${left}%`,
      width: `${width}%`,
      visible: true,
      outOfBounds: false
    };
  }
</script>

<div class="tasks-page-container">
  <!-- ═══ HEADER ROW ════════════════════════════════════════════════ -->
  <header class="tasks-page-header">
    <div class="header-left">
      <div class="title-with-badge">
        <h1 class="page-title">Tasks &amp; Workstream</h1>
        <span class="studio-subtext-pill">ClickUp Studio Pipeline</span>
      </div>
      <p class="page-subtitle">
        Decoupled pre-production task management. Ideate, track workstreams, manage pipeline dependencies, and link to NAS project vaults.
      </p>
    </div>

    <div class="header-right">
      <FluentButton appearance="secondary" onclick={loadTasks} disabled={isLoading} title="Reload Tasks">
        <FluentIcons name="refresh" size={14} />
      </FluentButton>

      <FluentButton appearance="primary" onclick={() => (isCreateModalOpen = true)}>
        <FluentIcons name="plus" size={14} />
        <span>New Task</span>
      </FluentButton>
    </div>
  </header>

  <!-- ═══ SUMMARY METRICS BAR ═══════════════════════════════════════ -->
  <div class="metrics-bar">
    <div class="metric-card">
      <div class="metric-icon-wrap">
        <FluentIcons name="kanban" size={16} color="var(--brand-accent)" />
      </div>
      <div class="metric-text">
        <span class="metric-label">TOTAL TASKS</span>
        <span class="metric-val">{tasks.length}</span>
      </div>
    </div>

    <div class="metric-card">
      <div class="metric-icon-wrap">
        <FluentIcons name="file" size={16} color="#64748B" />
      </div>
      <div class="metric-text">
        <span class="metric-label">BACKLOG</span>
        <span class="metric-val">{tasks.filter(t => t.status === 'backlog').length}</span>
      </div>
    </div>

    <div class="metric-card in-progress">
      <div class="metric-icon-wrap">
        <FluentIcons name="bolt" size={16} color="#0284C7" />
      </div>
      <div class="metric-text">
        <span class="metric-label">IN PROGRESS</span>
        <span class="metric-val">{tasks.filter(t => t.status === 'in-progress').length}</span>
      </div>
    </div>

    <div class="metric-card review">
      <div class="metric-icon-wrap">
        <FluentIcons name="search" size={16} color="#8B5CF6" />
      </div>
      <div class="metric-text">
        <span class="metric-label">IN REVIEW</span>
        <span class="metric-val">{tasks.filter(t => t.status === 'review').length}</span>
      </div>
    </div>

    <div class="metric-card done">
      <div class="metric-icon-wrap">
        <FluentIcons name="checkCircle" size={16} color="#10B981" />
      </div>
      <div class="metric-text">
        <span class="metric-label">COMPLETED</span>
        <span class="metric-val">{tasks.filter(t => t.status === 'done' || t.status === 'converted').length}</span>
      </div>
    </div>

    <div class="metric-card vault">
      <div class="metric-icon-wrap">
        <FluentIcons name="box" size={16} color="#0078D4" />
      </div>
      <div class="metric-text">
        <span class="metric-label">NAS LINKED</span>
        <span class="metric-val">{tasks.filter(t => !!t.projectId || t.status === 'converted').length}</span>
      </div>
    </div>

    {#if tasks.some(t => isOverdue(t.dueDate, t.status))}
      <div class="metric-card overdue">
        <div class="metric-icon-wrap">
          <FluentIcons name="warning" size={16} color="#DC2626" />
        </div>
        <div class="metric-text">
          <span class="metric-label">OVERDUE</span>
          <span class="metric-val">{tasks.filter(t => isOverdue(t.dueDate, t.status)).length}</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- ═══ CONTROLS & FILTER BAR ═════════════════════════════════════ -->
  <div class="controls-bar">
    <!-- 4-View Switcher -->
    <div class="segmented-control">
      <button
        type="button"
        class="seg-btn"
        class:active={viewMode === 'board'}
        onclick={() => (viewMode = 'board')}
        title="Kanban Board View"
      >
        <FluentIcons name="kanban" size={14} />
        <span>Board</span>
      </button>

      <button
        type="button"
        class="seg-btn"
        class:active={viewMode === 'list'}
        onclick={() => (viewMode = 'list')}
        title="Hierarchical List View with Subtasks"
      >
        <FluentIcons name="list" size={14} />
        <span>List</span>
      </button>

      <button
        type="button"
        class="seg-btn"
        class:active={viewMode === 'table'}
        onclick={() => (viewMode = 'table')}
        title="Dense Spreadsheet Table View"
      >
        <FluentIcons name="table" size={14} />
        <span>Table</span>
      </button>

      <button
        type="button"
        class="seg-btn"
        class:active={viewMode === 'timeline'}
        onclick={() => (viewMode = 'timeline')}
        title="Gantt Timeline Schedule View"
      >
        <FluentIcons name="gantt" size={14} />
        <span>Timeline</span>
      </button>
    </div>

    <!-- Group By Selector -->
    <div class="group-by-wrap">
      <span class="control-label">Group by:</span>
      <select class="group-select" bind:value={groupBy}>
        <option value="status">Status</option>
        <option value="workstream">Workstream</option>
        <option value="priority">Priority</option>
      </select>
    </div>

    <!-- Workstream Filter Chips -->
    <div class="filter-chips-wrap">
      <span class="filter-group-lbl">Workstream:</span>
      {#each workstreamChips as ws}
        <button
          type="button"
          class="chip-btn"
          class:active={workstreamFilter === ws}
          onclick={() => (workstreamFilter = ws)}
        >
          {ws === 'all' ? 'All' : ws}
        </button>
      {/each}
    </div>

    <!-- Priority Filter -->
    <div class="filter-chips-wrap">
      <span class="filter-group-lbl">Priority:</span>
      {#each priorityChips as p}
        <button
          type="button"
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
      type="button"
      class="chip-btn my-tasks-toggle"
      class:active={myTasksOnly}
      onclick={() => (myTasksOnly = !myTasksOnly)}
    >
      <FluentIcons name="user" size={13} />
      <span>My Tasks</span>
    </button>

    <!-- Search Input -->
    <div class="search-box">
      <FluentIcons name="search" size={14} class="search-ico" />
      <input
        type="text"
        placeholder="Search title, workstream, concept, tags…"
        bind:value={searchQuery}
        class="search-input"
      />
      {#if searchQuery}
        <button type="button" class="clear-search-btn" onclick={() => (searchQuery = '')}>✕</button>
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
      <FluentIcons name="file" size={32} color="var(--text-secondary)" />
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

  <!-- 1. KANBAN BOARD VIEW -->
  {:else if viewMode === 'board'}
    <div class="kanban-grid">
      {#each groupedSections as section}
        <div
          class="kanban-column"
          class:drag-over={dragOverCol === section.id}
          ondragover={(e) => handleDragOver(e, section.id)}
          ondragleave={() => handleDragLeave(section.id)}
          ondrop={(e) => handleDrop(e, section.id as StudioTaskStatus)}
          role="region"
          aria-label="{section.label} column"
        >
          <!-- Column Header -->
          <div class="col-header" style="border-top-color: {section.color};">
            <div class="col-title-wrap">
              <span class="col-title">{section.label}</span>
              <span class="col-counter">{section.tasks.length}</span>
            </div>
          </div>

          <!-- Cards Container -->
          <div class="col-cards">
            {#each section.tasks as task (task.id)}
              {@const subMeta = getSubtasksMeta(task.subtasks)}
              {@const blockers = getBlockers(task)}
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
                <!-- Card Header: ID, Brand, Workstream, Priority -->
                <div class="card-top-row">
                  <div class="card-top-left">
                    <span class="task-id-tag">#{task.id}</span>
                    <FluentBadge type="brand" value={task.brand || 'SS'} />
                    {#if task.workstream}
                      <span class="card-ws-pill">{task.workstream}</span>
                    {/if}
                  </div>
                  <div class="card-top-right">
                    <FluentBadge type="priority" value={task.priority || 'medium'} />
                  </div>
                </div>

                <!-- Card Title -->
                <h4 class="card-title">{task.title}</h4>

                <!-- Pipeline Blocker Alert Pill -->
                {#if blockers.length > 0}
                  <div class="card-blocker-pill" title="Waiting on prerequisite task to finish">
                    <FluentIcons name="warning" size={12} color="#D97706" />
                    <span>Waiting on {blockers.map(b => b.id).join(', ')}</span>
                  </div>
                {/if}

                <!-- Subtasks Progress Bar Glance -->
                {#if subMeta.total > 0}
                  <div class="card-subtasks-glance">
                    <div class="sub-progress-bar">
                      <div class="sub-progress-fill" style="width: {subMeta.percent}%;"></div>
                    </div>
                    <span class="sub-progress-lbl">
                      <FluentIcons name="list" size={11} />
                      {subMeta.completed}/{subMeta.total} subtasks ({subMeta.percent}%)
                    </span>
                  </div>
                {/if}

                <!-- Decision & Timeline Glance -->
                <div class="card-glance-row">
                  {#if task.decisionStatus && task.decisionStatus !== 'pending'}
                    <span class="card-decision-badge decision-{task.decisionStatus}">
                      {task.decisionStatus.replace('_', ' ')}
                    </span>
                  {/if}

                  <span class="card-timeline-pill" class:overdue={isOverdue(task.dueDate, task.status)}>
                    <FluentIcons name="calendar" size={12} />
                    {formatTimeline(task.startDate, task.dueDate)}
                  </span>
                </div>

                <!-- Card Footer: Assignee & Project Vault Link -->
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
                    {#if task.projectId}
                      <span class="vault-link-badge" title="Linked to NAS Project: {task.projectId}">
                        <FluentIcons name="box" size={12} />
                        {task.projectId.substring(0, 14)}…
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

  <!-- 2. CLICKUP HIERARCHICAL LIST VIEW -->
  {:else if viewMode === 'list'}
    <div class="list-view-container">
      {#each groupedSections as section}
        <div class="list-section">
          <!-- Section Header -->
          <div class="list-section-header">
            <span class="list-section-title" style="border-left-color: {section.color};">
              {section.label}
            </span>
            <span class="list-section-count">{section.tasks.length} tasks</span>
          </div>

          <!-- List Rows -->
          <div class="list-rows-wrap">
            {#each section.tasks as task (task.id)}
              {@const subMeta = getSubtasksMeta(task.subtasks)}
              {@const isExpanded = !!expandedTaskIds[task.id]}
              {@const blockers = getBlockers(task)}

              <div class="list-row-card" class:has-blocker={blockers.length > 0}>
                <!-- Main Task Row Header -->
                <div
                  class="list-row-main"
                  onclick={() => openTaskDetail(task)}
                  onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
                  role="button"
                  tabindex="0"
                >
                  <!-- Expand Subtasks Chevron -->
                  <button
                    type="button"
                    class="list-expand-btn"
                    onclick={(e) => { e.stopPropagation(); toggleListExpand(task.id); }}
                    title="{isExpanded ? 'Collapse' : 'Expand'} Subtasks"
                  >
                    <FluentIcons name={isExpanded ? 'chevronDown' : 'chevronRight'} size={14} />
                  </button>

                  <!-- Task ID & Title (# Main Task) -->
                  <div class="list-title-col">
                    <span class="task-id-tag">#{task.id}</span>
                    <span class="list-task-title">{task.title}</span>
                    {#if blockers.length > 0}
                      <span class="inline-blocker-warning" title="Waiting on prerequisite tasks">
                        <FluentIcons name="warning" size={12} color="#D97706" />
                        Blocked
                      </span>
                    {/if}
                  </div>

                  <!-- Workstream Pill -->
                  <div class="list-ws-col">
                    <span class="card-ws-pill">{task.workstream || 'General'}</span>
                  </div>

                  <!-- Subtasks Progress -->
                  <div class="list-subtasks-col">
                    {#if subMeta.total > 0}
                      <div class="mini-progress-bar">
                        <div class="mini-progress-fill" style="width: {subMeta.percent}%;"></div>
                      </div>
                      <span class="mini-progress-text">{subMeta.completed}/{subMeta.total}</span>
                    {:else}
                      <span class="empty-val">0 subtasks</span>
                    {/if}
                  </div>

                  <!-- Timeline -->
                  <div class="list-timeline-col">
                    <span class="timeline-text" class:overdue-text={isOverdue(task.dueDate, task.status)}>
                      {formatTimeline(task.startDate, task.dueDate)}
                    </span>
                  </div>

                  <!-- Decision -->
                  <div class="list-decision-col">
                    <span class="card-decision-badge decision-{task.decisionStatus || 'pending'}">
                      {(task.decisionStatus || 'pending').replace('_', ' ')}
                    </span>
                  </div>

                  <!-- Assignee -->
                  <div class="list-assignee-col">
                    <div class="assignee-avatar sm" style="background: {task.assigneeAvatarColor || '#0078D4'};">
                      {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                    </div>
                    <span>{task.assigneeName || task.assignee || 'Unassigned'}</span>
                  </div>

                  <!-- Priority -->
                  <div class="list-priority-col">
                    <FluentBadge type="priority" value={task.priority || 'medium'} />
                  </div>

                  <!-- Status Dropdown (Instant inline update) -->
                  <div class="list-status-col" onclick={(e) => e.stopPropagation()} onkeydown={() => {}} role="none">
                    <select
                      class="inline-status-select status-{task.status}"
                      value={task.status}
                      onchange={(e) => handleInlineStatusChange(task, (e.target as HTMLSelectElement).value as StudioTaskStatus)}
                    >
                      {#each columns as c}
                        <option value={c.id}>{c.label}</option>
                      {/each}
                    </select>
                  </div>
                </div>

                <!-- Expanded Subtasks Checklist (## list of Subtasks) -->
                {#if isExpanded}
                  <div class="list-subtasks-accordion">
                    <div class="subtasks-accordion-header">
                      <span class="subtask-header-lbl">## SUBTASKS CHECKLIST</span>
                    </div>

                    {#if !task.subtasks || task.subtasks.length === 0}
                      <p class="no-subtasks-prompt">
                        No subtasks created. Open details to generate subtasks with Gemini AI.
                      </p>
                    {:else}
                      <div class="accordion-subtask-list">
                        {#each task.subtasks as sub}
                          <div class="accordion-subtask-row" class:completed={sub.completed}>
                            <input
                              type="checkbox"
                              checked={sub.completed}
                              onchange={() => handleInlineSubtaskToggle(task, sub.id)}
                              class="subtask-checkbox"
                            />
                            <span class="subtask-title-text">{sub.title}</span>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>

  <!-- 3. DENSE SPREADSHEET TABLE VIEW -->
  {:else if viewMode === 'table'}
    <div class="table-container">
      <table class="studio-table">
        <thead>
          <tr>
            <th style="width: 90px;">Task ID</th>
            <th>Title &amp; Main Concept</th>
            <th style="width: 120px;">Workstream</th>
            <th style="width: 140px;">Subtasks</th>
            <th style="width: 140px;">Timeline</th>
            <th style="width: 110px;">Decision</th>
            <th style="width: 140px;">Assignee</th>
            <th style="width: 90px;">Priority</th>
            <th style="width: 130px;">Stage</th>
            <th style="width: 120px;">NAS Vault</th>
            <th style="width: 70px; text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredTasks as task (task.id)}
            {@const subMeta = getSubtasksMeta(task.subtasks)}
            <tr
              class="table-row"
              onclick={() => openTaskDetail(task)}
              onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
              role="button"
              tabindex="0"
              aria-label="Inspect task {task.id}: {task.title}"
            >
              <td class="id-cell">
                <span class="task-id-tag">#{task.id}</span>
              </td>

              <td class="title-cell">
                <div class="tbl-title">{task.title}</div>
                {#if task.description}
                  <div class="tbl-snippet">{task.description.substring(0, 50)}…</div>
                {/if}
              </td>

              <td>
                <span class="card-ws-pill">{task.workstream || 'Packaging'}</span>
              </td>

              <td>
                {#if subMeta.total > 0}
                  <div class="mini-progress-bar">
                    <div class="mini-progress-fill" style="width: {subMeta.percent}%;"></div>
                  </div>
                  <span class="mini-progress-text">{subMeta.completed}/{subMeta.total} done</span>
                {:else}
                  <span class="empty-val">—</span>
                {/if}
              </td>

              <td class="date-cell">
                <span class:overdue-text={isOverdue(task.dueDate, task.status)}>
                  {formatTimeline(task.startDate, task.dueDate)}
                </span>
              </td>

              <td>
                <span class="card-decision-badge decision-{task.decisionStatus || 'pending'}">
                  {(task.decisionStatus || 'pending').replace('_', ' ')}
                </span>
              </td>

              <td>
                <div class="tbl-assignee">
                  <div class="assignee-avatar sm" style="background: {task.assigneeAvatarColor || '#0078D4'};">
                    {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                  </div>
                  <span>{task.assigneeName || task.assignee || 'Unassigned'}</span>
                </div>
              </td>

              <td>
                <FluentBadge type="priority" value={task.priority || 'medium'} />
              </td>

              <td onclick={(e) => e.stopPropagation()} onkeydown={() => {}} role="none">
                <select
                  class="inline-status-select status-{task.status}"
                  value={task.status}
                  onchange={(e) => handleInlineStatusChange(task, (e.target as HTMLSelectElement).value as StudioTaskStatus)}
                >
                  {#each columns as c}
                    <option value={c.id}>{c.label}</option>
                  {/each}
                </select>
              </td>

              <td>
                {#if task.projectId}
                  <span class="vault-link-badge">
                    <FluentIcons name="box" size={11} />
                    {task.projectId.substring(0, 12)}…
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

  <!-- 4. GANTT / TIMELINE SCHEDULE VIEW -->
  {:else if viewMode === 'timeline'}
    <div class="gantt-container">
      <div class="gantt-header-row">
        <div class="gantt-task-meta-header">TASK &amp; WORKSTREAM</div>
        <div class="gantt-calendar-grid-header">
          {#each timelineDates as d}
            <div class="gantt-day-header" class:is-today={d.toDateString() === new Date().toDateString()}>
              <span class="day-name">{d.toLocaleDateString('en-US', { weekday: 'narrow' })}</span>
              <span class="day-num">{d.getDate()}</span>
            </div>
          {/each}
        </div>
      </div>

      <!-- Gantt Task Rows -->
      <div class="gantt-body">
        {#each filteredTasks as task (task.id)}
          {@const bar = getGanttBarStyle(task, timelineDates)}
          <div
            class="gantt-row"
            onclick={() => openTaskDetail(task)}
            onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
            role="button"
            tabindex="0"
          >
            <!-- Left Info -->
            <div class="gantt-row-title-col">
              <span class="task-id-tag">#{task.id}</span>
              <span class="gantt-title-text">{task.title}</span>
              <span class="card-ws-pill sm">{task.workstream || 'Studio'}</span>
            </div>

            <!-- Right Schedule Bar Grid -->
            <div class="gantt-bars-track">
              <!-- Grid vertical lines -->
              {#each timelineDates as d}
                <div class="gantt-grid-cell" class:is-today={d.toDateString() === new Date().toDateString()}></div>
              {/each}

              <!-- Task Bar -->
              {#if bar.visible}
                <div
                  class="gantt-task-bar status-{task.status}"
                  style="left: {bar.left}; width: {bar.width};"
                  title="{task.title} ({task.status})"
                >
                  <span class="bar-title">{task.title}</span>
                </div>
              {/if}
            </div>
          </div>
        {/each}
      </div>
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
  {allTasks}
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
    align-items: flex-start;
    justify-content: space-between;
    gap: 20px;
    flex-wrap: wrap;
  }

  .title-with-badge {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .page-title {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
    letter-spacing: -0.5px;
  }

  .studio-subtext-pill {
    font-size: 11px;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 4px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    color: var(--brand-accent);
  }

  .page-subtitle {
    font-size: 13px;
    color: var(--text-secondary);
    margin: 4px 0 0;
    max-width: 720px;
    line-height: 1.45;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  /* ═══ METRICS BAR ══════════════════════════════════════════════ */
  .metrics-bar {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }

  .metric-card {
    flex: 1;
    min-width: 120px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 10px 14px;
    display: flex;
    align-items: center;
    gap: 10px;
    transition: all 0.15s ease;
  }
  .metric-card:hover {
    border-color: var(--brand-accent);
    transform: translateY(-1px);
  }

  .metric-icon-wrap {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border-radius: 6px;
    background: var(--surface-card-subtle);
  }

  .metric-text {
    display: flex;
    flex-direction: column;
  }

  .metric-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-secondary);
    letter-spacing: 0.4px;
  }

  .metric-val {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    line-height: 1.2;
  }

  .metric-card.in-progress .metric-val { color: #0284C7; }
  .metric-card.review .metric-val { color: #8B5CF6; }
  .metric-card.done .metric-val { color: #10B981; }
  .metric-card.overdue {
    border-color: rgba(220, 38, 38, 0.3);
    background: rgba(220, 38, 38, 0.05);
  }
  .metric-card.overdue .metric-val { color: #DC2626; }

  /* ═══ CONTROLS BAR ═════════════════════════════════════════════ */
  .controls-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 10px 14px;
  }

  .segmented-control {
    display: inline-flex;
    background: var(--surface-card-subtle);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
    border: 1px solid var(--surface-card-border);
  }

  .seg-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 5px 12px;
    border-radius: 4px;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .seg-btn:hover {
    color: var(--text-primary);
  }
  .seg-btn.active {
    background: var(--surface-card);
    color: var(--brand-accent);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
  }

  .group-by-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
    border-left: 1px solid var(--surface-card-border);
    padding-left: 12px;
  }
  .control-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
  }
  .group-select {
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 12px;
    font-weight: 600;
  }

  .filter-chips-wrap {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: wrap;
  }
  .filter-group-lbl {
    font-size: 11px;
    color: var(--text-secondary);
    margin-right: 2px;
  }

  .chip-btn {
    padding: 3px 8px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.12s ease;
  }
  .chip-btn:hover {
    background: var(--surface-card);
    color: var(--text-primary);
  }
  .chip-btn.active {
    background: rgba(0, 120, 212, 0.12);
    border-color: var(--brand-accent);
    color: var(--brand-accent);
    font-weight: 600;
  }

  .my-tasks-toggle {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    margin-left: auto;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    padding: 4px 10px;
    min-width: 240px;
  }
  .search-input {
    border: none;
    background: transparent;
    color: var(--text-primary);
    font-size: 12px;
    width: 100%;
  }
  .search-input:focus { outline: none; }
  .clear-search-btn {
    background: transparent;
    border: none;
    font-size: 11px;
    color: var(--text-secondary);
    cursor: pointer;
  }

  /* ═══ KANBAN GRID ══════════════════════════════════════════════ */
  .kanban-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 16px;
    align-items: start;
  }

  .kanban-column {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    min-height: 480px;
    transition: all 0.15s ease;
  }
  .kanban-column.drag-over {
    border-color: var(--brand-accent);
    background: rgba(0, 120, 212, 0.05);
  }

  .col-header {
    border-top: 3px solid #64748B;
    border-top-left-radius: 7px;
    border-top-right-radius: 7px;
    padding: 12px 14px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }

  .col-title-wrap {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .col-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .col-counter {
    font-size: 11px;
    font-weight: 600;
    background: var(--surface-card-subtle);
    padding: 2px 6px;
    border-radius: 10px;
    color: var(--text-secondary);
  }

  .col-cards {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  /* Task Card */
  .task-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .task-card:hover {
    border-color: var(--brand-accent);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .card-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }
  .card-top-left {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
  }

  .task-id-tag {
    font-family: monospace;
    font-size: 11px;
    font-weight: 700;
    color: var(--brand-accent);
  }

  .card-ws-pill {
    font-size: 10px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 3px;
    background: rgba(0, 120, 212, 0.08);
    color: var(--brand-accent);
    border: 1px solid rgba(0, 120, 212, 0.2);
  }
  .card-ws-pill.sm { font-size: 9px; padding: 1px 4px; }

  .card-title {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.35;
  }

  .card-blocker-pill {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: rgba(245, 158, 11, 0.12);
    border: 1px solid rgba(245, 158, 11, 0.3);
    color: #B45309;
    padding: 3px 6px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 600;
  }

  .card-subtasks-glance {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .sub-progress-bar {
    height: 4px;
    border-radius: 2px;
    background: var(--surface-card-border);
    overflow: hidden;
  }
  .sub-progress-fill {
    height: 100%;
    background: #10B981;
  }
  .sub-progress-lbl {
    font-size: 10px;
    color: var(--text-secondary);
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  .card-glance-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }

  .card-decision-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 3px;
    text-transform: uppercase;
  }
  .card-decision-badge.decision-approved { background: rgba(16, 185, 129, 0.15); color: #10B981; }
  .card-decision-badge.decision-pending { background: rgba(100, 116, 139, 0.15); color: var(--text-secondary); }
  .card-decision-badge.decision-in_review { background: rgba(139, 92, 246, 0.15); color: #8B5CF6; }
  .card-decision-badge.decision-changes_requested { background: rgba(245, 158, 11, 0.15); color: #F59E0B; }
  .card-decision-badge.decision-rejected { background: rgba(239, 68, 68, 0.15); color: #EF4444; }

  .card-timeline-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    color: var(--text-secondary);
  }
  .card-timeline-pill.overdue {
    color: #DC2626;
    font-weight: 600;
  }

  .card-footer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
    padding-top: 6px;
    border-top: 1px solid var(--surface-card-border);
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
    color: #FFF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: 700;
  }
  .assignee-avatar.sm {
    width: 18px;
    height: 18px;
    font-size: 9px;
  }
  .assignee-name {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .vault-link-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    color: var(--brand-accent);
    background: var(--surface-card-subtle);
    padding: 2px 6px;
    border-radius: 3px;
    border: 1px solid var(--surface-card-border);
  }

  /* ═══ CLICKUP HIERARCHICAL LIST VIEW ═══════════════════════════ */
  .list-view-container {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .list-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .list-section-header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 4px;
    border-bottom: 1px solid var(--surface-card-border);
  }
  .list-section-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    padding-left: 8px;
    border-left: 3px solid var(--brand-accent);
  }
  .list-section-count {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .list-rows-wrap {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .list-row-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    display: flex;
    flex-direction: column;
    transition: all 0.12s ease;
  }
  .list-row-card:hover {
    border-color: var(--brand-accent);
  }

  .list-row-main {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 12px;
    cursor: pointer;
    font-size: 12px;
  }

  .list-expand-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
    padding: 2px;
  }

  .list-title-col {
    flex: 2;
    min-width: 220px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .list-task-title {
    font-weight: 600;
    color: var(--text-primary);
  }
  .inline-blocker-warning {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-size: 10px;
    color: #D97706;
    background: rgba(245, 158, 11, 0.12);
    padding: 1px 4px;
    border-radius: 3px;
  }

  .list-ws-col { width: 110px; }
  .list-subtasks-col { width: 120px; display: flex; align-items: center; gap: 6px; }
  .list-timeline-col { width: 130px; font-size: 11px; color: var(--text-secondary); }
  .list-decision-col { width: 100px; }
  .list-assignee-col { width: 130px; display: flex; align-items: center; gap: 6px; }
  .list-priority-col { width: 80px; }
  .list-status-col { width: 110px; }

  .inline-status-select {
    padding: 3px 6px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    font-size: 11px;
    font-weight: 600;
    color: var(--text-primary);
  }

  /* Subtasks Accordion */
  .list-subtasks-accordion {
    padding: 8px 14px 12px 38px;
    background: var(--surface-card-subtle);
    border-top: 1px dashed var(--surface-card-border);
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .subtask-header-lbl {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-secondary);
  }
  .accordion-subtask-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .accordion-subtask-row {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
  }
  .accordion-subtask-row.completed .subtask-title-text {
    text-decoration: line-through;
    color: var(--text-secondary);
  }
  .subtask-checkbox {
    width: 14px;
    height: 14px;
    cursor: pointer;
  }
  .no-subtasks-prompt {
    margin: 0;
    font-size: 11px;
    color: var(--text-secondary);
  }

  /* ═══ TABLE VIEW ═══════════════════════════════════════════════ */
  .table-container {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    overflow-x: auto;
  }

  .studio-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  .studio-table th {
    text-align: left;
    padding: 10px 12px;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
  }
  .studio-table td {
    padding: 8px 12px;
    border-bottom: 1px solid var(--surface-card-border);
    color: var(--text-primary);
  }
  .table-row {
    cursor: pointer;
    transition: background 0.1s ease;
  }
  .table-row:hover {
    background: var(--surface-card-subtle);
  }

  .tbl-title { font-weight: 600; color: var(--text-primary); }
  .tbl-snippet { font-size: 11px; color: var(--text-secondary); }
  .tbl-assignee { display: flex; align-items: center; gap: 6px; }
  .pre-prod-cell-badge { font-size: 10px; color: var(--text-secondary); }
  .tbl-open-btn {
    background: transparent;
    border: none;
    color: var(--brand-accent);
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
  }

  .mini-progress-bar {
    width: 50px;
    height: 4px;
    background: var(--surface-card-border);
    border-radius: 2px;
    overflow: hidden;
    display: inline-block;
  }
  .mini-progress-fill { height: 100%; background: #10B981; }
  .mini-progress-text { font-size: 10px; color: var(--text-secondary); }
  .overdue-text { color: #DC2626; font-weight: 600; }
  .empty-val { color: var(--text-secondary); }

  /* ═══ GANTT / TIMELINE SCHEDULE VIEW ═══════════════════════════ */
  .gantt-container {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    overflow-x: auto;
  }

  .gantt-header-row {
    display: flex;
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
  }
  .gantt-task-meta-header {
    width: 260px;
    min-width: 260px;
    padding: 10px 14px;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    border-right: 1px solid var(--surface-card-border);
  }
  .gantt-calendar-grid-header {
    flex: 1;
    display: flex;
  }
  .gantt-day-header {
    flex: 1;
    min-width: 36px;
    text-align: center;
    padding: 6px 2px;
    border-right: 1px solid var(--surface-card-border);
    display: flex;
    flex-direction: column;
    font-size: 10px;
    color: var(--text-secondary);
  }
  .gantt-day-header.is-today {
    background: rgba(0, 120, 212, 0.1);
    color: var(--brand-accent);
    font-weight: 700;
  }

  .gantt-body {
    display: flex;
    flex-direction: column;
  }

  .gantt-row {
    display: flex;
    border-bottom: 1px solid var(--surface-card-border);
    cursor: pointer;
    transition: background 0.12s ease;
  }
  .gantt-row:hover { background: var(--surface-card-subtle); }

  .gantt-row-title-col {
    width: 260px;
    min-width: 260px;
    padding: 8px 14px;
    border-right: 1px solid var(--surface-card-border);
    display: flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
  }
  .gantt-title-text {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .gantt-bars-track {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }
  .gantt-grid-cell {
    flex: 1;
    min-width: 36px;
    height: 100%;
    border-right: 1px solid var(--surface-card-border);
  }
  .gantt-grid-cell.is-today {
    background: rgba(0, 120, 212, 0.05);
  }

  .gantt-task-bar {
    position: absolute;
    height: 22px;
    border-radius: 4px;
    background: var(--brand-accent);
    color: #FFF;
    display: flex;
    align-items: center;
    padding: 0 8px;
    font-size: 11px;
    font-weight: 600;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    z-index: 2;
  }
  .gantt-task-bar.status-backlog { background: #64748B; }
  .gantt-task-bar.status-in-progress { background: #0284C7; }
  .gantt-task-bar.status-review { background: #8B5CF6; }
  .gantt-task-bar.status-done { background: #10B981; }

  /* Loading & Empty */
  .loading-state,
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    background: var(--surface-card);
    border: 1px dashed var(--surface-card-border);
    border-radius: 8px;
    text-align: center;
    gap: 12px;
  }
  .spinner {
    width: 28px;
    height: 28px;
    border: 3px solid var(--surface-card-border);
    border-top-color: var(--brand-accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>

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
  
  // ClickUp 5-View Switcher: overview | list | board | gantt | table
  let viewMode = $state<'overview' | 'list' | 'board' | 'gantt' | 'table'>('list');
  
  // Group By: status | workstream | priority
  let groupBy = $state<'status' | 'workstream' | 'priority'>('workstream');

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

  // Expanded tree states for hierarchical List & Gantt
  let expandedWorkstreams = $state<Record<string, boolean>>({
    Packaging: true,
    Signage: true,
    Copywriting: true,
    'Motion & Video': true,
    'Digital & Social': true,
    'Brand Asset': true,
    '3D Rendering': true,
    General: true
  });
  let expandedTaskIds = $state<Record<string, boolean>>({});

  // Inline quick-create task under specific group
  let inlineCreateParent = $state<{ workstream?: string; status?: StudioTaskStatus } | null>(null);
  let inlineTaskTitle = $state('');

  // Drag and drop state for board
  let draggedTaskId = $state<string | null>(null);
  let dragOverCol = $state<string | null>(null);

  let staffRoster = $state<any[]>([]);

  const columns: { id: StudioTaskStatus; label: string; icon: string; color: string }[] = [
    { id: 'backlog', label: 'TO DO', icon: 'circleDashed', color: '#94A3B8' },
    { id: 'in-progress', label: 'IN PROGRESS', icon: 'bolt', color: '#0284C7' },
    { id: 'review', label: 'REVIEW', icon: 'search', color: '#8B5CF6' },
    { id: 'done', label: 'COMPLETE', icon: 'checkCircle', color: '#10B981' }
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

    const onTasksChanged = () => { loadTasks(); };
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

  // Unique workstreams present
  const presentWorkstreams = $derived.by(() => {
    const set = new Set<string>();
    filteredTasks.forEach(t => {
      set.add(t.workstream || 'General');
    });
    if (set.size === 0) return ['Packaging', 'Signage', 'Copywriting'];
    return Array.from(set);
  });

  // Grouped tasks by Workstream then Status (ClickUp List arrangement)
  const workstreamGroups = $derived.by(() => {
    return presentWorkstreams.map(ws => {
      const wsTasks = filteredTasks.filter(t => (t.workstream || 'General') === ws);
      const total = wsTasks.length;
      const completed = wsTasks.filter(t => t.status === 'done' || t.status === 'converted').length;
      const percent = total > 0 ? Math.round((completed / total) * 100) : 0;

      // Group tasks inside workstream by Status
      const statusGroups = [
        { status: 'backlog' as StudioTaskStatus, label: 'TO DO', color: '#94A3B8', tasks: wsTasks.filter(t => t.status === 'backlog') },
        { status: 'in-progress' as StudioTaskStatus, label: 'IN PROGRESS', color: '#0284C7', tasks: wsTasks.filter(t => t.status === 'in-progress') },
        { status: 'review' as StudioTaskStatus, label: 'REVIEW', color: '#8B5CF6', tasks: wsTasks.filter(t => t.status === 'review') },
        { status: 'done' as StudioTaskStatus, label: 'COMPLETE', color: '#10B981', tasks: wsTasks.filter(t => t.status === 'done' || t.status === 'converted') }
      ];

      return {
        workstream: ws,
        total,
        completed,
        percent,
        tasks: wsTasks,
        statusGroups
      };
    });
  });

  // Priority color & flag helper
  function getPriorityMeta(p?: ProjectPriority) {
    switch (p) {
      case 'urgent': return { color: '#EF4444', label: 'Urgent', rank: 4 };
      case 'high': return { color: '#F97316', label: 'High', rank: 3 };
      case 'medium': return { color: '#0284C7', label: 'Normal', rank: 2 };
      case 'low': return { color: '#94A3B8', label: 'Low', rank: 1 };
      default: return { color: '#CBD5E1', label: 'None', rank: 0 };
    }
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

  // Quick inline task creation directly from List view
  async function handleQuickInlineCreate(workstream: string, status: StudioTaskStatus = 'backlog') {
    const t = inlineTaskTitle.trim();
    if (!t) {
      inlineCreateParent = null;
      return;
    }
    inlineTaskTitle = '';
    inlineCreateParent = null;
    try {
      const res = await ApiClient.createStudioTask({
        title: t,
        workstream,
        status,
        priority: 'medium',
        brand: 'SS'
      });
      handleTaskCreated(res.task);
      appState.addToast(`Created task "${t}" in ${workstream}`, 'success');
    } catch (err: any) {
      appState.addToast(`Failed to create task: ${err.message}`, 'error');
    }
  }

  // Inline Status change
  async function handleInlineStatusChange(task: StudioTask, newStatus: StudioTaskStatus) {
    if (task.status === newStatus) return;
    const old = task.status;
    task.status = newStatus;
    try {
      const res = await ApiClient.updateStudioTask(task.id, { status: newStatus });
      handleTaskUpdated(res.task);
    } catch (err: any) {
      task.status = old;
      appState.addToast(`Failed to update status: ${err.message}`, 'error');
    }
  }

  // Inline Subtask Toggle
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

  function toggleWorkstreamExpand(ws: string) {
    expandedWorkstreams[ws] = !expandedWorkstreams[ws];
  }

  function toggleTaskSubtasks(taskId: string) {
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

  function formatDateShort(iso?: string): string {
    if (!iso) return '';
    try {
      const d = new Date(iso);
      return d.toLocaleDateString('en-US', { month: 'numeric', day: 'numeric', year: '2-digit' });
    } catch {
      return iso;
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

  // 14-Day Calendar Dates for ClickUp Gantt View
  const todayDate = new Date();
  const ganttDates = $derived.by(() => {
    const list: Date[] = [];
    const base = new Date();
    base.setHours(0, 0, 0, 0);
    // 3 days before today, 10 days after today
    for (let i = -3; i <= 10; i++) {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      list.push(d);
    }
    return list;
  });

  function getGanttBarStyle(task: StudioTask, dates: Date[]) {
    if (!dates || dates.length === 0) return { left: '0%', width: '0%', isMilestone: false };
    const minTime = dates[0].getTime();
    const maxTime = dates[dates.length - 1].getTime() + 86400000;
    const total = maxTime - minTime;

    const start = task.startDate ? new Date(task.startDate).getTime() : (task.dueDate ? new Date(task.dueDate).getTime() - 86400000 * 2 : minTime);
    const due = task.dueDate ? new Date(task.dueDate).getTime() + 86400000 : start + 86400000 * 2;

    const clampStart = Math.max(start, minTime);
    const clampDue = Math.min(due, maxTime);

    const left = ((clampStart - minTime) / total) * 100;
    const width = Math.max(((clampDue - clampStart) / total) * 100, 2.5);

    return {
      left: `${left}%`,
      width: `${width}%`,
      isMilestone: width <= 3
    };
  }

  // Board Drag and Drop
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
</script>

<div class="clickup-container">
  <!-- ═══ CLICKUP TOP SUB-HEADER & NAVIGATION ═══════════════════════ -->
  <header class="clickup-top-header">
    <div class="header-left-cluster">
      <div class="space-title-dropdown">
        <span class="space-icon-dot"></span>
        <h1 class="space-name">SS Creative Studio</h1>
        <FluentIcons name="chevronDown" size={14} class="caret-down" />
        <span class="favorite-star" title="Star workspace">☆</span>
      </div>
    </div>

    <div class="header-right-tools">
      <button type="button" class="tool-ghost-btn" title="Automate Studio Workflows">
        <FluentIcons name="bolt" size={14} />
        <span>Automate</span>
      </button>

      <button type="button" class="tool-ghost-btn ai-btn" title="Gemini AI Studio Brain" onclick={() => {
        if (tasks.length > 0) openTaskDetail(tasks[0]);
      }}>
        <FluentIcons name="sparkles" size={14} color="#8B5CF6" />
        <span>Brain AI</span>
      </button>

      <button type="button" class="tool-ghost-btn" title="Share with Team / Client">
        <FluentIcons name="share" size={14} />
        <span>Share</span>
      </button>

      <div class="tool-divider"></div>

      <!-- + Task Primary Action Button (ClickUp Signature Solid Blue) -->
      <button
        type="button"
        class="clickup-add-task-btn"
        onclick={() => (isCreateModalOpen = true)}
      >
        <FluentIcons name="plus" size={14} />
        <span>Task</span>
        <FluentIcons name="chevronDown" size={12} />
      </button>
    </div>
  </header>

  <!-- ═══ CLICKUP VIEWS NAVIGATION STRIP ════════════════════════════ -->
  <div class="clickup-views-nav">
    <div class="views-tabs-list">
      <button
        type="button"
        class="view-tab"
        class:active={viewMode === 'overview'}
        onclick={() => (viewMode = 'overview')}
      >
        <FluentIcons name="overview" size={14} />
        <span>Overview</span>
      </button>

      <button
        type="button"
        class="view-tab"
        class:active={viewMode === 'list'}
        onclick={() => (viewMode = 'list')}
      >
        <FluentIcons name="list" size={14} />
        <span>List</span>
      </button>

      <button
        type="button"
        class="view-tab"
        class:active={viewMode === 'board'}
        onclick={() => (viewMode = 'board')}
      >
        <FluentIcons name="kanban" size={14} />
        <span>Board</span>
      </button>

      <button
        type="button"
        class="view-tab gantt-tab"
        class:active={viewMode === 'gantt'}
        onclick={() => (viewMode = 'gantt')}
      >
        <FluentIcons name="gantt" size={14} color={viewMode === 'gantt' ? '#EF4444' : 'currentColor'} />
        <span>Gantt</span>
      </button>

      <button
        type="button"
        class="view-tab"
        class:active={viewMode === 'table'}
        onclick={() => (viewMode = 'table')}
      >
        <FluentIcons name="table" size={14} />
        <span>Table</span>
      </button>
    </div>

    <!-- Right Controls: Status Pill, Filter, Me Mode, Search -->
    <div class="views-sub-controls">
      <!-- Status Filter Pill -->
      <select class="clickup-filter-pill" bind:value={statusFilter}>
        <option value="all">Status: All</option>
        {#each columns as c}
          <option value={c.id}>{c.label}</option>
        {/each}
      </select>

      <!-- Workstream Filter Pill -->
      <select class="clickup-filter-pill" bind:value={workstreamFilter}>
        <option value="all">Workstream: All</option>
        {#each workstreamChips.filter(w => w !== 'all') as ws}
          <option value={ws}>{ws}</option>
        {/each}
      </select>

      <!-- Me Mode Toggle -->
      <button
        type="button"
        class="me-mode-btn"
        class:active={myTasksOnly}
        onclick={() => (myTasksOnly = !myTasksOnly)}
        title="Toggle Me Mode (Show only assigned to me)"
      >
        <FluentIcons name="user" size={14} />
      </button>

      <!-- Search Box -->
      <div class="clickup-search-box">
        <FluentIcons name="search" size={13} color="var(--text-secondary)" />
        <input
          type="text"
          placeholder="Search Ctrl K"
          bind:value={searchQuery}
          class="clickup-search-input"
        />
        {#if searchQuery}
          <button type="button" class="clear-btn" onclick={() => (searchQuery = '')}>✕</button>
        {/if}
      </div>
    </div>
  </div>

  <!-- ═══ MAIN WORKSPACE VIEW ROUTER ════════════════════════════════ -->
  {#if isLoading && tasks.length === 0}
    <div class="loading-state">
      <div class="spinner"></div>
      <span>Loading ClickUp Studio Tasks…</span>
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       1. OVERVIEW VIEW (Inspired by Screenshot 3)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'overview'}
    <div class="overview-view-container">
      <!-- Lists Progress Table Card -->
      <div class="overview-card">
        <div class="overview-card-header">
          <h3 class="card-title">Lists</h3>
          <span class="refresh-subtext">Refreshed just now</span>
        </div>

        <table class="overview-lists-table">
          <thead>
            <tr>
              <th>Name</th>
              <th style="width: 80px;">Color</th>
              <th style="width: 280px;">Progress</th>
              <th style="width: 100px;">Start</th>
              <th style="width: 100px;">End</th>
              <th style="width: 90px;">Priority</th>
              <th style="width: 90px;">Owner</th>
            </tr>
          </thead>
          <tbody>
            {#each workstreamGroups as group}
              <tr class="overview-list-row" onclick={() => { workstreamFilter = group.workstream; viewMode = 'list'; }}>
                <td class="ws-name-cell">
                  <FluentIcons name="list" size={14} color="#0284C7" />
                  <strong>{group.workstream}</strong>
                </td>
                <td>
                  <span class="color-bullet" style="background: #0284C7;"></span>
                </td>
                <td>
                  <div class="progress-bar-cell">
                    <div class="progress-track">
                      <div class="progress-fill" style="width: {group.percent}%;"></div>
                    </div>
                    <span class="progress-count">{group.completed}/{group.total}</span>
                  </div>
                </td>
                <td><FluentIcons name="calendar" size={12} color="var(--text-secondary)" /></td>
                <td><FluentIcons name="calendar" size={12} color="var(--text-secondary)" /></td>
                <td><FluentIcons name="flag" size={12} color="#CBD5E1" /></td>
                <td><FluentIcons name="user" size={12} color="var(--text-secondary)" /></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Bottom Split: Resources & Workload by Status -->
      <div class="overview-bottom-grid">
        <div class="overview-card">
          <div class="overview-card-header">
            <h3 class="card-title">Resources</h3>
          </div>
          <div class="drop-resources-zone">
            <FluentIcons name="upload" size={24} color="var(--text-secondary)" />
            <p>Drop files here or attach project briefs</p>
          </div>
        </div>

        <div class="overview-card">
          <div class="overview-card-header">
            <h3 class="card-title">Workload by Status</h3>
          </div>
          <div class="workload-breakdown-row">
            <div class="donut-chart-mock">
              <FluentIcons name="pieChart" size={64} color="#0284C7" />
              <div class="donut-center-label">
                <strong>{tasks.length}</strong>
                <span>Tasks</span>
              </div>
            </div>
            <div class="donut-legend">
              {#each columns as col}
                {@const cCount = tasks.filter(t => t.status === col.id).length}
                <div class="legend-row">
                  <span class="legend-dot" style="background: {col.color};"></span>
                  <span class="legend-name">{col.label}</span>
                  <span class="legend-val">{cCount}</span>
                </div>
              {/each}
            </div>
          </div>
        </div>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       2. LIST VIEW (Exact ClickUp Arrangement - Screenshot 2)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'list'}
    <div class="clickup-list-container">
      {#each workstreamGroups as group}
        <div class="workstream-folder-block">
          <!-- Folder Header with Breadcrumb & Expand -->
          <div class="folder-header" onclick={() => toggleWorkstreamExpand(group.workstream)} role="button" tabindex="0" onkeydown={() => {}}>
            <div class="breadcrumb-trail">
              <span>SS Creative Studio</span>
            </div>
            <div class="folder-title-row">
              <span class="caret-icon">
                <FluentIcons name={expandedWorkstreams[group.workstream] ? 'chevronDown' : 'chevronRight'} size={14} />
              </span>
              <h2 class="folder-name">{group.workstream}</h2>
              <span class="folder-actions-ellipsis">•••</span>
            </div>
          </div>

          {#if expandedWorkstreams[group.workstream]}
            <!-- Status Groups inside Folder -->
            {#each group.statusGroups as sGroup}
              {#if sGroup.tasks.length > 0 || inlineCreateParent?.workstream === group.workstream}
                <div class="status-group-section">
                  <!-- Status Header Row -->
                  <div class="status-group-header">
                    <span class="status-circle-badge" style="border-color: {sGroup.color};"></span>
                    <span class="status-label-text" style="color: {sGroup.color};">{sGroup.label}</span>
                    <span class="status-count-badge">{sGroup.tasks.length}</span>
                  </div>

                  <!-- Column Headers for the Group -->
                  <div class="list-columns-header">
                    <div class="col-head name-col">Name</div>
                    <div class="col-head assignee-col">Assignee</div>
                    <div class="col-head due-col">Due date</div>
                    <div class="col-head priority-col">Priority</div>
                    <div class="col-head add-col">＋</div>
                  </div>

                  <!-- Task Rows -->
                  <div class="group-task-rows">
                    {#each sGroup.tasks as task (task.id)}
                      {@const pMeta = getPriorityMeta(task.priority)}
                      {@const hasSubtasks = (task.subtasks || []).length > 0}
                      {@const isSubExpanded = !!expandedTaskIds[task.id]}
                      {@const blockers = getBlockers(task)}

                      <div class="task-tree-node">
                        <!-- Main Task Row -->
                        <div
                          class="clickup-task-row"
                          onclick={() => openTaskDetail(task)}
                          role="button"
                          tabindex="0"
                          onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
                        >
                          <!-- Left: Expand caret, Status check, Title & Link Icons -->
                          <div class="row-cell-name">
                            {#if hasSubtasks}
                              <button
                                type="button"
                                class="subtasks-expand-caret"
                                onclick={(e) => { e.stopPropagation(); toggleTaskSubtasks(task.id); }}
                                title="Expand Subtasks"
                              >
                                <FluentIcons name={isSubExpanded ? 'chevronDown' : 'chevronRight'} size={12} />
                              </button>
                            {:else}
                              <span class="empty-caret-spacer"></span>
                            {/if}

                            <!-- Status Circle Toggle -->
                            <button
                              type="button"
                              class="status-circle-btn"
                              class:is-done={task.status === 'done' || task.status === 'converted'}
                              style="border-color: {sGroup.color};"
                              onclick={(e) => {
                                e.stopPropagation();
                                handleInlineStatusChange(task, task.status === 'done' ? 'backlog' : 'done');
                              }}
                              title="Toggle status"
                            >
                              {#if task.status === 'done' || task.status === 'converted'}
                                <FluentIcons name="checkmark" size={10} color="#10B981" />
                              {/if}
                            </button>

                            <!-- Task Title -->
                            <span class="task-title-label">{task.title}</span>

                            <!-- ClickUp Dependency / Subtasks Indicators -->
                            {#if blockers.length > 0}
                              <span class="link-badge blocker" title="Waiting on {blockers.map(b => b.id).join(', ')}">
                                <FluentIcons name="link" size={11} color="#D97706" />
                                <span>{blockers.length}</span>
                              </span>
                            {/if}

                            {#if hasSubtasks}
                              <span class="link-badge subtasks" title="{task.subtasks?.length} Subtasks">
                                <FluentIcons name="list" size={11} color="var(--text-secondary)" />
                                <span>{task.subtasks?.length}</span>
                              </span>
                            {/if}
                          </div>

                          <!-- Assignee -->
                          <div class="row-cell-assignee">
                            {#if task.assignee}
                              <div
                                class="assignee-avatar-circle"
                                style="background: {task.assigneeAvatarColor || '#0078D4'};"
                                title="{task.assigneeName || task.assignee}"
                              >
                                {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                              </div>
                            {:else}
                              <span class="empty-assignee-ghost" title="Unassigned">
                                <FluentIcons name="user" size={13} color="#94A3B8" />
                              </span>
                            {/if}
                          </div>

                          <!-- Due Date -->
                          <div class="row-cell-due">
                            {#if task.dueDate}
                              <span class="due-text" class:overdue={isOverdue(task.dueDate, task.status)}>
                                {formatDateShort(task.dueDate)}
                              </span>
                            {:else}
                              <FluentIcons name="calendar" size={13} color="#CBD5E1" />
                            {/if}
                          </div>

                          <!-- Priority Flag -->
                          <div class="row-cell-priority">
                            <span class="priority-flag-wrap" title="Priority: {pMeta.label}">
                              <FluentIcons name="flag" size={13} color={pMeta.color} />
                              <span class="p-name" style="color: {pMeta.color};">{pMeta.label}</span>
                            </span>
                          </div>

                          <!-- Action Adder -->
                          <div class="row-cell-add">
                            <span class="row-more-dots">•••</span>
                          </div>
                        </div>

                        <!-- Nested Subtasks (ClickUp exact indentation) -->
                        {#if isSubExpanded && task.subtasks}
                          <div class="nested-subtasks-tree">
                            {#each task.subtasks as sub}
                              <div class="nested-subtask-row" class:completed={sub.completed}>
                                <div class="sub-indent-elbow"></div>
                                <input
                                  type="checkbox"
                                  checked={sub.completed}
                                  onchange={() => handleInlineSubtaskToggle(task, sub.id)}
                                  class="clickup-checkbox"
                                />
                                <span class="subtask-text">{sub.title}</span>
                              </div>
                            {/each}
                          </div>
                        {/if}
                      </div>
                    {/each}

                    <!-- Inline Add Task Row -->
                    {#if inlineCreateParent?.workstream === group.workstream && inlineCreateParent?.status === sGroup.status}
                      <div class="inline-task-create-row">
                        <span class="status-circle-btn dashed"></span>
                        <input
                          type="text"
                          class="inline-task-input"
                          placeholder="Task Name... (press Enter to create)"
                          bind:value={inlineTaskTitle}
                          onkeydown={(e) => {
                            if (e.key === 'Enter') handleQuickInlineCreate(group.workstream, sGroup.status);
                            if (e.key === 'Escape') inlineCreateParent = null;
                          }}
                          autofocus
                        />
                        <button type="button" class="btn-save-inline" onclick={() => handleQuickInlineCreate(group.workstream, sGroup.status)}>
                          Save
                        </button>
                        <button type="button" class="btn-cancel-inline" onclick={() => (inlineCreateParent = null)}>
                          ✕
                        </button>
                      </div>
                    {:else}
                      <button
                        type="button"
                        class="add-task-inline-btn"
                        onclick={() => {
                          inlineCreateParent = { workstream: group.workstream, status: sGroup.status };
                          inlineTaskTitle = '';
                        }}
                      >
                        <FluentIcons name="plus" size={12} />
                        <span>Add Task</span>
                      </button>
                    {/if}
                  </div>
                </div>
              {/if}
            {/each}
          {/if}
        </div>
      {/each}
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       3. BOARD VIEW (Kanban Columns)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'board'}
    <div class="clickup-board-grid">
      {#each columns as col}
        {@const colTasks = filteredTasks.filter(t => t.status === col.id || (col.id === 'done' && t.status === 'converted'))}
        <div
          class="board-column"
          class:drag-over={dragOverCol === col.id}
          ondragover={(e) => handleDragOver(e, col.id)}
          ondragleave={() => handleDragLeave(col.id)}
          ondrop={(e) => handleDrop(e, col.id)}
          role="region"
          aria-label="{col.label} column"
        >
          <!-- Column Header -->
          <div class="board-col-header" style="border-top-color: {col.color};">
            <span class="col-title-text">{col.label}</span>
            <span class="col-count-pill">{colTasks.length}</span>
            <button
              type="button"
              class="col-add-btn"
              onclick={() => {
                inlineCreateParent = { status: col.id };
                isCreateModalOpen = true;
              }}
              title="Add task to {col.label}"
            >
              ＋
            </button>
          </div>

          <!-- Cards List -->
          <div class="board-col-cards">
            {#each colTasks as task (task.id)}
              {@const pMeta = getPriorityMeta(task.priority)}
              {@const subMeta = getSubtasksMeta(task.subtasks)}
              {@const blockers = getBlockers(task)}

              <!-- svelte-ignore a11y_click_events_have_key_events -->
              <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
              <div
                class="board-card"
                class:overdue={isOverdue(task.dueDate, task.status)}
                draggable="true"
                ondragstart={(e) => handleDragStart(e, task)}
                onclick={() => openTaskDetail(task)}
                role="button"
                tabindex="0"
              >
                <!-- Workstream & Priority -->
                <div class="card-meta-top">
                  <span class="ws-tag">{task.workstream || 'General'}</span>
                  <span class="priority-flag" title="Priority: {pMeta.label}">
                    <FluentIcons name="flag" size={13} color={pMeta.color} />
                  </span>
                </div>

                <!-- Title -->
                <h4 class="card-name">{task.title}</h4>

                <!-- Blocker Alert -->
                {#if blockers.length > 0}
                  <div class="card-blocker-pill">
                    <FluentIcons name="warning" size={12} color="#D97706" />
                    <span>Waiting on {blockers.map(b => b.id).join(', ')}</span>
                  </div>
                {/if}

                <!-- Subtasks Progress -->
                {#if subMeta.total > 0}
                  <div class="card-sub-glance">
                    <div class="sub-track">
                      <div class="sub-fill" style="width: {subMeta.percent}%;"></div>
                    </div>
                    <span>{subMeta.completed}/{subMeta.total} subtasks</span>
                  </div>
                {/if}

                <!-- Card Bottom: Assignee & Due Date -->
                <div class="card-meta-bottom">
                  {#if task.assignee}
                    <div class="assignee-avatar-circle sm" style="background: {task.assigneeAvatarColor || '#0078D4'};">
                      {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                    </div>
                  {:else}
                    <FluentIcons name="user" size={13} color="#94A3B8" />
                  {/if}

                  {#if task.dueDate}
                    <span class="date-chip" class:overdue={isOverdue(task.dueDate, task.status)}>
                      <FluentIcons name="calendar" size={11} />
                      {formatDateShort(task.dueDate)}
                    </span>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       4. GANTT / TIMELINE VIEW (Exact ClickUp Split Layout - Image 1 & 4)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'gantt'}
    <div class="clickup-gantt-wrapper">
      <!-- Gantt Sub-Toolbar -->
      <div class="gantt-sub-toolbar">
        <div class="toolbar-left">
          <button type="button" class="gantt-btn today-btn">Today</button>
          <button type="button" class="gantt-btn dropdown-btn">
            <span>Week</span>
            <FluentIcons name="chevronDown" size={12} />
          </button>
          <button type="button" class="gantt-btn">Auto fit</button>
          <button type="button" class="gantt-btn">Export</button>
        </div>

        <div class="toolbar-right">
          <span class="save-view-pill">Save view ▾</span>
          <div class="zoom-controls">
            <button type="button" class="zoom-btn">＋</button>
            <button type="button" class="zoom-btn">−</button>
          </div>
        </div>
      </div>

      <!-- Gantt 2-Pane Splitter View -->
      <div class="gantt-split-container">
        <!-- Left Pane: Hierarchical Tree Column -->
        <div class="gantt-left-tree">
          <div class="gantt-tree-header">
            <span class="tree-col-name">Name</span>
            <span class="tree-col-assignee">Assignee(s)</span>
            <span class="tree-col-due">Due Date</span>
            <span class="tree-col-priority">Priority</span>
            <span class="tree-col-add">＋</span>
          </div>

          <div class="gantt-tree-rows">
            <!-- Root Space Row -->
            <div class="tree-row root-space">
              <span class="caret-icon">▾</span>
              <FluentIcons name="box" size={13} color="var(--brand-accent)" />
              <strong class="row-name">SS Creative Studio</strong>
            </div>

            <!-- Folders & Tasks -->
            {#each workstreamGroups as group}
              <div class="tree-row folder-row" onclick={() => toggleWorkstreamExpand(group.workstream)} role="none">
                <span class="caret-icon">
                  <FluentIcons name={expandedWorkstreams[group.workstream] ? 'chevronDown' : 'chevronRight'} size={12} />
                </span>
                <FluentIcons name="folder" size={13} color="#0284C7" />
                <span class="row-name">{group.workstream}</span>
              </div>

              {#if expandedWorkstreams[group.workstream]}
                {#each group.tasks as task}
                  {@const pMeta = getPriorityMeta(task.priority)}
                  {@const hasSub = (task.subtasks || []).length > 0}
                  {@const isSubExp = !!expandedTaskIds[task.id]}

                  <div
                    class="tree-row task-row"
                    onclick={() => openTaskDetail(task)}
                    role="button"
                    tabindex="0"
                    onkeydown={() => {}}
                  >
                    {#if hasSub}
                      <button
                        type="button"
                        class="subtasks-expand-caret"
                        onclick={(e) => { e.stopPropagation(); toggleTaskSubtasks(task.id); }}
                      >
                        <FluentIcons name={isSubExp ? 'chevronDown' : 'chevronRight'} size={11} />
                      </button>
                    {:else}
                      <span class="empty-caret-spacer"></span>
                    {/if}

                    <span class="status-circle-dot" class:done={task.status === 'done'}></span>
                    <span class="row-name task-title-truncated">{task.title}</span>

                    <!-- Assignee -->
                    <span class="tree-cell-assignee">
                      {#if task.assignee}
                        <div class="assignee-avatar-circle xs" style="background: {task.assigneeAvatarColor || '#0078D4'};">
                          {(task.assigneeName || task.assignee || 'U').substring(0, 1)}
                        </div>
                      {:else}
                        <FluentIcons name="user" size={12} color="#CBD5E1" />
                      {/if}
                    </span>

                    <!-- Due Date -->
                    <span class="tree-cell-due">
                      <FluentIcons name="calendar" size={12} color={task.dueDate ? '#64748B' : '#CBD5E1'} />
                    </span>

                    <!-- Priority Flag -->
                    <span class="tree-cell-priority">
                      <FluentIcons name="flag" size={12} color={pMeta.color} />
                    </span>
                  </div>

                  <!-- Subtasks in Tree -->
                  {#if isSubExp && task.subtasks}
                    {#each task.subtasks as sub}
                      <div class="tree-row subtask-row">
                        <span class="sub-elbow"></span>
                        <span class="status-circle-dot sm"></span>
                        <span class="row-name">{sub.title}</span>
                      </div>
                    {/each}
                  {/if}
                {/each}
              {/if}
            {/each}
          </div>
        </div>

        <!-- Right Pane: Calendar Grid & Schedule Bars -->
        <div class="gantt-right-calendar">
          <!-- Calendar Timeline Header -->
          <div class="gantt-calendar-header">
            <!-- Weeks Header -->
            <div class="weeks-row">
              <span class="week-label">W40 Oct 5 – 11</span>
              <span class="week-label">W41 Oct 12 – 18</span>
            </div>

            <!-- Days Header -->
            <div class="days-row">
              {#each ganttDates as d}
                {@const isToday = d.toDateString() === todayDate.toDateString()}
                {@const isWeekend = d.getDay() === 0 || d.getDay() === 6}
                <div class="day-cell-head" class:is-today={isToday} class:is-weekend={isWeekend}>
                  <span class="day-short">{d.toLocaleDateString('en-US', { weekday: 'narrow' })}</span>
                  <span class="day-number-bubble" class:today-bubble={isToday}>{d.getDate()}</span>
                </div>
              {/each}
            </div>
          </div>

          <!-- Calendar Body with Vertical Guidelines & Task Bars -->
          <div class="gantt-calendar-body">
            <!-- Space Row Alignment Placeholder -->
            <div class="grid-row-spacer"></div>

            {#each workstreamGroups as group}
              <!-- Folder Spacer -->
              <div class="grid-row-spacer"></div>

              {#if expandedWorkstreams[group.workstream]}
                {#each group.tasks as task}
                  {@const bar = getGanttBarStyle(task, ganttDates)}
                  {@const isSubExp = !!expandedTaskIds[task.id]}

                  <div class="gantt-grid-task-row">
                    <!-- Day Columns Background Grid -->
                    {#each ganttDates as d}
                      {@const isToday = d.toDateString() === todayDate.toDateString()}
                      {@const isWeekend = d.getDay() === 0 || d.getDay() === 6}
                      <div class="gantt-bg-day-col" class:is-today={isToday} class:is-weekend={isWeekend}>
                        {#if isToday}
                          <div class="vertical-today-red-line"></div>
                        {/if}
                      </div>
                    {/each}

                    <!-- Floating Task Schedule Bar -->
                    {#if bar.isMilestone}
                      <div
                        class="gantt-milestone-point"
                        style="left: {bar.left};"
                        onclick={() => openTaskDetail(task)}
                        role="none"
                        title="{task.title}"
                      ></div>
                    {:else}
                      <div
                        class="gantt-schedule-bar status-{task.status}"
                        style="left: {bar.left}; width: {bar.width};"
                        onclick={() => openTaskDetail(task)}
                        role="none"
                        title="{task.title} ({task.status})"
                      >
                        <span class="bar-handle-left">&lt;</span>
                        <span class="bar-title-text">{task.title}</span>
                      </div>
                    {/if}
                  </div>

                  <!-- Subtask Rows Spacers if expanded -->
                  {#if isSubExp && task.subtasks}
                    {#each task.subtasks as _}
                      <div class="grid-row-spacer"></div>
                    {/each}
                  {/if}
                {/each}
              {/if}
            {/each}
          </div>
        </div>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       5. TABLE VIEW (Exact ClickUp Spreadsheet Grid - Screenshot 5)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'table'}
    <div class="clickup-table-container">
      <table class="clickup-data-table">
        <thead>
          <tr>
            <th style="width: 32px; text-align: center;"><input type="checkbox" class="clickup-checkbox" /></th>
            <th style="width: 40px; text-align: center;">#</th>
            <th>Name</th>
            <th style="width: 180px;">Assignee</th>
            <th style="width: 140px;">Status</th>
            <th style="width: 120px;">Due date</th>
            <th style="width: 120px;">Priority</th>
            <th style="width: 40px; text-align: center;">＋</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredTasks as task, idx (task.id)}
            {@const pMeta = getPriorityMeta(task.priority)}
            {@const blockers = getBlockers(task)}
            <tr
              class="clickup-table-row"
              onclick={() => openTaskDetail(task)}
              role="button"
              tabindex="0"
              onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
            >
              <!-- Checkbox -->
              <td style="text-align: center;" onclick={(e) => e.stopPropagation()} role="none">
                <input type="checkbox" class="clickup-checkbox" />
              </td>

              <!-- Row Index -->
              <td class="row-num-cell">{idx + 1}</td>

              <!-- Name with ClickUp Status Circle -->
              <td class="name-cell">
                <span class="status-circle-dot" class:done={task.status === 'done'}></span>
                <span class="table-task-title">{task.title}</span>
                {#if blockers.length > 0}
                  <span class="link-badge blocker" title="Waiting on prerequisite">
                    <FluentIcons name="link" size={10} color="#D97706" />
                    <span>{blockers.length}</span>
                  </span>
                {/if}
              </td>

              <!-- Assignee (Avatar + Full Name) -->
              <td>
                {#if task.assignee}
                  <div class="table-assignee-flex">
                    <div class="assignee-avatar-circle xs" style="background: {task.assigneeAvatarColor || '#0078D4'};">
                      {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                    </div>
                    <span class="assignee-full-name">{task.assigneeName || task.assignee}</span>
                  </div>
                {:else}
                  <span class="empty-val">—</span>
                {/if}
              </td>

              <!-- Status Pill (ClickUp Signature Rounded Pill) -->
              <td onclick={(e) => e.stopPropagation()} role="none">
                <select
                  class="clickup-status-pill status-{task.status}"
                  value={task.status}
                  onchange={(e) => handleInlineStatusChange(task, (e.target as HTMLSelectElement).value as StudioTaskStatus)}
                >
                  <option value="backlog">TO DO</option>
                  <option value="in-progress">IN PROGRESS</option>
                  <option value="review">REVIEW</option>
                  <option value="done">COMPLETE</option>
                </select>
              </td>

              <!-- Due Date -->
              <td>
                {#if task.dueDate}
                  <span class="table-due-date" class:overdue={isOverdue(task.dueDate, task.status)}>
                    {formatDateShort(task.dueDate)}
                  </span>
                {:else}
                  <span class="empty-val">—</span>
                {/if}
              </td>

              <!-- Priority Flag -->
              <td>
                <span class="table-priority-wrap">
                  <FluentIcons name="flag" size={13} color={pMeta.color} />
                  <span style="color: {pMeta.color}; font-weight: 500;">{pMeta.label}</span>
                </span>
              </td>

              <!-- Adder -->
              <td style="text-align: center;">
                <span class="table-more">•••</span>
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
  allTasks={tasks}
  {staffRoster}
  onClose={() => { isDetailDrawerOpen = false; selectedTask = null; }}
  onUpdated={handleTaskUpdated}
  onDeleted={handleTaskDeleted}
/>

<style>
  /* ═══ CLICKUP DESIGN SYSTEM & TOKENS ═══════════════════════════ */
  .clickup-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    min-height: calc(100vh - 60px);
    background: var(--surface-card);
    color: var(--text-primary);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }

  /* ═══ 1. TOP SUB-HEADER ═════════════════════════════════════════ */
  .clickup-top-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }

  .header-left-cluster {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .space-title-dropdown {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .space-icon-dot {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    background: #0284C7;
  }

  .space-name {
    font-size: 16px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }

  .favorite-star {
    font-size: 16px;
    color: var(--text-secondary);
    cursor: pointer;
  }

  .header-right-tools {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .tool-ghost-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    border: none;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 500;
    padding: 6px 10px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .tool-ghost-btn:hover {
    background: var(--surface-card-subtle);
    color: var(--text-primary);
  }
  .tool-ghost-btn.ai-btn {
    color: #8B5CF6;
    font-weight: 600;
  }

  .tool-divider {
    width: 1px;
    height: 18px;
    background: var(--surface-card-border);
    margin: 0 4px;
  }

  /* ClickUp Signature Solid Blue Add Task Button */
  .clickup-add-task-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: #0078D4;
    color: #FFF;
    border: none;
    border-radius: 6px;
    padding: 7px 14px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .clickup-add-task-btn:hover {
    background: #0284C7;
  }

  /* ═══ 2. VIEWS NAVIGATION STRIP ═════════════════════════════════ */
  .clickup-views-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }

  .views-tabs-list {
    display: flex;
    gap: 4px;
  }

  .view-tab {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 10px 14px;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    position: relative;
    transition: color 0.15s ease;
  }
  .view-tab:hover {
    color: var(--text-primary);
  }
  .view-tab.active {
    color: var(--brand-accent, #0078D4);
    font-weight: 600;
  }
  .view-tab.active::after {
    content: '';
    position: absolute;
    bottom: -1px;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--brand-accent, #0078D4);
  }
  .view-tab.gantt-tab.active {
    color: #EF4444;
  }
  .view-tab.gantt-tab.active::after {
    background: #EF4444;
  }

  .views-sub-controls {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .clickup-filter-pill {
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 500;
    cursor: pointer;
  }

  .me-mode-btn {
    width: 28px;
    height: 28px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-secondary);
    cursor: pointer;
  }
  .me-mode-btn.active {
    background: rgba(0, 120, 212, 0.12);
    border-color: #0078D4;
    color: #0078D4;
  }

  .clickup-search-box {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    padding: 3px 8px;
    width: 160px;
  }
  .clickup-search-input {
    border: none;
    background: transparent;
    font-size: 11px;
    color: var(--text-primary);
    width: 100%;
  }
  .clickup-search-input:focus { outline: none; }
  .clear-btn { background: transparent; border: none; font-size: 10px; cursor: pointer; color: var(--text-secondary); }

  /* ═══ 3. OVERVIEW VIEW ══════════════════════════════════════════ */
  .overview-view-container {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .overview-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 16px 20px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  }

  .overview-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .card-title {
    font-size: 15px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }
  .refresh-subtext {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .overview-lists-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  .overview-lists-table th {
    text-align: left;
    font-size: 11px;
    color: var(--text-secondary);
    padding: 8px 10px;
    border-bottom: 1px solid var(--surface-card-border);
  }
  .overview-lists-table td {
    padding: 12px 10px;
    border-bottom: 1px solid var(--surface-card-border);
  }
  .overview-list-row {
    cursor: pointer;
  }
  .overview-list-row:hover {
    background: var(--surface-card-subtle);
  }
  .ws-name-cell {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .color-bullet {
    display: inline-block;
    width: 14px;
    height: 4px;
    border-radius: 2px;
  }

  .progress-bar-cell {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .progress-track {
    flex: 1;
    height: 6px;
    border-radius: 3px;
    background: var(--surface-card-border);
    overflow: hidden;
  }
  .progress-fill {
    height: 100%;
    background: #0284C7;
  }
  .progress-count {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .overview-bottom-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }

  .drop-resources-zone {
    height: 160px;
    border: 2px dashed var(--surface-card-border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    color: var(--text-secondary);
    font-size: 13px;
  }

  .workload-breakdown-row {
    display: flex;
    align-items: center;
    gap: 32px;
    height: 160px;
  }
  .donut-chart-mock {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .donut-center-label {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    font-size: 11px;
  }
  .donut-center-label strong { font-size: 15px; }
  .donut-legend {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .legend-row {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
  }
  .legend-dot { width: 8px; height: 8px; border-radius: 50%; }
  .legend-name { color: var(--text-secondary); min-width: 100px; }
  .legend-val { font-weight: 700; color: var(--text-primary); }

  /* ═══ 4. CLICKUP LIST VIEW (SCREENSHOT 2) ═══════════════════════ */
  .clickup-list-container {
    padding: 16px 24px;
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  .workstream-folder-block {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .folder-header {
    display: flex;
    flex-direction: column;
    gap: 2px;
    cursor: pointer;
  }
  .breadcrumb-trail {
    font-size: 11px;
    color: var(--text-secondary);
  }
  .folder-title-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .folder-name {
    font-size: 16px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }
  .folder-actions-ellipsis {
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
    margin-left: 6px;
  }

  .status-group-section {
    display: flex;
    flex-direction: column;
    margin-bottom: 12px;
  }

  .status-group-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 0;
  }
  .status-circle-badge {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 2px solid #94A3B8;
  }
  .status-label-text {
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.5px;
  }
  .status-count-badge {
    font-size: 11px;
    color: var(--text-secondary);
    font-weight: 600;
  }

  .list-columns-header {
    display: flex;
    align-items: center;
    padding: 6px 12px;
    font-size: 11px;
    color: var(--text-secondary);
    border-bottom: 1px solid var(--surface-card-border);
  }
  .name-col { flex: 1; }
  .assignee-col { width: 140px; }
  .due-col { width: 120px; }
  .priority-col { width: 110px; }
  .add-col { width: 30px; text-align: center; }

  .group-task-rows {
    display: flex;
    flex-direction: column;
  }

  .clickup-task-row {
    display: flex;
    align-items: center;
    padding: 7px 12px;
    border-bottom: 1px solid var(--surface-card-border);
    cursor: pointer;
    font-size: 13px;
    transition: background 0.1s ease;
  }
  .clickup-task-row:hover {
    background: var(--surface-card-subtle);
  }

  .row-cell-name {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  .subtasks-expand-caret {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    color: var(--text-secondary);
    display: inline-flex;
    align-items: center;
  }
  .empty-caret-spacer {
    width: 12px;
  }

  .status-circle-btn {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    border: 1.5px dashed #94A3B8;
    background: transparent;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
  }
  .status-circle-btn.is-done {
    border-style: solid;
    background: rgba(16, 185, 129, 0.1);
  }

  .task-title-label {
    font-weight: 500;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .link-badge {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-size: 10px;
    padding: 1px 4px;
    border-radius: 3px;
  }
  .link-badge.blocker {
    background: rgba(245, 158, 11, 0.15);
    color: #B45309;
  }
  .link-badge.subtasks {
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
  }

  .row-cell-assignee {
    width: 140px;
    display: flex;
    align-items: center;
  }
  .assignee-avatar-circle {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    color: #FFF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 9px;
    font-weight: 700;
  }
  .assignee-avatar-circle.xs { width: 18px; height: 18px; font-size: 8px; }

  .row-cell-due {
    width: 120px;
    display: flex;
    align-items: center;
    font-size: 11px;
    color: var(--text-secondary);
  }
  .due-text.overdue {
    color: #EF4444;
    font-weight: 600;
  }

  .row-cell-priority {
    width: 110px;
    display: flex;
    align-items: center;
  }
  .priority-flag-wrap {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
  }

  .row-cell-add {
    width: 30px;
    text-align: center;
    color: var(--text-secondary);
  }

  .nested-subtasks-tree {
    display: flex;
    flex-direction: column;
    padding-left: 36px;
    background: var(--surface-card-subtle);
  }
  .nested-subtask-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    font-size: 12px;
    border-bottom: 1px dashed var(--surface-card-border);
  }
  .nested-subtask-row.completed .subtask-text {
    text-decoration: line-through;
    color: var(--text-secondary);
  }
  .sub-indent-elbow {
    width: 10px;
    height: 10px;
    border-left: 1px solid var(--surface-card-border);
    border-bottom: 1px solid var(--surface-card-border);
  }

  .add-task-inline-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    background: transparent;
    border: none;
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
  }
  .add-task-inline-btn:hover {
    color: var(--brand-accent);
  }

  .inline-task-create-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    background: var(--surface-card-subtle);
  }
  .inline-task-input {
    flex: 1;
    min-height: 28px;
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    font-size: 12px;
    color: var(--text-primary);
  }
  .btn-save-inline {
    padding: 4px 10px;
    border-radius: 4px;
    border: none;
    background: #0078D4;
    color: #FFF;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
  }
  .btn-cancel-inline {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
  }

  /* ═══ 5. BOARD VIEW ═════════════════════════════════════════════ */
  .clickup-board-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 16px;
    padding: 20px;
    align-items: start;
  }

  .board-column {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    min-height: 480px;
  }

  .board-col-header {
    border-top: 3px solid #64748B;
    border-top-left-radius: 7px;
    border-top-right-radius: 7px;
    padding: 10px 14px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: var(--surface-card);
    border-bottom: 1px solid var(--surface-card-border);
  }
  .col-title-text { font-size: 12px; font-weight: 700; color: var(--text-primary); }
  .col-count-pill { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  .col-add-btn { background: transparent; border: none; font-size: 14px; cursor: pointer; color: var(--text-secondary); }

  .board-col-cards {
    padding: 10px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .board-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    cursor: pointer;
    transition: all 0.12s ease;
  }
  .board-card:hover {
    border-color: #0078D4;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }
  .card-meta-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .ws-tag {
    font-size: 10px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 3px;
    background: rgba(0, 120, 212, 0.08);
    color: #0078D4;
  }
  .card-name {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
  }
  .card-blocker-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    background: rgba(245, 158, 11, 0.15);
    color: #B45309;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .card-sub-glance {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 10px;
    color: var(--text-secondary);
  }
  .sub-track { height: 3px; border-radius: 2px; background: var(--surface-card-border); overflow: hidden; }
  .sub-fill { height: 100%; background: #10B981; }

  .card-meta-bottom {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 6px;
    border-top: 1px solid var(--surface-card-border);
  }
  .date-chip { font-size: 10px; color: var(--text-secondary); display: inline-flex; align-items: center; gap: 3px; }
  .date-chip.overdue { color: #EF4444; font-weight: 600; }

  /* ═══ 6. GANTT / TIMELINE SPLIT (SCREENSHOT 1 & 4) ══════════════ */
  .clickup-gantt-wrapper {
    display: flex;
    flex-direction: column;
    background: var(--surface-card);
  }

  .gantt-sub-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 18px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }
  .toolbar-left,
  .toolbar-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .gantt-btn {
    padding: 4px 10px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 11px;
    font-weight: 500;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .gantt-btn.today-btn { font-weight: 700; }
  .save-view-pill { font-size: 11px; color: #D97706; background: rgba(245, 158, 11, 0.1); padding: 3px 8px; border-radius: 4px; font-weight: 600; }
  .zoom-controls { display: flex; border: 1px solid var(--surface-card-border); border-radius: 4px; }
  .zoom-btn { background: transparent; border: none; padding: 2px 8px; cursor: pointer; }

  .gantt-split-container {
    display: flex;
    min-height: 520px;
    border-bottom: 1px solid var(--surface-card-border);
  }

  /* Left Tree Column */
  .gantt-left-tree {
    width: 360px;
    min-width: 360px;
    border-right: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    display: flex;
    flex-direction: column;
  }

  .gantt-tree-header {
    display: flex;
    align-items: center;
    padding: 10px 14px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    border-bottom: 1px solid var(--surface-card-border);
    height: 48px;
  }
  .tree-col-name { flex: 1; }
  .tree-col-assignee { width: 70px; }
  .tree-col-due { width: 50px; }
  .tree-col-priority { width: 50px; }
  .tree-col-add { width: 24px; text-align: right; }

  .gantt-tree-rows {
    display: flex;
    flex-direction: column;
  }

  .tree-row {
    display: flex;
    align-items: center;
    height: 32px;
    padding: 0 14px;
    font-size: 12px;
    border-bottom: 1px solid var(--surface-card-border);
    gap: 8px;
    cursor: pointer;
  }
  .tree-row:hover { background: var(--surface-card-subtle); }
  .tree-row.root-space { font-weight: 700; }
  .tree-row.folder-row { padding-left: 24px; font-weight: 600; }
  .tree-row.task-row { padding-left: 36px; }
  .tree-row.subtask-row { padding-left: 54px; font-size: 11px; color: var(--text-secondary); }

  .status-circle-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    border: 1px solid #94A3B8;
  }
  .status-circle-dot.done {
    background: #10B981;
    border-color: #10B981;
  }
  .status-circle-dot.sm { width: 6px; height: 6px; }
  .task-title-truncated {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .tree-cell-assignee { width: 70px; }
  .tree-cell-due { width: 50px; }
  .tree-cell-priority { width: 50px; }

  /* Right Calendar Grid */
  .gantt-right-calendar {
    flex: 1;
    overflow-x: auto;
    display: flex;
    flex-direction: column;
    background: var(--surface-card);
  }

  .gantt-calendar-header {
    display: flex;
    flex-direction: column;
    border-bottom: 1px solid var(--surface-card-border);
    height: 48px;
  }
  .weeks-row {
    display: flex;
    height: 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
  }
  .week-label {
    flex: 1;
    font-size: 10px;
    font-weight: 600;
    color: var(--text-secondary);
    padding: 2px 8px;
  }

  .days-row {
    display: flex;
    flex: 1;
  }
  .day-cell-head {
    flex: 1;
    min-width: 44px;
    border-right: 1px solid var(--surface-card-border);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
    font-size: 10px;
    color: var(--text-secondary);
  }
  .day-cell-head.is-weekend {
    background: rgba(0, 0, 0, 0.02);
  }
  .day-number-bubble.today-bubble {
    background: #EF4444;
    color: #FFF;
    border-radius: 50%;
    width: 16px;
    height: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
  }

  .gantt-calendar-body {
    display: flex;
    flex-direction: column;
    position: relative;
  }

  .grid-row-spacer {
    height: 32px;
    border-bottom: 1px solid var(--surface-card-border);
  }

  .gantt-grid-task-row {
    height: 32px;
    border-bottom: 1px solid var(--surface-card-border);
    position: relative;
    display: flex;
  }

  .gantt-bg-day-col {
    flex: 1;
    min-width: 44px;
    height: 100%;
    border-right: 1px solid var(--surface-card-border);
    position: relative;
  }
  .gantt-bg-day-col.is-weekend {
    background: rgba(0, 0, 0, 0.02);
  }

  .vertical-today-red-line {
    position: absolute;
    top: 0;
    bottom: 0;
    left: 50%;
    width: 1.5px;
    background: #EF4444;
    z-index: 1;
  }

  .gantt-schedule-bar {
    position: absolute;
    top: 5px;
    height: 22px;
    border-radius: 4px;
    background: #0284C7;
    color: #FFF;
    display: flex;
    align-items: center;
    padding: 0 6px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.15);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    z-index: 2;
  }
  .bar-handle-left { font-size: 10px; margin-right: 4px; opacity: 0.8; }
  .gantt-schedule-bar.status-backlog { background: #64748B; }
  .gantt-schedule-bar.status-in-progress { background: #0284C7; }
  .gantt-schedule-bar.status-review { background: #8B5CF6; }
  .gantt-schedule-bar.status-done { background: #10B981; }

  .gantt-milestone-point {
    position: absolute;
    top: 10px;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #F59E0B;
    z-index: 2;
    cursor: pointer;
  }

  /* ═══ 7. TABLE VIEW (SCREENSHOT 5) ══════════════════════════════ */
  .clickup-table-container {
    padding: 0;
    background: var(--surface-card);
    overflow-x: auto;
  }

  .clickup-data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  .clickup-data-table th {
    text-align: left;
    padding: 8px 10px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    border-bottom: 1px solid var(--surface-card-border);
    border-right: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }
  .clickup-data-table td {
    padding: 6px 10px;
    border-bottom: 1px solid var(--surface-card-border);
    border-right: 1px solid var(--surface-card-border);
  }
  .clickup-table-row {
    cursor: pointer;
  }
  .clickup-table-row:hover {
    background: var(--surface-card-subtle);
  }

  .row-num-cell {
    text-align: center;
    color: var(--text-secondary);
    font-size: 11px;
  }

  .name-cell {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .table-task-title {
    font-weight: 500;
    color: var(--text-primary);
  }

  .table-assignee-flex {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .assignee-full-name {
    font-size: 11px;
    color: var(--text-primary);
  }

  /* ClickUp Status Pill */
  .clickup-status-pill {
    padding: 3px 8px;
    border-radius: 12px;
    font-size: 10px;
    font-weight: 700;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    cursor: pointer;
  }
  .clickup-status-pill.status-backlog {
    border-color: #CBD5E1;
    color: #64748B;
  }
  .clickup-status-pill.status-in-progress {
    background: #0284C7;
    color: #FFF;
    border-color: #0284C7;
  }
  .clickup-status-pill.status-review {
    background: #8B5CF6;
    color: #FFF;
    border-color: #8B5CF6;
  }
  .clickup-status-pill.status-done {
    background: #10B981;
    color: #FFF;
    border-color: #10B981;
  }

  .table-due-date.overdue {
    color: #EF4444;
    font-weight: 600;
  }

  .table-priority-wrap {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
  }

  .empty-val {
    color: var(--text-secondary);
  }

  /* Loading */
  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    gap: 12px;
    color: var(--text-secondary);
  }
  .spinner {
    width: 24px;
    height: 24px;
    border: 3px solid var(--surface-card-border);
    border-top-color: #0078D4;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .clickup-checkbox {
    width: 14px;
    height: 14px;
    cursor: pointer;
  }
</style>

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

  // A/B Layout Mode: 'minimalist' (A: Focus & Speed) vs 'executive' (B: Full Operations & Telemetry)
  let layoutMode = $state<'minimalist' | 'executive'>(
    (typeof localStorage !== 'undefined' && localStorage.getItem('ss_cam_tasks_mode') === 'executive') ? 'executive' : 'minimalist'
  );

  function setLayoutMode(m: 'minimalist' | 'executive') {
    layoutMode = m;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ss_cam_tasks_mode', m);
    }
    if (m === 'minimalist' && viewMode === 'overview') {
      viewMode = 'list';
    }
  }

  // 5-View Switcher: overview | list | board | gantt | table
  let viewMode = $state<'overview' | 'list' | 'board' | 'gantt' | 'table'>('list');
  
  // Group By: status | workstream | priority
  let groupBy = $state<'status' | 'workstream' | 'priority'>('workstream');

  // Filters
  let brandFilter = $state('all');
  let priorityFilter = $state('all');
  let statusFilter = $state('all');
  let workstreamFilter = $state('all');
  let myTasksOnly = $state(false);
  let hideCompleted = $state(false);
  let searchQuery = $state('');
  
  let isCreateModalOpen = $state(false);

  // Selected task for detail drawer
  let selectedTask = $state<StudioTask | null>(null);
  let isDetailDrawerOpen = $state(false);

  // Table multi-selection & sorting
  let selectedTaskIds = $state<string[]>([]);
  let tableSortCol = $state<'title' | 'assignee' | 'status' | 'dueDate' | 'priority'>('title');
  let tableSortAsc = $state(true);

  // Timeline (Gantt) navigation state
  let timelineOffset = $state(0); // Offset in 7-day weeks

  // Expanded tree states for hierarchical List & Timeline
  let expandedWorkstreams = $state<Record<string, boolean>>({
    'General Operations': true,
    'Software & App Dev': true,
    'Packaging & Dieline': true,
    'Creative & Brand Identity': true,
    'Digital Marketing & Social': true,
    'Motion, Video & 3D': true,
    'QA & Compliance': true,
    'Executive & Strategy': true
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
    { id: 'backlog', label: 'Backlog', icon: 'circleDashed', color: '#64748B' },
    { id: 'in-progress', label: 'In Progress', icon: 'bolt', color: '#0284C7' },
    { id: 'review', label: 'Review', icon: 'search', color: '#F59E0B' },
    { id: 'done', label: 'Done', icon: 'checkCircle', color: '#10B981' }
  ];

  const brandChips = ['all', 'SS', 'SSH', 'SSC', 'SSW', 'SSE', 'SST'];
  const priorityChips = ['all', 'urgent', 'high', 'medium', 'low'];
  const workstreamChips = [
    'all',
    'General Operations',
    'Software & App Dev',
    'Packaging & Dieline',
    'Creative & Brand Identity',
    'Digital Marketing & Social',
    'Motion, Video & 3D',
    'QA & Compliance',
    'Executive & Strategy'
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

    const onKeydown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        const searchInput = document.querySelector<HTMLInputElement>('.clickup-search-input');
        if (searchInput) {
          searchInput.focus();
          searchInput.select();
        }
      }
    };
    window.addEventListener('keydown', onKeydown);

    return () => {
      window.removeEventListener('task:created', onTasksChanged);
      window.removeEventListener('task:updated', onTasksChanged);
      window.removeEventListener('task:deleted', onTasksChanged);
      window.removeEventListener('studio-task:created', onTasksChanged);
      window.removeEventListener('studio-task:updated', onTasksChanged);
      window.removeEventListener('studio-task:deleted', onTasksChanged);
      window.removeEventListener('workspace:updated', onTasksChanged);
      window.removeEventListener('keydown', onKeydown);
    };
  });

  const currentUsername = $derived(
    (appState.currentUser?.username || appState.currentUser?.name || appState.currentUser?.staffId || '').toLowerCase()
  );

  const filteredTasks = $derived.by(() => {
    let list = tasks;

    if (hideCompleted) {
      list = list.filter(t => t.status !== 'done' && t.status !== 'converted');
    }

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
      list = list.filter(t => (t.workstream || 'General Operations').toLowerCase() === workstreamFilter.toLowerCase());
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
      set.add(t.workstream || 'General Operations');
    });
    if (set.size === 0) return ['General Operations', 'Software & App Dev', 'Packaging & Dieline'];
    return Array.from(set);
  });

  // Grouped tasks by Workstream then Status (ClickUp List arrangement)
  const workstreamGroups = $derived.by(() => {
    return presentWorkstreams.map(ws => {
      const wsTasks = filteredTasks.filter(t => (t.workstream || 'General Operations') === ws);
      const total = wsTasks.length;
      const completed = wsTasks.filter(t => t.status === 'done' || t.status === 'converted').length;
      const percent = total > 0 ? Math.round((completed / total) * 100) : 0;

      // Group tasks inside workstream by Status
      const statusGroups = [
        { status: 'backlog' as StudioTaskStatus, label: 'BACKLOG', color: '#64748B', tasks: wsTasks.filter(t => t.status === 'backlog') },
        { status: 'in-progress' as StudioTaskStatus, label: 'IN PROGRESS', color: '#0284C7', tasks: wsTasks.filter(t => t.status === 'in-progress') },
        { status: 'review' as StudioTaskStatus, label: 'REVIEW', color: '#F59E0B', tasks: wsTasks.filter(t => t.status === 'review') },
        { status: 'done' as StudioTaskStatus, label: 'DONE', color: '#10B981', tasks: wsTasks.filter(t => t.status === 'done' || t.status === 'converted') }
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

  // Executive Overview Stats derivation
  const overviewStats = $derived.by(() => {
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === 'done' || t.status === 'converted').length;
    const inProgress = tasks.filter(t => t.status === 'in-progress').length;
    const inReview = tasks.filter(t => t.status === 'review').length;
    const backlog = tasks.filter(t => t.status === 'backlog').length;
    const urgentOrHigh = tasks.filter(t => (t.priority === 'urgent' || t.priority === 'high') && t.status !== 'done' && t.status !== 'converted').length;
    const overallPercent = total > 0 ? Math.round((completed / total) * 100) : 0;

    // SVG Donut calculation: Circumference = 2 * PI * 48 = 301.59
    const circumference = 301.59;
    const toRatio = (cnt: number) => total > 0 ? cnt / total : 0;

    const rBacklog = toRatio(backlog);
    const rProgress = toRatio(inProgress);
    const rReview = toRatio(inReview);
    const rDone = toRatio(completed);

    const backlogDash = `${rBacklog * circumference} ${circumference}`;
    const inProgressDash = `${rProgress * circumference} ${circumference}`;
    const reviewDash = `${rReview * circumference} ${circumference}`;
    const doneDash = `${rDone * circumference} ${circumference}`;

    const backlogOffset = 0;
    const inProgressOffset = -(rBacklog * circumference);
    const reviewOffset = -((rBacklog + rProgress) * circumference);
    const doneOffset = -((rBacklog + rProgress + rReview) * circumference);

    return {
      total,
      completed,
      inProgress,
      inReview,
      backlog,
      urgentOrHigh,
      overallPercent,
      ratios: {
        backlog: Math.round(rBacklog * 100),
        inProgress: Math.round(rProgress * 100),
        review: Math.round(rReview * 100),
        done: Math.round(rDone * 100)
      },
      dashes: { backlog: backlogDash, inProgress: inProgressDash, review: reviewDash, done: doneDash },
      offsets: { backlog: backlogOffset, inProgress: inProgressOffset, review: reviewOffset, done: doneOffset }
    };
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

  // Quick inline task creation directly from List view with mandatory assignee
  async function handleQuickInlineCreate(workstream: string, status: StudioTaskStatus = 'backlog', keepActive: boolean = false) {
    const t = inlineTaskTitle.trim();
    if (!t) {
      inlineCreateParent = null;
      return;
    }
    inlineTaskTitle = '';
    if (!keepActive) {
      inlineCreateParent = null;
    }
    try {
      const owner = currentUsername || 'harussani';
      const ownerName = appState.currentUser?.name || 'Harussani (Me)';
      const res = await ApiClient.createStudioTask({
        title: t,
        workstream,
        status,
        priority: 'medium',
        brand: 'SS',
        assignee: owner,
        assigneeName: ownerName,
        assigneeAvatarColor: '#0284C7'
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

  // 1-Click Hover Micro-Action: Advance status to next sequential stage
  async function handleAdvanceStatus(e: MouseEvent, task: StudioTask) {
    e.stopPropagation();
    const transitions: Record<StudioTaskStatus, StudioTaskStatus> = {
      'backlog': 'in-progress',
      'in-progress': 'review',
      'review': 'done',
      'done': 'backlog'
    };
    const nextStatus = transitions[task.status] || 'in-progress';
    await handleInlineStatusChange(task, nextStatus);
    appState.addToast(`Moved "${task.title}" to ${nextStatus.toUpperCase()}`, 'info');
  }

  // 1-Click Hover Micro-Action: Assign to current user
  async function handleQuickAssignToMe(e: MouseEvent, task: StudioTask) {
    e.stopPropagation();
    const username = currentUsername || 'harussani';
    const fullName = appState.currentUser?.name || 'Harussani (Me)';
    if (task.assignee === username) return;
    try {
      const res = await ApiClient.updateStudioTask(task.id, {
        assignee: username,
        assigneeName: fullName,
        assigneeAvatarColor: '#0284C7'
      });
      handleTaskUpdated(res.task);
      appState.addToast(`Assigned to ${fullName}`, 'success');
    } catch (err: any) {
      appState.addToast(`Failed to assign: ${err.message}`, 'error');
    }
  }

  // 1-Click Hover Micro-Action: Bump due date (+1 day)
  async function handleQuickBumpDueDate(e: MouseEvent, task: StudioTask, days: number = 1) {
    e.stopPropagation();
    const base = task.dueDate ? new Date(task.dueDate) : new Date();
    base.setDate(base.getDate() + days);
    const iso = base.toISOString().split('T')[0];
    try {
      const res = await ApiClient.updateStudioTask(task.id, { dueDate: iso });
      handleTaskUpdated(res.task);
      appState.addToast(`Due date bumped to ${formatDateShort(iso)}`, 'info');
    } catch (err: any) {
      appState.addToast(`Failed to set due date: ${err.message}`, 'error');
    }
  }

  // Active filters tracker & quick reset
  const hasActiveFilters = $derived(
    statusFilter !== 'all' ||
    workstreamFilter !== 'all' ||
    brandFilter !== 'all' ||
    priorityFilter !== 'all' ||
    myTasksOnly ||
    hideCompleted ||
    searchQuery.trim().length > 0
  );

  function resetAllFilters() {
    statusFilter = 'all';
    workstreamFilter = 'all';
    brandFilter = 'all';
    priorityFilter = 'all';
    myTasksOnly = false;
    hideCompleted = false;
    searchQuery = '';
  }

  // Executive Bottleneck Radar: Detect overdue, blocked, or urgent deliverables
  const bottleneckTasks = $derived.by(() => {
    return tasks.filter(t => {
      if (t.status === 'done' || t.status === 'converted') return false;
      const overdue = isOverdue(t.dueDate, t.status);
      const isBlocked = (t.blockedBy || []).some(bId => {
        const blk = tasks.find(x => x.id === bId);
        return blk && blk.status !== 'done' && blk.status !== 'converted';
      });
      const isUrgent = t.priority === 'urgent';
      return overdue || isBlocked || isUrgent;
    });
  });

  const bottleneckBreakdown = $derived.by(() => {
    let overdueCount = 0;
    let blockedCount = 0;
    let urgentCount = 0;
    bottleneckTasks.forEach(t => {
      if (isOverdue(t.dueDate, t.status)) overdueCount++;
      if ((t.blockedBy || []).some(bId => {
        const blk = tasks.find(x => x.id === bId);
        return blk && blk.status !== 'done' && blk.status !== 'converted';
      })) blockedCount++;
      if (t.priority === 'urgent') urgentCount++;
    });
    return { overdueCount, blockedCount, urgentCount };
  });

  function triageBottlenecksInList() {
    priorityFilter = 'urgent';
    hideCompleted = true;
    viewMode = 'list';
    appState.addToast(`Filtered to high-priority deliverables`, 'info');
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

  // Inline Subtask Enter Key creation: Inserts a new subtask right below the edited one
  async function handleInlineSubtaskTitleKeydown(e: KeyboardEvent, task: StudioTask, subIndex: number) {
    if (e.key === 'Enter') {
      e.preventDefault();
      const newSub: TaskSubtask = {
        id: `st-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        title: '',
        completed: false
      };
      const curList = [...(task.subtasks || [])];
      curList.splice(subIndex + 1, 0, newSub);
      task.subtasks = curList;

      try {
        const res = await ApiClient.updateStudioTask(task.id, { subtasks: curList });
        handleTaskUpdated(res.task);
      } catch (err: any) {
        console.warn('Failed to insert subtask:', err.message);
      }

      setTimeout(() => {
        const rowInputs = document.querySelectorAll<HTMLInputElement>(`.nested-subtask-input-${task.id}`);
        if (rowInputs[subIndex + 1]) {
          rowInputs[subIndex + 1].focus();
        }
      }, 50);
    } else if (e.key === 'Backspace' && task.subtasks?.[subIndex]?.title === '' && task.subtasks.length > 1) {
      e.preventDefault();
      const curList = task.subtasks.filter((_, i) => i !== subIndex);
      task.subtasks = curList;
      try {
        const res = await ApiClient.updateStudioTask(task.id, { subtasks: curList });
        handleTaskUpdated(res.task);
      } catch (err: any) {
        console.warn('Failed to remove subtask:', err.message);
      }
      setTimeout(() => {
        const rowInputs = document.querySelectorAll<HTMLInputElement>(`.nested-subtask-input-${task.id}`);
        const targetIdx = Math.max(0, subIndex - 1);
        if (rowInputs[targetIdx]) {
          rowInputs[targetIdx].focus();
        }
      }, 50);
    }
  }

  async function handleSaveSubtaskTitle(task: StudioTask) {
    try {
      const res = await ApiClient.updateStudioTask(task.id, { subtasks: task.subtasks });
      handleTaskUpdated(res.task);
    } catch (err: any) {
      console.warn('Failed to save subtask:', err.message);
    }
  }

  async function handleQuickAddSubtask(e: KeyboardEvent, task: StudioTask) {
    if (e.key === 'Enter') {
      const target = e.target as HTMLInputElement;
      const text = target.value.trim();
      if (!text) return;
      e.preventDefault();
      target.value = '';

      const newSub: TaskSubtask = {
        id: `st-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        title: text,
        completed: false
      };
      const curList = [...(task.subtasks || []), newSub];
      task.subtasks = curList;

      try {
        const res = await ApiClient.updateStudioTask(task.id, { subtasks: curList });
        handleTaskUpdated(res.task);
      } catch (err: any) {
        console.warn('Failed to add subtask:', err.message);
      }
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

  // 14-Day Calendar Dates for Dynamic Timeline (Gantt) View
  const todayDate = new Date();

  const dynamicTimelineDates = $derived.by(() => {
    const list: Date[] = [];
    const base = new Date();
    base.setHours(0, 0, 0, 0);
    base.setDate(base.getDate() - 3 + timelineOffset * 7);
    for (let i = 0; i < 14; i++) {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      list.push(d);
    }
    return list;
  });

  const timelineRangeLabel = $derived.by(() => {
    if (dynamicTimelineDates.length === 0) return '';
    const f = dynamicTimelineDates[0];
    const l = dynamicTimelineDates[dynamicTimelineDates.length - 1];
    return `${f.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} – ${l.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
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

  // Team Workload & Allocation Telemetry (Replaces bloated emoji links in Overview)
  const teamWorkloads = $derived.by(() => {
    const map = new Map<string, { total: number; inProgress: number; review: number; done: number; name: string }>();
    for (const t of tasks) {
      const key = (t.assignee || 'unassigned').toLowerCase();
      const name = t.assigneeName || (key === 'unassigned' ? 'Unassigned' : key);
      const entry = map.get(key) || { total: 0, inProgress: 0, review: 0, done: 0, name };
      entry.total += 1;
      if (t.status === 'in-progress') entry.inProgress += 1;
      if (t.status === 'review') entry.review += 1;
      if (t.status === 'done' || t.status === 'converted') entry.done += 1;
      map.set(key, entry);
    }
    return Array.from(map.entries())
      .map(([key, data]) => ({ key, ...data }))
      .sort((a, b) => b.total - a.total);
  });

  // Table Sorting and Batch Operations
  const sortedTableTasks = $derived.by(() => {
    const list = [...filteredTasks];
    const pRanks: Record<string, number> = { urgent: 4, high: 3, medium: 2, low: 1 };
    return list.sort((a, b) => {
      let cmp = 0;
      if (tableSortCol === 'title') {
        cmp = (a.title || '').localeCompare(b.title || '');
      } else if (tableSortCol === 'assignee') {
        cmp = (a.assigneeName || a.assignee || '').localeCompare(b.assigneeName || b.assignee || '');
      } else if (tableSortCol === 'status') {
        cmp = (a.status || '').localeCompare(b.status || '');
      } else if (tableSortCol === 'dueDate') {
        cmp = (a.dueDate || '').localeCompare(b.dueDate || '');
      } else if (tableSortCol === 'priority') {
        cmp = (pRanks[a.priority || 'medium'] || 0) - (pRanks[b.priority || 'medium'] || 0);
      }
      return tableSortAsc ? cmp : -cmp;
    });
  });

  function toggleTableSort(col: 'title' | 'assignee' | 'status' | 'dueDate' | 'priority') {
    if (tableSortCol === col) {
      tableSortAsc = !tableSortAsc;
    } else {
      tableSortCol = col;
      tableSortAsc = true;
    }
  }

  function toggleSelectAllTable() {
    if (selectedTaskIds.length === filteredTasks.length && filteredTasks.length > 0) {
      selectedTaskIds = [];
    } else {
      selectedTaskIds = filteredTasks.map(t => t.id);
    }
  }

  function toggleSelectTask(id: string) {
    if (selectedTaskIds.includes(id)) {
      selectedTaskIds = selectedTaskIds.filter(i => i !== id);
    } else {
      selectedTaskIds = [...selectedTaskIds, id];
    }
  }

  async function handleBatchStatusChange(newStatus: StudioTaskStatus) {
    if (selectedTaskIds.length === 0) return;
    const targets = [...selectedTaskIds];
    try {
      await Promise.all(targets.map(id => ApiClient.updateStudioTask(id, { status: newStatus })));
      tasks = tasks.map(t => targets.includes(t.id) ? { ...t, status: newStatus } : t);
      appState.addToast(`Updated ${targets.length} tasks to ${newStatus}`, 'success');
      selectedTaskIds = [];
    } catch (err: any) {
      appState.addToast(`Failed batch update: ${err.message}`, 'error');
    }
  }

  async function handleBatchDelete() {
    if (selectedTaskIds.length === 0) return;
    const cnt = selectedTaskIds.length;
    if (!confirm(`Are you sure you want to delete ${cnt} selected task(s)?`)) return;
    const targets = [...selectedTaskIds];
    try {
      await Promise.all(targets.map(id => ApiClient.deleteStudioTask(id)));
      tasks = tasks.filter(t => !targets.includes(t.id));
      appState.addToast(`Deleted ${cnt} tasks`, 'info');
      selectedTaskIds = [];
    } catch (err: any) {
      appState.addToast(`Failed to delete tasks: ${err.message}`, 'error');
    }
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
  <!-- ═══ TOP SUB-HEADER & A/B MODE SWITCHER ═══════════════════════ -->
  <header class="clickup-top-header">
    <div class="header-left-cluster">
      <div class="space-title-dropdown">
        <span class="space-icon-dot"></span>
        <h1 class="space-name">Workspace Tasks &amp; Deliverables</h1>
        <span class="task-count-pill">{filteredTasks.length} task{filteredTasks.length !== 1 ? 's' : ''}</span>
      </div>
    </div>

    <div class="header-right-tools">
      <!-- Studio A/B Layout Switcher -->
      <div class="ab-layout-pill">
        <button
          type="button"
          class="ab-pill-btn"
          class:active={layoutMode === 'minimalist'}
          onclick={() => setLayoutMode('minimalist')}
          title="Minimalist View (A): Direct high-density task execution (List, Board, Table)"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M4 6h16M4 12h10M4 18h7"/></svg>
          <span>Minimalist (A)</span>
        </button>
        <button
          type="button"
          class="ab-pill-btn"
          class:active={layoutMode === 'executive'}
          onclick={() => setLayoutMode('executive')}
          title="Executive View (B): Full operational metrics, KPI telemetry deck, workstream matrix"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          <span>Executive (B)</span>
        </button>
      </div>

      <!-- Sync Live Telemetry Button -->
      <button
        type="button"
        class="sync-telemetry-btn"
        onclick={() => loadTasks()}
        disabled={isLoading}
        title="Sync live tasks from server"
      >
        <FluentIcons name="sync" size={13} class={isLoading ? 'spinning' : ''} />
        <span>{isLoading ? 'Syncing...' : 'Sync'}</span>
      </button>

      <div class="tool-divider"></div>

      <!-- + Task Primary Action Button -->
      <button
        type="button"
        class="clickup-add-task-btn"
        onclick={() => (isCreateModalOpen = true)}
      >
        <FluentIcons name="plus" size={14} />
        <span>New Task</span>
      </button>
    </div>
  </header>

  <!-- ═══ 2-TIER TOOLBAR: TIER 1 (VIEW NAVIGATION & CORE TOGGLES) ═══ -->
  <div class="clickup-views-nav">
    <div class="views-tabs-list">
      {#if layoutMode === 'executive'}
        <button
          type="button"
          class="view-tab"
          class:active={viewMode === 'overview'}
          onclick={() => (viewMode = 'overview')}
        >
          <FluentIcons name="overview" size={14} />
          <span>Overview</span>
          {#if bottleneckTasks.length > 0}
            <span class="view-tab-alert-dot" title="{bottleneckTasks.length} Bottlenecks Requiring Attention"></span>
          {/if}
        </button>
      {/if}

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
        class="view-tab"
        class:active={viewMode === 'table'}
        onclick={() => (viewMode = 'table')}
      >
        <FluentIcons name="table" size={14} />
        <span>Table</span>
      </button>

      <button
        type="button"
        class="view-tab timeline-tab"
        class:active={viewMode === 'gantt'}
        onclick={() => (viewMode = 'gantt')}
      >
        <FluentIcons name="gantt" size={14} />
        <span>Timeline</span>
      </button>
    </div>

    <!-- Right Controls: Me Mode & Hide Completed Toggles -->
    <div class="tier1-right-toggles">
      <!-- Me Mode Toggle Button -->
      <button
        type="button"
        class="me-mode-btn"
        class:active={myTasksOnly}
        onclick={() => (myTasksOnly = !myTasksOnly)}
        title="Toggle Me Mode (Show only assigned to me)"
      >
        <FluentIcons name="user" size={13} />
        <span>Assigned to Me</span>
      </button>

      <!-- Hide Completed Tasks Toggle Button -->
      <button
        type="button"
        class="filter-icon-toggle-btn"
        class:active={hideCompleted}
        onclick={() => (hideCompleted = !hideCompleted)}
        title="Toggle visibility of completed tasks"
      >
        <FluentIcons name={hideCompleted ? 'eyeSlash' : 'eye'} size={13} />
        <span>{hideCompleted ? 'Completed: Hidden' : 'Completed: Shown'}</span>
      </button>
    </div>
  </div>

  <!-- ═══ 2-TIER TOOLBAR: TIER 2 (OPERATIONAL REFINEMENT RAIL) ════════ -->
  <div class="clickup-refinement-toolbar">
    <div class="refinement-left-group">
      <!-- Search Input with Ctrl+K Hint -->
      <div class="clickup-search-box">
        <FluentIcons name="search" size={13} color="var(--text-secondary)" />
        <input
          type="text"
          placeholder="Search deliverables, owners, tags... (Ctrl+K)"
          bind:value={searchQuery}
          class="clickup-search-input"
        />
        {#if searchQuery}
          <button type="button" class="clear-btn" onclick={() => (searchQuery = '')}>✕</button>
        {:else}
          <kbd class="search-kbd-hint">Ctrl+K</kbd>
        {/if}
      </div>

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

      <!-- Brand Filter Pill -->
      <select class="clickup-filter-pill" bind:value={brandFilter}>
        <option value="all">Brand: All</option>
        {#each brandChips.filter(b => b !== 'all') as b}
          <option value={b}>Brand: {b}</option>
        {/each}
      </select>

      <!-- Priority Filter Pill -->
      <select class="clickup-filter-pill" bind:value={priorityFilter}>
        <option value="all">Priority: All</option>
        {#each priorityChips.filter(p => p !== 'all') as p}
          <option value={p}>Priority: {p.charAt(0).toUpperCase() + p.slice(1)}</option>
        {/each}
      </select>
    </div>

    <div class="refinement-right-group">
      {#if hasActiveFilters}
        <button
          type="button"
          class="reset-filters-btn"
          onclick={resetAllFilters}
          title="Reset all active filters"
        >
          <FluentIcons name="arrowCounterclockwise" size={12} />
          <span>Reset Filters</span>
        </button>
      {/if}
    </div>
  </div>

  <!-- ═══ MAIN WORKSPACE VIEW ROUTER ════════════════════════════════ -->
  {#if isLoading && tasks.length === 0}
    <div class="loading-state">
      <div class="spinner"></div>
      <span>Loading Workspace Tasks…</span>
    </div>

  <!-- ═══════════════════════════════════════════════════════════════
       1. OVERVIEW VIEW (Revamped Executive UI)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'overview'}
    <div class="overview-view-container">

      <!-- EXECUTIVE BOTTLENECK RADAR BANNER (Phase 4) -->
      {#if bottleneckTasks.length > 0}
        <div class="executive-bottleneck-radar-banner">
          <div class="radar-left">
            <span class="radar-pulsing-dot"></span>
            <div class="radar-text-block">
              <span class="radar-title">Executive Bottleneck Radar: {bottleneckTasks.length} Deliverable{bottleneckTasks.length !== 1 ? 's' : ''} Require Attention</span>
              <span class="radar-desc">
                {#if bottleneckBreakdown.overdueCount > 0}<strong>{bottleneckBreakdown.overdueCount}</strong> overdue{/if}
                {#if bottleneckBreakdown.blockedCount > 0}{bottleneckBreakdown.overdueCount > 0 ? ' • ' : ''}<strong>{bottleneckBreakdown.blockedCount}</strong> blocked by dependencies{/if}
                {#if bottleneckBreakdown.urgentCount > 0}{(bottleneckBreakdown.overdueCount > 0 || bottleneckBreakdown.blockedCount > 0) ? ' • ' : ''}<strong>{bottleneckBreakdown.urgentCount}</strong> urgent priority{/if}
              </span>
            </div>
          </div>
          <div class="radar-right">
            <button type="button" class="radar-action-btn" onclick={triageBottlenecksInList}>
              <span>Triage Deliverables in List</span>
              <FluentIcons name="arrowRight" size={13} />
            </button>
          </div>
        </div>
      {/if}

      <!-- TOP 4 EXECUTIVE KPI SUMMARY CARDS -->
      <div class="overview-kpi-grid">
        <button
          type="button"
          class="kpi-metric-card"
          onclick={() => { statusFilter = 'all'; viewMode = 'list'; }}
        >
          <div class="kpi-top-row">
            <span class="kpi-label">TOTAL WORKSPACE TASKS</span>
            <span class="kpi-badge neutral">{overviewStats.overallPercent}% VELOCITY</span>
          </div>
          <div class="kpi-number-row">
            <span class="kpi-number">{overviewStats.total}</span>
            <span class="kpi-trend-pill">
              <FluentIcons name="checkCircle" size={12} color="#10B981" />
              <span>{overviewStats.completed} Closed</span>
            </span>
          </div>
          <div class="kpi-progress-bar">
            <div class="kpi-progress-fill" style="width: {overviewStats.overallPercent}%;"></div>
          </div>
        </button>

        <button
          type="button"
          class="kpi-metric-card"
          onclick={() => { statusFilter = 'in-progress'; viewMode = 'board'; }}
        >
          <div class="kpi-top-row">
            <span class="kpi-label">IN FLIGHT PIPELINE</span>
            <span class="kpi-badge in-progress">ACTIVE</span>
          </div>
          <div class="kpi-number-row">
            <span class="kpi-number" style="color: #0284C7;">{overviewStats.inProgress}</span>
            <span class="kpi-subtext">Active Execution</span>
          </div>
          <div class="kpi-footer-hint">Filter In Progress on Board ➔</div>
        </button>

        <button
          type="button"
          class="kpi-metric-card"
          onclick={() => { statusFilter = 'review'; viewMode = 'list'; }}
        >
          <div class="kpi-top-row">
            <span class="kpi-label">TEAM REVIEW QUEUE</span>
            <span class="kpi-badge review">IN REVIEW</span>
          </div>
          <div class="kpi-number-row">
            <span class="kpi-number" style="color: #F59E0B;">{overviewStats.inReview}</span>
            <span class="kpi-subtext">Awaiting Sign-Off</span>
          </div>
          <div class="kpi-footer-hint">Explore Review Queue ➔</div>
        </button>

        <button
          type="button"
          class="kpi-metric-card"
          onclick={() => { priorityFilter = 'urgent'; viewMode = 'list'; }}
        >
          <div class="kpi-top-row">
            <span class="kpi-label">CRITICAL ATTENTION</span>
            <span class="kpi-badge urgent">URGENT / HIGH</span>
          </div>
          <div class="kpi-number-row">
            <span class="kpi-number" style="color: #EF4444;">{overviewStats.urgentOrHigh}</span>
            <span class="kpi-subtext">Priority Watch</span>
          </div>
          <div class="kpi-footer-hint">View High Priority Tasks ➔</div>
        </button>
      </div>

      <!-- SERVICE WORKSTREAMS & DELIVERABLE HEALTH MATRIX -->
      <div class="overview-card">
        <div class="overview-card-header">
          <div class="card-header-titles">
            <h3 class="card-title">Service Workstreams &amp; Deliverable Health</h3>
            <span class="card-subtitle">Real-time throughput, status distribution, and active ownership per operational department.</span>
          </div>
          <div class="card-header-actions">
            <span class="refresh-subtext">Refreshed just now</span>
            <button type="button" class="btn-primary-sm" onclick={() => (isCreateModalOpen = true)}>
              <FluentIcons name="plus" size={12} />
              <span>New Task</span>
            </button>
          </div>
        </div>

        <table class="overview-lists-table">
          <thead>
            <tr>
              <th>Workstream / Department</th>
              <th style="width: 220px;">Status Breakdown</th>
              <th style="width: 240px;">Completion Progress</th>
              <th style="width: 140px;">Active Owners</th>
              <th style="width: 110px; text-align: right;">Action</th>
            </tr>
          </thead>
          <tbody>
            {#each workstreamGroups as group}
              {@const wsAssignees = Array.from(new Set(group.tasks.map(t => t.assigneeName || t.assignee).filter(Boolean)))}
              <tr class="overview-list-row" onclick={() => { workstreamFilter = group.workstream; viewMode = 'list'; }}>
                <td class="ws-name-cell">
                  <div class="ws-icon-circle">
                    <FluentIcons name="list" size={13} color="#0284C7" />
                  </div>
                  <div class="ws-name-meta">
                    <strong>{group.workstream}</strong>
                    <span class="ws-task-total">{group.total} task{group.total !== 1 ? 's' : ''}</span>
                  </div>
                </td>
                <td>
                  <div class="status-distribution-pills">
                    {#each group.statusGroups as sg}
                      {#if sg.tasks.length > 0}
                        <span class="mini-status-chip" style="border-color: {sg.color}; color: {sg.color};">
                          {sg.tasks.length} {sg.status === 'in-progress' ? 'Prog' : sg.status}
                        </span>
                      {/if}
                    {/each}
                  </div>
                </td>
                <td>
                  <div class="progress-bar-cell">
                    <div class="progress-track">
                      <div class="progress-fill" style="width: {group.percent}%;"></div>
                    </div>
                    <span class="progress-percent-badge">{group.percent}%</span>
                    <span class="progress-count">{group.completed}/{group.total}</span>
                  </div>
                </td>
                <td>
                  <div class="owners-avatar-stack">
                    {#if wsAssignees.length > 0}
                      {#each wsAssignees.slice(0, 3) as ownerName}
                        <div class="mini-owner-circle" title={ownerName}>
                          {ownerName.substring(0, 2).toUpperCase()}
                        </div>
                      {/each}
                      {#if wsAssignees.length > 3}
                        <span class="owner-overflow-tag">+{wsAssignees.length - 3}</span>
                      {/if}
                    {:else}
                      <span class="unassigned-text">Unassigned</span>
                    {/if}
                  </div>
                </td>
                <td style="text-align: right;">
                  <button type="button" class="table-action-pill" onclick={(e) => {
                    e.stopPropagation();
                    workstreamFilter = group.workstream;
                    viewMode = 'list';
                  }}>
                    Open List ➔
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- BOTTOM SPLIT: TEAM BANDWIDTH & WORKLOAD STATUS DONUT -->
      <div class="overview-bottom-grid">
        <!-- Team Bandwidth & Allocation Card -->
        <div class="overview-card">
          <div class="overview-card-header">
            <div class="card-header-titles">
              <h3 class="card-title">Team Bandwidth &amp; Workload Allocation</h3>
              <span class="card-subtitle">Active task distribution, in-flight execution, and review queues per owner.</span>
            </div>
          </div>

          <div class="team-bandwidth-container">
            <table class="team-bandwidth-table">
              <thead>
                <tr>
                  <th>Team Member</th>
                  <th style="width: 70px; text-align: center;">Total</th>
                  <th style="width: 90px; text-align: center;">In Progress</th>
                  <th style="width: 80px; text-align: center;">In Review</th>
                  <th style="width: 100px; text-align: center;">Capacity</th>
                  <th style="width: 70px; text-align: right;">Action</th>
                </tr>
              </thead>
              <tbody>
                {#if teamWorkloads.length === 0}
                  <tr>
                    <td colspan="6" style="text-align: center; color: var(--text-tertiary); padding: 18px;">
                      No team assignments logged
                    </td>
                  </tr>
                {:else}
                  {#each teamWorkloads as tw}
                    {@const statusTier = tw.inProgress >= 4 ? 'busy' : (tw.inProgress >= 1 ? 'optimal' : 'light')}
                    {@const statusLabel = tw.inProgress >= 4 ? 'High Load' : (tw.inProgress >= 1 ? 'Optimal' : 'Light')}
                    <tr class="tb-row">
                      <td>
                        <div class="tb-user-cell">
                          <div class="tb-avatar">
                            {tw.name.substring(0, 2).toUpperCase()}
                          </div>
                          <span class="tb-name">{tw.name}</span>
                        </div>
                      </td>
                      <td style="text-align: center; font-weight: 700;">{tw.total}</td>
                      <td style="text-align: center;">
                        <span class="mini-status-chip" style="border-color: #0284C7; color: #0284C7;">{tw.inProgress}</span>
                      </td>
                      <td style="text-align: center;">
                        <span class="mini-status-chip" style="border-color: #F59E0B; color: #F59E0B;">{tw.review}</span>
                      </td>
                      <td style="text-align: center;">
                        <span class="tb-status-badge {statusTier}">{statusLabel}</span>
                      </td>
                      <td style="text-align: right;">
                        <button
                          type="button"
                          class="table-action-pill"
                          onclick={() => { searchQuery = tw.name; viewMode = 'list'; }}
                          title="View tasks for {tw.name}"
                        >
                          View ➔
                        </button>
                      </td>
                    </tr>
                  {/each}
                {/if}
              </tbody>
            </table>
          </div>
        </div>

        <!-- Workload by Status (Interactive SVG Donut Chart) -->
        <div class="overview-card">
          <div class="overview-card-header">
            <div class="card-header-titles">
              <h3 class="card-title">Workload by Status</h3>
              <span class="card-subtitle">Deliverables distributed across execution and review cycles.</span>
            </div>
          </div>

          <div class="workload-breakdown-row">
            <!-- Modern SVG Donut Chart -->
            <div class="donut-chart-container">
              <svg viewBox="0 0 120 120" class="donut-svg-ring">
                <!-- Background Track -->
                <circle
                  cx="60"
                  cy="60"
                  r="48"
                  fill="none"
                  stroke="var(--surface-card-border, #E2E8F0)"
                  stroke-width="12"
                />
                <!-- Backlog Arc -->
                <circle
                  cx="60"
                  cy="60"
                  r="48"
                  fill="none"
                  stroke="#64748B"
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray={overviewStats.dashes.backlog}
                  stroke-dashoffset={overviewStats.offsets.backlog}
                  transform="rotate(-90 60 60)"
                />
                <!-- In Progress Arc -->
                <circle
                  cx="60"
                  cy="60"
                  r="48"
                  fill="none"
                  stroke="#0284C7"
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray={overviewStats.dashes.inProgress}
                  stroke-dashoffset={overviewStats.offsets.inProgress}
                  transform="rotate(-90 60 60)"
                />
                <!-- Review Arc -->
                <circle
                  cx="60"
                  cy="60"
                  r="48"
                  fill="none"
                  stroke="#F59E0B"
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray={overviewStats.dashes.review}
                  stroke-dashoffset={overviewStats.offsets.review}
                  transform="rotate(-90 60 60)"
                />
                <!-- Done Arc -->
                <circle
                  cx="60"
                  cy="60"
                  r="48"
                  fill="none"
                  stroke="#10B981"
                  stroke-width="12"
                  stroke-linecap="round"
                  stroke-dasharray={overviewStats.dashes.done}
                  stroke-dashoffset={overviewStats.offsets.done}
                  transform="rotate(-90 60 60)"
                />
              </svg>

              <div class="donut-center-overlay">
                <span class="donut-stat-number">{overviewStats.total}</span>
                <span class="donut-stat-label">Total Tasks</span>
              </div>
            </div>

            <!-- Legend Table -->
            <div class="donut-legend-table">
              {#each columns as col}
                {@const cCount = tasks.filter(t => t.status === col.id || (col.id === 'done' && t.status === 'converted')).length}
                {@const cRatio = overviewStats.ratios[col.id] || 0}
                <button
                  type="button"
                  class="legend-status-row"
                  onclick={() => { statusFilter = col.id; viewMode = 'board'; }}
                >
                  <div class="legend-left-col">
                    <span class="legend-dot" style="background: {col.color};"></span>
                    <span class="legend-label">{col.label}</span>
                  </div>
                  <div class="legend-right-col">
                    <span class="legend-count">{cCount}</span>
                    <span class="legend-percent-tag">{cRatio}%</span>
                  </div>
                </button>
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
          <!-- Folder Header with Expand & Department Stats -->
          <div class="folder-header" onclick={() => toggleWorkstreamExpand(group.workstream)} role="button" tabindex="0" onkeydown={() => {}}>
            <div class="folder-title-row">
              <span class="caret-icon">
                <FluentIcons name={expandedWorkstreams[group.workstream] ? 'chevronDown' : 'chevronRight'} size={14} />
              </span>
              <h2 class="folder-name">{group.workstream}</h2>
              <span class="folder-count-pill">{group.total} task{group.total !== 1 ? 's' : ''}</span>
              <span class="folder-progress-pill">{group.percent}% Complete</span>
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

                          <!-- Action Adder & Hover Micro-Actions Rail (Phase 3) -->
                          <div class="row-cell-add">
                            <div class="row-hover-actions" onclick={(e) => e.stopPropagation()} role="none">
                              <button
                                type="button"
                                class="micro-action-btn advance"
                                onclick={(e) => handleAdvanceStatus(e, task)}
                                title="Advance status to next stage"
                              >
                                <FluentIcons name={task.status === 'done' ? 'arrowCounterclockwise' : (task.status === 'review' ? 'checkmark' : (task.status === 'in-progress' ? 'search' : 'bolt'))} size={11} />
                                <span class="micro-btn-label">
                                  {task.status === 'done' ? 'Reopen' : (task.status === 'review' ? 'Done' : (task.status === 'in-progress' ? 'Review' : 'Advance'))}
                                </span>
                              </button>

                              {#if (task.assignee || '').toLowerCase() !== currentUsername}
                                <button
                                  type="button"
                                  class="micro-action-btn assign"
                                  onclick={(e) => handleQuickAssignToMe(e, task)}
                                  title="Assign to me ({currentUsername || 'me'})"
                                >
                                  <FluentIcons name="user" size={11} />
                                  <span class="micro-btn-label">+Me</span>
                                </button>
                              {/if}

                              <button
                                type="button"
                                class="micro-action-btn due"
                                onclick={(e) => handleQuickBumpDueDate(e, task, 1)}
                                title="Bump due date +1 day"
                              >
                                <FluentIcons name="calendar" size={11} />
                                <span class="micro-btn-label">+1d</span>
                              </button>
                            </div>
                            <span class="row-more-dots">•••</span>
                          </div>
                        </div>

                        <!-- Nested Subtasks (ClickUp exact indentation) -->
                        {#if isSubExpanded && task.subtasks}
                          <div class="nested-subtasks-tree">
                            {#each task.subtasks as sub, sIdx}
                              <div class="nested-subtask-row" class:completed={sub.completed}>
                                <div class="sub-indent-elbow"></div>
                                <input
                                  type="checkbox"
                                  checked={sub.completed}
                                  onchange={() => handleInlineSubtaskToggle(task, sub.id)}
                                  class="clickup-checkbox"
                                  title="Toggle subtask completion"
                                />
                                <input
                                  type="text"
                                  class="nested-subtask-input nested-subtask-input-{task.id}"
                                  bind:value={sub.title}
                                  onkeydown={(e) => handleInlineSubtaskTitleKeydown(e, task, sIdx)}
                                  onblur={() => handleSaveSubtaskTitle(task)}
                                  placeholder="Subtask title (press Return for next)..."
                                />
                              </div>
                            {/each}

                            <!-- Quick add subtask input row -->
                            <div class="nested-subtask-quick-add">
                              <div class="sub-indent-elbow"></div>
                              <FluentIcons name="plus" size={11} color="var(--text-tertiary)" />
                              <input
                                type="text"
                                class="subtask-quick-input"
                                placeholder="+ Add new subtask (press Return)..."
                                onkeydown={(e) => handleQuickAddSubtask(e, task)}
                              />
                            </div>
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
                          placeholder="Task Name... (press Enter to create and continue, Esc to close)"
                          bind:value={inlineTaskTitle}
                          onkeydown={(e) => {
                            if (e.key === 'Enter') handleQuickInlineCreate(group.workstream, sGroup.status, true);
                            if (e.key === 'Escape') inlineCreateParent = null;
                          }}
                          autofocus
                        />
                        <button type="button" class="btn-save-inline" onclick={() => handleQuickInlineCreate(group.workstream, sGroup.status, true)}>
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
                  <span class="ws-tag">{task.workstream || 'General Operations'}</span>
                  <span class="priority-pill-badge {task.priority || 'medium'}">
                    <FluentIcons name="flag" size={11} color={pMeta.color} />
                    <span>{pMeta.label}</span>
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
                  <div class="card-bottom-assignee">
                    {#if task.assignee}
                      <div class="assignee-avatar-circle sm" style="background: {task.assigneeAvatarColor || '#0078D4'};" title="{task.assigneeName || task.assignee}">
                        {(task.assigneeName || task.assignee || 'U').substring(0, 2).toUpperCase()}
                      </div>
                      <span class="card-assignee-name">{task.assigneeName || task.assignee}</span>
                    {:else}
                      <FluentIcons name="user" size={13} color="#94A3B8" />
                      <span class="card-assignee-name unassigned">Unassigned</span>
                    {/if}
                  </div>

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
       4. GANTT / TIMELINE VIEW (Dynamic Interactive Timeline)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'gantt'}
    <div class="clickup-gantt-wrapper">
      <!-- Gantt Sub-Toolbar with working timeline navigation -->
      <div class="gantt-sub-toolbar">
        <div class="toolbar-left">
          <button type="button" class="gantt-btn" onclick={() => (timelineOffset -= 1)} title="Previous week">
            ◀ Prev Week
          </button>
          <button type="button" class="gantt-btn today-btn" onclick={() => (timelineOffset = 0)} title="Jump to current week">
            Today
          </button>
          <button type="button" class="gantt-btn" onclick={() => (timelineOffset += 1)} title="Next week">
            Next Week ▶
          </button>
          <span class="timeline-range-pill">{timelineRangeLabel}</span>
        </div>

        <div class="toolbar-right">
          <button
            type="button"
            class="gantt-btn"
            onclick={() => {
              const allCollapsed = Object.values(expandedWorkstreams).every(v => !v);
              const nextState = allCollapsed;
              for (const k in expandedWorkstreams) {
                expandedWorkstreams[k] = nextState;
              }
            }}
          >
            {Object.values(expandedWorkstreams).some(v => v) ? 'Collapse All' : 'Expand All'}
          </button>
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
              <strong class="row-name">Workspace Directory</strong>
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
            <!-- Dynamic Weeks Header -->
            <div class="weeks-row">
              {#if dynamicTimelineDates.length >= 14}
                <span class="week-label">
                  Week 1: {dynamicTimelineDates[0].toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} – {dynamicTimelineDates[6].toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                </span>
                <span class="week-label">
                  Week 2: {dynamicTimelineDates[7].toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} – {dynamicTimelineDates[13].toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                </span>
              {/if}
            </div>

            <!-- Days Header -->
            <div class="days-row">
              {#each dynamicTimelineDates as d}
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
                  {@const bar = getGanttBarStyle(task, dynamicTimelineDates)}
                  {@const isSubExp = !!expandedTaskIds[task.id]}

                  <div class="gantt-grid-task-row">
                    <!-- Day Columns Background Grid -->
                    {#each dynamicTimelineDates as d}
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
       5. TABLE VIEW (Interactive Multi-Select & Sortable Grid)
       ═══════════════════════════════════════════════════════════════ -->
  {:else if viewMode === 'table'}
    <div class="clickup-table-container">
      <table class="clickup-data-table">
        <thead>
          <tr>
            <th style="width: 32px; text-align: center;">
              <input
                type="checkbox"
                class="clickup-checkbox"
                checked={selectedTaskIds.length === filteredTasks.length && filteredTasks.length > 0}
                onchange={toggleSelectAllTable}
                title="Select all tasks"
              />
            </th>
            <th style="width: 40px; text-align: center;">#</th>
            <th class="sortable-th" onclick={() => toggleTableSort('title')}>
              Name {#if tableSortCol === 'title'}{tableSortAsc ? '▲' : '▼'}{/if}
            </th>
            <th class="sortable-th" style="width: 180px;" onclick={() => toggleTableSort('assignee')}>
              Assignee {#if tableSortCol === 'assignee'}{tableSortAsc ? '▲' : '▼'}{/if}
            </th>
            <th class="sortable-th" style="width: 140px;" onclick={() => toggleTableSort('status')}>
              Status {#if tableSortCol === 'status'}{tableSortAsc ? '▲' : '▼'}{/if}
            </th>
            <th class="sortable-th" style="width: 130px;" onclick={() => toggleTableSort('dueDate')}>
              Due Date {#if tableSortCol === 'dueDate'}{tableSortAsc ? '▲' : '▼'}{/if}
            </th>
            <th class="sortable-th" style="width: 120px;" onclick={() => toggleTableSort('priority')}>
              Priority {#if tableSortCol === 'priority'}{tableSortAsc ? '▲' : '▼'}{/if}
            </th>
            <th style="width: 40px; text-align: center;">•••</th>
          </tr>
        </thead>
        <tbody>
          {#each sortedTableTasks as task, idx (task.id)}
            {@const pMeta = getPriorityMeta(task.priority)}
            {@const blockers = getBlockers(task)}
            <tr
              class="clickup-table-row"
              class:row-selected={selectedTaskIds.includes(task.id)}
              onclick={() => openTaskDetail(task)}
              role="button"
              tabindex="0"
              onkeydown={(e) => { if (e.key === 'Enter') openTaskDetail(task); }}
            >
              <!-- Checkbox -->
              <td style="text-align: center;" onclick={(e) => e.stopPropagation()} role="none">
                <input
                  type="checkbox"
                  class="clickup-checkbox"
                  checked={selectedTaskIds.includes(task.id)}
                  onchange={() => toggleSelectTask(task.id)}
                  title="Select task"
                />
              </td>

              <!-- Row Index -->
              <td class="row-num-cell">{idx + 1}</td>

              <!-- Name with Status Circle -->
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

              <!-- Status Pill -->
              <td onclick={(e) => e.stopPropagation()} role="none">
                <select
                  class="clickup-status-pill status-{task.status}"
                  value={task.status}
                  onchange={(e) => handleInlineStatusChange(task, (e.target as HTMLSelectElement).value as StudioTaskStatus)}
                >
                  <option value="backlog">Backlog</option>
                  <option value="in-progress">In Progress</option>
                  <option value="review">Review</option>
                  <option value="done">Done</option>
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
                  <span style="color: {pMeta.color}; font-weight: 600;">{pMeta.label}</span>
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

      <!-- Floating Batch Action Bar -->
      {#if selectedTaskIds.length > 0}
        <div class="batch-action-bar">
          <div class="batch-summary">
            <span class="batch-count-badge">{selectedTaskIds.length}</span>
            <span>task{selectedTaskIds.length > 1 ? 's' : ''} selected</span>
          </div>
          <div class="batch-actions-group">
            <button type="button" class="batch-btn" onclick={() => handleBatchStatusChange('in-progress')}>
              Mark In Progress
            </button>
            <button type="button" class="batch-btn" onclick={() => handleBatchStatusChange('review')}>
              Mark Review
            </button>
            <button type="button" class="batch-btn success" onclick={() => handleBatchStatusChange('done')}>
              Mark Done
            </button>
            <button type="button" class="batch-btn danger" onclick={handleBatchDelete}>
              Delete
            </button>
            <button type="button" class="batch-btn ghost" onclick={() => (selectedTaskIds = [])}>
              Deselect All
            </button>
          </div>
        </div>
      {/if}
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

  /* Studio A/B Layout Switcher Pill */
  .ab-layout-pill {
    display: inline-flex;
    align-items: center;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 3px;
    gap: 2px;
  }
  .ab-pill-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 6px;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .ab-pill-btn:hover {
    color: var(--text-primary);
  }
  .ab-pill-btn.active {
    background: var(--surface-card);
    color: #0078D4;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  /* Live Sync Button */
  .sync-telemetry-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    padding: 6px 12px;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .sync-telemetry-btn:hover:not(:disabled) {
    background: var(--surface-card-subtle);
    color: var(--text-primary);
    border-color: #0078D4;
  }
  .sync-telemetry-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
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

  /* ═══ 2. VIEWS NAVIGATION STRIP (2-TIER ARCHITECTURE) ═══════════ */
  .task-count-pill {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    padding: 2px 8px;
    border-radius: 12px;
  }

  .clickup-views-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    min-height: 44px;
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
  .view-tab.timeline-tab.active {
    color: #EF4444;
  }
  .view-tab.timeline-tab.active::after {
    background: #EF4444;
  }
  .view-tab-alert-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #EF4444;
    display: inline-block;
    margin-left: 2px;
    box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.2);
  }

  .tier1-right-toggles {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  /* ═══ TIER 2: REFINEMENT TOOLBAR ═════════════════════════════════ */
  .clickup-refinement-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 20px;
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
    gap: 12px;
    flex-wrap: wrap;
  }

  .refinement-left-group {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    flex: 1;
  }

  .refinement-right-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .clickup-search-box {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    padding: 0 10px;
    height: 36px;
    width: 280px;
    transition: border-color 0.15s, box-shadow 0.15s;
  }
  .clickup-search-box:focus-within {
    border-color: #0078D4;
    box-shadow: 0 0 0 2px rgba(0, 120, 212, 0.15);
  }
  .clickup-search-input {
    border: none;
    background: transparent;
    font-size: 12px;
    color: var(--text-primary);
    width: 100%;
    outline: none;
  }
  .search-kbd-hint {
    font-size: 10px;
    font-family: inherit;
    font-weight: 600;
    color: var(--text-tertiary);
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    padding: 1px 5px;
    white-space: nowrap;
  }
  .clear-btn { background: transparent; border: none; font-size: 10px; cursor: pointer; color: var(--text-secondary); }

  /* Mandatory Anti-Clipping ComboBox / Filter Select Standard */
  .clickup-filter-pill {
    height: 36px;
    line-height: 36px;
    padding: 0 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    vertical-align: middle;
    transition: all 0.15s ease;
  }
  .clickup-filter-pill:hover {
    border-color: #0078D4;
    color: var(--text-primary);
  }
  .clickup-filter-pill:focus {
    outline: none;
    border-color: #0078D4;
    box-shadow: 0 0 0 2px rgba(0, 120, 212, 0.15);
  }

  .me-mode-btn {
    height: 36px;
    padding: 0 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .me-mode-btn:hover {
    border-color: #0078D4;
    color: var(--text-primary);
  }
  .me-mode-btn.active {
    background: rgba(0, 120, 212, 0.1);
    border-color: #0078D4;
    color: #0078D4;
    font-weight: 600;
  }

  .filter-icon-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 36px;
    padding: 0 12px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .filter-icon-toggle-btn:hover {
    border-color: #0284C7;
    color: var(--text-primary);
  }
  .filter-icon-toggle-btn.active {
    background: rgba(16, 185, 129, 0.1);
    border-color: #10B981;
    color: #047857;
    font-weight: 600;
  }

  .reset-filters-btn {
    height: 36px;
    padding: 0 12px;
    border-radius: 6px;
    border: 1px dashed var(--surface-card-border);
    background: transparent;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .reset-filters-btn:hover {
    background: var(--surface-card);
    border-color: #EF4444;
    color: #EF4444;
  }

  /* ═══ 3. OVERVIEW VIEW (EXECUTIVE DASHBOARD UI) ═════════════════ */
  .overview-view-container {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  /* Executive Bottleneck Radar Alert Banner */
  .executive-bottleneck-radar-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(239, 68, 68, 0.06);
    border: 1px solid rgba(239, 68, 68, 0.25);
    border-radius: 8px;
    padding: 12px 18px;
    gap: 16px;
  }
  .radar-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .radar-pulsing-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: #EF4444;
    box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
    animation: radarPulse 1.8s infinite;
    flex-shrink: 0;
  }
  @keyframes radarPulse {
    0% {
      transform: scale(0.95);
      box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
    }
    70% {
      transform: scale(1);
      box-shadow: 0 0 0 8px rgba(239, 68, 68, 0);
    }
    100% {
      transform: scale(0.95);
      box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
    }
  }
  .radar-text-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .radar-title {
    font-size: 13px;
    font-weight: 700;
    color: #B91C1C;
  }
  .radar-desc {
    font-size: 12px;
    color: #7F1D1D;
  }
  .radar-action-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: #EF4444;
    color: #FFFFFF;
    border: none;
    border-radius: 6px;
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
    white-space: nowrap;
  }
  .radar-action-btn:hover {
    background: #DC2626;
  }

  /* Top 4 KPI Metrics */
  .overview-kpi-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
  }

  .kpi-metric-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 10px;
    padding: 16px 18px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    text-align: left;
    cursor: pointer;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
    transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
  }
  .kpi-metric-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
    border-color: #0284C7;
  }

  .kpi-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .kpi-label {
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
  }
  .kpi-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 12px;
  }
  .kpi-badge.neutral { background: var(--surface-card-subtle); color: var(--text-secondary); }
  .kpi-badge.in-progress { background: rgba(2, 132, 199, 0.12); color: #0284C7; }
  .kpi-badge.review { background: rgba(245, 158, 11, 0.12); color: #D97706; }
  .kpi-badge.urgent { background: rgba(239, 68, 68, 0.12); color: #EF4444; }

  .kpi-number-row {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }
  .kpi-number {
    font-size: 28px;
    font-weight: 800;
    line-height: 1;
    color: var(--text-primary);
  }
  .kpi-trend-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-weight: 600;
    color: #10B981;
    background: rgba(16, 185, 129, 0.1);
    padding: 2px 6px;
    border-radius: 10px;
  }
  .kpi-subtext {
    font-size: 12px;
    color: var(--text-secondary);
    font-weight: 500;
  }

  .kpi-progress-bar {
    width: 100%;
    height: 5px;
    border-radius: 3px;
    background: var(--surface-card-border);
    overflow: hidden;
    margin-top: 4px;
  }
  .kpi-progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #0284C7, #10B981);
    border-radius: 3px;
  }
  .kpi-footer-hint {
    font-size: 11px;
    color: var(--text-tertiary, #94A3B8);
    margin-top: 4px;
  }

  /* Overview Card Shell */
  .overview-card {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 10px;
    padding: 20px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
  }
  .overview-card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  .card-header-titles {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .card-title {
    font-size: 16px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }
  .card-subtitle {
    font-size: 12px;
    color: var(--text-secondary);
  }
  .card-header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .btn-primary-sm {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 5px 12px;
    border-radius: 6px;
    border: none;
    background: #0284C7;
    color: #FFFFFF;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .btn-primary-sm:hover { background: #0369A1; }

  /* Workstreams Table */
  .overview-lists-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  .overview-lists-table th {
    text-align: left;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    padding: 10px 12px;
    border-bottom: 1px solid var(--surface-card-border);
  }
  .overview-lists-table td {
    padding: 14px 12px;
    border-bottom: 1px solid var(--surface-card-border);
    vertical-align: middle;
  }
  .overview-list-row {
    cursor: pointer;
    transition: background 0.12s;
  }
  .overview-list-row:hover {
    background: var(--surface-card-subtle);
  }
  .ws-name-cell {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .ws-icon-circle {
    width: 28px;
    height: 28px;
    border-radius: 6px;
    background: rgba(2, 132, 199, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .ws-name-meta {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .ws-task-total {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .status-distribution-pills {
    display: flex;
    align-items: center;
    gap: 5px;
    flex-wrap: wrap;
  }
  .mini-status-chip {
    font-size: 10px;
    font-weight: 700;
    padding: 1px 6px;
    border-radius: 10px;
    border: 1px solid transparent;
    background: var(--surface-card-subtle);
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
    border-radius: 3px;
  }
  .progress-percent-badge {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .progress-count {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .owners-avatar-stack {
    display: flex;
    align-items: center;
  }
  .mini-owner-circle {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #0284C7;
    color: #FFFFFF;
    font-size: 9px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--surface-card);
    margin-right: -6px;
  }
  .mini-owner-circle:nth-child(2) { background: #8B5CF6; }
  .mini-owner-circle:nth-child(3) { background: #10B981; }
  .owner-overflow-tag {
    font-size: 10px;
    font-weight: 600;
    color: var(--text-secondary);
    margin-left: 10px;
  }
  .unassigned-text {
    font-size: 11px;
    color: var(--text-tertiary, #94A3B8);
  }
  .table-action-pill {
    padding: 4px 10px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    font-size: 11px;
    font-weight: 600;
    color: #0284C7;
    cursor: pointer;
    transition: all 0.12s;
  }
  .table-action-pill:hover {
    background: rgba(2, 132, 199, 0.1);
    border-color: #0284C7;
  }

  /* Bottom Grid: Team Bandwidth & SVG Donut Chart */
  .overview-bottom-grid {
    display: grid;
    grid-template-columns: 1.15fr 0.85fr;
    gap: 20px;
  }

  .team-bandwidth-container {
    overflow-x: auto;
    padding: 0;
  }
  .team-bandwidth-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  .team-bandwidth-table th {
    text-align: left;
    padding: 8px 10px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }
  .team-bandwidth-table td {
    padding: 8px 10px;
    border-bottom: 1px solid var(--surface-card-border);
    vertical-align: middle;
  }
  .tb-row:hover {
    background: var(--surface-card-subtle);
  }
  .tb-user-cell {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .tb-avatar {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: #0078D4;
    color: #FFF;
    font-size: 10px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .tb-name {
    font-weight: 600;
    color: var(--text-primary);
  }
  .tb-status-badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 10px;
    font-weight: 700;
  }
  .tb-status-badge.busy {
    background: rgba(239, 68, 68, 0.12);
    color: #EF4444;
  }
  .tb-status-badge.optimal {
    background: rgba(16, 185, 129, 0.12);
    color: #10B981;
  }
  .tb-status-badge.light {
    background: rgba(100, 116, 139, 0.12);
    color: #64748B;
  }

  /* SVG Donut Chart */
  .workload-breakdown-row {
    display: flex;
    align-items: center;
    gap: 28px;
    padding: 8px 0;
  }
  .donut-chart-container {
    position: relative;
    width: 140px;
    height: 140px;
    flex-shrink: 0;
  }
  .donut-svg-ring {
    width: 100%;
    height: 100%;
    transform: rotate(0deg);
  }
  .donut-center-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    pointer-events: none;
  }
  .donut-stat-number {
    font-size: 24px;
    font-weight: 800;
    color: var(--text-primary);
    line-height: 1;
  }
  .donut-stat-label {
    font-size: 10px;
    font-weight: 600;
    color: var(--text-secondary);
    margin-top: 2px;
    text-transform: uppercase;
  }

  .donut-legend-table {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .legend-status-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.12s;
  }
  .legend-status-row:hover {
    background: var(--surface-card);
    border-color: #0284C7;
  }
  .legend-left-col {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .legend-dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
  }
  .legend-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary);
  }
  .legend-right-col {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .legend-count {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .legend-percent-tag {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 8px;
    background: rgba(0, 0, 0, 0.06);
    color: var(--text-secondary);
  }

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
    width: auto;
    min-width: 36px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    position: relative;
    color: var(--text-secondary);
  }

  .row-hover-actions {
    display: flex;
    align-items: center;
    gap: 4px;
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.15s ease, transform 0.15s ease;
    transform: translateX(4px);
    margin-right: 4px;
  }
  .clickup-task-row:hover .row-hover-actions {
    opacity: 1;
    pointer-events: auto;
    transform: translateX(0);
  }
  .clickup-task-row:hover .row-more-dots {
    display: none;
  }

  .micro-action-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    height: 24px;
    padding: 0 6px;
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.12s ease;
  }
  .micro-action-btn:hover {
    border-color: #0078D4;
    color: #0078D4;
    background: rgba(0, 120, 212, 0.08);
  }
  .micro-action-btn.advance:hover {
    border-color: #10B981;
    color: #10B981;
    background: rgba(16, 185, 129, 0.08);
  }
  .micro-btn-label {
    font-size: 10px;
    font-weight: 600;
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
  .nested-subtask-row.completed .nested-subtask-input {
    text-decoration: line-through;
    color: var(--text-secondary);
  }
  .nested-subtask-input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-size: 12px;
    color: var(--text-primary);
    padding: 2px 6px;
    border-radius: 4px;
    transition: background 0.12s, box-shadow 0.12s;
  }
  .nested-subtask-input:focus {
    background: var(--surface-card);
    box-shadow: 0 0 0 1px #0284C7;
  }
  .nested-subtask-quick-add {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    font-size: 12px;
  }
  .subtask-quick-input {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    font-size: 11.5px;
    color: var(--text-primary);
    padding: 3px 6px;
    border-radius: 4px;
  }
  .subtask-quick-input:focus {
    background: var(--surface-card);
    box-shadow: 0 0 0 1px #0284C7;
  }
  .subtask-quick-input::placeholder {
    color: var(--text-tertiary, #94A3B8);
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

  /* ═══ 5. BOARD VIEW (STRICT 4 COLUMNS IN SINGLE ROW) ════════════ */
  .clickup-board-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(260px, 1fr));
    gap: 16px;
    padding: 20px;
    align-items: start;
    overflow-x: auto;
    width: 100%;
    box-sizing: border-box;
  }

  .board-column {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    min-height: 520px;
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
    border-color: #0284C7;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
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

  /* Priority color-coded badges */
  .priority-pill-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 10px;
  }
  .priority-pill-badge.urgent {
    background: #FEE2E2;
    color: #B91C1C;
    border: 1px solid #FECACA;
  }
  .priority-pill-badge.high {
    background: #FFEDD5;
    color: #C2410C;
    border: 1px solid #FED7AA;
  }
  .priority-pill-badge.medium {
    background: #E0F2FE;
    color: #0369A1;
    border: 1px solid #BAE6FD;
  }
  .priority-pill-badge.low {
    background: #F1F5F9;
    color: #475569;
    border: 1px solid #CBD5E1;
  }

  .card-bottom-assignee {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .card-assignee-name {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
  }
  .card-assignee-name.unassigned {
    color: var(--text-tertiary, #94A3B8);
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
  .gantt-schedule-bar.status-review { background: #F59E0B; }
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

  .timeline-range-pill {
    display: inline-flex;
    align-items: center;
    font-size: 11.5px;
    font-weight: 600;
    color: var(--text-primary);
    padding: 4px 10px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    letter-spacing: 0.2px;
  }

  /* ═══ 7. TABLE VIEW (Interactive Multi-Select & Sortable Grid) ═════ */
  .clickup-table-container {
    position: relative;
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
  .sortable-th {
    cursor: pointer;
    user-select: none;
    transition: background 0.12s, color 0.12s;
  }
  .sortable-th:hover {
    background: var(--surface-card-subtle);
    color: var(--text-primary);
  }
  .clickup-data-table td {
    padding: 6px 10px;
    border-bottom: 1px solid var(--surface-card-border);
    border-right: 1px solid var(--surface-card-border);
  }
  .clickup-table-row {
    cursor: pointer;
    transition: background 0.1s ease;
  }
  .clickup-table-row:hover {
    background: var(--surface-card-subtle);
  }
  .clickup-table-row.row-selected {
    background: rgba(2, 132, 199, 0.08);
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
    background: #F59E0B;
    color: #FFF;
    border-color: #F59E0B;
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

  /* Floating Batch Action Bar */
  .batch-action-bar {
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: #1E293B;
    color: #F8FAFC;
    padding: 10px 18px;
    border-radius: 30px;
    box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 8px 10px -6px rgba(0, 0, 0, 0.2);
    display: flex;
    align-items: center;
    gap: 16px;
    z-index: 999;
    animation: slideUpFade 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes slideUpFade {
    from {
      opacity: 0;
      transform: translate(-50%, 15px);
    }
    to {
      opacity: 1;
      transform: translate(-50%, 0);
    }
  }

  .batch-summary {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 600;
  }
  .batch-count-badge {
    background: #0284C7;
    color: #FFF;
    border-radius: 12px;
    padding: 2px 8px;
    font-size: 11px;
    font-weight: 700;
  }

  .batch-actions-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .batch-btn {
    border: none;
    background: rgba(255, 255, 255, 0.12);
    color: #FFF;
    font-size: 12px;
    font-weight: 600;
    padding: 6px 12px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .batch-btn:hover {
    background: rgba(255, 255, 255, 0.22);
  }
  .batch-btn.success {
    background: #10B981;
    color: #FFF;
  }
  .batch-btn.success:hover {
    background: #059669;
  }
  .batch-btn.danger {
    background: #EF4444;
    color: #FFF;
  }
  .batch-btn.danger:hover {
    background: #DC2626;
  }
  .batch-btn.ghost {
    background: transparent;
    color: #94A3B8;
  }
  .batch-btn.ghost:hover {
    color: #FFF;
  }

  /* Loading & Animation */
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

  :global(.spinning) {
    animation: spin 0.8s linear infinite;
  }

  .clickup-checkbox {
    width: 14px;
    height: 14px;
    cursor: pointer;
  }
</style>

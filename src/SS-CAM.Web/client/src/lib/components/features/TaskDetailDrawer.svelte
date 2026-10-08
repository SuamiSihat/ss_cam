<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { 
    StudioTask, 
    StudioTaskStatus, 
    ProjectPriority, 
    TaskDecisionStatus, 
    TaskSubtask, 
    Project 
  } from '$lib/types';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface Props {
    open: boolean;
    task: StudioTask | null;
    allTasks?: StudioTask[];
    staffRoster?: any[];
    onClose: () => void;
    onUpdated: (task: StudioTask) => void;
    onDeleted?: (taskId: string) => void;
  }

  let {
    open = $bindable(false),
    task,
    allTasks = [],
    staffRoster = [],
    onClose,
    onUpdated,
    onDeleted
  }: Props = $props();

  // Basic task fields
  let title = $state('');
  let status = $state<StudioTaskStatus>('backlog');
  let priority = $state<ProjectPriority>('medium');
  let brand = $state('SS');
  let workstream = $state('Packaging');
  let assignee = $state('');
  let startDate = $state('');
  let dueDate = $state('');
  let tagsInput = $state('');
  let description = $state('');
  let specs = $state('');

  // Decision fields
  let decisionStatus = $state<TaskDecisionStatus>('pending');
  let decisionSummary = $state('');

  // Subtasks & Dependencies
  let subtasks = $state<TaskSubtask[]>([]);
  let newSubtaskTitle = $state('');
  let blockedBy = $state<string[]>([]);
  let blocks = $state<string[]>([]);

  // Project Catalog Linking
  let projectId = $state<string | undefined>(undefined);
  let projectTitle = $state<string | undefined>(undefined);
  let availableProjects = $state<Project[]>([]);
  let isLoadingProjects = $state(false);

  // Gemini AI Assistant & Tabs
  let activeTab = $state<'checklist' | 'specs' | 'ai-assistant' | 'activity'>('checklist');
  let aiChatPrompt = $state('');
  let isAiWorking = $state(false);
  let aiMessages = $state<Array<{ role: 'user' | 'assistant'; text: string; time: string }>>([]);
  let preflightIssues = $state<Array<{ type: 'blocker' | 'warning' | 'info'; message: string }>>([]);

  // Comments / Activity
  let newCommentText = $state('');

  // Provisioning
  let isSaving = $state(false);
  let isDeleting = $state(false);
  let showDeleteConfirm = $state(false);
  let isProvisioning = $state(false);
  let showProvisionForm = $state(false);
  let presetType = $state('Graphic & Print Design');
  let provisionDesigner = $state('');

  const brandOptions = [
    { code: 'SS', label: 'SuamiSihat (Primary)' },
    { code: 'SSH', label: 'SuamiSihat Holding' },
    { code: 'SSC', label: 'SuamiSihat Healthcare' },
    { code: 'SSW', label: 'SuamiSihat Wellness' },
    { code: 'SSE', label: 'SuamiSihat E-Commerce' },
    { code: 'SST', label: 'SuamiSihat Technology' }
  ];

  const workstreamOptions = [
    'Packaging',
    'Signage',
    'Copywriting',
    'Motion & Video',
    'Digital & Social',
    'Brand Asset',
    '3D Rendering',
    'General Studio'
  ];

  const statusOptions: { id: StudioTaskStatus; label: string; icon: string }[] = [
    { id: 'backlog', label: 'Backlog / Intake', icon: 'file' },
    { id: 'in-progress', label: 'In Progress', icon: 'bolt' },
    { id: 'review', label: 'Review & QA', icon: 'search' },
    { id: 'done', label: 'Approved & Done', icon: 'checkCircle' },
    { id: 'converted', label: 'NAS Vault Provisioned', icon: 'box' }
  ];

  const priorityOptions: { id: ProjectPriority; label: string; color: string }[] = [
    { id: 'urgent', label: 'Urgent (P3)', color: '#EF4444' },
    { id: 'high', label: 'High (P2)', color: '#F97316' },
    { id: 'medium', label: 'Medium (P1)', color: '#0284C7' },
    { id: 'low', label: 'Low', color: '#64748B' }
  ];

  const decisionOptions: { id: TaskDecisionStatus; label: string; badge: string; color: string }[] = [
    { id: 'pending', label: 'Pending Evaluation', badge: 'Pending', color: 'var(--text-secondary)' },
    { id: 'in_review', label: 'In Team Review', badge: 'Reviewing', color: '#8B5CF6' },
    { id: 'approved', label: 'Approved for Production', badge: 'Approved', color: '#10B981' },
    { id: 'changes_requested', label: 'Changes Requested', badge: 'Revisions', color: '#F59E0B' },
    { id: 'rejected', label: 'Rejected / Shelved', badge: 'Rejected', color: '#EF4444' }
  ];

  async function loadProjects() {
    if (availableProjects.length > 0) return;
    isLoadingProjects = true;
    try {
      const res = await ApiClient.getProjects();
      if (res && Array.isArray(res.projects)) {
        availableProjects = res.projects;
      }
    } catch (e: any) {
      console.debug('[TaskDetailDrawer] Failed to load projects:', e.message);
    } finally {
      isLoadingProjects = false;
    }
  }

  onMount(() => {
    loadProjects();
  });

  // Sync state whenever task prop changes
  $effect(() => {
    if (task) {
      title = task.title || '';
      status = task.status || 'backlog';
      priority = task.priority || 'medium';
      brand = task.brand || 'SS';
      workstream = task.workstream || 'Packaging';
      assignee = task.assignee || '';
      startDate = task.startDate ? task.startDate.split('T')[0] : '';
      dueDate = task.dueDate ? task.dueDate.split('T')[0] : '';
      tagsInput = Array.isArray(task.tags) ? task.tags.join(', ') : '';
      description = task.description || '';
      specs = task.specs || '';
      decisionStatus = task.decisionStatus || 'pending';
      decisionSummary = task.decisionSummary || '';
      subtasks = Array.isArray(task.subtasks) ? JSON.parse(JSON.stringify(task.subtasks)) : [];
      blockedBy = Array.isArray(task.blockedBy) ? [...task.blockedBy] : [];
      blocks = Array.isArray(task.blocks) ? [...task.blocks] : [];
      projectId = task.projectId || undefined;
      projectTitle = task.projectTitle || undefined;
      provisionDesigner = task.assigneeName || task.assignee || 'Harussani';
      showProvisionForm = false;
      showDeleteConfirm = false;
      aiMessages = [];
      preflightIssues = [];
    }
  });

  const assignedMember = $derived.by(() => {
    if (!assignee) return null;
    return staffRoster.find(
      s => (s.staffId && s.staffId.toLowerCase() === assignee.toLowerCase()) ||
           (s.username && s.username.toLowerCase() === assignee.toLowerCase())
    ) || null;
  });

  const otherTasks = $derived.by(() => {
    if (!task) return [];
    return allTasks.filter(t => t.id !== task.id);
  });

  // Active blockers: tasks that this task is waiting on that are not completed
  const activeBlockers = $derived.by(() => {
    if (!blockedBy || blockedBy.length === 0) return [];
    return allTasks.filter(t => blockedBy.includes(t.id) && t.status !== 'done' && t.status !== 'converted');
  });

  // Subtasks completion calculation
  const subtasksProgress = $derived.by(() => {
    const total = subtasks.length;
    if (total === 0) return { total: 0, completed: 0, percent: 0 };
    const completed = subtasks.filter(s => s.completed).length;
    return {
      total,
      completed,
      percent: Math.round((completed / total) * 100)
    };
  });

  function closeDrawer() {
    showDeleteConfirm = false;
    open = false;
    if (onClose) onClose();
  }

  function close() {
    closeDrawer();
  }

  function handleAddSubtask() {
    const t = newSubtaskTitle.trim();
    if (!t) return;
    subtasks = [
      ...subtasks,
      {
        id: `st-${Date.now()}-${subtasks.length}`,
        title: t,
        completed: false
      }
    ];
    newSubtaskTitle = '';
    handleQuickSubtaskSave();
  }

  function handleToggleSubtask(subtaskId: string) {
    subtasks = subtasks.map(s => (s.id === subtaskId ? { ...s, completed: !s.completed } : s));
    handleQuickSubtaskSave();
  }

  function handleDeleteSubtask(subtaskId: string) {
    subtasks = subtasks.filter(s => s.id !== subtaskId);
    handleQuickSubtaskSave();
  }

  async function handleQuickSubtaskSave() {
    if (!task) return;
    try {
      const res = await ApiClient.updateStudioTask(task.id, { subtasks });
      onUpdated(res.task);
    } catch (e: any) {
      console.warn('[TaskDetailDrawer] Quick subtask save error:', e.message);
    }
  }

  function toggleBlockedBy(otherId: string) {
    if (blockedBy.includes(otherId)) {
      blockedBy = blockedBy.filter(id => id !== otherId);
    } else {
      blockedBy = [...blockedBy, otherId];
    }
  }

  function toggleBlocks(otherId: string) {
    if (blocks.includes(otherId)) {
      blocks = blocks.filter(id => id !== otherId);
    } else {
      blocks = [...blocks, otherId];
    }
  }

  function handleSelectProject(e: Event) {
    const target = e.target as HTMLSelectElement;
    const selectedId = target.value;
    if (!selectedId) {
      projectId = undefined;
      projectTitle = undefined;
      return;
    }
    const found = availableProjects.find(p => p.id === selectedId);
    if (found) {
      projectId = found.id;
      projectTitle = found.title;
    }
  }

  async function handleSave() {
    if (!task) return;
    if (!title.trim()) {
      appState.addToast('Task title cannot be empty', 'warning');
      return;
    }

    isSaving = true;
    try {
      const selectedMember = assignedMember;
      const tags = tagsInput
        .split(',')
        .map(t => t.trim())
        .filter(Boolean);

      const res = await ApiClient.updateStudioTask(task.id, {
        title: title.trim(),
        status,
        priority,
        brand,
        workstream,
        assignee,
        assigneeName: selectedMember ? selectedMember.name : assignee,
        assigneeAvatarColor: selectedMember ? selectedMember.avatarColor : undefined,
        startDate: startDate || undefined,
        dueDate: dueDate || undefined,
        tags,
        description: description.trim(),
        specs: specs.trim(),
        decisionStatus,
        decisionSummary: decisionSummary.trim(),
        subtasks,
        blockedBy,
        blocks,
        projectId,
        projectTitle
      });

      appState.addToast(`Saved changes for ${task.id}`, 'success');
      onUpdated(res.task);
    } catch (err: any) {
      appState.addToast(`Failed to update task: ${err.message}`, 'error');
    } finally {
      isSaving = false;
    }
  }

  async function handleAiAssist(action: string, prompt = '') {
    if (!task) return;
    isAiWorking = true;
    try {
      const res = await ApiClient.aiAssistStudioTask(task.id, { action, prompt });
      
      if (res.reply) {
        aiMessages = [
          ...aiMessages,
          ...(prompt ? [{ role: 'user' as const, text: prompt, time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }] : []),
          { role: 'assistant' as const, text: res.reply, time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }
        ];
      }

      if (action === 'subtasks' && res.suggestedSubtasks && res.suggestedSubtasks.length > 0) {
        subtasks = [...subtasks, ...res.suggestedSubtasks];
        await handleQuickSubtaskSave();
        appState.addToast(`Appended ${res.suggestedSubtasks.length} subtasks generated by Gemini!`, 'success');
        activeTab = 'checklist';
      }

      if (action === 'specs' && res.suggestedSpecs) {
        specs = res.suggestedSpecs;
        appState.addToast('Drafted production specifications with Gemini!', 'success');
        activeTab = 'specs';
      }

      if (action === 'preflight' && res.preflightIssues) {
        preflightIssues = res.preflightIssues;
      }
    } catch (err: any) {
      appState.addToast(`AI assistant error: ${err.message}`, 'error');
    } finally {
      isAiWorking = false;
    }
  }

  function handleSendAiChat() {
    if (!aiChatPrompt.trim()) return;
    const p = aiChatPrompt.trim();
    aiChatPrompt = '';
    handleAiAssist('chat', p);
  }

  async function handleAddComment() {
    if (!task || !newCommentText.trim()) return;
    const text = newCommentText.trim();
    newCommentText = '';

    const newComment = {
      id: `cm-${Date.now()}`,
      author: appState.currentUser?.name || appState.currentUser?.username || 'Staff',
      authorAvatar: appState.currentUser?.avatarColor || '#0078D4',
      message: text,
      timestamp: new Date().toISOString()
    };

    const currentComments = Array.isArray(task.comments) ? [...task.comments, newComment] : [newComment];
    try {
      const res = await ApiClient.updateStudioTask(task.id, { comments: currentComments });
      onUpdated(res.task);
      appState.addToast('Comment posted', 'info');
    } catch (err: any) {
      appState.addToast(`Failed to post comment: ${err.message}`, 'error');
    }
  }

  function handleDeleteClick() {
    showDeleteConfirm = true;
  }

  function handleCancelDelete() {
    showDeleteConfirm = false;
  }

  async function handleConfirmDelete() {
    if (!task) return;
    isDeleting = true;
    try {
      await ApiClient.deleteStudioTask(task.id);
      appState.addToast(`Deleted task ${task.id}`, 'info');
      if (onDeleted) onDeleted(task.id);
      closeDrawer();
    } catch (err: any) {
      appState.addToast(`Failed to delete task: ${err.message}`, 'error');
    } finally {
      isDeleting = false;
      showDeleteConfirm = false;
    }
  }

  async function handleDelete() {
    handleDeleteClick();
  }

  async function handleProvision() {
    if (!task) return;
    isProvisioning = true;
    try {
      const res = await ApiClient.provisionTaskWorkspace(task.id, {
        brand,
        presetType,
        designer: provisionDesigner || task.assigneeName || 'Design-Studio'
      });

      appState.addToast(`Provisioned NAS Project ${res.jobId}!`, 'success', 'NAS Workspace Ready');
      status = 'converted';
      projectId = res.projectId || res.jobId;
      projectTitle = task.title;
      if (res.task) {
        onUpdated(res.task);
      }
      showProvisionForm = false;
    } catch (err: any) {
      appState.addToast(`Provisioning failed: ${err.message}`, 'error');
    } finally {
      isProvisioning = false;
    }
  }

  function jumpToProject() {
    if (projectId || task?.jobId) {
      closeDrawer();
      appState.navigate('project-detail', { id: projectId || task?.jobId });
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape' && open) {
      closeDrawer();
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if open && task}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="drawer-backdrop" onclick={closeDrawer}></div>

  <aside class="task-drawer" role="dialog" aria-label="Task Details">
    <!-- ═══ HEADER ═══ -->
    <div class="drawer-header">
      <div class="header-left">
        <span class="task-id-badge">#{task.id}</span>
        <FluentBadge type="brand" value={brand} />
        <span class="workstream-badge">{workstream}</span>
        <span class="decision-badge decision-{decisionStatus}">
          {decisionOptions.find(d => d.id === decisionStatus)?.badge || decisionStatus}
        </span>
      </div>

      <div class="header-right">
        <button class="close-icon-btn" onclick={closeDrawer} aria-label="Close drawer" title="Close drawer">
          <FluentIcons name="close" size={16} />
        </button>
      </div>
    </div>

    <!-- Active Blocker Alert Banner -->
    {#if activeBlockers.length > 0}
      <div class="blocker-alert-banner">
        <div class="alert-icon">
          <FluentIcons name="warning" size={18} color="#D97706" />
        </div>
        <div class="alert-content">
          <strong>Pipeline Blocked:</strong> Waiting on {activeBlockers.length} prerequisite task(s) to finish:
          <span class="blocker-names">
            {activeBlockers.map(b => `${b.id} (${b.title})`).join(', ')}
          </span>
        </div>
      </div>
    {/if}

    <!-- ═══ BODY SCROLL CONTAINER ═══ -->
    <div class="drawer-body">
      <!-- Title Input (Main Task) -->
      <div class="title-field-group">
        <label for="task-title-input" class="field-label"># MAIN TASK</label>
        <input
          id="task-title-input"
          type="text"
          class="title-input"
          bind:value={title}
          placeholder="Task title or concept overview..."
        />
      </div>

      <!-- Quick Stage / Status Strip -->
      <div class="field-group">
        <label class="field-label">WORKSTREAM STAGE</label>
        <div class="status-strip">
          {#each statusOptions as opt}
            <button
              type="button"
              class="status-btn"
              class:selected={status === opt.id}
              onclick={() => (status = opt.id)}
            >
              <FluentIcons name={opt.icon as any} size={14} />
              <span>{opt.label}</span>
            </button>
          {/each}
        </div>
      </div>

      <!-- Metadata Grid -->
      <div class="meta-grid">
        <!-- Workstream -->
        <div class="field-group">
          <label for="task-workstream-select" class="field-label">WORKSTREAM / DEPARTMENT</label>
          <select id="task-workstream-select" class="fluent-select" bind:value={workstream}>
            {#each workstreamOptions as ws}
              <option value={ws}>{ws}</option>
            {/each}
          </select>
        </div>

        <!-- Priority -->
        <div class="field-group">
          <label for="task-priority-select" class="field-label">PRIORITY</label>
          <select id="task-priority-select" class="fluent-select" bind:value={priority}>
            {#each priorityOptions as p}
              <option value={p.id}>{p.label}</option>
            {/each}
          </select>
        </div>

        <!-- Subsidiary Brand -->
        <div class="field-group">
          <label for="task-brand-select" class="field-label">SUBSIDIARY BRAND</label>
          <select id="task-brand-select" class="fluent-select" bind:value={brand}>
            {#each brandOptions as b}
              <option value={b.code}>[{b.code}] {b.label}</option>
            {/each}
          </select>
        </div>

        <!-- Lead Assignee -->
        <div class="field-group">
          <label for="task-assignee-select" class="field-label">LEAD ASSIGNEE</label>
          <select id="task-assignee-select" class="fluent-select" bind:value={assignee}>
            <option value="">Unassigned</option>
            {#each staffRoster as staff}
              <option value={staff.staffId || staff.username}>
                {staff.name} ({staff.staffId || staff.role})
              </option>
            {/each}
          </select>
        </div>
      </div>

      <!-- Timeline & Schedule -->
      <div class="field-group">
        <label class="field-label">PRODUCTION TIMELINE</label>
        <div class="timeline-inputs-grid">
          <div class="date-input-wrap">
            <span class="sub-label">Start Date</span>
            <input type="date" class="fluent-date-input" bind:value={startDate} />
          </div>
          <div class="date-input-wrap">
            <span class="sub-label">Due Date</span>
            <input type="date" class="fluent-date-input" bind:value={dueDate} />
          </div>
        </div>
      </div>

      <!-- ═══ SUBTASKS BREAKDOWN (Create by Return Key) ═══ -->
      <div class="subtasks-detail-card">
        <div class="subtasks-detail-header">
          <span class="card-section-title">
            <FluentIcons name="list" size={16} />
            Subtasks Breakdown
          </span>
          <span class="subtasks-pill-count">
            {subtasks.filter(s => s.completed).length}/{subtasks.length} Completed
          </span>
        </div>

        {#if subtasks.length > 0}
          <div class="subtasks-detail-list">
            {#each subtasks as sub, index (sub.id)}
              <div class="subtask-detail-row" class:is-done={sub.completed}>
                <input
                  type="checkbox"
                  checked={sub.completed}
                  onchange={() => handleToggleSubtask(sub.id)}
                  class="clickup-checkbox"
                />
                <input
                  id={`subtask-input-${sub.id}`}
                  type="text"
                  bind:value={sub.title}
                  placeholder="Enter subtask title..."
                  class="subtask-inline-edit-input"
                  onblur={handleQuickSubtaskSave}
                  onkeydown={(e) => handleSubtaskTitleKeydown(e, index)}
                />
                <button
                  type="button"
                  class="delete-subtask-row-btn"
                  onclick={() => handleDeleteSubtask(sub.id)}
                  title="Remove subtask"
                >
                  ✕
                </button>
              </div>
            {/each}
          </div>
        {/if}

        <!-- Add Subtask Quick Input (Press Enter) -->
        <div class="add-subtask-detail-row">
          <span class="add-subtask-icon">＋</span>
          <input
            type="text"
            placeholder="Add a new subtask (press Enter to create)..."
            bind:value={newSubtaskTitle}
            class="add-subtask-detail-input"
            onkeydown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                handleAddSubtask();
              }
            }}
          />
          {#if newSubtaskTitle.trim()}
            <button type="button" class="btn-submit-subtask" onclick={handleAddSubtask}>
              Add
            </button>
          {/if}
        </div>
      </div>

      <!-- Decision State & Sign-Off Summary -->
      <div class="decision-card">
        <div class="decision-card-header">
          <span class="card-section-title">
            <FluentIcons name="checkCircle" size={16} />
            Decision &amp; Sign-off State
          </span>
          <select class="fluent-select sm" bind:value={decisionStatus}>
            {#each decisionOptions as opt}
              <option value={opt.id}>{opt.label}</option>
            {/each}
          </select>
        </div>
        <div class="decision-summary-wrap">
          <label for="task-decision-summary" class="sub-label">Decision Notes / Blocker Summary</label>
          <textarea
            id="task-decision-summary"
            class="fluent-textarea sm"
            rows="2"
            placeholder="Document sign-off conditions, specifications, or revision requirements..."
            bind:value={decisionSummary}
          ></textarea>
        </div>
      </div>

      <!-- Pipeline Dependencies (Waiting On & Blocks) -->
      <div class="dependencies-card">
        <span class="card-section-title">
          <FluentIcons name="timeline" size={16} />
          Pipeline Dependencies
        </span>
        <p class="section-hint">Link prerequisite tasks that must finish before this task can start, or downstream tasks waiting on this deliverable.</p>

        <div class="dep-grid">
          <!-- Waiting on -->
          <div class="dep-col">
            <span class="dep-header">Waiting on (Prerequisites):</span>
            <div class="dep-chips-wrap">
              {#if blockedBy.length === 0}
                <span class="dep-empty">None (Unblocked)</span>
              {:else}
                {#each blockedBy as depId}
                  {@const depTask = allTasks.find(t => t.id === depId)}
                  <span class="dep-chip" class:dep-unfinished={depTask && depTask.status !== 'done'}>
                    <FluentIcons name={depTask?.status === 'done' ? 'checkmark' : 'warning'} size={12} />
                    <span>{depId} {depTask ? `(${depTask.status})` : ''}</span>
                    <button type="button" class="remove-dep-btn" onclick={() => toggleBlockedBy(depId)}>✕</button>
                  </span>
                {/each}
              {/if}
            </div>
            <!-- Add prerequisite dropdown -->
            {#if otherTasks.length > 0}
              <div class="add-dep-row">
                <select class="fluent-select xs" onchange={(e) => {
                  const val = (e.target as HTMLSelectElement).value;
                  if (val) { toggleBlockedBy(val); (e.target as HTMLSelectElement).value = ''; }
                }}>
                  <option value="">＋ Add prerequisite task…</option>
                  {#each otherTasks.filter(t => !blockedBy.includes(t.id)) as t}
                    <option value={t.id}>[{t.id}] {t.title} ({t.status})</option>
                  {/each}
                </select>
              </div>
            {/if}
          </div>

          <!-- Blocks -->
          <div class="dep-col">
            <span class="dep-header">Blocks (Downstream):</span>
            <div class="dep-chips-wrap">
              {#if blocks.length === 0}
                <span class="dep-empty">None (No downstream tasks)</span>
              {:else}
                {#each blocks as blockId}
                  {@const blkTask = allTasks.find(t => t.id === blockId)}
                  <span class="dep-chip">
                    <FluentIcons name="arrowRight" size={12} />
                    <span>{blockId} {blkTask ? `(${blkTask.title})` : ''}</span>
                    <button type="button" class="remove-dep-btn" onclick={() => toggleBlocks(blockId)}>✕</button>
                  </span>
                {/each}
              {/if}
            </div>
            {#if otherTasks.length > 0}
              <div class="add-dep-row">
                <select class="fluent-select xs" onchange={(e) => {
                  const val = (e.target as HTMLSelectElement).value;
                  if (val) { toggleBlocks(val); (e.target as HTMLSelectElement).value = ''; }
                }}>
                  <option value="">＋ Add blocked task…</option>
                  {#each otherTasks.filter(t => !blocks.includes(t.id)) as t}
                    <option value={t.id}>[{t.id}] {t.title}</option>
                  {/each}
                </select>
              </div>
            {/if}
          </div>
        </div>
      </div>

      <!-- ═══ NAS PROJECT CATALOG LINKING & BRIDGE ═══ -->
      <div class="bridge-card" class:is-provisioned={status === 'converted' || !!projectId}>
        <div class="bridge-header">
          <div class="bridge-icon-wrap">
            <FluentIcons name="box" size={18} />
          </div>
          <div class="bridge-title-wrap">
            <h4>NAS Project Vault Integration</h4>
            <p>Connect this task to an official Synology NAS workspace folder or scaffold a new vault.</p>
          </div>
        </div>

        {#if projectId}
          <div class="bridge-details">
            <div class="bridge-meta-row">
              <span class="lbl">Linked NAS Project:</span>
              <span class="val highlight">{projectTitle || projectId}</span>
            </div>
            <div class="bridge-meta-row">
              <span class="lbl">Vault ID:</span>
              <span class="val path-val">{projectId}</span>
            </div>
          </div>
          <div class="bridge-actions">
            <FluentButton appearance="primary" onclick={jumpToProject}>
              Open Project Vault ↗
            </FluentButton>
            <button type="button" class="unlink-btn" onclick={() => { projectId = undefined; projectTitle = undefined; }}>
              Unlink Project
            </button>
          </div>
        {:else}
          <div class="link-existing-row">
            <label for="link-project-select" class="sub-label">Link to Existing NAS Project:</label>
            <select id="link-project-select" class="fluent-select" onchange={handleSelectProject}>
              <option value="">-- Choose project from NAS catalog --</option>
              {#each availableProjects as p}
                <option value={p.id}>[{p.id}] {p.title || p.folderName || p.id}</option>
              {/each}
            </select>
          </div>

          <div class="bridge-or-divider">
            <span>OR</span>
          </div>

          {#if showProvisionForm}
            <div class="provision-form">
              <div class="form-row">
                <label for="provision-preset" class="field-label">PIPELINE PRESET</label>
                <select id="provision-preset" class="fluent-select" bind:value={presetType}>
                  <option value="Graphic & Print Design">Graphic &amp; Print Design (5 Folders + COPY.md)</option>
                  <option value="Video Production">Video Production (Raw Footage + Audio Stems)</option>
                  <option value="Social Media Marketing">Social Media Marketing (Carousels &amp; Banners)</option>
                </select>
              </div>

              <div class="form-row">
                <label for="provision-designer" class="field-label">TARGET DESIGNER DIRECTORY</label>
                <input
                  id="provision-designer"
                  type="text"
                  class="fluent-text-input"
                  bind:value={provisionDesigner}
                  placeholder="Designer folder name (e.g. Harussani)"
                />
              </div>

              <div class="provision-btn-row">
                <FluentButton
                  appearance="primary"
                  onclick={handleProvision}
                  disabled={isProvisioning}
                >
                  {isProvisioning ? 'Scaffolding NAS Folders…' : 'Confirm & Provision Vault'}
                </FluentButton>
                <FluentButton
                  appearance="secondary"
                  onclick={() => (showProvisionForm = false)}
                >
                  Cancel
                </FluentButton>
              </div>
            </div>
          {:else}
            <div class="bridge-actions">
              <FluentButton
                appearance="secondary"
                onclick={() => (showProvisionForm = true)}
              >
                ＋ Scaffold New NAS Vault
              </FluentButton>
            </div>
          {/if}
        {/if}
      </div>

      <!-- ═══ TABBED DETAILED SECTIONS ═══ -->
      <div class="section-tabs-container">
        <div class="tabs-header-strip">
          <button
            type="button"
            class="tab-strip-btn"
            class:active={activeTab === 'checklist'}
            onclick={() => (activeTab = 'checklist')}
          >
            <FluentIcons name="list" size={14} />
            <span>Subtasks ({subtasksProgress.completed}/{subtasksProgress.total})</span>
          </button>

          <button
            type="button"
            class="tab-strip-btn"
            class:active={activeTab === 'specs'}
            onclick={() => (activeTab = 'specs')}
          >
            <FluentIcons name="file" size={14} />
            <span>Technical Specs</span>
          </button>

          <button
            type="button"
            class="tab-strip-btn"
            class:active={activeTab === 'ai-assistant'}
            onclick={() => (activeTab = 'ai-assistant')}
          >
            <FluentIcons name="sparkles" size={14} />
            <span>Gemini AI Studio</span>
          </button>

          <button
            type="button"
            class="tab-strip-btn"
            class:active={activeTab === 'activity'}
            onclick={() => (activeTab = 'activity')}
          >
            <FluentIcons name="comments" size={14} />
            <span>Activity &amp; Comments</span>
          </button>
        </div>

        <!-- TAB 1: SUBTASKS CHECKLIST -->
        {#if activeTab === 'checklist'}
          <div class="tab-pane">
            <div class="checklist-header">
              <div class="checklist-progress-wrap">
                <div class="progress-bar-bg">
                  <div class="progress-bar-fill" style="width: {subtasksProgress.percent}%;"></div>
                </div>
                <span class="progress-text">{subtasksProgress.completed} of {subtasksProgress.total} completed ({subtasksProgress.percent}%)</span>
              </div>

              <button
                type="button"
                class="ai-suggest-btn"
                onclick={() => handleAiAssist('subtasks')}
                disabled={isAiWorking}
              >
                <FluentIcons name="sparkle" size={13} />
                <span>{isAiWorking ? 'Generating…' : 'AI Generate Subtasks'}</span>
              </button>
            </div>

            <!-- List of Subtasks -->
            <div class="subtasks-list">
              {#if subtasks.length === 0}
                <div class="empty-subtasks">
                  <p>No subtasks yet. Add specific deliverable items below or click <strong>AI Generate Subtasks</strong>.</p>
                </div>
              {:else}
                {#each subtasks as sub (sub.id)}
                  <div class="subtask-item" class:completed={sub.completed}>
                    <input
                      type="checkbox"
                      checked={sub.completed}
                      onchange={() => handleToggleSubtask(sub.id)}
                      class="subtask-checkbox"
                    />
                    <input
                      type="text"
                      class="subtask-title-input"
                      bind:value={sub.title}
                      onblur={handleQuickSubtaskSave}
                    />
                    <button
                      type="button"
                      class="delete-subtask-btn"
                      onclick={() => handleDeleteSubtask(sub.id)}
                      title="Remove subtask"
                    >
                      ✕
                    </button>
                  </div>
                {/each}
              {/if}

              <!-- Inline Add Subtask -->
              <div class="add-subtask-row">
                <input
                  type="text"
                  class="add-subtask-input"
                  placeholder="＋ Add subtask checklist item (press Enter)…"
                  bind:value={newSubtaskTitle}
                  onkeydown={(e) => { if (e.key === 'Enter') handleAddSubtask(); }}
                />
                <button type="button" class="add-subtask-btn" onclick={handleAddSubtask}>
                  Add
                </button>
              </div>
            </div>
          </div>

        <!-- TAB 2: TECHNICAL SPECS & NOTES -->
        {:else if activeTab === 'specs'}
          <div class="tab-pane">
            <div class="specs-toolbar">
              <span class="section-hint">Dielines, dimensions, color profiles (CMYK/RGB), bleeds, and typography rules.</span>
              <button
                type="button"
                class="ai-suggest-btn"
                onclick={() => handleAiAssist('specs')}
                disabled={isAiWorking}
              >
                <FluentIcons name="sparkles" size={13} />
                <span>Draft Specs with AI</span>
              </button>
            </div>
            <textarea
              class="fluent-textarea"
              rows="8"
              bind:value={specs}
              placeholder="e.g. Dimensions: 150x200mm, 3mm Bleed, Fogra39 CMYK, Spot Pantone Gold..."
            ></textarea>
          </div>

        <!-- TAB 3: GEMINI AI ASSISTANT -->
        {:else if activeTab === 'ai-assistant'}
          <div class="tab-pane ai-tab-pane">
            <!-- 1-Click Prompt Action Chips -->
            <div class="ai-chips-bar">
              <button
                type="button"
                class="ai-action-chip"
                onclick={() => handleAiAssist('subtasks')}
                disabled={isAiWorking}
              >
                <FluentIcons name="bolt" size={13} />
                Break down into Subtasks
              </button>

              <button
                type="button"
                class="ai-action-chip"
                onclick={() => handleAiAssist('specs')}
                disabled={isAiWorking}
              >
                <FluentIcons name="file" size={13} />
                Draft Technical Dieline Specs
              </button>

              <button
                type="button"
                class="ai-action-chip"
                onclick={() => handleAiAssist('preflight')}
                disabled={isAiWorking}
              >
                <FluentIcons name="warning" size={13} />
                Preflight Blocker Check
              </button>
            </div>

            <!-- Preflight Audit Output -->
            {#if preflightIssues.length > 0}
              <div class="preflight-card">
                <h5>Preflight Health Audit:</h5>
                <ul class="preflight-list">
                  {#each preflightIssues as issue}
                    <li class="preflight-item {issue.type}">
                      <FluentIcons name={issue.type === 'blocker' ? 'warning' : issue.type === 'warning' ? 'warning' : 'info'} size={14} />
                      <span>{issue.message}</span>
                    </li>
                  {/each}
                </ul>
              </div>
            {/if}

            <!-- AI Chat Conversation Log -->
            <div class="ai-chat-thread">
              {#if aiMessages.length === 0}
                <div class="ai-empty-prompt">
                  <FluentIcons name="sparkles" size={24} color="var(--brand-accent)" />
                  <p>Ask Gemini about creative direction, packaging specs, copywriting hooks, or production blockers.</p>
                </div>
              {:else}
                {#each aiMessages as msg}
                  <div class="chat-msg-row {msg.role}">
                    <div class="msg-bubble">
                      <div class="msg-header">
                        <strong>{msg.role === 'user' ? 'You' : 'Gemini Studio Assistant'}</strong>
                        <span class="msg-time">{msg.time}</span>
                      </div>
                      <div class="msg-body">{msg.text}</div>
                    </div>
                  </div>
                {/each}
              {/if}
            </div>

            <!-- Chat Input -->
            <div class="ai-chat-input-bar">
              <input
                type="text"
                class="ai-chat-input"
                placeholder="Ask Gemini to refine this task or write directions..."
                bind:value={aiChatPrompt}
                onkeydown={(e) => { if (e.key === 'Enter') handleSendAiChat(); }}
                disabled={isAiWorking}
              />
              <FluentButton
                appearance="primary"
                onclick={handleSendAiChat}
                disabled={isAiWorking || !aiChatPrompt.trim()}
              >
                {isAiWorking ? 'Thinking…' : 'Send'}
              </FluentButton>
            </div>
          </div>

        <!-- TAB 4: ACTIVITY & COMMENTS -->
        {:else if activeTab === 'activity'}
          <div class="tab-pane">
            <div class="comments-thread">
              {#if !task.comments || task.comments.length === 0}
                <div class="empty-comments">
                  <p>No comments or activity logged yet.</p>
                </div>
              {:else}
                {#each task.comments as comment}
                  <div class="comment-item">
                    <div class="comment-avatar" style="background: {comment.authorAvatar || '#0078D4'};">
                      {(comment.author || 'U').substring(0, 2).toUpperCase()}
                    </div>
                    <div class="comment-content">
                      <div class="comment-header">
                        <span class="author-name">{comment.author}</span>
                        <span class="comment-date">{new Date(comment.timestamp).toLocaleDateString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
                      </div>
                      <p class="comment-msg">{comment.message}</p>
                    </div>
                  </div>
                {/each}
              {/if}
            </div>

            <!-- Add Comment Input -->
            <div class="add-comment-row">
              <input
                type="text"
                class="fluent-text-input"
                placeholder="Write an internal comment or status update…"
                bind:value={newCommentText}
                onkeydown={(e) => { if (e.key === 'Enter') handleAddComment(); }}
              />
              <FluentButton appearance="secondary" onclick={handleAddComment} disabled={!newCommentText.trim()}>
                Post
              </FluentButton>
            </div>
          </div>
        {/if}
      </div>

      <!-- Description / Concept Brief -->
      <div class="field-group">
        <label for="task-desc-area" class="field-label">CONCEPT BRIEF &amp; OBJECTIVES</label>
        <textarea
          id="task-desc-area"
          class="fluent-textarea"
          rows="4"
          bind:value={description}
          placeholder="Write creative directions, visual concepts, dieline specs, or marketing hooks..."
        ></textarea>
      </div>

      <!-- Tags Input -->
      <div class="field-group">
        <label for="task-tags-input" class="field-label">TAGS &amp; LABELS (COMMA SEPARATED)</label>
        <input
          id="task-tags-input"
          type="text"
          class="fluent-text-input"
          bind:value={tagsInput}
          placeholder="packaging, 3d, social, promo, tiktok..."
        />
      </div>

      <!-- Timestamp Meta -->
      <div class="timestamps-footer">
        <span>Created: {new Date(task.createdAt).toLocaleString()}</span>
        {#if task.updatedAt}
          <span>Updated: {new Date(task.updatedAt).toLocaleString()}</span>
        {/if}
      </div>
    </div>

    <!-- ═══ FOOTER ACTIONS ═══ -->
    <div class="drawer-footer">
      <div class="footer-left">
        {#if !showDeleteConfirm}
          <button
            type="button"
            class="delete-task-btn"
            onclick={handleDeleteClick}
            disabled={isDeleting || isSaving}
            title="Delete Task Permanently"
          >
            <FluentIcons name="trash" size={14} />
            <span>Delete</span>
          </button>
        {:else}
          <div class="delete-confirm-group" role="alert">
            <span class="delete-confirm-prompt">Permanently delete #{task.id}?</span>
            <button
              type="button"
              class="delete-confirm-yes-btn"
              onclick={handleConfirmDelete}
              disabled={isDeleting}
            >
              <FluentIcons name="trash" size={13} />
              <span>{isDeleting ? 'Deleting…' : 'Yes, Delete'}</span>
            </button>
            <button
              type="button"
              class="delete-confirm-no-btn"
              onclick={handleCancelDelete}
              disabled={isDeleting}
            >
              Cancel
            </button>
          </div>
        {/if}
      </div>

      <div class="footer-right">
        <FluentButton appearance="secondary" onclick={closeDrawer} disabled={isSaving || isDeleting}>
          Cancel
        </FluentButton>
        <FluentButton appearance="primary" onclick={handleSave} disabled={isSaving || isDeleting}>
          {isSaving ? 'Saving Changes…' : 'Save Changes'}
        </FluentButton>
      </div>
    </div>
  </aside>
{/if}

<style>
  .drawer-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.45);
    backdrop-filter: blur(4px);
    z-index: 1000;
  }

  .task-drawer {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: 660px;
    max-width: 95vw;
    background: var(--surface-card);
    border-left: 1px solid var(--surface-card-border);
    box-shadow: -8px 0 32px rgba(0, 0, 0, 0.28);
    z-index: 1001;
    display: flex;
    flex-direction: column;
    animation: drawerSlide 0.22s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes drawerSlide {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  /* ═══ HEADER ═══ */
  .drawer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    gap: 12px;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .task-id-badge {
    font-family: monospace;
    font-size: 13px;
    font-weight: 700;
    color: var(--brand-accent);
    padding: 3px 8px;
    background: var(--surface-card-subtle);
    border-radius: 4px;
    border: 1px solid var(--surface-card-border);
  }

  .workstream-badge {
    font-size: 11px;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 4px;
    background: rgba(0, 120, 212, 0.1);
    color: var(--brand-accent);
    border: 1px solid rgba(0, 120, 212, 0.25);
  }

  .decision-badge {
    font-size: 11px;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 4px;
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }
  .decision-badge.decision-approved { background: rgba(16, 185, 129, 0.15); color: #10B981; }
  .decision-badge.decision-pending { background: rgba(100, 116, 139, 0.15); color: var(--text-secondary); }
  .decision-badge.decision-in_review { background: rgba(139, 92, 246, 0.15); color: #8B5CF6; }
  .decision-badge.decision-changes_requested { background: rgba(245, 158, 11, 0.15); color: #F59E0B; }
  .decision-badge.decision-rejected { background: rgba(239, 68, 68, 0.15); color: #EF4444; }

  .close-icon-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    padding: 6px;
    border-radius: 4px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: all 0.15s ease;
  }
  .close-icon-btn:hover {
    background: var(--surface-card-subtle);
    color: var(--text-primary);
  }

  /* Blocker Banner */
  .blocker-alert-banner {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 18px;
    background: rgba(245, 158, 11, 0.12);
    border-bottom: 1px solid rgba(245, 158, 11, 0.3);
    font-size: 12px;
    color: #B45309;
  }
  .blocker-names {
    font-weight: 600;
    color: #92400E;
  }

  /* ═══ BODY ═══ */
  .drawer-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .field-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    letter-spacing: 0.4px;
    margin-bottom: 5px;
    display: block;
  }

  .sub-label {
    font-size: 11px;
    color: var(--text-secondary);
    margin-bottom: 4px;
    display: block;
  }

  .section-hint {
    font-size: 12px;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }

  .title-field-group {
    display: flex;
    flex-direction: column;
  }

  .title-input {
    width: 100%;
    min-height: 42px;
    padding: 8px 12px;
    font-size: 17px;
    font-weight: 600;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
  }
  .title-input:focus {
    outline: none;
    border-color: var(--brand-accent);
  }

  /* Status Strip */
  .status-strip {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .status-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .status-btn:hover {
    background: var(--surface-card);
    color: var(--text-primary);
  }
  .status-btn.selected {
    border-color: var(--brand-accent);
    background: rgba(0, 120, 212, 0.1);
    color: var(--brand-accent);
    font-weight: 600;
  }

  /* Metadata Grid */
  .meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .timeline-inputs-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .fluent-select,
  .fluent-date-input,
  .fluent-text-input,
  .fluent-textarea {
    width: 100%;
    min-height: 36px;
    padding: 6px 10px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
  }
  .fluent-select.sm,
  .fluent-textarea.sm {
    min-height: 30px;
    font-size: 12px;
  }
  .fluent-select.xs {
    min-height: 28px;
    font-size: 11px;
    padding: 4px 8px;
  }
  .fluent-select:focus,
  .fluent-date-input:focus,
  .fluent-text-input:focus,
  .fluent-textarea:focus {
    outline: none;
    border-color: var(--brand-accent);
  }

  /* Decision & Dependencies Cards */
  .decision-card,
  .dependencies-card {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .decision-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .card-section-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .dep-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .dep-col {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .dep-header {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .dep-chips-wrap {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    min-height: 30px;
  }

  .dep-empty {
    font-size: 11px;
    color: var(--text-secondary);
    font-style: italic;
  }

  .dep-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 11px;
    color: var(--text-primary);
  }
  .dep-chip.dep-unfinished {
    border-color: rgba(245, 158, 11, 0.4);
    background: rgba(245, 158, 11, 0.1);
    color: #B45309;
  }

  .remove-dep-btn {
    background: transparent;
    border: none;
    cursor: pointer;
    font-size: 10px;
    color: var(--text-secondary);
    padding: 0 2px;
  }
  .remove-dep-btn:hover { color: var(--color-danger, #EF4444); }

  /* Bridge Card */
  .bridge-card {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .bridge-card.is-provisioned {
    border-color: rgba(16, 185, 129, 0.3);
    background: rgba(16, 185, 129, 0.04);
  }

  .bridge-header {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .bridge-title-wrap h4 {
    margin: 0;
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .bridge-title-wrap p {
    margin: 2px 0 0;
    font-size: 11px;
    color: var(--text-secondary);
  }

  .bridge-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    background: var(--surface-card);
    padding: 10px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    font-size: 12px;
  }
  .bridge-meta-row {
    display: flex;
    justify-content: space-between;
  }
  .bridge-meta-row .highlight {
    font-weight: 700;
    color: var(--brand-accent);
  }
  .bridge-meta-row .path-val {
    font-family: monospace;
    font-size: 11px;
  }

  .bridge-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .unlink-btn {
    background: transparent;
    border: none;
    font-size: 11px;
    color: var(--text-secondary);
    cursor: pointer;
    text-decoration: underline;
  }

  .bridge-or-divider {
    text-align: center;
    font-size: 10px;
    font-weight: 700;
    color: var(--text-secondary);
    position: relative;
  }
  .bridge-or-divider::before,
  .bridge-or-divider::after {
    content: '';
    position: absolute;
    top: 50%;
    width: 44%;
    height: 1px;
    background: var(--surface-card-border);
  }
  .bridge-or-divider::before { left: 0; }
  .bridge-or-divider::after { right: 0; }

  /* ═══ TABS SECTION ═══ */
  .section-tabs-container {
    display: flex;
    flex-direction: column;
    gap: 10px;
    border-top: 1px solid var(--surface-card-border);
    padding-top: 16px;
  }

  .tabs-header-strip {
    display: flex;
    gap: 4px;
    border-bottom: 1px solid var(--surface-card-border);
    padding-bottom: 4px;
    overflow-x: auto;
  }

  .tab-strip-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 6px;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .tab-strip-btn:hover {
    color: var(--text-primary);
    background: var(--surface-card-subtle);
  }
  .tab-strip-btn.active {
    color: var(--brand-accent);
    background: rgba(0, 120, 212, 0.1);
  }

  .tab-pane {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  /* Subtasks UI */
  .checklist-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .checklist-progress-wrap {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .progress-bar-bg {
    flex: 1;
    height: 6px;
    border-radius: 3px;
    background: var(--surface-card-border);
    overflow: hidden;
  }
  .progress-bar-fill {
    height: 100%;
    background: #10B981;
    transition: width 0.2s ease;
  }
  .progress-text {
    font-size: 11px;
    color: var(--text-secondary);
    white-space: nowrap;
  }

  .ai-suggest-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: rgba(139, 92, 246, 0.12);
    border: 1px solid rgba(139, 92, 246, 0.25);
    color: #8B5CF6;
    padding: 5px 10px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
  }
  .ai-suggest-btn:hover { background: rgba(139, 92, 246, 0.2); }

  .subtasks-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .subtask-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
  }
  .subtask-item.completed .subtask-title-input {
    text-decoration: line-through;
    color: var(--text-secondary);
  }

  .subtask-checkbox {
    width: 16px;
    height: 16px;
    cursor: pointer;
  }

  .subtask-title-input {
    flex: 1;
    background: transparent;
    border: none;
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
  }
  .subtask-title-input:focus { outline: none; }

  .delete-subtask-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
    padding: 2px 6px;
  }
  .delete-subtask-btn:hover { color: var(--color-danger, #EF4444); }

  .add-subtask-row {
    display: flex;
    gap: 8px;
    margin-top: 4px;
  }
  .add-subtask-input {
    flex: 1;
    min-height: 32px;
    padding: 4px 10px;
    border-radius: 6px;
    border: 1px dashed var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 12px;
  }
  .add-subtask-btn {
    padding: 4px 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
    color: var(--text-primary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
  }

  /* AI Assistant Tab */
  .ai-chips-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .ai-action-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-primary);
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .ai-action-chip:hover {
    border-color: var(--brand-accent);
    color: var(--brand-accent);
  }

  .preflight-card {
    background: rgba(245, 158, 11, 0.08);
    border: 1px solid rgba(245, 158, 11, 0.25);
    border-radius: 6px;
    padding: 10px;
    font-size: 12px;
  }
  .preflight-card h5 { margin: 0 0 6px; font-size: 12px; }
  .preflight-list { margin: 0; padding-left: 18px; display: flex; flex-direction: column; gap: 4px; }
  .preflight-item.blocker { color: #DC2626; font-weight: 600; }
  .preflight-item.warning { color: #D97706; }
  .preflight-item.info { color: #0284C7; }

  .ai-chat-thread {
    min-height: 120px;
    max-height: 240px;
    overflow-y: auto;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .ai-empty-prompt {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    color: var(--text-secondary);
    font-size: 12px;
    text-align: center;
    padding: 20px 10px;
  }

  .chat-msg-row {
    display: flex;
  }
  .chat-msg-row.user { justify-content: flex-end; }
  .chat-msg-row.assistant { justify-content: flex-start; }

  .msg-bubble {
    max-width: 85%;
    padding: 8px 12px;
    border-radius: 8px;
    font-size: 12px;
    line-height: 1.4;
  }
  .chat-msg-row.user .msg-bubble {
    background: var(--brand-accent);
    color: #FFF;
  }
  .chat-msg-row.assistant .msg-bubble {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    color: var(--text-primary);
  }
  .msg-header {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    margin-bottom: 4px;
    opacity: 0.8;
  }

  .ai-chat-input-bar {
    display: flex;
    gap: 8px;
  }
  .ai-chat-input {
    flex: 1;
    min-height: 36px;
    padding: 6px 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 12px;
  }

  /* Comments Tab */
  .comments-thread {
    display: flex;
    flex-direction: column;
    gap: 10px;
    max-height: 200px;
    overflow-y: auto;
  }
  .comment-item {
    display: flex;
    gap: 10px;
    padding: 8px 10px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
  }
  .comment-avatar {
    width: 26px;
    height: 26px;
    border-radius: 50%;
    color: #FFF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    font-weight: 700;
  }
  .comment-content { flex: 1; }
  .comment-header {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    margin-bottom: 3px;
  }
  .author-name { font-weight: 600; color: var(--text-primary); }
  .comment-date { color: var(--text-secondary); }
  .comment-msg { margin: 0; font-size: 12px; color: var(--text-primary); }

  .add-comment-row {
    display: flex;
    gap: 8px;
  }

  .timestamps-footer {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-secondary);
    padding-top: 8px;
    border-top: 1px solid var(--surface-card-border);
  }

  /* ═══ FOOTER ACTIONS ═══ */
  .drawer-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 20px;
    border-top: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }

  .footer-right {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .delete-task-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    border: 1px solid transparent;
    color: var(--color-danger, #EF4444);
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .delete-task-btn:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: rgba(239, 68, 68, 0.25);
  }

  .delete-confirm-group {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    background: rgba(239, 68, 68, 0.08);
    border: 1px solid rgba(239, 68, 68, 0.3);
    padding: 4px 10px;
    border-radius: 6px;
    animation: fadeIn 0.15s ease-out;
  }

  .delete-confirm-prompt {
    font-size: 12px;
    font-weight: 600;
    color: var(--color-danger, #EF4444);
  }

  .delete-confirm-yes-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: var(--color-danger, #EF4444);
    border: 1px solid transparent;
    color: #FFFFFF;
    padding: 4px 10px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .delete-confirm-yes-btn:hover:not(:disabled) {
    background: #DC2626;
  }
  .delete-confirm-yes-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .delete-confirm-no-btn {
    background: transparent;
    border: 1px solid var(--surface-card-border);
    color: var(--text-secondary);
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .delete-confirm-no-btn:hover:not(:disabled) {
    background: var(--surface-card-subtle);
    color: var(--text-primary);
  }
</style>

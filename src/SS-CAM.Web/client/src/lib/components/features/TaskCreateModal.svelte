<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { StudioTask, StudioTaskStatus, ProjectPriority, TaskDecisionStatus } from '$lib/types';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface Props {
    isOpen: boolean;
    onClose: () => void;
    onCreated: (task: StudioTask) => void;
  }

  let { isOpen = $bindable(false), onClose, onCreated }: Props = $props();

  // Active top navigation tab
  let activeTab = $state<'task' | 'doc' | 'reminder' | 'whiteboard' | 'dashboard'>('task');

  // Form states
  let title = $state('');
  let description = $state('');
  let workstream = $state('General Operations');
  let taskType = $state('Task (default)');
  let status = $state<StudioTaskStatus>('backlog');
  let priority = $state<ProjectPriority>('medium');
  let assignee = $state('harussani');
  let assigneeName = $state('Harussani (Me)');
  let assigneeAvatar = $state('#0284C7');
  let startDate = $state('');
  let dueDate = $state('');
  let tags = $state<string[]>([]);
  let brand = $state('SS');
  let decisionStatus = $state<TaskDecisionStatus>('pending');
  let isSubmitting = $state(false);

  // Popover toggles
  let showWorkstreamPicker = $state(false);
  let showTypePicker = $state(false);
  let showStatusPicker = $state(false);
  let showAssigneePicker = $state(false);
  let showDatePicker = $state(false);
  let showPriorityPicker = $state(false);
  let showTagsPicker = $state(false);
  let showMorePicker = $state(false);
  let showSplitMenu = $state(false);
  let showSubtasksField = $state(false);
  let subtasksList = $state<string[]>([]);
  let newSubtaskInput = $state('');

  // Date picker state
  let dateTab = $state<'start' | 'due'>('due');
  let calYear = $state(2026);
  let calMonth = $state(9); // 0-indexed: 9 = October

  // Search filter states inside dropdowns
  let workstreamSearch = $state('');
  let typeSearch = $state('');
  let assigneeSearch = $state('');
  let tagInput = $state('');

  let staffRoster = $state<any[]>([]);

  const workstreams = [
    { id: 'General Operations', name: 'General Operations', count: 2 },
    { id: 'Software & App Dev', name: 'Software & App Dev', count: 3 },
    { id: 'Packaging & Dieline', name: 'Packaging & Dieline', count: 1 },
    { id: 'Creative & Brand Identity', name: 'Creative & Brand Identity', count: 2 },
    { id: 'Digital Marketing & Social', name: 'Digital Marketing & Social', count: 1 },
    { id: 'Motion, Video & 3D', name: 'Motion, Video & 3D', count: 1 },
    { id: 'QA & Compliance', name: 'QA & Compliance', count: 1 },
    { id: 'Executive & Strategy', name: 'Executive & Strategy', count: 1 }
  ];

  const taskTypes = [
    { id: 'Task (default)', label: 'Task (default)', icon: 'target' },
    { id: 'Milestone', label: 'Milestone', icon: 'milestone' },
    { id: 'Form Response', label: 'Form Response', icon: 'file' },
    { id: 'Meeting Note', label: 'Meeting Note', icon: 'edit' }
  ];

  const statuses: { id: StudioTaskStatus; label: string; color: string }[] = [
    { id: 'backlog', label: 'BACKLOG', color: '#64748B' },
    { id: 'in-progress', label: 'IN PROGRESS', color: '#0284C7' },
    { id: 'review', label: 'REVIEW', color: '#8B5CF6' },
    { id: 'done', label: 'DONE', color: '#10B981' }
  ];

  const priorities: { id: ProjectPriority; label: string; color: string }[] = [
    { id: 'urgent', label: 'Urgent', color: '#EF4444' },
    { id: 'high', label: 'High', color: '#F97316' },
    { id: 'medium', label: 'Normal', color: '#0284C7' },
    { id: 'low', label: 'Low', color: '#94A3B8' }
  ];

  const brands = [
    { code: 'SS', label: 'SuamiSihat (Primary)' },
    { code: 'SSH', label: 'SuamiSihat Holding' },
    { code: 'SSC', label: 'SuamiSihat Healthcare' },
    { code: 'SSW', label: 'SuamiSihat Wellness' },
    { code: 'SSE', label: 'SuamiSihat E-Commerce' },
    { code: 'SST', label: 'SuamiSihat Technology' }
  ];

  const decisions: { id: TaskDecisionStatus; label: string }[] = [
    { id: 'pending', label: 'Pending Evaluation' },
    { id: 'in_review', label: 'In Team / Lead Review' },
    { id: 'approved', label: 'Approved for Production' },
    { id: 'changes_requested', label: 'Changes Requested' },
    { id: 'rejected', label: 'Rejected / Shelved' }
  ];

  onMount(async () => {
    try {
      const res = await ApiClient.getStaffRoster();
      if (res && Array.isArray(res.roster)) {
        staffRoster = res.roster;
      }
    } catch (e) {
      console.debug('Failed to load roster:', e);
    }
  });

  $effect(() => {
    if (isOpen && staffRoster.length === 0) {
      ApiClient.getStaffRoster()
        .then(res => {
          if (res && Array.isArray(res.roster)) staffRoster = res.roster;
        })
        .catch(() => {});
    }
  });

  // Close all popovers helper
  function closeAllPopovers() {
    showWorkstreamPicker = false;
    showTypePicker = false;
    showStatusPicker = false;
    showAssigneePicker = false;
    showDatePicker = false;
    showPriorityPicker = false;
    showTagsPicker = false;
    showMorePicker = false;
    showSplitMenu = false;
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (!isOpen) return;
    if (e.key === 'Escape') {
      if (
        showWorkstreamPicker ||
        showTypePicker ||
        showStatusPicker ||
        showAssigneePicker ||
        showDatePicker ||
        showPriorityPicker ||
        showTagsPicker ||
        showMorePicker ||
        showSplitMenu
      ) {
        closeAllPopovers();
        e.stopPropagation();
      } else {
        handleClose();
      }
    }
  }

  function handleClose() {
    closeAllPopovers();
    isOpen = false;
    if (onClose) onClose();
  }

  function handleReset() {
    title = '';
    description = '';
    workstream = 'General Operations';
    taskType = 'Task (default)';
    status = 'backlog';
    priority = 'medium';
    assignee = 'harussani';
    assigneeName = 'Harussani (Me)';
    assigneeAvatar = '#0284C7';
    startDate = '';
    dueDate = '';
    tags = [];
    brand = 'SS';
    decisionStatus = 'pending';
    subtasksList = [];
    newSubtaskInput = '';
    closeAllPopovers();
  }

  // Calendar matrix calculation
  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  const calendarDays = $derived.by(() => {
    const firstDay = new Date(calYear, calMonth, 1);
    const lastDay = new Date(calYear, calMonth + 1, 0);
    // Align with Monday as first day: Monday is 0, Sunday is 6
    let startDayOfWeek = firstDay.getDay() - 1;
    if (startDayOfWeek === -1) startDayOfWeek = 6;

    const days = [];
    // Previous month filler days
    const prevMonthLastDay = new Date(calYear, calMonth, 0).getDate();
    for (let i = startDayOfWeek - 1; i >= 0; i--) {
      days.push({
        dayNumber: prevMonthLastDay - i,
        isCurrentMonth: false,
        dateStr: `${calYear}-${String(calMonth).padStart(2, '0')}-${String(prevMonthLastDay - i).padStart(2, '0')}`
      });
    }

    // Current month days
    for (let d = 1; d <= lastDay.getDate(); d++) {
      const monthStr = String(calMonth + 1).padStart(2, '0');
      const dayStr = String(d).padStart(2, '0');
      days.push({
        dayNumber: d,
        isCurrentMonth: true,
        dateStr: `${calYear}-${monthStr}-${dayStr}`,
        isToday: calYear === 2026 && calMonth === 9 && d === 7 // Oct 7, 2026
      });
    }

    // Trailing next month filler
    const totalSlots = Math.ceil(days.length / 7) * 7;
    let nextDay = 1;
    while (days.length < totalSlots) {
      days.push({
        dayNumber: nextDay,
        isCurrentMonth: false,
        dateStr: `${calYear}-${String(calMonth + 2).padStart(2, '0')}-${String(nextDay).padStart(2, '0')}`
      });
      nextDay++;
    }

    return days;
  });

  function selectDate(dateStr: string) {
    if (dateTab === 'start') {
      startDate = dateStr;
    } else {
      dueDate = dateStr;
    }
  }

  function applyPresetDate(preset: string) {
    const today = new Date(2026, 9, 7); // Wednesday, Oct 7, 2026
    let target = new Date(today);

    if (preset === 'today') {
      // today
    } else if (preset === 'tomorrow') {
      target.setDate(today.getDate() + 1);
    } else if (preset === 'weekend') {
      target.setDate(today.getDate() + 3); // Saturday Oct 10
    } else if (preset === 'next_week') {
      target.setDate(today.getDate() + 5); // Monday Oct 12
    } else if (preset === 'next_weekend') {
      target.setDate(today.getDate() + 10); // Saturday Oct 17
    } else if (preset === '2_weeks') {
      target.setDate(today.getDate() + 14); // Wednesday Oct 21
    } else if (preset === '4_weeks') {
      target.setDate(today.getDate() + 28); // Wednesday Nov 4
    }

    const y = target.getFullYear();
    const m = String(target.getMonth() + 1).padStart(2, '0');
    const d = String(target.getDate()).padStart(2, '0');
    const formatted = `${y}-${m}-${d}`;

    if (dateTab === 'start') {
      startDate = formatted;
    } else {
      dueDate = formatted;
    }
  }

  function addSubtask() {
    if (newSubtaskInput.trim()) {
      subtasksList = [...subtasksList, newSubtaskInput.trim()];
      newSubtaskInput = '';
    }
  }

  function removeSubtask(index: number) {
    subtasksList = subtasksList.filter((_, i) => i !== index);
  }

  function handleSubtaskInputKeydown(e: KeyboardEvent, index: number) {
    if (e.key === 'Enter') {
      e.preventDefault();
      subtasksList = [
        ...subtasksList.slice(0, index + 1),
        '',
        ...subtasksList.slice(index + 1)
      ];
      setTimeout(() => {
        const inputs = document.querySelectorAll<HTMLInputElement>('.subtask-inline-edit');
        if (inputs[index + 1]) {
          inputs[index + 1].focus();
        }
      }, 50);
    } else if (e.key === 'Backspace' && subtasksList[index] === '' && subtasksList.length > 1) {
      e.preventDefault();
      removeSubtask(index);
      setTimeout(() => {
        const inputs = document.querySelectorAll<HTMLInputElement>('.subtask-inline-edit');
        const targetIdx = Math.max(0, index - 1);
        if (inputs[targetIdx]) {
          inputs[targetIdx].focus();
        }
      }, 50);
    }
  }

  function addTag() {
    if (tagInput.trim() && !tags.includes(tagInput.trim())) {
      tags = [...tags, tagInput.trim()];
      tagInput = '';
    }
  }

  function removeTag(tag: string) {
    tags = tags.filter(t => t !== tag);
  }

  async function handleSubmit(andOpen: boolean = false) {
    if (!title.trim()) {
      appState.addToast('Please enter a task title.', 'warning');
      return;
    }

    if (!assignee || !assignee.trim()) {
      appState.addToast('Please assign an owner. Each task must have an assignee.', 'warning');
      showAssigneePicker = true;
      return;
    }

    isSubmitting = true;
    try {
      const filteredSubtasks = subtasksList.filter(s => s.trim().length > 0);
      const parsedSubtasks = filteredSubtasks.map((st, idx) => ({
        id: `st-${Date.now()}-${idx}`,
        title: st.trim(),
        completed: false
      }));

      const res = await ApiClient.createStudioTask({
        title: title.trim(),
        brand,
        workstream,
        priority,
        status,
        decisionStatus,
        assignee: assignee.trim(),
        assigneeName: assigneeName || assignee,
        assigneeAvatarColor: assigneeAvatar || undefined,
        startDate: startDate || undefined,
        dueDate: dueDate || undefined,
        subtasks: parsedSubtasks,
        tags,
        description: description.trim()
      });

      appState.addToast(`Task "${title.trim()}" created successfully`, 'success', 'Task Created');
      onCreated(res.task);
      handleReset();
      handleClose();
    } catch (err: any) {
      appState.addToast(`Failed to create task: ${err.message}`, 'error');
    } finally {
      isSubmitting = false;
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if isOpen}
  <!-- Backdrop -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="clickup-modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) handleClose(); }}>
    <div class="clickup-modal-card" role="dialog" aria-modal="true" onclick={closeAllPopovers}>

      <!-- TOP TAB BAR -->
      <div class="modal-top-bar" onclick={(e) => e.stopPropagation()}>
        <div class="tab-items-left">
          <button
            type="button"
            class="top-tab-item {activeTab === 'task' ? 'active' : ''}"
            onclick={() => activeTab = 'task'}
          >
            Task
          </button>
          <button
            type="button"
            class="top-tab-item {activeTab === 'doc' ? 'active' : ''}"
            onclick={() => activeTab = 'doc'}
          >
            Doc
          </button>
          <button
            type="button"
            class="top-tab-item {activeTab === 'reminder' ? 'active' : ''}"
            onclick={() => activeTab = 'reminder'}
          >
            Reminder
          </button>
          <button
            type="button"
            class="top-tab-item {activeTab === 'whiteboard' ? 'active' : ''}"
            onclick={() => activeTab = 'whiteboard'}
          >
            Whiteboard
          </button>
          <button
            type="button"
            class="top-tab-item {activeTab === 'dashboard' ? 'active' : ''}"
            onclick={() => activeTab = 'dashboard'}
          >
            Dashboard
          </button>
        </div>

        <div class="top-actions-right">
          <button type="button" class="icon-utility-btn" title="Minimize / Dock">
            <FluentIcons name="minimize" size={15} />
          </button>
          <button type="button" class="icon-close-circle" onclick={handleClose} title="Close">
            <FluentIcons name="close" size={14} />
          </button>
        </div>
      </div>

      <!-- MAIN MODAL CONTENT -->
      <div class="modal-content-area" onclick={(e) => e.stopPropagation()}>

        <!-- SUBHEADER PILL SELECTORS -->
        <div class="pill-selectors-row">
          
          <!-- Location / Workstream Pill -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="subheader-pill-btn {showWorkstreamPicker ? 'selected' : ''}"
              onclick={() => {
                const prev = showWorkstreamPicker;
                closeAllPopovers();
                showWorkstreamPicker = !prev;
              }}
            >
              <FluentIcons name="list" size={13} color="var(--text-secondary)" />
              <span class="pill-btn-label">{workstream}</span>
              <FluentIcons name="chevronDown" size={11} color="var(--text-tertiary)" />
            </button>

            <!-- Location Dropdown Menu (Screenshot 2) -->
            {#if showWorkstreamPicker}
              <div class="dropdown-popover-card location-picker-menu">
                <div class="picker-search-bar">
                  <input
                    type="text"
                    placeholder="Search..."
                    bind:value={workstreamSearch}
                    class="picker-search-input"
                    autofocus
                  />
                </div>

                <div class="picker-scroll-area">
                  <div class="picker-section-label">Workstream / Department</div>
                  <button
                    type="button"
                    class="picker-option-row {workstream === 'General Operations' ? 'active' : ''}"
                    onclick={() => { workstream = 'General Operations'; showWorkstreamPicker = false; }}
                  >
                    <div class="option-left">
                      <FluentIcons name="list" size={14} color="var(--text-secondary)" />
                      <span>General Operations</span>
                    </div>
                    {#if workstream === 'General Operations'}
                      <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                    {/if}
                  </button>

                  <button
                    type="button"
                    class="picker-option-row {workstream === 'Software & App Dev' ? 'active' : ''}"
                    onclick={() => { workstream = 'Software & App Dev'; showWorkstreamPicker = false; }}
                  >
                    <div class="option-left">
                      <FluentIcons name="list" size={14} color="var(--text-secondary)" />
                      <span>Software & App Dev</span>
                    </div>
                    <span class="picker-count-badge">3</span>
                  </button>

                  <div class="picker-section-label">Browse Teams & Services</div>
                  <div class="picker-browse-folder">
                    <FluentIcons name="user" size={14} color="var(--text-tertiary)" />
                    <span>Personal Queue</span>
                  </div>

                  <div class="picker-browse-folder team-active">
                    <span class="team-color-badge blue">👥</span>
                    <span>SS Technology & Dev</span>
                  </div>

                  {#each workstreams.filter(w => w.name.toLowerCase().includes(workstreamSearch.toLowerCase())) as ws}
                    <button
                      type="button"
                      class="picker-option-row nested {workstream === ws.name ? 'active' : ''}"
                      onclick={() => { workstream = ws.name; showWorkstreamPicker = false; }}
                    >
                      <div class="option-left">
                        <FluentIcons name="list" size={13} color="var(--text-secondary)" />
                        <span>{ws.name}</span>
                      </div>
                      {#if workstream === ws.name}
                        <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                      {:else if ws.count > 0}
                        <span class="picker-count-badge">{ws.count}</span>
                      {/if}
                    </button>
                  {/each}

                  <div class="picker-browse-folder">
                    <span class="team-color-badge green">S</span>
                    <span>SS Operations & Logistics</span>
                  </div>
                </div>
              </div>
            {/if}
          </div>

          <!-- Task Type Pill -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="subheader-pill-btn {showTypePicker ? 'selected' : ''}"
              onclick={() => {
                const prev = showTypePicker;
                closeAllPopovers();
                showTypePicker = !prev;
              }}
            >
              <FluentIcons name="target" size={13} color="var(--text-secondary)" />
              <span class="pill-btn-label">{taskType}</span>
              <FluentIcons name="chevronDown" size={11} color="var(--text-tertiary)" />
            </button>

            <!-- Task Type Dropdown Menu (Screenshot 3) -->
            {#if showTypePicker}
              <div class="dropdown-popover-card task-type-menu">
                <div class="picker-search-bar">
                  <input
                    type="text"
                    placeholder="Find type (e.g. Milestone)"
                    bind:value={typeSearch}
                    class="picker-search-input"
                    autofocus
                  />
                </div>

                <div class="picker-scroll-area">
                  <div class="picker-section-label">
                    <span>Task Types</span>
                    <FluentIcons name="info" size={12} color="var(--text-tertiary)" />
                  </div>

                  {#each taskTypes.filter(t => t.label.toLowerCase().includes(typeSearch.toLowerCase())) as tt}
                    <button
                      type="button"
                      class="picker-option-row {taskType === tt.id ? 'active' : ''}"
                      onclick={() => { taskType = tt.id; showTypePicker = false; }}
                    >
                      <div class="option-left">
                        <FluentIcons name={tt.icon as any} size={14} color="var(--text-secondary)" />
                        <span>{tt.label}</span>
                      </div>
                      {#if taskType === tt.id}
                        <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                      {/if}
                    </button>
                  {/each}
                </div>
              </div>
            {/if}
          </div>

        </div>

        <!-- BORDERLESS TITLE & DESCRIPTION -->
        <div class="title-desc-container">
          <input
            type="text"
            placeholder="Task Name"
            bind:value={title}
            class="clickup-title-input"
            autofocus
          />

          <textarea
            placeholder="Add description"
            bind:value={description}
            class="clickup-description-input"
            rows="3"
          ></textarea>
        </div>

        <!-- CLICKUP ATTRIBUTE ACTION PILLS ROW (Screenshot 1) -->
        <div class="attribute-chips-row">

          <!-- Status Pill -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn status-chip"
              onclick={() => {
                const prev = showStatusPicker;
                closeAllPopovers();
                showStatusPicker = !prev;
              }}
            >
              <span class="chip-status-dot" style="background-color: {statuses.find(s => s.id === status)?.color}"></span>
              <span class="chip-text">{statuses.find(s => s.id === status)?.label}</span>
            </button>

            {#if showStatusPicker}
              <div class="dropdown-popover-card status-menu">
                <div class="picker-section-label">Status</div>
                {#each statuses as st}
                  <button
                    type="button"
                    class="picker-option-row {status === st.id ? 'active' : ''}"
                    onclick={() => { status = st.id; showStatusPicker = false; }}
                  >
                    <div class="option-left">
                      <span class="chip-status-dot" style="background-color: {st.color}"></span>
                      <span>{st.label}</span>
                    </div>
                    {#if status === st.id}
                      <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                    {/if}
                  </button>
                {/each}
              </div>
            {/if}
          </div>

          <!-- Assignee Pill (Screenshot 4) -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn {assignee ? 'has-value' : ''}"
              onclick={() => {
                const prev = showAssigneePicker;
                closeAllPopovers();
                showAssigneePicker = !prev;
              }}
            >
              {#if assignee}
                <span class="assignee-avatar-pill" style="background-color: {assigneeAvatar || '#3B82F6'}">
                  {(assigneeName || assignee).charAt(0).toUpperCase()}
                </span>
                <span class="chip-text">{assigneeName || assignee}</span>
              {:else}
                <FluentIcons name="users" size={14} color="var(--text-secondary)" />
                <span class="chip-text">Assignee</span>
              {/if}
            </button>

            <!-- Assignee Picker Popover (Screenshot 4) -->
            {#if showAssigneePicker}
              <div class="dropdown-popover-card assignee-menu">
                <div class="picker-search-bar">
                  <FluentIcons name="search" size={13} color="var(--text-tertiary)" />
                  <input
                    type="text"
                    placeholder="Search or enter email..."
                    bind:value={assigneeSearch}
                    class="picker-search-input"
                    autofocus
                  />
                </div>

                <div class="picker-scroll-area">
                  <div class="picker-section-label">People</div>
                  
                  <!-- Current user "Me" -->
                  <button
                    type="button"
                    class="picker-option-row {assignee === 'harussani' ? 'active' : ''}"
                    onclick={() => {
                      assignee = 'harussani';
                      assigneeName = 'Harussani (Me)';
                      assigneeAvatar = '#0284C7';
                      showAssigneePicker = false;
                    }}
                  >
                    <div class="option-left">
                      <div class="avatar-with-presence">
                        <span class="avatar-badge" style="background: #0284C7;">HM</span>
                        <span class="presence-dot online"></span>
                      </div>
                      <span>Me (Harussani)</span>
                    </div>
                  </button>

                  {#each staffRoster.filter(s => (s.name || s.username).toLowerCase().includes(assigneeSearch.toLowerCase())) as staff}
                    <button
                      type="button"
                      class="picker-option-row {assignee === staff.staffId ? 'active' : ''}"
                      onclick={() => {
                        assignee = staff.staffId || staff.username;
                        assigneeName = staff.name || staff.username;
                        assigneeAvatar = staff.avatarColor || '#64748B';
                        showAssigneePicker = false;
                      }}
                    >
                      <div class="option-left">
                        <div class="avatar-with-presence">
                          <span class="avatar-badge" style="background: {staff.avatarColor || '#64748B'};">
                            {(staff.name || staff.username).slice(0, 2).toUpperCase()}
                          </span>
                          <span class="presence-dot online"></span>
                        </div>
                        <div class="staff-text-col">
                          <span class="staff-title">{staff.name}</span>
                          <span class="staff-sub">{staff.email || staff.role}</span>
                        </div>
                      </div>
                    </button>
                  {/each}

                  <div class="picker-section-label">Agents</div>
                  <button
                    type="button"
                    class="picker-option-row agent-row"
                    onclick={() => {
                      assignee = 'gemini-agent';
                      assigneeName = 'Gemini Creative Agent';
                      assigneeAvatar = '#8B5CF6';
                      showAssigneePicker = false;
                    }}
                  >
                    <div class="option-left">
                      <div class="agent-icon-badge">
                        <FluentIcons name="sparkles" size={13} color="#FFFFFF" />
                      </div>
                      <div class="staff-text-col">
                        <span class="staff-title">Gemini Studio Agent</span>
                        <span class="staff-sub">Creative Automation &amp; Preflight</span>
                      </div>
                    </div>
                  </button>
                </div>
              </div>
            {/if}
          </div>

          <!-- Due Date Pill (Screenshot 5) -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn {dueDate || startDate ? 'has-value' : ''}"
              onclick={() => {
                const prev = showDatePicker;
                closeAllPopovers();
                showDatePicker = !prev;
              }}
            >
              <FluentIcons name="calendar" size={14} color="var(--text-secondary)" />
              <span class="chip-text">
                {dueDate ? dueDate : (startDate ? `From ${startDate}` : 'Due date')}
              </span>
            </button>

            <!-- Dual Date Picker Popover (Screenshot 5) -->
            {#if showDatePicker}
              <div class="dropdown-popover-card dual-date-picker">
                <!-- Top Tabs for Start / Due Date -->
                <div class="date-header-tabs">
                  <button
                    type="button"
                    class="date-input-tab {dateTab === 'start' ? 'active-tab' : ''}"
                    onclick={() => dateTab = 'start'}
                  >
                    <FluentIcons name="calendar" size={13} color="var(--text-secondary)" />
                    <span>{startDate ? startDate : 'Start date'}</span>
                  </button>

                  <button
                    type="button"
                    class="date-input-tab {dateTab === 'due' ? 'active-tab' : ''}"
                    onclick={() => dateTab = 'due'}
                  >
                    <FluentIcons name="calendar" size={13} color="var(--brand-primary, #0084FF)" />
                    <span>{dueDate ? dueDate : 'Due date'}</span>
                  </button>
                </div>

                <!-- Split Body: Left Presets + Right Calendar Grid -->
                <div class="date-picker-split-body">
                  <!-- Left Quick Presets -->
                  <div class="date-presets-col">
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('today')}>
                      <span>Today</span>
                      <span class="preset-hint">Wed</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('today')}>
                      <span>Later</span>
                      <span class="preset-hint">8:24 am</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('tomorrow')}>
                      <span>Tomorrow</span>
                      <span class="preset-hint">Thu</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('weekend')}>
                      <span>This weekend</span>
                      <span class="preset-hint">Sat</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('next_week')}>
                      <span>Next week</span>
                      <span class="preset-hint">Mon</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('next_weekend')}>
                      <span>Next weekend</span>
                      <span class="preset-hint">17 Oct</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('2_weeks')}>
                      <span>2 weeks</span>
                      <span class="preset-hint">21 Oct</span>
                    </button>
                    <button type="button" class="preset-row" onclick={() => applyPresetDate('4_weeks')}>
                      <span>4 weeks</span>
                      <span class="preset-hint">4 Nov</span>
                    </button>

                    <div class="preset-divider"></div>
                    <button type="button" class="preset-row recurring-row">
                      <span>Set Recurring</span>
                      <FluentIcons name="chevronRight" size={11} color="var(--text-tertiary)" />
                    </button>
                  </div>

                  <!-- Right Calendar View (October 2026) -->
                  <div class="date-calendar-col">
                    <div class="cal-nav-row">
                      <span class="cal-month-title">{monthNames[calMonth]} {calYear}</span>
                      <div class="cal-nav-actions">
                        <button type="button" class="cal-nav-btn" onclick={() => { calYear = 2026; calMonth = 9; }}>
                          Today
                        </button>
                        <button
                          type="button"
                          class="cal-nav-btn"
                          onclick={() => {
                            if (calMonth === 0) { calMonth = 11; calYear--; }
                            else { calMonth--; }
                          }}
                        >
                          ‹
                        </button>
                        <button
                          type="button"
                          class="cal-nav-btn"
                          onclick={() => {
                            if (calMonth === 11) { calMonth = 0; calYear++; }
                            else { calMonth++; }
                          }}
                        >
                          ›
                        </button>
                      </div>
                    </div>

                    <!-- Days of Week Headers -->
                    <div class="cal-weekdays-row">
                      <span>Mo</span>
                      <span>Tu</span>
                      <span>We</span>
                      <span>Th</span>
                      <span>Fr</span>
                      <span>Sa</span>
                      <span>Su</span>
                    </div>

                    <!-- Day Grid -->
                    <div class="cal-grid">
                      {#each calendarDays as d}
                        <button
                          type="button"
                          class="cal-day-cell {d.isCurrentMonth ? '' : 'muted'} {d.isToday ? 'is-today-red' : ''} {(dateTab === 'start' && startDate === d.dateStr) || (dateTab === 'due' && dueDate === d.dateStr) ? 'is-selected' : ''}"
                          onclick={() => selectDate(d.dateStr)}
                        >
                          {d.dayNumber}
                        </button>
                      {/each}
                    </div>
                  </div>
                </div>

                <div class="date-footer-row">
                  <button
                    type="button"
                    class="date-clear-btn"
                    onclick={() => {
                      if (dateTab === 'start') startDate = '';
                      else dueDate = '';
                    }}
                  >
                    Clear {dateTab === 'start' ? 'Start Date' : 'Due Date'}
                  </button>
                  <button
                    type="button"
                    class="date-done-btn"
                    onclick={() => showDatePicker = false}
                  >
                    Done
                  </button>
                </div>
              </div>
            {/if}
          </div>

          <!-- Priority Pill -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn {priority !== 'medium' ? 'has-value' : ''}"
              onclick={() => {
                const prev = showPriorityPicker;
                closeAllPopovers();
                showPriorityPicker = !prev;
              }}
            >
              <FluentIcons
                name="flag"
                size={13}
                color={priorities.find(p => p.id === priority)?.color || 'var(--text-secondary)'}
              />
              <span class="chip-text">{priorities.find(p => p.id === priority)?.label}</span>
            </button>

            {#if showPriorityPicker}
              <div class="dropdown-popover-card priority-menu">
                <div class="picker-section-label">Priority</div>
                {#each priorities as pr}
                  <button
                    type="button"
                    class="picker-option-row {priority === pr.id ? 'active' : ''}"
                    onclick={() => { priority = pr.id; showPriorityPicker = false; }}
                  >
                    <div class="option-left">
                      <FluentIcons name="flag" size={13} color={pr.color} />
                      <span>{pr.label}</span>
                    </div>
                    {#if priority === pr.id}
                      <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                    {/if}
                  </button>
                {/each}
              </div>
            {/if}
          </div>

          <!-- Tags Pill -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn {tags.length > 0 ? 'has-value' : ''}"
              onclick={() => {
                const prev = showTagsPicker;
                closeAllPopovers();
                showTagsPicker = !prev;
              }}
            >
              <FluentIcons name="tag" size={13} color="var(--text-secondary)" />
              <span class="chip-text">
                {tags.length > 0 ? `${tags.length} Tag${tags.length > 1 ? 's' : ''}` : 'Tags'}
              </span>
            </button>

            {#if showTagsPicker}
              <div class="dropdown-popover-card tags-menu">
                <div class="picker-search-bar">
                  <input
                    type="text"
                    placeholder="Add a tag..."
                    bind:value={tagInput}
                    onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } }}
                    class="picker-search-input"
                    autofocus
                  />
                  <button type="button" class="tag-add-btn" onclick={addTag}>Add</button>
                </div>

                {#if tags.length > 0}
                  <div class="tags-badge-cloud">
                    {#each tags as t}
                      <span class="tag-bubble">
                        #{t}
                        <button type="button" class="tag-remove" onclick={() => removeTag(t)}>✕</button>
                      </span>
                    {/each}
                  </div>
                {:else}
                  <div class="empty-tags-hint">No tags added yet. Type and press Enter.</div>
                {/if}
              </div>
            {/if}
          </div>

          <!-- More Actions ("...") -->
          <div class="relative-popover-anchor">
            <button
              type="button"
              class="attribute-chip-btn more-chip"
              onclick={() => {
                const prev = showMorePicker;
                closeAllPopovers();
                showMorePicker = !prev;
              }}
            >
              <FluentIcons name="moreHorizontal" size={15} color="var(--text-secondary)" />
            </button>

            {#if showMorePicker}
              <div class="dropdown-popover-card more-options-menu">
                <div class="picker-section-label">Subsidiary Brand</div>
                <div class="menu-brand-grid">
                  {#each brands as b}
                    <button
                      type="button"
                      class="picker-option-row {brand === b.code ? 'active' : ''}"
                      onclick={() => { brand = b.code; }}
                    >
                      <div class="option-left">
                        <span class="brand-code-badge">{b.code}</span>
                        <span>{b.label}</span>
                      </div>
                      {#if brand === b.code}
                        <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                      {/if}
                    </button>
                  {/each}
                </div>

                <div class="preset-divider"></div>
                <div class="picker-section-label">Decision &amp; Review State</div>
                <div class="menu-brand-grid">
                  {#each decisions as d}
                    <button
                      type="button"
                      class="picker-option-row {decisionStatus === d.id ? 'active' : ''}"
                      onclick={() => { decisionStatus = d.id; }}
                    >
                      <div class="option-left">
                        <span class="decision-bullet"></span>
                        <span>{d.label}</span>
                      </div>
                      {#if decisionStatus === d.id}
                        <FluentIcons name="checkmark" size={13} color="var(--brand-primary, #0084FF)" />
                      {/if}
                    </button>
                  {/each}
                </div>
              </div>
            {/if}
          </div>

        </div>

        <!-- FIELDS & EXPANSION SECTION (Screenshot 1) -->
        <div class="fields-section-container">
          <div class="fields-heading">Fields</div>

          <div class="fields-actions-row">
            <button
              type="button"
              class="create-field-btn"
              onclick={() => showSubtasksField = !showSubtasksField}
            >
              <FluentIcons name="plus" size={12} color="var(--text-secondary)" />
              <span>{showSubtasksField ? 'Hide Subtasks Checklist' : 'Add Initial Subtasks'}</span>
            </button>
          </div>

          {#if showSubtasksField}
            <div class="subtasks-input-card">
              <div class="subtasks-header-row">
                <span class="subtasks-label">## SUBTASKS BREAKDOWN</span>
                <span class="subtasks-count">{subtasksList.length} items</span>
              </div>

              {#if subtasksList.length > 0}
                <div class="subtasks-checklist">
                  {#each subtasksList as st, index}
                    <div class="subtask-entry-row">
                      <span class="subtask-circle"></span>
                      <input
                        type="text"
                        class="subtask-inline-edit"
                        bind:value={subtasksList[index]}
                        onkeydown={(e) => handleSubtaskInputKeydown(e, index)}
                        placeholder="Subtask name... (press Return to add next)"
                      />
                      <button type="button" class="subtask-delete-btn" onclick={() => removeSubtask(index)} title="Remove subtask">
                        ✕
                      </button>
                    </div>
                  {/each}
                </div>
              {/if}

              <div class="subtask-add-row">
                <input
                  type="text"
                  placeholder="Add a subtask (press Return/Enter to add)..."
                  bind:value={newSubtaskInput}
                  onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addSubtask(); } }}
                  class="subtask-text-input"
                />
                <button type="button" class="subtask-btn-submit" onclick={addSubtask}>
                  Add
                </button>
              </div>
            </div>
          {/if}
        </div>

      </div>

      <!-- BOTTOM ACTION FOOTER (Screenshot 1) -->
      <div class="modal-footer-bar" onclick={(e) => e.stopPropagation()}>
        <div class="footer-left">
          <button type="button" class="templates-btn">
            <FluentIcons name="sparkles" size={13} color="var(--text-secondary)" />
            <span>Templates</span>
          </button>
        </div>

        <div class="footer-right">
          <!-- Attachment Clip -->
          <button type="button" class="footer-icon-btn" title="Add Attachments">
            <FluentIcons name="paperclip" size={15} color="var(--text-secondary)" />
          </button>

          <!-- Watchers / Notifications Bell -->
          <button type="button" class="footer-icon-btn" title="Task Watchers">
            <FluentIcons name="bell" size={15} color="var(--text-secondary)" />
            <span class="bell-count">1</span>
          </button>

          <!-- ClickUp Signature Split Button -->
          <div class="split-create-button-group">
            <button
              type="button"
              class="primary-create-btn"
              disabled={isSubmitting}
              onclick={() => handleSubmit(false)}
            >
              {isSubmitting ? 'Creating...' : 'Create Task'}
            </button>

            <button
              type="button"
              class="split-chevron-btn"
              disabled={isSubmitting}
              onclick={() => showSplitMenu = !showSplitMenu}
            >
              <FluentIcons name="chevronDown" size={11} color="#FFFFFF" />
            </button>

            {#if showSplitMenu}
              <div class="split-dropdown-popup">
                <button
                  type="button"
                  class="split-menu-row"
                  onclick={() => handleSubmit(true)}
                >
                  Create &amp; open
                </button>
                <button
                  type="button"
                  class="split-menu-row"
                  onclick={() => handleSubmit(false)}
                >
                  Create &amp; duplicate
                </button>
              </div>
            {/if}
          </div>
        </div>
      </div>

    </div>
  </div>
{/if}

<style>
  /* ─── MODAL BACKDROP & FLOATING CARD ─── */
  .clickup-modal-backdrop {
    position: fixed;
    inset: 0;
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(15, 23, 42, 0.6);
    backdrop-filter: blur(5px);
    animation: fadeIn 0.15s ease-out;
    padding: 20px;
  }

  .clickup-modal-card {
    position: relative;
    width: 100%;
    max-width: 660px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 14px;
    box-shadow: 0 24px 64px -12px rgba(0, 0, 0, 0.32), 0 0 0 1px rgba(0, 0, 0, 0.05);
    display: flex;
    flex-direction: column;
    overflow: visible;
    animation: scaleUp 0.18s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes scaleUp {
    from { opacity: 0; transform: scale(0.96); }
    to { opacity: 1; transform: scale(1); }
  }

  /* ─── TOP NAVIGATION TAB BAR ─── */
  .modal-top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 18px;
    height: 48px;
    border-bottom: 1px solid var(--surface-card-border, #E2E8F0);
  }

  .tab-items-left {
    display: flex;
    align-items: center;
    gap: 20px;
    height: 100%;
  }

  .top-tab-item {
    background: none;
    border: none;
    padding: 0;
    height: 100%;
    font-size: 13.5px;
    font-weight: 500;
    color: var(--text-secondary, #64748B);
    cursor: pointer;
    position: relative;
    transition: color 0.15s;
    display: flex;
    align-items: center;
  }

  .top-tab-item:hover {
    color: var(--text-primary, #0F172A);
  }

  .top-tab-item.active {
    color: var(--text-primary, #0F172A);
    font-weight: 600;
  }

  .top-tab-item.active::after {
    content: '';
    position: absolute;
    bottom: -1px;
    left: 0;
    right: 0;
    height: 2px;
    background-color: var(--brand-primary, #0084FF);
    border-radius: 2px 2px 0 0;
  }

  .top-actions-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .icon-utility-btn {
    background: none;
    border: none;
    width: 28px;
    height: 28px;
    border-radius: 6px;
    color: var(--text-tertiary, #94A3B8);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .icon-utility-btn:hover {
    background: var(--surface-card-hover, rgba(0, 0, 0, 0.05));
    color: var(--text-primary, #0F172A);
  }

  .icon-close-circle {
    background: var(--surface-card-subtle, #F1F5F9);
    border: none;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    color: var(--text-secondary, #64748B);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .icon-close-circle:hover {
    background: #E2E8F0;
    color: var(--text-primary, #0F172A);
  }

  /* ─── MAIN CONTENT AREA ─── */
  .modal-content-area {
    padding: 16px 22px 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  /* Subheader Pills */
  .pill-selectors-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .relative-popover-anchor {
    position: relative;
  }

  .subheader-pill-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    background: transparent;
    border: 1px solid var(--surface-card-border, #CBD5E1);
    border-radius: 6px;
    font-size: 12.5px;
    font-weight: 500;
    color: var(--text-primary, #1E293B);
    cursor: pointer;
    transition: all 0.15s;
  }

  .subheader-pill-btn:hover {
    border-color: #94A3B8;
    background: var(--surface-card-hover, rgba(0, 0, 0, 0.03));
  }

  .subheader-pill-btn.selected {
    border-color: var(--brand-primary, #0084FF);
    box-shadow: 0 0 0 2px rgba(0, 132, 255, 0.15);
  }

  .pill-btn-label {
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* ─── TITLE & DESCRIPTION ─── */
  .title-desc-container {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .clickup-title-input {
    width: 100%;
    border: none;
    outline: none;
    background: transparent;
    font-size: 21px;
    font-weight: 600;
    color: var(--text-primary, #0F172A);
    padding: 4px 0;
    font-family: inherit;
  }

  .clickup-title-input::placeholder {
    color: var(--text-tertiary, #94A3B8);
    font-weight: 500;
  }

  .clickup-description-input {
    width: 100%;
    border: none;
    outline: none;
    background: transparent;
    font-size: 13.5px;
    color: var(--text-primary, #334155);
    font-family: inherit;
    line-height: 1.5;
    resize: none;
    padding: 0;
  }

  .clickup-description-input::placeholder {
    color: var(--text-tertiary, #94A3B8);
  }

  /* ─── ATTRIBUTE CHIPS ROW (Pill Buttons) ─── */
  .attribute-chips-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    padding-top: 10px;
  }

  .attribute-chip-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary, #475569);
    cursor: pointer;
    transition: all 0.15s;
    user-select: none;
  }

  .attribute-chip-btn:hover {
    background: var(--surface-card-hover, #F1F5F9);
    border-color: #CBD5E1;
    color: var(--text-primary, #0F172A);
  }

  .attribute-chip-btn.has-value {
    color: var(--text-primary, #0F172A);
    border-color: #CBD5E1;
  }

  .chip-status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .assignee-avatar-pill {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    color: #FFFFFF;
    font-size: 9px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .more-chip {
    padding: 0 8px;
  }

  /* ─── FIELDS SECTION ─── */
  .fields-section-container {
    padding-top: 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .fields-heading {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--text-tertiary, #64748B);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .create-field-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary, #475569);
    cursor: pointer;
    align-self: flex-start;
    transition: background 0.15s;
  }

  .create-field-btn:hover {
    background: var(--surface-card-hover, #F1F5F9);
    color: var(--text-primary, #0F172A);
  }

  /* Subtasks expansion box */
  .subtasks-input-card {
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 4px;
  }

  .subtasks-header-row {
    display: flex;
    justify-content: space-between;
    font-size: 11.5px;
    font-weight: 600;
    color: var(--text-tertiary, #64748B);
  }

  .subtasks-checklist {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .subtask-entry-row {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 5px;
    padding: 5px 8px;
    font-size: 12.5px;
  }

  .subtask-circle {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 1.5px solid #94A3B8;
  }

  .subtask-text {
    flex: 1;
    color: var(--text-primary, #0F172A);
  }

  .subtask-inline-edit {
    flex: 1;
    border: none;
    background: transparent;
    font-size: 12.5px;
    color: var(--text-primary, #0F172A);
    outline: none;
    padding: 2px 4px;
    border-radius: 4px;
  }

  .subtask-inline-edit:focus {
    background: var(--surface-card-subtle, #F8FAFC);
    box-shadow: 0 0 0 1px #0284C7;
  }

  .subtask-delete-btn {
    background: none;
    border: none;
    color: var(--text-tertiary, #94A3B8);
    cursor: pointer;
    font-size: 11px;
  }

  .subtask-delete-btn:hover {
    color: #EF4444;
  }

  .subtask-add-row {
    display: flex;
    gap: 6px;
  }

  .subtask-text-input {
    flex: 1;
    height: 28px;
    padding: 0 8px;
    border: 1px solid var(--surface-card-border, #CBD5E1);
    border-radius: 5px;
    font-size: 12px;
    outline: none;
    background: var(--surface-card, #FFFFFF);
  }

  .subtask-btn-submit {
    height: 28px;
    padding: 0 10px;
    background: var(--surface-card-subtle, #E2E8F0);
    border: none;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
  }

  /* ─── BOTTOM ACTION FOOTER ─── */
  .modal-footer-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 20px;
    border-top: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    border-radius: 0 0 14px 14px;
  }

  .templates-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    height: 32px;
    padding: 0 12px;
    background: transparent;
    border: 1px solid var(--surface-card-border, #CBD5E1);
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary, #475569);
    cursor: pointer;
    transition: all 0.15s;
  }

  .templates-btn:hover {
    background: var(--surface-card-hover, rgba(0, 0, 0, 0.04));
    border-color: #94A3B8;
    color: var(--text-primary, #0F172A);
  }

  .footer-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .footer-icon-btn {
    background: none;
    border: none;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border-radius: 6px;
    cursor: pointer;
    transition: background 0.15s;
  }

  .footer-icon-btn:hover {
    background: var(--surface-card-hover, rgba(0, 0, 0, 0.05));
  }

  .bell-count {
    position: absolute;
    right: 2px;
    bottom: 2px;
    font-size: 9px;
    font-weight: 700;
    color: var(--text-secondary, #64748B);
  }

  /* Split Primary Button */
  .split-create-button-group {
    position: relative;
    display: inline-flex;
    align-items: stretch;
    height: 34px;
  }

  .primary-create-btn {
    height: 100%;
    padding: 0 14px;
    background-color: var(--brand-primary, #0084FF);
    border: none;
    border-radius: 6px 0 0 6px;
    color: #FFFFFF;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.15s;
  }

  .primary-create-btn:hover:not(:disabled) {
    background-color: #0070DF;
  }

  .primary-create-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .split-chevron-btn {
    height: 100%;
    width: 24px;
    padding: 0;
    background-color: var(--brand-primary, #0084FF);
    border: none;
    border-left: 1px solid rgba(255, 255, 255, 0.25);
    border-radius: 0 6px 6px 0;
    color: #FFFFFF;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background-color 0.15s;
  }

  .split-chevron-btn:hover:not(:disabled) {
    background-color: #0070DF;
  }

  .split-dropdown-popup {
    position: absolute;
    bottom: calc(100% + 6px);
    right: 0;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 8px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
    padding: 4px;
    min-width: 150px;
    z-index: 1000;
  }

  .split-menu-row {
    width: 100%;
    text-align: left;
    background: none;
    border: none;
    padding: 8px 12px;
    font-size: 13px;
    border-radius: 5px;
    color: var(--text-primary, #0F172A);
    cursor: pointer;
  }

  .split-menu-row:hover {
    background: var(--surface-card-hover, #F1F5F9);
  }

  /* ─── FLOATING DROPDOWN POPOVERS ─── */
  .dropdown-popover-card {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    z-index: 1000;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 10px;
    box-shadow: 0 16px 36px -4px rgba(0, 0, 0, 0.22);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: fadeIn 0.12s ease-out;
  }

  .picker-search-bar {
    padding: 8px 10px;
    display: flex;
    align-items: center;
    gap: 6px;
    border-bottom: 1px solid var(--surface-card-border, #E2E8F0);
  }

  .picker-search-input {
    width: 100%;
    border: 1px solid #38BDF8;
    border-radius: 6px;
    padding: 5px 8px;
    font-size: 12.5px;
    outline: none;
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #0F172A);
  }

  .picker-scroll-area {
    max-height: 240px;
    overflow-y: auto;
    padding: 6px 4px;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .picker-section-label {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 6px 8px 3px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, #64748B);
    text-transform: uppercase;
  }

  .picker-option-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    background: none;
    border: none;
    padding: 6px 10px;
    border-radius: 6px;
    font-size: 13px;
    color: var(--text-primary, #0F172A);
    cursor: pointer;
    text-align: left;
    transition: background 0.12s;
  }

  .picker-option-row:hover {
    background: var(--surface-card-hover, #F1F5F9);
  }

  .picker-option-row.active {
    background: var(--surface-card-subtle, #F8FAFC);
    font-weight: 600;
  }

  .picker-option-row.nested {
    padding-left: 24px;
  }

  .option-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .picker-count-badge {
    font-size: 11px;
    color: var(--text-tertiary, #94A3B8);
  }

  .picker-browse-folder {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary, #475569);
  }

  .team-color-badge {
    width: 18px;
    height: 18px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    color: #FFFFFF;
    font-weight: 700;
  }

  .team-color-badge.blue { background-color: #3B82F6; }
  .team-color-badge.green { background-color: #10B981; }

  /* Specific Menus Sizing */
  .location-picker-menu { width: 260px; }
  .task-type-menu { width: 220px; }
  .status-menu { width: 170px; padding: 6px; }
  .priority-menu { width: 160px; padding: 6px; }
  .assignee-menu { width: 260px; }
  .tags-menu { width: 240px; padding: 8px; }
  .more-options-menu { width: 260px; padding: 8px; max-height: 320px; overflow-y: auto; }

  /* Assignee Picker Roster Items */
  .avatar-with-presence {
    position: relative;
    width: 24px;
    height: 24px;
  }

  .avatar-badge {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    color: #FFFFFF;
    font-size: 10px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .presence-dot {
    position: absolute;
    bottom: -1px;
    right: -1px;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    border: 1.5px solid var(--surface-card, #FFFFFF);
  }

  .presence-dot.online {
    background-color: #10B981;
  }

  .staff-text-col {
    display: flex;
    flex-direction: column;
  }

  .staff-title {
    font-size: 12.5px;
    font-weight: 500;
  }

  .staff-sub {
    font-size: 10.5px;
    color: var(--text-tertiary, #94A3B8);
  }

  .agent-icon-badge {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: linear-gradient(135deg, #8B5CF6, #EC4899);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* Tags menu */
  .tag-add-btn {
    background: var(--brand-primary, #0084FF);
    border: none;
    border-radius: 4px;
    color: #FFFFFF;
    font-size: 11px;
    padding: 0 8px;
    height: 26px;
    cursor: pointer;
  }

  .tags-badge-cloud {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 8px;
  }

  .tag-bubble {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: var(--surface-card-subtle, #F1F5F9);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 12px;
    padding: 2px 8px;
    font-size: 11.5px;
    color: var(--text-secondary, #475569);
  }

  .tag-remove {
    background: none;
    border: none;
    color: var(--text-tertiary, #94A3B8);
    cursor: pointer;
    font-size: 10px;
    padding: 0;
  }

  .empty-tags-hint {
    padding: 8px 4px 4px;
    font-size: 11.5px;
    color: var(--text-tertiary, #94A3B8);
    text-align: center;
  }

  /* More menu badges */
  .brand-code-badge {
    display: inline-block;
    padding: 1px 5px;
    background: rgba(0, 132, 255, 0.1);
    color: var(--brand-primary, #0084FF);
    font-weight: 700;
    font-size: 10px;
    border-radius: 3px;
  }

  .decision-bullet {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background-color: #64748B;
  }

  /* ─── DUAL DATE PICKER (Screenshot 5) ─── */
  .dual-date-picker {
    width: 420px;
    padding: 12px;
  }

  .date-header-tabs {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    margin-bottom: 12px;
  }

  .date-input-tab {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 34px;
    padding: 0 10px;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 6px;
    font-size: 12.5px;
    color: var(--text-primary, #0F172A);
    cursor: pointer;
    transition: all 0.15s;
  }

  .date-input-tab.active-tab {
    border-color: #38BDF8;
    box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);
    background: #FFFFFF;
    font-weight: 600;
  }

  .date-picker-split-body {
    display: grid;
    grid-template-columns: 140px 1fr;
    gap: 12px;
  }

  /* Left Presets */
  .date-presets-col {
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--surface-card-border, #E2E8F0);
    padding-right: 8px;
  }

  .preset-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    background: none;
    border: none;
    padding: 5px 6px;
    border-radius: 5px;
    font-size: 12px;
    color: var(--text-primary, #0F172A);
    cursor: pointer;
    text-align: left;
    transition: background 0.12s;
  }

  .preset-row:hover {
    background: var(--surface-card-hover, #F1F5F9);
  }

  .preset-hint {
    font-size: 11px;
    color: var(--text-tertiary, #94A3B8);
  }

  .preset-divider {
    height: 1px;
    background-color: var(--surface-card-border, #E2E8F0);
    margin: 6px 0;
  }

  .recurring-row {
    color: var(--text-secondary, #475569);
  }

  /* Right Calendar */
  .date-calendar-col {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .cal-nav-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 2px;
  }

  .cal-month-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary, #0F172A);
  }

  .cal-nav-actions {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .cal-nav-btn {
    background: none;
    border: none;
    font-size: 11.5px;
    font-weight: 500;
    color: var(--text-secondary, #475569);
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 4px;
  }

  .cal-nav-btn:hover {
    background: var(--surface-card-hover, #F1F5F9);
  }

  .cal-weekdays-row {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    text-align: center;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, #94A3B8);
    padding: 4px 0;
  }

  .cal-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 2px;
  }

  .cal-day-cell {
    aspect-ratio: 1;
    background: none;
    border: none;
    border-radius: 50%;
    font-size: 12px;
    color: var(--text-primary, #0F172A);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.12s;
  }

  .cal-day-cell:hover:not(.is-today-red) {
    background: var(--surface-card-hover, #F1F5F9);
  }

  .cal-day-cell.muted {
    color: var(--text-tertiary, #CBD5E1);
  }

  /* Signature ClickUp Today Red Circle Badge (Screenshot 5) */
  .cal-day-cell.is-today-red {
    background-color: #EF4444 !important;
    color: #FFFFFF !important;
    font-weight: 700;
  }

  .cal-day-cell.is-selected:not(.is-today-red) {
    background-color: var(--brand-primary, #0084FF);
    color: #FFFFFF;
    font-weight: 600;
  }

  .date-footer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 10px;
    padding-top: 8px;
    border-top: 1px solid var(--surface-card-border, #E2E8F0);
  }

  .date-clear-btn {
    background: none;
    border: none;
    font-size: 12px;
    color: var(--text-tertiary, #94A3B8);
    cursor: pointer;
  }

  .date-clear-btn:hover {
    color: #EF4444;
  }

  .date-done-btn {
    background: var(--brand-primary, #0084FF);
    border: none;
    border-radius: 5px;
    color: #FFFFFF;
    font-size: 12px;
    font-weight: 600;
    padding: 4px 12px;
    cursor: pointer;
  }
</style>

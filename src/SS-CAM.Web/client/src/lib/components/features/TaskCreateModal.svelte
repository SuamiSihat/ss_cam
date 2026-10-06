<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { StudioTask, StudioTaskStatus, ProjectPriority, TaskDecisionStatus } from '$lib/types';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface Props {
    isOpen: boolean;
    onClose: () => void;
    onCreated: (task: StudioTask) => void;
  }

  let { isOpen = $bindable(false), onClose, onCreated }: Props = $props();

  let title = $state('');
  let brand = $state('SS');
  let workstream = $state('Packaging');
  let priority = $state<ProjectPriority>('medium');
  let status = $state<StudioTaskStatus>('backlog');
  let decisionStatus = $state<TaskDecisionStatus>('pending');
  let assignee = $state('');
  let startDate = $state('');
  let dueDate = $state('');
  let tags = $state('');
  let description = $state('');
  let subtasksText = $state('');
  let isSubmitting = $state(false);

  let staffRoster = $state<any[]>([]);

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

  const priorityOptions: { id: ProjectPriority; label: string }[] = [
    { id: 'urgent', label: 'Urgent (P3)' },
    { id: 'high', label: 'High (P2)' },
    { id: 'medium', label: 'Medium (P1)' },
    { id: 'low', label: 'Low' }
  ];

  const statusOptions: { id: StudioTaskStatus; label: string }[] = [
    { id: 'backlog', label: 'Backlog / Intake' },
    { id: 'in-progress', label: 'In Progress' },
    { id: 'review', label: 'Review & QA' },
    { id: 'done', label: 'Approved & Done' }
  ];

  const decisionOptions: { id: TaskDecisionStatus; label: string }[] = [
    { id: 'pending', label: 'Pending Evaluation' },
    { id: 'in_review', label: 'In Art Director Review' },
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

  async function handleSubmit() {
    if (!title.trim()) {
      appState.addToast('Please enter a task title.', 'warning');
      return;
    }

    isSubmitting = true;
    try {
      const selectedStaffObj = staffRoster.find(
        s => (s.staffId && s.staffId.toLowerCase() === assignee.toLowerCase()) ||
             (s.username && s.username.toLowerCase() === assignee.toLowerCase())
      );
      const assigneeName = selectedStaffObj ? selectedStaffObj.name : assignee;
      const assigneeAvatarColor = selectedStaffObj ? selectedStaffObj.avatarColor : undefined;

      const parsedTags = tags
        .split(',')
        .map(t => t.trim())
        .filter(Boolean);

      // Parse initial subtasks from lines
      const parsedSubtasks = subtasksText
        .split('\n')
        .map(line => line.trim())
        .filter(Boolean)
        .map((subTitle, idx) => ({
          id: `st-${Date.now()}-${idx}`,
          title: subTitle,
          completed: false
        }));

      const res = await ApiClient.createStudioTask({
        title: title.trim(),
        brand,
        workstream,
        priority,
        status,
        decisionStatus,
        assignee,
        assigneeName,
        assigneeAvatarColor,
        startDate: startDate || undefined,
        dueDate: dueDate || undefined,
        subtasks: parsedSubtasks,
        tags: parsedTags,
        description: description.trim()
      });

      appState.addToast(`Task "${title.trim()}" created successfully`, 'success', 'Task Created');
      onCreated(res.task);
      handleReset();
      onClose();
    } catch (err: any) {
      appState.addToast(`Failed to create task: ${err.message}`, 'error');
    } finally {
      isSubmitting = false;
    }
  }

  function handleClose() {
    isOpen = false;
    if (onClose) onClose();
  }

  function handleReset() {
    title = '';
    workstream = 'Packaging';
    description = '';
    tags = '';
    subtasksText = '';
    startDate = '';
    dueDate = '';
    priority = 'medium';
    status = 'backlog';
    decisionStatus = 'pending';
    brand = 'SS';
  }
</script>

<FluentDialog open={isOpen} title="Create Studio Task" onClose={handleClose}>
  <div class="task-modal-body">
    <!-- Task Title -->
    <div class="form-row">
      <label for="create-task-title" class="form-label">
        TASK TITLE <span class="req">*</span>
      </label>
      <input
        id="create-task-title"
        type="text"
        class="form-input text-lg"
        placeholder="e.g. Ramadan 2026 Gift Box 3D Mockup & Dieline Review"
        bind:value={title}
        autofocus
      />
    </div>

    <!-- Workstream & Brand -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-workstream" class="form-label">WORKSTREAM</label>
        <select id="create-task-workstream" class="form-select" bind:value={workstream}>
          {#each workstreamOptions as ws}
            <option value={ws}>{ws}</option>
          {/each}
        </select>
      </div>

      <div class="form-row">
        <label for="create-task-brand" class="form-label">SUBSIDIARY BRAND</label>
        <select id="create-task-brand" class="form-select" bind:value={brand}>
          {#each brandOptions as b}
            <option value={b.code}>[{b.code}] {b.label}</option>
          {/each}
        </select>
      </div>
    </div>

    <!-- Priority & Status -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-priority" class="form-label">PRIORITY</label>
        <select id="create-task-priority" class="form-select" bind:value={priority}>
          {#each priorityOptions as p}
            <option value={p.id}>{p.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-row">
        <label for="create-task-status" class="form-label">INITIAL STAGE</label>
        <select id="create-task-status" class="form-select" bind:value={status}>
          {#each statusOptions as s}
            <option value={s.id}>{s.label}</option>
          {/each}
        </select>
      </div>
    </div>

    <!-- Lead Assignee & Decision Status -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-assignee" class="form-label">LEAD ASSIGNEE</label>
        <select id="create-task-assignee" class="form-select" bind:value={assignee}>
          <option value="">Unassigned</option>
          {#each staffRoster as staff}
            <option value={staff.staffId || staff.username}>
              {staff.name} ({staff.staffId || staff.role})
            </option>
          {/each}
        </select>
      </div>

      <div class="form-row">
        <label for="create-task-decision" class="form-label">DECISION STATE</label>
        <select id="create-task-decision" class="form-select" bind:value={decisionStatus}>
          {#each decisionOptions as d}
            <option value={d.id}>{d.label}</option>
          {/each}
        </select>
      </div>
    </div>

    <!-- Timeline: Start Date & Due Date -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-start" class="form-label">START DATE</label>
        <input
          id="create-task-start"
          type="date"
          class="form-input"
          bind:value={startDate}
        />
      </div>

      <div class="form-row">
        <label for="create-task-due" class="form-label">DUE DATE</label>
        <input
          id="create-task-due"
          type="date"
          class="form-input"
          bind:value={dueDate}
        />
      </div>
    </div>

    <!-- Subtasks breakdown (optional initial checklist) -->
    <div class="form-row">
      <label for="create-task-subtasks" class="form-label">
        ## SUBTASKS (ONE PER LINE, OPTIONAL)
      </label>
      <textarea
        id="create-task-subtasks"
        class="form-textarea"
        rows="2"
        placeholder="Verify die-cut measurements&#10;Check Pantone spot colors&#10;Render 3D mockup"
        bind:value={subtasksText}
      ></textarea>
    </div>

    <!-- Tags -->
    <div class="form-row">
      <label for="create-task-tags" class="form-label">TAGS (COMMA SEPARATED)</label>
      <input
        id="create-task-tags"
        type="text"
        class="form-input"
        placeholder="packaging, dieline, cmyk, pantone"
        bind:value={tags}
      />
    </div>

    <!-- Concept Brief / Notes -->
    <div class="form-row">
      <label for="create-task-desc" class="form-label">CONCEPT BRIEF &amp; OBJECTIVES</label>
      <textarea
        id="create-task-desc"
        class="form-textarea"
        rows="3"
        placeholder="Brief description of visual concept, dieline dimensions, angle requirements, or target market..."
        bind:value={description}
      ></textarea>
    </div>

    <div class="bridge-info-box">
      <span class="info-icon-wrap">
        <FluentIcons name="info" size={16} />
      </span>
      <p>
        <strong>Decoupled Pre-Production:</strong> This creates a lightweight task for conceptual tracking. When ready for NAS file authoring, you can link it directly to an official NAS project vault.
      </p>
    </div>
  </div>

  {#snippet footer()}
    <FluentButton appearance="secondary" onclick={onClose} disabled={isSubmitting}>
      Cancel
    </FluentButton>
    <FluentButton appearance="primary" onclick={handleSubmit} disabled={isSubmitting}>
      {isSubmitting ? 'Creating Task…' : 'Create Task'}
    </FluentButton>
  {/snippet}
</FluentDialog>

<style>
  .task-modal-body {
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 6px 0;
  }

  .form-row {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .form-grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .form-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    letter-spacing: 0.4px;
  }

  .req {
    color: var(--color-danger, #EF4444);
  }

  .form-input,
  .form-select,
  .form-textarea {
    width: 100%;
    min-height: 36px;
    padding: 7px 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    color: var(--text-primary);
    font-size: 13px;
    transition: all 0.15s ease;
    font-family: inherit;
  }

  .form-select option {
    background: var(--surface-card);
    color: var(--text-primary);
    padding: 8px 12px;
  }

  .form-input.text-lg {
    font-size: 15px;
    font-weight: 600;
    min-height: 40px;
  }

  .form-input:focus,
  .form-select:focus,
  .form-textarea:focus {
    outline: none;
    border-color: var(--brand-accent);
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.2);
  }

  .form-textarea {
    resize: vertical;
    line-height: 1.5;
  }

  .bridge-info-box {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 10px 14px;
    background: var(--surface-card-subtle, rgba(0, 120, 212, 0.06));
    border: 1px solid var(--surface-card-border, rgba(0, 120, 212, 0.18));
    border-radius: 8px;
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.45;
  }

  .bridge-info-box strong {
    color: var(--brand-primary);
  }

  .info-icon-wrap {
    color: var(--brand-accent, #0078D4);
    display: inline-flex;
    margin-top: 2px;
  }
</style>

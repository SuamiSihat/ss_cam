<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { StudioTask, StudioTaskStatus, ProjectPriority } from '$lib/types';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';

  interface Props {
    isOpen: boolean;
    onClose: () => void;
    onCreated: (task: StudioTask) => void;
  }

  let { isOpen = $bindable(false), onClose, onCreated }: Props = $props();

  let title = $state('');
  let brand = $state('SS');
  let priority = $state<ProjectPriority>('medium');
  let status = $state<StudioTaskStatus>('backlog');
  let assignee = $state('');
  let dueDate = $state('');
  let tags = $state('');
  let description = $state('');
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

  const priorityOptions: { id: ProjectPriority; label: string }[] = [
    { id: 'urgent', label: '🔴 Urgent (P3)' },
    { id: 'high', label: '🟠 High (P2)' },
    { id: 'medium', label: '🔵 Medium (P1)' },
    { id: 'low', label: '⚪ Low' }
  ];

  const statusOptions: { id: StudioTaskStatus; label: string }[] = [
    { id: 'backlog', label: '📋 Backlog / Intake' },
    { id: 'in-progress', label: '⚡ In Progress' },
    { id: 'review', label: '🔍 Review & QA' }
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

      const res = await ApiClient.createStudioTask({
        title: title.trim(),
        brand,
        priority,
        status,
        assignee,
        assigneeName,
        assigneeAvatarColor,
        dueDate: dueDate || undefined,
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
    description = '';
    tags = '';
    dueDate = '';
    priority = 'medium';
    status = 'backlog';
    brand = 'SS';
  }
</script>

<FluentDialog open={isOpen} title="Create Studio Task (Pre-Production)" onClose={handleClose}>
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
        placeholder="e.g. Ramadan 2026 Gift Box 3D Mockup Ideation"
        bind:value={title}
        autofocus
      />
    </div>

    <!-- Brand & Priority -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-brand" class="form-label">SUBSIDIARY BRAND</label>
        <select id="create-task-brand" class="form-select" bind:value={brand}>
          {#each brandOptions as b}
            <option value={b.code}>[{b.code}] {b.label}</option>
          {/each}
        </select>
      </div>

      <div class="form-row">
        <label for="create-task-priority" class="form-label">PRIORITY</label>
        <select id="create-task-priority" class="form-select" bind:value={priority}>
          {#each priorityOptions as p}
            <option value={p.id}>{p.label}</option>
          {/each}
        </select>
      </div>
    </div>

    <!-- Status & Assignee -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-status" class="form-label">INITIAL STAGE</label>
        <select id="create-task-status" class="form-select" bind:value={status}>
          {#each statusOptions as s}
            <option value={s.id}>{s.label}</option>
          {/each}
        </select>
      </div>

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
    </div>

    <!-- Due Date & Tags -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="create-task-due" class="form-label">DUE DATE</label>
        <input
          id="create-task-due"
          type="date"
          class="form-input"
          bind:value={dueDate}
        />
      </div>

      <div class="form-row">
        <label for="create-task-tags" class="form-label">TAGS (COMMA SEPARATED)</label>
        <input
          id="create-task-tags"
          type="text"
          class="form-input"
          placeholder="packaging, 3d, social, tiktok"
          bind:value={tags}
        />
      </div>
    </div>

    <!-- Concept Brief / Notes -->
    <div class="form-row">
      <label for="create-task-desc" class="form-label">CONCEPT BRIEF &amp; OBJECTIVES</label>
      <textarea
        id="create-task-desc"
        class="form-textarea"
        rows="4"
        placeholder="Brief description of visual concept, dieline dimensions, angle requirements, or target market..."
        bind:value={description}
      ></textarea>
    </div>

    <div class="bridge-info-box">
      <span class="info-icon">💡</span>
      <p>
        <strong>Decoupled Pre-Production:</strong> This creates a lightweight task that will NOT create folders on Synology NAS yet. Once approved, use <em>[Provision NAS Workspace]</em> to generate the official project vault.
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
    background: var(--color-info-bg, #EFF6FF);
    border: 1px solid var(--color-info-border, #BFDBFE);
    border-radius: 8px;
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.45;
  }

  .bridge-info-box strong {
    color: var(--brand-primary);
  }

  .bridge-info-box em {
    color: var(--text-primary);
    font-style: normal;
    font-weight: 600;
  }

  .info-icon {
    font-size: 16px;
  }
</style>

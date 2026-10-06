<script lang="ts">
  import { onMount } from 'svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';

  interface Props {
    isOpen: boolean;
    preselectedProjectId?: string;
    onClose: () => void;
    onCreated: (task: any) => void;
  }

  let { isOpen = $bindable(false), preselectedProjectId = '', onClose, onCreated }: Props = $props();

  let projectId = $state(preselectedProjectId || '');
  let name = $state('');
  let role = $state<'copywriter' | 'designer' | 'manager' | 'reviewer'>('copywriter');
  let assignee = $state('');
  let status = $state('draft');
  let weight = $state(2.0);
  let channel = $state('whatsapp');
  let specs = $state('');
  let notes = $state('');
  let isSubmitting = $state(false);
  let projectSearch = $state('');

  $effect(() => {
    if (preselectedProjectId) {
      projectId = preselectedProjectId;
    }
  });

  const activeProjects = $derived.by(() => {
    const list = projectStore.projects || [];
    if (!projectSearch) return list.slice(0, 50);
    const q = projectSearch.toLowerCase();
    return list.filter(p => 
      (p.id || '').toLowerCase().includes(q) ||
      (p.title || '').toLowerCase().includes(q) ||
      (p.jobId || '').toLowerCase().includes(q)
    ).slice(0, 50);
  });

  const staffRoster = $derived(appState.staffRoster || []);

  const filteredStaff = $derived.by(() => {
    if (role === 'copywriter') {
      const cw = staffRoster.filter(s => (s.role || '').toLowerCase().includes('copy') || (s.role || '').toLowerCase().includes('writer'));
      return cw.length > 0 ? cw : staffRoster;
    }
    if (role === 'designer') {
      const des = staffRoster.filter(s => (s.role || '').toLowerCase().includes('design') || (s.role || '').toLowerCase().includes('art'));
      return des.length > 0 ? des : staffRoster;
    }
    return staffRoster;
  });

  async function handleSubmit() {
    if (!projectId) {
      appState.addToast('Please select a project to link this task to.', 'warning');
      return;
    }
    if (!name.trim()) {
      appState.addToast('Please enter a task title.', 'warning');
      return;
    }

    isSubmitting = true;
    try {
      const selectedStaffObj = staffRoster.find(s => s.staffId === assignee || s.username === assignee);
      const assigneeName = selectedStaffObj ? selectedStaffObj.name : assignee;

      const res = await ApiClient.createTask({
        projectId,
        name: name.trim(),
        role,
        assignee,
        assigneeName,
        status,
        weight,
        channel,
        specs: specs.trim(),
        notes: notes.trim(),
        linkedFile: role === 'copywriter' ? '03_COPYWRITING/COPY.md' : ''
      });

      appState.addToast(`Task "${name.trim()}" created and linked to ${projectId}`, 'success');
      onCreated(res.task);
      handleReset();
      onClose();
    } catch (err: any) {
      appState.addToast(`Failed to create task: ${err.message}`, 'error');
    } finally {
      isSubmitting = false;
    }
  }

  function handleReset() {
    name = '';
    notes = '';
    specs = '';
    weight = 2.0;
    projectSearch = '';
  }
</script>

<FluentDialog {isOpen} title="Create Collaborative Task (ClickUp Engine)" {onClose}>
  <div class="task-modal-body">
    <!-- 1. Link to Designer Project ID -->
    <div class="form-row">
      <label for="task-project-select" class="form-label required">
        <span>Linked Designer Project ID</span>
        <span class="label-hint">Bi-directionally synced with Designer NAS Vault</span>
      </label>
      <div class="project-picker-wrap">
        <select id="task-project-select" class="fluent-select" bind:value={projectId}>
          <option value="" disabled>-- Select Creative Project --</option>
          {#each activeProjects as p}
            <option value={p.id}>
              [{p.jobId || p.id}] {p.title || p.folderName} ({p.designer || 'Unassigned'})
            </option>
          {/each}
        </select>
      </div>
    </div>

    <!-- 2. Task Title -->
    <div class="form-row">
      <label for="task-name-input" class="form-label required">Task Title / Action Item</label>
      <input
        id="task-name-input"
        type="text"
        class="fluent-input"
        placeholder="e.g. Write 3 Hook Angles for TikTok Video Ad..."
        bind:value={name}
        required
      />
    </div>

    <!-- 3. Role & Assignee Split -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="task-role-select" class="form-label required">Task Role</label>
        <select id="task-role-select" class="fluent-select" bind:value={role}>
          <option value="copywriter">✍️ Copywriter (Copy Studio)</option>
          <option value="designer">🎨 Graphic Designer (Assets/Dieline)</option>
          <option value="manager">📋 Manager / Director (Review)</option>
          <option value="reviewer">🔍 Medical / Compliance Review</option>
        </select>
      </div>

      <div class="form-row">
        <label for="task-assignee-select" class="form-label">Assignee</label>
        <select id="task-assignee-select" class="fluent-select" bind:value={assignee}>
          <option value="">Unassigned</option>
          {#each filteredStaff as s}
            <option value={s.username || s.staffId}>
              {s.name} ({s.officialTitle || s.role})
            </option>
          {/each}
        </select>
      </div>
    </div>

    <!-- 4. Format Channel & Weight Points -->
    <div class="form-grid-2">
      <div class="form-row">
        <label for="task-channel-select" class="form-label">Marketing Channel</label>
        <select id="task-channel-select" class="fluent-select" bind:value={channel}>
          <option value="whatsapp">📱 WhatsApp Broadcast / Script</option>
          <option value="meta_ads">📸 Meta Ads (Carousel / 9:16)</option>
          <option value="tiktok">🎵 TikTok / Short-form Hook</option>
          <option value="packaging">📦 Product Packaging / Box Dieline</option>
          <option value="print">🖨️ Print / Banner / Bunting</option>
          <option value="landing_page">🌐 Landing Page / Web Copy</option>
        </select>
      </div>

      <div class="form-row">
        <label for="task-weight-select" class="form-label">Complexity Weight</label>
        <select id="task-weight-select" class="fluent-select" bind:value={weight}>
          <option value={1.0}>1 pt (Minor Edit / Hook Variant)</option>
          <option value={2.0}>2 pts (Standard Post / Script)</option>
          <option value={3.0}>3 pts (Multi-Slide / Full Campaign)</option>
          <option value={5.0}>5 pts (High-Complexity / Packaging Overhaul)</option>
        </select>
      </div>
    </div>

    <!-- 5. Specs & Guidelines -->
    <div class="form-row">
      <label for="task-notes-area" class="form-label">Creative Brief Notes & Key Angles</label>
      <textarea
        id="task-notes-area"
        class="fluent-textarea"
        rows="3"
        placeholder="Specific selling points, target demographics, KKM health precautions, or link previews..."
        bind:value={notes}
      ></textarea>
    </div>
  </div>

  <svelte:fragment slot="footer">
    <div class="dialog-actions">
      <FluentButton appearance="subtle" onclick={onClose} disabled={isSubmitting}>
        Cancel
      </FluentButton>
      <FluentButton appearance="primary" onclick={handleSubmit} disabled={isSubmitting}>
        {isSubmitting ? 'Creating Task…' : 'Create & Link Task'}
      </FluentButton>
    </div>
  </svelte:fragment>
</FluentDialog>

<style>
  .task-modal-body {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 6px 0;
  }

  .form-row {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .form-grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
  }

  @media (max-width: 600px) {
    .form-grid-2 {
      grid-template-columns: 1fr;
    }
  }

  .form-label {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-primary, #ffffff);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .form-label.required::after {
    content: '*';
    color: #ef4444;
    margin-left: 4px;
  }

  .label-hint {
    font-size: 0.72rem;
    font-weight: 400;
    color: var(--text-muted, #94a3b8);
  }

  .fluent-input, .fluent-select, .fluent-textarea {
    width: 100%;
    box-sizing: border-box;
    background: var(--card-bg, #1e293b);
    border: 1px solid var(--border-color, rgba(255,255,255,0.12));
    border-radius: 8px;
    padding: 10px 12px;
    color: var(--text-primary, #ffffff);
    font-size: 0.875rem;
    font-family: inherit;
    transition: border-color 0.2s, box-shadow 0.2s;
  }

  .fluent-select {
    min-height: 38px;
    cursor: pointer;
  }

  .fluent-input:focus, .fluent-select:focus, .fluent-textarea:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.25);
  }

  .dialog-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    width: 100%;
  }
</style>

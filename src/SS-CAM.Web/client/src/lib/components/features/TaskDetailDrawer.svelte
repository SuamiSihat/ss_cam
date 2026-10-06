<script lang="ts">
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import type { StudioTask, StudioTaskStatus, ProjectPriority } from '$lib/types';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface Props {
    open: boolean;
    task: StudioTask | null;
    staffRoster?: any[];
    onClose: () => void;
    onUpdated: (task: StudioTask) => void;
    onDeleted?: (taskId: string) => void;
  }

  let {
    open = $bindable(false),
    task,
    staffRoster = [],
    onClose,
    onUpdated,
    onDeleted
  }: Props = $props();

  let title = $state('');
  let status = $state<StudioTaskStatus>('backlog');
  let priority = $state<ProjectPriority>('medium');
  let brand = $state('SS');
  let assignee = $state('');
  let dueDate = $state('');
  let tagsInput = $state('');
  let description = $state('');
  let isSaving = $state(false);
  let isDeleting = $state(false);
  let isProvisioning = $state(false);
  let showProvisionForm = $state(false);
  let presetType = $state('Graphic & Print Design');
  let provisionDesigner = $state('');
  let activeTab = $state<'details' | 'notes'>('details');

  const brandOptions = [
    { code: 'SS', label: 'SuamiSihat (Primary)' },
    { code: 'SSH', label: 'SuamiSihat Holding' },
    { code: 'SSC', label: 'SuamiSihat Healthcare' },
    { code: 'SSW', label: 'SuamiSihat Wellness' },
    { code: 'SSE', label: 'SuamiSihat E-Commerce' },
    { code: 'SST', label: 'SuamiSihat Technology' }
  ];

  const statusOptions: { id: StudioTaskStatus; label: string; icon: string }[] = [
    { id: 'backlog', label: 'Backlog / Intake', icon: '📋' },
    { id: 'in-progress', label: 'In Progress', icon: '⚡' },
    { id: 'review', label: 'Review & QA', icon: '🔍' },
    { id: 'done', label: 'Approved & Done', icon: '✅' },
    { id: 'converted', label: 'NAS Vault Provisioned', icon: '🏛️' }
  ];

  const priorityOptions: { id: ProjectPriority; label: string; color: string }[] = [
    { id: 'urgent', label: 'Urgent (P3)', color: '#EF4444' },
    { id: 'high', label: 'High (P2)', color: '#F97316' },
    { id: 'medium', label: 'Medium (P1)', color: '#0284C7' },
    { id: 'low', label: 'Low', color: '#64748B' }
  ];

  // Sync state whenever task prop changes
  $effect(() => {
    if (task) {
      title = task.title || '';
      status = task.status || 'backlog';
      priority = task.priority || 'medium';
      brand = task.brand || 'SS';
      assignee = task.assignee || '';
      dueDate = task.dueDate ? task.dueDate.split('T')[0] : '';
      tagsInput = Array.isArray(task.tags) ? task.tags.join(', ') : '';
      description = task.description || '';
      provisionDesigner = task.assigneeName || task.assignee || 'Harussani';
      showProvisionForm = false;
    }
  });

  const assignedMember = $derived.by(() => {
    if (!assignee) return null;
    return staffRoster.find(
      s => (s.staffId && s.staffId.toLowerCase() === assignee.toLowerCase()) ||
           (s.username && s.username.toLowerCase() === assignee.toLowerCase())
    ) || null;
  });

  function close() {
    open = false;
    onClose();
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
        assignee,
        assigneeName: selectedMember ? selectedMember.name : assignee,
        assigneeAvatarColor: selectedMember ? selectedMember.avatarColor : undefined,
        dueDate: dueDate || undefined,
        tags,
        description: description.trim()
      });

      appState.addToast(`Saved changes for ${task.id}`, 'success');
      onUpdated(res.task);
    } catch (err: any) {
      appState.addToast(`Failed to update task: ${err.message}`, 'error');
    } finally {
      isSaving = false;
    }
  }

  async function handleDelete() {
    if (!task) return;
    if (!confirm(`Are you sure you want to delete task ${task.id} ("${task.title}")?`)) {
      return;
    }

    isDeleting = true;
    try {
      await ApiClient.deleteStudioTask(task.id);
      appState.addToast(`Deleted task ${task.id}`, 'info');
      if (onDeleted) onDeleted(task.id);
      close();
    } catch (err: any) {
      appState.addToast(`Failed to delete task: ${err.message}`, 'error');
    } finally {
      isDeleting = false;
    }
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
    if (task && (task.projectId || task.jobId)) {
      close();
      appState.navigate('project-detail', { id: task.projectId || task.jobId });
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape' && open) {
      close();
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if open && task}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="drawer-backdrop" onclick={close}></div>

  <aside class="task-drawer" role="dialog" aria-label="Task Details">
    <!-- ═══ HEADER ═══ -->
    <div class="drawer-header">
      <div class="header-left">
        <span class="task-id-badge">{task.id}</span>
        <FluentBadge type="brand" value={brand} />
        <span class="status-pill status-{status}">
          {statusOptions.find(s => s.id === status)?.label || status}
        </span>
      </div>

      <div class="header-right">
        <button class="close-icon-btn" onclick={close} aria-label="Close drawer" title="Close drawer">
          <FluentIcons name="close" size={16} />
        </button>
      </div>
    </div>

    <!-- ═══ BODY SCROLL CONTAINER ═══ -->
    <div class="drawer-body">
      <!-- Editable Title -->
      <div class="title-field-group">
        <label for="task-title-input" class="field-label">TASK TITLE</label>
        <input
          id="task-title-input"
          type="text"
          class="title-input"
          bind:value={title}
          placeholder="Task title or concept overview..."
        />
      </div>

      <!-- Quick Status Strip -->
      <div class="field-group">
        <label class="field-label">WORKSTREAM STATUS</label>
        <div class="status-strip">
          {#each statusOptions as opt}
            <button
              type="button"
              class="status-btn"
              class:selected={status === opt.id}
              onclick={() => (status = opt.id)}
            >
              <span>{opt.icon}</span>
              <span>{opt.label}</span>
            </button>
          {/each}
        </div>
      </div>

      <!-- Metadata Grid -->
      <div class="meta-grid">
        <!-- Priority -->
        <div class="field-group">
          <label for="task-priority-select" class="field-label">PRIORITY</label>
          <select id="task-priority-select" class="fluent-select" bind:value={priority}>
            {#each priorityOptions as p}
              <option value={p.id}>{p.label}</option>
            {/each}
          </select>
        </div>

        <!-- Target Brand -->
        <div class="field-group">
          <label for="task-brand-select" class="field-label">SUBSIDIARY BRAND</label>
          <select id="task-brand-select" class="fluent-select" bind:value={brand}>
            {#each brandOptions as b}
              <option value={b.code}>[{b.code}] {b.label}</option>
            {/each}
          </select>
        </div>

        <!-- Assignee -->
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

        <!-- Due Date -->
        <div class="field-group">
          <label for="task-due-date" class="field-label">DUE DATE</label>
          <input
            id="task-due-date"
            type="date"
            class="fluent-date-input"
            bind:value={dueDate}
          />
        </div>
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

      <!-- ═══ NAS WORKSPACE BRIDGE SECTION ═══ -->
      <div class="bridge-card" class:is-provisioned={status === 'converted' || !!task.projectId}>
        {#if status === 'converted' || task.projectId}
          <div class="bridge-header">
            <div class="bridge-icon">🏛️</div>
            <div class="bridge-title-wrap">
              <h4>Synology NAS Workspace Provisioned</h4>
              <p>Canonical project vault scaffolded on NAS file system.</p>
            </div>
          </div>
          <div class="bridge-details">
            <div class="bridge-meta-row">
              <span class="lbl">Official Job ID:</span>
              <span class="val highlight">{task.jobId || 'Scaffolded'}</span>
            </div>
            {#if task.projectId}
              <div class="bridge-meta-row">
                <span class="lbl">Vault Folder:</span>
                <span class="val path-val">{task.projectId}</span>
              </div>
            {/if}
          </div>
          <div class="bridge-actions">
            <FluentButton appearance="primary" onclick={jumpToProject}>
              Open Project Workspace ↗
            </FluentButton>
          </div>
        {:else}
          <div class="bridge-header">
            <div class="bridge-icon">🚀</div>
            <div class="bridge-title-wrap">
              <h4>The Bridge — Provision NAS Workspace</h4>
              <p>Promote this pre-production concept into an official Synology NAS Project Vault.</p>
            </div>
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
                appearance="primary"
                onclick={() => (showProvisionForm = true)}
              >
                🏛️ Provision NAS Workspace
              </FluentButton>
            </div>
          {/if}
        {/if}
      </div>

      <!-- Description / Concept Brief -->
      <div class="field-group">
        <div class="desc-header">
          <label for="task-desc-area" class="field-label">CONCEPT BRIEF &amp; NOTES (MARKDOWN)</label>
          <div class="tab-toggle">
            <button
              type="button"
              class="tab-btn"
              class:active={activeTab === 'details'}
              onclick={() => (activeTab = 'details')}
            >
              Write
            </button>
            <button
              type="button"
              class="tab-btn"
              class:active={activeTab === 'notes'}
              onclick={() => (activeTab = 'notes')}
            >
              Preview
            </button>
          </div>
        </div>

        {#if activeTab === 'details'}
          <textarea
            id="task-desc-area"
            class="desc-textarea"
            rows="8"
            bind:value={description}
            placeholder="Write creative directions, visual concepts, dieline specs, or marketing hooks..."
          ></textarea>
        {:else}
          <div class="desc-preview">
            {#if description.trim()}
              <pre class="preview-pre">{description}</pre>
            {:else}
              <span class="preview-empty">No notes or description written yet.</span>
            {/if}
          </div>
        {/if}
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
        <button
          type="button"
          class="delete-task-btn"
          onclick={handleDelete}
          disabled={isDeleting}
          title="Delete task"
        >
          🗑️ Delete Task
        </button>
      </div>

      <div class="footer-right">
        <FluentButton appearance="secondary" onclick={close}>
          Cancel
        </FluentButton>
        <FluentButton
          appearance="primary"
          onclick={handleSave}
          disabled={isSaving}
        >
          {isSaving ? 'Saving…' : 'Save Changes'}
        </FluentButton>
      </div>
    </div>
  </aside>
{/if}

<style>
  .drawer-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(4px);
    z-index: 1000;
  }

  .task-drawer {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: 620px;
    max-width: 95vw;
    background: var(--bg-card, #1E293B);
    border-left: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.12));
    display: flex;
    flex-direction: column;
    z-index: 1001;
    box-shadow: -10px 0 35px rgba(0, 0, 0, 0.45);
    animation: drawerSlide 0.22s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes drawerSlide {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  .drawer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.08));
    background: var(--bg-app, #0F172A);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .task-id-badge {
    font-family: monospace;
    font-weight: 800;
    font-size: 13px;
    color: var(--brand-accent, #38BDF8);
    background: rgba(56, 189, 248, 0.12);
    padding: 4px 9px;
    border-radius: 6px;
    border: 1px solid rgba(56, 189, 248, 0.3);
  }

  .status-pill {
    font-size: 11px;
    font-weight: 700;
    padding: 3px 9px;
    border-radius: 9999px;
    text-transform: capitalize;
  }
  .status-backlog { background: rgba(100, 116, 139, 0.2); color: #94A3B8; border: 1px solid rgba(100, 116, 139, 0.35); }
  .status-in-progress { background: rgba(2, 132, 199, 0.2); color: #38BDF8; border: 1px solid rgba(2, 132, 199, 0.4); }
  .status-review { background: rgba(139, 92, 246, 0.2); color: #C084FC; border: 1px solid rgba(139, 92, 246, 0.4); }
  .status-done { background: rgba(16, 185, 129, 0.2); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.4); }
  .status-converted { background: rgba(217, 119, 6, 0.2); color: #FBBF24; border: 1px solid rgba(217, 119, 6, 0.4); }

  .close-icon-btn {
    width: 32px;
    height: 32px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.12));
    background: transparent;
    color: var(--text-secondary, #94A3B8);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.15s;
  }
  .close-icon-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-primary, #F8FAFC);
  }

  .drawer-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px 24px 32px 20px;
    display: flex;
    flex-direction: column;
    gap: 18px;
  }

  .field-label {
    display: block;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary, #94A3B8);
    letter-spacing: 0.5px;
    margin-bottom: 6px;
  }

  .title-field-group {
    display: flex;
    flex-direction: column;
  }

  .title-input {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary, #F8FAFC);
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.15));
    border-radius: 8px;
    padding: 10px 14px;
    transition: all 0.15s;
  }
  .title-input:focus {
    outline: none;
    border-color: var(--brand-primary, #0078D4);
    box-shadow: 0 0 0 2px rgba(0, 120, 212, 0.25);
  }

  .status-strip {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }

  .status-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 6px 11px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.1));
    background: rgba(0, 0, 0, 0.2);
    color: var(--text-secondary, #94A3B8);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }
  .status-btn:hover {
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-primary, #F8FAFC);
  }
  .status-btn.selected {
    background: var(--brand-tint, rgba(0, 120, 212, 0.18));
    border-color: var(--brand-primary, #0078D4);
    color: var(--brand-accent, #38BDF8);
  }

  .meta-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
  }

  .fluent-select,
  .fluent-text-input,
  .fluent-date-input {
    width: 100%;
    min-height: 38px;
    padding: 7px 12px;
    border-radius: 6px;
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.14));
    background: rgba(0, 0, 0, 0.25);
    color: var(--text-primary, #F8FAFC);
    font-size: 13px;
    transition: all 0.15s;
  }
  .fluent-select option {
    background: var(--bg-card, #1E293B);
    color: var(--text-primary, #F8FAFC);
    padding: 8px 12px;
  }
  .fluent-select:focus,
  .fluent-text-input:focus,
  .fluent-date-input:focus {
    outline: none;
    border-color: var(--brand-primary, #0078D4);
  }

  .desc-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 6px;
  }

  .tab-toggle {
    display: flex;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 6px;
    padding: 2px;
  }
  .tab-btn {
    border: none;
    background: none;
    color: var(--text-secondary, #94A3B8);
    font-size: 11px;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 4px;
    cursor: pointer;
  }
  .tab-btn.active {
    background: var(--brand-primary, #0078D4);
    color: #FFFFFF;
  }

  .desc-textarea {
    width: 100%;
    padding: 12px;
    border-radius: 8px;
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.14));
    background: rgba(0, 0, 0, 0.25);
    color: var(--text-primary, #F8FAFC);
    font-size: 13px;
    line-height: 1.5;
    font-family: inherit;
    resize: vertical;
  }
  .desc-textarea:focus {
    outline: none;
    border-color: var(--brand-primary, #0078D4);
  }

  .desc-preview {
    padding: 12px;
    border-radius: 8px;
    border: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.1));
    background: rgba(0, 0, 0, 0.35);
    min-height: 140px;
  }
  .preview-pre {
    margin: 0;
    white-space: pre-wrap;
    font-family: inherit;
    font-size: 13px;
    color: var(--text-primary, #F8FAFC);
  }
  .preview-empty {
    font-size: 12px;
    color: var(--text-muted, #64748B);
    font-style: italic;
  }

  /* Bridge Card */
  .bridge-card {
    border: 1px solid rgba(56, 189, 248, 0.3);
    background: linear-gradient(135deg, rgba(2, 132, 199, 0.12) 0%, rgba(14, 165, 233, 0.04) 100%);
    border-radius: 10px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .bridge-card.is-provisioned {
    border-color: rgba(245, 158, 11, 0.35);
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(217, 119, 6, 0.04) 100%);
  }

  .bridge-header {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .bridge-icon {
    font-size: 24px;
  }
  .bridge-title-wrap h4 {
    margin: 0;
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #F8FAFC);
  }
  .bridge-title-wrap p {
    margin: 2px 0 0 0;
    font-size: 12px;
    color: var(--text-secondary, #94A3B8);
  }

  .bridge-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
    background: rgba(0, 0, 0, 0.25);
    padding: 10px 12px;
    border-radius: 6px;
  }
  .bridge-meta-row {
    display: flex;
    gap: 8px;
    font-size: 12px;
  }
  .bridge-meta-row .lbl { color: var(--text-secondary, #94A3B8); font-weight: 600; }
  .bridge-meta-row .val.highlight { color: #FBBF24; font-weight: 800; font-family: monospace; }
  .bridge-meta-row .path-val { color: var(--text-primary, #F8FAFC); font-family: monospace; word-break: break-all; }

  .provision-form {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 6px;
  }
  .provision-btn-row {
    display: flex;
    gap: 8px;
    margin-top: 6px;
  }

  .timestamps-footer {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-muted, #64748B);
    padding: 10px 0 0 0;
    border-top: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.06));
  }

  .drawer-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-top: 1px solid var(--surface-card-border, rgba(255, 255, 255, 0.08));
    background: var(--bg-app, #0F172A);
  }
  .footer-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .delete-task-btn {
    border: none;
    background: transparent;
    color: #EF4444;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
    transition: all 0.15s;
  }
  .delete-task-btn:hover {
    background: rgba(239, 68, 68, 0.15);
  }
</style>

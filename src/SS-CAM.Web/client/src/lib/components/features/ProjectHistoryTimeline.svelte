<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { ApiClient } from '$lib/services/api';
  import { getErrorMessage } from '$lib/copy';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface ProjectSnapshot {
    id: string;
    timestamp: string;
    trigger: string;
    actor: string;
    revision: number;
    status: string;
    note: string;
    sourceFiles?: Array<{
      name: string;
      sizeBytes: number;
      sizeFormatted: string;
      ext: string;
      modifiedAt?: string;
    }>;
  }

  interface Props {
    projectId: string;
    projectTitle?: string;
    onRollbackSuccess?: () => void;
  }

  let {
    projectId = '',
    projectTitle = '',
    onRollbackSuccess
  }: Props = $props();

  let snapshots = $state<ProjectSnapshot[]>([]);
  let isLoading = $state<boolean>(false);
  let isRollingBack = $state<string | null>(null);
  let isCapturing = $state<boolean>(false);
  let customNote = $state<string>('');
  let snapshotToRestore = $state<ProjectSnapshot | null>(null);
  let captureInputEl: HTMLInputElement | null = null;

  export function focusCaptureInput() {
    if (captureInputEl) {
      captureInputEl.focus();
    }
  }

  $effect(() => {
    if (projectId) {
      loadSnapshots();
    }
  });

  async function loadSnapshots() {
    if (!projectId) return;
    isLoading = true;
    try {
      const res = await ApiClient.getProjectSnapshots(projectId);
      snapshots = res.snapshots || [];
    } catch (err: any) {
      console.warn('[ProjectHistoryTimeline] Failed to load snapshots:', err.message);
    } finally {
      isLoading = false;
    }
  }

  async function handleCreateSnapshot() {
    if (!projectId) return;
    isCapturing = true;
    try {
      await ApiClient.createProjectSnapshot(projectId, {
        trigger: 'MANUAL_USER_SNAPSHOT',
        note: customNote.trim() || 'Manual studio milestone snapshot'
      });
      customNote = '';
      appState.addToast('Version snapshot captured.', 'success');
      await loadSnapshots();
    } catch (err: any) {
      appState.addToast(getErrorMessage(err, 'We couldn\'t capture a snapshot. Please try again.'), 'error');
    } finally {
      isCapturing = false;
    }
  }

  function handleRollback(snap: ProjectSnapshot) {
    if (!projectId || !snap.id) return;
    snapshotToRestore = snap;
  }

  async function confirmRestoreVersion() {
    if (!projectId || !snapshotToRestore) return;
    const snap = snapshotToRestore;
    isRollingBack = snap.id;
    try {
      const res = await ApiClient.rollbackProject(projectId, snap.id);
      appState.addToast(res.message || 'Restored earlier project version.', 'success');
      await loadSnapshots();
      if (onRollbackSuccess) onRollbackSuccess();
      snapshotToRestore = null;
    } catch (err: any) {
      appState.addToast(getErrorMessage(err, 'We couldn\'t restore this version. Please try again.'), 'error');
    } finally {
      isRollingBack = null;
    }
  }
</script>

<div class="history-timeline-root">
  <!-- Manual Snapshot Capture Bar -->
  <div class="capture-bar">
    <div class="capture-input-wrap">
      <input
        bind:this={captureInputEl}
        type="text"
        class="capture-input"
        placeholder="Add note for milestone (e.g. Pre-campaign client review copy)..."
        bind:value={customNote}
        onkeydown={(e) => { if (e.key === 'Enter') handleCreateSnapshot(); }}
        aria-label="Milestone snapshot note"
      />
    </div>
    <FluentButton
      appearance="cta"
      size="sm"
      loading={isCapturing}
      onclick={handleCreateSnapshot}
    >
      <FluentIcons name="camera" size={14} />
      <span style="margin-left: 6px;">Capture snapshot</span>
    </FluentButton>
  </div>

  <!-- Visual Milestone Tree -->
  <div class="tree-container">
    {#if isLoading}
      <div class="loading-box">
        <FluentIcons name="history" size={24} color="var(--brand-primary)" />
        <p style="margin-top: 8px;">Loading revision timeline...</p>
      </div>
    {:else if snapshots.length === 0}
      <div class="empty-box">
        <FluentIcons name="history" size={36} color="var(--text-tertiary)" />
        <p style="margin-top: 10px; font-weight: 600; color: var(--text-primary);">No historical snapshots captured yet.</p>
        <span class="empty-sub">Snapshots are automatically created during client decisions, file uploads, and milestone saves.</span>
      </div>
    {:else}
      <div class="milestones-list">
        {#each snapshots as snap, index}
          <div class="milestone-card {index === 0 ? 'is-latest' : ''}">
            <div class="milestone-indicator">
              <div class="circle-node">{snap.revision || 1}</div>
              {#if index < snapshots.length - 1}
                <div class="connector-line"></div>
              {/if}
            </div>

            <div class="milestone-content">
              <div class="milestone-top">
                <div class="rev-tags">
                  <span class="rev-badge">Rev {snap.revision || 1}</span>
                  <span class="status-pill status-{snap.status || 'in-progress'}">{snap.status || 'in-progress'}</span>
                  {#if index === 0}
                    <span class="latest-tag">CURRENT STATE</span>
                  {/if}
                </div>
                <span class="timestamp-meta">{new Date(snap.timestamp).toLocaleString()}</span>
              </div>

              <div class="milestone-note">"{snap.note || 'Milestone checkpoint'}"</div>

              <div class="milestone-meta-row">
                <span class="actor-tag">
                  <FluentIcons name="user" size={12} />
                  <span style="margin-left: 4px;">{snap.actor || 'Designer'}</span>
                </span>
                <span class="trigger-tag">
                  <FluentIcons name="bolt" size={12} />
                  <span style="margin-left: 4px;">{snap.trigger || 'SNAPSHOT'}</span>
                </span>
                <span class="snap-id-tag">{snap.id}</span>
              </div>

              {#if snap.sourceFiles && snap.sourceFiles.length > 0}
                <div class="source-files-box">
                  <div class="source-files-header">
                    <FluentIcons name="folder" size={12} color="var(--brand-primary)" />
                    <span>Snapshotted Design Assets ({snap.sourceFiles.length}):</span>
                  </div>
                  <div class="source-files-chips">
                    {#each snap.sourceFiles as sf}
                      <span class="source-file-chip" title="{sf.name} ({sf.sizeFormatted})">
                        <span class="file-ext-badge ext-{sf.ext.replace('.', '')}">{sf.ext.toUpperCase()}</span>
                        <span class="file-name">{sf.name}</span>
                        <span class="file-size">{sf.sizeFormatted}</span>
                      </span>
                    {/each}
                  </div>
                </div>
              {/if}

              {#if index !== 0}
                <div class="rollback-action-row">
                  <button
                    type="button"
                    class="rollback-btn"
                    disabled={isRollingBack === snap.id}
                    onclick={() => handleRollback(snap)}
                  >
                    <FluentIcons name="history" size={13} />
                    <span style="margin-left: 6px;">{isRollingBack === snap.id ? 'Restoring...' : 'Restore this revision'}</span>
                  </button>
                </div>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <div class="timeline-footer-note">
    <FluentIcons name="lock" size={13} color="var(--brand-primary)" />
    <span style="margin-left: 6px;">Pre-rollback safety backups are created automatically prior to any restoration.</span>
  </div>
</div>

<FluentDialog
  open={!!snapshotToRestore}
  title="Restore earlier version"
  confirmText="Restore version"
  confirmAppearance="primary"
  loading={!!isRollingBack}
  onConfirm={confirmRestoreVersion}
  onClose={() => { snapshotToRestore = null; }}
>
  {#if snapshotToRestore}
    <div style="padding: 6px 0;">
      <p style="margin: 0 0 10px 0; font-size: 14px; line-height: 1.5; color: var(--text-primary);">
        Are you sure you want to restore <strong>Rev {snapshotToRestore.revision || 'selected'}</strong> ({snapshotToRestore.id})?
      </p>
      <p style="margin: 0; font-size: 13px; line-height: 1.5; color: var(--text-secondary);">
        A backup copy of current files will be created automatically on the shared drive before restoring.
      </p>
    </div>
  {/if}
</FluentDialog>

<style>
  .history-timeline-root {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .capture-bar {
    display: flex;
    gap: 12px;
    align-items: center;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 8px);
    padding: 12px 16px;
  }

  .capture-input-wrap {
    flex: 1;
  }

  .capture-input {
    width: 100%;
    box-sizing: border-box;
    background: var(--bg-canvas, #FCFAF6);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-sm, 6px);
    padding: 10px 14px;
    color: var(--text-primary);
    font-size: 13px;
    outline: none;
    font-family: inherit;
    transition: border-color 0.15s;
  }
  .capture-input:focus {
    border-color: var(--brand-primary);
  }

  .tree-container {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .loading-box, .empty-box {
    text-align: center;
    padding: 48px 24px;
    color: var(--text-secondary);
    font-size: 13px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 8px);
  }

  .empty-sub {
    font-size: 12px;
    color: var(--text-tertiary);
    display: block;
    margin-top: 6px;
  }

  .milestones-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .milestone-card {
    display: flex;
    gap: 16px;
    position: relative;
  }

  .milestone-indicator {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 32px;
    flex-shrink: 0;
  }

  .circle-node {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--brand-primary, #043388);
    border: 2px solid var(--ss-azure, #21A1F7);
    color: #FFF;
    font-size: 11px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2;
  }

  .connector-line {
    flex: 1;
    width: 2px;
    background: var(--surface-card-border);
    margin: 4px 0;
    min-height: 48px;
  }

  .milestone-content {
    flex: 1;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md, 8px);
    padding: 14px 18px;
    margin-bottom: 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .milestone-card.is-latest .milestone-content {
    border-color: var(--brand-primary);
    background: color-mix(in srgb, var(--brand-primary) 4%, var(--surface-card));
  }

  .milestone-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
  }

  .rev-tags {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .rev-badge {
    font-size: 11px;
    font-weight: 800;
    background: var(--brand-primary, #043388);
    color: #FFF;
    padding: 2px 7px;
    border-radius: 4px;
  }

  .status-pill {
    font-size: 11px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 4px;
    text-transform: capitalize;
  }
  .status-pill.status-approved, .status-pill.status-done {
    background: var(--colorStatusSuccessBackground1, #ECFDF5);
    color: var(--colorStatusSuccessForeground1, #047857);
  }
  .status-pill.status-revision {
    background: var(--colorStatusDangerBackground1, #FEF2F2);
    color: var(--colorStatusDangerForeground1, #B91C1C);
  }
  .status-pill.status-in-progress, .status-pill.status-draft {
    background: var(--colorStatusWarningBackground1, #FFFBEB);
    color: var(--colorStatusWarningForeground1, #B45309);
  }

  .latest-tag {
    font-size: 9px;
    font-weight: 900;
    background: var(--colorStatusSuccessForeground1, #047857);
    color: #FFF;
    padding: 2px 6px;
    border-radius: 3px;
    letter-spacing: 0.5px;
  }

  .timestamp-meta {
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .milestone-note {
    font-size: 13.5px;
    color: var(--text-primary);
    font-weight: 600;
    font-style: italic;
  }

  .milestone-meta-row {
    display: flex;
    align-items: center;
    gap: 14px;
    font-size: 11.5px;
    color: var(--text-secondary);
    flex-wrap: wrap;
  }

  .actor-tag, .trigger-tag {
    display: inline-flex;
    align-items: center;
  }

  .snap-id-tag {
    font-family: var(--font-mono, monospace);
    font-size: 10.5px;
    color: var(--text-tertiary);
  }

  .source-files-box {
    margin-top: 6px;
    padding: 10px 12px;
    background: var(--bg-canvas, #FCFAF6);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-sm, 6px);
  }

  .source-files-header {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary);
    margin-bottom: 8px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .source-files-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .source-file-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 4px;
    padding: 3px 8px;
    font-size: 11.5px;
    color: var(--text-primary);
  }

  .file-ext-badge {
    font-size: 9px;
    font-weight: 800;
    padding: 1px 4px;
    border-radius: 3px;
    background: var(--brand-primary);
    color: #FFF;
  }
  .file-ext-badge.ext-psd { background: #31A8FF; color: #001E36; }
  .file-ext-badge.ext-ai { background: #FF9A00; color: #331500; }
  .file-ext-badge.ext-pdf { background: #EF4444; color: #FFF; }
  .file-ext-badge.ext-mp4, .file-ext-badge.ext-mov { background: #8B5CF6; color: #FFF; }

  .file-name {
    max-width: 160px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-weight: 500;
  }

  .file-size {
    font-size: 10.5px;
    color: var(--text-tertiary);
  }

  .rollback-action-row {
    margin-top: 8px;
    display: flex;
    justify-content: flex-end;
  }

  .rollback-btn {
    display: inline-flex;
    align-items: center;
    background: transparent;
    border: 1px solid var(--colorStatusDangerBorder1, #FECACA);
    color: var(--colorStatusDangerForeground1, #B91C1C);
    padding: 6px 12px;
    border-radius: var(--radius-sm, 6px);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
    font-family: inherit;
  }
  .rollback-btn:hover {
    background: var(--colorStatusDangerBackground1, #FEF2F2);
  }

  .timeline-footer-note {
    display: flex;
    align-items: center;
    font-size: 12px;
    color: var(--text-tertiary);
    padding: 4px 0;
  }
</style>

<script lang="ts">
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import ProjectHistoryTimeline from '$lib/components/features/ProjectHistoryTimeline.svelte';

  interface Props {
    open?: boolean;
    projectId?: string;
    projectTitle?: string;
    onClose?: () => void;
    onRollbackSuccess?: () => void;
  }

  let {
    open = $bindable(false),
    projectId = '',
    projectTitle = '',
    onClose,
    onRollbackSuccess
  }: Props = $props();

  function closeModal() {
    open = false;
    if (onClose) onClose();
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="timeline-backdrop" onclick={(e) => { if (e.target === e.currentTarget) closeModal(); }}>
    <div class="timeline-modal">
      <div class="timeline-header">
        <div class="header-left">
          <div class="timeline-icon-badge">
            <FluentIcons name="history" size={20} color="var(--brand-primary)" />
          </div>
          <div>
            <h2 class="modal-title">Creative Version Timeline &amp; Rollback</h2>
            <p class="modal-sub">Audit-backed revision milestones for <b>{projectTitle || projectId}</b>.</p>
          </div>
        </div>
        <button class="close-btn" onclick={closeModal} title="Close Modal" aria-label="Close Modal">
          <FluentIcons name="close" size={16} />
        </button>
      </div>

      <div class="timeline-body">
        <ProjectHistoryTimeline
          {projectId}
          {projectTitle}
          onRollbackSuccess={() => {
            if (onRollbackSuccess) onRollbackSuccess();
          }}
        />
      </div>

      <div class="timeline-footer">
        <FluentButton appearance="secondary" onclick={closeModal}>Close</FluentButton>
      </div>
    </div>
  </div>
{/if}

<style>
  .timeline-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1960;
    padding: 20px;
    animation: fadeIn 0.15s ease-out;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: scale(0.98); }
    to { opacity: 1; transform: scale(1); }
  }

  .timeline-modal {
    width: 95%;
    max-width: 820px;
    height: 85vh;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg, 12px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: var(--shadow-28);
  }

  .timeline-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }

  .header-left { display: flex; align-items: center; gap: 12px; }
  .timeline-icon-badge {
    width: 36px;
    height: 36px;
    border-radius: var(--radius-sm, 6px);
    background: var(--bg-canvas);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .modal-title { font-size: 16px; font-weight: 700; color: var(--text-primary); margin: 0; }
  .modal-sub { font-size: 12px; color: var(--text-secondary); margin: 2px 0 0 0; }

  .close-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
    padding: 8px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .close-btn:hover { color: var(--text-primary); background: var(--bg-canvas); }

  .timeline-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .timeline-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding: 12px 20px;
    border-top: 1px solid var(--surface-card-border);
    background: var(--surface-card);
  }
</style>

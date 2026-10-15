<script lang="ts">
  import type { Snippet } from 'svelte';
  import FluentButton from './FluentButton.svelte';
  import FluentIcons from './FluentIcons.svelte';

  interface Props {
    open?: boolean;
    title?: string;
    confirmText?: string;
    cancelText?: string;
    confirmAppearance?: 'primary' | 'danger' | 'success';
    loading?: boolean;
    onConfirm?: () => Promise<void> | void;
    onClose?: () => void;
    children?: Snippet;
    footer?: Snippet;
  }

  let {
    open = $bindable(false),
    title = 'Dialog',
    confirmText = 'Confirm',
    cancelText = 'Cancel',
    confirmAppearance = 'primary',
    loading = false,
    onConfirm,
    onClose,
    children,
    footer
  }: Props = $props();

  let dialogElement: HTMLDivElement | null = $state(null);
  let previousActiveElement: HTMLElement | null = $state(null);
  const titleId = `dialog-title-${Math.random().toString(36).slice(2, 9)}`;

  $effect(() => {
    if (open) {
      previousActiveElement = (typeof document !== 'undefined' ? document.activeElement : null) as HTMLElement | null;
      setTimeout(() => {
        if (dialogElement) {
          const focusable = dialogElement.querySelectorAll<HTMLElement>(
            'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
          );
          if (focusable.length > 0) {
            focusable[0].focus();
          } else {
            dialogElement.focus();
          }
        }
      }, 40);
    } else if (previousActiveElement) {
      previousActiveElement.focus();
      previousActiveElement = null;
    }
  });

  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget && onClose) {
      onClose();
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (!open) return;
    if (e.key === 'Escape' && onClose) {
      e.stopPropagation();
      onClose();
      return;
    }

    if (e.key === 'Tab' && dialogElement) {
      const focusable = dialogElement.querySelectorAll<HTMLElement>(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last.focus();
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-backdrop" onclick={handleBackdropClick}>
    <div
      bind:this={dialogElement}
      class="modal-dialog"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      tabindex="-1"
    >
      <div class="modal-header">
        <h3 id={titleId} class="modal-title">{title}</h3>
        <button class="close-btn" onclick={onClose} aria-label="Close dialog" type="button">
          <FluentIcons name="close" size={16} />
        </button>
      </div>

      <div class="modal-body">
        {#if children}
          {@render children()}
        {/if}
      </div>

      <div class="modal-footer">
        {#if footer}
          {@render footer()}
        {:else}
          <FluentButton appearance="secondary" onclick={onClose}>{cancelText}</FluentButton>
          {#if onConfirm}
            <FluentButton appearance={confirmAppearance} {loading} onclick={onConfirm}>{confirmText}</FluentButton>
          {/if}
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: var(--glass-blur);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    animation: fadeIn 0.15s ease-out;
  }

  .modal-dialog {
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-xl);
    width: 90%;
    max-width: 540px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: scaleUp 0.15s ease-out;
    outline: none;
  }
  .modal-dialog:focus-visible {
    outline: 2px solid var(--ss-azure);
    outline-offset: 2px;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--surface-card-border);
  }

  .modal-title {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .close-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
    min-width: 44px;
    min-height: 44px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-md);
    transition: all var(--transition-fast);
  }
  .close-btn:hover {
    background: var(--surface-card-hover);
    color: var(--text-primary);
  }
  .close-btn:focus-visible {
    outline: var(--focus-outline, 2px solid var(--ss-azure));
    outline-offset: 2px;
  }

  .modal-body {
    padding: 20px;
    overflow-y: auto;
    font-size: 13.5px;
    color: var(--text-secondary);
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    border-top: 1px solid var(--surface-card-border);
    background: var(--surface-card-subtle);
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes scaleUp {
    from { transform: scale(0.95); opacity: 0; }
    to { transform: scale(1); opacity: 1; }
  }
</style>

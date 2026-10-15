<script lang="ts">
  import FluentButton from './FluentButton.svelte';
  import FluentIcons from './FluentIcons.svelte';

  interface Props {
    title?: string;
    message: string;
    onRetry?: () => void | Promise<void>;
    retryLabel?: string;
    isRetrying?: boolean;
    dismissible?: boolean;
    onDismiss?: () => void;
  }

  let {
    title = 'Unable to load content',
    message,
    onRetry,
    retryLabel = 'Retry',
    isRetrying = false,
    dismissible = false,
    onDismiss
  }: Props = $props();

  let localRetrying = $state(false);

  async function handleRetry() {
    if (!onRetry || isRetrying || localRetrying) return;
    localRetrying = true;
    try {
      await onRetry();
    } finally {
      localRetrying = false;
    }
  }
</script>

<div class="fluent-error-banner" role="alert">
  <div class="banner-icon">
    <FluentIcons name="warning" size={18} color="var(--color-danger, #EF4444)" />
  </div>

  <div class="banner-body">
    {#if title}
      <h4 class="banner-title">{title}</h4>
    {/if}
    <p class="banner-message">{message}</p>
  </div>

  <div class="banner-actions">
    {#if onRetry}
      <FluentButton
        appearance="secondary"
        size="sm"
        loading={isRetrying || localRetrying}
        onclick={handleRetry}
      >
        <FluentIcons name="refresh" size={13} />
        <span style="margin-left: 6px;">{retryLabel}</span>
      </FluentButton>
    {/if}

    {#if dismissible && onDismiss}
      <button
        type="button"
        class="banner-dismiss-btn"
        onclick={onDismiss}
        aria-label="Dismiss alert"
      >
        <FluentIcons name="close" size={13} />
      </button>
    {/if}
  </div>
</div>

<style>
  .fluent-error-banner {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 12px 16px;
    background: rgba(239, 68, 68, 0.08);
    border: 1px solid rgba(239, 68, 68, 0.28);
    border-radius: 8px;
    margin-bottom: 16px;
    color: var(--color-text-primary, #F8FAFC);
    transition: all 0.2s ease;
  }

  .banner-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .banner-body {
    flex: 1;
    min-width: 0;
  }

  .banner-title {
    margin: 0 0 2px 0;
    font-size: 13px;
    font-weight: 600;
    color: #FCA5A5;
    line-height: 1.3;
  }

  .banner-message {
    margin: 0;
    font-size: 12.5px;
    color: #E2E8F0;
    line-height: 1.4;
    word-break: break-word;
  }

  .banner-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
  }

  .banner-dismiss-btn {
    background: transparent;
    border: none;
    color: #94A3B8;
    cursor: pointer;
    padding: 6px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.15s ease, color 0.15s ease;
  }

  .banner-dismiss-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: #F8FAFC;
  }
</style>

<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    appearance?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'success' | 'cta';
    size?: 'sm' | 'md' | 'lg' | 'touch';
    disabled?: boolean;
    loading?: boolean;
    type?: 'button' | 'submit' | 'reset';
    onclick?: (e: MouseEvent) => void;
    title?: string;
    style?: string;
    class?: string;
    children?: Snippet;
  }

  let {
    appearance = 'secondary',
    size = 'md',
    disabled = false,
    loading = false,
    type = 'button',
    onclick,
    title,
    style = '',
    class: className = '',
    children
  }: Props = $props();
</script>

<button
  {type}
  class="fluent-btn btn-{appearance} btn-{size} {className}"
  {disabled}
  {title}
  {style}
  {onclick}
>
  {#if loading}
    <span class="spinner"></span>
  {/if}
  {#if children}
    {@render children()}
  {/if}
</button>

<style>
  .fluent-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    font-family: var(--font-family);
    font-weight: 600;
    border-radius: var(--radius-md);
    cursor: pointer;
    border: 1px solid transparent;
    transition: all var(--transition-fast);
    user-select: none;
    text-decoration: none;
    white-space: nowrap;
  }

  .fluent-btn:hover:not(:disabled) {
    transform: translateY(-1px);
  }

  .fluent-btn:active:not(:disabled) {
    transform: scale(0.98);
  }

  .fluent-btn:focus-visible {
    outline: var(--focus-outline, 2px solid var(--ss-azure));
    outline-offset: 2px;
  }

  /* Sizes (Minimum 44px interactive target for md/lg; 36px for sm; 52px for touch) */
  .btn-sm { min-height: 36px; padding: 6px 12px; font-size: 12px; }
  .btn-md { min-height: 44px; padding: 10px 18px; font-size: 13.5px; }
  .btn-lg { min-height: 48px; padding: 12px 24px; font-size: 14.5px; }
  .btn-touch { min-height: 52px; min-width: 52px; padding: 12px 22px; font-size: 15px; }

  /* High-Converting CTA (Banana #FCE53D / Neutral Black #1C1C1C) */
  .btn-cta {
    background: var(--cta-bg, #FCE53D);
    color: var(--cta-fg, #1C1C1C);
    border-color: var(--cta-bg, #FCE53D);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
    font-weight: 700;
  }
  .btn-cta:hover:not(:disabled) {
    background: var(--cta-hover, #FADB14);
    border-color: var(--cta-hover, #FADB14);
    box-shadow: 0 4px 10px rgba(252, 229, 61, 0.35);
  }

  /* 10% Accent Layer */
  .btn-primary {
    background: var(--brand-primary);
    color: var(--text-inverted);
    border-color: var(--brand-primary);
    box-shadow: var(--shadow-sm);
  }
  .btn-primary:hover:not(:disabled) {
    background: var(--brand-secondary);
    box-shadow: var(--brand-glow);
  }

  /* 30% Secondary Layer */
  .btn-secondary {
    background: var(--surface-card);
    color: var(--text-primary);
    border-color: var(--surface-card-border);
  }
  .btn-secondary:hover:not(:disabled) {
    background: var(--surface-card-subtle);
    border-color: var(--brand-accent);
    color: var(--brand-accent);
  }

  .btn-ghost {
    background: transparent;
    color: var(--text-secondary);
    border-color: transparent;
  }
  .btn-ghost:hover:not(:disabled) {
    background: var(--surface-card-hover);
    color: var(--text-primary);
  }

  .btn-danger {
    background: var(--color-danger-bg);
    color: var(--color-danger);
    border-color: var(--color-danger-border);
  }
  .btn-danger:hover:not(:disabled) {
    background: var(--color-danger);
    color: #FFFFFF;
  }

  .btn-success {
    background: var(--color-success-bg);
    color: var(--color-success);
    border-color: var(--color-success-border);
  }
  .btn-success:hover:not(:disabled) {
    background: var(--color-success);
    color: #FFFFFF;
  }

  .fluent-btn:disabled {
    opacity: var(--disabled-opacity, 0.45);
    cursor: not-allowed;
    pointer-events: none;
  }

  .spinner {
    width: 12px;
    height: 12px;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>

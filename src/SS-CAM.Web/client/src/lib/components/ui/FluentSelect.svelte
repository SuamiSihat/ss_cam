<script lang="ts">
  interface OptionItem {
    value: string;
    label: string;
  }

  interface Props {
    value?: string;
    options?: (OptionItem | string)[];
    label?: string;
    disabled?: boolean;
    onchange?: (e: Event) => void;
    style?: string;
    class?: string;
  }

  let {
    value = $bindable(''),
    options = [],
    label,
    disabled = false,
    onchange,
    style = '',
    class: className = ''
  }: Props = $props();
</script>

<div class="fluent-select-wrapper {className}" {style}>
  {#if label}
    <label class="fluent-label">{label}</label>
  {/if}
  <select class="fluent-select" bind:value {disabled} {onchange}>
    {#each options as opt}
      {#if typeof opt === 'string'}
        <option value={opt}>{opt}</option>
      {:else}
        <option value={opt.value}>{opt.label}</option>
      {/if}
    {/each}
  </select>
</div>

<style>
  .fluent-select-wrapper {
    display: flex;
    flex-direction: column;
    gap: 4px;
    width: 100%;
  }

  .fluent-label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary);
    letter-spacing: normal;
  }

  .fluent-select {
    width: 100%;
    min-height: 44px;
    padding: 10px 14px;
    font-family: var(--font-family);
    font-size: 13.5px;
    line-height: 1.4;
    color: var(--text-primary);
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: all var(--transition-fast);
  }

  .fluent-select:focus {
    outline: none;
    border-color: var(--brand-accent);
    box-shadow: var(--focus-ring);
  }

  .fluent-select:focus-visible {
    outline: var(--focus-outline, 2px solid var(--ss-azure));
    outline-offset: 2px;
  }

  .fluent-select:disabled {
    background: var(--surface-card-subtle);
    color: var(--text-tertiary);
    opacity: var(--disabled-opacity, 0.45);
    cursor: not-allowed;
  }
</style>

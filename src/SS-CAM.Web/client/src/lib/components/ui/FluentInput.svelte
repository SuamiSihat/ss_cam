<script lang="ts">
  interface Props {
    value?: string | number;
    label?: string;
    placeholder?: string;
    type?: string;
    disabled?: boolean;
    readonly?: boolean;
    required?: boolean;
    error?: string;
    autocomplete?: string;
    oninput?: (e: Event) => void;
    onchange?: (e: Event) => void;
    style?: string;
    class?: string;
  }

  let {
    value = $bindable(''),
    label,
    placeholder = '',
    type = 'text',
    disabled = false,
    readonly = false,
    required = false,
    error,
    autocomplete,
    oninput,
    onchange,
    style = '',
    class: className = ''
  }: Props = $props();
</script>

<div class="fluent-input-wrapper {className}" {style}>
  {#if label}
    <label class="fluent-label">
      {label}
      {#if required}<span class="req-star">*</span>{/if}
    </label>
  {/if}
  <input
    {type}
    class="fluent-input"
    class:has-error={!!error}
    {placeholder}
    {disabled}
    {readonly}
    {autocomplete}
    bind:value
    {oninput}
    {onchange}
  />
  {#if error}
    <span class="fluent-error-msg">{error}</span>
  {/if}
</div>

<style>
  .fluent-input-wrapper {
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

  .req-star {
    color: var(--color-danger);
    margin-left: 2px;
  }

  .fluent-input {
    width: 100%;
    min-height: 44px;
    padding: 10px 14px;
    font-family: var(--font-family);
    font-size: 13.5px;
    color: var(--text-primary);
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-md);
    transition: all var(--transition-fast);
  }

  .fluent-input:focus {
    outline: none;
    border-color: var(--brand-accent);
    box-shadow: var(--focus-ring);
  }

  .fluent-input:focus-visible {
    outline: var(--focus-outline, 2px solid var(--ss-azure));
    outline-offset: 2px;
  }

  .fluent-input:disabled {
    background: var(--surface-card-subtle);
    color: var(--text-tertiary);
    opacity: var(--disabled-opacity, 0.45);
    cursor: not-allowed;
  }

  .fluent-input.has-error {
    border-color: var(--color-danger);
  }

  .fluent-error-msg {
    font-size: 11.5px;
    color: var(--color-danger);
    font-weight: 600;
  }
</style>

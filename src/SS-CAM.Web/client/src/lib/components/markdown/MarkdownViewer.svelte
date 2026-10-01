<script lang="ts">
  import { MarkdownService, type MarkdownToken } from '$lib/services/markdown';

  // MermaidViewer is loaded lazily — only when the content actually contains
  // a mermaid block. This keeps the 3MB mermaid bundle out of the initial load.
  // Vite will code-split it into a separate async chunk automatically.
  let MermaidViewer: any = $state(null);
  let mermaidLoadError = $state<string | null>(null);

  interface Props {
    content: string;
    class?: string;
    projectId?: string;
  }

  let { content, class: className = '', projectId = '' }: Props = $props();

  // Tokenize content into standard markdown vs Mermaid code blocks
  let tokens = $derived.by<MarkdownToken[]>(() => {
    if (!content) return [];
    return MarkdownService.tokenize(content);
  });

  // Only load MermaidViewer when content actually has a mermaid block
  const hasMermaid = $derived(tokens.some(t => t.type === 'code' && t.lang === 'mermaid'));

  $effect(() => {
    if (hasMermaid && !MermaidViewer) {
      import('./MermaidViewer.svelte')
        .then(mod => { MermaidViewer = mod.default; })
        .catch(err => {
          mermaidLoadError = 'Failed to load diagram renderer.';
          console.warn('[MarkdownViewer] MermaidViewer lazy load failed:', err);
        });
    }
  });
</script>

<div class="markdown-body {className}">
  {#if !content || content.trim() === ''}
    <div class="empty-markdown">
      <i>No Markdown content provided.</i>
    </div>
  {:else}
    {#each tokens as token}
      {#if token.type === 'code' && token.lang === 'mermaid'}
        {#if MermaidViewer}
          <MermaidViewer chartCode={token.text || ''} />
        {:else if mermaidLoadError}
          <div class="mermaid-load-err">{mermaidLoadError}</div>
        {:else}
          <!-- Skeleton while MermaidViewer chunk loads (~1-2s on first hit) -->
          <div class="mermaid-loading-placeholder" aria-hidden="true">
            <div class="mermaid-skel-badge">Mermaid Diagram</div>
            <div class="mermaid-skel-bar"></div>
            <div class="mermaid-skel-bar short"></div>
          </div>
        {/if}
      {:else}
        <!-- Render sanitized standard markdown block -->
        <!-- eslint-disable-next-line svelte/no-at-html-tags -->
        {@html MarkdownService.renderToHtml(token.raw || '', projectId)}
      {/if}
    {/each}
  {/if}
</div>

<style>
  .empty-markdown {
    color: var(--text-tertiary);
    font-size: 13px;
    padding: 12px 0;
  }

  /* Placeholder shown while the MermaidViewer chunk is fetching (~first render only) */
  .mermaid-loading-placeholder {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg);
    padding: 16px 18px;
    margin: 18px 0;
    min-height: 80px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .mermaid-skel-badge {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-tertiary);
  }

  .mermaid-skel-bar {
    height: 12px;
    border-radius: 4px;
    width: 70%;
    background: linear-gradient(
      90deg,
      var(--surface-card-subtle) 25%,
      var(--surface-card-hover, #E8EDF2) 50%,
      var(--surface-card-subtle) 75%
    );
    background-size: 200% 100%;
    animation: mermaidShimmer 1.6s ease-in-out infinite;
  }

  .mermaid-skel-bar.short { width: 45%; }

  @keyframes mermaidShimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  .mermaid-load-err {
    font-size: 12px;
    color: var(--color-danger);
    padding: 8px 0;
  }
</style>
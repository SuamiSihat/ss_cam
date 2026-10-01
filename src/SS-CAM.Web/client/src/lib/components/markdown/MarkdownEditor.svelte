<script lang="ts">
  import MarkdownViewer from './MarkdownViewer.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';

  interface Props {
    value?: string;
    placeholder?: string;
    onSave?: (newContent: string) => Promise<void> | void;
    readonly?: boolean;
    title?: string;
    saveLabel?: string;
  }

  let {
    value = $bindable(''),
    placeholder = 'Write Markdown document, checklist (- [ ]), or diagrams (```mermaid)...',
    onSave,
    readonly = false,
    title = '',
    saveLabel = 'Save Document'
  }: Props = $props();

  let mode = $state<'split' | 'preview' | 'source'>('preview');
  let isSaving = $state<boolean>(false);
  let isFullscreen = $state<boolean>(false);
  let textareaEl = $state<HTMLTextAreaElement | null>(null);

  let showHeadingMenu = $state<boolean>(false);
  let showDiagramMenu = $state<boolean>(false);
  let showCalloutMenu = $state<boolean>(false);

  // Statistics derived
  const wordCount = $derived.by(() => {
    return (value || '').trim().split(/\s+/).filter(Boolean).length;
  });

  const charCount = $derived((value || '').length);
  const readingTime = $derived(Math.max(1, Math.ceil(wordCount / 200)));

  async function handleSave() {
    if (!onSave) return;
    isSaving = true;
    try {
      await onSave(value);
    } finally {
      isSaving = false;
    }
  }

  function wrapSelection(prefix: string, suffix: string = prefix, defaultPlaceholder: string = 'text') {
    if (readonly || !textareaEl) {
      value += `${prefix}${defaultPlaceholder}${suffix}`;
      return;
    }

    const start = textareaEl.selectionStart;
    const end = textareaEl.selectionEnd;
    const selected = value.substring(start, end) || defaultPlaceholder;
    const replacement = `${prefix}${selected}${suffix}`;

    value = value.substring(0, start) + replacement + value.substring(end);

    setTimeout(() => {
      if (textareaEl) {
        textareaEl.focus();
        textareaEl.setSelectionRange(start + prefix.length, start + prefix.length + selected.length);
      }
    }, 10);
  }

  function insertBlock(block: string) {
    if (readonly || !textareaEl) {
      value += `\n${block}\n`;
      return;
    }
    const start = textareaEl.selectionStart;
    const end = textareaEl.selectionEnd;
    const before = value.substring(0, start);
    const after = value.substring(end);
    const needsLeadingNewline = before.length > 0 && !before.endsWith('\n\n');
    const prefix = needsLeadingNewline ? '\n\n' : '';

    value = before + prefix + block + '\n\n' + after;

    setTimeout(() => {
      if (textareaEl) {
        textareaEl.focus();
        const newPos = start + prefix.length + block.length + 2;
        textareaEl.setSelectionRange(newPos, newPos);
      }
    }, 10);
  }

  function insertMermaid(type: 'flow' | 'pie' | 'sequence' | 'timeline' | 'architecture') {
    let code = '';
    if (type === 'flow') {
      code = `\`\`\`mermaid\nflowchart TD\n  Brief[Creative Brief] --> Concept[Visual Concept]\n  Concept --> Review{Art Director Review}\n  Review -->|Approved| Master[Final Production Assets]\n  Review -->|Revision Required| Concept\n\`\`\``;
    } else if (type === 'pie') {
      code = `\`\`\`mermaid\npie title Deliverable Media Mix\n  "Packaging Dielines" : 40\n  "Social Media Ads" : 35\n  "3D Render Assets" : 25\n\`\`\``;
    } else if (type === 'sequence') {
      code = `\`\`\`mermaid\nsequenceDiagram\n  autonumber\n  Designer->>Manager: Submit Deliverable (v1)\n  Manager-->>Designer: Request Bleed Correction\n  Designer->>Manager: Submit Master Artwork (v2)\n  Manager->>NAS: Sign-Off & Archive\n\`\`\``;
    } else if (type === 'timeline') {
      code = `\`\`\`mermaid\ntimeline\n  title Campaign Creative Milestones\n  Week 1 : Visual Moodboard & Angle\n  Week 2 : Dielines & Product Renders\n  Week 3 : Video Scripts & Copywriting\n  Week 4 : Final Master Exports & Handoff\n\`\`\``;
    } else if (type === 'architecture') {
      code = `\`\`\`mermaid\nflowchart LR\n  subgraph SS-Master [Brand Repository]\n    Core[Core Asset Catalog]\n    NAS[(Synology Storage)]\n  end\n  Core --> Figma[Figma Vectors]\n  Core --> Adobe[Adobe InDesign / AI]\n  Core --> Web[Creative Web Portal]\n\`\`\``;
    }
    insertBlock(code);
  }

  function insertTable() {
    const table = `| Item / Feature | Specification / Requirement | Status |
| :--- | :--- | :--- |
| **Packaging Box** | CMYK 300 DPI, Matt Lamination + Gold Foil | \`Ready\` |
| **Bottle Label** | 80mm x 45mm Waterproof Vinyl | \`In-Progress\` |
| **Social Carousel** | 1080 x 1350px (4:5 Ratio), 5 Slides | \`Pending\` |`;
    insertBlock(table);
  }

  function insertLink() {
    wrapSelection('[', '](https://)', 'Link text');
  }

  function insertImage() {
    wrapSelection('![', '](https://)', 'Image description');
  }

  function insertAttachment() {
    wrapSelection('[Attachment: ', '](path_or_url)', 'Document Name');
  }

  function insertCallout(type: 'NOTE' | 'IMPORTANT' | 'WARNING' | 'TIP') {
    const callout = `> [!${type}]\n> Enter critical campaign requirements, compliance checks, or brand guidelines here.`;
    insertBlock(callout);
  }

  function insertHorizontalRule() {
    insertBlock('---');
  }

  function handleKeyDown(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      handleSave();
      return;
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
      e.preventDefault();
      wrapSelection('**', '**', 'bold text');
      return;
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 'i') {
      e.preventDefault();
      wrapSelection('*', '*', 'italic text');
      return;
    }
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      insertLink();
      return;
    }
    if (e.key === 'Tab' && textareaEl) {
      e.preventDefault();
      const start = textareaEl.selectionStart;
      const end = textareaEl.selectionEnd;
      value = value.substring(0, start) + '  ' + value.substring(end);
      setTimeout(() => {
        if (textareaEl) textareaEl.setSelectionRange(start + 2, start + 2);
      }, 0);
      return;
    }
    if (e.key === 'Escape') {
      showHeadingMenu = false;
      showDiagramMenu = false;
      showCalloutMenu = false;
      if (isFullscreen) isFullscreen = false;
    }
  }

  function closeAllMenus() {
    showHeadingMenu = false;
    showDiagramMenu = false;
    showCalloutMenu = false;
  }
</script>

<svelte:window onclick={closeAllMenus} />

<div class="markdown-editor-wrapper" class:fullscreen-mode={isFullscreen}>
  <!-- Top Fluent 2 Command Toolbar -->
  <div class="editor-toolbar" role="toolbar" aria-label="Markdown formatting tools">
    <div class="toolbar-primary-row">
      <!-- Group 1: Document Badge -->
      {#if title}
        <div class="toolbar-doc-badge">
          <svg class="doc-icon" viewBox="0 0 20 20" fill="currentColor" width="13" height="13">
            <path d="M4 3a2 2 0 0 1 2-2h5.586a1 1 0 0 1 .707.293l4.414 4.414a1 1 0 0 1 .293.707V17a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V3zm7 0v4a1 1 0 0 0 1 1h4L11 3z"/>
          </svg>
          <span class="doc-title-text">{title}</span>
        </div>
        <span class="tool-divider" aria-hidden="true"></span>
      {/if}

      <!-- Group 2: Typography Formatting -->
      <div class="toolbar-button-group">
        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('**', '**', 'bold text')}
          title="Bold (Ctrl+B)"
          aria-label="Bold"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('*', '*', 'italic text')}
          title="Italic (Ctrl+I)"
          aria-label="Italic"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('~~', '~~', 'strikethrough')}
          title="Strikethrough"
          aria-label="Strikethrough"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M16 4H9a3 3 0 0 0-2.83 4"/><path d="M14 12a4 4 0 0 1 0 8H6"/><line x1="4" y1="12" x2="20" y2="12"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('`', '`', 'code')}
          title="Inline Code"
          aria-label="Inline Code"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>
          </svg>
        </button>
      </div>

      <span class="tool-divider" aria-hidden="true"></span>

      <!-- Group 3: Headings & Hierarchy -->
      <div class="toolbar-button-group">
        <!-- Heading Dropdown -->
        <div class="dropdown-wrapper">
          <button
            type="button"
            class="tool-dropdown-btn"
            class:active={showHeadingMenu}
            onclick={(e) => { e.stopPropagation(); showHeadingMenu = !showHeadingMenu; showDiagramMenu = false; showCalloutMenu = false; }}
            title="Headings"
            aria-haspopup="menu"
            aria-expanded={showHeadingMenu}
          >
            <span class="btn-text-badge">H▾</span>
          </button>
          {#if showHeadingMenu}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="dropdown-menu" onclick={(e) => e.stopPropagation()} role="menu">
              <button type="button" class="dropdown-item" onclick={() => { wrapSelection('# ', '', 'Heading 1'); showHeadingMenu = false; }} role="menuitem">
                <span class="item-badge">H1</span>
                <span class="item-name">Page Title (H1)</span>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { wrapSelection('## ', '', 'Heading 2'); showHeadingMenu = false; }} role="menuitem">
                <span class="item-badge">H2</span>
                <span class="item-name">Section Title (H2)</span>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { wrapSelection('### ', '', 'Heading 3'); showHeadingMenu = false; }} role="menuitem">
                <span class="item-badge">H3</span>
                <span class="item-name">Sub-section (H3)</span>
              </button>
            </div>
          {/if}
        </div>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('- ', '', 'List item')}
          title="Bullet List"
          aria-label="Bullet List"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/>
            <line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('1. ', '', 'Numbered item')}
          title="Numbered List"
          aria-label="Numbered List"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/>
            <path d="M4 6h1v4"/><path d="M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => insertBlock('- [ ] New deliverable task')}
          title="Checklist Item (- [ ])"
          aria-label="Checklist Item"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="4" width="18" height="16" rx="3"/><polyline points="9 12 11 14 15 10"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={() => wrapSelection('> ', '', 'Quote text')}
          title="Blockquote"
          aria-label="Blockquote"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
            <path d="M6 17h3l2-4V7H5v6h3l-2 4zm8 0h3l2-4V7h-6v6h3l-2 4z"/>
          </svg>
        </button>
      </div>

      <span class="tool-divider" aria-hidden="true"></span>

      <!-- Group 4: Inserts & Media -->
      <div class="toolbar-button-group">
        <button
          type="button"
          class="tool-btn"
          onclick={insertTable}
          title="Insert Table Matrix"
          aria-label="Insert Table"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/><path d="M9 3v18"/><path d="M15 3v18"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={insertLink}
          title="Insert Hyperlink (Ctrl+K)"
          aria-label="Insert Link"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={insertImage}
          title="Insert Image Embed"
          aria-label="Insert Image"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={insertAttachment}
          title="Insert File Attachment"
          aria-label="Insert Attachment"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
          </svg>
        </button>

        <button
          type="button"
          class="tool-btn"
          onclick={insertHorizontalRule}
          title="Horizontal Divider"
          aria-label="Horizontal Divider"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
            <line x1="3" y1="12" x2="21" y2="12"/>
          </svg>
        </button>
      </div>

      <span class="tool-divider" aria-hidden="true"></span>

      <!-- Group 5: Advanced Creative Studio Tools (Callouts & Diagrams) -->
      <div class="toolbar-button-group">
        <!-- Callout Dropdown -->
        <div class="dropdown-wrapper">
          <button
            type="button"
            class="tool-dropdown-btn"
            class:active={showCalloutMenu}
            onclick={(e) => { e.stopPropagation(); showCalloutMenu = !showCalloutMenu; showDiagramMenu = false; showHeadingMenu = false; }}
            title="Insert Callout Alert Box"
            aria-haspopup="menu"
            aria-expanded={showCalloutMenu}
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
            </svg>
            <span class="dropdown-label">Callout</span>
            <span class="arrow-glyph" aria-hidden="true">▾</span>
          </button>
          {#if showCalloutMenu}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="dropdown-menu callout-menu" onclick={(e) => e.stopPropagation()} role="menu">
              <button type="button" class="dropdown-item callout-item note" onclick={() => { insertCallout('NOTE'); showCalloutMenu = false; }} role="menuitem">
                <span class="callout-dot note"></span>
                <div class="item-info">
                  <span class="item-name">Note Callout</span>
                  <span class="item-sub">Information &amp; design specs</span>
                </div>
              </button>
              <button type="button" class="dropdown-item callout-item important" onclick={() => { insertCallout('IMPORTANT'); showCalloutMenu = false; }} role="menuitem">
                <span class="callout-dot important"></span>
                <div class="item-info">
                  <span class="item-name">Important</span>
                  <span class="item-sub">Crucial campaign requirements</span>
                </div>
              </button>
              <button type="button" class="dropdown-item callout-item tip" onclick={() => { insertCallout('TIP'); showCalloutMenu = false; }} role="menuitem">
                <span class="callout-dot tip"></span>
                <div class="item-info">
                  <span class="item-name">Tip &amp; Best Practice</span>
                  <span class="item-sub">Art direction advice &amp; techniques</span>
                </div>
              </button>
              <button type="button" class="dropdown-item callout-item warning" onclick={() => { insertCallout('WARNING'); showCalloutMenu = false; }} role="menuitem">
                <span class="callout-dot warning"></span>
                <div class="item-info">
                  <span class="item-name">Warning</span>
                  <span class="item-sub">Compliance &amp; risk flags</span>
                </div>
              </button>
            </div>
          {/if}
        </div>

        <!-- Mermaid Diagram Dropdown -->
        <div class="dropdown-wrapper">
          <button
            type="button"
            class="tool-dropdown-btn"
            class:active={showDiagramMenu}
            onclick={(e) => { e.stopPropagation(); showDiagramMenu = !showDiagramMenu; showCalloutMenu = false; showHeadingMenu = false; }}
            title="Insert Interactive Mermaid Diagram"
            aria-haspopup="menu"
            aria-expanded={showDiagramMenu}
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="3" width="6" height="6" rx="1"/><rect x="15" y="15" width="6" height="6" rx="1"/><rect x="15" y="3" width="6" height="6" rx="1"/>
              <path d="M6 9v9h9"/><path d="M9 6h6"/>
            </svg>
            <span class="dropdown-label">Diagram</span>
            <span class="arrow-glyph" aria-hidden="true">▾</span>
          </button>
          {#if showDiagramMenu}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div class="dropdown-menu diagram-menu" onclick={(e) => e.stopPropagation()} role="menu">
              <button type="button" class="dropdown-item" onclick={() => { insertMermaid('flow'); showDiagramMenu = false; }} role="menuitem">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="6" height="6" rx="1"/><path d="M6 9v6"/><rect x="3" y="15" width="6" height="6" rx="1"/></svg>
                <div class="item-info">
                  <span class="item-name">Workflow Flowchart</span>
                  <span class="item-sub">Production pipelines &amp; steps</span>
                </div>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { insertMermaid('sequence'); showDiagramMenu = false; }} role="menuitem">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" y1="4" x2="4" y2="20"/><line x1="20" y1="4" x2="20" y2="20"/><path d="M4 10h16"/><path d="M20 16H4"/></svg>
                <div class="item-info">
                  <span class="item-name">Approval Sequence</span>
                  <span class="item-sub">Designer &harr; Manager sign-offs</span>
                </div>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { insertMermaid('timeline'); showDiagramMenu = false; }} role="menuitem">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                <div class="item-info">
                  <span class="item-name">Milestones Timeline</span>
                  <span class="item-sub">Weekly schedule &amp; checkpoints</span>
                </div>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { insertMermaid('pie'); showDiagramMenu = false; }} role="menuitem">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
                <div class="item-info">
                  <span class="item-name">Media Mix Breakdown</span>
                  <span class="item-sub">Deliverable ratio pie chart</span>
                </div>
              </button>
              <button type="button" class="dropdown-item" onclick={() => { insertMermaid('architecture'); showDiagramMenu = false; }} role="menuitem">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="10" x2="6" y2="14"/></svg>
                <div class="item-info">
                  <span class="item-name">Brand System Architecture</span>
                  <span class="item-sub">Cross-app asset repositories</span>
                </div>
              </button>
            </div>
          {/if}
        </div>
      </div>

      <!-- Right: Document Stats, Mode Switcher, Zen Fullscreen & Save CTA -->
      <div class="toolbar-actions-group">
        <!-- Stats Pill -->
        <div class="stats-badge" title="Word count, character count, and reading estimate">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          <span>{wordCount}w</span>
          <span class="stat-dot">•</span>
          <span>{charCount}c</span>
          <span class="stat-dot">•</span>
          <span>~{readingTime}m</span>
        </div>

        <!-- Mode Segmented Control -->
        <div class="mode-segmented-control" role="group" aria-label="Editor view mode">
          <button
            type="button"
            class="mode-btn"
            class:active={mode === 'preview'}
            onclick={() => mode = 'preview'}
            title="Rendered Document View"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            <span>Preview</span>
          </button>
          <button
            type="button"
            class="mode-btn"
            class:active={mode === 'split'}
            onclick={() => mode = 'split'}
            title="Split Editor & Live Preview"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="12" y1="3" x2="12" y2="21"/></svg>
            <span>Split</span>
          </button>
          <button
            type="button"
            class="mode-btn"
            class:active={mode === 'source'}
            onclick={() => mode = 'source'}
            title="Markdown Source Code View"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>
            <span>Source</span>
          </button>
        </div>

        <!-- Fullscreen Zen Mode Button -->
        <button
          type="button"
          class="tool-btn icon-only"
          class:active={isFullscreen}
          onclick={() => isFullscreen = !isFullscreen}
          title={isFullscreen ? 'Exit Fullscreen (Esc)' : 'Zen Fullscreen Editor'}
          aria-label={isFullscreen ? 'Exit Fullscreen' : 'Zen Fullscreen'}
        >
          {#if isFullscreen}
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 14 10 14 10 20"/><polyline points="20 10 14 10 14 4"/><line x1="14" y1="10" x2="21" y2="3"/><line x1="3" y1="21" x2="10" y2="14"/></svg>
          {:else}
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><polyline points="21 14 21 21 14 21"/><polyline points="3 10 3 3 10 3"/></svg>
          {/if}
        </button>

        <!-- Save CTA -->
        {#if onSave && !readonly}
          <FluentButton appearance="primary" size="sm" loading={isSaving} onclick={handleSave}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"/>
            </svg>
            <span style="margin-left: 4px;">{saveLabel}</span>
          </FluentButton>
        {/if}
      </div>
    </div>
  </div>

  <!-- Content Panes Area -->
  <div class="editor-panes mode-{mode}">
    {#if mode === 'split' || mode === 'source'}
      <div class="source-pane">
        <textarea
          bind:this={textareaEl}
          bind:value
          {placeholder}
          disabled={readonly}
          spellcheck="false"
          onkeydown={handleKeyDown}
        ></textarea>
      </div>
    {/if}

    {#if mode === 'split' || mode === 'preview'}
      <div class="preview-pane">
        {#if value && value.trim()}
          <MarkdownViewer content={value} />
        {:else}
          <div class="empty-preview">
            <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="36" height="36">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>
            </svg>
            <p>No Markdown content written yet.</p>
            <span class="empty-sub">Type in the editor or use the toolbar above to populate your creative document.</span>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .markdown-editor-wrapper {
    display: flex;
    flex-direction: column;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg, 12px);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
    transition: all 0.2s ease;
  }

  /* ─── Zen Fullscreen Mode ─── */
  .markdown-editor-wrapper.fullscreen-mode {
    position: fixed;
    inset: 0;
    z-index: 9999;
    border-radius: 0;
    border: none;
    height: 100vh;
    max-height: 100vh;
    background: var(--surface-card, #0B0F19);
  }
  .markdown-editor-wrapper.fullscreen-mode .editor-panes {
    flex: 1;
    height: calc(100vh - 48px);
    max-height: calc(100vh - 48px);
  }
  .markdown-editor-wrapper.fullscreen-mode .source-pane textarea {
    height: 100%;
    min-height: calc(100vh - 48px);
  }

  /* ─── Fluent 2 Command Toolbar ─── */
  .editor-toolbar {
    background: var(--surface-card-subtle, #F8FAFC);
    border-bottom: 1px solid var(--surface-card-border);
    position: sticky;
    top: 0;
    z-index: 30;
    user-select: none;
  }

  .toolbar-primary-row {
    display: flex;
    align-items: center;
    padding: 6px 10px;
    gap: 6px;
    flex-wrap: wrap;
  }

  /* Document Badge */
  .toolbar-doc-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 3px 8px;
    background: var(--bg-app, rgba(0,0,0,0.04));
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-primary);
    font-family: var(--font-mono, monospace);
  }
  .doc-icon {
    color: var(--brand-primary, #0078D4);
    flex-shrink: 0;
  }
  .doc-title-text {
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Toolbar Group & Dividers */
  .toolbar-button-group {
    display: inline-flex;
    align-items: center;
    gap: 2px;
  }
  .tool-divider {
    display: inline-block;
    width: 1px;
    height: 18px;
    background: var(--surface-card-border);
    margin: 0 3px;
  }

  /* Standard Tool Button */
  .tool-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-secondary);
    border-radius: 5px;
    cursor: pointer;
    transition: all 0.12s ease;
    padding: 0;
  }
  .tool-btn:hover {
    background: var(--surface-card-hover, rgba(0,0,0,0.05));
    color: var(--text-primary);
    border-color: var(--surface-card-border);
  }
  .tool-btn.active {
    background: var(--brand-tint, rgba(0, 120, 212, 0.12));
    border-color: var(--brand-accent, #38BDF8);
    color: var(--brand-primary, #0078D4);
  }

  /* Dropdown Buttons */
  .dropdown-wrapper {
    position: relative;
    display: inline-block;
  }
  .tool-dropdown-btn {
    height: 28px;
    padding: 0 7px;
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-secondary);
    border-radius: 5px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    transition: all 0.12s ease;
    font-family: inherit;
  }
  .tool-dropdown-btn:hover, .tool-dropdown-btn.active {
    background: var(--surface-card-hover, rgba(0,0,0,0.05));
    border-color: var(--surface-card-border);
    color: var(--text-primary);
  }
  .btn-text-badge {
    font-weight: 800;
    font-size: 11px;
  }
  .dropdown-label {
    font-size: 11px;
    font-weight: 600;
  }
  .arrow-glyph {
    font-size: 8px;
    opacity: 0.6;
    margin-left: 1px;
  }

  /* ─── Modern Dropdown Menus ─── */
  .dropdown-menu {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    background: var(--surface-card, #FFFFFF);
    backdrop-filter: blur(20px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 8px;
    box-shadow: var(--shadow-xl, 0 16px 36px rgba(0,0,0,0.22));
    padding: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    z-index: 100;
    min-width: 170px;
    animation: menuFadeIn 0.12s ease-out;
  }
  @keyframes menuFadeIn {
    from { opacity: 0; transform: translateY(-4px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .dropdown-menu.diagram-menu { min-width: 220px; }
  .dropdown-menu.callout-menu { min-width: 210px; }

  .dropdown-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border: none;
    background: transparent;
    color: var(--text-primary);
    border-radius: 6px;
    font-size: 11.5px;
    cursor: pointer;
    transition: all 0.1s ease;
    font-family: inherit;
    text-align: left;
  }
  .dropdown-item:hover {
    background: var(--brand-tint, rgba(0, 120, 212, 0.08));
    color: var(--brand-primary, #0078D4);
  }
  .dropdown-item svg { flex-shrink: 0; color: var(--text-secondary); }
  .dropdown-item:hover svg { color: var(--brand-primary, #0078D4); }
  .item-badge {
    font-weight: 800;
    font-size: 10.5px;
    padding: 1px 5px;
    background: var(--bg-app);
    border-radius: 4px;
    color: var(--brand-primary, #0078D4);
  }
  .item-info {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .item-name {
    font-weight: 600;
    font-size: 11.5px;
    line-height: 1.2;
  }
  .item-sub {
    font-size: 9.5px;
    color: var(--text-tertiary);
  }

  /* Callout dots */
  .callout-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .callout-dot.note { background: #0284C7; }
  .callout-dot.important { background: #F59E0B; }
  .callout-dot.tip { background: #10B981; }
  .callout-dot.warning { background: #EF4444; }

  /* ─── Right Action Area ─── */
  .toolbar-actions-group {
    margin-left: auto;
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }

  .stats-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 7px;
    background: var(--bg-app);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    color: var(--text-tertiary);
    font-size: 10.5px;
    font-weight: 600;
    font-family: var(--font-mono, monospace);
  }
  .stats-badge svg { color: var(--text-tertiary); }
  .stat-dot { opacity: 0.4; }

  /* Segmented View Mode Switcher */
  .mode-segmented-control {
    display: inline-flex;
    align-items: center;
    background: var(--bg-app);
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
  }
  .mode-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 600;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.12s ease;
    font-family: inherit;
  }
  .mode-btn:hover {
    color: var(--text-primary);
  }
  .mode-btn.active {
    background: var(--surface-card);
    color: var(--brand-primary, #0078D4);
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }
  .mode-btn svg { flex-shrink: 0; }

  /* ─── Editor Panes Layout ─── */
  .editor-panes {
    display: grid;
    min-height: 320px;
    background: var(--surface-card);
  }
  .editor-panes.mode-split {
    grid-template-columns: 1fr 1fr;
  }
  .editor-panes.mode-source {
    grid-template-columns: 1fr;
  }
  .editor-panes.mode-preview {
    grid-template-columns: 1fr;
    min-height: auto;
  }

  .source-pane {
    display: flex;
    border-right: 1px solid var(--surface-card-border);
    background: var(--surface-card);
    min-height: 480px;
  }
  .mode-source .source-pane {
    border-right: none;
  }

  .source-pane textarea {
    width: 100%;
    min-height: 480px;
    height: 100%;
    padding: 18px 20px;
    border: none;
    outline: none;
    resize: vertical;
    overflow-y: auto;
    font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    font-size: 13px;
    line-height: 1.65;
    background: transparent;
    color: var(--text-primary);
    box-sizing: border-box;
    tab-size: 2;
  }

  .preview-pane {
    padding: 20px 24px;
    background: var(--surface-card);
    min-height: 260px;
    overflow-y: auto;
  }

  .empty-preview {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: var(--text-secondary);
    text-align: center;
    padding: 48px 24px;
  }
  .empty-preview .empty-icon {
    color: var(--text-tertiary);
    margin-bottom: 12px;
    opacity: 0.6;
  }
  .empty-preview p {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0 0 4px 0;
  }
  .empty-preview .empty-sub {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  @media (max-width: 900px) {
    .editor-panes.mode-split {
      grid-template-columns: 1fr;
    }
    .source-pane {
      border-right: none;
      border-bottom: 1px solid var(--surface-card-border);
      min-height: 280px;
    }
    .toolbar-actions-group {
      margin-left: 0;
      width: 100%;
      justify-content: space-between;
      margin-top: 4px;
    }
  }
</style>

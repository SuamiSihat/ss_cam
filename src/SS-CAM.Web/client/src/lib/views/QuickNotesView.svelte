<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface QuickNote {
    id: string;
    title: string;
    body: string;
    tag: string;
    isPinned: boolean;
    updatedAt: string;
  }

  const STORAGE_KEY = 'sscam_quick_notes_vault';

  const DEFAULT_TAGS = ['All', 'Ideas', 'Briefs', 'Copywriting', 'Meeting', 'Production'];

  const SEED_NOTES: QuickNote[] = [
    {
      id: 'note-1',
      title: 'Campaign Angle 2026: Acoustic Wave Energy',
      body: '# ESWT Focus Campaign\n\n- Primary Hook: "Mengapa rawatan gelombang kejutan lebih pantas berbanding rawatan biasa?"\n- Call To Action: Layari klinik cawangan berhampiran untuk sesi penilaian diagnostik.\n- Audience: Lelaki 30-55 tahun yang mementingkan rawatan tanpa ubat berpanjangan.',
      tag: 'Copywriting',
      isPinned: true,
      updatedAt: new Date().toISOString()
    },
    {
      id: 'note-2',
      title: 'Studio Asset Naming Rules Quick Reference',
      body: 'Standard Deliverable Naming:\n\n`[BRAND]_[CAMPAIGN]_[ASPECT]_[REVISION]_[DATE].[EXT]`\n\nContoh: `SS_TRT_1x1_REV02_20261028.mp4`\n\nPastikan folder 05_DELIVERABLES sentiasa bersih tanpa fail draf mentah.',
      tag: 'Production',
      isPinned: true,
      updatedAt: new Date(Date.now() - 86400000).toISOString()
    },
    {
      id: 'note-3',
      title: 'Monthly Creative Sync Notes',
      body: 'Keputusan mesyuarat mingguan:\n\n1. Selaraskan skrip TV Display dengan layout baharu 16:9.\n2. Siapkan aset poster cawangan Johor Bahru sebelum akhir bulan.\n3. Semak kelulusan perubatan bagi graf anatomi spermatogenesis 74 hari.',
      tag: 'Meeting',
      isPinned: false,
      updatedAt: new Date(Date.now() - 172800000).toISOString()
    }
  ];

  let notes = $state<QuickNote[]>([]);
  let activeNoteId = $state<string>('');
  let searchQuery = $state('');
  let selectedTag = $state('All');
  let isPreviewMode = $state(false);
  let saveStatus = $state('Saved');

  onMount(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        notes = JSON.parse(stored);
      } else {
        notes = SEED_NOTES;
        persistNotes(SEED_NOTES);
      }
    } catch {
      notes = SEED_NOTES;
    }

    if (notes.length > 0 && !activeNoteId) {
      activeNoteId = notes[0].id;
    }
  });

  function persistNotes(currentNotes: QuickNote[]) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(currentNotes));
      saveStatus = 'Saved';
    } catch {
      saveStatus = 'Storage full';
    }
  }

  const activeNote = $derived(notes.find(n => n.id === activeNoteId) || null);

  const filteredNotes = $derived(
    notes
      .filter(n => {
        const matchesTag = selectedTag === 'All' || n.tag === selectedTag;
        const matchesSearch = !searchQuery ||
          n.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          n.body.toLowerCase().includes(searchQuery.toLowerCase());
        return matchesTag && matchesSearch;
      })
      .sort((a, b) => {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime();
      })
  );

  function createNewNote() {
    const newNote: QuickNote = {
      id: 'note-' + Date.now(),
      title: 'Untitled note',
      body: '',
      tag: selectedTag === 'All' ? 'Ideas' : selectedTag,
      isPinned: false,
      updatedAt: new Date().toISOString()
    };
    notes = [newNote, ...notes];
    activeNoteId = newNote.id;
    persistNotes(notes);
    appState.addToast('Created new quick note', 'info', 'New Note');
  }

  function updateActiveNote(field: keyof QuickNote, value: any) {
    if (!activeNoteId) return;
    saveStatus = 'Saving…';
    notes = notes.map(n => {
      if (n.id === activeNoteId) {
        return {
          ...n,
          [field]: value,
          updatedAt: new Date().toISOString()
        };
      }
      return n;
    });
    persistNotes(notes);
  }

  function togglePin(noteId: string) {
    notes = notes.map(n => {
      if (n.id === noteId) {
        const next = !n.isPinned;
        appState.addToast(next ? 'Note pinned to top' : 'Note unpinned', 'info');
        return { ...n, isPinned: next, updatedAt: new Date().toISOString() };
      }
      return n;
    });
    persistNotes(notes);
  }

  function deleteNote(noteId: string) {
    notes = notes.filter(n => n.id !== noteId);
    persistNotes(notes);
    if (activeNoteId === noteId) {
      activeNoteId = notes.length > 0 ? notes[0].id : '';
    }
    appState.addToast('Note deleted', 'info');
  }

  function copyMarkdown() {
    if (!activeNote) return;
    navigator.clipboard.writeText(`# ${activeNote.title}\n\n${activeNote.body}`).then(() => {
      appState.addToast('Markdown copied to clipboard', 'success', 'Copied');
    });
  }

  function exportMarkdownFile() {
    if (!activeNote) return;
    const blob = new Blob([`# ${activeNote.title}\n\n${activeNote.body}`], { type: 'text/markdown;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${activeNote.title.replace(/[^a-zA-Z0-9_-]/g, '_')}.md`;
    a.click();
    URL.revokeObjectURL(url);
    appState.addToast('Exported note file', 'success', 'Exported');
  }

  function insertFormatting(prefix: string, suffix: string = '') {
    if (!activeNote) return;
    const textarea = document.getElementById('note-body-editor') as HTMLTextAreaElement | null;
    if (!textarea) return;

    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const current = activeNote.body;
    const selected = current.substring(start, end);

    const replacement = `${prefix}${selected || 'text'}${suffix}`;
    const nextBody = current.substring(0, start) + replacement + current.substring(end);
    updateActiveNote('body', nextBody);

    setTimeout(() => {
      textarea.focus();
      textarea.setSelectionRange(start + prefix.length, start + prefix.length + (selected ? selected.length : 4));
    }, 10);
  }

  function renderSimpleMarkdown(text: string): string {
    if (!text) return '<p class="placeholder-text">Nothing written yet. Start typing on the left…</p>';
    const lines = text.split('\n');
    let html = '';
    for (const line of lines) {
      if (line.startsWith('# ')) {
        html += `<h2>${escapeHtml(line.slice(2))}</h2>`;
      } else if (line.startsWith('## ')) {
        html += `<h3>${escapeHtml(line.slice(3))}</h3>`;
      } else if (line.startsWith('### ')) {
        html += `<h4>${escapeHtml(line.slice(4))}</h4>`;
      } else if (line.startsWith('- [ ] ')) {
        html += `<div class="todo-line"><input type="checkbox" disabled /> <span>${escapeHtml(line.slice(6))}</span></div>`;
      } else if (line.startsWith('- [x] ')) {
        html += `<div class="todo-line done"><input type="checkbox" checked disabled /> <del>${escapeHtml(line.slice(6))}</del></div>`;
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        html += `<li>${escapeHtml(line.slice(2))}</li>`;
      } else if (line.startsWith('`') && line.endsWith('`') && line.length > 2) {
        html += `<pre><code>${escapeHtml(line.slice(1, -1))}</code></pre>`;
      } else if (line.trim() === '') {
        html += `<div class="md-spacer"></div>`;
      } else {
        html += `<p>${escapeHtml(line)}</p>`;
      }
    }
    return html;
  }

  function escapeHtml(str: string) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function formatDate(iso: string) {
    try {
      const d = new Date(iso);
      return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
    } catch {
      return iso;
    }
  }
</script>

<div class="quick-notes-page">
  <!-- Header -->
  <header class="notes-header">
    <div class="header-left">
      <div class="header-icon-wrap">
        <FluentIcons name="edit" size="24" color="var(--brand-primary, #022057)" />
      </div>
      <div>
        <h1 class="page-title">Quick notes & creative scratchpad</h1>
        <p class="page-subtitle">Notion-inspired scratchpad for brief outlines, copy angles, and meeting decisions.</p>
      </div>
    </div>
    <div class="header-actions">
      <span class="save-status-indicator" title="Local browser storage">
        <span class="status-dot"></span>
        {saveStatus}
      </span>
      <FluentButton appearance="primary" onclick={createNewNote}>
        <FluentIcons name="plus" size="14" />
        New note
      </FluentButton>
    </div>
  </header>

  <!-- Main Split Layout -->
  <div class="notes-container">
    <!-- Sidebar Notes List -->
    <aside class="notes-sidebar">
      <div class="sidebar-search-box">
        <FluentIcons name="search" size="14" color="var(--text-secondary, #64748B)" />
        <input
          type="text"
          placeholder="Search notes…"
          bind:value={searchQuery}
          class="sidebar-search-input"
        />
        {#if searchQuery}
          <button type="button" class="clear-btn" onclick={() => (searchQuery = '')}>×</button>
        {/if}
      </div>

      <!-- Tag Filter Pills -->
      <div class="tag-pills-bar">
        {#each DEFAULT_TAGS as tag}
          <button
            type="button"
            class="tag-pill"
            class:active={selectedTag === tag}
            onclick={() => (selectedTag = tag)}
          >
            {tag}
          </button>
        {/each}
      </div>

      <!-- Notes Item List -->
      <div class="notes-list" role="list">
        {#if filteredNotes.length === 0}
          <div class="empty-notes-prompt">
            <FluentIcons name="edit" size="28" color="var(--text-secondary, #64748B)" />
            <p>No notes found</p>
            <button type="button" class="create-first-btn" onclick={createNewNote}>Create a note</button>
          </div>
        {:else}
          {#each filteredNotes as note (note.id)}
            <div
              class="note-item-card"
              class:selected={activeNoteId === note.id}
              onclick={() => (activeNoteId = note.id)}
              role="button"
              tabindex="0"
              onkeydown={(e) => { if (e.key === 'Enter') activeNoteId = note.id; }}
            >
              <div class="note-item-top">
                <div class="note-title-wrap">
                  {#if note.isPinned}
                    <span class="pinned-indicator" title="Pinned note">📌</span>
                  {/if}
                  <h4 class="note-item-title">{note.title || 'Untitled note'}</h4>
                </div>
                <button
                  type="button"
                  class="pin-toggle-btn"
                  onclick={(e) => { e.stopPropagation(); togglePin(note.id); }}
                  title={note.isPinned ? 'Unpin note' : 'Pin note to top'}
                  aria-label="Toggle pin"
                >
                  <FluentIcons name="pin" size="13" color={note.isPinned ? 'var(--brand-primary, #022057)' : 'var(--text-secondary, #94A3B8)'} />
                </button>
              </div>
              <p class="note-item-excerpt">{note.body ? note.body.slice(0, 85).replace(/[#*`]/g, '') : 'Empty note…'}</p>
              <div class="note-item-footer">
                <span class="note-tag-badge">{note.tag}</span>
                <span class="note-date">{formatDate(note.updatedAt)}</span>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </aside>

    <!-- Main Note Editor / Preview -->
    <main class="note-editor-panel">
      {#if activeNote}
        <div class="editor-header">
          <input
            type="text"
            class="note-title-input"
            value={activeNote.title}
            placeholder="Note title…"
            oninput={(e) => updateActiveNote('title', (e.target as HTMLInputElement).value)}
          />
          <div class="editor-toolbar">
            <div class="tag-selector-wrap">
              <label for="note-tag-select" class="sr-only">Category</label>
              <select
                id="note-tag-select"
                class="tag-select"
                value={activeNote.tag}
                onchange={(e) => updateActiveNote('tag', (e.target as HTMLSelectElement).value)}
              >
                <option value="Ideas">Ideas</option>
                <option value="Briefs">Briefs</option>
                <option value="Copywriting">Copywriting</option>
                <option value="Meeting">Meeting</option>
                <option value="Production">Production</option>
              </select>
            </div>
            <div class="toolbar-sep"></div>
            <button
              type="button"
              class="toolbar-btn"
              class:active={isPreviewMode}
              onclick={() => (isPreviewMode = !isPreviewMode)}
              title="Toggle Markdown Preview"
            >
              <FluentIcons name="eye" size="14" />
              <span>{isPreviewMode ? 'Edit' : 'Preview'}</span>
            </button>
            <button type="button" class="toolbar-btn" onclick={copyMarkdown} title="Copy markdown to clipboard">
              <FluentIcons name="copy" size="14" />
              <span>Copy</span>
            </button>
            <button type="button" class="toolbar-btn" onclick={exportMarkdownFile} title="Download .md file">
              <FluentIcons name="download" size="14" />
              <span>Export</span>
            </button>
            <button type="button" class="toolbar-btn danger" onclick={() => deleteNote(activeNote.id)} title="Delete note">
              <FluentIcons name="trash" size="14" />
            </button>
          </div>
        </div>

        <!-- Markdown Formatting Ribbon (Shown in Edit Mode) -->
        {#if !isPreviewMode}
          <div class="markdown-ribbon">
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('**', '**')} title="Bold"><strong>B</strong></button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('*', '*')} title="Italic"><em>I</em></button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('# ')} title="Heading 1">H1</button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('## ')} title="Heading 2">H2</button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('- ')} title="Bullet list">• List</button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('- [ ] ')} title="Task checkbox">☑ Task</button>
            <button type="button" class="ribbon-btn" onclick={() => insertFormatting('`', '`')} title="Inline code">`code`</button>
          </div>
        {/if}

        <!-- Editor / Preview Area -->
        <div class="editor-content-area">
          {#if isPreviewMode}
            <div class="markdown-preview-pane">
              {@html renderSimpleMarkdown(activeNote.body)}
            </div>
          {:else}
            <textarea
              id="note-body-editor"
              class="note-textarea"
              placeholder="Write your creative brief, hook angles, or script notes here in Markdown…"
              value={activeNote.body}
              oninput={(e) => updateActiveNote('body', (e.target as HTMLTextAreaElement).value)}
            ></textarea>
          {/if}
        </div>
      {:else}
        <div class="no-selection-placeholder">
          <FluentIcons name="edit" size="48" color="var(--text-secondary, #94A3B8)" />
          <h3>No note selected</h3>
          <p>Select a note from the left sidebar or create a new one to begin writing.</p>
          <FluentButton appearance="primary" onclick={createNewNote}>
            <FluentIcons name="plus" size="14" />
            Create new note
          </FluentButton>
        </div>
      {/if}
    </main>
  </div>
</div>

<style>
  .quick-notes-page {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 24px;
    max-width: 1400px;
    margin: 0 auto;
    height: calc(100vh - 80px);
  }

  .notes-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .header-icon-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--brand-tint, #E8F1FC);
  }

  .page-title {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .page-subtitle {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 3px 0 0 0;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .save-status-indicator {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
  }

  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #107C41;
  }

  .notes-container {
    display: grid;
    grid-template-columns: 340px 1fr;
    gap: 16px;
    flex: 1;
    min-height: 0;
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 12px;
    background: var(--surface-card, #FFFFFF);
    overflow: hidden;
  }

  /* Sidebar */
  .notes-sidebar {
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border-subtle, #E2E8F0);
    background: var(--surface-bg, #F8FAFC);
    min-height: 0;
  }

  .sidebar-search-box {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 14px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .sidebar-search-input {
    flex: 1;
    border: none;
    background: none;
    font-size: 13px;
    color: var(--text-primary, #1C1C1C);
    outline: none;
  }

  .clear-btn {
    border: none;
    background: none;
    font-size: 16px;
    color: var(--text-secondary, #64748B);
    cursor: pointer;
  }

  .tag-pills-bar {
    display: flex;
    gap: 6px;
    padding: 10px 14px;
    overflow-x: auto;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .tag-pill {
    padding: 4px 10px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 14px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s ease;
  }

  .tag-pill:hover {
    color: var(--brand-primary, #022057);
    border-color: var(--brand-primary, #022057);
  }

  .tag-pill.active {
    background: var(--brand-primary, #022057);
    color: #FFFFFF;
    border-color: var(--brand-primary, #022057);
  }

  .notes-list {
    flex: 1;
    overflow-y: auto;
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .note-item-card {
    padding: 12px 14px;
    border-radius: 8px;
    border: 1px solid transparent;
    background: var(--surface-card, #FFFFFF);
    cursor: pointer;
    transition: all 0.15s ease;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .note-item-card:hover {
    border-color: var(--border-subtle, #E2E8F0);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  }

  .note-item-card.selected {
    background: var(--brand-tint, #E8F1FC);
    border-color: rgba(2, 32, 87, 0.2);
  }

  .note-item-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .note-title-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
  }

  .pinned-indicator {
    font-size: 12px;
  }

  .note-item-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .pin-toggle-btn {
    border: none;
    background: none;
    cursor: pointer;
    padding: 2px;
    display: flex;
    align-items: center;
  }

  .note-item-excerpt {
    font-size: 12px;
    color: var(--text-secondary, #64748B);
    margin: 0;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .note-item-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 4px;
  }

  .note-tag-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(2, 32, 87, 0.08);
    color: var(--brand-primary, #022057);
  }

  .note-date {
    font-size: 11px;
    color: var(--text-secondary, #94A3B8);
  }

  .empty-notes-prompt {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 16px;
    text-align: center;
    gap: 8px;
    color: var(--text-secondary, #64748B);
  }

  .create-first-btn {
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 600;
    background: var(--brand-primary, #022057);
    color: #FFFFFF;
    border: none;
    border-radius: 6px;
    cursor: pointer;
  }

  /* Main Editor */
  .note-editor-panel {
    display: flex;
    flex-direction: column;
    min-height: 0;
    background: var(--surface-card, #FFFFFF);
  }

  .editor-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .note-title-input {
    flex: 1;
    font-size: 20px;
    font-weight: 700;
    border: none;
    outline: none;
    color: var(--text-primary, #1C1C1C);
    background: none;
  }

  .editor-toolbar {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .tag-select {
    padding: 6px 10px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 6px;
    outline: none;
    cursor: pointer;
  }

  .toolbar-sep {
    width: 1px;
    height: 20px;
    background: var(--border-subtle, #E2E8F0);
    margin: 0 4px;
  }

  .toolbar-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .toolbar-btn:hover {
    color: var(--brand-primary, #022057);
    border-color: var(--brand-primary, #022057);
  }

  .toolbar-btn.active {
    background: var(--brand-primary, #022057);
    color: #FFFFFF;
    border-color: var(--brand-primary, #022057);
  }

  .toolbar-btn.danger:hover {
    color: #C42B1C;
    border-color: #C42B1C;
    background: rgba(196, 43, 28, 0.08);
  }

  .markdown-ribbon {
    display: flex;
    gap: 6px;
    padding: 8px 20px;
    background: var(--surface-bg, #F8FAFC);
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .ribbon-btn {
    padding: 4px 8px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 4px;
    cursor: pointer;
  }

  .ribbon-btn:hover {
    color: var(--brand-primary, #022057);
    border-color: var(--brand-primary, #022057);
  }

  .editor-content-area {
    flex: 1;
    min-height: 0;
    display: flex;
    overflow-y: auto;
  }

  .note-textarea {
    flex: 1;
    border: none;
    outline: none;
    resize: none;
    padding: 20px;
    font-family: inherit;
    font-size: 14px;
    line-height: 1.6;
    color: var(--text-primary, #1C1C1C);
    background: var(--surface-card, #FFFFFF);
  }

  .markdown-preview-pane {
    flex: 1;
    padding: 20px;
    overflow-y: auto;
    font-size: 14px;
    line-height: 1.6;
    color: var(--text-primary, #1C1C1C);
  }

  .markdown-preview-pane :global(h2) {
    font-size: 18px;
    font-weight: 700;
    margin: 16px 0 8px 0;
    color: var(--brand-primary, #022057);
  }

  .markdown-preview-pane :global(h3) {
    font-size: 16px;
    font-weight: 700;
    margin: 12px 0 6px 0;
  }

  .markdown-preview-pane :global(p) {
    margin: 6px 0;
  }

  .markdown-preview-pane :global(li) {
    margin-left: 20px;
  }

  .markdown-preview-pane :global(.todo-line) {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 4px 0;
  }

  .markdown-preview-pane :global(pre) {
    background: var(--surface-bg, #F8FAFC);
    padding: 10px;
    border-radius: 6px;
    border: 1px solid var(--border-subtle, #E2E8F0);
    font-family: monospace;
    font-size: 12px;
  }

  .no-selection-placeholder {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: 40px;
    gap: 12px;
    color: var(--text-secondary, #64748B);
  }

  .no-selection-placeholder h3 {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    border: 0;
  }

  @media (max-width: 900px) {
    .notes-container {
      grid-template-columns: 1fr;
    }
  }
</style>

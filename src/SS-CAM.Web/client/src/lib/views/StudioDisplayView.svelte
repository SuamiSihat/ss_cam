<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { ApiClient } from '$lib/services/api';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';

  type Tab = 'queue' | 'playlist' | 'branch' | 'display';

  interface Slide {
    id: string;
    enabled: boolean;
    tag: string;
    title: string;
    subtitle: string;
    type: string;
    src?: string;
    muted?: boolean;
    originalName?: string;
    sizeBytes?: number;
  }

  interface Config {
    branchCode: string;
    slideDurationSec: number;
    soundAlertEnabled: boolean;
    rooms: string[];
    ticker: { enabled: boolean; prefix: string; text: string };
    queue: {
      currentCall: { ticket: string; room: string; doctor?: string | null; calledAt?: string } | null;
      upcoming: Array<{ ticket: string; room?: string }>;
    };
    slides: Slide[];
    branch?: any;
    updatedAt?: string;
  }

  const TABS: Array<{ id: Tab; label: string }> = [
    { id: 'queue', label: 'Queue' },
    { id: 'playlist', label: 'Playlist' },
    { id: 'branch', label: 'Branch info' },
    { id: 'display', label: 'Display' }
  ];
  const PREFIXES = ['A', 'B', 'C', 'D', 'E', 'F'];
  const BUILT_IN = ['doctors', 'eswt', 'trt', 'intake'];
  const TYPE_LABEL: Record<string, string> = {
    doctors: 'Duty doctors', eswt: 'Treatment info', trt: 'Treatment info', intake: 'Check-in', notice: 'Notice', video: 'Video'
  };

  let tab = $state<Tab>('queue');
  let config = $state<Config | null>(null);
  let branches = $state<any[]>([]);
  let isLoading = $state(true);
  let loadError = $state('');
  let busy = $state(false);
  let liveAt = $state('');

  // Queue entry
  let prefix = $state('A');
  let digits = $state('');
  let room = $state('');
  let doctor = $state('');

  // Playlist
  let uploadPct = $state<number | null>(null);
  let fileInput = $state<HTMLInputElement | null>(null);
  let noticeOpen = $state(false);
  let noticeTitle = $state('');
  let noticeBody = $state('');
  let confirmOpen = $state(false);
  let confirmTitle = $state('');
  let confirmText = $state('Confirm');
  let confirmAction: (() => Promise<void>) | null = null;

  // Branch editor
  let editCode = $state('');
  let form = $state<any>(null);
  let newDoctor = $state('');
  let branchError = $state('');
  let newRoom = $state('');

  const ticket = $derived(digits ? `${prefix}-${digits}` : '');
  const doctors = $derived<string[]>(Array.isArray(config?.branch?.doctors) ? config!.branch.doctors : []);
  const rooms = $derived<string[]>(config?.rooms || []);
  const current = $derived(config?.queue.currentCall || null);
  const waiting = $derived(config?.queue.upcoming || []);

  function apply(next: Config | undefined | null) {
    if (!next) return;
    config = next;
    liveAt = new Date().toLocaleTimeString();
    if (!room || !next.rooms?.includes(room)) room = next.rooms?.[0] || '';
    if (!editCode) {
      editCode = next.branchCode;
      loadForm();
    }
  }

  function loadForm() {
    const b = branches.find(x => x.code === editCode) || (config?.branch && config.branch.code === editCode ? config.branch : null);
    form = b ? { ...b, doctors: [...(b.doctors || [])] } : null;
    branchError = '';
  }

  async function loadAll() {
    try {
      const [cfg, br] = await Promise.all([ApiClient.getSignageConfig(), ApiClient.getClinicBranches()]);
      branches = br.branches || [];
      apply(cfg.config);
      loadForm();
      loadError = '';
    } catch (err: any) {
      console.error('[StudioDisplayView] loadAll:', err);
      loadError = err?.message || 'Could not load the Studio Display.';
    } finally {
      isLoading = false;
    }
  }

  async function refreshConfig() {
    try {
      const res = await ApiClient.getSignageConfig();
      apply(res.config);
    } catch (err: any) {
      console.warn('[StudioDisplayView] refreshConfig:', err?.message);
    }
  }

  function onLive() { refreshConfig(); }

  onMount(() => {
    loadAll();
    window.addEventListener('signage:updated', onLive);
  });
  onDestroy(() => window.removeEventListener('signage:updated', onLive));

  async function run<T>(fn: () => Promise<T>, okMsg?: string): Promise<T | undefined> {
    if (busy) return;
    busy = true;
    try {
      const out = await fn();
      if (okMsg) appState.addToast(okMsg, 'success');
      return out;
    } catch (err: any) {
      appState.addToast(err?.message || 'That did not work. Please try again.', 'error');
    } finally {
      busy = false;
    }
  }

  function ask(title: string, text: string, action: () => Promise<void>) {
    confirmTitle = title; confirmText = text; confirmAction = action; confirmOpen = true;
  }
  async function doConfirm() {
    const fn = confirmAction;
    confirmOpen = false;
    confirmAction = null;
    if (fn) await fn();
  }

  // ── Queue ──
  function press(d: string) { if (digits.length < 4) digits += d; }
  function backspace() { digits = digits.slice(0, -1); }

  async function callTicket(t: string, r: string, fromWaiting = false) {
    await run(async () => {
      const res = await ApiClient.callSignageTicket({ ticket: t, room: r || room, doctor: doctor || undefined, popUpcoming: true });
      apply(res.config);
    }, `Calling ${t}`);
    if (!fromWaiting) digits = '';
  }
  async function callNow() {
    if (!ticket) { appState.addToast('Enter a ticket number first.', 'warning'); return; }
    await callTicket(ticket, room);
  }
  async function callNext() {
    await run(async () => {
      const res = await ApiClient.callSignageTicket({ ticket: '', room, doctor: doctor || undefined, isNext: true });
      apply(res.config);
    }, 'Calling next ticket');
  }
  async function recall() {
    if (!current) return;
    await run(async () => {
      const res = await ApiClient.callSignageTicket({ ticket: current.ticket, room: current.room, doctor: current.doctor || undefined, popUpcoming: false });
      apply(res.config);
    }, `Re-announcing ${current.ticket}`);
  }
  async function addWaiting() {
    if (!ticket || !config) { appState.addToast('Enter a ticket number first.', 'warning'); return; }
    if (waiting.some(w => w.ticket === ticket)) { appState.addToast(`${ticket} is already waiting.`, 'warning'); return; }
    const list = [...waiting, { ticket, room }];
    await run(async () => { apply((await ApiClient.updateSignageUpcoming(list)).config); digits = ''; }, `${ticket} added to waiting`);
  }
  async function moveWaiting(i: number, dir: -1 | 1) {
    const list = [...waiting];
    const j = i + dir;
    if (j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    await run(async () => { apply((await ApiClient.updateSignageUpcoming(list)).config); });
  }
  async function removeWaiting(i: number) {
    const list = waiting.filter((_, k) => k !== i);
    await run(async () => { apply((await ApiClient.updateSignageUpcoming(list)).config); });
  }
  function clearQueue() {
    ask('Clear the queue?', 'Clear queue', async () => {
      await run(async () => { apply((await ApiClient.clearSignageQueue(true)).config); }, 'Queue cleared');
    });
  }

  // ── Playlist ──
  async function saveSlides(slides: Slide[]) {
    await run(async () => { apply((await ApiClient.updateSignageConfig({ slides })).config); });
  }
  function moveSlide(i: number, dir: -1 | 1) {
    if (!config) return;
    const list = [...config.slides];
    const j = i + dir;
    if (j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    saveSlides(list);
  }
  function toggleSlide(i: number) {
    if (!config) return;
    saveSlides(config.slides.map((s, k) => (k === i ? { ...s, enabled: !s.enabled } : s)));
  }
  function toggleMute(i: number) {
    if (!config) return;
    saveSlides(config.slides.map((s, k) => (k === i ? { ...s, muted: !s.muted } : s)));
  }
  function removeSlide(i: number) {
    if (!config) return;
    const s = config.slides[i];
    ask(`Remove "${s.title || TYPE_LABEL[s.type]}"?`, 'Remove', async () => {
      if (s.type === 'video' && s.src) {
        const name = s.src.split('/').pop() || '';
        await run(async () => { apply((await ApiClient.deleteSignageVideo(name)).config); }, 'Video removed');
      } else {
        await saveSlides(config!.slides.filter((_, k) => k !== i));
      }
    });
  }
  async function addNotice() {
    if (!config || !noticeTitle.trim()) { appState.addToast('Give the notice a title.', 'warning'); return; }
    const slide: Slide = {
      id: `notice-${Date.now().toString(36)}`, enabled: true, type: 'notice',
      tag: 'ANNOUNCEMENT', title: noticeTitle.trim(), subtitle: noticeBody.trim()
    };
    noticeOpen = false;
    noticeTitle = ''; noticeBody = '';
    await saveSlides([...config.slides, slide]);
  }
  async function changeDuration(delta: number) {
    if (!config) return;
    const v = Math.min(120, Math.max(3, config.slideDurationSec + delta));
    await run(async () => { apply((await ApiClient.updateSignageConfig({ slideDurationSec: v })).config); });
  }
  async function onFilePicked(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    if (!/\.(mp4|webm)$/i.test(file.name)) { appState.addToast('Choose an MP4 or WebM video.', 'warning'); return; }
    uploadPct = 0;
    await run(async () => {
      const res = await ApiClient.uploadSignageVideo(file, p => (uploadPct = p));
      apply(res.config);
    }, 'Video added to the playlist');
    uploadPct = null;
  }
  function fmtSize(n?: number) {
    if (!n) return '';
    return n >= 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;
  }

  // ── Branch ──
  async function showOnTv(code: string) {
    await run(async () => { apply((await ApiClient.updateSignageConfig({ branchCode: code })).config); }, 'TV branch changed');
  }
  function pickBranch(code: string) { editCode = code; loadForm(); }
  function addDoctor() {
    const v = newDoctor.trim();
    if (!v || !form) return;
    if (!form.doctors.includes(v)) form.doctors = [...form.doctors, v];
    newDoctor = '';
  }
  function removeDoctor(i: number) { form.doctors = form.doctors.filter((_: string, k: number) => k !== i); }
  async function saveBranch() {
    if (!form) return;
    branchError = '';
    const patch = {
      name: form.name, shortName: form.shortName, address: form.address, phone: form.phone,
      whatsapp: form.whatsapp, operatingHours: form.operatingHours, kkmLicense: form.kkmLicense,
      checkInUrl: form.checkInUrl, googleReviewUrl: form.googleReviewUrl, doctors: form.doctors
    };
    if (busy) return;
    busy = true;
    try {
      const res = await ApiClient.updateClinicBranch(editCode, patch);
      branches = branches.map(b => (b.code === editCode ? res.branch : b));
      appState.addToast('Branch info saved. TV screens are updating.', 'success');
      await refreshConfig();
      loadForm();
    } catch (err: any) {
      branchError = err?.message || 'Could not save the branch.';
    } finally {
      busy = false;
    }
  }

  // ── Display ──
  async function saveDisplay(patch: any, msg?: string) {
    await run(async () => { apply((await ApiClient.updateSignageConfig(patch)).config); }, msg);
  }
  async function saveRooms(list: string[]) { await saveDisplay({ rooms: list }); }
  async function addRoomName() {
    const v = newRoom.trim();
    if (!v || !config) return;
    if (config.rooms.includes(v)) { appState.addToast('That room already exists.', 'warning'); return; }
    newRoom = '';
    await saveRooms([...config.rooms, v]);
  }
  async function removeRoomName(r: string) {
    if (!config || config.rooms.length <= 1) { appState.addToast('Keep at least one room.', 'warning'); return; }
    await saveRooms(config.rooms.filter(x => x !== r));
  }
  let tickerDraft = $state<{ prefix: string; text: string } | null>(null);
  $effect(() => {
    if (config && !tickerDraft) tickerDraft = { prefix: config.ticker.prefix, text: config.ticker.text };
  });
</script>

<div class="sd-page">
  <header class="sd-head">
    <div class="sd-head-text">
      <h1 class="sd-title">Studio display</h1>
      <p class="sd-sub">Run the clinic TV: call tickets, manage the playlist and keep branch details current.</p>
    </div>
    <div class="sd-head-actions">
      <span class="sd-live" title="Updates reach every connected TV instantly"><span class="sd-dot"></span>Live{liveAt ? ` · ${liveAt}` : ''}</span>
      <a class="sd-open" href="#signage" target="_blank" rel="noopener">Open TV screen</a>
    </div>
  </header>

  <div class="sd-tabs" role="tablist" aria-label="Studio display sections">
    {#each TABS as t (t.id)}
      <button type="button" role="tab" id="sd-tab-{t.id}" class="sd-tab" class:active={tab === t.id}
        aria-selected={tab === t.id} onclick={() => (tab = t.id)}>{t.label}</button>
    {/each}
  </div>

  {#if isLoading}
    <p class="sd-state">Loading Studio display…</p>
  {:else if loadError || !config}
    <FluentCard>
      <p class="sd-state">{loadError || 'Studio display is not available.'}</p>
      <FluentButton appearance="primary" onclick={loadAll}>Try again</FluentButton>
    </FluentCard>
  {:else}
    <div class="sd-body" class:is-busy={busy}>
      {#if tab === 'queue'}
        <FluentCard padding="20px">
          <div class="sd-now" class:idle={!current}>
            <span class="sd-label">Now calling</span>
            <span class="sd-now-ticket">{current ? current.ticket : '—'}</span>
            <span class="sd-now-room">{current ? current.room : 'No ticket is being called'}</span>
            {#if current?.doctor}<span class="sd-now-doc">{current.doctor}</span>{/if}
          </div>
          <div class="sd-row">
            <button type="button" class="sd-big primary" id="sd-call-next" onclick={callNext} disabled={busy || waiting.length === 0}>Call next{waiting.length ? ` (${waiting[0].ticket})` : ''}</button>
            <button type="button" class="sd-big" id="sd-recall" onclick={recall} disabled={busy || !current}>Recall</button>
            <button type="button" class="sd-big danger" id="sd-clear" onclick={clearQueue} disabled={busy || (!current && waiting.length === 0)}>Clear</button>
          </div>
        </FluentCard>

        <div class="sd-grid">
          <FluentCard padding="20px">
            <h2 class="sd-h2">Ticket</h2>
            <div class="sd-chips" aria-label="Ticket prefix">
              {#each PREFIXES as p (p)}
                <button type="button" class="sd-chip" class:on={prefix === p} onclick={() => (prefix = p)}>{p}</button>
              {/each}
            </div>
            <div class="sd-display" aria-live="polite">{ticket || `${prefix}-…`}</div>
            <div class="sd-keypad">
              {#each ['1','2','3','4','5','6','7','8','9'] as d (d)}
                <button type="button" class="sd-key" onclick={() => press(d)}>{d}</button>
              {/each}
              <button type="button" class="sd-key alt" onclick={() => (digits = '')} aria-label="Clear digits">C</button>
              <button type="button" class="sd-key" onclick={() => press('0')}>0</button>
              <button type="button" class="sd-key alt" onclick={backspace} aria-label="Delete last digit">⌫</button>
            </div>
            <h3 class="sd-h3">Room</h3>
            <div class="sd-chips">
              {#each rooms as r (r)}
                <button type="button" class="sd-chip wide" class:on={room === r} onclick={() => (room = r)}>{r}</button>
              {/each}
            </div>
            {#if doctors.length}
              <h3 class="sd-h3">Doctor <span class="sd-opt">(optional)</span></h3>
              <div class="sd-chips">
                <button type="button" class="sd-chip wide" class:on={doctor === ''} onclick={() => (doctor = '')}>None</button>
                {#each doctors as d (d)}
                  <button type="button" class="sd-chip wide" class:on={doctor === d} onclick={() => (doctor = d)}>{d}</button>
                {/each}
              </div>
            {/if}
            <div class="sd-row">
              <button type="button" class="sd-big primary" id="sd-call-now" onclick={callNow} disabled={busy || !ticket}>Call now</button>
              <button type="button" class="sd-big" id="sd-add-wait" onclick={addWaiting} disabled={busy || !ticket}>Add to waiting</button>
            </div>
          </FluentCard>

          <FluentCard padding="20px">
            <h2 class="sd-h2">Waiting ({waiting.length})</h2>
            {#if waiting.length === 0}
              <p class="sd-empty">No one is waiting. Add tickets with the keypad.</p>
            {:else}
              <ul class="sd-list">
                {#each waiting as w, i (w.ticket)}
                  <li class="sd-item">
                    <div class="sd-item-main">
                      <span class="sd-item-ticket">{w.ticket}</span>
                      <span class="sd-item-sub">{w.room || room}</span>
                    </div>
                    <div class="sd-item-actions">
                      <button type="button" class="sd-icon primary" onclick={() => callTicket(w.ticket, w.room || room, true)} disabled={busy}>Call</button>
                      <button type="button" class="sd-icon" aria-label="Move {w.ticket} up" onclick={() => moveWaiting(i, -1)} disabled={busy || i === 0}>↑</button>
                      <button type="button" class="sd-icon" aria-label="Move {w.ticket} down" onclick={() => moveWaiting(i, 1)} disabled={busy || i === waiting.length - 1}>↓</button>
                      <button type="button" class="sd-icon danger" aria-label="Remove {w.ticket}" onclick={() => removeWaiting(i)} disabled={busy}>✕</button>
                    </div>
                  </li>
                {/each}
              </ul>
            {/if}
          </FluentCard>
        </div>
      {/if}

      {#if tab === 'playlist'}
        <FluentCard padding="20px">
          <div class="sd-between">
            <h2 class="sd-h2">Playlist</h2>
            <div class="sd-stepper" aria-label="Seconds per slide">
              <button type="button" class="sd-icon" aria-label="Shorter" onclick={() => changeDuration(-1)} disabled={busy || config.slideDurationSec <= 3}>−</button>
              <span class="sd-step-val">{config.slideDurationSec}s per slide</span>
              <button type="button" class="sd-icon" aria-label="Longer" onclick={() => changeDuration(1)} disabled={busy || config.slideDurationSec >= 120}>+</button>
            </div>
          </div>
          <p class="sd-sub">Plays top to bottom on the TV. Videos play to the end, then the next item starts.</p>
          <ul class="sd-list">
            {#each config.slides as s, i (s.id)}
              <li class="sd-item" class:off={!s.enabled}>
                <button type="button" class="sd-toggle" class:on={s.enabled} role="switch" aria-checked={s.enabled}
                  aria-label="Show {s.title || TYPE_LABEL[s.type]} on the TV" onclick={() => toggleSlide(i)} disabled={busy}><span></span></button>
                <div class="sd-item-main">
                  <span class="sd-item-ticket sm">{s.title || TYPE_LABEL[s.type] || s.type}</span>
                  <span class="sd-item-sub">{TYPE_LABEL[s.type] || s.type}{s.type === 'video' && s.sizeBytes ? ` · ${fmtSize(s.sizeBytes)}` : ''}{s.type === 'video' ? (s.muted ? ' · muted' : ' · sound on') : ''}</span>
                </div>
                <div class="sd-item-actions">
                  {#if s.type === 'video'}
                    <button type="button" class="sd-icon" onclick={() => toggleMute(i)} disabled={busy} aria-label={s.muted ? 'Turn sound on' : 'Mute video'}>{s.muted ? 'Sound' : 'Mute'}</button>
                  {/if}
                  <button type="button" class="sd-icon" aria-label="Move up" onclick={() => moveSlide(i, -1)} disabled={busy || i === 0}>↑</button>
                  <button type="button" class="sd-icon" aria-label="Move down" onclick={() => moveSlide(i, 1)} disabled={busy || i === config.slides.length - 1}>↓</button>
                  {#if !BUILT_IN.includes(s.type)}
                    <button type="button" class="sd-icon danger" aria-label="Remove" onclick={() => removeSlide(i)} disabled={busy}>✕</button>
                  {/if}
                </div>
              </li>
            {/each}
          </ul>
          {#if uploadPct !== null}
            <div class="sd-progress" role="progressbar" aria-valuenow={uploadPct} aria-valuemin="0" aria-valuemax="100"><div style="width:{uploadPct}%"></div></div>
            <p class="sd-sub">Uploading video… {uploadPct}%</p>
          {/if}
          <div class="sd-row">
            <button type="button" class="sd-big primary" id="sd-upload" onclick={() => fileInput?.click()} disabled={busy || uploadPct !== null}>Add video</button>
            <button type="button" class="sd-big" id="sd-add-notice" onclick={() => (noticeOpen = true)} disabled={busy}>Add notice</button>
          </div>
          <input bind:this={fileInput} type="file" accept="video/mp4,video/webm,.mp4,.webm" hidden onchange={onFilePicked} />
          <p class="sd-hint">MP4 or WebM, up to 300 MB. Videos play on the TV from this server only.</p>
        </FluentCard>
      {/if}

      {#if tab === 'branch'}
        <FluentCard padding="20px">
          <h2 class="sd-h2">Branch</h2>
          <div class="sd-chips">
            {#each branches as b (b.code)}
              <button type="button" class="sd-chip wide" class:on={editCode === b.code} onclick={() => pickBranch(b.code)}>
                {b.shortName || b.name}{config.branchCode === b.code ? ' · on TV' : ''}
              </button>
            {/each}
          </div>
          {#if form}
            <div class="sd-form">
              <label class="sd-field"><span>Branch name</span><input class="sd-input" bind:value={form.name} maxlength="160" /></label>
              <label class="sd-field"><span>Short name</span><input class="sd-input" bind:value={form.shortName} maxlength="80" /></label>
              <label class="sd-field full"><span>Address</span><textarea class="sd-input" rows="2" bind:value={form.address} maxlength="300"></textarea></label>
              <label class="sd-field"><span>Phone</span><input class="sd-input" type="tel" bind:value={form.phone} maxlength="40" /></label>
              <label class="sd-field"><span>WhatsApp</span><input class="sd-input" type="tel" bind:value={form.whatsapp} maxlength="40" /></label>
              <label class="sd-field"><span>Operating hours</span><input class="sd-input" bind:value={form.operatingHours} maxlength="200" /></label>
              <label class="sd-field"><span>KKM licence</span><input class="sd-input" bind:value={form.kkmLicense} maxlength="80" /></label>
              <label class="sd-field full"><span>Check-in link</span><input class="sd-input" type="url" bind:value={form.checkInUrl} placeholder="https://" /></label>
              <label class="sd-field full"><span>Review link</span><input class="sd-input" type="url" bind:value={form.googleReviewUrl} placeholder="https://" /></label>
            </div>
            <h3 class="sd-h3">Doctors</h3>
            <div class="sd-chips">
              {#each form.doctors as d, i (d)}
                <span class="sd-tag">{d}<button type="button" aria-label="Remove {d}" onclick={() => removeDoctor(i)}>✕</button></span>
              {/each}
              {#if form.doctors.length === 0}<span class="sd-empty">No doctors listed.</span>{/if}
            </div>
            <div class="sd-add">
              <input class="sd-input" placeholder="Add doctor name" bind:value={newDoctor} onkeydown={(e) => e.key === 'Enter' && addDoctor()} />
              <button type="button" class="sd-big" onclick={addDoctor}>Add</button>
            </div>
            {#if branchError}<p class="sd-error" role="alert">{branchError}</p>{/if}
            <div class="sd-row">
              <button type="button" class="sd-big primary" id="sd-save-branch" onclick={saveBranch} disabled={busy}>Save branch info</button>
              {#if config.branchCode !== editCode}
                <button type="button" class="sd-big" onclick={() => showOnTv(editCode)} disabled={busy}>Show this branch on TV</button>
              {/if}
            </div>
          {:else}
            <p class="sd-empty">Branch details are not available.</p>
          {/if}
        </FluentCard>
      {/if}

      {#if tab === 'display'}
        <FluentCard padding="20px">
          <h2 class="sd-h2">Sound</h2>
          <div class="sd-item">
            <div class="sd-item-main"><span class="sd-item-ticket sm">Chime and voice on call</span><span class="sd-item-sub">The TV must have been touched once after opening to allow audio.</span></div>
            <button type="button" class="sd-toggle" class:on={config.soundAlertEnabled} role="switch" aria-checked={config.soundAlertEnabled}
              aria-label="Sound alert" onclick={() => saveDisplay({ soundAlertEnabled: !config!.soundAlertEnabled })} disabled={busy}><span></span></button>
          </div>
        </FluentCard>

        <FluentCard padding="20px">
          <h2 class="sd-h2">Ticker</h2>
          <div class="sd-item">
            <div class="sd-item-main"><span class="sd-item-ticket sm">Show scrolling ticker</span></div>
            <button type="button" class="sd-toggle" class:on={config.ticker.enabled} role="switch" aria-checked={config.ticker.enabled}
              aria-label="Show ticker" onclick={() => saveDisplay({ ticker: { ...config!.ticker, enabled: !config!.ticker.enabled } })} disabled={busy}><span></span></button>
          </div>
          {#if tickerDraft}
            <div class="sd-form">
              <label class="sd-field"><span>Label</span><input class="sd-input" bind:value={tickerDraft.prefix} maxlength="40" /></label>
              <label class="sd-field full"><span>Message</span><textarea class="sd-input" rows="3" bind:value={tickerDraft.text} maxlength="600"></textarea></label>
            </div>
            <div class="sd-row">
              <button type="button" class="sd-big primary" onclick={() => saveDisplay({ ticker: { ...config!.ticker, ...tickerDraft } }, 'Ticker updated')} disabled={busy}>Save ticker</button>
            </div>
          {/if}
        </FluentCard>

        <FluentCard padding="20px">
          <h2 class="sd-h2">Rooms and counters</h2>
          <div class="sd-chips">
            {#each config.rooms as r (r)}
              <span class="sd-tag">{r}<button type="button" aria-label="Remove {r}" onclick={() => removeRoomName(r)}>✕</button></span>
            {/each}
          </div>
          <div class="sd-add">
            <input class="sd-input" placeholder="Add room or counter" bind:value={newRoom} onkeydown={(e) => e.key === 'Enter' && addRoomName()} />
            <button type="button" class="sd-big" onclick={addRoomName}>Add</button>
          </div>
        </FluentCard>
      {/if}
    </div>
  {/if}
</div>

<FluentDialog bind:open={noticeOpen} title="Add notice" confirmText="Add to playlist" onConfirm={addNotice} onClose={() => (noticeOpen = false)}>
  <div class="sd-form one">
    <label class="sd-field"><span>Title</span><input class="sd-input" bind:value={noticeTitle} maxlength="120" /></label>
    <label class="sd-field"><span>Message</span><textarea class="sd-input" rows="3" bind:value={noticeBody} maxlength="300"></textarea></label>
  </div>
</FluentDialog>

<FluentDialog bind:open={confirmOpen} title={confirmTitle} confirmText={confirmText} confirmAppearance="danger" onConfirm={doConfirm} onClose={() => (confirmOpen = false)}>
  <p>This cannot be undone.</p>
</FluentDialog>

<style>
  .sd-page { --sd-line: color-mix(in srgb, var(--text-secondary) 40%, transparent); padding: 0 0 48px; display: flex; flex-direction: column; gap: 16px; width: 100%; touch-action: manipulation; }
  .sd-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; flex-wrap: wrap; }
  .sd-title { font-size: 24px; font-weight: 700; margin: 0; color: var(--text-primary); }
  .sd-sub { margin: 4px 0 12px; color: var(--text-secondary); font-size: 14px; }
  .sd-head .sd-sub { margin-bottom: 0; }
  .sd-head-actions { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .sd-live { display: inline-flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-secondary); }
  .sd-dot { width: 10px; height: 10px; border-radius: 50%; background: var(--success, #107c10); animation: sdpulse 2s infinite; }
  @keyframes sdpulse { 50% { opacity: .35; } }
  .sd-open { min-height: 48px; display: inline-flex; align-items: center; padding: 0 18px; border: 1px solid var(--sd-line); border-radius: 8px; color: var(--brand-accent); font-weight: 600; text-decoration: none; }

  .sd-tabs { display: flex; gap: 6px; padding: 4px; background: var(--card-border); border-radius: 12px; flex-wrap: wrap; }
  .sd-tab { flex: 1 1 120px; min-height: 52px; border: none; border-radius: 9px; background: transparent; color: var(--text-secondary); font-size: 16px; font-weight: 600; cursor: pointer; }
  .sd-tab.active { background: var(--brand-accent); color: #fff; }
  .sd-tab:focus-visible, .sd-big:focus-visible, .sd-key:focus-visible, .sd-chip:focus-visible, .sd-icon:focus-visible, .sd-toggle:focus-visible { outline: 3px solid var(--brand-accent); outline-offset: 2px; }

  .sd-body { display: flex; flex-direction: column; gap: 16px; padding-bottom: 24px; }
  .sd-body.is-busy { cursor: progress; }
  .sd-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; align-items: start; }
  .sd-h2 { font-size: 18px; font-weight: 700; margin: 0 0 12px; color: var(--text-primary); }
  .sd-h3 { font-size: 14px; font-weight: 600; margin: 16px 0 8px; color: var(--text-secondary); }
  .sd-opt { font-weight: 400; }
  .sd-state, .sd-empty, .sd-hint { color: var(--text-secondary); font-size: 14px; margin: 8px 0; }
  .sd-error { color: var(--danger, #c50f1f); font-size: 14px; margin: 12px 0 0; }
  .sd-between { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }

  .sd-now { text-align: center; padding: 20px; border-radius: 12px; border: 1px solid var(--sd-line); display: flex; flex-direction: column; gap: 4px; margin-bottom: 16px; }
  .sd-now.idle { opacity: .7; }
  .sd-label { font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--text-secondary); }
  .sd-now-ticket { font-size: 56px; font-weight: 800; line-height: 1.1; color: var(--brand-accent); }
  .sd-now-room { font-size: 18px; color: var(--text-primary); }
  .sd-now-doc { font-size: 14px; color: var(--text-secondary); }

  .sd-row { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 16px; }
  .sd-big { flex: 1 1 140px; min-height: 56px; padding: 0 20px; border-radius: 10px; border: 1px solid var(--sd-line); background: transparent; color: var(--text-primary); font-size: 16px; font-weight: 700; cursor: pointer; }
  .sd-big.primary { background: var(--brand-accent); border-color: var(--brand-accent); color: #fff; }
  .sd-big.danger { color: var(--danger, #c50f1f); }
  .sd-big:active:not(:disabled), .sd-key:active, .sd-chip:active, .sd-icon:active:not(:disabled) { transform: scale(.97); }
  button:disabled { opacity: .45; cursor: not-allowed; }

  .sd-chips { display: flex; flex-wrap: wrap; gap: 8px; }
  .sd-chip { min-height: 48px; min-width: 48px; padding: 0 16px; border-radius: 24px; border: 1px solid var(--sd-line); background: transparent; color: var(--text-primary); font-size: 15px; font-weight: 600; cursor: pointer; }
  .sd-chip.on { background: var(--brand-accent); border-color: var(--brand-accent); color: #fff; }
  .sd-display { margin: 16px 0; text-align: center; font-size: 40px; font-weight: 800; letter-spacing: .05em; min-height: 56px; color: var(--text-primary); }
  .sd-keypad { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
  .sd-key { min-height: 64px; font-size: 26px; font-weight: 700; border-radius: 12px; border: 1px solid var(--sd-line); background: transparent; color: var(--text-primary); cursor: pointer; }
  .sd-key.alt { color: var(--text-secondary); }

  .sd-list { list-style: none; margin: 12px 0 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
  .sd-item { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 12px; border: 1px solid var(--sd-line); border-radius: 10px; min-height: 64px; }
  .sd-item.off { opacity: .55; }
  .sd-item-main { display: flex; flex-direction: column; min-width: 0; flex: 1; }
  .sd-item-ticket { font-size: 24px; font-weight: 800; color: var(--text-primary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sd-item-ticket.sm { font-size: 16px; font-weight: 700; }
  .sd-item-sub { font-size: 13px; color: var(--text-secondary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sd-item-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .sd-icon { min-width: 48px; min-height: 48px; padding: 0 12px; border-radius: 10px; border: 1px solid var(--sd-line); background: transparent; color: var(--text-primary); font-size: 16px; font-weight: 700; cursor: pointer; }
  .sd-icon.primary { background: var(--brand-accent); border-color: var(--brand-accent); color: #fff; }
  .sd-icon.danger { color: var(--danger, #c50f1f); }
  .sd-stepper { display: flex; align-items: center; gap: 8px; }
  .sd-step-val { min-width: 110px; text-align: center; font-weight: 600; color: var(--text-primary); }

  .sd-toggle { width: 60px; height: 34px; min-width: 60px; border-radius: 17px; border: 1px solid var(--sd-line); background: var(--sd-line); position: relative; cursor: pointer; padding: 0; flex-shrink: 0; margin: 7px 0; }
  .sd-toggle span { position: absolute; top: 3px; left: 3px; width: 26px; height: 26px; border-radius: 50%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.3); transition: transform .15s; }
  .sd-toggle.on { background: var(--brand-accent); border-color: var(--brand-accent); }
  .sd-toggle.on span { transform: translateX(26px); }

  .sd-progress { height: 10px; border-radius: 5px; background: var(--card-border); overflow: hidden; margin-top: 12px; }
  .sd-progress div { height: 100%; background: var(--brand-accent); transition: width .2s; }

  .sd-form { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 14px; margin-top: 16px; }
  .sd-form.one { grid-template-columns: 1fr; margin-top: 0; }
  .sd-field { display: flex; flex-direction: column; gap: 6px; font-size: 13px; color: var(--text-secondary); }
  .sd-field.full { grid-column: 1 / -1; }
  .sd-input { min-height: 48px; padding: 8px 12px; font-size: 16px; border-radius: 8px; border: 1px solid var(--sd-line); background: var(--input-bg, transparent); color: var(--text-primary); font-family: inherit; box-sizing: border-box; width: 100%; }
  .sd-input:focus-visible { outline: 3px solid var(--brand-accent); outline-offset: 1px; }
  .sd-add { display: flex; gap: 10px; margin-top: 12px; }
  .sd-add .sd-big { flex: 0 0 110px; }
  .sd-tag { display: inline-flex; align-items: center; gap: 4px; min-height: 44px; padding: 0 4px 0 14px; border-radius: 22px; border: 1px solid var(--sd-line); color: var(--text-primary); font-size: 14px; font-weight: 600; }
  .sd-tag button { min-width: 40px; min-height: 40px; border: none; background: transparent; color: var(--text-secondary); font-size: 16px; cursor: pointer; border-radius: 50%; }

  @media (max-width: 720px) {
    .sd-page { padding: 16px 12px 40px; }
    .sd-now-ticket { font-size: 44px; }
    .sd-item { flex-wrap: wrap; }
    .sd-item-actions { width: 100%; justify-content: flex-end; }
  }
  @media (prefers-reduced-motion: reduce) { .sd-dot { animation: none; } .sd-toggle span, .sd-progress div { transition: none; } }
</style>

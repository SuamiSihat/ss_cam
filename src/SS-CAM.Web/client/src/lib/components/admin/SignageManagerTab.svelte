<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { ApiClient } from '$lib/services/api';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  interface SignageSlide {
    id: string;
    enabled: boolean;
    tag: string;
    title: string;
    subtitle: string;
    type: string;
  }

  interface SignageConfig {
    branchCode: string;
    slideDurationSec: number;
    soundAlertEnabled: boolean;
    kkmLicense: string;
    ticker: {
      enabled: boolean;
      prefix: string;
      text: string;
    };
    queue: {
      currentCall: {
        ticket: string;
        room: string;
        doctor?: string | null;
        calledAt?: string;
      } | null;
      upcoming: Array<{ ticket: string; room?: string }>;
    };
    slides: SignageSlide[];
    branch?: any;
    updatedAt?: string;
  }

  let config = $state<SignageConfig>({
    branchCode: 'SSC-BSR',
    slideDurationSec: 10,
    soundAlertEnabled: true,
    kkmLicense: 'KKM/JPS/KL/2024/0912',
    ticker: {
      enabled: true,
      prefix: 'INFO KLINIK',
      text: 'Selamat datang ke SuamiSihat Clinic • Rawatan kesihatan lelaki beretika, saintifik dan diperakui KKM.'
    },
    queue: {
      currentCall: null,
      upcoming: []
    },
    slides: []
  });

  let isLoading = $state(false);
  let isSaving = $state(false);
  let isCalling = $state(false);

  // Quick Call form
  let callTicket = $state('A-1031');
  let callRoom = $state('Bilik Rawatan 1');
  let callDoctor = $state('');

  // Add Upcoming form
  let addTicket = $state('');
  let addRoom = $state('Bilik Rawatan 1');

  // Custom notice slide inputs
  let noticeTitle = $state('Pemeriksaan Kesihatan Komprehensif');
  let noticeSubtitle = $state('Dapatkan saringan tahap testosteron dan kesihatan prostat anda hari ini di kaunter pendaftaran.');

  const CLINIC_BRANCHES = [
    { code: 'SSC-BSR', name: 'SuamiSihat Clinic Bangsar (HQ Induk)', shortName: 'Bangsar HQ' },
    { code: 'SSC-KD',  name: 'SuamiSihat Clinic Kota Damansara',     shortName: 'Kota Damansara' },
    { code: 'SSC-JB',  name: 'SuamiSihat Clinic Johor Bahru',        shortName: 'Johor Bahru' },
    { code: 'SSC-PNG', name: 'SuamiSihat Clinic Georgetown Penang',  shortName: 'Penang' }
  ];

  const CLINIC_ROOMS = [
    'Bilik Rawatan 1',
    'Bilik Rawatan 2',
    'Bilik Rawatan 3',
    'Bilik Prosedur ESWT',
    'Kaunter Saringan',
    'Makmal Darah TRT',
    'Kaunter Farmasi'
  ];

  const currentBranchDoctors = $derived<string[]>(
    config.branch?.doctors && Array.isArray(config.branch.doctors) ? config.branch.doctors : []
  );

  async function loadData() {
    isLoading = true;
    try {
      const res = await ApiClient.getSignageConfig(config.branchCode);
      if (res.success && res.config) {
        config = res.config;
        syncNoticeFields();
        if (!callDoctor && currentBranchDoctors.length > 0) {
          callDoctor = currentBranchDoctors[0];
        }
      }
    } catch (err: any) {
      appState.addToast('Failed to load Studio Display settings.', 'error');
    } finally {
      isLoading = false;
    }
  }

  function syncNoticeFields() {
    const noticeSlide = config.slides?.find(s => s.type === 'notice' || s.id === 'custom-notice');
    if (noticeSlide) {
      noticeTitle = noticeSlide.title || noticeTitle;
      noticeSubtitle = noticeSlide.subtitle || noticeSubtitle;
    }
  }

  function suggestNextTicket(last: string) {
    const match = last.match(/^([A-Za-z]+)-?(\d+)$/);
    if (match) {
      const prefix = match[1];
      const num = parseInt(match[2], 10) + 1;
      callTicket = `${prefix}-${num}`;
    }
  }

  async function handleCallTicket(ticketNum?: string, roomName?: string) {
    const t = (ticketNum || callTicket).trim().toUpperCase();
    const r = (roomName || callRoom).trim();
    if (!t) {
      appState.addToast('Please enter a ticket number to call.', 'warning');
      return;
    }

    isCalling = true;
    try {
      const res = await ApiClient.callSignageTicket({
        ticket: t,
        room: r,
        doctor: callDoctor.trim() || undefined,
        popUpcoming: true
      });
      if (res.success && res.config) {
        config = res.config;
        appState.addToast(`Called ticket ${t} to ${r}. Broadcasted in real-time!`, 'success');
        suggestNextTicket(t);
      }
    } catch (err: any) {
      appState.addToast(err.message || 'Failed to call queue ticket.', 'error');
    } finally {
      isCalling = false;
    }
  }

  async function handleCallNextInQueue() {
    if (!config.queue?.upcoming || config.queue.upcoming.length === 0) {
      appState.addToast('No upcoming tickets in the queue.', 'warning');
      return;
    }
    const next = config.queue.upcoming[0];
    await handleCallTicket(next.ticket, next.room || callRoom);
  }

  async function handleAddUpcoming() {
    const t = addTicket.trim().toUpperCase();
    if (!t) {
      appState.addToast('Please enter a ticket number.', 'warning');
      return;
    }

    const currentList = [...(config.queue?.upcoming || [])];
    currentList.push({ ticket: t, room: addRoom.trim() });

    try {
      const res = await ApiClient.updateSignageUpcoming(currentList);
      if (res.success && res.config) {
        config = res.config;
        appState.addToast(`Ticket ${t} added to waiting queue.`, 'success');
        addTicket = '';
      }
    } catch (err: any) {
      appState.addToast(err.message || 'Failed to add upcoming ticket.', 'error');
    }
  }

  async function handleRemoveUpcoming(idx: number) {
    const currentList = [...(config.queue?.upcoming || [])];
    currentList.splice(idx, 1);
    try {
      const res = await ApiClient.updateSignageUpcoming(currentList);
      if (res.success && res.config) {
        config = res.config;
        appState.addToast('Ticket removed from waiting queue.', 'info');
      }
    } catch (err: any) {
      appState.addToast(err.message || 'Failed to remove ticket.', 'error');
    }
  }

  async function handleClearQueue(clearCurrent: boolean = false) {
    if (!confirm(clearCurrent ? 'Reset both current call and all upcoming tickets?' : 'Clear all tickets in the waiting queue?')) {
      return;
    }
    try {
      const res = await ApiClient.clearSignageQueue(clearCurrent);
      if (res.success && res.config) {
        config = res.config;
        appState.addToast('Queue cleared & updated on TV display.', 'info');
      }
    } catch (err: any) {
      appState.addToast(err.message || 'Failed to clear queue.', 'error');
    }
  }

  async function handleSaveSettings() {
    isSaving = true;

    // Sync custom notice into slides array
    const slides = (config.slides || []).map(s => {
      if (s.type === 'notice' || s.id === 'custom-notice') {
        return {
          ...s,
          title: noticeTitle.trim(),
          subtitle: noticeSubtitle.trim()
        };
      }
      return s;
    });

    try {
      const res = await ApiClient.updateSignageConfig({
        branchCode: config.branchCode,
        slideDurationSec: Number(config.slideDurationSec) || 10,
        soundAlertEnabled: config.soundAlertEnabled !== false,
        kkmLicense: config.kkmLicense,
        ticker: config.ticker,
        slides
      });
      if (res.success && res.config) {
        config = res.config;
        appState.addToast('Settings saved & broadcasted to Studio Display!', 'success');
      }
    } catch (err: any) {
      appState.addToast(err.message || 'Failed to save settings.', 'error');
    } finally {
      isSaving = false;
    }
  }

  async function handleBranchSelect(newCode: string) {
    config.branchCode = newCode;
    await loadData();
    await handleSaveSettings();
  }

  function handleSignageUpdated(evt: any) {
    const detail = evt.detail || evt;
    if (detail && (detail.branchCode || detail.queue)) {
      config = detail;
      syncNoticeFields();
    }
  }

  onMount(async () => {
    await loadData();
    if (typeof window !== 'undefined') {
      window.addEventListener('signage:updated', handleSignageUpdated as EventListener);
    }
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('signage:updated', handleSignageUpdated as EventListener);
    }
  });
</script>

<div class="signage-manager-pane">
  <!-- Section Title & Deck Action Bar -->
  <div class="deck-action-bar">
    <div>
      <div class="signage-badge-row">
        <span class="signage-live-badge">
          <span class="live-dot-pulse"></span>
          <span>LIVE BROADCAST ENABLED</span>
        </span>
        <span class="branch-pill-badge">{config.branch?.name || config.branchCode}</span>
      </div>
      <h2 class="deck-title">Studio Display &amp; Signage TV Control</h2>
      <p class="deck-desc">
        Manage real-time queue calling, clinic billboard slide rotation, running ticker announcements, and branch configuration. Changes broadcast immediately to all connected TV screens via Server-Sent Events.
      </p>
    </div>

    <div class="deck-controls">
      <a
        href="#signage"
        target="_blank"
        rel="noopener noreferrer"
        class="launch-tv-btn"
        title="Open full-screen display in new window"
      >
        <FluentIcons name="externalLink" size={14} />
        <span>Open Kiosk Screen</span>
      </a>

      <FluentButton appearance="secondary" onclick={loadData} disabled={isLoading}>
        <FluentIcons name="refresh" size={14} />
        <span>{isLoading ? 'Syncing...' : 'Sync'}</span>
      </FluentButton>

      <FluentButton appearance="primary" onclick={handleSaveSettings} disabled={isSaving}>
        <FluentIcons name="save" size={14} />
        <span>{isSaving ? 'Broadcasting...' : 'Save &amp; Broadcast'}</span>
      </FluentButton>
    </div>
  </div>

  <!-- Management Grid -->
  <div class="signage-grid-layout">
    <!-- ════════ COLUMN 1: LIVE QUEUE CONTROLLER ════════ -->
    <div class="grid-col">
      <FluentCard elevated>
        <div class="card-section-header">
          <div class="csh-icon" style="background: rgba(33, 161, 247, 0.15); color: #21A1F7;">🔔</div>
          <div>
            <h3 class="csh-title">Live Queue Calling Console</h3>
            <p class="csh-subtitle">Broadcast patient call numbers to the lounge TV screen in real-time.</p>
          </div>
        </div>

        <!-- Current Called Ticket Spotlight -->
        <div class="current-call-monitor">
          <div class="ccm-top-row">
            <span class="ccm-tag">SEDANG DIPANGGIL (NOW CALLING)</span>
            {#if config.queue?.currentCall?.calledAt}
              <span class="ccm-time">
                Called {new Date(config.queue.currentCall.calledAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </span>
            {/if}
          </div>

          <div class="ccm-hero">
            <div class="ccm-ticket">{config.queue?.currentCall?.ticket || '---'}</div>
            <div class="ccm-dest">
              <span class="ccm-room">{config.queue?.currentCall?.room || 'Kaunter Sedia Ada'}</span>
              {#if config.queue?.currentCall?.doctor}
                <span class="ccm-doc">• {config.queue.currentCall.doctor}</span>
              {/if}
            </div>
          </div>
        </div>

        <!-- Call Action Form -->
        <div class="queue-form-box">
          <h4 class="form-box-title">Panggil Nombor (Call Number)</h4>
          <div class="form-row-2col">
            <div class="form-group">
              <label for="call-ticket-input" class="form-label">Nombor Giliran (Ticket)</label>
              <input
                id="call-ticket-input"
                type="text"
                class="fluent-text-input bold-ticket"
                placeholder="e.g. A-1029"
                bind:value={callTicket}
              />
            </div>

            <div class="form-group">
              <label for="call-room-input" class="form-label">Bilik / Destinasi (Room)</label>
              <select id="call-room-input" class="fluent-select-input" bind:value={callRoom}>
                {#each CLINIC_ROOMS as rm}
                  <option value={rm}>{rm}</option>
                {/each}
              </select>
            </div>
          </div>

          {#if currentBranchDoctors.length > 0}
            <div class="form-group" style="margin-top: 10px;">
              <label for="call-doc-input" class="form-label">Doktor Bertugas (Doctor)</label>
              <select id="call-doc-input" class="fluent-select-input" bind:value={callDoctor}>
                {#each currentBranchDoctors as doc}
                  <option value={doc}>{doc}</option>
                {/each}
              </select>
            </div>
          {/if}

          <div class="call-action-btns">
            <FluentButton appearance="primary" onclick={() => handleCallTicket()} disabled={isCalling}>
              <FluentIcons name="bell" size={14} />
              <span>{isCalling ? 'Calling...' : 'Panggil Nombor (Call Now)'}</span>
            </FluentButton>

            <FluentButton appearance="secondary" onclick={handleCallNextInQueue} disabled={isCalling || !(config.queue?.upcoming?.length > 0)}>
              <FluentIcons name="arrowRight" size={14} />
              <span>Giliran Seterusnya (Next)</span>
            </FluentButton>
          </div>
        </div>

        <!-- Upcoming Queue List -->
        <div class="upcoming-manager-box">
          <div class="umb-header">
            <span class="umb-title">Senarai Menunggu ({config.queue?.upcoming?.length || 0})</span>
            {#if config.queue?.upcoming && config.queue.upcoming.length > 0}
              <button type="button" class="clear-queue-link" onclick={() => handleClearQueue(false)}>
                Kosongkan Senarai
              </button>
            {/if}
          </div>

          <!-- Add to upcoming row -->
          <div class="add-upcoming-row">
            <input
              type="text"
              class="fluent-text-input sm-ticket"
              placeholder="Nombor (e.g. A-1032)"
              bind:value={addTicket}
            />
            <select class="fluent-select-input sm-room" bind:value={addRoom}>
              {#each CLINIC_ROOMS as rm}
                <option value={rm}>{rm}</option>
              {/each}
            </select>
            <FluentButton appearance="secondary" onclick={handleAddUpcoming}>
              <FluentIcons name="add" size={13} />
              <span>Tambah</span>
            </FluentButton>
          </div>

          <!-- List of upcoming items -->
          <div class="upcoming-items-scroll">
            {#if config.queue?.upcoming && config.queue.upcoming.length > 0}
              {#each config.queue.upcoming as item, idx}
                <div class="upcoming-item-row">
                  <div class="uir-info">
                    <span class="uir-num">{item.ticket}</span>
                    <span class="uir-room">{item.room || 'Kaunter Saringan'}</span>
                  </div>
                  <div class="uir-actions">
                    <button
                      type="button"
                      class="uir-call-btn"
                      title="Panggil nombor ini sekarang"
                      onclick={() => handleCallTicket(item.ticket, item.room)}
                    >
                      Panggil
                    </button>
                    <button
                      type="button"
                      class="uir-del-btn"
                      title="Buang dari senarai"
                      onclick={() => handleRemoveUpcoming(idx)}
                    >
                      <FluentIcons name="close" size={12} />
                    </button>
                  </div>
                </div>
              {/each}
            {:else}
              <div class="empty-upcoming-notice">
                Tiada nombor giliran menunggu. Tambah nombor di atas untuk memaparkan senarai giliran seterusnya pada skrin TV.
              </div>
            {/if}
          </div>

          <div class="sound-toggle-row">
            <label class="toggle-control-label">
              <input type="checkbox" bind:checked={config.soundAlertEnabled} onchange={handleSaveSettings} />
              <span class="toggle-text">Bunyikan Chime Audio pada TV bila nombor dipanggil</span>
            </label>
          </div>
        </div>
      </FluentCard>
    </div>

    <!-- ════════ COLUMN 2: BILLBOARD & SLIDES ════════ -->
    <div class="grid-col">
      <!-- Card: Branch & Timing -->
      <FluentCard elevated>
        <div class="card-section-header">
          <div class="csh-icon" style="background: rgba(16, 185, 129, 0.15); color: #10B981;">🏢</div>
          <div>
            <h3 class="csh-title">Cawangan &amp; Kelajuan Paparan</h3>
            <p class="csh-subtitle">Pilih cawangan klinik yang dipaparkan pada skrin TV.</p>
          </div>
        </div>

        <div class="form-row-2col" style="margin-bottom: 16px;">
          <div class="form-group">
            <label for="branch-selector-input" class="form-label">Cawangan Klinik (Branch)</label>
            <select
              id="branch-selector-input"
              class="fluent-select-input"
              bind:value={config.branchCode}
              onchange={(e) => handleBranchSelect((e.target as HTMLSelectElement).value)}
            >
              {#each CLINIC_BRANCHES as br}
                <option value={br.code}>{br.name}</option>
              {/each}
            </select>
          </div>

          <div class="form-group">
            <label for="slide-dur-input" class="form-label">Masa Setiap Slide (Saat)</label>
            <input
              id="slide-dur-input"
              type="number"
              min="3"
              max="60"
              class="fluent-text-input"
              bind:value={config.slideDurationSec}
            />
          </div>
        </div>

        <div class="branch-meta-card">
          <div class="bmc-row">
            <span class="bmc-label">Alamat:</span>
            <span class="bmc-val">{config.branch?.address || '-'}</span>
          </div>
          <div class="bmc-row">
            <span class="bmc-label">No. Lesen KKM:</span>
            <span class="bmc-val">{config.kkmLicense || config.branch?.kkmLicense || '-'}</span>
          </div>
          <div class="bmc-row">
            <span class="bmc-label">Bantuan Kaunter:</span>
            <span class="bmc-val">{config.branch?.phone || '-'} • WhatsApp: {config.branch?.whatsapp || '-'}</span>
          </div>
        </div>
      </FluentCard>

      <!-- Card: Slides Sequences -->
      <FluentCard elevated style="margin-top: 20px;">
        <div class="card-section-header">
          <div class="csh-icon" style="background: rgba(139, 92, 246, 0.15); color: #8B5CF6;">🎞️</div>
          <div>
            <h3 class="csh-title">Slide Pusingan (Billboard Carousel)</h3>
            <p class="csh-subtitle">Aktifkan atau nyahaktifkan slide yang berputar pada skrin utama TV.</p>
          </div>
        </div>

        <div class="slides-toggle-list">
          {#each config.slides as slide}
            <div class="slide-toggle-item">
              <label class="slide-toggle-label">
                <input type="checkbox" bind:checked={slide.enabled} />
                <div class="sti-text">
                  <span class="sti-title">{slide.tag || slide.title}</span>
                  <span class="sti-sub">{slide.title} — {slide.subtitle}</span>
                </div>
              </label>
              <span class="sti-type-badge">{slide.type}</span>
            </div>
          {/each}
        </div>

        <!-- Custom Notice Slide Editor -->
        <div class="notice-editor-box">
          <h4 class="form-box-title">Slide Pengumuman Khas (Special Notice)</h4>
          <div class="form-group" style="margin-bottom: 10px;">
            <label for="notice-title-input" class="form-label">Tajuk Pengumuman</label>
            <input
              id="notice-title-input"
              type="text"
              class="fluent-text-input"
              bind:value={noticeTitle}
              placeholder="e.g. Saringan Kesihatan Percuma"
            />
          </div>
          <div class="form-group">
            <label for="notice-sub-input" class="form-label">Huraian Pengumuman</label>
            <textarea
              id="notice-sub-input"
              rows="2"
              class="fluent-textarea-input"
              bind:value={noticeSubtitle}
              placeholder="Teks keterangan penuh yang akan dipaparkan..."
            ></textarea>
          </div>
        </div>
      </FluentCard>

      <!-- Card: Running Ticker -->
      <FluentCard elevated style="margin-top: 20px;">
        <div class="card-section-header">
          <div class="csh-icon" style="background: rgba(245, 158, 11, 0.15); color: #F59E0B;">📢</div>
          <div>
            <h3 class="csh-title">Teks Pengumuman Bergerak (Running Ticker)</h3>
            <p class="csh-subtitle">Mesej bergerak di bahagian bawah skrin kiosk TV.</p>
          </div>
        </div>

        <div class="ticker-enable-row">
          <label class="toggle-control-label">
            <input type="checkbox" bind:checked={config.ticker.enabled} />
            <span class="toggle-text">Aktifkan Running Ticker pada Kiosk TV</span>
          </label>
        </div>

        <div class="form-row-2col" style="margin-bottom: 12px;">
          <div class="form-group" style="max-width: 180px;">
            <label for="ticker-prefix-input" class="form-label">Label Awalan (Prefix)</label>
            <input
              id="ticker-prefix-input"
              type="text"
              class="fluent-text-input"
              bind:value={config.ticker.prefix}
              placeholder="INFO KLINIK"
            />
          </div>
        </div>

        <div class="form-group">
          <label for="ticker-text-input" class="form-label">Kandungan Mesej Pengumuman (Announcement Content)</label>
          <textarea
            id="ticker-text-input"
            rows="3"
            class="fluent-textarea-input"
            bind:value={config.ticker.text}
            placeholder="Masukkan teks pengumuman..."
          ></textarea>
        </div>
      </FluentCard>
    </div>
  </div>
</div>

<style>
  .signage-manager-pane {
    padding: 0;
  }

  .deck-action-bar {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 24px;
    gap: 20px;
  }

  .deck-title {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
    margin: 4px 0 6px 0;
  }

  .deck-desc {
    font-size: 13px;
    color: var(--text-secondary);
    margin: 0;
    max-width: 760px;
    line-height: 1.5;
  }

  .signage-badge-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }

  .signage-live-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.35);
    color: #10B981;
    font-size: 10.5px;
    font-weight: 800;
    letter-spacing: 0.8px;
    padding: 3px 10px;
    border-radius: 20px;
  }

  .live-dot-pulse {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #10B981;
    animation: livePulse 2s infinite;
  }

  @keyframes livePulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.4; transform: scale(0.8); }
  }

  .branch-pill-badge {
    font-size: 11px;
    font-weight: 700;
    color: #21A1F7;
    background: rgba(33, 161, 247, 0.1);
    padding: 3px 10px;
    border-radius: 12px;
  }

  .deck-controls {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-shrink: 0;
  }

  .launch-tv-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: rgba(33, 161, 247, 0.15);
    color: #21A1F7;
    border: 1px solid rgba(33, 161, 247, 0.3);
    padding: 8px 14px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.2s ease;
  }

  .launch-tv-btn:hover {
    background: #21A1F7;
    color: #FFFFFF;
    box-shadow: 0 4px 12px rgba(33, 161, 247, 0.3);
  }

  .signage-grid-layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }

  .grid-col {
    display: flex;
    flex-direction: column;
  }

  .card-section-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 20px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--card-border, rgba(255, 255, 255, 0.08));
  }

  .csh-icon {
    width: 38px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    flex-shrink: 0;
  }

  .csh-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0 0 2px 0;
  }

  .csh-subtitle {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
  }

  /* Current Call Monitor */
  .current-call-monitor {
    background: linear-gradient(135deg, rgba(33, 161, 247, 0.12) 0%, rgba(4, 51, 136, 0.25) 100%);
    border: 1.5px solid #21A1F7;
    border-radius: 14px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 4px 20px rgba(33, 161, 247, 0.15);
  }

  .ccm-top-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }

  .ccm-tag {
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 0.8px;
    color: #38BDF8;
  }

  .ccm-time {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .ccm-hero {
    display: flex;
    align-items: baseline;
    gap: 20px;
  }

  .ccm-ticket {
    font-size: 48px;
    font-weight: 900;
    color: #FFFFFF;
    letter-spacing: 1px;
    line-height: 1;
  }

  .ccm-dest {
    display: flex;
    flex-direction: column;
  }

  .ccm-room {
    font-size: 16px;
    font-weight: 700;
    color: #38BDF8;
  }

  .ccm-doc {
    font-size: 12px;
    color: var(--text-secondary);
  }

  /* Form Elements */
  .queue-form-box, .upcoming-manager-box, .notice-editor-box {
    background: var(--card-bg-subtle, rgba(255, 255, 255, 0.02));
    border: 1px solid var(--card-border, rgba(255, 255, 255, 0.08));
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 20px;
  }

  .form-box-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0 0 12px 0;
  }

  .form-row-2col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .form-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .fluent-text-input, .fluent-select-input, .fluent-textarea-input {
    background: var(--input-bg, rgba(255, 255, 255, 0.06));
    border: 1px solid var(--input-border, rgba(255, 255, 255, 0.15));
    border-radius: 8px;
    padding: 8px 12px;
    color: var(--text-primary, #FFFFFF);
    font-size: 13px;
    font-family: inherit;
    outline: none;
    transition: all 0.2s ease;
    min-height: 36px;
    vertical-align: middle;
  }

  .fluent-text-input:focus, .fluent-select-input:focus, .fluent-textarea-input:focus {
    border-color: #21A1F7;
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.2);
  }

  .bold-ticket {
    font-size: 18px;
    font-weight: 800;
    letter-spacing: 1px;
    text-align: center;
    color: #38BDF8;
  }

  .call-action-btns {
    display: flex;
    gap: 10px;
    margin-top: 14px;
  }

  /* Upcoming Queue List */
  .umb-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .umb-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .clear-queue-link {
    background: none;
    border: none;
    color: #EF4444;
    font-size: 11.5px;
    font-weight: 600;
    cursor: pointer;
    padding: 0;
    text-decoration: underline;
  }

  .add-upcoming-row {
    display: grid;
    grid-template-columns: 140px 1fr auto;
    gap: 8px;
    margin-bottom: 12px;
  }

  .sm-ticket {
    font-size: 13px;
    font-weight: 700;
  }

  .upcoming-items-scroll {
    max-height: 180px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding-right: 4px;
    margin-bottom: 14px;
  }

  .upcoming-item-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 8px;
    padding: 8px 12px;
  }

  .uir-info {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .uir-num {
    font-size: 14px;
    font-weight: 800;
    color: #FFFFFF;
  }

  .uir-room {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .uir-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .uir-call-btn {
    background: rgba(33, 161, 247, 0.15);
    border: 1px solid rgba(33, 161, 247, 0.3);
    color: #38BDF8;
    border-radius: 6px;
    padding: 3px 8px;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
  }

  .uir-call-btn:hover {
    background: #21A1F7;
    color: #FFFFFF;
  }

  .uir-del-btn {
    background: none;
    border: none;
    color: #94A3B8;
    cursor: pointer;
    padding: 3px;
    display: flex;
    align-items: center;
  }

  .uir-del-btn:hover {
    color: #EF4444;
  }

  .empty-upcoming-notice {
    font-size: 12px;
    color: var(--text-secondary);
    text-align: center;
    padding: 16px;
    font-style: italic;
  }

  .sound-toggle-row {
    padding-top: 10px;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
  }

  .toggle-control-label {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    user-select: none;
  }

  .toggle-text {
    font-size: 12.5px;
    color: var(--text-secondary);
  }

  /* Branch Meta Card */
  .branch-meta-card {
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 10px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .bmc-row {
    display: flex;
    font-size: 12px;
    gap: 8px;
  }

  .bmc-label {
    color: var(--text-secondary);
    width: 110px;
    flex-shrink: 0;
    font-weight: 600;
  }

  .bmc-val {
    color: var(--text-primary);
  }

  /* Slides List */
  .slides-toggle-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 16px;
  }

  .slide-toggle-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 8px;
    padding: 10px 14px;
  }

  .slide-toggle-label {
    display: flex;
    align-items: center;
    gap: 12px;
    cursor: pointer;
    flex: 1;
  }

  .sti-text {
    display: flex;
    flex-direction: column;
  }

  .sti-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .sti-sub {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .sti-type-badge {
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    background: rgba(255, 255, 255, 0.08);
    color: #94A3B8;
    padding: 2px 8px;
    border-radius: 6px;
  }

  .ticker-enable-row {
    margin-bottom: 12px;
  }

  @media (max-width: 1024px) {
    .signage-grid-layout {
      grid-template-columns: 1fr;
    }
    .deck-action-bar {
      flex-direction: column;
      align-items: stretch;
    }
    .deck-controls {
      justify-content: flex-start;
      flex-wrap: wrap;
    }
  }
</style>

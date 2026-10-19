<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';

  interface BranchData {
    code?: string;
    name: string;
    shortName: string;
    address: string;
    phone: string;
    whatsapp: string;
    doctors: string[];
    operatingHours: string;
    kkmLicense: string;
    checkInUrl: string;
  }

  interface QueueCall {
    ticket: string;
    room: string;
    doctor?: string | null;
    calledAt?: string;
  }

  interface UpcomingTicket {
    ticket: string;
    room?: string;
  }

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
    effectiveLicense?: string;
    ticker: {
      enabled: boolean;
      prefix: string;
      text: string;
    };
    queue: {
      currentCall: QueueCall | null;
      upcoming: UpcomingTicket[];
    };
    slides: SignageSlide[];
    branch?: BranchData | null;
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
      text: 'Selamat datang ke SuamiSihat Clinic • Rawatan kesihatan lelaki beretika, saintifik dan diperakui KKM • Kerahsiaan rekod pesakit dilindungi 100% di bawah Akta Perlindungan Data Peribadi (PDPA 2010).'
    },
    queue: {
      currentCall: null,
      upcoming: []
    },
    slides: [
      {
        id: 'duty-doctor',
        enabled: true,
        tag: 'DOKTOR BERTUGAS HARI INI',
        title: 'Pakar Konsultasi Kesihatan Lelaki',
        subtitle: 'Sedia membantu anda dengan bimbingan klinikal peribadi dan sulit.',
        type: 'doctors'
      }
    ],
    branch: {
      name: 'SuamiSihat Clinic Bangsar (HQ Induk)',
      shortName: 'Bangsar HQ',
      address: 'No. 45, Jalan Telawi 3, Bangsar Baru, 59100 Kuala Lumpur',
      phone: '+603-2284 1122',
      whatsapp: '+6012-345 6789',
      doctors: ['Dr. Azlan Shah, MD (Cyberjaya), Dip. Men\'s Health', 'Dr. Farhan Kamil, MBBS (Malaya)'],
      operatingHours: 'Isnin - Sabtu: 9:00 AM - 7:00 PM',
      kkmLicense: 'KKM/JPS/KL/2024/0912',
      checkInUrl: 'https://suamisihat.clinic/checkin/bangsar'
    }
  });

  let currentTime = $state('');
  let currentDate = $state('');
  let currentSlide = $state(0);
  let isOffline = $state(typeof navigator !== 'undefined' ? !navigator.onLine : false);
  let justCalled = $state(false);
  let previousTicket = $state<string | null>(null);

  let slideTimer: any = null;
  let clockTimer: any = null;
  let pollTimer: any = null;
  let flashTimeout: any = null;

  const branch = $derived<BranchData>(config.branch || {
    name: 'SuamiSihat Clinic',
    shortName: 'Clinic',
    address: 'Kuala Lumpur, Malaysia',
    phone: '+603-2284 1122',
    whatsapp: '+6012-345 6789',
    doctors: [],
    operatingHours: '9:00 AM - 7:00 PM',
    kkmLicense: config.kkmLicense || 'KKM/JPS/KL/2024/0912',
    checkInUrl: 'https://suamisihat.clinic'
  });

  const activeSlides = $derived(
    config.slides && config.slides.length > 0
      ? config.slides.filter(s => s.enabled !== false)
      : []
  );

  const displaySlide = $derived<SignageSlide | null>(
    activeSlides.length > 0 ? activeSlides[currentSlide % activeSlides.length] : null
  );

  function getQueryBranch(): string | null {
    if (typeof window === 'undefined') return null;
    try {
      const hashPart = window.location.hash || '';
      if (hashPart.includes('?')) {
        const queryParams = new URLSearchParams(hashPart.split('?')[1]);
        if (queryParams.has('branch')) return queryParams.get('branch');
      }
      const searchParams = new URLSearchParams(window.location.search);
      if (searchParams.has('branch')) return searchParams.get('branch');
    } catch {
      // Fall through to default
    }
    return null;
  }

  function updateClock() {
    const now = new Date();
    currentTime = now.toLocaleTimeString('ms-MY', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true });
    currentDate = now.toLocaleDateString('ms-MY', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  }

  function playClinicChime() {
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const now = ctx.currentTime;

      // Tone 1: E5 (659.25 Hz)
      const osc1 = ctx.createOscillator();
      const gain1 = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(659.25, now);
      gain1.gain.setValueAtTime(0, now);
      gain1.gain.linearRampToValueAtTime(0.2, now + 0.05);
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.55);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.55);

      // Tone 2: C5 (523.25 Hz)
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(523.25, now + 0.22);
      gain2.gain.setValueAtTime(0, now + 0.22);
      gain2.gain.linearRampToValueAtTime(0.25, now + 0.27);
      gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.85);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(now + 0.22);
      osc2.stop(now + 0.85);
    } catch (err) {
      console.debug('[Signage] Audio chime skipped:', err);
    }
  }

  function speakTicketCall(ticket: string, room: string) {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;
    try {
      window.speechSynthesis.cancel();
      const formattedTicket = ticket.split('').join(' ');
      const text = `Nombor giliran, ${formattedTicket}. Sila ke, ${room}.`;
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'ms-MY';
      utterance.rate = 0.9;
      utterance.pitch = 1.0;
      setTimeout(() => {
        try {
          window.speechSynthesis.speak(utterance);
        } catch {
          // Ignore speech failures
        }
      }, 1100);
    } catch {
      // Speech synthesis unsupported or blocked
    }
  }

  function handleDataReceived(newConfig: SignageConfig) {
    if (!newConfig) return;

    const newTicket = newConfig.queue?.currentCall?.ticket || null;
    if (newTicket && newTicket !== previousTicket) {
      if (previousTicket !== null) {
        justCalled = true;
        if (flashTimeout) clearTimeout(flashTimeout);
        flashTimeout = setTimeout(() => { justCalled = false; }, 4000);

        if (newConfig.soundAlertEnabled !== false) {
          playClinicChime();
          speakTicketCall(newTicket, newConfig.queue?.currentCall?.room || 'Bilik Rawatan');
        }
      }
      previousTicket = newTicket;
    }

    config = newConfig;
    isOffline = false;
    resetSlideTimer();
  }

  async function fetchSignageData() {
    if (typeof navigator !== 'undefined' && !navigator.onLine) {
      isOffline = true;
      return;
    }

    const branchParam = getQueryBranch();
    const url = `/api/clinic/signage${branchParam ? `?branch=${encodeURIComponent(branchParam)}` : ''}`;

    try {
      const res = await fetch(url, { cache: 'no-store' });
      if (res.ok) {
        const json = await res.json();
        if (json.success && json.config) {
          handleDataReceived(json.config);
        }
      } else {
        isOffline = true;
      }
    } catch {
      isOffline = true;
    }
  }

  function resetSlideTimer() {
    if (slideTimer) clearInterval(slideTimer);
    const duration = Math.max(3, config.slideDurationSec || 10) * 1000;
    slideTimer = setInterval(() => {
      if (activeSlides.length > 0) {
        currentSlide = (currentSlide + 1) % activeSlides.length;
      }
    }, duration);
  }

  function handleSseSignageEvent(evt: any) {
    const detail = evt.detail || evt;
    if (detail && (detail.branchCode || detail.queue)) {
      handleDataReceived(detail);
    }
  }

  onMount(async () => {
    updateClock();
    clockTimer = setInterval(updateClock, 1000);

    await fetchSignageData();
    resetSlideTimer();

    // Heartbeat polling every 5 seconds for sub-5s real-time accuracy across independent TV boxes
    pollTimer = setInterval(fetchSignageData, 5000);

    if (typeof window !== 'undefined') {
      window.addEventListener('online', () => { isOffline = false; fetchSignageData(); });
      window.addEventListener('offline', () => { isOffline = true; });
      window.addEventListener('signage:updated', handleSseSignageEvent as EventListener);
    }
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('signage:updated', handleSseSignageEvent as EventListener);
    }
    if (slideTimer) clearInterval(slideTimer);
    if (clockTimer) clearInterval(clockTimer);
    if (pollTimer) clearInterval(pollTimer);
    if (flashTimeout) clearTimeout(flashTimeout);
  });
</script>

<div class="signage-kiosk">
  <!-- Top Bar -->
  <header class="signage-header">
    <div class="header-brand">
      <div class="brand-logo-badge">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="#21A1F7">
          <circle cx="12" cy="12" r="10" fill="none" stroke="#21A1F7" stroke-width="2.5"/>
          <path d="M12 6v12M6 12h12" stroke="#21A1F7" stroke-width="2.5" stroke-linecap="round"/>
        </svg>
        <div class="brand-text">
          <span class="brand-title">SUAMISIHAT CLINIC</span>
          <span class="brand-branch">{branch.name}</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      {#if appState.currentUser}
        <a href="#dashboard" class="exit-portal-link" title="Return to SS-CAM Portal">
          ← Return to Portal
        </a>
      {/if}
      {#if isOffline}
        <div class="offline-pill" role="status" aria-live="polite">
          <span class="offline-dot"></span>
          <span>Offline Mode • Cached Schedule</span>
        </div>
      {:else}
        <div class="live-pill" role="status" aria-live="polite" title="Live synchronized with clinic reception">
          <span class="live-dot"></span>
          <span>Live Sync</span>
        </div>
      {/if}
      <div class="license-pill">LESEN KKM: {config.effectiveLicense || branch.kkmLicense || config.kkmLicense}</div>
      <div class="clock-display">
        <span class="clock-time">{currentTime}</span>
        <span class="clock-date">{currentDate}</span>
      </div>
    </div>
  </header>

  <!-- Main Billboard Arena -->
  <main class="signage-arena">
    <!-- Active Slide Showcase -->
    <div class="slide-card">
      {#if displaySlide}
        <div class="slide-tag">{displaySlide.tag}</div>
        <h1 class="slide-title">{displaySlide.title}</h1>
        <p class="slide-subtitle">{displaySlide.subtitle}</p>

        {#if displaySlide.type === 'doctors'}
          <!-- Doctor Spotlight Card -->
          <div class="doctor-roster-grid">
            {#if branch.doctors && branch.doctors.length > 0}
              {#each branch.doctors as doc, idx}
                <div class="doctor-badge">
                  <div class="doctor-avatar">👨‍⚕️</div>
                  <div class="doctor-info">
                    <div class="doc-label">Doktor Bertugas {idx + 1}</div>
                    <div class="doc-name">{doc}</div>
                    <div class="doc-status">🟢 Tersedia untuk Konsultasi</div>
                  </div>
                </div>
              {/each}
            {:else}
              <div class="doctor-badge">
                <div class="doctor-avatar">👨‍⚕️</div>
                <div class="doctor-info">
                  <div class="doc-label">Doktor Bertugas</div>
                  <div class="doc-name">Pakar Perubatan Lelaki Bertugas</div>
                  <div class="doc-status">🟢 Kaunter Dibuka</div>
                </div>
              </div>
            {/if}
          </div>
        {:else if displaySlide.type === 'eswt'}
          <!-- ESWT Shockwave Spotlight -->
          <div class="tech-graphic-grid">
            <div class="tech-feature-card">
              <div class="tech-icon">⚡</div>
              <div class="tech-headline">Gelombang Akustik</div>
              <div class="tech-desc">Menembusi tisu lembut untuk mengaktifkan pertumbuhan salur darah baharu.</div>
            </div>
            <div class="tech-feature-card">
              <div class="tech-icon">🛡️</div>
              <div class="tech-headline">100% Non-Invasif</div>
              <div class="tech-desc">Tanpa pembedahan, tanpa bius, dan pesakit boleh pulang segera.</div>
            </div>
            <div class="tech-feature-card">
              <div class="tech-icon">📈</div>
              <div class="tech-headline">Kadar Kejayaan 80%+</div>
              <div class="tech-desc">Terbukti melalui ujian klinikal antarabangsa untuk kesihatan vaskular.</div>
            </div>
          </div>
        {:else if displaySlide.type === 'trt'}
          <!-- TRT Spotlight -->
          <div class="tech-graphic-grid">
            <div class="tech-feature-card">
              <div class="tech-icon">🩸</div>
              <div class="tech-headline">Ujian Darah Komprehensif</div>
              <div class="tech-desc">Pemantauan paras hormon dan penanda biometrik darah setiap 12 minggu.</div>
            </div>
            <div class="tech-feature-card">
              <div class="tech-icon">🔋</div>
              <div class="tech-headline">Peningkatan Tenaga</div>
              <div class="tech-desc">Menghapuskan keletihan kronik, memulihkan stamina dan pembentukan otot.</div>
            </div>
            <div class="tech-feature-card">
              <div class="tech-icon">🧠</div>
              <div class="tech-headline">Fokus & Ketajaman Minda</div>
              <div class="tech-desc">Mengurangkan 'brain fog' dan menyokong kestabilan emosi optimum.</div>
            </div>
          </div>
        {:else if displaySlide.type === 'intake'}
          <!-- Intake Check-In -->
          <div class="qr-intake-showcase">
            <div class="qr-placeholder">
              <svg width="180" height="180" viewBox="0 0 100 100" fill="#022057">
                <rect x="10" y="10" width="30" height="30" rx="4"/>
                <rect x="15" y="15" width="20" height="20" fill="#FFFFFF"/>
                <rect x="20" y="20" width="10" height="10" fill="#022057"/>
                <rect x="60" y="10" width="30" height="30" rx="4"/>
                <rect x="65" y="15" width="20" height="20" fill="#FFFFFF"/>
                <rect x="70" y="20" width="10" height="10" fill="#022057"/>
                <rect x="10" y="60" width="30" height="30" rx="4"/>
                <rect x="15" y="65" width="20" height="20" fill="#FFFFFF"/>
                <rect x="20" y="70" width="10" height="10" fill="#022057"/>
                <rect x="45" y="45" width="15" height="15" fill="#21A1F7"/>
                <rect x="45" y="15" width="8" height="20"/>
                <rect x="15" y="45" width="20" height="8"/>
                <rect x="65" y="45" width="25" height="8"/>
                <rect x="45" y="70" width="45" height="20"/>
              </svg>
            </div>
            <div class="qr-instructions">
              <div class="qr-inst-title">Imbas Kod QR di Telefon Pintar Anda</div>
              <div class="qr-inst-step">1. Buka kamera telefon anda dan halakan ke skrin ini.</div>
              <div class="qr-inst-step">2. Tekan pautan pendaftaran ({branch.shortName}) untuk daftar giliran pantas.</div>
              <div class="qr-inst-step">3. Kakitangan klinik akan memanggil nombor giliran anda dengan serta-merta.</div>
            </div>
          </div>
        {:else}
          <!-- Generic Dynamic Notice Slide -->
          <div class="custom-notice-card">
            <div class="notice-icon-large">📢</div>
            <div class="notice-body-text">
              <h3>{displaySlide.title}</h3>
              <p>{displaySlide.subtitle}</p>
            </div>
          </div>
        {/if}
      {:else}
        <div class="slide-empty">
          <div class="slide-tag">SUAMISIHAT CLINIC</div>
          <h1 class="slide-title">Selamat Datang ke {branch.name}</h1>
          <p class="slide-subtitle">Sedia membantu anda dengan bimbingan klinikal peribadi dan sulit.</p>
        </div>
      {/if}
    </div>

    <!-- Live Queue Call Sidebar -->
    <aside class="signage-queue-panel">
      <div class="queue-header">
        <span class="queue-icon">🔔</span>
        <span class="queue-title">PANGGILAN GILIRAN</span>
      </div>

      <div class="queue-current-call" class:just-called={justCalled}>
        <div class="call-badge">NOMBOR TERKINI</div>
        {#if config.queue?.currentCall?.ticket}
          <div class="call-number">{config.queue.currentCall.ticket}</div>
          <div class="call-room">{config.queue.currentCall.room || 'Bilik Rawatan'}</div>
          {#if config.queue.currentCall.doctor}
            <div class="call-doc">{config.queue.currentCall.doctor}</div>
          {/if}
        {:else}
          <div class="call-number idle-number">---</div>
          <div class="call-room">Sedia untuk Panggilan</div>
          <div class="call-doc">Sila tunggu giliran anda</div>
        {/if}
      </div>

      <div class="queue-upcoming">
        <div class="upcoming-label">Giliran Seterusnya:</div>
        {#if config.queue?.upcoming && config.queue.upcoming.length > 0}
          {#each config.queue.upcoming as item}
            <div class="upcoming-item">
              <span class="up-num">{item.ticket}</span>
              <span class="up-dest">{item.room || 'Kaunter Saringan'}</span>
            </div>
          {/each}
        {:else}
          <div class="upcoming-empty">Tiada giliran menunggu saat ini</div>
        {/if}
      </div>

      <div class="branch-contact-box">
        <div class="cb-label">Bantuan Kaunter:</div>
        <div class="cb-val">{branch.phone}</div>
        <div class="cb-wa">WhatsApp: {branch.whatsapp}</div>
      </div>
    </aside>
  </main>

  <!-- Bottom Running Ticker -->
  {#if config.ticker && config.ticker.enabled !== false}
    <footer class="signage-footer">
      <div class="ticker-prefix">{config.ticker.prefix || 'INFO KLINIK'}</div>
      <div class="ticker-content">
        <div class="ticker-text">
          {config.ticker.text}
        </div>
      </div>
    </footer>
  {/if}
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: #020C1F;
    font-family: var(--font-family, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif);
  }

  .signage-kiosk {
    width: 100vw;
    height: 100vh;
    display: flex;
    flex-direction: column;
    background: radial-gradient(circle at 15% 20%, #061938 0%, #020C1F 100%);
    color: #F8FAFC;
    overflow: hidden;
    user-select: none;
  }

  /* Header */
  .signage-header {
    height: 80px;
    padding: 0 40px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(4, 20, 48, 0.7);
    backdrop-filter: blur(16px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    flex-shrink: 0;
  }

  .header-brand {
    display: flex;
    align-items: center;
  }

  .brand-logo-badge {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .brand-text {
    display: flex;
    flex-direction: column;
  }

  .brand-title {
    font-size: 18px;
    font-weight: 800;
    letter-spacing: 1.5px;
    color: #FFFFFF;
  }

  .brand-branch {
    font-size: 12px;
    color: #21A1F7;
    font-weight: 600;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 20px;
  }

  .exit-portal-link {
    color: #94A3B8;
    text-decoration: none;
    font-size: 12px;
    font-weight: 600;
    padding: 6px 12px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .exit-portal-link:hover {
    color: #FFFFFF;
    background: rgba(255, 255, 255, 0.12);
  }

  .offline-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #FCA5A5;
    padding: 4px 10px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
  }

  .offline-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #EF4444;
  }

  .live-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.3);
    color: #6EE7B7;
    padding: 4px 10px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
  }

  .live-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #10B981;
    animation: livePulseDot 2s infinite ease-in-out;
  }

  @keyframes livePulseDot {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.4; transform: scale(0.8); }
  }

  .license-pill {
    background: rgba(33, 161, 247, 0.1);
    border: 1px solid rgba(33, 161, 247, 0.25);
    color: #BAE6FD;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.5px;
  }

  .clock-display {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }

  .clock-time {
    font-size: 20px;
    font-weight: 800;
    color: #FFFFFF;
    font-variant-numeric: tabular-nums;
  }

  .clock-date {
    font-size: 11px;
    color: #94A3B8;
  }

  /* Main Arena */
  .signage-arena {
    flex: 1;
    display: grid;
    grid-template-columns: 1fr 380px;
    gap: 32px;
    padding: 32px 40px;
    overflow: hidden;
  }

  /* Slide Showcase */
  .slide-card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 24px;
    padding: 48px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    position: relative;
    overflow: hidden;
    backdrop-filter: blur(10px);
  }

  .slide-tag {
    font-size: 13px;
    font-weight: 800;
    letter-spacing: 2px;
    color: #21A1F7;
    margin-bottom: 16px;
    text-transform: uppercase;
  }

  .slide-title {
    font-size: 44px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0 0 16px 0;
    line-height: 1.15;
    letter-spacing: -0.5px;
  }

  .slide-subtitle {
    font-size: 20px;
    color: #94A3B8;
    margin: 0 0 40px 0;
    line-height: 1.5;
    max-width: 800px;
  }

  /* Doctor Roster */
  .doctor-roster-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 20px;
  }

  .doctor-badge {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    align-items: center;
    gap: 18px;
  }

  .doctor-avatar {
    font-size: 40px;
    background: rgba(33, 161, 247, 0.15);
    width: 64px;
    height: 64px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 16px;
  }

  .doctor-info {
    display: flex;
    flex-direction: column;
  }

  .doc-label {
    font-size: 11px;
    font-weight: 700;
    color: #21A1F7;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 4px;
  }

  .doc-name {
    font-size: 17px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 6px;
  }

  .doc-status {
    font-size: 12px;
    color: #6EE7B7;
    font-weight: 600;
  }

  /* Tech Cards */
  .tech-graphic-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
  }

  .tech-feature-card {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    flex-direction: column;
  }

  .tech-icon {
    font-size: 32px;
    margin-bottom: 16px;
  }

  .tech-headline {
    font-size: 18px;
    font-weight: 700;
    color: #BAE6FD;
    margin-bottom: 8px;
  }

  .tech-desc {
    font-size: 13px;
    color: #94A3B8;
    line-height: 1.5;
  }

  /* QR Showcase */
  .qr-intake-showcase {
    display: flex;
    align-items: center;
    gap: 40px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 20px;
    padding: 32px;
  }

  .qr-placeholder {
    background: #FFFFFF;
    padding: 16px;
    border-radius: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  }

  .qr-instructions {
    display: flex;
    flex-direction: column;
  }

  .qr-inst-title {
    font-size: 24px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 16px;
  }

  .qr-inst-step {
    font-size: 16px;
    color: #CBD5E1;
    margin-bottom: 10px;
    line-height: 1.4;
  }

  /* Custom Notice Card */
  .custom-notice-card {
    display: flex;
    align-items: center;
    gap: 32px;
    background: rgba(33, 161, 247, 0.08);
    border: 1px solid rgba(33, 161, 247, 0.25);
    border-radius: 20px;
    padding: 36px;
  }

  .notice-icon-large {
    font-size: 54px;
    background: rgba(33, 161, 247, 0.15);
    width: 90px;
    height: 90px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 20px;
    flex-shrink: 0;
  }

  .notice-body-text h3 {
    font-size: 24px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0 0 10px 0;
  }

  .notice-body-text p {
    font-size: 17px;
    color: #CBD5E1;
    line-height: 1.5;
    margin: 0;
  }

  .slide-empty {
    padding: 24px 0;
  }

  /* Queue Panel */
  .signage-queue-panel {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 24px;
    padding: 28px;
    display: flex;
    flex-direction: column;
  }

  .queue-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 24px;
    padding-bottom: 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .queue-icon {
    font-size: 20px;
  }

  .queue-title {
    font-size: 14px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #BAE6FD;
  }

  .queue-current-call {
    background: linear-gradient(135deg, rgba(33, 161, 247, 0.15) 0%, rgba(4, 51, 136, 0.3) 100%);
    border: 2px solid #21A1F7;
    border-radius: 18px;
    padding: 24px;
    text-align: center;
    margin-bottom: 24px;
    box-shadow: 0 10px 30px rgba(33, 161, 247, 0.2);
    transition: all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
  }

  .queue-current-call.just-called {
    border-color: #38BDF8;
    animation: callPulse 1.2s cubic-bezier(0.2, 0.8, 0.2, 1) infinite;
  }

  @keyframes callPulse {
    0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(33, 161, 247, 0.7); }
    50% { transform: scale(1.03); box-shadow: 0 0 0 16px rgba(33, 161, 247, 0); }
    100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(33, 161, 247, 0); }
  }

  .call-badge {
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #6DC6EC;
    margin-bottom: 6px;
  }

  .call-number {
    font-size: 56px;
    font-weight: 900;
    color: #FFFFFF;
    line-height: 1;
    margin-bottom: 10px;
    letter-spacing: 2px;
  }

  .call-number.idle-number {
    font-size: 40px;
    color: #64748B;
  }

  .call-room {
    font-size: 17px;
    font-weight: 700;
    color: #21A1F7;
    margin-bottom: 4px;
  }

  .call-doc {
    font-size: 12px;
    color: #94A3B8;
  }

  .queue-upcoming {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 24px;
  }

  .upcoming-label {
    font-size: 12px;
    font-weight: 700;
    color: #94A3B8;
    margin-bottom: 4px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .upcoming-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 10px;
    padding: 12px 16px;
  }

  .up-num {
    font-size: 16px;
    font-weight: 800;
    color: #FFFFFF;
  }

  .up-dest {
    font-size: 12px;
    color: #94A3B8;
  }

  .upcoming-empty {
    font-size: 13px;
    color: #64748B;
    text-align: center;
    padding: 16px 0;
    font-style: italic;
  }

  .branch-contact-box {
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 14px 16px;
  }

  .cb-label {
    font-size: 11px;
    font-weight: 700;
    color: #64748B;
    text-transform: uppercase;
    margin-bottom: 4px;
  }

  .cb-val, .cb-wa {
    font-size: 12px;
    color: #CBD5E1;
    font-weight: 600;
    margin-bottom: 2px;
  }

  /* Running Ticker */
  .signage-footer {
    height: 54px;
    background: #043388;
    display: flex;
    align-items: center;
    flex-shrink: 0;
    overflow: hidden;
    border-top: 1px solid rgba(255, 255, 255, 0.15);
  }

  .ticker-prefix {
    background: #21A1F7;
    color: #FFFFFF;
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 1px;
    height: 100%;
    display: flex;
    align-items: center;
    padding: 0 24px;
    z-index: 2;
    box-shadow: 4px 0 12px rgba(0, 0, 0, 0.2);
    white-space: nowrap;
  }

  .ticker-content {
    flex: 1;
    overflow: hidden;
    white-space: nowrap;
    position: relative;
  }

  .ticker-text {
    display: inline-block;
    padding-left: 100%;
    animation: marqueeTicker 30s linear infinite;
    font-size: 14px;
    font-weight: 600;
    color: #FFFFFF;
    letter-spacing: 0.5px;
  }

  @keyframes marqueeTicker {
    0% { transform: translate3d(0, 0, 0); }
    100% { transform: translate3d(-100%, 0, 0); }
  }

  @media (max-width: 1024px) {
    .signage-arena {
      grid-template-columns: 1fr;
    }
  }
</style>

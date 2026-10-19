<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import QRCode from 'qrcode';

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
    tag?: string;
    title: string;
    subtitle?: string;
    type: string; // 'banner' | 'video' | 'notice' | 'doctors' | 'eswt' | 'trt' | 'intake'
    src?: string;
    muted?: boolean;
    durationSec?: number;
    fit?: 'cover' | 'contain';
    fullScreen?: boolean;
    alt?: string;
    startsAt?: string | null;
    endsAt?: string | null;
  }

  interface SignageConfig {
    branchCode: string;
    branchMissing?: boolean;
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
      doctors: ['Dr. Azlan Shah, MD (Cyberjaya)', 'Dr. Farhan Kamil, MBBS (Malaya)'],
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
  let previousCallKey = $state<string | null>(null);
  let videoEl = $state<HTMLVideoElement | null>(null);
  let logoLoadError = $state(false);

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

  // Schedule filtering (D4): only show slides within startsAt and endsAt window
  const activeSlides = $derived(
    config.slides && config.slides.length > 0
      ? config.slides.filter(s => {
          if (s.enabled === false) return false;
          const now = Date.now();
          if (s.startsAt && new Date(s.startsAt).getTime() > now) return false;
          if (s.endsAt && new Date(s.endsAt).getTime() < now) return false;
          return true;
        })
      : []
  );

  const displaySlide = $derived<SignageSlide | null>(
    activeSlides.length > 0 ? activeSlides[currentSlide % activeSlides.length] : null
  );

  // Slide advancement and timing
  const slideKey = $derived(displaySlide ? `${displaySlide.id}|${displaySlide.type}|${displaySlide.src || ''}` : '');
  const slideIsVideo = $derived(displaySlide?.type === 'video');
  const slideCount = $derived(activeSlides.length);
  const slideMs = $derived(
    displaySlide?.durationSec
      ? Math.max(3, displaySlide.durationSec) * 1000
      : Math.max(3, config.slideDurationSec || 10) * 1000
  );

  // Real QR code generated from branch's checkInUrl
  let checkInQr = $state('');
  $effect(() => {
    const url = branch.checkInUrl;
    if (!url || !/^https?:\/\//i.test(url)) { checkInQr = ''; return; }
    let cancelled = false;
    QRCode.toString(url, {
      type: 'svg',
      margin: 1,
      errorCorrectionLevel: 'M',
      color: { dark: '#022057', light: '#FFFFFF' }
    })
      .then((svg: string) => { if (!cancelled) checkInQr = svg; })
      .catch((err: unknown) => {
        console.warn('[Signage] QR generation failed:', err);
        if (!cancelled) checkInQr = '';
      });
    return () => { cancelled = true; };
  });

  function advanceSlide() {
    if (slideCount > 1) {
      currentSlide = (currentSlide + 1) % slideCount;
    }
  }

  // Timer effect for standard and banner slides
  $effect(() => {
    void slideKey;
    if (slideTimer) { clearTimeout(slideTimer); slideTimer = null; }
    if (slideIsVideo || slideCount <= 1) return;
    const ms = slideMs;
    slideTimer = setTimeout(advanceSlide, ms);
    return () => {
      if (slideTimer) { clearTimeout(slideTimer); slideTimer = null; }
    };
  });

  // Preload next banner image in background to ensure zero flicker
  $effect(() => {
    if (slideCount > 1) {
      const nextIdx = (currentSlide + 1) % slideCount;
      const nextSlide = activeSlides[nextIdx];
      if (nextSlide?.type === 'banner' && nextSlide.src) {
        const pre = new Image();
        pre.src = nextSlide.src;
      }
    }
  });

  function onVideoReady(e: Event) {
    const v = e.currentTarget as HTMLVideoElement;
    v.play().catch(() => {
      v.muted = true;
      v.play().catch(err => console.debug('[Signage] Video autoplay blocked:', err));
    });
  }

  function onVideoError() {
    console.warn('[Signage] Video failed to load, skipping to next slide');
    if (slideTimer) clearTimeout(slideTimer);
    slideTimer = setTimeout(advanceSlide, 3000);
  }

  function onBannerError() {
    console.warn('[Signage] Banner image failed to load, skipping to next slide');
    if (slideTimer) clearTimeout(slideTimer);
    slideTimer = setTimeout(advanceSlide, 3000);
  }

  function duckVideo() {
    if (!videoEl || videoEl.muted) return;
    const v = videoEl;
    v.volume = 0.15;
    setTimeout(() => {
      try { v.volume = 1; } catch { /* noop */ }
    }, 6000);
  }

  function isPreviewMode(): boolean {
    if (typeof window === 'undefined') return false;
    try {
      const hashPart = window.location.hash || '';
      return hashPart.includes('preview=1') || window.location.search.includes('preview=1');
    } catch {
      return false;
    }
  }

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
    if (isPreviewMode()) return; // Never play audio in preview mode
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
      gain1.gain.linearRampToValueAtTime(0.25, now + 0.05);
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
      gain2.gain.linearRampToValueAtTime(0.3, now + 0.27);
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
    if (isPreviewMode() || typeof window === 'undefined' || !('speechSynthesis' in window)) return;
    try {
      window.speechSynthesis.cancel();
      const formattedTicket = ticket.split('').join(' ');
      const text = `Nombor giliran, ${formattedTicket}. Sila ke, ${room}.`;
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'ms-MY';
      utterance.rate = 0.9;
      utterance.pitch = 1.0;
      setTimeout(() => {
        try { window.speechSynthesis.speak(utterance); } catch { /* noop */ }
      }, 1100);
    } catch {
      // Speech synthesis unsupported or blocked
    }
  }

  function handleDataReceived(newConfig: SignageConfig) {
    if (!newConfig) return;

    const call = newConfig.queue?.currentCall;
    const newCallKey = call?.ticket ? `${call.ticket}|${call.calledAt || ''}` : null;
    if (newCallKey && newCallKey !== previousCallKey) {
      if (previousCallKey !== null) {
        justCalled = true;
        if (flashTimeout) clearTimeout(flashTimeout);
        flashTimeout = setTimeout(() => { justCalled = false; }, 4500);

        if (newConfig.soundAlertEnabled !== false) {
          duckVideo();
          playClinicChime();
          speakTicketCall(call!.ticket, call!.room || 'Bilik Rawatan');
        }
      }
      previousCallKey = newCallKey;
    } else if (!newCallKey) {
      previousCallKey = null;
    }

    config = newConfig;
    isOffline = false;
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

  function handleSseSignageEvent(evt: any) {
    const detail = evt.detail || evt;
    if (getQueryBranch()) {
      fetchSignageData();
      return;
    }
    if (detail && (detail.branchCode || detail.queue)) {
      handleDataReceived(detail);
    }
  }

  onMount(async () => {
    updateClock();
    clockTimer = setInterval(updateClock, 1000);
    await fetchSignageData();
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
    if (slideTimer) clearTimeout(slideTimer);
    if (clockTimer) clearInterval(clockTimer);
    if (pollTimer) clearInterval(pollTimer);
    if (flashTimeout) clearTimeout(flashTimeout);
  });
</script>

<div class="signage-kiosk">
  <!-- ═══ MISSING / ARCHIVED BRANCH SAFEGUARD SCREEN ═══════════════ -->
  {#if config.branchMissing}
    <div class="missing-branch-overlay" role="alert">
      <div class="missing-branch-card">
        <div class="missing-branch-icon">
          <FluentIcons name="warning" />
        </div>
        <h1 class="missing-branch-title">Skrin TV Ini Belum Ditetapkan ke Cawangan</h1>
        <p class="missing-branch-sub">
          Cawangan yang diminta telah diarkibkan atau belum wujud. Skrin ini dilindungi untuk mengelakkan paparan maklumat atau lesen yang tidak sepadan.
        </p>
        <div class="missing-branch-badge">
          Kod Cawangan: {getQueryBranch() || 'Tidak Dinyatakan'}
        </div>
        <p class="missing-branch-hint">
          Sila konfigurasikan cawangan ini di portal Studio Display atau kemas kini pautan TV anda.
        </p>
      </div>
    </div>
  {:else}
    <!-- ═══ FULLSCREEN BANNER CALL OVERLAY (D3 SAFEGUARD) ═══════════ -->
    {#if displaySlide?.fullScreen && justCalled && config.queue?.currentCall}
      <div class="fs-call-overlay" role="alert">
        <div class="fs-call-card">
          <span class="fs-call-badge">NOMBOR TERKINI</span>
          <span class="fs-call-number">{config.queue.currentCall.ticket}</span>
          <span class="fs-call-room">{config.queue.currentCall.room || 'Bilik Rawatan'}</span>
          {#if config.queue.currentCall.doctor}
            <span class="fs-call-doctor">{config.queue.currentCall.doctor}</span>
          {/if}
        </div>
      </div>
    {/if}

    <!-- ═══ TOP HEADER BAR ═════════════════════════════════════════ -->
    <header class="signage-header">
      <div class="header-brand">
        {#if !logoLoadError}
          <img
            src="/brand/suamisihat-logo-on-dark.svg"
            alt="SuamiSihat Clinic"
            class="brand-logo-svg"
            onerror={() => (logoLoadError = true)}
          />
        {/if}
        <div class="brand-text-block">
          <span class="brand-clinic-name">SUAMISIHAT CLINIC</span>
          <span class="brand-branch-name">{branch.name}</span>
        </div>
      </div>

      <div class="header-status-group">
        {#if appState.currentUser && !isPreviewMode()}
          <a href="#dashboard" class="portal-return-link" title="Return to SS-CAM Portal">
            ← Kembali ke Portal
          </a>
        {/if}

        {#if isOffline}
          <div class="status-pill offline" role="status" aria-live="polite">
            <span class="status-dot"></span>
            <span>Mod Luar Talian</span>
          </div>
        {:else}
          <div class="status-pill online" role="status" aria-live="polite" title="Live synchronized with reception">
            <span class="status-dot"></span>
            <span>Live Sync</span>
          </div>
        {/if}

        <div class="license-tag" title="KKM Establishment Licence">
          LESEN KKM: {config.effectiveLicense || branch.kkmLicense || config.kkmLicense || 'DISEMAK'}
        </div>

        <div class="tv-clock">
          <span class="tv-time">{currentTime}</span>
          <span class="tv-date">{currentDate}</span>
        </div>
      </div>
    </header>

    <!-- ═══ MAIN ARENA ═══════════════════════════════════════════════ -->
    <main class="signage-arena" class:is-fullscreen={displaySlide?.fullScreen}>
      <!-- Left/Main: Slide Showcase -->
      <section class="slide-card" class:banner-mode={displaySlide?.type === 'banner'}>
        {#if displaySlide}
          <!-- Slide Header for text-based cards -->
          {#if displaySlide.type !== 'video' && displaySlide.type !== 'banner'}
            <div class="slide-tag">{displaySlide.tag || TYPE_LABEL[displaySlide.type] || 'KLINIK'}</div>
            <h1 class="slide-title">{displaySlide.title}</h1>
            {#if displaySlide.subtitle}
              <p class="slide-subtitle">{displaySlide.subtitle}</p>
            {/if}
          {/if}

          <!-- 1. BANNER IMAGE SLIDE -->
          {#if displaySlide.type === 'banner' && displaySlide.src}
            <div class="banner-stage" class:contain-mode={displaySlide.fit === 'contain'}>
              <img
                src={displaySlide.src}
                alt={displaySlide.alt || displaySlide.title || 'Clinic Banner'}
                class="banner-image"
                style="object-fit: {displaySlide.fit || 'cover'};"
                onerror={onBannerError}
              />
              {#if displaySlide.title || displaySlide.subtitle}
                <div class="banner-caption-strip">
                  {#if displaySlide.tag}
                    <span class="banner-caption-tag">{displaySlide.tag}</span>
                  {/if}
                  {#if displaySlide.title}
                    <h2 class="banner-caption-title">{displaySlide.title}</h2>
                  {/if}
                  {#if displaySlide.subtitle}
                    <p class="banner-caption-sub">{displaySlide.subtitle}</p>
                  {/if}
                </div>
              {/if}
            </div>

          <!-- 2. DOCTORS ON DUTY SLIDE -->
          {:else if displaySlide.type === 'doctors'}
            <div class="doctor-roster-grid">
              {#if branch.doctors && branch.doctors.length > 0}
                {#each branch.doctors as doc, idx}
                  <div class="doctor-badge">
                    <div class="doctor-icon-box">
                      <FluentIcons name="user" />
                    </div>
                    <div class="doctor-details">
                      <span class="doc-badge-label">Doktor Bertugas {idx + 1}</span>
                      <span class="doc-badge-name">{doc}</span>
                      <span class="doc-badge-status">🟢 Tersedia untuk Konsultasi</span>
                    </div>
                  </div>
                {/each}
              {:else}
                <div class="doctor-badge">
                  <div class="doctor-icon-box"><FluentIcons name="user" /></div>
                  <div class="doctor-details">
                    <span class="doc-badge-label">Doktor Bertugas</span>
                    <span class="doc-badge-name">Pakar Perubatan Lelaki Bertugas</span>
                    <span class="doc-badge-status">🟢 Kaunter Dibuka</span>
                  </div>
                </div>
              {/if}
            </div>

          <!-- 3. ESWT TREATMENT SLIDE -->
          {:else if displaySlide.type === 'eswt'}
            <div class="tech-graphic-grid">
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="bolt" /></div>
                <h3 class="tech-card-title">Gelombang Akustik</h3>
                <p class="tech-card-desc">Menembusi tisu lembut untuk mengaktifkan pertumbuhan salur darah baharu (neovaskularisasi).</p>
              </div>
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="checkmark" /></div>
                <h3 class="tech-card-title">100% Non-Invasif</h3>
                <p class="tech-card-desc">Tanpa pembedahan, tanpa bius, dan pesakit boleh pulang segera menjalani aktiviti harian.</p>
              </div>
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="rocket" /></div>
                <h3 class="tech-card-title">Kadar Kejayaan 80%+</h3>
                <p class="tech-card-desc">Terbukti melalui ujian klinikal antarabangsa untuk pemulihan fungsi vaskular lelaki.</p>
              </div>
            </div>

          <!-- 4. TRT TREATMENT SLIDE -->
          {:else if displaySlide.type === 'trt'}
            <div class="tech-graphic-grid">
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="timeline" /></div>
                <h3 class="tech-card-title">Ujian Darah Komprehensif</h3>
                <p class="tech-card-desc">Pemantauan paras hormon dan penanda biometrik darah berkala setiap 12 minggu.</p>
              </div>
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="bolt" /></div>
                <h3 class="tech-card-title">Peningkatan Tenaga</h3>
                <p class="tech-card-desc">Menghapuskan keletihan kronik, memulihkan stamina fizikal dan menyokong pembentukan otot.</p>
              </div>
              <div class="tech-feature-card">
                <div class="tech-icon-box"><FluentIcons name="sparkles" /></div>
                <h3 class="tech-card-title">Fokus & Ketajaman Minda</h3>
                <p class="tech-card-desc">Mengurangkan 'brain fog' dan menyokong kestabilan emosi serta tidur berkualiti.</p>
              </div>
            </div>

          <!-- 5. INTAKE CHECK-IN QR SLIDE -->
          {:else if displaySlide.type === 'intake'}
            <div class="intake-qr-container">
              <div class="qr-white-card">
                {#if checkInQr}
                  <div class="qr-render" role="img" aria-label="QR code for {branch.shortName} check-in">
                    {@html checkInQr}
                  </div>
                {:else}
                  <div class="qr-missing-msg">Pautan pendaftaran sedang dikemas kini</div>
                {/if}
              </div>
              <div class="qr-guide-text">
                <h2 class="qr-guide-title">Imbas Kod QR untuk Pendaftaran Pantas</h2>
                <div class="qr-guide-step"><strong>1.</strong> Buka kamera telefon pintar anda dan halakan ke kod QR ini.</div>
                <div class="qr-guide-step"><strong>2.</strong> Buka pautan pendaftaran <em>{branch.shortName}</em> untuk isi borang saringan ringkas.</div>
                <div class="qr-guide-step"><strong>3.</strong> Nombor giliran anda akan dipanggil pada skrin ini secara automatik.</div>
              </div>
            </div>

          <!-- 6. VIDEO SLIDE -->
          {:else if displaySlide.type === 'video' && displaySlide.src}
            {#key slideKey}
              <!-- svelte-ignore a11y_media_has_caption -->
              <video
                class="slide-video-element"
                bind:this={videoEl}
                src={displaySlide.src}
                muted={displaySlide.muted !== false}
                loop={slideCount <= 1}
                playsinline
                preload="auto"
                onloadeddata={onVideoReady}
                onended={advanceSlide}
                onerror={onVideoError}
              ></video>
            {/key}

          <!-- 7. NOTICE SLIDE (DYNAMIC) -->
          {:else}
            <div class="dynamic-notice-card">
              <div class="notice-icon-circle">
                <FluentIcons name="info" />
              </div>
              <div class="notice-text-content">
                <h2 class="notice-heading">{displaySlide.title}</h2>
                <p class="notice-body">{displaySlide.subtitle}</p>
              </div>
            </div>
          {/if}
        {:else}
          <div class="empty-billboard">
            <span class="slide-tag">SUAMISIHAT CLINIC</span>
            <h1 class="slide-title">Selamat Datang ke {branch.name}</h1>
            <p class="slide-subtitle">Sedia membantu anda dengan bimbingan klinikal peribadi dan sulit.</p>
          </div>
        {/if}
      </section>

      <!-- Right/Sidebar: Live Queue Calling Panel -->
      {#if !displaySlide?.fullScreen}
        <aside class="signage-queue-panel">
          <div class="queue-panel-head">
            <span class="queue-panel-icon"><FluentIcons name="bell" /></span>
            <span class="queue-panel-title">PANGGILAN GILIRAN</span>
          </div>

          <!-- Active Ticket Box: HIGH-VISIBILITY BANANA YELLOW CTA HIGHLIGHT -->
          <div class="queue-call-box" class:is-calling={justCalled}>
            <span class="queue-call-tag">NOMBOR TERKINI</span>
            {#if config.queue?.currentCall?.ticket}
              <div class="queue-call-number">{config.queue.currentCall.ticket}</div>
              <div class="queue-call-room">{config.queue.currentCall.room || 'Bilik Rawatan'}</div>
              {#if config.queue.currentCall.doctor}
                <div class="queue-call-doc">{config.queue.currentCall.doctor}</div>
              {/if}
            {:else}
              <div class="queue-call-number idle">---</div>
              <div class="queue-call-room">Sedia untuk Panggilan</div>
              <div class="queue-call-doc">Sila tunggu giliran anda</div>
            {/if}
          </div>

          <!-- Upcoming Tickets -->
          <div class="queue-upcoming-section">
            <span class="upcoming-heading">Giliran Seterusnya:</span>
            {#if config.queue?.upcoming && config.queue.upcoming.length > 0}
              <div class="upcoming-list">
                {#each config.queue.upcoming as item}
                  <div class="upcoming-row">
                    <span class="upcoming-ticket">{item.ticket}</span>
                    <span class="upcoming-room">{item.room || 'Kaunter Saringan'}</span>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="upcoming-empty-note">Tiada giliran menunggu saat ini</div>
            {/if}
          </div>

          <!-- Branch Contact Info -->
          <div class="branch-footer-contact">
            <span class="contact-lbl">Bantuan Kaunter:</span>
            <span class="contact-val">{branch.phone}</span>
            <span class="contact-sub">WhatsApp: {branch.whatsapp}</span>
          </div>
        </aside>
      {/if}
    </main>

    <!-- ═══ BOTTOM RUNNING TICKER ═══════════════════════════════════ -->
    {#if config.ticker && config.ticker.enabled !== false}
      <footer class="signage-footer">
        <div class="ticker-ribbon-tag">{config.ticker.prefix || 'INFO KLINIK'}</div>
        <div class="ticker-scroll-viewport">
          <div class="ticker-scroll-content">
            {config.ticker.text}
          </div>
        </div>
      </footer>
    {/if}
  {/if}
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: #020C1F;
    font-family: var(--font-family, 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif);
  }

  .signage-kiosk {
    /* ═══ PRUSSIAN NAVY CLINICAL GROUND + BANANA ACCENT ═══ */
    --kiosk-navy-900: #020C1F;
    --kiosk-navy-800: #022057;
    --kiosk-royal: #043388;
    --kiosk-azure: #21A1F7;
    --kiosk-malibu: #6DC6EC;
    --kiosk-banana: #FCE53D;
    --kiosk-neutral-black: #1C1C1C;
    --kiosk-card-bg: rgba(255, 255, 255, 0.04);
    --kiosk-border: rgba(255, 255, 255, 0.12);

    width: 100vw;
    height: 100vh;
    display: flex;
    flex-direction: column;
    background: radial-gradient(circle at 15% 20%, #061938 0%, #020C1F 100%);
    color: #F8FAFC;
    overflow: hidden;
    user-select: none;
    box-sizing: border-box;
  }

  /* ═══ HEADER ════════════════════════════════════════════════════ */
  .signage-header {
    height: 84px;
    padding: 0 40px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(4, 20, 48, 0.75);
    backdrop-filter: blur(16px);
    border-bottom: 1px solid var(--kiosk-border);
    flex-shrink: 0;
  }
  .header-brand {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  .brand-logo-svg {
    height: 38px;
    max-width: 180px;
    object-fit: contain;
  }
  .brand-text-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .brand-clinic-name {
    font-size: 19px;
    font-weight: 800;
    letter-spacing: 1.5px;
    color: #FFFFFF;
  }
  .brand-branch-name {
    font-size: 13.5px;
    color: var(--kiosk-azure);
    font-weight: 600;
  }

  .header-status-group {
    display: flex;
    align-items: center;
    gap: 20px;
  }
  .portal-return-link {
    color: #94A3B8;
    text-decoration: none;
    font-size: 13px;
    font-weight: 600;
    padding: 6px 14px;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid var(--kiosk-border);
    border-radius: 8px;
    transition: all 0.2s ease;
  }
  .portal-return-link:hover {
    color: #FFFFFF;
    background: rgba(255, 255, 255, 0.12);
  }

  .status-pill {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 13px;
    font-weight: 600;
  }
  .status-pill.online {
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.35);
    color: #6EE7B7;
  }
  .status-pill.offline {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.35);
    color: #FCA5A5;
  }
  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: currentColor;
    animation: livePulse 2s infinite ease-in-out;
  }
  @keyframes livePulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.4; transform: scale(0.8); }
  }

  .license-tag {
    background: rgba(33, 161, 247, 0.1);
    border: 1px solid rgba(33, 161, 247, 0.25);
    color: #BAE6FD;
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12.5px;
    font-weight: 700;
    letter-spacing: 0.5px;
  }

  .tv-clock {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }
  .tv-time {
    font-size: 22px;
    font-weight: 800;
    color: #FFFFFF;
    font-variant-numeric: tabular-nums;
  }
  .tv-date {
    font-size: 12px;
    color: #94A3B8;
  }

  /* ═══ MAIN ARENA ═══════════════════════════════════════════════ */
  .signage-arena {
    flex: 1;
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 32px;
    padding: 28px 40px;
    overflow: hidden;
    position: relative;
  }
  .signage-arena.is-fullscreen {
    grid-template-columns: 1fr;
    padding: 20px 40px;
  }

  /* Slide Card */
  .slide-card {
    background: var(--kiosk-card-bg);
    border: 1px solid var(--kiosk-border);
    border-radius: 24px;
    padding: 44px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    position: relative;
    overflow: hidden;
    backdrop-filter: blur(12px);
    box-sizing: border-box;
  }
  .slide-card.banner-mode {
    padding: 0;
    background: #000000;
  }

  .slide-tag {
    font-size: 14px;
    font-weight: 800;
    letter-spacing: 2px;
    color: var(--kiosk-azure);
    margin-bottom: 14px;
    text-transform: uppercase;
  }
  .slide-title {
    font-size: 46px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0 0 16px 0;
    line-height: 1.15;
    letter-spacing: -0.5px;
  }
  .slide-subtitle {
    font-size: 20px;
    color: #CBD5E1;
    margin: 0 0 36px 0;
    line-height: 1.5;
    max-width: 820px;
  }

  /* ═══ BANNER IMAGE SLIDE ════════════════════════════════════════ */
  .banner-stage {
    width: 100%;
    height: 100%;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #020C1F;
    overflow: hidden;
  }
  .banner-image {
    width: 100%;
    height: 100%;
    display: block;
    transition: opacity 0.4s ease;
  }
  .banner-caption-strip {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 24px 32px;
    background: linear-gradient(to top, rgba(2, 12, 31, 0.95) 0%, rgba(2, 12, 31, 0.6) 70%, transparent 100%);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .banner-caption-tag {
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    color: var(--kiosk-azure);
  }
  .banner-caption-title {
    font-size: 26px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0;
  }
  .banner-caption-sub {
    font-size: 16px;
    color: #CBD5E1;
    margin: 0;
    line-height: 1.4;
  }

  /* ═══ VIDEO SLIDE ═══════════════════════════════════════════════ */
  .slide-video-element {
    width: 100%;
    height: 100%;
    object-fit: contain;
    background: #000;
    border-radius: 16px;
  }

  /* ═══ DOCTORS SPOTLIGHT ═════════════════════════════════════════ */
  .doctor-roster-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }
  .doctor-badge {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--kiosk-border);
    border-radius: 18px;
    padding: 24px;
    display: flex;
    align-items: center;
    gap: 20px;
  }
  .doctor-icon-box {
    width: 64px;
    height: 64px;
    border-radius: 16px;
    background: rgba(33, 161, 247, 0.15);
    color: var(--kiosk-azure);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .doctor-icon-box :global(svg) {
    width: 32px;
    height: 32px;
  }
  .doctor-details {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .doc-badge-label {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--kiosk-azure);
  }
  .doc-badge-name {
    font-size: 18px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .doc-badge-status {
    font-size: 13px;
    color: #6EE7B7;
    font-weight: 600;
  }

  /* ═══ CLINICAL TECH CARDS (ESWT / TRT) ══════════════════════════ */
  .tech-graphic-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 24px;
  }
  .tech-feature-card {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--kiosk-border);
    border-radius: 18px;
    padding: 28px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .tech-icon-box {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    background: rgba(33, 161, 247, 0.15);
    color: var(--kiosk-azure);
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 8px;
  }
  .tech-icon-box :global(svg) {
    width: 26px;
    height: 26px;
  }
  .tech-card-title {
    font-size: 20px;
    font-weight: 800;
    color: #BAE6FD;
    margin: 0;
  }
  .tech-card-desc {
    font-size: 14px;
    color: #94A3B8;
    line-height: 1.5;
    margin: 0;
  }

  /* ═══ INTAKE QR SHOWCASE ════════════════════════════════════════ */
  .intake-qr-container {
    display: flex;
    align-items: center;
    gap: 40px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid var(--kiosk-border);
    border-radius: 20px;
    padding: 36px;
  }
  .qr-white-card {
    background: #FFFFFF;
    padding: 16px;
    border-radius: 16px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .qr-render {
    width: 220px;
    height: 220px;
  }
  .qr-render :global(svg) {
    width: 100%;
    height: 100%;
    display: block;
  }
  .qr-missing-msg {
    max-width: 200px;
    font-size: 14px;
    color: #022057;
    text-align: center;
  }
  .qr-guide-text {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .qr-guide-title {
    font-size: 24px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0 0 6px 0;
  }
  .qr-guide-step {
    font-size: 16px;
    color: #CBD5E1;
    line-height: 1.45;
  }

  /* ═══ DYNAMIC NOTICE CARD ═══════════════════════════════════════ */
  .dynamic-notice-card {
    display: flex;
    align-items: center;
    gap: 32px;
    background: rgba(33, 161, 247, 0.08);
    border: 1px solid rgba(33, 161, 247, 0.25);
    border-radius: 20px;
    padding: 40px;
  }
  .notice-icon-circle {
    width: 88px;
    height: 88px;
    border-radius: 22px;
    background: rgba(33, 161, 247, 0.18);
    color: var(--kiosk-azure);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .notice-icon-circle :global(svg) {
    width: 44px;
    height: 44px;
  }
  .notice-text-content {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .notice-heading {
    font-size: 28px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0;
  }
  .notice-body {
    font-size: 18px;
    color: #CBD5E1;
    line-height: 1.5;
    margin: 0;
  }

  /* ═══ LIVE QUEUE SIDEBAR (ATTENTION-GRABBING BANANA CTA) ════════ */
  .signage-queue-panel {
    background: var(--kiosk-card-bg);
    border: 1px solid var(--kiosk-border);
    border-radius: 24px;
    padding: 28px;
    display: flex;
    flex-direction: column;
  }
  .queue-panel-head {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 24px;
    padding-bottom: 14px;
    border-bottom: 1px solid var(--kiosk-border);
  }
  .queue-panel-icon {
    width: 22px;
    height: 22px;
    color: var(--kiosk-azure);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .queue-panel-icon :global(svg) {
    width: 100%;
    height: 100%;
  }
  .queue-panel-title {
    font-size: 15px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #BAE6FD;
  }

  /* Queue Call Box: BANANA YELLOW #FCE53D ON CALL */
  .queue-call-box {
    background: linear-gradient(135deg, rgba(33, 161, 247, 0.15) 0%, rgba(4, 51, 136, 0.35) 100%);
    border: 2px solid var(--kiosk-azure);
    border-radius: 18px;
    padding: 24px;
    text-align: center;
    margin-bottom: 24px;
    box-shadow: 0 10px 30px rgba(33, 161, 247, 0.2);
    transition: all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
  }
  .queue-call-box.is-calling {
    background: var(--kiosk-banana);
    border-color: var(--kiosk-banana);
    color: var(--kiosk-neutral-black);
    animation: bananaPulse 1.2s cubic-bezier(0.2, 0.8, 0.2, 1) infinite;
  }
  @keyframes bananaPulse {
    0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(252, 229, 61, 0.8); }
    50% { transform: scale(1.03); box-shadow: 0 0 0 20px rgba(252, 229, 61, 0); }
    100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(252, 229, 61, 0); }
  }

  .queue-call-tag {
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: #6DC6EC;
    margin-bottom: 6px;
    display: block;
  }
  .queue-call-box.is-calling .queue-call-tag {
    color: #5C3D00;
  }

  .queue-call-number {
    font-size: 58px;
    font-weight: 900;
    color: #FFFFFF;
    line-height: 1;
    margin-bottom: 10px;
    letter-spacing: 2px;
  }
  .queue-call-number.idle {
    font-size: 44px;
    color: #64748B;
  }
  .queue-call-box.is-calling .queue-call-number {
    color: var(--kiosk-neutral-black);
  }

  .queue-call-room {
    font-size: 18px;
    font-weight: 800;
    color: var(--kiosk-azure);
    margin-bottom: 4px;
  }
  .queue-call-box.is-calling .queue-call-room {
    color: var(--kiosk-royal);
  }

  .queue-call-doc {
    font-size: 13px;
    color: #CBD5E1;
  }
  .queue-call-box.is-calling .queue-call-doc {
    color: #333333;
    font-weight: 600;
  }

  /* Upcoming List */
  .queue-upcoming-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 24px;
  }
  .upcoming-heading {
    font-size: 12.5px;
    font-weight: 700;
    color: #94A3B8;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .upcoming-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .upcoming-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    padding: 12px 18px;
  }
  .upcoming-ticket {
    font-size: 18px;
    font-weight: 800;
    color: #FFFFFF;
  }
  .upcoming-room {
    font-size: 13px;
    color: #94A3B8;
  }
  .upcoming-empty-note {
    font-size: 13.5px;
    color: #64748B;
    text-align: center;
    padding: 20px 0;
    font-style: italic;
  }

  .branch-footer-contact {
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid var(--kiosk-border);
    border-radius: 14px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .contact-lbl {
    font-size: 11px;
    font-weight: 700;
    color: #64748B;
    text-transform: uppercase;
  }
  .contact-val {
    font-size: 13.5px;
    color: #FFFFFF;
    font-weight: 700;
  }
  .contact-sub {
    font-size: 12.5px;
    color: #94A3B8;
  }

  /* ═══ FULLSCREEN CALL OVERLAY (D3) ═══════════════════════════════ */
  .fs-call-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(2, 12, 31, 0.85);
    backdrop-filter: blur(20px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    animation: fsOverlayIn 0.3s ease-out;
  }
  @keyframes fsOverlayIn {
    from { opacity: 0; transform: scale(0.95); }
    to { opacity: 1; transform: scale(1); }
  }
  .fs-call-card {
    background: var(--kiosk-banana);
    color: var(--kiosk-neutral-black);
    padding: 48px 64px;
    border-radius: 32px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6), 0 0 0 16px rgba(252, 229, 61, 0.4);
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 12px;
  }
  .fs-call-badge {
    font-size: 16px;
    font-weight: 800;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: #5C3D00;
  }
  .fs-call-number {
    font-size: 96px;
    font-weight: 900;
    line-height: 1;
    letter-spacing: 4px;
    color: var(--kiosk-neutral-black);
  }
  .fs-call-room {
    font-size: 32px;
    font-weight: 800;
    color: var(--kiosk-royal);
  }
  .fs-call-doctor {
    font-size: 18px;
    font-weight: 600;
    color: #333333;
  }

  /* ═══ MISSING BRANCH SCREEN (T3.5) ═════════════════════════════ */
  .missing-branch-overlay {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 40px;
    background: radial-gradient(circle at center, #061938 0%, #020C1F 100%);
  }
  .missing-branch-card {
    max-width: 680px;
    background: rgba(255, 255, 255, 0.04);
    border: 2px solid var(--kiosk-border);
    border-radius: 28px;
    padding: 56px 48px;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 16px;
  }
  .missing-branch-icon {
    width: 64px;
    height: 64px;
    color: var(--kiosk-banana);
  }
  .missing-branch-icon :global(svg) {
    width: 100%;
    height: 100%;
  }
  .missing-branch-title {
    font-size: 32px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0;
    line-height: 1.25;
  }
  .missing-branch-sub {
    font-size: 17px;
    color: #CBD5E1;
    line-height: 1.5;
    margin: 0;
  }
  .missing-branch-badge {
    background: rgba(33, 161, 247, 0.15);
    border: 1px solid var(--kiosk-azure);
    color: #BAE6FD;
    padding: 8px 18px;
    border-radius: 20px;
    font-size: 15px;
    font-weight: 700;
  }
  .missing-branch-hint {
    font-size: 13px;
    color: #94A3B8;
    margin: 12px 0 0;
  }

  /* ═══ RUNNING TICKER ════════════════════════════════════════════ */
  .signage-footer {
    height: 56px;
    background: var(--kiosk-royal);
    display: flex;
    align-items: center;
    flex-shrink: 0;
    overflow: hidden;
    border-top: 1px solid rgba(255, 255, 255, 0.18);
  }
  .ticker-ribbon-tag {
    background: var(--kiosk-azure);
    color: #FFFFFF;
    font-size: 13px;
    font-weight: 800;
    letter-spacing: 1px;
    height: 100%;
    display: flex;
    align-items: center;
    padding: 0 28px;
    z-index: 2;
    box-shadow: 4px 0 12px rgba(0, 0, 0, 0.25);
    white-space: nowrap;
  }
  .ticker-scroll-viewport {
    flex: 1;
    overflow: hidden;
    white-space: nowrap;
    position: relative;
  }
  .ticker-scroll-content {
    display: inline-block;
    padding-left: 100%;
    animation: marqueeTicker 32s linear infinite;
    font-size: 15px;
    font-weight: 600;
    color: #FFFFFF;
    letter-spacing: 0.5px;
  }
  @keyframes marqueeTicker {
    0% { transform: translate3d(0, 0, 0); }
    100% { transform: translate3d(-100%, 0, 0); }
  }

  /* ═══ REDUCED MOTION SAFEGUARD ══════════════════════════════════ */
  @media (prefers-reduced-motion: reduce) {
    .ticker-scroll-content { animation: none; padding-left: 16px; }
    .status-dot { animation: none; }
    .queue-call-box.is-calling { animation: none; }
  }
</style>

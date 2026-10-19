<script lang="ts">
  import type { ConsultationLang } from '$lib/config/consultation.i18n';

  interface Props {
    phase?: number;
    lang?: ConsultationLang;
    patientMode?: boolean;
  }

  let {
    phase = 1,
    lang = 'ms',
    patientMode = false
  }: Props = $props();

  let isPlaying = $state(true);
  let activeHotspot = $state<number | null>(null);

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  const hotspots = $derived([
    {
      id: 1,
      x: 130,
      y: 190,
      title: lang === 'ms' ? 'Tubul Seminiferus & Sel Induk' : 'Seminiferous Tubules & Germ Cells',
      desc: lang === 'ms'
        ? 'Tapak permulaan spermatogenesis di dalam testis. Sel spermatogonia memulakan pembahagian mitosis untuk membentuk generasi sel sperma baharu.'
        : 'Origin site of spermatogenesis within the testicular tubules. Spermatogonia undergo mitotic division to initiate the sperm lineage.'
    },
    {
      id: 2,
      x: 340,
      y: 180,
      title: lang === 'ms' ? 'Pembahagian Meiosis & Sarung Mitokondria' : 'Meiosis & Mitochondrial Sheath',
      desc: lang === 'ms'
        ? 'Sel melalui fasa meiosis untuk mengurangkan separuh kromosom. Mitokondria berkumpul di bahagian leher bagi menjana tenaga ATP untuk motiliti.'
        : 'Meiotic reduction division halves genetic material. Mitochondria tightly spiral around the midpiece, providing ATP energy for swimming motility.'
    },
    {
      id: 3,
      x: 520,
      y: 175,
      title: lang === 'ms' ? 'Spermiogenesis & Tudung Akrosom' : 'Spermiogenesis & Acrosome Cap',
      desc: lang === 'ms'
        ? 'Diferensiasi bentuk sperma: pemadatan nukleus, pembentukan tudung akrosom berenzim, dan pemanjangan ekor flagelum.'
        : 'Morphological transformation: nuclear chromatin condensation, enzymatic acrosome cap formation, and flagellar tail elongation.'
    },
    {
      id: 4,
      x: 690,
      y: 195,
      title: lang === 'ms' ? 'Transit Epididimis & Pematangan WHO' : 'Epididymal Maturation & WHO Benchmark',
      desc: lang === 'ms'
        ? 'Sperma melalui transit 10-14 hari di epididimis untuk memperoleh keupayaan berenang progresif sebelum bersedia untuk analisis 12-minggu.'
        : 'Sperm undergo 10-14 day epididymal transit, gaining forward progressive motility prior to 12-week repeat laboratory benchmarking.'
    }
  ]);

  const whoParameters = $derived([
    {
      label: lang === 'ms' ? 'Kepekatan (Kiraan)' : 'Sperm Concentration',
      standard: '>= 16 juta / mL',
      metric: '>= 16 M/mL',
      status: phase >= 2 ? 'improving' : 'baseline'
    },
    {
      label: lang === 'ms' ? 'Motiliti Progresif' : 'Progressive Motility',
      standard: '>= 30% PR (>= 42% PR+NP)',
      metric: '>= 30% PR',
      status: phase >= 3 ? 'improving' : 'baseline'
    },
    {
      label: lang === 'ms' ? 'Vitaliti (Sperma Hidup)' : 'Vitality (Live Ratio)',
      standard: '>= 54% hidup',
      metric: '>= 54%',
      status: phase >= 2 ? 'improving' : 'baseline'
    },
    {
      label: lang === 'ms' ? 'Morfologi Normal' : 'Normal Morphology',
      standard: '>= 4% piawaian Kruger',
      metric: '>= 4% Kruger',
      status: phase === 4 ? 'improving' : 'baseline'
    }
  ]);

  function toggleHotspot(id: number) {
    activeHotspot = activeHotspot === id ? null : id;
  }
</script>

<div class="fertility-illustration-container" class:paused={!isPlaying} class:patient-mode={patientMode}>
  <!-- Controls Toolbar -->
  <div class="canvas-controls-toolbar">
    <div class="cct-left">
      <button
        class="ctrl-icon-btn"
        onclick={togglePlay}
        title={isPlaying ? (lang === 'ms' ? 'Jeda animasi' : 'Pause animation') : (lang === 'ms' ? 'Mainkan animasi' : 'Play animation')}
        aria-label={isPlaying ? 'Pause animation' : 'Play animation'}
      >
        {#if isPlaying}
          <svg viewBox="0 0 20 20" width="16" height="16" fill="currentColor">
            <rect x="5" y="4" width="3.5" height="12" rx="1" />
            <rect x="11.5" y="4" width="3.5" height="12" rx="1" />
          </svg>
        {:else}
          <svg viewBox="0 0 20 20" width="16" height="16" fill="currentColor">
            <polygon points="6,4 16,10 6,16" />
          </svg>
        {/if}
        <span class="ctrl-btn-text">
          {isPlaying ? (lang === 'ms' ? 'Jeda' : 'Pause') : (lang === 'ms' ? 'Main' : 'Play')}
        </span>
      </button>

      <span class="phase-indicator-tag">
        {lang === 'ms' ? `Fasa ${phase}` : `Phase ${phase}`}:
        {phase === 1
          ? (lang === 'ms' ? 'Ujian Garis Asas (Minggu 1)' : 'Baseline Test (Week 1)')
          : phase === 2
          ? (lang === 'ms' ? 'Infusi Selular & Meiosis (Minggu 2-6)' : 'Cellular Infusion & Meiosis (Wks 2-6)')
          : phase === 3
          ? (lang === 'ms' ? 'Spermiogenesis & Gaya Hidup (Minggu 7-9)' : 'Spermiogenesis & Lifestyle (Wks 7-9)')
          : (lang === 'ms' ? 'Analisis Ulangan Pasca-74 Hari (Minggu 12)' : 'Repeat Analysis Post-74 Days (Wk 12)')}
      </span>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '🔬 Manual Makmal Semen WHO Edisi Ke-6 (2021)' : '🔬 WHO Semen Laboratory Manual (6th Ed, 2021)'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    <svg
      viewBox="0 0 800 360"
      class="fertility-svg"
      role="img"
      aria-labelledby="fertility-svg-title fertility-svg-desc"
    >
      <title id="fertility-svg-title">
        {lang === 'ms' ? 'Simulasi Kitaran Spermatogenesis 12-Minggu' : '12-Week Spermatogenesis Biological Cycle Simulation'}
      </title>
      <desc id="fertility-svg-desc">
        {lang === 'ms'
          ? 'Garis masa biologi 74 hari pembentukan sel sperma berserta transit epididimis dan penanda aras kualiti semen WHO.'
          : '74-day biological spermatogenesis timeline showing cell differentiation stages, epididymal transit, and WHO semen benchmarks.'}
      </desc>

      <defs>
        <radialGradient id="fertilityBgGrad" cx="50%" cy="50%" r="60%">
          <stop offset="0%" stop-color="#08234D" />
          <stop offset="100%" stop-color="#020C1E" />
        </radialGradient>

        <linearGradient id="timelineProgGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#21A1F7" />
          <stop offset="50%" stop-color="#10B981" />
          <stop offset="100%" stop-color="#34D399" />
        </linearGradient>

        <linearGradient id="spermCellGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#67E8F9" />
          <stop offset="100%" stop-color="#38BDF8" />
        </linearGradient>

        <filter id="cellGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3" result="glow" />
          <feComposite in="SourceGraphic" in2="glow" operator="over" />
        </filter>
      </defs>

      <!-- Background Canvas -->
      <rect width="800" height="360" rx="16" fill="url(#fertilityBgGrad)" stroke="#0E3368" stroke-width="2" />

      <!-- Timeline Main Track (Week 0 to Week 12) -->
      <line x1="80" y1="180" x2="720" y2="180" stroke="rgba(255, 255, 255, 0.15)" stroke-width="4" stroke-linecap="round" />
      <!-- Animated Active Timeline Progress Line -->
      <line
        x1="80"
        y1="180"
        x2={80 + (phase / 4) * 640}
        y2="180"
        stroke="url(#timelineProgGrad)"
        stroke-width="5"
        stroke-linecap="round"
      />

      <!-- Stage 1 (Weeks 0-2): Spermatogonia Stem Cell Division (Left Station) -->
      <g class="spermatogenesis-stage stage-1" transform="translate(110, 110)">
        <rect x="-35" y="-35" width="70" height="70" rx="12" fill="rgba(33, 161, 247, 0.12)" stroke="#21A1F7" stroke-width="1.5" />
        <circle cx="0" cy="0" r="16" fill="#0284C7" stroke="#38BDF8" stroke-width="2" />
        <circle cx="0" cy="0" r="7" fill="#67E8F9" />
        <text x="0" y="50" fill="#94A3B8" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Minggu 1-2' : 'Weeks 1-2'}
        </text>
        <text x="0" y="65" fill="#E2E8F0" font-size="10.5" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Spermatogonia' : 'Stem Cells'}
        </text>
      </g>

      <!-- Stage 2 (Weeks 3-6): Meiosis & Primary Spermatocyte (Mid-Left Station) -->
      <g class="spermatogenesis-stage stage-2" transform="translate(300, 110)">
        <rect x="-35" y="-35" width="70" height="70" rx="12" fill="rgba(99, 102, 241, 0.12)" stroke="#6366F1" stroke-width="1.5" />
        <!-- Dividing Meiotic Chromatin -->
        <circle cx="-7" cy="0" r="11" fill="#4F46E5" stroke="#818CF8" stroke-width="1.5" />
        <circle cx="7" cy="0" r="11" fill="#4F46E5" stroke="#818CF8" stroke-width="1.5" />
        <!-- Antioxidant Infusion Shield Aura (NAD+ / CoQ10) -->
        {#if phase >= 2}
          <circle cx="0" cy="0" r="26" fill="none" stroke="#10B981" stroke-width="1.5" stroke-dasharray="4,2" class="shield-aura" />
        {/if}
        <text x="0" y="50" fill="#94A3B8" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Minggu 3-6' : 'Weeks 3-6'}
        </text>
        <text x="0" y="65" fill="#E2E8F0" font-size="10.5" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Meiosis I & II' : 'Meiotic Division'}
        </text>
      </g>

      <!-- Stage 3 (Weeks 7-9): Spermiogenesis & Flagellum Elongation (Mid-Right Station) -->
      <g class="spermatogenesis-stage stage-3" transform="translate(500, 110)">
        <rect x="-40" y="-35" width="80" height="70" rx="12" fill="rgba(16, 185, 129, 0.12)" stroke="#10B981" stroke-width="1.5" />
        <!-- Elongating Sperm Head with Acrosome Cap -->
        <ellipse cx="-12" cy="0" rx="12" ry="8" fill="#047857" stroke="#34D399" stroke-width="1.5" />
        <path d="M -24 0 A 12 8 0 0 1 -18 -8 L -18 8 Z" fill="#6EE7B7" />
        <!-- Flagellar Tail Bud -->
        <path d="M 0 0 Q 15 -8 28 5" fill="none" stroke="#34D399" stroke-width="2.5" stroke-linecap="round" />
        <text x="0" y="50" fill="#94A3B8" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Minggu 7-9' : 'Weeks 7-9'}
        </text>
        <text x="0" y="65" fill="#E2E8F0" font-size="10.5" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Spermiogenesis' : 'Differentiation'}
        </text>
      </g>

      <!-- Stage 4 (Weeks 10-12): Mature Progressive Spermatozoa (Right Station: Epididymis) -->
      <g class="spermatogenesis-stage stage-4" transform="translate(680, 110)">
        <rect x="-40" y="-35" width="80" height="70" rx="12" fill="rgba(56, 189, 248, 0.15)" stroke="#38BDF8" stroke-width="2" />
        <!-- Fully Mature Swimming Spermatozoon -->
        <g class="swimming-sperm" class:swimming={isPlaying} filter="url(#cellGlow)">
          <ellipse cx="-16" cy="0" rx="10" ry="6" fill="#0284C7" stroke="#67E8F9" stroke-width="1.5" />
          <rect cx="-6" y="-3" width="7" height="6" rx="2" fill="#F59E0B" /> <!-- Mitochondrial Midpiece -->
          <path d="M 1 0 Q 14 -8 24 6 T 38 -2" fill="none" stroke="#38BDF8" stroke-width="2" stroke-linecap="round" class="flagellum-tail" />
        </g>
        <text x="0" y="50" fill="#94A3B8" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Minggu 12+' : 'Week 12+'}
        </text>
        <text x="0" y="65" fill="#38BDF8" font-size="10.5" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Matang & Motil' : 'Mature Motile'}
        </text>
      </g>

      <!-- Bottom Panel: WHO 6th Edition Semen Parameter Trackers -->
      <g class="who-parameters-strip" transform="translate(70, 240)">
        <rect width="660" height="90" rx="12" fill="rgba(6, 25, 56, 0.9)" stroke="rgba(33, 161, 247, 0.3)" stroke-width="1" />
        <text x="20" y="24" fill="#38BDF8" font-size="10.5" font-weight="800" letter-spacing="0.6">
          {lang === 'ms' ? 'PAPAN PARAMETER SEMEN WHO EDISI KE-6 (2021):' : 'WHO 6TH EDITION SEMEN BENCHMARK PANEL (2021):'}
        </text>

        <!-- 4 Cards for 4 WHO Parameters -->
        {#each whoParameters as param, idx}
          <g transform={`translate(${20 + idx * 155}, 34)`}>
            <rect width="145" height="44" rx="8" fill="rgba(255, 255, 255, 0.04)" stroke="rgba(255, 255, 255, 0.08)" stroke-width="1" />
            <text x="10" y="16" fill="#94A3B8" font-size="9" font-weight="700">
              {param.label}
            </text>
            <text x="10" y="32" fill={param.status === 'improving' ? '#34D399' : '#FFFFFF'} font-size="11" font-weight="800">
              {param.metric}
            </text>
          </g>
        {/each}
      </g>

      <!-- Interactive Hotspots (1, 2, 3, 4) -->
      {#each hotspots as hs}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <g
          class="hotspot-pin-node"
          class:active={activeHotspot === hs.id}
          transform={`translate(${hs.x}, ${hs.y})`}
          onclick={() => toggleHotspot(hs.id)}
          tabindex="0"
          role="button"
          aria-label={hs.title}
        >
          <circle cx="0" cy="0" r="14" fill="#10B981" fill-opacity="0.25" class="halo-circle" />
          <circle
            cx="0"
            cy="0"
            r="9"
            fill={activeHotspot === hs.id ? '#34D399' : '#047857'}
            stroke="#6EE7B7"
            stroke-width="2"
          />
          <text x="0" y="3.5" text-anchor="middle" fill="#FFFFFF" font-size="9" font-weight="800">
            {hs.id}
          </text>
        </g>
      {/each}
    </svg>
  </div>

  <!-- Interactive Hotspot Callout Popover Card -->
  {#if activeHotspot !== null}
    {@const hs = hotspots.find(h => h.id === activeHotspot)}
    {#if hs}
      <div class="hotspot-callout-card" role="region" aria-live="polite">
        <div class="hcc-head">
          <div class="hcc-badge">HOTSPOT #{hs.id}</div>
          <h4 class="hcc-title">{hs.title}</h4>
          <button class="hcc-close" onclick={() => (activeHotspot = null)} aria-label="Tutup / Close">
            ×
          </button>
        </div>
        <p class="hcc-desc">{hs.desc}</p>
      </div>
    {/if}
  {/if}
</div>

<style>
  .fertility-illustration-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    position: relative;
  }

  .canvas-controls-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 14px;
    background: rgba(0, 0, 0, 0.35);
    border-radius: 10px;
    margin-bottom: 12px;
    gap: 12px;
  }

  .cct-left {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .ctrl-icon-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 5px 12px;
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.4);
    border-radius: 6px;
    color: #34D399;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .ctrl-icon-btn:hover {
    background: rgba(16, 185, 129, 0.28);
    color: #FFFFFF;
    border-color: #6EE7B7;
  }

  .phase-indicator-tag {
    font-size: 12px;
    font-weight: 700;
    color: #34D399;
    background: rgba(16, 185, 129, 0.15);
    border: 1px solid rgba(16, 185, 129, 0.3);
    padding: 3px 10px;
    border-radius: 6px;
  }

  .simulation-note {
    font-size: 11px;
    color: #94A3B8;
  }

  .svg-viewport {
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
    overflow: hidden;
  }

  .fertility-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Flagellar Swimming Undulation Animation */
  @keyframes undulateTail {
    0%, 100% {
      d: path("M 1 0 Q 14 -8 24 6 T 38 -2");
    }
    50% {
      d: path("M 1 0 Q 14 8 24 -6 T 38 2");
    }
  }

  .swimming .flagellum-tail {
    animation: undulateTail 0.8s ease-in-out infinite;
  }

  /* Shield Aura Pulse */
  @keyframes shieldPulse {
    0%, 100% { opacity: 0.4; transform: scale(1); }
    50% { opacity: 0.9; transform: scale(1.08); }
  }

  .shield-aura {
    animation: shieldPulse 2.5s ease-in-out infinite;
    transform-origin: center;
  }

  /* Hotspot Pin Interactive Styling */
  .hotspot-pin-node {
    cursor: pointer;
    outline: none;
    transition: transform 0.2s ease;
  }

  .hotspot-pin-node:hover {
    transform: scale(1.2);
  }

  @keyframes pulseHalo {
    0%, 100% { transform: scale(1); opacity: 0.25; }
    50% { transform: scale(1.4); opacity: 0.05; }
  }

  .hotspot-pin-node .halo-circle {
    animation: pulseHalo 2s ease-in-out infinite;
  }

  /* Hotspot Callout Popover */
  .hotspot-callout-card {
    margin-top: 14px;
    background: rgba(6, 25, 56, 0.95);
    border: 1px solid rgba(16, 185, 129, 0.4);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    border-radius: 12px;
    padding: 16px 20px;
    animation: fadeIn 0.2s ease;
  }

  .hcc-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 6px;
  }

  .hcc-badge {
    font-size: 10px;
    font-weight: 800;
    color: #10B981;
    letter-spacing: 0.8px;
  }

  .hcc-title {
    font-size: 14px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0;
    flex: 1;
    margin-left: 10px;
  }

  .hcc-close {
    background: transparent;
    border: none;
    color: #94A3B8;
    font-size: 18px;
    line-height: 1;
    cursor: pointer;
    padding: 2px 6px;
  }

  .hcc-close:hover {
    color: #FFFFFF;
  }

  .hcc-desc {
    font-size: 12.5px;
    color: #CBD5E1;
    line-height: 1.5;
    margin: 0;
  }

  .paused * {
    animation-play-state: paused !important;
  }

  @media (prefers-reduced-motion: reduce) {
    *, ::before, ::after {
      animation: none !important;
      transition: none !important;
    }
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(4px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>

<script lang="ts">
  import { onDestroy } from 'svelte';
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

  // Breathing pacer state: 'squeeze' | 'hold' | 'relax'
  let pacerStage = $state<'squeeze' | 'hold' | 'relax'>('squeeze');
  let pacerTimer: any = null;

  // Rhythm durations based on treatment phase
  const rhythmDurations = $derived({
    squeeze: phase === 1 ? 3000 : phase === 2 ? 4000 : 5000,
    hold: phase === 1 ? 3000 : phase === 2 ? 5000 : 7000,
    relax: phase === 1 ? 4000 : phase === 2 ? 4000 : 5000
  });

  function startPacerCycle() {
    clearTimeout(pacerTimer);
    if (!isPlaying) return;

    if (pacerStage === 'squeeze') {
      pacerTimer = setTimeout(() => {
        if (isPlaying) {
          pacerStage = 'hold';
          startPacerCycle();
        }
      }, rhythmDurations.squeeze);
    } else if (pacerStage === 'hold') {
      pacerTimer = setTimeout(() => {
        if (isPlaying) {
          pacerStage = 'relax';
          startPacerCycle();
        }
      }, rhythmDurations.hold);
    } else {
      pacerTimer = setTimeout(() => {
        if (isPlaying) {
          pacerStage = 'squeeze';
          startPacerCycle();
        }
      }, rhythmDurations.relax);
    }
  }

  $effect(() => {
    if (isPlaying) {
      startPacerCycle();
    } else {
      clearTimeout(pacerTimer);
    }
  });

  onDestroy(() => {
    clearTimeout(pacerTimer);
  });

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  function setStageManual(stage: 'squeeze' | 'hold' | 'relax') {
    pacerStage = stage;
    if (isPlaying) {
      startPacerCycle();
    }
  }

  const hotspots = $derived([
    {
      id: 1,
      x: 390,
      y: 220,
      title: lang === 'ms' ? 'Otot Levator Ani & Pubococcygeus' : 'Levator Ani & Pubococcygeus Muscle',
      desc: lang === 'ms'
        ? 'Jaringan otot berbentuk buaian (hammock) yang menyokong pundi kencing, prostat, dan rektum. Pengecutan mengangkat organ pelvis ke atas.'
        : 'Muscular hammock supporting the bladder, prostate, and rectum. Coordinated contraction elevates the pelvic organs superiorly.'
    },
    {
      id: 2,
      x: 480,
      y: 175,
      title: lang === 'ms' ? 'Otot Bulbocavernosus' : 'Bulbocavernosus Muscle',
      desc: lang === 'ms'
        ? 'Otot dasar yang mengelilingi pangkal penis. Berfungsi mengekalkan ketegangan dan mengawal latensi ejakulasi semasa hubungan intim.'
        : 'Superficial muscle encircling the penile bulb. Critical for sustaining intracavernosal rigidity and ejaculatory latency control.'
    },
    {
      id: 3,
      x: 340,
      y: 140,
      title: lang === 'ms' ? 'Pundi Kencing & Leher Sfinkter' : 'Bladder Neck & External Sphincter',
      desc: lang === 'ms'
        ? 'Latihan dasar pelvis mengukuhkan kawalan sfinkter uretra luar bagi mengelakkan kebocoran air kencing dan menyokong kontinens.'
        : 'Pelvic conditioning strengthens the external urethral sphincter, preventing post-micturition dribble and reinforcing continence.'
    },
    {
      id: 4,
      x: 230,
      y: 190,
      title: lang === 'ms' ? 'Tulang Pubis & Koksiks (Titik Sauh)' : 'Pubic Bone & Coccyx Anchors',
      desc: lang === 'ms'
        ? 'Struktur tulang anterior dan posterior yang menjadi sauh kepada ligamen dan fascia lantai pelvis.'
        : 'Anterior and posterior skeletal landmarks anchoring the pelvic fascial attachments and suspensory ligaments.'
    }
  ]);

  function toggleHotspot(id: number) {
    activeHotspot = activeHotspot === id ? null : id;
  }
</script>

<div class="kegel-illustration-container" class:patient-mode={patientMode}>
  <!-- Controls Toolbar -->
  <div class="canvas-controls-toolbar">
    <div class="cct-left">
      <button
        class="ctrl-icon-btn"
        onclick={togglePlay}
        title={isPlaying ? (lang === 'ms' ? 'Jeda ritma' : 'Pause cadence') : (lang === 'ms' ? 'Mulakan ritma' : 'Start cadence')}
        aria-label={isPlaying ? 'Pause cadence' : 'Play cadence'}
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
          {isPlaying ? (lang === 'ms' ? 'Jeda' : 'Pause') : (lang === 'ms' ? 'Mula Ritma' : 'Play')}
        </span>
      </button>

      <!-- Pacer Stage Segmented Pills -->
      <div class="pacer-pills-group" role="group" aria-label="Pacer stage selector">
        <button
          class="pacer-pill"
          class:active={pacerStage === 'squeeze'}
          onclick={() => setStageManual('squeeze')}
        >
          {lang === 'ms' ? '1. Angkat & Kecut (Squeeze)' : '1. Squeeze & Lift'}
        </button>
        <button
          class="pacer-pill"
          class:active={pacerStage === 'hold'}
          onclick={() => setStageManual('hold')}
        >
          {lang === 'ms' ? '2. Tahan (Hold)' : '2. Hold'}
        </button>
        <button
          class="pacer-pill"
          class:active={pacerStage === 'relax'}
          onclick={() => setStageManual('relax')}
        >
          {lang === 'ms' ? '3. Rehat (Release)' : '3. Relax'}
        </button>
      </div>

      <span class="phase-indicator-tag">
        {lang === 'ms' ? `Fasa ${phase}` : `Phase ${phase}`}:
        {phase === 1
          ? (lang === 'ms' ? 'Pengasingan Otot (3s)' : 'Muscle Isolation (3s)')
          : phase === 2
          ? (lang === 'ms' ? 'Ketahanan Progresif (5s)' : 'Progressive Endurance (5s)')
          : phase === 3
          ? (lang === 'ms' ? 'Pengecutan Intensiti Tinggi (7s)' : 'High-Intensity Cadence (7s)')
          : (lang === 'ms' ? 'Penyelenggaraan Memori Otot' : 'Muscle Memory Retention')}
      </span>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '🫁 Panduan Pernafasan Pelvis Beritma' : '🫁 Rhythmic Pelvic Breathing Guide'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    <svg
      viewBox="0 0 800 360"
      class="kegel-svg"
      role="img"
      aria-labelledby="kegel-svg-title kegel-svg-desc"
    >
      <title id="kegel-svg-title">
        {lang === 'ms' ? 'Simulasi Biomekanik Lantai Pelvis & Latihan Kegel' : 'Pelvic Floor Biomechanics & Kegel Training Simulation'}
      </title>
      <desc id="kegel-svg-desc">
        {lang === 'ms'
          ? 'Pandangan sagital pelvis lelaki memaparkan pengecutan otot levator ani dan bulbocavernosus selaras dengan ritma pernafasan.'
          : 'Male sagittal pelvic cross-section demonstrating dynamic contraction of the levator ani and bulbocavernosus muscles aligned with breath pacing.'}
      </desc>

      <defs>
        <radialGradient id="pelvicGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#08234D" />
          <stop offset="100%" stop-color="#030F24" />
        </radialGradient>

        <linearGradient id="muscleContractGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#F43F5E" />
          <stop offset="50%" stop-color="#FB7185" />
          <stop offset="100%" stop-color="#BE123C" />
        </linearGradient>

        <linearGradient id="muscleRelaxGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#64748B" />
          <stop offset="50%" stop-color="#94A3B8" />
          <stop offset="100%" stop-color="#475569" />
        </linearGradient>

        <filter id="muscleGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3.5" result="glow" />
          <feComposite in="SourceGraphic" in2="glow" operator="over" />
        </filter>
      </defs>

      <!-- Background Canvas -->
      <rect width="800" height="360" rx="16" fill="url(#pelvicGrad)" stroke="#0E3368" stroke-width="2" />

      <!-- Pelvic Bony Landmarks (Bones) -->
      <!-- Pubic Bone (Anterior - Left) -->
      <path
        d="M 220 180 Q 235 155 250 170 Q 260 195 240 215 Q 220 205 220 180 Z"
        fill="#1E293B"
        stroke="#475569"
        stroke-width="2"
      />
      <text x="228" y="160" fill="#94A3B8" font-size="10" font-weight="700">
        {lang === 'ms' ? 'SIMFISIS PUBIS' : 'PUBIC BONE'}
      </text>

      <!-- Sacrum & Coccyx (Posterior - Right) -->
      <path
        d="M 570 80 Q 560 130 550 180 Q 540 220 535 240 Q 550 240 565 210 Q 585 150 590 80 Z"
        fill="#1E293B"
        stroke="#475569"
        stroke-width="2"
      />
      <text x="585" y="100" fill="#94A3B8" font-size="10" font-weight="700">
        {lang === 'ms' ? 'SAKRUM / KOKSIKS' : 'SACRUM / COCCYX'}
      </text>

      <!-- Pelvic Viscera (Bladder, Prostate, Rectum) -->
      <g class="viscera-group" opacity="0.85">
        <!-- Urinary Bladder -->
        <path
          d="M 280 150 C 290 90, 360 85, 390 120 C 410 145, 390 180, 350 185 C 310 185, 275 175, 280 150 Z"
          fill="rgba(33, 161, 247, 0.12)"
          stroke="#0284C7"
          stroke-width="1.8"
        />
        <text x="340" y="140" fill="#38BDF8" font-size="11" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'PUNDI KENCING' : 'URINARY BLADDER'}
        </text>

        <!-- Prostate Gland -->
        <ellipse cx="360" cy="200" rx="22" ry="16" fill="rgba(168, 85, 247, 0.15)" stroke="#9333EA" stroke-width="1.8" />
        <text x="360" y="204" fill="#C084FC" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'PROSTAT' : 'PROSTATE'}
        </text>

        <!-- Rectum & Anal Canal (Posterior) -->
        <path
          d="M 480 100 Q 470 170 475 240 Q 495 240 495 170 Q 500 100 480 100 Z"
          fill="rgba(100, 116, 139, 0.15)"
          stroke="#64748B"
          stroke-width="1.5"
        />
        <text x="500" y="130" fill="#94A3B8" font-size="9.5" font-weight="600">
          {lang === 'ms' ? 'REKTUM' : 'RECTUM'}
        </text>
      </g>

      <!-- Pelvic Floor Muscle Sling (Dynamic Levator Ani Hammock) -->
      <!-- Changes curvature and elevation based on pacerStage -->
      <g
        class="pelvic-muscle-hammock"
        class:muscle-squeezed={pacerStage === 'squeeze'}
        class:muscle-held={pacerStage === 'hold'}
        class:muscle-relaxed={pacerStage === 'relax'}
        filter={pacerStage !== 'relax' ? 'url(#muscleGlow)' : undefined}
      >
        <!-- The Muscle Sling Path -->
        {#if pacerStage === 'relax'}
          <!-- Descended/Baseline Relaxed Sling -->
          <path
            d="M 240 210 Q 360 270 535 240"
            fill="none"
            stroke="url(#muscleRelaxGrad)"
            stroke-width="12"
            stroke-linecap="round"
            class="muscle-path"
          />
        {:else if pacerStage === 'squeeze'}
          <!-- Actively Elevating & Squeezing Sling -->
          <path
            d="M 240 210 Q 360 240 535 240"
            fill="none"
            stroke="url(#muscleContractGrad)"
            stroke-width="14"
            stroke-linecap="round"
            class="muscle-path contracting"
          />
        {:else}
          <!-- Peak Sustained Engagement (Hold) -->
          <path
            d="M 240 210 Q 360 230 535 240"
            fill="none"
            stroke="url(#muscleContractGrad)"
            stroke-width="15"
            stroke-linecap="round"
            class="muscle-path holding"
          />
        {/if}

        <!-- Vector Muscle Striations -->
        <path d="M 290 220 L 305 240" stroke="#FFFFFF" stroke-width="1" stroke-opacity="0.4" />
        <path d="M 340 225 L 355 245" stroke="#FFFFFF" stroke-width="1" stroke-opacity="0.4" />
        <path d="M 390 225 L 405 245" stroke="#FFFFFF" stroke-width="1" stroke-opacity="0.4" />
        <path d="M 440 225 L 455 245" stroke="#FFFFFF" stroke-width="1" stroke-opacity="0.4" />
        <path d="M 490 225 L 505 242" stroke="#FFFFFF" stroke-width="1" stroke-opacity="0.4" />
      </g>

      <!-- Upward Force Vector Arrows (Visible during Squeeze & Hold) -->
      {#if pacerStage !== 'relax'}
        <g class="lift-arrows-group" opacity="0.9">
          <path d="M 330 250 L 330 225 M 325 233 L 330 225 L 335 233" stroke="#F43F5E" stroke-width="2.5" stroke-linecap="round" />
          <path d="M 380 250 L 380 220 M 375 228 L 380 220 L 385 228" stroke="#F43F5E" stroke-width="2.5" stroke-linecap="round" />
          <path d="M 430 250 L 430 225 M 425 233 L 430 225 L 435 233" stroke="#F43F5E" stroke-width="2.5" stroke-linecap="round" />
        </g>
      {/if}

      <!-- Bulbocavernosus Muscle (Anterior Base of Penis) -->
      <path
        d="M 210 230 C 220 220, 240 230, 235 250 C 220 255, 205 245, 210 230 Z"
        fill={pacerStage !== 'relax' ? '#F43F5E' : '#64748B'}
        stroke="#FFFFFF"
        stroke-width="1.5"
      />
      <text x="215" y="275" fill={pacerStage !== 'relax' ? '#FB7185' : '#94A3B8'} font-size="10" font-weight="700">
        {lang === 'ms' ? 'Otot Bulbocavernosus' : 'Bulbocavernosus'}
      </text>

      <!-- Dynamic Pacer HUD Gauge in Lower Left -->
      <g class="pacer-hud-card" transform="translate(40, 210)">
        <rect width="150" height="110" rx="10" fill="rgba(6, 25, 56, 0.85)" stroke="rgba(33, 161, 247, 0.3)" stroke-width="1" />
        <text x="15" y="25" fill="#38BDF8" font-size="10" font-weight="800" letter-spacing="0.5">
          {lang === 'ms' ? 'PACER PERNAFASAN' : 'BREATHING PACER'}
        </text>

        <!-- Current Action Label -->
        <text
          x="15"
          y="55"
          fill={pacerStage === 'squeeze' ? '#38BDF8' : pacerStage === 'hold' ? '#F43F5E' : '#10B981'}
          font-size="15"
          font-weight="900"
        >
          {pacerStage === 'squeeze'
            ? (lang === 'ms' ? '⬆️ ANGKAT & KECUT' : '⬆️ SQUEEZE & LIFT')
            : pacerStage === 'hold'
            ? (lang === 'ms' ? '⏹️ TAHAN OTOT' : '⏹️ HOLD CONTRACTION')
            : (lang === 'ms' ? '⬇️ REHATKAN OTOT' : '⬇️ RELAX & BREATHE')}
        </text>

        <text x="15" y="80" fill="#CBD5E1" font-size="11" font-weight="600">
          {pacerStage === 'squeeze'
            ? (lang === 'ms' ? 'Hembus nafas perlahan' : 'Exhale smoothly')
            : pacerStage === 'hold'
            ? (lang === 'ms' ? 'Kekalkan ketegangan' : 'Maintain peak tone')
            : (lang === 'ms' ? 'Tarik nafas diafragma' : 'Inhale deeply via belly')}
        </text>

        <text x="15" y="98" fill="#94A3B8" font-size="9.5">
          {lang === 'ms' ? `Ritma Fasa ${phase}: ${rhythmDurations[pacerStage] / 1000} saat` : `Phase ${phase} Cadence: ${rhythmDurations[pacerStage] / 1000}s`}
        </text>
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
          <circle cx="0" cy="0" r="14" fill="#21A1F7" fill-opacity="0.25" class="halo-circle" />
          <circle
            cx="0"
            cy="0"
            r="9"
            fill={activeHotspot === hs.id ? '#38BDF8' : '#043388'}
            stroke="#60A5FA"
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
  .kegel-illustration-container {
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
    background: rgba(33, 161, 247, 0.15);
    border: 1px solid rgba(33, 161, 247, 0.4);
    border-radius: 6px;
    color: #38BDF8;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .ctrl-icon-btn:hover {
    background: rgba(33, 161, 247, 0.28);
    color: #FFFFFF;
    border-color: #38BDF8;
  }

  .pacer-pills-group {
    display: inline-flex;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
  }

  .pacer-pill {
    padding: 4px 10px;
    border-radius: 4px;
    border: none;
    background: transparent;
    color: #94A3B8;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .pacer-pill.active {
    background: #0284C7;
    color: #FFFFFF;
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

  .kegel-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Muscle Dynamic Transition */
  .muscle-path {
    transition: d 0.4s ease-in-out, stroke 0.4s ease;
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
    border: 1px solid rgba(33, 161, 247, 0.4);
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
    color: #21A1F7;
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

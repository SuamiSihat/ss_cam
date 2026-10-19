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
  let activeMilestone = $state<number | null>(null);
  let animationKey = $state(0);

  const milestones = $derived([
    {
      id: 0,
      x: 110,
      y: 245,
      timeLabel: lang === 'ms' ? 'Asas (Minggu 0)' : 'Baseline (Wk 0)',
      serumValue: '7.8 nmol/L',
      status: 'deficient',
      title: lang === 'ms' ? 'Saringan Asas & Pengesahan Diagnostik' : 'Baseline Diagnostic Screen',
      desc: lang === 'ms'
        ? 'Ujian darah pagi berulang (sebelum 11:00 AM) mengesahkan paras testosteron rendah bersama simptom keletihan dan penurunan libido.'
        : 'Repeat fasting morning blood draw (prior to 11:00 AM) confirming low serum testosterone with clinical fatigue and reduced vitality.',
      tests: lang === 'ms' ? 'Ujian: Total T, Free T, PSA, Hematokrit (Hct), Profil Lipid & Fungsi Hati' : 'Tests: Total T, Free T, PSA, Hematocrit (Hct), Lipid Profile & LFT'
    },
    {
      id: 1,
      x: 230,
      y: 195,
      timeLabel: lang === 'ms' ? 'Bulan 1 (Minggu 4)' : 'Month 1 (Wk 4)',
      serumValue: '14.5 nmol/L',
      status: 'rising',
      title: lang === 'ms' ? 'Pemulihan Tenaga & Kualiti Tidur' : 'Energy & Sleep Restoration',
      desc: lang === 'ms'
        ? 'Paras hormon memasuki paras fisiologi normal terendah. Pesakit mula merasai tidur lebih lena, mood stabil dan keletihan berkurang.'
        : 'Serum levels enter lower physiological range. Patients report deeper sleep architecture, mood stabilization, and reduced chronic brain fog.',
      tests: lang === 'ms' ? 'Semakan: Toleransi dos & semakan tekanan darah' : 'Review: Dosing tolerance & blood pressure check'
    },
    {
      id: 2,
      x: 370,
      y: 160,
      timeLabel: lang === 'ms' ? 'Bulan 3 (Minggu 12)' : 'Month 3 (Wk 12)',
      serumValue: '18.6 nmol/L',
      status: 'optimal',
      title: lang === 'ms' ? 'Titik Pemantauan Darah 12-Minggu' : '12-Week Safety Monitoring Audit',
      desc: lang === 'ms'
        ? 'Paras testosteron mencapai zon fisiologi stabil. Ujian darah keselamatan dijalankan bagi memeriksa paras hematokrit dan PSA.'
        : 'Physiological steady-state achieved. Mandatory safety laboratory audit ensures hematocrit and prostate health remain strictly protected.',
      tests: lang === 'ms' ? 'Ujian Wajib: Total T, Free T, Hematokrit (<54%), PSA, Profil Lipid' : 'Mandatory Tests: Total T, Free T, Hematocrit (<54%), PSA, Lipids'
    },
    {
      id: 3,
      x: 510,
      y: 155,
      timeLabel: lang === 'ms' ? 'Bulan 6 (Minggu 24)' : 'Month 6 (Wk 24)',
      serumValue: '19.2 nmol/L',
      status: 'optimal',
      title: lang === 'ms' ? 'Peningkatan Komposisi & Sensitiviti Insulin' : 'Body Composition & Metabolic Health',
      desc: lang === 'ms'
        ? 'Kesan metabolik jangka sederhana: pengurangan lemak viseral, pembentukan jisim otot tanpa lemak dan kawalan glukosa lebih baik.'
        : 'Mid-term metabolic benefits: reduction in visceral adipose tissue, lean muscular mass retention, and enhanced insulin sensitivity.',
      tests: lang === 'ms' ? 'Semakan: Komposisi badan & glukosa darah' : 'Review: Body composition & fasting glucose'
    },
    {
      id: 4,
      x: 660,
      y: 155,
      timeLabel: lang === 'ms' ? 'Bulan 12 (Minggu 52)' : 'Month 12 (Wk 52)',
      serumValue: '19.0 nmol/L',
      status: 'optimal',
      title: lang === 'ms' ? 'Penyelenggaraan Tahunan & Kesihatan Kardiovaskular' : 'Annual Cardiovascular & Maintenance Audit',
      desc: lang === 'ms'
        ? 'Semakan menyeluruh tahunan bagi memastikan kestabilan jangka panjang yang selamat di bawah pengawasan doktor bertauliah.'
        : 'Comprehensive annual safety review ensuring sustained long-term endocrine balance and cardiovascular wellness under medical supervision.',
      tests: lang === 'ms' ? 'Ujian Tahunan: Panel darah lengkap, PSA, Hct, Kardiovaskular' : 'Annual Tests: Comprehensive blood panel, PSA, Hematocrit, ECG'
    }
  ]);

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  function replayAnimation() {
    animationKey++;
    isPlaying = true;
  }

  function toggleMilestone(id: number) {
    activeMilestone = activeMilestone === id ? null : id;
  }
</script>

<div class="trt-illustration-container" class:paused={!isPlaying} class:patient-mode={patientMode}>
  <!-- Controls Toolbar -->
  <div class="canvas-controls-toolbar">
    <div class="cct-left">
      <button
        class="ctrl-icon-btn"
        onclick={togglePlay}
        title={isPlaying ? (lang === 'ms' ? 'Jeda animasi' : 'Play animation') : (lang === 'ms' ? 'Mainkan animasi' : 'Resume animation')}
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

      <button
        class="ctrl-icon-btn secondary"
        onclick={replayAnimation}
        title={lang === 'ms' ? 'Lukis semula keluk' : 'Replay curve animation'}
        aria-label="Replay curve"
      >
        <svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 10a7 7 0 1 0 2-4.9L3 7m0-4v4h4" />
        </svg>
        <span class="ctrl-btn-text">{lang === 'ms' ? 'Lukis Semula' : 'Replay'}</span>
      </button>

      <span class="phase-indicator-tag">
        {lang === 'ms' ? `Fasa ${phase}` : `Phase ${phase}`}:
        {#if phase === 1}
          {lang === 'ms' ? 'Ujian Asas & Penetapan Dos' : 'Baseline Test & Dosing'}
        {:else if phase === 2}
          {lang === 'ms' ? 'Peningkatan Tenaga & Tidur' : 'Energy & Sleep Restoration'}
        {:else if phase === 3}
          {lang === 'ms' ? 'Kestabilan Komposisi Badan' : 'Body Composition & Plateau'}
        {:else}
          {lang === 'ms' ? 'Pemantauan 12-Bulan & Keselamatan' : '12-Month Safety & Audit'}
        {/if}
      </span>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '📋 Piawaian Garis Panduan Endocrine Society / EAU' : '📋 Endocrine Society & EAU Guideline Standard'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    {#key animationKey}
      <svg
        viewBox="0 0 800 360"
        class="trt-svg"
        role="img"
        aria-labelledby="trt-svg-title trt-svg-desc"
      >
        <title id="trt-svg-title">
          {lang === 'ms' ? 'Keluk Pemulihan Hormon TRT Fisiologi' : 'Physiological TRT Hormone Recovery Curve'}
        </title>
        <desc id="trt-svg-desc">
          {lang === 'ms'
            ? 'Carta graf menunjukkan ambang diagnostik hipogonadisme, keluk pemulihan fisiologi selamat ke julat 14-25 nmol/L, dan titik pemantauan darah berkala.'
            : 'Chart curve illustrating hypogonadism diagnostic threshold, steady-state recovery curve within 14-25 nmol/L physiological range, and periodic safety lab audit nodes.'}
        </desc>

        <defs>
          <!-- Grid Pattern -->
          <pattern id="trtGrid" width="40" height="30" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 30" fill="none" stroke="rgba(255, 255, 255, 0.04)" stroke-width="0.5" />
          </pattern>

          <!-- Normal Target Range Gradient -->
          <linearGradient id="targetRangeGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#10B981" stop-opacity="0.16" />
            <stop offset="100%" stop-color="#10B981" stop-opacity="0.04" />
          </linearGradient>

          <!-- Deficiency Trough Gradient -->
          <linearGradient id="deficientGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#EF4444" stop-opacity="0.12" />
            <stop offset="100%" stop-color="#EF4444" stop-opacity="0.02" />
          </linearGradient>

          <!-- Curve Glowing Filter -->
          <filter id="curveGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        <!-- Chart Grid Backdrop -->
        <rect x="70" y="40" width="670" height="260" fill="url(#trtGrid)" />

        <!-- 1. Normal Target Physiological Range Band (14 - 25 nmol/L) -->
        <!-- y: 120 (25 nmol/L) to y: 200 (14 nmol/L) -->
        <rect
          x="70"
          y="120"
          width="670"
          height="80"
          fill="url(#targetRangeGrad)"
          stroke="#10B981"
          stroke-width="1.5"
          stroke-dasharray="6,4"
        />

        <text x="730" y="140" fill="#34D399" font-size="11" font-weight="700" text-anchor="end">
          {lang === 'ms' ? 'Zon Sasaran Fisiologi Normal (14 - 25 nmol/L)' : 'Target Physiological Zone (14 - 25 nmol/L)'}
        </text>
        <text x="730" y="155" fill="#6EE7B7" font-size="9.5" text-anchor="end" opacity="0.85">
          {lang === 'ms' ? 'Berdasarkan Garis Panduan Klinikal Endocrine Society' : 'Endocrine Society Guideline Recommended'}
        </text>

        <!-- 2. Diagnostic Deficiency Trough Band (< 9.2 - 12 nmol/L) -->
        <!-- y: 214 (12 nmol/L threshold) to y: 300 (0 nmol/L) -->
        <rect
          x="70"
          y="214"
          width="670"
          height="86"
          fill="url(#deficientGrad)"
        />

        <!-- Deficiency Threshold Red Dashed Line (12 nmol/L) -->
        <line
          x1="70"
          y1="214"
          x2="740"
          y2="214"
          stroke="#EF4444"
          stroke-width="1.5"
          stroke-dasharray="5,4"
        />

        <text x="730" y="232" fill="#F87171" font-size="10.5" font-weight="700" text-anchor="end">
          {lang === 'ms' ? 'Ambang Diagnostik Hipogonadisme (< 9.2 - 12 nmol/L)' : 'Diagnostic Deficiency Threshold (< 9.2 - 12 nmol/L)'}
        </text>
        <text x="730" y="246" fill="#FCA5A5" font-size="9" text-anchor="end" opacity="0.8">
          {lang === 'ms' ? 'Perlu disahkan melalui sekurang-kurangnya 2 ujian darah pagi berulang' : 'Requires confirmation on >=2 repeat fasting morning blood samples'}
        </text>

        <!-- Chart Axes -->
        <!-- Y-Axis line -->
        <line x1="70" y1="40" x2="70" y2="300" stroke="#475569" stroke-width="1.5" />
        <!-- X-Axis line -->
        <line x1="70" y1="300" x2="740" y2="300" stroke="#475569" stroke-width="1.5" />

        <!-- Y-Axis Ticks & Labels (Serum Total Testosterone nmol/L) -->
        <text x="60" y="304" fill="#94A3B8" font-size="10" text-anchor="end">0</text>
        <text x="60" y="232" fill="#F87171" font-size="10" font-weight="700" text-anchor="end">10</text>
        <text x="60" y="218" fill="#F87171" font-size="9.5" text-anchor="end">12</text>
        <text x="60" y="204" fill="#34D399" font-size="10" font-weight="700" text-anchor="end">14</text>
        <text x="60" y="160" fill="#34D399" font-size="10" font-weight="700" text-anchor="end">20</text>
        <text x="60" y="124" fill="#34D399" font-size="10" font-weight="700" text-anchor="end">25</text>
        <text x="60" y="88" fill="#94A3B8" font-size="10" text-anchor="end">30</text>

        <!-- Y-Axis Title -->
        <text
          x="20"
          y="170"
          fill="#94A3B8"
          font-size="10"
          font-weight="700"
          letter-spacing="0.5"
          transform="rotate(-90 20 170)"
          text-anchor="middle"
        >
          {lang === 'ms' ? 'TOTAL TESTOSTERONE (nmol/L)' : 'SERUM TESTOSTERONE (nmol/L)'}
        </text>

        <!-- Untreated Flat Deficiency Baseline Trajectory (Red dotted line) -->
        <path
          d="M 110 245 C 230 250, 370 255, 510 255 S 660 258, 730 260"
          fill="none"
          stroke="#EF4444"
          stroke-width="2"
          stroke-dasharray="6,4"
          opacity="0.6"
        />
        <text x="730" y="274" fill="#F87171" font-size="9.5" font-style="italic" text-anchor="end">
          {lang === 'ms' ? 'Tanpa Rawatan (Kekal Rendah / Keletihan)' : 'Untreated Trajectory (Chronic Fatigue)'}
        </text>

        <!-- TRT Steady State Recovery Self-Drawing Curve (Cyan Glowing Line) -->
        <path
          d="M 110 245 C 180 240, 210 198, 230 195 C 280 188, 330 165, 370 160 C 430 155, 480 155, 510 155 C 570 155, 620 155, 660 155 L 730 155"
          fill="none"
          stroke="#21A1F7"
          stroke-width="4.5"
          stroke-linecap="round"
          class="hormone-draw-curve"
          filter="url(#curveGlow)"
        />

        <!-- X-Axis Milestone Grid Vertical Guidelines -->
        {#each milestones as ms}
          <line
            x1={ms.x}
            y1="40"
            x2={ms.x}
            y2="300"
            stroke="rgba(255, 255, 255, 0.08)"
            stroke-width="1"
            stroke-dasharray="3,3"
          />

          <!-- X-Axis Timeline Labels -->
          <text
            x={ms.x}
            y="320"
            fill={activeMilestone === ms.id ? '#38BDF8' : '#CBD5E1'}
            font-size="10.5"
            font-weight={activeMilestone === ms.id ? '800' : '600'}
            text-anchor="middle"
          >
            {ms.timeLabel}
          </text>

          <!-- Interactive Milestone Node Points Along the Curve -->
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <g
            class="milestone-node"
            class:active={activeMilestone === ms.id}
            transform={`translate(${ms.x}, ${ms.y})`}
            onclick={() => toggleMilestone(ms.id)}
            role="button"
            tabindex="0"
            aria-label={`${ms.timeLabel}: ${ms.title}`}
          >
            <!-- Pulsing outer circle -->
            <circle cx="0" cy="0" r="14" fill="#21A1F7" fill-opacity="0.25" class="halo-circle" />
            <!-- Core node dot -->
            <circle
              cx="0"
              cy="0"
              r="7"
              fill={ms.status === 'deficient' ? '#EF4444' : ms.status === 'rising' ? '#F59E0B' : '#10B981'}
              stroke="#FFFFFF"
              stroke-width="2"
            />
            <!-- Value badge tag above node -->
            <rect
              x="-28"
              y="-26"
              width="56"
              height="16"
              rx="4"
              fill="rgba(6, 25, 56, 0.9)"
              stroke={ms.status === 'deficient' ? '#EF4444' : '#10B981'}
              stroke-width="1"
            />
            <text x="0" y="-14" fill="#FFFFFF" font-size="8.5" font-weight="700" text-anchor="middle">
              {ms.serumValue}
            </text>
          </g>
        {/each}
      </svg>
    {/key}
  </div>

  <!-- Interactive Milestone Popover Card (When a point on the curve is clicked) -->
  {#if activeMilestone !== null}
    {@const ms = milestones.find(m => m.id === activeMilestone)}
    {#if ms}
      <div class="milestone-callout-card" role="region" aria-live="polite">
        <div class="mcc-head">
          <div class="mcc-tag">
            {ms.timeLabel} • <span class="serum-pill">{ms.serumValue}</span>
          </div>
          <h4 class="mcc-title">{ms.title}</h4>
          <button class="mcc-close" onclick={() => (activeMilestone = null)} aria-label="Tutup / Close">
            ×
          </button>
        </div>
        <p class="mcc-desc">{ms.desc}</p>
        <div class="mcc-tests-tag">
          <strong>📋 {ms.tests}</strong>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .trt-illustration-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    position: relative;
  }

  /* Controls Toolbar */
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

  .ctrl-icon-btn.secondary {
    background: rgba(255, 255, 255, 0.05);
    border-color: rgba(255, 255, 255, 0.15);
    color: #CBD5E1;
  }

  .ctrl-icon-btn.secondary:hover {
    background: rgba(255, 255, 255, 0.1);
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

  /* SVG Viewport */
  .svg-viewport {
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
    overflow: hidden;
  }

  .trt-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Self-drawing hormone curve animation */
  @keyframes drawCurve {
    from {
      stroke-dashoffset: 1000;
    }
    to {
      stroke-dashoffset: 0;
    }
  }

  .hormone-draw-curve {
    stroke-dasharray: 1000;
    stroke-dashoffset: 0;
    animation: drawCurve 2.5s ease-out forwards;
  }

  /* Milestone Nodes */
  .milestone-node {
    cursor: pointer;
    outline: none;
    transition: transform 0.2s ease;
  }

  .milestone-node:hover {
    transform: scale(1.2);
  }

  @keyframes pulseHalo {
    0%, 100% { transform: scale(1); opacity: 0.3; }
    50% { transform: scale(1.4); opacity: 0.08; }
  }

  .milestone-node .halo-circle {
    animation: pulseHalo 2s ease-in-out infinite;
  }

  /* Milestone Callout Popover */
  .milestone-callout-card {
    margin-top: 14px;
    background: rgba(6, 25, 56, 0.95);
    border: 1px solid rgba(33, 161, 247, 0.4);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    border-radius: 12px;
    padding: 16px 20px;
    animation: fadeIn 0.2s ease;
  }

  .mcc-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 6px;
    gap: 10px;
    flex-wrap: wrap;
  }

  .mcc-tag {
    font-size: 11px;
    font-weight: 800;
    color: #38BDF8;
  }

  .serum-pill {
    color: #34D399;
    background: rgba(52, 211, 153, 0.15);
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid rgba(52, 211, 153, 0.3);
  }

  .mcc-title {
    font-size: 14px;
    font-weight: 800;
    color: #FFFFFF;
    margin: 0;
    flex: 1;
  }

  .mcc-close {
    background: transparent;
    border: none;
    color: #94A3B8;
    font-size: 18px;
    line-height: 1;
    cursor: pointer;
    padding: 2px 6px;
  }

  .mcc-close:hover {
    color: #FFFFFF;
  }

  .mcc-desc {
    font-size: 13px;
    color: #CBD5E1;
    line-height: 1.5;
    margin: 0 0 10px 0;
  }

  .mcc-tests-tag {
    font-size: 11.5px;
    color: #BAE6FD;
    background: rgba(33, 161, 247, 0.1);
    border: 1px dashed rgba(33, 161, 247, 0.3);
    padding: 6px 12px;
    border-radius: 6px;
    line-height: 1.4;
  }

  /* Paused State */
  .paused * {
    animation-play-state: paused !important;
  }

  /* Reduced Motion Support */
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

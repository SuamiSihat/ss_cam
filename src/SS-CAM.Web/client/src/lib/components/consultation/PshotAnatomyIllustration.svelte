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
  let activeStep = $state<number>(1);

  // Sync active step with phase
  $effect(() => {
    activeStep = phase;
  });

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  const steps = $derived([
    {
      id: 1,
      title: lang === 'ms' ? '1. Konsultasi & Ujian Darah' : '1. Screening & Blood Review',
      sub: lang === 'ms' ? 'Penilaian kelayakan & persetujuan termaklum' : 'Eligibility assessment & consent'
    },
    {
      id: 2,
      title: lang === 'ms' ? '2. Pengambilan Darah Aseptik' : '2. Sterile Venipuncture',
      sub: lang === 'ms' ? 'Tabung antikoagulan steril' : 'Sterile anticoagulated tube'
    },
    {
      id: 3,
      title: lang === 'ms' ? '3. Sentrifugasi Kecerunan Ketumpatan' : '3. Density Centrifugation',
      sub: lang === 'ms' ? 'Pemisahan fraksi plasma kaya platlet' : 'Platelet-rich fraction separation'
    },
    {
      id: 4,
      title: lang === 'ms' ? '4. Pentadbiran Klinikal oleh Doktor' : '4. Doctor Administration',
      sub: lang === 'ms' ? 'Penghantaran autologus tempatan' : 'Aseptic target delivery'
    }
  ]);

  const hotspots = $derived([
    {
      id: 1,
      x: 130,
      y: 190,
      title: lang === 'ms' ? 'Pengambilan Darah Autologus Pesakit' : 'Autologous Blood Collection',
      desc: lang === 'ms'
        ? 'Darah pesakit sendiri diambil secara steril (venipuncture) menggunakan tiub berdaftar KKM bebas bahan tambahan sintetik.'
        : 'Patient’s autologous whole blood collected using sterile medical-grade anticoagulated collection tubes.'
    },
    {
      id: 2,
      x: 320,
      y: 180,
      title: lang === 'ms' ? 'Pemisahan Sentrifugasi 3-Lapisan' : 'Three-Layer Density Separation',
      desc: lang === 'ms'
        ? 'Putaran sentrifugasi terkalibrasi memisahkan sel darah merah (bawah) daripada plasma kaya platlet (lapisan emas atas).'
        : 'Calibrated centrifugation partitions whole blood into heavy erythrocytes (bottom), buffy coat (mid), and golden platelet-rich plasma (top).'
    },
    {
      id: 3,
      x: 500,
      y: 170,
      title: lang === 'ms' ? 'Granul-Alfa & Faktor Pertumbuhan (PDGF/VEGF)' : 'Alpha-Granules & Growth Factors (PDGF/VEGF)',
      desc: lang === 'ms'
        ? 'Platlet mengandungi granul-alfa kaya faktor pertumbuhan semulajadi yang merangsang pembaikan sel tisu dan pengaliran mikro.'
        : 'Concentrated autologous platelets release alpha-granule growth factors (VEGF, PDGF, TGF-β) supporting tissue recovery.'
    },
    {
      id: 4,
      x: 690,
      y: 190,
      title: lang === 'ms' ? 'Pentadbiran Klinikal & Pemantauan Doktor' : 'Clinical Delivery & Physician Oversight',
      desc: lang === 'ms'
        ? 'Prosedur dijalankan di dalam bilik rawatan aseptik oleh doktor perubatan berdaftar di bawah persetujuan termaklum pesakit.'
        : 'Procedure executed in an aseptic medical environment by a licensed physician under comprehensive informed consent.'
    }
  ]);

  function toggleHotspot(id: number) {
    activeHotspot = activeHotspot === id ? null : id;
  }
</script>

<div class="pshot-illustration-container" class:paused={!isPlaying} class:patient-mode={patientMode}>
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

      <!-- Step Navigation Selector Pills -->
      <div class="steps-pills-group" role="group" aria-label="Step selector">
        {#each steps as s}
          <button
            class="step-pill"
            class:active={activeStep === s.id}
            onclick={() => (activeStep = s.id)}
          >
            {s.title}
          </button>
        {/each}
      </div>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '💉 Aliran Prosedur Klinikal Autologus Aseptik' : '💉 Aseptic Autologous Procedural Workflow'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    <svg
      viewBox="0 0 800 360"
      class="pshot-svg"
      role="img"
      aria-labelledby="pshot-svg-title pshot-svg-desc"
    >
      <title id="pshot-svg-title">
        {lang === 'ms' ? 'Aliran Prosedur Rawatan Regeneratif P-Shot' : 'P-Shot Regenerative Clinical Procedural Workflow'}
      </title>
      <desc id="pshot-svg-desc">
        {lang === 'ms'
          ? 'Rajah proses 4 langkah menunjukkan konsultasi, venipuncture steril, pemisahan sentrifugasi PRP, dan pentadbiran klinikal berpandu doktor.'
          : 'Four-stage procedural workflow depicting patient consultation, sterile blood draw, centrifugal PRP separation, and doctor-led administration.'}
      </desc>

      <defs>
        <radialGradient id="pshotBgGrad" cx="50%" cy="50%" r="60%">
          <stop offset="0%" stop-color="#08234D" />
          <stop offset="100%" stop-color="#020C1E" />
        </radialGradient>

        <!-- Golden PRP Gradient -->
        <linearGradient id="prpGoldGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#FDE047" />
          <stop offset="60%" stop-color="#EAB308" />
          <stop offset="100%" stop-color="#CA8A04" />
        </linearGradient>

        <!-- Red Blood Cell Fraction Gradient -->
        <linearGradient id="rbcLayerGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#991B1B" />
          <stop offset="100%" stop-color="#7F1D1D" />
        </linearGradient>

        <filter id="prpGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3" result="glow" />
          <feComposite in="SourceGraphic" in2="glow" operator="over" />
        </filter>
      </defs>

      <!-- Background Canvas -->
      <rect width="800" height="360" rx="16" fill="url(#pshotBgGrad)" stroke="#0E3368" stroke-width="2" />

      <!-- Step Connecting Flow Arrows -->
      <g class="flow-connectors" stroke="rgba(33, 161, 247, 0.3)" stroke-width="2" stroke-dasharray="4,3">
        <line x1="200" y1="170" x2="250" y2="170" />
        <line x1="390" y1="170" x2="440" y2="170" />
        <line x1="580" y1="170" x2="630" y2="170" />
      </g>

      <!-- STEP 1: Sterile Blood Collection (Left Station) -->
      <g class="step-station station-1" class:active-station={activeStep === 1} transform="translate(60, 80)">
        <rect width="140" height="180" rx="14" fill={activeStep === 1 ? 'rgba(33, 161, 247, 0.15)' : 'rgba(255, 255, 255, 0.03)'} stroke={activeStep === 1 ? '#38BDF8' : 'rgba(255, 255, 255, 0.1)'} stroke-width={activeStep === 1 ? 2 : 1} />
        
        <!-- Blood Collection Tube -->
        <g transform="translate(50, 20)">
          <!-- Tube Glass Body -->
          <rect x="0" y="20" width="40" height="90" rx="8" fill="rgba(255, 255, 255, 0.08)" stroke="#94A3B8" stroke-width="1.5" />
          <!-- Rubber Stopper -->
          <rect x="-2" y="10" width="44" height="12" rx="3" fill="#DC2626" />
          <!-- Whole Blood Volume (Uniform Dark Red) -->
          <rect x="2" y="45" width="36" height="63" rx="6" fill="#DC2626" />
        </g>

        <text x="70" y="145" fill="#FFFFFF" font-size="11" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Langkah 1: Sampel' : 'Step 1: Blood Draw'}
        </text>
        <text x="70" y="162" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Darah Autologus' : 'Autologous Venipuncture'}
        </text>
      </g>

      <!-- STEP 2: Calibrated Centrifugation (Mid-Left Station) -->
      <g class="step-station station-2" class:active-station={activeStep === 2} transform="translate(250, 80)">
        <rect width="140" height="180" rx="14" fill={activeStep === 2 ? 'rgba(33, 161, 247, 0.15)' : 'rgba(255, 255, 255, 0.03)'} stroke={activeStep === 2 ? '#38BDF8' : 'rgba(255, 255, 255, 0.1)'} stroke-width={activeStep === 2 ? 2 : 1} />
        
        <!-- Centrifuge Rotor Schematic -->
        <g transform="translate(70, 65)">
          <circle cx="0" cy="0" r="32" fill="rgba(6, 25, 56, 0.8)" stroke="#21A1F7" stroke-width="2" class="centrifuge-rotor" class:spinning={isPlaying && activeStep === 2} />
          <circle cx="0" cy="0" r="8" fill="#38BDF8" />
          <line x1="-24" y1="0" x2="24" y2="0" stroke="#60A5FA" stroke-width="2" />
          <line x1="0" y1="-24" x2="0" y2="24" stroke="#60A5FA" stroke-width="2" />
        </g>

        <text x="70" y="145" fill="#FFFFFF" font-size="11" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Langkah 2: Putaran' : 'Step 2: Centrifuge'}
        </text>
        <text x="70" y="162" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Putaran Terkalibrasi' : 'Speed & G-Force Separation'}
        </text>
      </g>

      <!-- STEP 3: Separated Density Layers (Mid-Right Station) -->
      <g class="step-station station-3" class:active-station={activeStep === 3} transform="translate(440, 80)">
        <rect width="140" height="180" rx="14" fill={activeStep === 3 ? 'rgba(33, 161, 247, 0.15)' : 'rgba(255, 255, 255, 0.03)'} stroke={activeStep === 3 ? '#38BDF8' : 'rgba(255, 255, 255, 0.1)'} stroke-width={activeStep === 3 ? 2 : 1} />

        <!-- Fractionated Tube -->
        <g transform="translate(50, 20)">
          <!-- Outer Glass Tube -->
          <rect x="0" y="20" width="40" height="90" rx="8" fill="rgba(255, 255, 255, 0.05)" stroke="#38BDF8" stroke-width="1.5" />
          <!-- Layer 1: Golden PRP (Top) -->
          <rect x="2" y="35" width="36" height="35" rx="4" fill="url(#prpGoldGrad)" filter="url(#prpGlow)" />
          <!-- Layer 2: Buffy Coat (Middle white line) -->
          <rect x="2" y="69" width="36" height="4" fill="#F8FAFC" />
          <!-- Layer 3: Packed Red Blood Cells (Bottom) -->
          <rect x="2" y="73" width="36" height="35" rx="4" fill="url(#rbcLayerGrad)" />
        </g>

        <text x="70" y="145" fill="#FDE047" font-size="11" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Langkah 3: Fraksi PRP' : 'Step 3: PRP Layer'}
        </text>
        <text x="70" y="162" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Lapisan Platlet Emas' : 'Concentrated Platelets'}
        </text>
      </g>

      <!-- STEP 4: Clinician Administration (Right Station) -->
      <g class="step-station station-4" class:active-station={activeStep === 4} transform="translate(630, 80)">
        <rect width="130" height="180" rx="14" fill={activeStep === 4 ? 'rgba(33, 161, 247, 0.15)' : 'rgba(255, 255, 255, 0.03)'} stroke={activeStep === 4 ? '#38BDF8' : 'rgba(255, 255, 255, 0.1)'} stroke-width={activeStep === 4 ? 2 : 1} />

        <!-- Syringe Vector Silhouette with Golden PRP -->
        <g transform="translate(65, 60)">
          <rect x="-6" y="-30" width="12" height="45" rx="3" fill="url(#prpGoldGrad)" stroke="#38BDF8" stroke-width="1.5" />
          <line x1="0" y1="15" x2="0" y2="35" stroke="#E2E8F0" stroke-width="2" stroke-linecap="round" />
          <!-- Pulsing Growth Factor Sparks -->
          <circle cx="-12" cy="30" r="3" fill="#38BDF8" class="sparkle-dot d1" />
          <circle cx="12" cy="25" r="3" fill="#FDE047" class="sparkle-dot d2" />
          <circle cx="0" cy="42" r="3.5" fill="#34D399" class="sparkle-dot d3" />
        </g>

        <text x="65" y="145" fill="#38BDF8" font-size="11" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Langkah 4: Prosedur' : 'Step 4: Delivery'}
        </text>
        <text x="65" y="162" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Ditadbir oleh Doktor' : 'Physician-Administered'}
        </text>
      </g>

      <!-- Bottom Compliance Disclaimer Banner Box -->
      <g class="compliance-banner-box" transform="translate(60, 280)">
        <rect width="700" height="52" rx="10" fill="rgba(6, 25, 56, 0.9)" stroke="rgba(33, 161, 247, 0.3)" stroke-width="1" />
        <text x="20" y="24" fill="#38BDF8" font-size="10.5" font-weight="800">
          {lang === 'ms' ? '🛡️ PENYATA KESELAMATAN & KELAYAKAN KLINIKAL (KKM & AKTA IKLAN UBAT 1956):' : '🛡️ CLINICAL SAFETY & ETHICAL DISCLOSURE (MEDICINES ADVERTISEMENT BOARD):'}
        </text>
        <text x="20" y="40" fill="#CBD5E1" font-size="10">
          {lang === 'ms'
            ? 'Rawatan autologus dijalankan oleh doktor bertauliah selepas persetujuan termaklum (informed consent). Tiada sebarang tuntutan hasil mutlak.'
            : 'Autologous procedure conducted exclusively by licensed physicians under informed consent. Efficacy depends on individual biological response.'}
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
          <circle cx="0" cy="0" r="14" fill="#EAB308" fill-opacity="0.25" class="halo-circle" />
          <circle
            cx="0"
            cy="0"
            r="9"
            fill={activeHotspot === hs.id ? '#FDE047' : '#A16207'}
            stroke="#FEF08A"
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
  .pshot-illustration-container {
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
    background: rgba(234, 179, 8, 0.15);
    border: 1px solid rgba(234, 179, 8, 0.4);
    border-radius: 6px;
    color: #FDE047;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .ctrl-icon-btn:hover {
    background: rgba(234, 179, 8, 0.28);
    color: #FFFFFF;
    border-color: #FEF08A;
  }

  .steps-pills-group {
    display: inline-flex;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
  }

  .step-pill {
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

  .step-pill.active {
    background: #CA8A04;
    color: #FFFFFF;
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

  .pshot-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Centrifuge spinning animation */
  @keyframes spinRotor {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .spinning {
    animation: spinRotor 3s linear infinite;
    transform-origin: center;
  }

  /* Sparkles */
  @keyframes sparkPulse {
    0%, 100% { opacity: 0.3; transform: scale(0.8); }
    50% { opacity: 1; transform: scale(1.3); }
  }

  .sparkle-dot.d1 { animation: sparkPulse 1.8s ease-in-out infinite; }
  .sparkle-dot.d2 { animation: sparkPulse 1.8s ease-in-out 0.6s infinite; }
  .sparkle-dot.d3 { animation: sparkPulse 1.8s ease-in-out 1.2s infinite; }

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
    border: 1px solid rgba(234, 179, 8, 0.4);
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
    color: #FDE047;
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

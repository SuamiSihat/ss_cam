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

  const hotspots = $derived([
    {
      id: 1,
      x: 105,
      y: 190,
      title: lang === 'ms' ? 'Prob Aplikasi ESWT' : 'ESWT Applicator Probe',
      desc: lang === 'ms'
        ? 'Transduser akustik berfokus melepaskan gelombang kejutan tenaga rendah (0.09 mJ/mm²) terus ke tisu vaskular.'
        : 'Focused acoustic transducer delivering low-intensity shockwaves (0.09 mJ/mm²) directly to vascular target tissue.'
    },
    {
      id: 2,
      x: 235,
      y: 165,
      title: lang === 'ms' ? 'Gelombang Akustik & Tekanan Ricih' : 'Acoustic Pulse & Shear Stress',
      desc: lang === 'ms'
        ? 'Gelombang tenaga mekanikal menembusi membran tunika albuginea tanpa sebarang kerosakan kulit atau tisu.'
        : 'Mechanical acoustic wavefront traverses tunica albuginea without skin puncture or thermal tissue damage.'
    },
    {
      id: 3,
      x: 420,
      y: 115,
      title: lang === 'ms' ? 'Sel Endotelium & Isyarat VEGF/NO' : 'Endothelial Cells & VEGF/NO',
      desc: lang === 'ms'
        ? 'Tekanan ricih mekanikal merangsang pembebasan faktor pertumbuhan salur darah (VEGF) dan molekul nitrik oksida (NO).'
        : 'Micro-shear stress triggers cellular mechanotransduction, releasing VEGF and nitric oxide (NO) for vascular dilation.'
    },
    {
      id: 4,
      x: 580,
      y: 200,
      title: lang === 'ms' ? 'Neovaskularisasi & Kapilari Baharu' : 'Neovascularization & Capillary Bed',
      desc: lang === 'ms'
        ? 'Pembentukan jaringan kapilari mikro baharu di korpus kavernosum menyokong perfusi darah dan ketahanan ereksi semulajadi.'
        : 'Formation of new microvascular capillary networks in corpus cavernosum supporting natural perfusion and rigidity.'
    }
  ]);

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  function toggleHotspot(id: number) {
    activeHotspot = activeHotspot === id ? null : id;
  }
</script>

<div class="eswt-illustration-container" class:paused={!isPlaying} class:patient-mode={patientMode}>
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
          <!-- Pause SVG -->
          <svg viewBox="0 0 20 20" width="16" height="16" fill="currentColor">
            <rect x="5" y="4" width="3.5" height="12" rx="1" />
            <rect x="11.5" y="4" width="3.5" height="12" rx="1" />
          </svg>
        {:else}
          <!-- Play SVG -->
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
        {#if phase === 1}
          {lang === 'ms' ? 'Rangsangan Selular' : 'Cellular Activation'}
        {:else if phase === 2}
          {lang === 'ms' ? 'Neovaskularisasi' : 'Neovascularization'}
        {:else if phase === 3}
          {lang === 'ms' ? 'Pengukuhan Kapilari' : 'Capillary Strengthening'}
        {:else}
          {lang === 'ms' ? 'Penyelenggaraan Stabil' : 'Mature Stable Perfusion'}
        {/if}
      </span>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '🔬 Rajah Ilustrasi Mekanisme Perubatan' : '🔬 Illustrative Medical Simulation'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    <svg
      viewBox="0 0 800 360"
      class="eswt-svg"
      role="img"
      aria-labelledby="eswt-svg-title eswt-svg-desc"
    >
      <title id="eswt-svg-title">
        {lang === 'ms' ? 'Simulasi Mekanisme Tindakan Terapi ESWT' : 'ESWT Shockwave Therapy Mechanism Simulation'}
      </title>
      <desc id="eswt-svg-desc">
        {lang === 'ms'
          ? 'Keratan rentas mikrovaskular menunjukkan gelombang kejutan akustik merangsang faktor VEGF dan pembentukan kapilari darah baharu mengikut fasa rawatan.'
          : 'Microvascular cross-section showing acoustic shockwaves stimulating VEGF signaling and angiogenesis across clinical treatment phases.'}
      </desc>

      <defs>
        <!-- Background Grid Pattern -->
        <pattern id="eswtGrid" width="20" height="20" patternUnits="userSpaceOnUse">
          <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(33, 161, 247, 0.05)" stroke-width="0.5" />
        </pattern>

        <!-- Wavefront Gradient -->
        <linearGradient id="waveFrontGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#38BDF8" stop-opacity="0.9" />
          <stop offset="50%" stop-color="#21A1F7" stop-opacity="0.6" />
          <stop offset="100%" stop-color="#043388" stop-opacity="0.1" />
        </linearGradient>

        <!-- Tissue Bed Gradient -->
        <radialGradient id="tissueBedGrad" cx="60%" cy="50%" r="60%">
          <stop offset="0%" stop-color="#0A2540" stop-opacity="0.9" />
          <stop offset="60%" stop-color="#061938" stop-opacity="0.95" />
          <stop offset="100%" stop-color="#020C1E" stop-opacity="1" />
        </radialGradient>

        <!-- Blood Vessel Gradient -->
        <linearGradient id="arteryGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#EF4444" />
          <stop offset="50%" stop-color="#DC2626" />
          <stop offset="100%" stop-color="#B91C1C" />
        </linearGradient>

        <!-- Sprouting Capillary Glow -->
        <filter id="capillaryGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>

        <!-- Wavefront Glow -->
        <filter id="waveGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="2.5" result="glow" />
          <feComposite in="SourceGraphic" in2="glow" operator="over" />
        </filter>
      </defs>

      <!-- Grid Backdrop -->
      <rect width="800" height="360" fill="url(#eswtGrid)" rx="16" />

      <!-- Penile Corpus Cavernosum Vascular Tissue Bed Container -->
      <g class="tissue-bed-layer" transform="translate(160, 30)">
        <!-- Outer Boundary (Tunica Albuginea Sheath) -->
        <rect
          x="0"
          y="0"
          width="600"
          height="300"
          rx="24"
          fill="url(#tissueBedGrad)"
          stroke="#0F3A78"
          stroke-width="2.5"
        />

        <!-- Sheath Inner Rim (Collagen Band) -->
        <rect
          x="6"
          y="6"
          width="588"
          height="288"
          rx="20"
          fill="none"
          stroke="#21A1F7"
          stroke-width="1"
          stroke-opacity="0.25"
          stroke-dasharray="8,4"
        />

        <!-- Sinusoidal Mesh Network (Spongy Architecture) -->
        <g class="sinusoidal-network" opacity="0.45">
          <ellipse cx="120" cy="80" rx="40" ry="25" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="220" cy="120" rx="55" ry="35" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="340" cy="80" rx="60" ry="30" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="460" cy="110" rx="50" ry="32" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="140" cy="220" rx="50" ry="30" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="260" cy="200" rx="45" ry="30" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="380" cy="220" rx="55" ry="32" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
          <ellipse cx="490" cy="210" rx="45" ry="28" fill="rgba(33, 161, 247, 0.05)" stroke="#1E4976" stroke-width="1" />
        </g>

        <!-- Main Helicine Cavernous Artery (Supply Trunk) -->
        <path
          d="M 10 150 C 70 140, 120 160, 180 150 S 260 130, 320 150 S 400 160, 480 145 T 580 150"
          fill="none"
          stroke="url(#arteryGrad)"
          stroke-width="8"
          stroke-linecap="round"
        />

        <!-- Secondary Arteriolar Branches (Baseline - visible in all phases) -->
        <path d="M 180 150 Q 210 100 240 80" fill="none" stroke="#EF4444" stroke-width="4.5" stroke-linecap="round" />
        <path d="M 180 150 Q 200 200 230 220" fill="none" stroke="#EF4444" stroke-width="4.5" stroke-linecap="round" />
        <path d="M 320 150 Q 350 100 370 70" fill="none" stroke="#EF4444" stroke-width="4.5" stroke-linecap="round" />
        <path d="M 320 150 Q 340 200 370 230" fill="none" stroke="#EF4444" stroke-width="4.5" stroke-linecap="round" />

        <!-- PHASE 2+: Sprouting Capillaries (Angiogenesis Activated) -->
        {#if phase >= 2}
          <g class="phase-2-capillaries" filter="url(#capillaryGlow)">
            <!-- Sprouting branches from upper arteriole -->
            <path
              d="M 240 80 Q 260 65 290 60"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path"
            />
            <path
              d="M 240 80 Q 250 100 280 110"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path delay-1"
            />
            <!-- Sprouting branches from lower arteriole -->
            <path
              d="M 230 220 Q 255 235 285 240"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path"
            />
            <path
              d="M 230 220 Q 260 205 285 190"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path delay-2"
            />
            <!-- Mid section sprouts -->
            <path
              d="M 370 70 Q 400 60 430 65"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path"
            />
            <path
              d="M 370 230 Q 410 240 440 230"
              fill="none"
              stroke="#F87171"
              stroke-width={phase >= 3 ? 3.5 : 2.5}
              stroke-linecap="round"
              class="sprouting-path delay-1"
            />
          </g>
        {/if}

        <!-- PHASE 3+: Dense Microvascular Meshwork (Collateral Perfusion) -->
        {#if phase >= 3}
          <g class="phase-3-dense-mesh" filter="url(#capillaryGlow)">
            <path d="M 290 60 Q 330 55 370 70" fill="none" stroke="#FCA5A5" stroke-width="2.5" stroke-dasharray="3,1" />
            <path d="M 285 240 Q 330 250 370 230" fill="none" stroke="#FCA5A5" stroke-width="2.5" stroke-dasharray="3,1" />
            <path d="M 280 110 Q 310 130 330 110 T 370 70" fill="none" stroke="#FCA5A5" stroke-width="2" />
            <path d="M 285 190 Q 310 170 340 190 T 370 230" fill="none" stroke="#FCA5A5" stroke-width="2" />
            <!-- Distal Artery Perfusion -->
            <path d="M 480 145 Q 510 100 540 85" fill="none" stroke="#EF4444" stroke-width="3.5" stroke-linecap="round" />
            <path d="M 480 145 Q 510 190 540 215" fill="none" stroke="#EF4444" stroke-width="3.5" stroke-linecap="round" />
            <path d="M 540 85 Q 560 70 580 80" fill="none" stroke="#F87171" stroke-width="2.5" />
            <path d="M 540 215 Q 565 230 585 220" fill="none" stroke="#F87171" stroke-width="2.5" />
          </g>
        {/if}

        <!-- PHASE 4: Mature Micro-Circulation Micro-Spheres (Laminar Blood Flow) -->
        {#if phase === 4}
          <g class="phase-4-flow-particles">
            <circle cx="150" cy="150" r="3.5" fill="#FEE2E2" class="flow-particle p1" />
            <circle cx="260" cy="140" r="3" fill="#FEE2E2" class="flow-particle p2" />
            <circle cx="360" cy="155" r="3.5" fill="#FEE2E2" class="flow-particle p3" />
            <circle cx="460" cy="148" r="3" fill="#FEE2E2" class="flow-particle p4" />
            <circle cx="240" cy="80" r="2.5" fill="#FCA5A5" class="flow-particle p5" />
            <circle cx="370" cy="70" r="2.5" fill="#FCA5A5" class="flow-particle p6" />
            <circle cx="230" cy="220" r="2.5" fill="#FCA5A5" class="flow-particle p7" />
          </g>
        {/if}

        <!-- Nitric Oxide (NO) & VEGF Signaling Molecules Floating -->
        <g class="signaling-molecules" class:active-signaling={isPlaying}>
          <!-- Pulsing micro bubbles -->
          <circle cx="210" cy="110" r="4" fill="#38BDF8" opacity="0.8" class="signaling-bubble b1" />
          <circle cx="330" cy="100" r="4.5" fill="#67E8F9" opacity="0.85" class="signaling-bubble b2" />
          <circle cx="390" cy="170" r="3.5" fill="#38BDF8" opacity="0.75" class="signaling-bubble b3" />
          <circle cx="270" cy="190" r="4" fill="#67E8F9" opacity="0.8" class="signaling-bubble b4" />
          <circle cx="470" cy="130" r="4.5" fill="#38BDF8" opacity="0.85" class="signaling-bubble b5" />
        </g>

        <!-- Tissue Label Annotations -->
        <text x="20" y="30" fill="#64748B" font-size="11" font-weight="700" letter-spacing="0.5">
          {lang === 'ms' ? 'KORPUS KAVERNOSUM (TISU SPONS EREKSI)' : 'CORPUS CAVERNOSUM (VASCULAR BED)'}
        </text>
        <text x="320" y="285" fill="#38BDF8" font-size="11" font-weight="600" text-anchor="middle">
          {phase === 1
            ? (lang === 'ms' ? 'Fasa 1: Pengaktifan Enzim Sintase Nitrik Oksida (eNOS)' : 'Phase 1: Endothelial Nitric Oxide Synthase (eNOS) Activation')
            : phase === 2
            ? (lang === 'ms' ? 'Fasa 2: Tunas Kapilari Mikro Baharu (Angiogenesis VEGF)' : 'Phase 2: Active Capillary Sprouting (VEGF-Driven Angiogenesis)')
            : phase === 3
            ? (lang === 'ms' ? 'Fasa 3: Pematangan Jaringan Kapilari & Ketumpatan Tisu' : 'Phase 3: Dense Anastomotic Capillary Network Consolidation')
            : (lang === 'ms' ? 'Fasa 4: Aliran Darah Vaskular Optimum & Kestabilan Refraktori' : 'Phase 4: Optimal Micro-perfusion & Stable Hemodynamic Flow')}
        </text>
      </g>

      <!-- Acoustic Propagation Shockwaves (Emitted from Applicator Cone) -->
      <g class="acoustic-wavefronts" class:wave-animating={isPlaying} filter="url(#waveGlow)">
        <!-- Wavefront Arc 1 -->
        <path
          d="M 170 70 Q 210 180 170 290"
          fill="none"
          stroke="url(#waveFrontGrad)"
          stroke-width="5"
          stroke-linecap="round"
          class="wave-arc w1"
        />
        <!-- Wavefront Arc 2 -->
        <path
          d="M 215 80 Q 260 180 215 280"
          fill="none"
          stroke="url(#waveFrontGrad)"
          stroke-width="4.5"
          stroke-linecap="round"
          class="wave-arc w2"
        />
        <!-- Wavefront Arc 3 -->
        <path
          d="M 260 90 Q 310 180 260 270"
          fill="none"
          stroke="url(#waveFrontGrad)"
          stroke-width="4"
          stroke-linecap="round"
          class="wave-arc w3"
        />
        <!-- Wavefront Arc 4 -->
        <path
          d="M 305 100 Q 360 180 305 260"
          fill="none"
          stroke="url(#waveFrontGrad)"
          stroke-width="3"
          stroke-dasharray="6,4"
          stroke-linecap="round"
          class="wave-arc w4"
        />
      </g>

      <!-- ESWT Acoustic Transducer Probe Applicator (Left Station) -->
      <g class="eswt-probe-group" transform="translate(30, 80)">
        <!-- Transducer Handle Body -->
        <path
          d="M 0 50 L 60 50 L 85 80 L 115 80 L 115 120 L 85 120 L 60 150 L 0 150 Z"
          fill="#0B2347"
          stroke="#21A1F7"
          stroke-width="2"
        />

        <!-- Transducer Focusing Nozzle Cone -->
        <path
          d="M 115 80 L 140 92 L 140 108 L 115 120 Z"
          fill="#21A1F7"
          stroke="#38BDF8"
          stroke-width="1.5"
        />

        <!-- Coupling Gel Membrane Cushion -->
        <path
          d="M 140 92 Q 148 100 140 108"
          fill="none"
          stroke="#67E8F9"
          stroke-width="3.5"
          stroke-linecap="round"
        />

        <!-- Probe Label & Grip Grippers -->
        <line x1="20" y1="70" x2="20" y2="130" stroke="#1D4ED8" stroke-width="3" stroke-linecap="round" />
        <line x1="30" y1="70" x2="30" y2="130" stroke="#1D4ED8" stroke-width="3" stroke-linecap="round" />
        <line x1="40" y1="70" x2="40" y2="130" stroke="#1D4ED8" stroke-width="3" stroke-linecap="round" />

        <text x="35" y="103" fill="#FFFFFF" font-size="10" font-weight="800" text-anchor="middle" transform="rotate(-90 35 103)">
          ESWT PROBE
        </text>

        <!-- Energy Flux Spec Pill -->
        <rect x="5" y="160" width="110" height="20" rx="5" fill="rgba(33, 161, 247, 0.15)" stroke="#21A1F7" stroke-width="1" />
        <text x="60" y="174" fill="#38BDF8" font-size="9.5" font-weight="700" text-anchor="middle">
          0.09 mJ/mm² Focused
        </text>
      </g>

      <!-- Interactive Hotspot Pins (1, 2, 3, 4) -->
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
          <!-- Pulsing halo -->
          <circle cx="0" cy="0" r="14" fill="#21A1F7" fill-opacity="0.2" class="halo-circle" />
          <!-- Pin button circle -->
          <circle
            cx="0"
            cy="0"
            r="9"
            fill={activeHotspot === hs.id ? '#38BDF8' : '#043388'}
            stroke="#60A5FA"
            stroke-width="2"
          />
          <text
            x="0"
            y="3.5"
            text-anchor="middle"
            fill="#FFFFFF"
            font-size="9"
            font-weight="800"
          >
            {hs.id}
          </text>
        </g>
      {/each}
    </svg>
  </div>

  <!-- Interactive Hotspot Callout Details Card (Shown when a hotspot is clicked) -->
  {#if activeHotspot !== null}
    {@const selectedHs = hotspots.find(h => h.id === activeHotspot)}
    {#if selectedHs}
      <div class="hotspot-callout-card" role="region" aria-live="polite">
        <div class="hcc-head">
          <div class="hcc-badge">HOTSPOT #{selectedHs.id}</div>
          <h4 class="hcc-title">{selectedHs.title}</h4>
          <button class="hcc-close" onclick={() => (activeHotspot = null)} aria-label="Tutup / Close">
            ×
          </button>
        </div>
        <p class="hcc-desc">{selectedHs.desc}</p>
      </div>
    {/if}
  {/if}
</div>

<style>
  .eswt-illustration-container {
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
    gap: 12px;
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

  .eswt-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Keyframe Animations */
  @keyframes propagateWave {
    0% {
      opacity: 0.1;
      transform: translateX(-15px) scaleX(0.92);
    }
    50% {
      opacity: 0.95;
      transform: translateX(0px) scaleX(1);
    }
    100% {
      opacity: 0.2;
      transform: translateX(20px) scaleX(1.08);
    }
  }

  .wave-animating .wave-arc.w1 {
    animation: propagateWave 1.8s ease-in-out infinite;
  }

  .wave-animating .wave-arc.w2 {
    animation: propagateWave 1.8s ease-in-out 0.35s infinite;
  }

  .wave-animating .wave-arc.w3 {
    animation: propagateWave 1.8s ease-in-out 0.7s infinite;
  }

  .wave-animating .wave-arc.w4 {
    animation: propagateWave 1.8s ease-in-out 1.05s infinite;
  }

  /* Signaling Bubbles Float Animation */
  @keyframes floatSignaling {
    0%, 100% {
      transform: translateY(0px) scale(1);
      opacity: 0.7;
    }
    50% {
      transform: translateY(-8px) scale(1.15);
      opacity: 1;
    }
  }

  .active-signaling .signaling-bubble.b1 { animation: floatSignaling 2.4s ease-in-out infinite; }
  .active-signaling .signaling-bubble.b2 { animation: floatSignaling 2.4s ease-in-out 0.5s infinite; }
  .active-signaling .signaling-bubble.b3 { animation: floatSignaling 2.4s ease-in-out 1s infinite; }
  .active-signaling .signaling-bubble.b4 { animation: floatSignaling 2.4s ease-in-out 1.5s infinite; }
  .active-signaling .signaling-bubble.b5 { animation: floatSignaling 2.4s ease-in-out 2s infinite; }

  /* Blood Flow Particles Animation */
  @keyframes flowParticle {
    0% { transform: translateX(0px); opacity: 0.3; }
    50% { opacity: 0.95; }
    100% { transform: translateX(40px); opacity: 0.3; }
  }

  .flow-particle {
    animation: flowParticle 1.5s linear infinite;
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

  /* Hotspot Callout Popover Card */
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

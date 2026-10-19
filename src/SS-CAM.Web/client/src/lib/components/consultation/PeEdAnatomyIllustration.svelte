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
  let selectedIntervention = $state<number | null>(null);

  function togglePlay() {
    isPlaying = !isPlaying;
  }

  const hotspots = $derived([
    {
      id: 1,
      x: 140,
      y: 190,
      title: lang === 'ms' ? 'Saraf Pudendal & Reseptor Sensori Glans' : 'Pudendal Afferent Nerve & Sensory Receptors',
      desc: lang === 'ms'
        ? 'Reseptor sensori menghantar isyarat rangsangan sentuhan melalui serat saraf pudendal ke pusat saraf tunjang sacral.'
        : 'Sensory tactile mechanoreceptors transmit afferent neural signals via the pudendal nerve toward the sacral reflex center.'
    },
    {
      id: 2,
      x: 400,
      y: 130,
      title: lang === 'ms' ? 'Pusat Lengkok Refleks Saraf Tunjang (S2-S4 & T10-L2)' : 'Spinal Reflex Arc Centers (S2-S4 & T10-L2)',
      desc: lang === 'ms'
        ? 'Pusat integrasi autonomik. Parasimpatetik (S2-S4) mengekalkan aliran darah ereksi, manakala simpatetik (T10-L2) mengawal lonjakan refleks ejakulasi.'
        : 'Autonomic integration hub. Parasympathetic (S2-S4) maintains pro-erectile dilation; sympathetic (T10-L2) triggers emission threshold.'
    },
    {
      id: 3,
      x: 640,
      y: 175,
      title: lang === 'ms' ? 'Pusat Ambang Emisi & Otot Bulbocavernosus' : 'Emission Threshold & Bulbocavernosus Response',
      desc: lang === 'ms'
        ? 'Apabila ambang saraf dicapai, kontraksi ritmik otot bulbocavernosus dan duktus deferens mencetuskan ejakulasi.'
        : 'Crossing the sympathetic activation threshold triggers rhythmic bulbocavernosus contractions and seminal fluid propulsion.'
    },
    {
      id: 4,
      x: 350,
      y: 250,
      title: lang === 'ms' ? 'Titik Intervensi Teknik Tingkah Laku Klinikal' : 'Clinical Behavioral Intervention Points',
      desc: lang === 'ms'
        ? 'Teknik henti-mula (stop-start), pernafasan diafragma dan relaksasi lantai pelvis memintas isyarat simpatetik sebelum mencapai ambang refleks.'
        : 'Stop-start pacing, diaphragmatic breath regulation, and pelvic muscle relaxation interrupt sympathetic crescendo prior to climax.'
    }
  ]);

  const interventions = $derived([
    {
      id: 1,
      title: lang === 'ms' ? '1. Kawalan Ambang & Henti-Mula' : '1. Stop-Start Sensory Pacing',
      desc: lang === 'ms'
        ? 'Mengenal pasti paras rangsangan 7/10 sebelum titik tanpa kembali (point of inevitable climax).'
        : 'Recognizing the 7/10 arousal plateau before crossing the sympathetic point of no return.'
    },
    {
      id: 2,
      title: lang === 'ms' ? '2. Pernafasan Diafragma Ritmik' : '2. Diaphragmatic Breath Regulation',
      desc: lang === 'ms'
        ? 'Tarikan nafas dalam mengaktifkan saraf vagus dan parasimpatetik, menurunkan paras adrenalin.'
        : 'Slow diaphragmatic breaths stimulate the vagus nerve, calming sympathetic adrenaline surges.'
    },
    {
      id: 3,
      title: lang === 'ms' ? '3. Relaksasi Otot Bulbocavernosus' : '3. Conscious Pelvic Relaxation',
      desc: lang === 'ms'
        ? 'Mengelakkan ketegangan mengecut secara tidak sengaja di dasar pelvis yang mempercepatkan ejakulasi.'
        : 'Preventing involuntary pelvic floor muscle spasming that prematurely forces emission.'
    }
  ]);

  function toggleHotspot(id: number) {
    activeHotspot = activeHotspot === id ? null : id;
  }
</script>

<div class="peed-illustration-container" class:paused={!isPlaying} class:patient-mode={patientMode}>
  <!-- Controls Toolbar -->
  <div class="canvas-controls-toolbar">
    <div class="cct-left">
      <button
        class="ctrl-icon-btn"
        onclick={togglePlay}
        title={isPlaying ? (lang === 'ms' ? 'Jeda isyarat' : 'Pause neural pulse') : (lang === 'ms' ? 'Mulakan isyarat' : 'Resume neural pulse')}
        aria-label={isPlaying ? 'Pause neural pulse' : 'Play neural pulse'}
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
          {isPlaying ? (lang === 'ms' ? 'Jeda Isyarat' : 'Pause') : (lang === 'ms' ? 'Main' : 'Play')}
        </span>
      </button>

      <span class="phase-indicator-tag">
        {lang === 'ms' ? `Fasa ${phase}` : `Phase ${phase}`}:
        {phase === 1
          ? (lang === 'ms' ? 'Pemetaan Sensori & Refleks' : 'Sensory Reflex Mapping')
          : phase === 2
          ? (lang === 'ms' ? 'Kawalan Ambang Rangsangan' : 'Threshold Pacing & Latency')
          : phase === 3
          ? (lang === 'ms' ? 'Pengukuhan Respons Ereksi' : 'Response Stability & Confidence')
          : (lang === 'ms' ? 'Kawalan Neuromuskular Stabil' : 'Conditioned Reflex Mastery')}
      </span>
    </div>

    <div class="cct-right">
      <span class="simulation-note">
        {lang === 'ms' ? '🧠 Litar Refleks Saraf & Tingkah Laku' : '🧠 Neuromuscular Reflex Arc & Behavioral Circuit'}
      </span>
    </div>
  </div>

  <!-- SVG Viewport -->
  <div class="svg-viewport">
    <svg
      viewBox="0 0 800 360"
      class="peed-svg"
      role="img"
      aria-labelledby="peed-svg-title peed-svg-desc"
    >
      <title id="peed-svg-title">
        {lang === 'ms' ? 'Litar Refleks Neuromuskular PE/ED' : 'PE/ED Neuromuscular Reflex Arc & Behavioral Control'}
      </title>
      <desc id="peed-svg-desc">
        {lang === 'ms'
          ? 'Rajah litar saraf menunjukkan pengaliran isyarat sensori ke saraf tunjang, keseimbangan parasimpatetik-simpatetik, dan titik intervensi kawalan tingkah laku.'
          : 'Neural pathway circuit diagram displaying afferent sensory flow to spinal cord, autonomic balance, and behavioural modulation techniques.'}
      </desc>

      <defs>
        <radialGradient id="circuitBgGrad" cx="50%" cy="50%" r="60%">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="100%" stop-color="#020617" />
        </radialGradient>

        <linearGradient id="nerveAfferentGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#38BDF8" />
          <stop offset="100%" stop-color="#818CF8" />
        </linearGradient>

        <linearGradient id="sympatheticGrad" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#F59E0B" />
          <stop offset="100%" stop-color="#EF4444" />
        </linearGradient>

        <filter id="nerveGlow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3" result="glow" />
          <feComposite in="SourceGraphic" in2="glow" operator="over" />
        </filter>
      </defs>

      <!-- Background Canvas -->
      <rect width="800" height="360" rx="16" fill="url(#circuitBgGrad)" stroke="#1E293B" stroke-width="2" />

      <!-- Section 1: Sensory Receptors (Left Station: Glans / Peripheral Receptors) -->
      <g class="sensory-station" transform="translate(60, 130)">
        <rect width="130" height="110" rx="12" fill="rgba(33, 161, 247, 0.08)" stroke="#38BDF8" stroke-width="1.5" />
        <circle cx="65" cy="40" r="22" fill="rgba(56, 189, 248, 0.15)" stroke="#38BDF8" stroke-width="2" />
        <text x="65" y="44" fill="#38BDF8" font-size="12" font-weight="800" text-anchor="middle">SENSORY</text>
        <text x="65" y="75" fill="#FFFFFF" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Reseptor Glans' : 'Tactile Glans'}
        </text>
        <text x="65" y="90" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Rangsangan Sentuhan' : 'Afferent Input'}
        </text>
      </g>

      <!-- Section 2: Spinal Cord Reflex Arc Hub (Center Station: S2-S4 & T10-L2) -->
      <g class="spinal-station" transform="translate(320, 70)">
        <!-- Spinal Column Cylinder Silhouette -->
        <rect width="160" height="150" rx="14" fill="rgba(99, 102, 241, 0.08)" stroke="#6366F1" stroke-width="2" />
        <text x="80" y="24" fill="#A5B4FC" font-size="10.5" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'PUSAT SARAF TUNJANG' : 'SPINAL CORD REFLEX'}
        </text>

        <!-- S2-S4 Parasympathetic Pro-Erectile Zone -->
        <rect x="15" y="38" width="130" height="42" rx="6" fill="rgba(16, 185, 129, 0.15)" stroke="#10B981" stroke-width="1" />
        <text x="80" y="54" fill="#34D399" font-size="10" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Parasimpatetik (S2-S4)' : 'Parasympathetic (S2-S4)'}
        </text>
        <text x="80" y="70" fill="#A7F3D0" font-size="8.5" text-anchor="middle">
          {lang === 'ms' ? 'Aliran Darah & Ketegangan' : 'Pro-Erection & Perfusion'}
        </text>

        <!-- T10-L2 Sympathetic Emission Threshold Zone -->
        <rect x="15" y="90" width="130" height="44" rx="6" fill="rgba(239, 68, 68, 0.15)" stroke="#EF4444" stroke-width="1" />
        <text x="80" y="107" fill="#F87171" font-size="10" font-weight="800" text-anchor="middle">
          {lang === 'ms' ? 'Simpatetik (T10-L2)' : 'Sympathetic (T10-L2)'}
        </text>
        <text x="80" y="122" fill="#FECACA" font-size="8.5" text-anchor="middle">
          {lang === 'ms' ? 'Ambang Cetusan Refleks' : 'Emission Reflex Threshold'}
        </text>
      </g>

      <!-- Section 3: Motor Output Response (Right Station: Bulbocavernosus / Ejaculation) -->
      <g class="effector-station" transform="translate(590, 130)">
        <rect width="140" height="110" rx="12" fill="rgba(244, 63, 94, 0.08)" stroke="#F43F5E" stroke-width="1.5" />
        <circle cx="70" cy="40" r="22" fill="rgba(244, 63, 94, 0.15)" stroke="#F43F5E" stroke-width="2" />
        <text x="70" y="44" fill="#FB7185" font-size="11" font-weight="800" text-anchor="middle">MOTOR</text>
        <text x="70" y="75" fill="#FFFFFF" font-size="10" font-weight="700" text-anchor="middle">
          {lang === 'ms' ? 'Otot Pelvis & Emisi' : 'Bulbocavernosus'}
        </text>
        <text x="70" y="90" fill="#94A3B8" font-size="9" text-anchor="middle">
          {lang === 'ms' ? 'Kawalan Latensi Masa' : 'Ejaculatory Latency'}
        </text>
      </g>

      <!-- Connecting Neural Pathways -->
      <!-- Pathway 1: Afferent Pudendal Nerve (Sensory -> Spinal Cord) -->
      <path
        d="M 190 185 C 240 185, 270 120, 320 120"
        fill="none"
        stroke="url(#nerveAfferentGrad)"
        stroke-width="4"
        stroke-linecap="round"
        filter="url(#nerveGlow)"
      />
      <text x="250" y="145" fill="#38BDF8" font-size="9.5" font-weight="700" text-anchor="middle">
        {lang === 'ms' ? 'Saraf Pudendal (Aferen)' : 'Pudendal Nerve'}
      </text>

      <!-- Pathway 2: Efferent Sympathetic Route (Spinal Cord -> Motor Effector) -->
      <path
        d="M 480 180 C 520 180, 550 185, 590 185"
        fill="none"
        stroke="url(#sympatheticGrad)"
        stroke-width="4"
        stroke-linecap="round"
        filter="url(#nerveGlow)"
      />
      <text x="535" y="165" fill="#F87171" font-size="9.5" font-weight="700" text-anchor="middle">
        {lang === 'ms' ? 'Jalur Simpatetik (Eferen)' : 'Sympathetic Efferent'}
      </text>

      <!-- Animated Neural Pulses Flowing along Pathway 1 -->
      <g class="neural-pulse-group" class:animating={isPlaying}>
        <circle cx="210" cy="180" r="4.5" fill="#FFFFFF" class="pulse-node p1" />
        <circle cx="260" cy="155" r="4.5" fill="#67E8F9" class="pulse-node p2" />
        <circle cx="300" cy="125" r="4.5" fill="#A5B4FC" class="pulse-node p3" />
        <!-- Pulse on Pathway 2 -->
        <circle cx="505" cy="180" r="4.5" fill="#FCA5A5" class="pulse-node p4" />
        <circle cx="550" cy="183" r="4.5" fill="#EF4444" class="pulse-node p5" />
      </g>

      <!-- Lower Behavioral Intervention Zone (The Interruption Gates) -->
      <g class="behavioral-strip" transform="translate(180, 250)">
        <rect width="440" height="75" rx="10" fill="rgba(16, 185, 129, 0.08)" stroke="#10B981" stroke-width="1.5" stroke-dasharray="6,3" />
        <text x="220" y="22" fill="#34D399" font-size="11" font-weight="800" text-anchor="middle" letter-spacing="0.5">
          {lang === 'ms' ? '🛡️ MODULASI TINGKAH LAKU & TEKNIK KAWALAN AMBANG' : '🛡️ BEHAVIORAL MODULATION & THRESHOLD PACING'}
        </text>

        <!-- 3 Behavioral Intervention Gate Badges -->
        <g class="gate-badges" transform="translate(20, 32)">
          <rect width="120" height="30" rx="6" fill="rgba(33, 161, 247, 0.2)" stroke="#21A1F7" stroke-width="1" />
          <text x="60" y="19" fill="#E0F2FE" font-size="9" font-weight="700" text-anchor="middle">
            {lang === 'ms' ? '1. Pacing Henti-Mula' : '1. Stop-Start Pacing'}
          </text>
        </g>

        <g class="gate-badges" transform="translate(160, 32)">
          <rect width="120" height="30" rx="6" fill="rgba(16, 185, 129, 0.2)" stroke="#10B981" stroke-width="1" />
          <text x="60" y="19" fill="#E0F2FE" font-size="9" font-weight="700" text-anchor="middle">
            {lang === 'ms' ? '2. Nafas Diafragma' : '2. Breath Control'}
          </text>
        </g>

        <g class="gate-badges" transform="translate(300, 32)">
          <rect width="120" height="30" rx="6" fill="rgba(244, 63, 94, 0.2)" stroke="#F43F5E" stroke-width="1" />
          <text x="60" y="19" fill="#E0F2FE" font-size="9" font-weight="700" text-anchor="middle">
            {lang === 'ms' ? '3. Relaksasi Pelvis' : '3. Pelvic Relaxation'}
          </text>
        </g>

        <!-- Interruption Arrows pointing from gates to the pathways -->
        <path d="M 80 0 L 80 -40" stroke="#10B981" stroke-width="2" stroke-dasharray="3,3" stroke-linecap="round" />
        <path d="M 360 0 L 360 -40" stroke="#10B981" stroke-width="2" stroke-dasharray="3,3" stroke-linecap="round" />
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
          <circle cx="0" cy="0" r="14" fill="#8B5CF6" fill-opacity="0.25" class="halo-circle" />
          <circle
            cx="0"
            cy="0"
            r="9"
            fill={activeHotspot === hs.id ? '#A78BFA' : '#4C1D95'}
            stroke="#C4B5FD"
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
  .peed-illustration-container {
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
    background: rgba(139, 92, 246, 0.15);
    border: 1px solid rgba(139, 92, 246, 0.4);
    border-radius: 6px;
    color: #A78BFA;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .ctrl-icon-btn:hover {
    background: rgba(139, 92, 246, 0.28);
    color: #FFFFFF;
    border-color: #C4B5FD;
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

  .peed-svg {
    width: 100%;
    height: auto;
    max-height: 380px;
  }

  /* Keyframe Animations for Neural Pulses */
  @keyframes pulseFlow {
    0% { opacity: 0.2; transform: scale(0.9); }
    50% { opacity: 1; transform: scale(1.3); }
    100% { opacity: 0.2; transform: scale(0.9); }
  }

  .animating .pulse-node.p1 { animation: pulseFlow 1.6s ease-in-out infinite; }
  .animating .pulse-node.p2 { animation: pulseFlow 1.6s ease-in-out 0.3s infinite; }
  .animating .pulse-node.p3 { animation: pulseFlow 1.6s ease-in-out 0.6s infinite; }
  .animating .pulse-node.p4 { animation: pulseFlow 1.6s ease-in-out 0.9s infinite; }
  .animating .pulse-node.p5 { animation: pulseFlow 1.6s ease-in-out 1.2s infinite; }

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
    border: 1px solid rgba(139, 92, 246, 0.4);
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
    color: #A78BFA;
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

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  // 1. Box Breathing Engine (4-4-4-4)
  type BreathPhase = 'Inhale' | 'Hold (Full)' | 'Exhale' | 'Hold (Empty)';
  let isBreathingActive = $state(false);
  let currentPhase = $state<BreathPhase>('Inhale');
  let phaseSecondsRemaining = $state(4);
  let breathCycleCount = $state(0);
  let breathingTimer: any = null;

  function toggleBreathing() {
    isBreathingActive = !isBreathingActive;
    if (isBreathingActive) {
      startBreathingLoop();
      appState.addToast('Box breathing cycle started. Follow the circle.', 'info', '4-4-4-4 Breathing');
    } else {
      clearInterval(breathingTimer);
      currentPhase = 'Inhale';
      phaseSecondsRemaining = 4;
    }
  }

  function startBreathingLoop() {
    clearInterval(breathingTimer);
    breathingTimer = setInterval(() => {
      phaseSecondsRemaining -= 1;
      if (phaseSecondsRemaining <= 0) {
        phaseSecondsRemaining = 4;
        if (currentPhase === 'Inhale') currentPhase = 'Hold (Full)';
        else if (currentPhase === 'Hold (Full)') currentPhase = 'Exhale';
        else if (currentPhase === 'Exhale') currentPhase = 'Hold (Empty)';
        else if (currentPhase === 'Hold (Empty)') {
          currentPhase = 'Inhale';
          breathCycleCount += 1;
        }
      }
    }, 1000);
  }

  // 2. Hydration Tracker
  let waterIntakeMl = $state(1250);
  const WATER_GOAL_ML = 2000;

  function addWater(amount: number) {
    waterIntakeMl = Math.min(waterIntakeMl + amount, 3500);
    appState.addToast(`Added ${amount} mL water. Total: ${waterIntakeMl} mL / ${WATER_GOAL_ML} mL`, 'success', 'Hydration');
  }

  function resetWater() {
    waterIntakeMl = 0;
    appState.addToast('Hydration counter reset for today.', 'info');
  }

  // 3. Ergonomics & Eye Break Timer (20-20-20 rule)
  let eyeBreakSecondsLeft = $state(20 * 60); // 20 minutes
  let isEyeBreakRunning = $state(true);
  let eyeBreakTimer: any = null;

  function startEyeBreakTimer() {
    clearInterval(eyeBreakTimer);
    eyeBreakTimer = setInterval(() => {
      if (isEyeBreakRunning && eyeBreakSecondsLeft > 0) {
        eyeBreakSecondsLeft -= 1;
        if (eyeBreakSecondsLeft === 0) {
          appState.addToast('20 minutes elapsed! Take a 20-second break and look 20 feet (6m) away to relieve eye strain.', 'warning', '20-20-20 Eye Break');
          eyeBreakSecondsLeft = 20 * 60; // reset
        }
      }
    }, 1000);
  }

  function formatTimeMinutes(seconds: number) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  // 4. Ambient Focus Audio
  let isAudioPlaying = $state(false);
  let audioVolume = $state(70);
  let selectedStation = $state('SuamiSihat Live Radio');

  const radioStations = [
    { name: 'SuamiSihat Live Radio', desc: 'Direct corporate stream & lounge broadcasting' },
    { name: 'Deep Focus Lo-Fi', desc: 'Mellow beats for deep copywriting & design flow' },
    { name: 'Clinical Ambient Waves', desc: 'Subtle soundscapes for intense concentration' }
  ];

  function toggleAudio() {
    isAudioPlaying = !isAudioPlaying;
    if (isAudioPlaying) {
      appState.addToast(`Playing ${selectedStation}`, 'info', 'Studio Audio');
    }
  }

  onMount(() => {
    startEyeBreakTimer();
  });

  onDestroy(() => {
    clearInterval(breathingTimer);
    clearInterval(eyeBreakTimer);
  });
</script>

<div class="wellbeing-page">
  <!-- Header -->
  <header class="page-header">
    <div class="header-left">
      <div class="header-icon-wrap">
        <FluentIcons name="sparkles" size="24" color="var(--brand-primary, #022057)" />
      </div>
      <div>
        <h1 class="page-title">Creative wellbeing & focus suite</h1>
        <p class="page-subtitle">Box breathing, 20-20-20 ergonomics rest, hydration tracking, and ambient studio focus audio.</p>
      </div>
    </div>
    <div class="header-actions">
      <div class="wellbeing-live-badge">
        <span class="live-pulse"></span>
        <span>Flow state: Optimal</span>
      </div>
    </div>
  </header>

  <!-- Metrics Bar -->
  <div class="metrics-grid">
    <FluentCard class="metric-card">
      <span class="metric-label">TOTAL FOCUS TIME</span>
      <span class="metric-val primary">3h 45m</span>
      <span class="metric-sub">Session average today</span>
    </FluentCard>

    <FluentCard class="metric-card">
      <span class="metric-label">DAILY HYDRATION</span>
      <span class="metric-val green">{waterIntakeMl} / {WATER_GOAL_ML} mL</span>
      <div class="mini-progress-bar">
        <div class="progress-fill" style="width: {Math.min(100, (waterIntakeMl / WATER_GOAL_ML) * 100)}%;"></div>
      </div>
    </FluentCard>

    <FluentCard class="metric-card">
      <span class="metric-label">20-20-20 EYE BREAK</span>
      <span class="metric-val amber">{formatTimeMinutes(eyeBreakSecondsLeft)}</span>
      <span class="metric-sub">{isEyeBreakRunning ? 'Countdown active' : 'Paused'}</span>
    </FluentCard>

    <FluentCard class="metric-card">
      <span class="metric-label">BURNOUT RISK INDEX</span>
      <span class="metric-val green">Low / Balanced</span>
      <span class="metric-sub">Based on session intervals</span>
    </FluentCard>
  </div>

  <!-- Main 2-Column Suite Layout -->
  <div class="suite-grid">
    <!-- Left Column: Box Breathing Engine -->
    <FluentCard class="suite-card breathing-card">
      <div class="card-head">
        <div class="head-title-wrap">
          <FluentIcons name="circleDashed" size="20" color="var(--brand-primary, #022057)" />
          <h3>4-4-4-4 Box Breathing Engine</h3>
        </div>
        <span class="cycle-pill">{breathCycleCount} cycles completed</span>
      </div>
      <p class="card-desc">Equal-interval box breathing (Pranayama) slows heart rate and resets autonomic stress during intense design reviews.</p>

      <div class="breathing-stage">
        <div class="breathing-circle" class:active={isBreathingActive} class:inhale={currentPhase === 'Inhale'} class:hold-full={currentPhase === 'Hold (Full)'} class:exhale={currentPhase === 'Exhale'} class:hold-empty={currentPhase === 'Hold (Empty)'}>
          <div class="circle-inner">
            <span class="phase-name">{isBreathingActive ? currentPhase : 'Ready'}</span>
            <span class="phase-count">{isBreathingActive ? `${phaseSecondsRemaining}s` : '4s'}</span>
          </div>
        </div>
      </div>

      <div class="breathing-controls">
        <FluentButton appearance={isBreathingActive ? 'secondary' : 'primary'} onclick={toggleBreathing}>
          {isBreathingActive ? 'Pause Breathing' : 'Start 4-4-4-4 Breathing'}
        </FluentButton>
      </div>
    </FluentCard>

    <!-- Right Column: Hydration & Ergonomics -->
    <div class="right-stack">
      <!-- Hydration Card -->
      <FluentCard class="suite-card">
        <div class="card-head">
          <div class="head-title-wrap">
            <FluentIcons name="bolt" size="18" color="var(--color-ss-azure, #21A1F7)" />
            <h3>Hydration Tracker</h3>
          </div>
          <button type="button" class="reset-link" onclick={resetWater}>Reset</button>
        </div>
        <p class="card-desc">Maintaining 2,000 mL daily intake prevents afternoon fatigue and keeps creative cognitive stamina sharp.</p>

        <div class="water-progress-wrap">
          <div class="water-bar">
            <div class="water-fill" style="width: {Math.min(100, (waterIntakeMl / WATER_GOAL_ML) * 100)}%;"></div>
          </div>
          <div class="water-numbers">
            <span>{waterIntakeMl} mL logged</span>
            <span>Goal: {WATER_GOAL_ML} mL</span>
          </div>
        </div>

        <div class="water-quick-buttons">
          <button type="button" class="water-add-btn" onclick={() => addWater(250)}>+250 mL (Cup)</button>
          <button type="button" class="water-add-btn" onclick={() => addWater(500)}>+500 mL (Bottle)</button>
          <button type="button" class="water-add-btn" onclick={() => addWater(750)}>+750 mL (Flask)</button>
        </div>
      </FluentCard>

      <!-- Ergonomics & Eye Break (20-20-20) -->
      <FluentCard class="suite-card">
        <div class="card-head">
          <div class="head-title-wrap">
            <FluentIcons name="eye" size="18" color="var(--brand-primary, #022057)" />
            <h3>20-20-20 Ergonomics & Eye Break</h3>
          </div>
          <button type="button" class="timer-toggle-btn" onclick={() => (isEyeBreakRunning = !isEyeBreakRunning)}>
            {isEyeBreakRunning ? 'Pause' : 'Resume'}
          </button>
        </div>
        <p class="card-desc">Every 20 minutes, gaze at an object 20 feet (6 meters) away for at least 20 seconds to prevent digital eye strain.</p>

        <div class="ergo-guidelines">
          <div class="ergo-rule-item">
            <span class="ergo-num">20m</span>
            <span>Focus work interval</span>
          </div>
          <div class="ergo-rule-item">
            <span class="ergo-num">20s</span>
            <span>Rest duration</span>
          </div>
          <div class="ergo-rule-item">
            <span class="ergo-num">20ft</span>
            <span>Distant viewing point</span>
          </div>
        </div>
      </FluentCard>

      <!-- Ambient Studio Radio Quick Widget -->
      <FluentCard class="suite-card">
        <div class="card-head">
          <div class="head-title-wrap">
            <FluentIcons name="volume" size="18" color="var(--brand-primary, #022057)" />
            <h3>Ambient Studio Audio</h3>
          </div>
          <span class="station-status-dot" class:playing={isAudioPlaying}></span>
        </div>

        <div class="radio-selector-wrap">
          <label for="wellbeing-station-select" class="sr-only">Radio Station</label>
          <select id="wellbeing-station-select" class="station-select" bind:value={selectedStation}>
            {#each radioStations as st}
              <option value={st.name}>{st.name} — {st.desc}</option>
            {/each}
          </select>
        </div>

        <div class="audio-controls-row">
          <FluentButton appearance={isAudioPlaying ? 'secondary' : 'primary'} onclick={toggleAudio}>
            {isAudioPlaying ? 'Stop Audio' : 'Play Radio'}
          </FluentButton>
          <div class="volume-slider-wrap">
            <FluentIcons name="volume" size="14" color="var(--text-secondary, #64748B)" />
            <input type="range" min="0" max="100" bind:value={audioVolume} class="volume-range" aria-label="Audio Volume" />
            <span class="volume-label">{audioVolume}%</span>
          </div>
        </div>
      </FluentCard>
    </div>
  </div>
</div>

<style>
  .wellbeing-page {
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding: 24px;
    max-width: 1320px;
    margin: 0 auto;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-subtle, #E2E8F0);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .header-icon-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--brand-tint, #E8F1FC);
  }

  .page-title {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .page-subtitle {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 3px 0 0 0;
  }

  .wellbeing-live-badge {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    border-radius: 20px;
    background: #DCFCE7;
    color: #107C41;
    font-size: 12px;
    font-weight: 700;
  }

  .live-pulse {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #107C41;
  }

  /* Metrics Grid */
  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 14px;
  }

  :global(.metric-card) {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 16px !important;
    border: 1px solid var(--border-subtle, #E2E8F0);
  }

  .metric-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-secondary, #64748B);
    text-transform: uppercase;
  }

  .metric-val {
    font-size: 22px;
    font-weight: 800;
  }

  .metric-val.primary { color: var(--brand-primary, #022057); }
  .metric-val.green { color: #107C41; }
  .metric-val.amber { color: #D83B01; }

  .metric-sub {
    font-size: 11.5px;
    color: var(--text-secondary, #94A3B8);
  }

  .mini-progress-bar {
    width: 100%;
    height: 6px;
    border-radius: 3px;
    background: var(--surface-bg, #F1F5F9);
    overflow: hidden;
    margin-top: 4px;
  }

  .progress-fill {
    height: 100%;
    background: #107C41;
    border-radius: 3px;
    transition: width 0.3s ease;
  }

  /* Suite Grid */
  .suite-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }

  :global(.suite-card) {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 20px !important;
    border: 1px solid var(--border-subtle, #E2E8F0);
  }

  .card-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .head-title-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .head-title-wrap h3 {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary, #1C1C1C);
    margin: 0;
  }

  .cycle-pill {
    font-size: 11px;
    font-weight: 600;
    color: var(--brand-primary, #022057);
    background: var(--brand-tint, #E8F1FC);
    padding: 3px 8px;
    border-radius: 12px;
  }

  .card-desc {
    font-size: 13px;
    color: var(--text-secondary, #64748B);
    margin: 0;
    line-height: 1.4;
  }

  /* Breathing Circle */
  .breathing-stage {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 40px 0;
  }

  .breathing-circle {
    width: 200px;
    height: 200px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(2, 32, 87, 0.1) 0%, rgba(33, 161, 247, 0.2) 100%);
    border: 4px solid var(--brand-primary, #022057);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 4s ease-in-out, border-color 0.5s ease;
  }

  .breathing-circle.inhale {
    transform: scale(1.25);
    border-color: #21A1F7;
  }

  .breathing-circle.hold-full {
    transform: scale(1.25);
    border-color: #FCE53D;
  }

  .breathing-circle.exhale {
    transform: scale(0.85);
    border-color: #107C41;
  }

  .breathing-circle.hold-empty {
    transform: scale(0.85);
    border-color: var(--brand-primary, #022057);
  }

  .circle-inner {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .phase-name {
    font-size: 15px;
    font-weight: 700;
    color: var(--brand-primary, #022057);
  }

  .phase-count {
    font-size: 26px;
    font-weight: 800;
    color: var(--text-primary, #1C1C1C);
  }

  .breathing-controls {
    display: flex;
    justify-content: center;
    margin-top: 8px;
  }

  /* Right Stack */
  .right-stack {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .reset-link, .timer-toggle-btn {
    font-size: 12px;
    font-weight: 600;
    color: var(--brand-primary, #022057);
    background: none;
    border: none;
    cursor: pointer;
  }

  .water-progress-wrap {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .water-bar {
    width: 100%;
    height: 10px;
    border-radius: 5px;
    background: var(--surface-bg, #F1F5F9);
    overflow: hidden;
  }

  .water-fill {
    height: 100%;
    background: #21A1F7;
    border-radius: 5px;
    transition: width 0.3s ease;
  }

  .water-numbers {
    display: flex;
    justify-content: space-between;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
  }

  .water-quick-buttons {
    display: flex;
    gap: 8px;
  }

  .water-add-btn {
    flex: 1;
    padding: 8px 0;
    font-size: 12px;
    font-weight: 600;
    color: var(--brand-primary, #022057);
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .water-add-btn:hover {
    background: var(--brand-tint, #E8F1FC);
    border-color: var(--brand-primary, #022057);
  }

  /* Ergonomics */
  .ergo-guidelines {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
    margin-top: 4px;
  }

  .ergo-rule-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    padding: 10px 8px;
    border-radius: 8px;
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    font-size: 11px;
    color: var(--text-secondary, #64748B);
  }

  .ergo-num {
    font-size: 16px;
    font-weight: 800;
    color: var(--brand-primary, #022057);
    margin-bottom: 2px;
  }

  /* Radio */
  .station-status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #94A3B8;
  }

  .station-status-dot.playing {
    background: #107C41;
  }

  .station-select {
    width: 100%;
    padding: 8px 12px;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary, #1C1C1C);
    background: var(--surface-bg, #F8FAFC);
    border: 1px solid var(--border-subtle, #E2E8F0);
    border-radius: 6px;
    outline: none;
    cursor: pointer;
    min-height: 36px;
  }

  .audio-controls-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  .volume-slider-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 1;
    max-width: 220px;
  }

  .volume-range {
    flex: 1;
  }

  .volume-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary, #64748B);
    min-width: 32px;
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    border: 0;
  }

  @media (max-width: 900px) {
    .suite-grid {
      grid-template-columns: 1fr;
    }
  }
</style>

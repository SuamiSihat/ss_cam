<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import copy, { getErrorMessage } from '$lib/copy';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentErrorBanner from '$lib/components/ui/FluentErrorBanner.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import { ApiClient } from '$lib/services/api';
  import {
    getConsultationCopy,
    getStoredConsultationLang,
    setStoredConsultationLang,
    type ConsultationLang,
    type TreatmentData
  } from '$lib/config/consultation.i18n';
  import EswtAnatomyIllustration from '$lib/components/consultation/EswtAnatomyIllustration.svelte';
  import TrtHormoneIllustration from '$lib/components/consultation/TrtHormoneIllustration.svelte';
  import KegelAnatomyIllustration from '$lib/components/consultation/KegelAnatomyIllustration.svelte';
  import PeEdAnatomyIllustration from '$lib/components/consultation/PeEdAnatomyIllustration.svelte';
  import FertilityAnatomyIllustration from '$lib/components/consultation/FertilityAnatomyIllustration.svelte';
  import PshotAnatomyIllustration from '$lib/components/consultation/PshotAnatomyIllustration.svelte';
  import ReferencePanel from '$lib/components/consultation/ReferencePanel.svelte';

  type TreatmentKey = 'eswt' | 'kegel' | 'pshot' | 'fertility' | 'trt' | 'pe_ed';

  // Component state
  let currentLang = $state<ConsultationLang>(getStoredConsultationLang());
  let selectedTreatment = $state<TreatmentKey>('eswt');
  let selectedPhase = $state(1); // 1, 2, 3, 4
  let isPatientView = $state(false);

  // References drawer state (Step 4)
  let refPanelOpen = $state(false);
  let highlightedRefId = $state<number | null>(null);

  function jumpToReference(refId: number) {
    highlightedRefId = refId;
    refPanelOpen = true;
    setTimeout(() => {
      const el = document.getElementById(`ref-card-${refId}`);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 100);
    setTimeout(() => {
      highlightedRefId = null;
    }, 3500);
  }

  // Dispatch modal state
  let patientName = $state('');
  let patientPhone = $state('');
  let followUpDate = $state('');
  let dispatchModalOpen = $state(false);
  let dispatchResult = $state<any>(null);
  let isDispatching = $state(false);
  let dispatchError = $state<string | null>(null);

  // Branches & pricing state
  let branches = $state<any[]>([]);
  let isLoadingBranches = $state(false);
  let branchError = $state<string | null>(null);
  let selectedBranch = $state('SSC-BSR');

  // Dialog keyboard & focus management
  let dialogElement: HTMLDivElement | null = $state(null);
  let previousActiveElement: HTMLElement | null = $state(null);

  // Derived copy & data
  const t = $derived(getConsultationCopy(currentLang));
  const activeTreatment = $derived<TreatmentData>(t.treatments[selectedTreatment]);
  const activePhaseInfo = $derived(activeTreatment.phases[selectedPhase - 1]);
  const activeBranch = $derived(branches.find((b: any) => b.code === selectedBranch) ?? null);
  const pricing = $derived(activeBranch?.pricing ?? null);

  onMount(async () => {
    await loadBranches();
  });

  function switchLanguage(lang: ConsultationLang) {
    currentLang = lang;
    setStoredConsultationLang(lang);
  }

  function togglePatientView() {
    isPatientView = !isPatientView;
    if (isPatientView) {
      if (typeof document !== 'undefined' && document.fullscreenEnabled && !document.fullscreenElement) {
        document.documentElement.requestFullscreen?.().catch(() => {});
      }
    } else {
      if (typeof document !== 'undefined' && document.fullscreenElement) {
        document.exitFullscreen?.().catch(() => {});
      }
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      if (dispatchModalOpen) {
        dispatchModalOpen = false;
        return;
      }
      if (isPatientView) {
        togglePatientView();
      }
    }
  }

  async function loadBranches() {
    isLoadingBranches = true;
    branchError = null;
    try {
      const res = await ApiClient.request('/clinic/branches');
      branches = res.branches || [];
      if (branches.length > 0 && !branches.some((b: any) => b.code === selectedBranch)) {
        selectedBranch = branches[0].code;
      }
    } catch (err: any) {
      branchError = getErrorMessage(err, 'We couldn\'t load the clinic branch information. Please try again.');
    } finally {
      isLoadingBranches = false;
    }
  }

  function formatPrice(amount: number | null | undefined): string {
    if (amount === null || amount === undefined) return '-';
    return (pricing?.currency ?? 'RM') + ' ' + Number(amount).toLocaleString('en-MY');
  }

  function openDispatchModal() {
    dispatchModalOpen = true;
    dispatchError = null;
    previousActiveElement = (typeof document !== 'undefined' ? document.activeElement : null) as HTMLElement | null;
    setTimeout(() => {
      const input = document.getElementById('pt-name');
      input?.focus();
    }, 50);
  }

  function closeDispatchModal() {
    dispatchModalOpen = false;
    if (previousActiveElement) {
      previousActiveElement.focus();
      previousActiveElement = null;
    }
  }

  async function handleDispatchCare() {
    if (!patientName.trim()) {
      appState.addToast(t.dispatchModal.nameWarning, 'warning');
      return;
    }

    isDispatching = true;
    dispatchError = null;
    try {
      dispatchResult = await ApiClient.request('/clinic/care-dispatch', {
        method: 'POST',
        body: JSON.stringify({
          patientName,
          patientPhone,
          protocolId: selectedTreatment,
          branchCode: selectedBranch,
          followUpDate
        })
      });
      appState.addToast(t.dispatchModal.successToast, 'success');
    } catch (e: any) {
      const msg = getErrorMessage(e, t.dispatchModal.errorDefault);
      dispatchError = msg;
      appState.addToast(msg, 'error');
    } finally {
      isDispatching = false;
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

<div class="consult-suite-view" class:patient-mode={isPatientView}>
  {#if branchError}
    <FluentErrorBanner
      title="Unable to connect to clinic services"
      message={branchError}
      retryLabel="Retry Connection"
      onRetry={loadBranches}
    />
  {/if}

  <!-- Patient View Dedicated Notification Banner -->
  {#if isPatientView}
    <aside class="patient-mode-banner" role="banner">
      <div class="pmb-left">
        <span class="pmb-badge">{t.patientViewBadge}</span>
        <span class="pmb-hint">{t.patientViewHint}</span>
      </div>
      <div class="pmb-right">
        <!-- Language Switcher in Patient View -->
        <div class="lang-toggle-group" role="group" aria-label={t.langToggleAria}>
          <button
            class="lang-btn"
            class:active={currentLang === 'ms'}
            onclick={() => switchLanguage('ms')}
            aria-pressed={currentLang === 'ms'}
          >
            BM
          </button>
          <button
            class="lang-btn"
            class:active={currentLang === 'en'}
            onclick={() => switchLanguage('en')}
            aria-pressed={currentLang === 'en'}
          >
            EN
          </button>
        </div>
        <FluentButton appearance="secondary" onclick={togglePatientView}>
          <FluentIcons name="close" size={14} /> {t.exitPatientViewBtn}
        </FluentButton>
      </div>
    </aside>
  {/if}

  <!-- Slim Header (Doctor Mode) -->
  {#if !isPatientView}
    <header class="suite-header">
      <div class="header-titles">
        <div class="suite-pill">{t.badge}</div>
        <h1 class="suite-title">{t.title}</h1>
        <p class="suite-desc">{t.desc}</p>
      </div>

      <div class="header-actions">
        <!-- Bilingual Language Selector Toggle -->
        <div class="lang-toggle-group" role="group" aria-label={t.langToggleAria}>
          <button
            class="lang-btn"
            class:active={currentLang === 'ms'}
            onclick={() => switchLanguage('ms')}
            aria-pressed={currentLang === 'ms'}
          >
            BM
          </button>
          <button
            class="lang-btn"
            class:active={currentLang === 'en'}
            onclick={() => switchLanguage('en')}
            aria-pressed={currentLang === 'en'}
          >
            EN
          </button>
        </div>

        <!-- Patient Presentation Mode Button -->
        <FluentButton appearance="secondary" onclick={togglePatientView} aria-label={t.patientViewBtn}>
          <FluentIcons name="tv" size={15} /> {t.patientViewBtn}
        </FluentButton>

        <!-- Dispatch Care Plan Modal Trigger -->
        <FluentButton appearance="primary" onclick={openDispatchModal}>
          <FluentIcons name="phone" size={15} /> {t.sendGuideBtn}
        </FluentButton>
      </div>
    </header>
  {/if}

  <!-- Treatment Selector Sticky Segmented Control (Vector Icons, No Raw Emoji) -->
  <nav class="treatment-nav" aria-label="Pilihan Rawatan / Treatment Selection">
    <!-- ESWT -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'eswt'}
      onclick={() => { selectedTreatment = 'eswt'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'eswt'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.eswt.label}</div>
        <div class="tab-sub">{t.tabs.eswt.sub}</div>
      </div>
    </button>

    <!-- Kegel -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'kegel'}
      onclick={() => { selectedTreatment = 'kegel'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'kegel'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M7 11V4a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v7" />
          <path d="M5 14h14l-1.5 5a2 2 0 0 1-1.9 1.4H8.4a2 2 0 0 1-1.9-1.4L5 14z" />
          <path d="M9 17h6" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.kegel.label}</div>
        <div class="tab-sub">{t.tabs.kegel.sub}</div>
      </div>
    </button>

    <!-- P-Shot -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'pshot'}
      onclick={() => { selectedTreatment = 'pshot'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'pshot'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <path d="m18 2 4 4" />
          <path d="m17 7 3-3" />
          <path d="M19 9 8.7 19.3c-.4.4-1 .4-1.4 0l-2.6-2.6c-.4-.4-.4-1 0-1.4L15 5" />
          <path d="m9 11 4 4" />
          <path d="m5 19-3 3" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.pshot.label}</div>
        <div class="tab-sub">{t.tabs.pshot.sub}</div>
      </div>
    </button>

    <!-- Fertility -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'fertility'}
      onclick={() => { selectedTreatment = 'fertility'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'fertility'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M2 15c6.667-6 13.333 0 20-6" />
          <path d="M9 22c1.798-1.998 2.518-3.995 2.807-5.993" />
          <path d="M15 2c-1.798 1.998-2.518 3.995-2.807 5.993" />
          <path d="m17 6-2.5-2.5" />
          <path d="m14 8-4-4" />
          <path d="m7 18 2.5 2.5" />
          <path d="m10 16 4 4" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.fertility.label}</div>
        <div class="tab-sub">{t.tabs.fertility.sub}</div>
      </div>
    </button>

    <!-- TRT -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'trt'}
      onclick={() => { selectedTreatment = 'trt'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'trt'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
          <circle cx="12" cy="14" r="3" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.trt.label}</div>
        <div class="tab-sub">{t.tabs.trt.sub}</div>
      </div>
    </button>

    <!-- PE/ED -->
    <button
      class="treatment-card-tab"
      class:active={selectedTreatment === 'pe_ed'}
      onclick={() => { selectedTreatment = 'pe_ed'; selectedPhase = 1; }}
      aria-pressed={selectedTreatment === 'pe_ed'}
    >
      <div class="tab-icon-box">
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10" />
          <circle cx="12" cy="12" r="6" />
          <circle cx="12" cy="12" r="2" />
        </svg>
      </div>
      <div class="tab-meta">
        <div class="tab-label">{t.tabs.pe_ed.label}</div>
        <div class="tab-sub">{t.tabs.pe_ed.sub}</div>
      </div>
    </button>
  </nav>

  <!-- Full-Width Anatomy Stage Hero (Edge-to-Edge Experience) -->
  <main class="anatomy-stage-hero" aria-label="Simulasi Anatomi Klinikal">
    <div class="stage-header-strip">
      <div class="stage-tag-group">
        <span class="stage-top-pill">{t.stage.topTag}</span>
        <button
          type="button"
          class="evidence-badge-btn"
          onclick={() => jumpToReference(activeTreatment.evidence.refId)}
          title="{currentLang === 'ms' ? 'Lihat rujukan garis panduan' : 'View guideline citation'} [{activeTreatment.evidence.refId}]"
        >
          <FluentIcons name="info" size={13} />
          <span>{t.stage.evidenceLevelTitle} {activeTreatment.evidence.levelLabel}</span>
          <span class="cite-sup">[{activeTreatment.evidence.refId}]</span>
        </button>
      </div>

      <h2 class="stage-treatment-title">{activeTreatment.title}</h2>
      <p class="stage-treatment-desc">{activeTreatment.description}</p>
    </div>

    <!-- Center Stage Vector Canvas -->
    <div class="stage-canvas-viewport">
      {#if selectedTreatment === 'eswt'}
        <EswtAnatomyIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {:else if selectedTreatment === 'kegel'}
        <KegelAnatomyIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {:else if selectedTreatment === 'pshot'}
        <PshotAnatomyIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {:else if selectedTreatment === 'fertility'}
        <FertilityAnatomyIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {:else if selectedTreatment === 'trt'}
        <TrtHormoneIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {:else if selectedTreatment === 'pe_ed'}
        <PeEdAnatomyIllustration phase={selectedPhase} lang={currentLang} patientMode={isPatientView} />
      {/if}
    </div>

    <!-- Floating Phase Scrubber Docked along the Bottom of the Stage -->
    <div class="stage-scrubber-dock">
      <div class="scrubber-head">
        <span class="scrubber-title">
          <FluentIcons name="timeline" size={14} /> {t.stage.phaseScrubberTitle}: {activePhaseInfo.title}
        </span>
        <span class="scrubber-active-metric">{activePhaseInfo.metric}</span>
      </div>

      <!-- Phase Segment Selector Buttons -->
      <div class="scrubber-pills">
        {#each activeTreatment.phases as p}
          <button
            class="scrubber-pill-btn"
            class:selected={selectedPhase === p.phase}
            onclick={() => (selectedPhase = p.phase)}
            aria-pressed={selectedPhase === p.phase}
          >
            {currentLang === 'ms' ? `Fasa ${p.phase}` : `Phase ${p.phase}`}
          </button>
        {/each}
      </div>

      <!-- Scrubber Slider -->
      <div class="scrubber-range-container">
        <div class="scrubber-range-ticks">
          <span>{t.stage.week1Label}</span>
          <span>{t.stage.week6Label}</span>
          <span>{t.stage.week12Label}</span>
        </div>
        <input
          type="range"
          min="1"
          max="4"
          step="1"
          bind:value={selectedPhase}
          class="stage-range-slider"
          aria-label={t.stage.phaseScrubberTitle}
        />
      </div>
    </div>
  </main>

  <!-- Horizontal Phase Details Strip Beneath the Stage -->
  <section class="phase-details-strip" aria-labelledby="phase-details-title">
    <div class="phase-metric-card">
      <div class="pms-label">{currentLang === 'ms' ? 'Sasaran Fisiologi' : 'Physiological Target'}</div>
      <div class="pms-value-badge">{activePhaseInfo.metric}</div>
      <h3 id="phase-details-title" class="pms-title">{activePhaseInfo.title}</h3>
    </div>

    <div class="phase-highlight-card">
      <div class="pms-label">{currentLang === 'ms' ? 'Sorotan Fasa' : 'Phase Highlight'}</div>
      <div class="pms-highlight">{activePhaseInfo.highlight}</div>
    </div>

    <div class="phase-clinical-card">
      <div class="pms-label">{currentLang === 'ms' ? 'Huraian Mekanisme Tindakan' : 'Clinical Mechanism Details'}</div>
      <p class="pms-details">{activePhaseInfo.details}</p>
    </div>
  </section>

  <!-- Evidence & Safety Row (Target Patient, Contraindications, Clinical Notes) -->
  <section class="evidence-safety-row" aria-label="Bukti Klinikal & Keselamatan / Clinical Evidence & Safety">
    <!-- Card 1: Target Patient -->
    <div class="safety-card">
      <div class="sc-head">
        <FluentIcons name="user" size={15} />
        <span class="sc-title">{currentLang === 'ms' ? 'Indikasi / Sasaran Pesakit' : 'Patient Indication & Suitability'}</span>
      </div>
      <p class="sc-body">{activeTreatment.targetPatient}</p>
    </div>

    <!-- Card 2: Contraindications & Red Flags -->
    <div class="safety-card warning-accent">
      <div class="sc-head">
        <FluentIcons name="warning" size={15} />
        <span class="sc-title">{currentLang === 'ms' ? 'Kontraindikasi & Langkah Berjaga-jaga' : 'Contraindications & Cautions'}</span>
      </div>
      <p class="sc-body">{activeTreatment.contraindications}</p>
    </div>

    <!-- Card 3: Clinical Guideline & Evidence Level -->
    <div
      class="safety-card guideline-accent interactive-ref-card"
      role="button"
      tabindex="0"
      onclick={() => jumpToReference(activeTreatment.evidence.refId)}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); jumpToReference(activeTreatment.evidence.refId); } }}
      title="{currentLang === 'ms' ? 'Klik untuk melihat rujukan garis panduan klinikal' : 'Click to inspect clinical guideline references'} [{activeTreatment.evidence.refId}]"
    >
      <div class="sc-head">
        <FluentIcons name="checkmark" size={15} />
        <span class="sc-title">{currentLang === 'ms' ? 'Rujukan & Bukti Klinikal' : 'Guideline & Evidence Base'}</span>
        <span class="ref-jump-tag">#{activeTreatment.evidence.refId} ↗</span>
      </div>
      <p class="sc-body"><strong>{activeTreatment.evidence.citation}</strong></p>
      <p class="sc-subtext">{activeTreatment.evidence.clinicalNote}</p>
      {#if activeTreatment.evidence.reviewMarker}
        <div class="clinical-marker-tag">
          <FluentIcons name="info" size={12} /> {activeTreatment.evidence.reviewMarker}
        </div>
      {/if}
    </div>
  </section>

  <!-- Doctor In-Clinic Guidance Note -->
  <div class="doctor-tip-card">
    <div class="tip-icon-cell">
      <FluentIcons name="sparkle" size={18} />
    </div>
    <div class="tip-text-cell">
      {isPatientView ? t.stage.patientTip : t.stage.doctorTip}
    </div>
  </div>

  <!-- Consultation Toolkit: Doctor View Only (Checklist & Branch Pricing Side-by-Side) -->
  {#if !isPatientView}
    <div class="doctor-toolkit-grid" aria-label={t.doctorOnlyBadge}>
      <!-- Card A: Consultation Checklist -->
      <section class="toolkit-card checklist-card" aria-labelledby="checklist-heading">
        <div class="tk-card-header">
          <span class="tk-badge">{t.doctorOnlyBadge}</span>
          <h3 id="checklist-heading" class="tk-title">{t.checklist.title}</h3>
          <p class="tk-subtitle">{t.checklist.subtitle}</p>
        </div>

        <ul class="checklist-items">
          {#each t.checklist.items as item}
            <li class="checklist-item">
              <span class="cli-icon"><FluentIcons name="checkCircle" size={15} /></span>
              <div class="cli-content">
                <strong>{item.title}</strong> {item.desc}
              </div>
            </li>
          {/each}
        </ul>
      </section>

      <!-- Card B: Branch Pricing & Packages -->
      <section class="toolkit-card pricing-card" aria-labelledby="pricing-heading">
        <div class="tk-card-header">
          <span class="tk-badge">{t.doctorOnlyBadge}</span>
          <h3 id="pricing-heading" class="tk-title">{t.pricing.title}</h3>
        </div>

        <div class="branch-selector-row">
          <label for="branch-select" class="bs-label">{t.pricing.branchLabel}</label>
          <select
            id="branch-select"
            class="input-field branch-select"
            bind:value={selectedBranch}
            disabled={isLoadingBranches || branches.length === 0}
          >
            {#each branches as b}
              <option value={b.code}>{b.shortName || b.name}</option>
            {/each}
          </select>
        </div>

        <div class="pricing-content-box" aria-live="polite">
          {#if isLoadingBranches}
            <p class="price-empty">{t.pricing.loading}</p>
          {:else if !pricing}
            <p class="price-empty">{t.pricing.notConfigured}</p>
          {:else}
            <dl class="price-table">
              <div class="price-row">
                <dt>{t.pricing.consultationFee}</dt>
                <dd>{formatPrice(pricing.consultationFee)}</dd>
              </div>

              {#if pricing.onlineBookingFee !== null && pricing.onlineBookingFee !== undefined}
                <div class="price-row">
                  <dt>{t.pricing.onlineBooking}</dt>
                  <dd>
                    {formatPrice(pricing.onlineBookingFee)}
                    {#if pricing.onlineBookingNote}
                      <span class="price-subnote">({pricing.onlineBookingNote})</span>
                    {/if}
                  </dd>
                </div>
              {/if}

              {#each pricing.packages ?? [] as pk}
                <div class="price-row">
                  <dt>{pk.label}</dt>
                  <dd>{formatPrice(pk.price)}</dd>
                </div>
              {/each}
            </dl>

            {#if pricing.validFrom || pricing.validTo}
              <p class="price-valid-note">
                <FluentIcons name="calendar" size={13} />
                {t.pricing.validDate}: {pricing.validFrom || '-'} &rarr; {pricing.validTo || '-'}
              </p>
            {/if}
          {/if}
        </div>
      </section>
    </div>
  {/if}

  <!-- Clinical References & Evidence Guidelines (Step 4) -->
  <ReferencePanel
    referencesSection={t.referencesSection}
    activeTreatmentId={selectedTreatment}
    bind:isOpen={refPanelOpen}
    {highlightedRefId}
    lang={currentLang}
    onSelectTreatment={(id) => {
      selectedTreatment = id as TreatmentKey;
      selectedPhase = 1;
    }}
  />

  <!-- Fixed Compliance Footer Disclaimer -->
  <footer class="suite-footer" role="contentinfo">
    <div class="footer-lock-icon">🔒</div>
    <div class="footer-text-group">
      <div class="footer-legal">{t.disclaimer.text}</div>
      <div class="footer-stamp">{t.disclaimer.reviewStamp}</div>
    </div>
  </footer>

  <!-- Accessible WhatsApp Post-Care Guide Modal -->
  {#if dispatchModalOpen}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) closeDispatchModal(); }}>
      <div
        class="modal-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        bind:this={dialogElement}
        tabindex="-1"
      >
        <div class="modal-head">
          <h3 id="modal-title" class="modal-title">{t.dispatchModal.title}</h3>
          <button class="modal-close" onclick={closeDispatchModal} aria-label={t.dispatchModal.closeBtn}>
            <FluentIcons name="close" size={16} />
          </button>
        </div>

        <div class="modal-body">
          {#if dispatchError}
            <FluentErrorBanner
              title="Unable to generate care guide"
              message={dispatchError}
              retryLabel="Retry Sending"
              onRetry={handleDispatchCare}
            />
          {/if}

          <div class="form-group">
            <label for="pt-name">{t.dispatchModal.patientNameLabel}</label>
            <input
              id="pt-name"
              type="text"
              bind:value={patientName}
              placeholder={t.dispatchModal.patientNamePlaceholder}
              class="input-field"
            />
          </div>

          <div class="form-group">
            <label for="pt-phone">{t.dispatchModal.phoneLabel}</label>
            <input
              id="pt-phone"
              type="tel"
              bind:value={patientPhone}
              placeholder={t.dispatchModal.phonePlaceholder}
              class="input-field"
            />
          </div>

          <div class="form-group">
            <label for="pt-date">{t.dispatchModal.dateLabel}</label>
            <input
              id="pt-date"
              type="text"
              bind:value={followUpDate}
              placeholder={t.dispatchModal.datePlaceholder}
              class="input-field"
            />
          </div>

          {#if dispatchResult}
            <div class="dispatch-result-box">
              <div class="dr-title">{t.dispatchModal.readyTitle}</div>
              <pre class="dr-preview">{dispatchResult.messageText}</pre>
              <a
                href={dispatchResult.whatsappUrl}
                target="_blank"
                rel="noreferrer"
                class="wa-jump-link"
              >
                👉 {t.dispatchModal.openWaBtn}
              </a>
            </div>
          {/if}
        </div>

        <div class="modal-foot">
          <FluentButton appearance="secondary" onclick={closeDispatchModal}>
            {t.dispatchModal.closeBtn}
          </FluentButton>
          <FluentButton appearance="primary" onclick={handleDispatchCare} disabled={isDispatching}>
            {isDispatching ? t.dispatchModal.generatingBtn : t.dispatchModal.generateBtn}
          </FluentButton>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .consult-suite-view {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 24px 32px;
    max-width: 1600px;
    margin: 0 auto;
    width: 100%;
    box-sizing: border-box;
    transition: all 0.2s ease;
  }

  /* Patient View Fullscreen Styling */
  .consult-suite-view.patient-mode {
    padding: 16px 24px 40px;
    max-width: 100%;
  }

  /* Patient View Banner */
  .patient-mode-banner {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: linear-gradient(135deg, rgba(4, 51, 136, 0.4) 0%, rgba(33, 161, 247, 0.2) 100%);
    border: 1px solid rgba(33, 161, 247, 0.4);
    border-radius: 12px;
    padding: 12px 20px;
    gap: 16px;
  }

  .pmb-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .pmb-badge {
    background: #21A1F7;
    color: #FFFFFF;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 0.8px;
    padding: 3px 8px;
    border-radius: 4px;
  }

  .pmb-hint {
    font-size: 13px;
    color: #E2E8F0;
  }

  .pmb-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  /* Slim Doctor Header */
  .suite-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 20px;
  }

  .suite-pill {
    display: inline-block;
    padding: 4px 12px;
    background: rgba(33, 161, 247, 0.12);
    border: 1px solid rgba(33, 161, 247, 0.3);
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    color: #21A1F7;
    letter-spacing: 0.8px;
    margin-bottom: 8px;
  }

  .suite-title {
    font-size: 24px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0 0 6px 0;
  }

  .suite-desc {
    font-size: 14px;
    color: var(--text-secondary, #94A3B8);
    margin: 0;
    max-width: 820px;
    line-height: 1.5;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }

  /* Segmented Language Selector */
  .lang-toggle-group {
    display: inline-flex;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px;
    padding: 3px;
    gap: 2px;
  }

  .lang-btn {
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 700;
    color: var(--text-secondary, #94A3B8);
    background: transparent;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .lang-btn:hover {
    color: #FFFFFF;
  }

  .lang-btn.active {
    background: #21A1F7;
    color: #FFFFFF;
    box-shadow: 0 2px 8px rgba(33, 161, 247, 0.3);
  }

  /* Treatment Navigation Bar */
  .treatment-nav {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 12px;
  }

  .treatment-card-tab {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 14px 18px;
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 12px;
    cursor: pointer;
    text-align: left;
    transition: all 0.15s ease;
  }

  .treatment-card-tab:hover {
    background: rgba(255, 255, 255, 0.08);
    border-color: rgba(33, 161, 247, 0.3);
  }

  .treatment-card-tab.active {
    background: linear-gradient(135deg, rgba(4, 51, 136, 0.3) 0%, rgba(33, 161, 247, 0.18) 100%);
    border: 2px solid #21A1F7;
    box-shadow: 0 4px 16px rgba(33, 161, 247, 0.2);
  }

  .tab-icon-box {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 8px;
    background: rgba(33, 161, 247, 0.1);
    color: #21A1F7;
    flex-shrink: 0;
  }

  .treatment-card-tab.active .tab-icon-box {
    background: #21A1F7;
    color: #FFFFFF;
  }

  .tab-meta {
    overflow: hidden;
  }

  .tab-label {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #FFFFFF);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tab-sub {
    font-size: 11px;
    color: var(--text-secondary, #94A3B8);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin-top: 2px;
  }

  /* Full-Width Anatomy Stage Hero */
  .anatomy-stage-hero {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 20px;
    padding: 28px 32px;
    display: flex;
    flex-direction: column;
    position: relative;
    overflow: hidden;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  }

  .stage-header-strip {
    margin-bottom: 20px;
  }

  .stage-tag-group {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 10px;
  }

  .stage-top-pill {
    font-size: 11px;
    font-weight: 800;
    color: #21A1F7;
    letter-spacing: 0.8px;
  }

  .evidence-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 3px 10px;
    background: rgba(16, 185, 129, 0.12);
    border: 1px solid rgba(16, 185, 129, 0.3);
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    color: #34D399;
  }

  .stage-treatment-title {
    font-size: 22px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0 0 8px 0;
  }

  .patient-mode .stage-treatment-title {
    font-size: 28px;
  }

  .stage-treatment-desc {
    font-size: 14px;
    color: var(--text-secondary, #CBD5E1);
    margin: 0;
    max-width: 900px;
    line-height: 1.6;
  }

  .patient-mode .stage-treatment-desc {
    font-size: 16px;
    max-width: 1100px;
  }

  /* Center Stage Graphic Canvas */
  .stage-canvas-viewport {
    background: radial-gradient(circle at center, rgba(33, 161, 247, 0.08) 0%, rgba(0, 0, 0, 0.4) 100%);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 280px;
    margin-bottom: 24px;
  }

  .patient-mode .stage-canvas-viewport {
    min-height: 380px;
    padding: 36px;
  }

  .anatomy-svg {
    width: 100%;
    max-width: 780px;
    height: auto;
    max-height: 340px;
  }

  /* Floating Phase Scrubber Docked along Bottom */
  .stage-scrubber-dock {
    background: rgba(6, 25, 56, 0.85);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(33, 161, 247, 0.3);
    border-radius: 14px;
    padding: 18px 24px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .scrubber-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
  }

  .scrubber-title {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 800;
    color: #38BDF8;
  }

  .scrubber-active-metric {
    font-size: 12px;
    font-weight: 700;
    color: #34D399;
    background: rgba(52, 211, 153, 0.15);
    border: 1px solid #10B981;
    padding: 2px 10px;
    border-radius: 6px;
  }

  .scrubber-pills {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
  }

  .scrubber-pill-btn {
    padding: 8px 12px;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.03);
    color: var(--text-secondary, #94A3B8);
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .scrubber-pill-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: #FFFFFF;
  }

  .scrubber-pill-btn.selected {
    background: #043388;
    color: #FFFFFF;
    border-color: #21A1F7;
    box-shadow: 0 0 12px rgba(33, 161, 247, 0.35);
  }

  .scrubber-range-container {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .scrubber-range-ticks {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-secondary, #94A3B8);
    font-weight: 600;
  }

  .stage-range-slider {
    width: 100%;
    accent-color: #21A1F7;
    cursor: pointer;
  }

  /* Horizontal Phase Details Strip */
  .phase-details-strip {
    display: grid;
    grid-template-columns: 280px 1.2fr 1.6fr;
    gap: 16px;
  }

  @media (max-width: 1024px) {
    .phase-details-strip {
      grid-template-columns: 1fr;
    }
  }

  .phase-metric-card,
  .phase-highlight-card,
  .phase-clinical-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 14px;
    padding: 18px 22px;
    display: flex;
    flex-direction: column;
  }

  .pms-label {
    font-size: 11px;
    font-weight: 700;
    color: #94A3B8;
    letter-spacing: 0.6px;
    text-transform: uppercase;
    margin-bottom: 8px;
  }

  .pms-value-badge {
    display: inline-block;
    padding: 4px 10px;
    background: rgba(52, 211, 153, 0.15);
    border: 1px solid #10B981;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 700;
    color: #34D399;
    margin-bottom: 8px;
    align-self: flex-start;
  }

  .pms-title {
    font-size: 15px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0;
  }

  .pms-highlight {
    font-size: 14px;
    font-weight: 700;
    color: #38BDF8;
    line-height: 1.5;
  }

  .pms-details {
    font-size: 13px;
    color: var(--text-secondary, #CBD5E1);
    line-height: 1.6;
    margin: 0;
  }

  /* Evidence & Safety Row */
  .evidence-safety-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 16px;
  }

  .safety-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.03));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 14px;
    padding: 18px 22px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .safety-card.warning-accent {
    border-color: rgba(245, 158, 11, 0.3);
    background: rgba(245, 158, 11, 0.03);
  }

  .safety-card.guideline-accent {
    border-color: rgba(33, 161, 247, 0.3);
    background: rgba(33, 161, 247, 0.03);
  }

  .safety-card.interactive-ref-card {
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .safety-card.interactive-ref-card:hover {
    border-color: #38BDF8;
    background: rgba(33, 161, 247, 0.08);
    transform: translateY(-1px);
  }

  .ref-jump-tag {
    margin-left: auto;
    font-size: 11px;
    font-weight: 700;
    color: #38BDF8;
    background: rgba(33, 161, 247, 0.12);
    border: 1px solid rgba(33, 161, 247, 0.3);
    border-radius: 4px;
    padding: 2px 6px;
  }

  .sc-head {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    font-weight: 700;
    color: #38BDF8;
  }

  .warning-accent .sc-head {
    color: #F59E0B;
  }

  .sc-title {
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .sc-body {
    font-size: 13px;
    color: var(--text-primary, #E2E8F0);
    margin: 0;
    line-height: 1.5;
  }

  .sc-subtext {
    font-size: 12px;
    color: var(--text-secondary, #94A3B8);
    margin: 0;
    line-height: 1.4;
  }

  .clinical-marker-tag {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    margin-top: 6px;
    padding: 4px 10px;
    background: rgba(33, 161, 247, 0.08);
    border: 1px dashed rgba(33, 161, 247, 0.3);
    border-radius: 6px;
    font-size: 11px;
    color: #7DD3FC;
    line-height: 1.4;
  }

  /* Doctor / Patient Tip Card */
  .doctor-tip-card {
    display: flex;
    align-items: flex-start;
    gap: 14px;
    padding: 16px 20px;
    background: rgba(33, 161, 247, 0.06);
    border: 1px dashed rgba(33, 161, 247, 0.3);
    border-radius: 12px;
  }

  .tip-icon-cell {
    color: #38BDF8;
    flex-shrink: 0;
  }

  .tip-text-cell {
    font-size: 13px;
    color: #BAE6FD;
    line-height: 1.5;
  }

  /* Doctor Toolkit Grid: Checklist & Branch Pricing */
  .doctor-toolkit-grid {
    display: grid;
    grid-template-columns: 1.1fr 0.9fr;
    gap: 24px;
  }

  @media (max-width: 960px) {
    .doctor-toolkit-grid {
      grid-template-columns: 1fr;
    }
  }

  .toolkit-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 18px;
    padding: 24px 28px;
    display: flex;
    flex-direction: column;
  }

  .tk-card-header {
    margin-bottom: 18px;
  }

  .tk-badge {
    display: inline-block;
    font-size: 10px;
    font-weight: 800;
    color: #21A1F7;
    letter-spacing: 0.8px;
    margin-bottom: 6px;
  }

  .tk-title {
    font-size: 18px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0 0 4px 0;
  }

  .tk-subtitle {
    font-size: 12px;
    color: var(--text-secondary, #94A3B8);
    margin: 0;
  }

  /* Checklist Items */
  .checklist-items {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .checklist-item {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    font-size: 13px;
    line-height: 1.5;
    color: var(--text-secondary, #CBD5E1);
  }

  .cli-icon {
    color: #10B981;
    flex-shrink: 0;
    margin-top: 2px;
  }

  .cli-content strong {
    color: var(--text-primary, #FFFFFF);
  }

  /* Branch Pricing Box */
  .branch-selector-row {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
  }

  .bs-label {
    font-size: 12px;
    font-weight: 700;
    color: #CBD5E1;
  }

  .branch-select {
    min-height: 36px;
    min-width: 220px;
  }

  .pricing-content-box {
    border: 1px dashed rgba(33, 161, 247, 0.3);
    border-radius: 12px;
    padding: 18px;
    background: rgba(0, 0, 0, 0.2);
  }

  .price-table {
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
    font-size: 13px;
  }

  .price-row {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    padding-bottom: 6px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  .price-row:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .price-row dt {
    color: var(--text-secondary, #CBD5E1);
  }

  .price-row dd {
    margin: 0;
    font-weight: 700;
    color: var(--text-primary, #FFFFFF);
    text-align: right;
  }

  .price-subnote {
    font-size: 11px;
    color: #94A3B8;
    font-weight: normal;
    display: block;
  }

  .price-empty {
    margin: 0;
    font-size: 12px;
    color: #94A3B8;
  }

  .price-valid-note {
    display: flex;
    align-items: center;
    gap: 6px;
    margin: 12px 0 0 0;
    font-size: 11px;
    color: #94A3B8;
  }

  /* Fixed Grounded Compliance Footer */
  .suite-footer {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 16px 20px;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    margin-top: 12px;
  }

  .footer-lock-icon {
    font-size: 18px;
    opacity: 0.8;
  }

  .footer-text-group {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .footer-legal {
    font-size: 12px;
    color: var(--text-secondary, #94A3B8);
    line-height: 1.4;
  }

  .footer-stamp {
    font-size: 11px;
    color: #64748B;
    font-style: italic;
  }

  /* Accessible Modal Styles */
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal-dialog {
    width: 600px;
    max-width: 90vw;
    background: #061938;
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 18px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
    overflow: hidden;
    outline: none;
  }

  .modal-head {
    padding: 20px 24px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .modal-title {
    font-size: 16px;
    font-weight: 700;
    color: #FFFFFF;
    margin: 0;
  }

  .modal-close {
    background: transparent;
    border: none;
    color: #94A3B8;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 6px;
    border-radius: 6px;
    transition: all 0.15s ease;
  }

  .modal-close:hover {
    color: #FFFFFF;
    background: rgba(255, 255, 255, 0.08);
  }

  .modal-body {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    max-height: 70vh;
    overflow-y: auto;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .form-group label {
    font-size: 12px;
    font-weight: 600;
    color: #CBD5E1;
  }

  .input-field {
    padding: 10px 14px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px;
    color: #FFFFFF;
    font-size: 13px;
    outline: none;
    transition: border-color 0.15s ease;
  }

  .input-field:focus {
    border-color: #21A1F7;
    box-shadow: 0 0 0 2px rgba(33, 161, 247, 0.25);
  }

  .dispatch-result-box {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(33, 161, 247, 0.3);
    border-radius: 10px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .dr-title {
    font-size: 12px;
    font-weight: 700;
    color: #34D399;
  }

  .dr-preview {
    font-size: 11px;
    color: #E2E8F0;
    white-space: pre-wrap;
    margin: 0;
    line-height: 1.4;
    max-height: 150px;
    overflow-y: auto;
  }

  .wa-jump-link {
    display: inline-block;
    padding: 10px 16px;
    background: #10B981;
    color: #FFFFFF;
    text-align: center;
    text-decoration: none;
    font-size: 13px;
    font-weight: 700;
    border-radius: 8px;
    transition: background 0.15s ease;
  }

  .wa-jump-link:hover {
    background: #059669;
  }

  .modal-foot {
    padding: 16px 24px;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    display: flex;
    justify-content: flex-end;
    gap: 12px;
  }

  /* Accessibility: Prefers Reduced Motion */
  @media (prefers-reduced-motion: reduce) {
    *, ::before, ::after {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
      scroll-behavior: auto !important;
    }
  }
</style>

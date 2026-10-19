<script lang="ts">
  /**
   * ReferencePanel.svelte
   * Collapsible medical guidelines and evidence panel for SS-CAM Consultation Suite.
   * Provides peer-reviewed guideline citations, evidence levels, and clinical takeaways.
   */
  import type { MedicalReferencesSection, MedicalReferenceItem, ConsultationLang } from '../../config/consultation.i18n';
  import FluentIcons from '../ui/FluentIcons.svelte';

  interface Props {
    referencesSection: MedicalReferencesSection;
    activeTreatmentId: string;
    isOpen?: boolean;
    highlightedRefId?: number | null;
    lang: ConsultationLang;
    onSelectTreatment?: (id: string) => void;
  }

  let {
    referencesSection,
    activeTreatmentId,
    isOpen = $bindable(false),
    highlightedRefId = null,
    lang,
    onSelectTreatment
  }: Props = $props();

  let filterMode = $state<'all' | 'current'>('all');

  let filteredReferences = $derived(
    filterMode === 'current'
      ? referencesSection.references.filter((r) => r.treatmentId === activeTreatmentId)
      : referencesSection.references
  );

  function toggleOpen() {
    isOpen = !isOpen;
  }

  // When a specific citation is clicked from the evidence cards, ensure panel is expanded and visible
  $effect(() => {
    if (highlightedRefId) {
      isOpen = true;
      const targetInCurrent = referencesSection.references.find(
        (r) => r.id === highlightedRefId && r.treatmentId === activeTreatmentId
      );
      if (filterMode === 'current' && !targetInCurrent) {
        filterMode = 'all';
      }
      setTimeout(() => {
        const el = document.getElementById(`ref-card-${highlightedRefId}`);
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }, 100);
    }
  });

  const TREATMENT_LABELS: Record<string, { ms: string; en: string }> = {
    eswt: { ms: 'ESWT Shockwave', en: 'ESWT Shockwave' },
    kegel: { ms: 'Kerusi Kegel', en: 'Kegel Chair' },
    pshot: { ms: 'P-Shot PRP', en: 'P-Shot PRP' },
    fertility: { ms: 'Kesuburan Lelaki', en: 'Male Fertility' },
    trt: { ms: 'Terapi TRT', en: 'TRT Hormone' },
    pe_ed: { ms: 'Rehabilitasi PE/ED', en: 'PE/ED Rehab' }
  };
</script>

<section
  id="clinical-references-section"
  class="reference-panel-container"
  class:is-open={isOpen}
  aria-labelledby="ref-panel-title"
>
  <!-- Interactive Accordion Header Trigger -->
  <header
    class="ref-panel-header"
    role="button"
    tabindex="0"
    onclick={toggleOpen}
    onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleOpen(); } }}
    aria-expanded={isOpen}
    aria-controls="ref-panel-content"
  >
    <div class="header-left">
      <div class="header-badge-row">
        <span class="ref-badge">
          <FluentIcons name="checkmark" size={13} /> {referencesSection.badge}
        </span>
        <span class="ref-active-tag">
          {lang === 'ms' ? 'Rawatan Semasa:' : 'Current Protocol:'} {TREATMENT_LABELS[activeTreatmentId]?.[lang] || activeTreatmentId}
        </span>
      </div>

      <h3 id="ref-panel-title" class="ref-panel-heading">
        <FluentIcons name="file" size={18} /> {referencesSection.title}
      </h3>
      <p class="ref-panel-sub">{referencesSection.subtitle}</p>
    </div>

    <div class="header-right">
      <button
        type="button"
        class="ref-toggle-btn"
        onclick={(e) => { e.stopPropagation(); toggleOpen(); }}
        aria-label={isOpen ? referencesSection.toggleClose : referencesSection.toggleOpen}
      >
        <span class="toggle-text">{isOpen ? referencesSection.toggleClose : referencesSection.toggleOpen}</span>
        <span class="toggle-icon-wrap" class:rotated={isOpen}>
          <FluentIcons name="chevronDown" size={16} />
        </span>
      </button>
    </div>
  </header>

  <!-- Collapsible Content Body -->
  {#if isOpen}
    <div id="ref-panel-content" class="ref-panel-body" role="region">
      <!-- Medical Director Clinical Advisory Notice Box -->
      <div class="director-notice-box">
        <div class="notice-icon-cell">
          <FluentIcons name="sparkles" size={20} />
        </div>
        <div class="notice-text-cell">
          <h4 class="notice-heading">{referencesSection.directorNoticeTitle}</h4>
          <p class="notice-body">{referencesSection.directorNoticeText}</p>
        </div>
      </div>

      <!-- Quick Filter Bar -->
      <div class="ref-filter-bar">
        <div class="filter-pills" role="tablist" aria-label="Penapis Rujukan / Reference Filter">
          <button
            type="button"
            class="filter-pill-btn"
            class:active={filterMode === 'all'}
            onclick={() => (filterMode = 'all')}
            role="tab"
            aria-selected={filterMode === 'all'}
          >
            {referencesSection.allFilterLabel}
          </button>
          <button
            type="button"
            class="filter-pill-btn"
            class:active={filterMode === 'current'}
            onclick={() => (filterMode = 'current')}
            role="tab"
            aria-selected={filterMode === 'current'}
          >
            {referencesSection.currentFilterLabel} ({TREATMENT_LABELS[activeTreatmentId]?.[lang] || activeTreatmentId})
          </button>
        </div>

        <div class="filter-count-badge">
          {filteredReferences.length} {lang === 'ms' ? 'Rujukan Dipaparkan' : 'Citations Displayed'}
        </div>
      </div>

      <!-- References Cards Grid -->
      <div class="ref-cards-grid">
        {#each filteredReferences as ref (ref.id)}
          <article
            id="ref-card-{ref.id}"
            class="ref-card"
            class:highlighted-card={highlightedRefId === ref.id}
            class:is-active-protocol={ref.treatmentId === activeTreatmentId}
            aria-labelledby="ref-heading-{ref.id}"
          >
            <!-- Card Meta Header -->
            <div class="card-meta-bar">
              <div class="meta-left">
                <span class="ref-num-badge">[{ref.id}]</span>
                <span class="guideline-org-tag">
                  {ref.guidelineBody}
                </span>
                <span class="guideline-year-tag">{ref.year}</span>
              </div>

              <div class="meta-right">
                <button
                  type="button"
                  class="treatment-link-pill"
                  onclick={() => onSelectTreatment?.(ref.treatmentId)}
                  title={lang === 'ms' ? 'Tukar ke rawatan ini' : 'Switch to this protocol'}
                >
                  <FluentIcons name="tag" size={12} /> {TREATMENT_LABELS[ref.treatmentId]?.[lang] || ref.treatmentId}
                </button>
              </div>
            </div>

            <!-- Citation Title & Evidence Level -->
            <h4 id="ref-heading-{ref.id}" class="citation-title">
              {ref.citation}
            </h4>

            <div class="evidence-level-chip">
              <FluentIcons name="checkmark" size={12} />
              <span class="el-label">{lang === 'ms' ? 'Kekuatan Bukti:' : 'Evidence Strength:'}</span>
              <strong class="el-val">{ref.evidenceLevel}</strong>
            </div>

            <!-- Content Sections -->
            <div class="card-sections-stack">
              <!-- Section 1: Guideline Recommendation -->
              <div class="rec-block">
                <div class="block-label">
                  <span class="bl-dot blue"></span>
                  {lang === 'ms' ? 'Rekomendasi Garis Panduan Antarabangsa:' : 'International Guideline Recommendation:'}
                </div>
                <p class="block-text">{ref.recommendation}</p>
              </div>

              <!-- Section 2: Clinical Application in SuamiSihat -->
              <div class="app-block">
                <div class="block-label">
                  <span class="bl-dot emerald"></span>
                  {lang === 'ms' ? 'Aplikasi Klinikal SuamiSihat (In-Clinic Protocol):' : 'SuamiSihat In-Clinic Application:'}
                </div>
                <p class="block-text">{ref.clinicalApplication}</p>
              </div>
            </div>

            <!-- Card Footer: Ethical Review Status & External URL -->
            <footer class="card-footer-strip">
              <div class="footer-left">
                {#if ref.reviewMarker}
                  <div class="review-status-tag" class:advisory={ref.reviewMarker.includes('Clinical Review Marker')}>
                    <FluentIcons name={ref.reviewMarker.includes('Clinical Review Marker') ? 'warning' : 'checkmark'} size={13} />
                    <span class="rst-text">{ref.reviewMarker}</span>
                  </div>
                {/if}
              </div>

              {#if ref.url}
                <div class="footer-right">
                  <a
                    href={ref.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="view-guideline-link"
                    aria-label="{referencesSection.viewGuidelineBtn}: {ref.citation}"
                  >
                    <span>{referencesSection.viewGuidelineBtn}</span>
                    <FluentIcons name="externalLink" size={13} />
                  </a>
                </div>
              {/if}
            </footer>
          </article>
        {/each}
      </div>
    </div>
  {/if}
</section>

<style>
  .reference-panel-container {
    margin-top: 24px;
    border-radius: 12px;
    background: var(--color-neutral-card, rgba(30, 41, 59, 0.65));
    border: 1px solid var(--color-neutral-stroke, rgba(255, 255, 255, 0.08));
    backdrop-filter: blur(12px);
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
    overflow: hidden;
  }

  .reference-panel-container:hover {
    border-color: rgba(255, 255, 255, 0.16);
  }

  .reference-panel-container.is-open {
    border-color: rgba(0, 136, 204, 0.4);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.25);
  }

  /* Header */
  .ref-panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 18px 24px;
    cursor: pointer;
    user-select: none;
    outline: none;
    transition: background 0.15s ease;
  }

  .ref-panel-header:hover {
    background: rgba(255, 255, 255, 0.02);
  }

  .ref-panel-header:focus-visible {
    outline: 2px solid var(--color-brand-primary, #0088cc);
    outline-offset: -2px;
  }

  .header-left {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .header-badge-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 2px;
  }

  .ref-badge {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.12);
    border: 1px solid rgba(56, 189, 248, 0.25);
    border-radius: 999px;
    padding: 2px 10px;
  }

  .ref-active-tag {
    font-size: 11px;
    color: var(--color-neutral-text-secondary, #94a3b8);
    background: rgba(255, 255, 255, 0.04);
    border-radius: 4px;
    padding: 2px 8px;
  }

  .ref-panel-heading {
    margin: 0;
    font-size: 16px;
    font-weight: 700;
    color: var(--color-neutral-text-primary, #f1f5f9);
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ref-panel-sub {
    margin: 0;
    font-size: 12px;
    color: var(--color-neutral-text-secondary, #94a3b8);
    line-height: 1.4;
  }

  /* Toggle button */
  .ref-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 600;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.08);
    border: 1px solid rgba(56, 189, 248, 0.2);
    border-radius: 8px;
    padding: 8px 14px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .ref-toggle-btn:hover {
    background: rgba(56, 189, 248, 0.16);
    border-color: rgba(56, 189, 248, 0.4);
    color: #e0f2fe;
  }

  .toggle-icon-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .toggle-icon-wrap.rotated {
    transform: rotate(180deg);
  }

  /* Body */
  .ref-panel-body {
    padding: 0 24px 24px 24px;
    border-top: 1px solid var(--color-neutral-stroke, rgba(255, 255, 255, 0.08));
    animation: fadeInSlide 0.25s ease-out;
  }

  @keyframes fadeInSlide {
    from {
      opacity: 0;
      transform: translateY(-8px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  /* Director Notice Box */
  .director-notice-box {
    display: flex;
    align-items: flex-start;
    gap: 14px;
    margin: 20px 0 16px 0;
    padding: 14px 18px;
    border-radius: 8px;
    background: rgba(234, 179, 8, 0.08);
    border: 1px solid rgba(234, 179, 8, 0.25);
  }

  .notice-icon-cell {
    color: #facc15;
    flex-shrink: 0;
    margin-top: 1px;
  }

  .notice-heading {
    margin: 0 0 3px 0;
    font-size: 13px;
    font-weight: 700;
    color: #fef08a;
  }

  .notice-body {
    margin: 0;
    font-size: 12px;
    color: #fef9c3;
    line-height: 1.5;
    opacity: 0.9;
  }

  /* Filter Bar */
  .ref-filter-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 18px;
    padding: 8px 0;
  }

  .filter-pills {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .filter-pill-btn {
    font-size: 12px;
    font-weight: 600;
    padding: 6px 14px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--color-neutral-text-secondary, #94a3b8);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .filter-pill-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: var(--color-neutral-text-primary, #f1f5f9);
  }

  .filter-pill-btn.active {
    background: rgba(0, 136, 204, 0.2);
    border-color: var(--color-brand-primary, #0088cc);
    color: #38bdf8;
  }

  .filter-count-badge {
    font-size: 12px;
    color: var(--color-neutral-text-secondary, #94a3b8);
  }

  /* Cards Grid */
  .ref-cards-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(460px, 1fr));
    gap: 16px;
  }

  @media (max-width: 680px) {
    .ref-cards-grid {
      grid-template-columns: 1fr;
    }
  }

  /* Individual Card */
  .ref-card {
    display: flex;
    flex-direction: column;
    border-radius: 10px;
    background: rgba(15, 23, 42, 0.55);
    border: 1px solid rgba(255, 255, 255, 0.08);
    padding: 18px;
    transition: all 0.2s ease;
  }

  .ref-card:hover {
    border-color: rgba(255, 255, 255, 0.18);
    transform: translateY(-1px);
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.2);
  }

  .ref-card.is-active-protocol {
    border-color: rgba(56, 189, 248, 0.35);
    background: rgba(15, 23, 42, 0.75);
  }

  /* Target Highlight Glow */
  .ref-card.highlighted-card {
    border-color: #38bdf8 !important;
    animation: pulseRefGlow 2.5s ease-in-out infinite;
  }

  @keyframes pulseRefGlow {
    0% {
      box-shadow: 0 0 0 0 rgba(56, 189, 248, 0.6);
      border-color: #38bdf8;
    }
    50% {
      box-shadow: 0 0 20px 4px rgba(56, 189, 248, 0.35);
      border-color: #0284c7;
    }
    100% {
      box-shadow: 0 0 0 0 rgba(56, 189, 248, 0);
      border-color: #38bdf8;
    }
  }

  /* Meta Bar */
  .card-meta-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    margin-bottom: 10px;
  }

  .meta-left {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .ref-num-badge {
    font-size: 13px;
    font-weight: 800;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.15);
    border: 1px solid rgba(56, 189, 248, 0.3);
    border-radius: 6px;
    padding: 2px 7px;
  }

  .guideline-org-tag {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #94a3b8;
  }

  .guideline-year-tag {
    font-size: 11px;
    font-weight: 600;
    color: #64748b;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    padding: 1px 6px;
  }

  .treatment-link-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-weight: 600;
    color: #cbd5e1;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 999px;
    padding: 3px 9px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .treatment-link-pill:hover {
    background: rgba(56, 189, 248, 0.15);
    border-color: rgba(56, 189, 248, 0.3);
    color: #38bdf8;
  }

  /* Citation Title */
  .citation-title {
    margin: 0 0 10px 0;
    font-size: 14px;
    font-weight: 700;
    color: var(--color-neutral-text-primary, #f1f5f9);
    line-height: 1.4;
  }

  /* Evidence Strength Chip */
  .evidence-level-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: #10b981;
    background: rgba(16, 185, 129, 0.08);
    border: 1px solid rgba(16, 185, 129, 0.2);
    border-radius: 6px;
    padding: 3px 9px;
    margin-bottom: 14px;
    align-self: flex-start;
  }

  .el-label {
    color: #a7f3d0;
  }

  .el-val {
    color: #34d399;
  }

  /* Card Sections Stack */
  .card-sections-stack {
    display: flex;
    flex-direction: column;
    gap: 12px;
    flex-grow: 1;
    margin-bottom: 16px;
  }

  .rec-block,
  .app-block {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px 12px;
    border-radius: 6px;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.04);
  }

  .block-label {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #94a3b8;
  }

  .bl-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }

  .bl-dot.blue {
    background: #38bdf8;
    box-shadow: 0 0 6px #38bdf8;
  }

  .bl-dot.emerald {
    background: #34d399;
    box-shadow: 0 0 6px #34d399;
  }

  .block-text {
    margin: 0;
    font-size: 12px;
    color: #cbd5e1;
    line-height: 1.5;
  }

  /* Footer Strip */
  .card-footer-strip {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding-top: 12px;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
    flex-wrap: wrap;
  }

  .footer-left {
    flex-grow: 1;
  }

  .review-status-tag {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
    color: #94a3b8;
  }

  .review-status-tag.advisory {
    color: #facc15;
    background: rgba(234, 179, 8, 0.1);
    border: 1px solid rgba(234, 179, 8, 0.2);
    border-radius: 4px;
    padding: 2px 6px;
  }

  .rst-text {
    line-height: 1.3;
  }

  .view-guideline-link {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 12px;
    font-weight: 600;
    color: #38bdf8;
    text-decoration: none;
    padding: 4px 10px;
    border-radius: 6px;
    background: rgba(56, 189, 248, 0.08);
    border: 1px solid rgba(56, 189, 248, 0.2);
    transition: all 0.15s ease;
  }

  .view-guideline-link:hover {
    background: rgba(56, 189, 248, 0.2);
    border-color: rgba(56, 189, 248, 0.4);
    color: #e0f2fe;
    text-decoration: none;
  }

  @media (prefers-reduced-motion: reduce) {
    .reference-panel-container,
    .toggle-icon-wrap,
    .ref-panel-body,
    .ref-card {
      transition: none !important;
      animation: none !important;
    }
  }
</style>

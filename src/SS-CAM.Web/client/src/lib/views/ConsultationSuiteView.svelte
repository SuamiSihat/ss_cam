<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';

  let selectedTreatment = $state<'eswt' | 'trt' | 'pe_ed'>('eswt');
  let selectedPhase = $state(1); // 1, 2, 3, 4
  let patientName = $state('');
  let patientPhone = $state('');
  let followUpDate = $state('');
  let dispatchModalOpen = $state(false);
  let dispatchResult = $state<any>(null);
  let isDispatching = $state(false);

  const treatments = {
    eswt: {
      id: 'eswt',
      name: 'Terapi Gelombang Kejutan (ESWT)',
      title: 'Pemulihan Vaskularisasi & Pengaliran Darah Mikro',
      description: 'Gelombang akustik berintensiti rendah merangsang faktor pertumbuhan salur darah (VEGF), menguraikan plak mikroskopik dan membina kapilari darah baharu secara semulajadi.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Penilaian Asas & Rangsangan Selular (Minggu 1-2)',
          highlight: 'Memulakan pengaktifan metabolik tisu tanpa kesakitan.',
          details: 'Sesi 1 & 2 dimulakan pada paras tenaga terkawal (0.09 mJ/mm²). Sel endotelium mula dirangsang untuk melepaskan molekul nitrik oksida (NO).',
          metric: '20% Pengaktifan Tisu'
        },
        {
          phase: 2,
          title: 'Fasa 2: Neovaskularisasi & Pembentukan Kapilari (Minggu 3-6)',
          highlight: 'Pembentukan jaringan salur darah mikro baharu (Angiogenesis).',
          details: 'Peningkatan aliran darah oksigen ke tisu spons korpus kavernosum. Pesakit mula merasakan peningkatan kekerapan respons ereksi pagi semulajadi.',
          metric: '55% Peningkatan Perfusi Vaskular'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengukuhan Struktur & Ketahanan Maksimum (Minggu 7-10)',
          highlight: 'Penyatuan serat kolagen dan pemulihan elastisiti tisu.',
          details: 'Ketegangan dan daya tahan ereksi mencapai paras optimum yang stabil. Tempoh latensi pemulihan berkurangan dengan ketara.',
          metric: '85% Kestabilan Prestasi'
        },
        {
          phase: 4,
          title: 'Fasa 4: Penyelenggaraan Jangka Panjang & Vitaliti Puncak (Minggu 12+)',
          highlight: 'Kekalkan hasil jangka masa panjang secara berterusan.',
          details: 'Semakan berkala setiap 6 bulan bersama bimbingan senaman lantai pelvis bagi mengekalkan vaskularisasi yang sihat sepanjang hayat.',
          metric: '100% Pencapaian Sasaran Klinikal'
        }
      ]
    },
    trt: {
      id: 'trt',
      name: 'Terapi Penggantian Testosteron (TRT)',
      title: 'Pengoptimuman Profil Hormon & Kesejahteraan Metabolik',
      description: 'Pelan rawatan perubatan berasaskan ujian darah klinikal bagi memulihkan paras hormon testosteron bio-identikal ke paras fisiologi lelaki aktif.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Ujian Profil Darah & Penentuan Dos (Minggu 1-2)',
          highlight: 'Penetapan dos selamat berasaskan Total T, Free T, PSA & Hct.',
          details: 'Penyelaras klinikal memeriksa fungsi hati, buah pinggang dan kepekatan sel darah merah sebelum memulakan suntikan formulasi terpilih.',
          metric: 'Penetapan Titik Asas (Baseline)'
        },
        {
          phase: 2,
          title: 'Fasa 2: Lonjakan Tenaga & Kualiti Tidur (Minggu 3-6)',
          highlight: 'Penurunan rasa letih kronik dan kejelasan mental meningkat.',
          details: 'Paras androgen mula stabil. Pesakit melaporkan tidur nyenyak, mood positif, dan motivasi kerja harian yang jauh lebih bertenaga.',
          metric: '60% Peningkatan Stamina Harian'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengurangan Lemak Viseral & Komposisi Otot (Minggu 7-10)',
          highlight: 'Metabolisme lipid meningkat dan pembentukan jisim otot tanpa lemak.',
          details: 'Sensitiviti insulin bertambah baik. Pembakaran lemak di bahagian perut lebih efektif apabila digandingkan dengan senaman rintangan asas.',
          metric: '80% Transformasi Komposisi Badan'
        },
        {
          phase: 4,
          title: 'Fasa 4: Pemantauan Darah 12-Minggu & Penyelenggaraan (Minggu 12+)',
          highlight: 'Ujian darah susulan wajib bagi menjamin keselamatan kardiovaskular.',
          details: 'Semakan semula paras hematokrit dan lipid darah bagi memastikan paras hormon kekal dalam zon terapeutik optimum yang selamat.',
          metric: '100% Keseimbangan Endokrin'
        }
      ]
    },
    pe_ed: {
      id: 'pe_ed',
      name: 'Rehabilitasi Prestasi Lelaki (PE/ED)',
      title: 'Pendekatan Klinikal Bersepadu & Kawalan Neuromuskular',
      description: 'Gabungan terapi fisioterapi lantai pelvis, modulasi neuro-sensori dan sokongan formulasi klinikal berdaftar KKM bagi memulihkan kawalan dan keyakinan intim.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Pemetaan Sensori & Kekuatan Otot Pelvis (Minggu 1-2)',
          highlight: 'Mengenal pasti otot bulbocavernosus dan reflex ejakulasi.',
          details: 'Doktor menguji ambang kepekaan saraf dan melatih teknik pengecutan otot dasar panggul yang betul.',
          metric: '25% Kesedaran Neuromuskular'
        },
        {
          phase: 2,
          title: 'Fasa 2: Kawalan Ambang & Pernafasan Rangsangan (Minggu 3-6)',
          highlight: 'Meningkatkan tempoh latensi intravaginal (IELT) secara bertahap.',
          details: 'Latihan teknik desensitisasi berperingkat dan kawalan ritma degupan jantung bagi mengelakkan lonjakan saraf simpatetik terlalu awal.',
          metric: '60% Peningkatan Kawalan Masa'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengukuhan Respons Ereksi Berterusan (Minggu 7-10)',
          highlight: 'Mengekalkan ketegangan tanpa keresahan prestasi (Performance Anxiety).',
          details: 'Kombinasi aliran darah vaskular yang kuat dan ketenangan psikologi menghasilkan kepuasan bersama pasangan secara konsisten.',
          metric: '85% Keyakinan Diri Puncak'
        },
        {
          phase: 4,
          title: 'Fasa 4: Kestabilan Spontan Seumur Hidup (Minggu 12+)',
          highlight: 'Keupayaan mengawal respon seksual secara automatik.',
          details: 'Hasil rawatan kekal berakar dalam memori otot dan sistem saraf tanpa perlu bergantung kepada ubat dos tinggi secara berterusan.',
          metric: '100% Kawalan Prestasi Mantap'
        }
      ]
    }
  };

  const activeTreatment = $derived(treatments[selectedTreatment]);
  const activePhaseInfo = $derived(activeTreatment.phases[selectedPhase - 1]);

  async function handleDispatchCare() {
    if (!patientName.trim()) {
      appState.addToast('Sila masukkan nama pesakit.', 'warning');
      return;
    }

    isDispatching = true;
    try {
      const res = await fetch('/api/clinic/care-dispatch', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          patientName,
          patientPhone,
          protocolId: selectedTreatment,
          branchCode: 'SSC-BSR',
          followUpDate
        })
      });

      if (res.ok) {
        dispatchResult = await res.json();
        appState.addToast('Panduan penjagaan digital berjaya dijana!', 'success');
      } else {
        const err = await res.json();
        appState.addToast(err.error || 'Gagal menjana panduan penjagaan.', 'error');
      }
    } catch (e: any) {
      appState.addToast(e.message, 'error');
    } finally {
      isDispatching = false;
    }
  }
</script>

<div class="consult-suite-view">
  <!-- Top Bar -->
  <header class="suite-header">
    <div class="header-titles">
      <div class="suite-pill">IN-CLINIC CONSULTATION SUITE • MODUL BILIK DOKTOR</div>
      <h1 class="suite-title">Kit Visual Konsultasi Pesakit & Standardisasi Prosedur</h1>
      <p class="suite-desc">
        Rajah anatomi interaktif dan simulasi fasa pemulihan bagi membantu pesakit memahami pelan rawatan klinikal secara saintifik dan telus.
      </p>
    </div>

    <div class="header-actions">
      <FluentButton appearance="primary" onclick={() => (dispatchModalOpen = true)}>
        📱 Hantar Panduan Selepas Rawatan (WhatsApp)
      </FluentButton>
    </div>
  </header>

  <!-- Treatment Selector Tabs -->
  <div class="treatment-tabs">
    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'eswt'}
      onclick={() => { selectedTreatment = 'eswt'; selectedPhase = 1; }}
    >
      <span class="tab-icon">⚡</span>
      <div class="tab-meta">
        <div class="tab-label">Terapi ESWT Shockwave</div>
        <div class="tab-sub">Neovaskularisasi & Aliran Darah</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'trt'}
      onclick={() => { selectedTreatment = 'trt'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🩸</span>
      <div class="tab-meta">
        <div class="tab-label">Terapi TRT Hormon</div>
        <div class="tab-sub">Pengoptimuman Profil Darah</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'pe_ed'}
      onclick={() => { selectedTreatment = 'pe_ed'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🎯</span>
      <div class="tab-meta">
        <div class="tab-label">Rehabilitasi PE/ED</div>
        <div class="tab-sub">Kawalan Neuromuskular Pelvis</div>
      </div>
    </button>
  </div>

  <!-- Interactive Visual Stage -->
  <div class="suite-stage-grid">
    <!-- Visual Anatomy Simulation Screen -->
    <div class="visual-canvas-card">
      <div class="canvas-top-tag">SIMULASI ANATOMI & MEKANISME TINDAKAN</div>
      <h2 class="canvas-treatment-title">{activeTreatment.title}</h2>
      <p class="canvas-treatment-desc">{activeTreatment.description}</p>

      <!-- Dynamic Vector Simulation Graphic -->
      <div class="vector-stage">
        {#if selectedTreatment === 'eswt'}
          <svg viewBox="0 0 600 240" class="anatomy-svg" aria-label="ESWT Shockwave Anatomy">
            <defs>
              <linearGradient id="waveGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stop-color="#21A1F7" stop-opacity="0.8"/>
                <stop offset="100%" stop-color="#043388" stop-opacity="0.2"/>
              </linearGradient>
            </defs>
            <!-- Vascular Tissue Bed -->
            <rect x="50" y="40" width="500" height="160" rx="16" fill="rgba(33, 161, 247, 0.05)" stroke="#043388" stroke-width="2"/>
            
            <!-- Shockwave Source Applicator -->
            <path d="M 60 70 L 110 90 L 110 150 L 60 170 Z" fill="#21A1F7"/>
            <text x="65" y="125" fill="#FFFFFF" font-size="11" font-weight="700">ESWT PROBE</text>

            <!-- Acoustic Propagation Waves -->
            <path d="M 125 80 Q 150 120 125 160" fill="none" stroke="#6DC6EC" stroke-width="3" stroke-dasharray="4,4"/>
            <path d="M 155 70 Q 185 120 155 170" fill="none" stroke="#21A1F7" stroke-width="4"/>
            <path d="M 185 60 Q 220 120 185 180" fill="none" stroke="#043388" stroke-width="4"/>

            <!-- Micro-Vascular Bed (New Capillaries) -->
            <g transform="translate(230, 60)">
              <circle cx="80" cy="60" r="45" fill="rgba(33, 161, 247, 0.1)" stroke="#38BDF8" stroke-width="2"/>
              <path d="M 30 60 Q 60 40 80 60 T 130 60" fill="none" stroke="#EF4444" stroke-width="5" stroke-linecap="round"/>
              <path d="M 80 60 Q 100 25 120 30" fill="none" stroke="#F87171" stroke-width="3" stroke-linecap="round"/>
              <path d="M 80 60 Q 95 95 125 90" fill="none" stroke="#F87171" stroke-width="3" stroke-linecap="round"/>
              <text x="50" y="125" fill="#38BDF8" font-size="12" font-weight="700">Salur Darah Mikro Baharu (Angiogenesis)</text>
            </g>
          </svg>
        {:else if selectedTreatment === 'trt'}
          <svg viewBox="0 0 600 240" class="anatomy-svg" aria-label="TRT Hormone Curve">
            <!-- Normal Range Band -->
            <rect x="50" y="40" width="500" height="70" fill="rgba(52, 211, 153, 0.1)" stroke="#10B981" stroke-width="1" stroke-dasharray="4,4"/>
            <text x="60" y="60" fill="#34D399" font-size="11" font-weight="700">Zon Terapeutik Optimum (15 - 30 nmol/L)</text>

            <!-- Deficient Baseline Curve -->
            <path d="M 50 180 Q 200 185 300 190 T 550 195" fill="none" stroke="#EF4444" stroke-width="3" stroke-dasharray="6,4"/>
            <text x="60" y="205" fill="#F87171" font-size="11">Paras Asas Rendah (Hipogonadisme)</text>

            <!-- TRT Optimized Steady Curve -->
            <path d="M 50 180 Q 120 70 200 75 T 350 78 T 550 75" fill="none" stroke="#21A1F7" stroke-width="4"/>
            <circle cx="200" cy="75" r="6" fill="#21A1F7"/>
            <text x="215" y="78" fill="#6DC6EC" font-size="12" font-weight="700">Paras Selepas Terapi TRT Terkawal</text>
          </svg>
        {:else}
          <svg viewBox="0 0 600 240" class="anatomy-svg" aria-label="Pelvic Neuromuscular Matrix">
            <rect x="50" y="40" width="500" height="160" rx="16" fill="rgba(139, 92, 246, 0.05)" stroke="#8B5CF6" stroke-width="2"/>
            <path d="M 100 120 Q 250 50 400 120 T 500 120" fill="none" stroke="#A78BFA" stroke-width="4"/>
            <circle cx="250" cy="85" r="10" fill="#8B5CF6"/>
            <text x="220" y="65" fill="#DDD6FE" font-size="12" font-weight="700">Titik Kawalan Neuromuskular</text>
            <text x="120" y="160" fill="#94A3B8" font-size="12">Latihan desensitisasi mengurangkan cetusan ejakulasi pra-matang secara mampan.</text>
          </svg>
        {/if}
      </div>

      <!-- Compliance Notice -->
      <div class="canvas-footer-note">
        🔒 *Semua rajah dan penerangan klinikal disemak mengikut Akta Iklan Ubat 1956 & garis panduan Lembaga Iklan Ubat (LIU/MAB).*
      </div>
    </div>

    <!-- 4-Phase Recovery Timeline Tracker -->
    <div class="phase-timeline-card">
      <div class="timeline-header">
        <span class="th-badge">PELAN RAWATAN & SASARAN PESAKIT</span>
        <h3 class="th-title">4 Fasa Kemajuan Klinikal</h3>
      </div>

      <!-- Phase Selector Pills -->
      <div class="phase-pills">
        {#each activeTreatment.phases as p}
          <button
            class="phase-pill-btn"
            class:selected={selectedPhase === p.phase}
            onclick={() => (selectedPhase = p.phase)}
          >
            Fasa {p.phase}
          </button>
        {/each}
      </div>

      <!-- Active Phase Details Display -->
      <div class="active-phase-box">
        <div class="ap-metric-badge">{activePhaseInfo.metric}</div>
        <h4 class="ap-title">{activePhaseInfo.title}</h4>
        <div class="ap-highlight">{activePhaseInfo.highlight}</div>
        <p class="ap-details">{activePhaseInfo.details}</p>
      </div>

      <!-- Interactive Range Slider -->
      <div class="slider-wrapper">
        <div class="slider-labels">
          <span>Minggu 1</span>
          <span>Minggu 6</span>
          <span>Minggu 12+</span>
        </div>
        <input
          type="range"
          min="1"
          max="4"
          step="1"
          bind:value={selectedPhase}
          class="phase-slider"
        />
      </div>

      <div class="doctor-tip-box">
        <span class="tip-icon">💡</span>
        <span class="tip-text">
          Tunjukkan fasa ini kepada pesakit semasa konsultasi bagi menetapkan jangkaan pemulihan yang realistik dan meningkatkan kepatuhan rawatan (*treatment adherence*).
        </span>
      </div>
    </div>
  </div>

  <!-- Dispatch Modal -->
  {#if dispatchModalOpen}
    <div class="modal-backdrop">
      <div class="modal-dialog">
        <div class="modal-head">
          <h3 class="modal-title">Hantar Panduan Selepas Rawatan ke WhatsApp Pesakit</h3>
          <button class="modal-close" onclick={() => (dispatchModalOpen = false)}>✕</button>
        </div>

        <div class="modal-body">
          <div class="form-group">
            <label for="pt-name">Nama Penuh Pesakit:</label>
            <input id="pt-name" type="text" bind:value={patientName} placeholder="cth: Tuan Ahmad Khairi" class="input-field"/>
          </div>

          <div class="form-group">
            <label for="pt-phone">Nombor Telefon WhatsApp:</label>
            <input id="pt-phone" type="tel" bind:value={patientPhone} placeholder="cth: 0123456789" class="input-field"/>
          </div>

          <div class="form-group">
            <label for="pt-date">Tarikh Temujanji Susulan (Pilihan):</label>
            <input id="pt-date" type="text" bind:value={followUpDate} placeholder="cth: 15 Oktober 2026, 11:00 AM" class="input-field"/>
          </div>

          {#if dispatchResult}
            <div class="dispatch-result-box">
              <div class="dr-title">Mesej WhatsApp Bersedia untuk Dihantar:</div>
              <pre class="dr-preview">{dispatchResult.messageText}</pre>
              <a
                href={dispatchResult.whatsappUrl}
                target="_blank"
                rel="noreferrer"
                class="wa-jump-link"
              >
                👉 Buka WhatsApp &amp; Hantar Mesej Sekarang ↗
              </a>
            </div>
          {/if}
        </div>

        <div class="modal-foot">
          <FluentButton appearance="secondary" onclick={() => (dispatchModalOpen = false)}>Tutup</FluentButton>
          <FluentButton appearance="primary" onclick={handleDispatchCare} disabled={isDispatching}>
            {isDispatching ? 'Menjana...' : 'Jana Pautan WhatsApp'}
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
  }

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
    max-width: 800px;
    line-height: 1.5;
  }

  .treatment-tabs {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
  }

  .treatment-tab-btn {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px 20px;
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 14px;
    cursor: pointer;
    text-align: left;
    transition: all 0.15s ease;
  }

  .treatment-tab-btn:hover {
    background: rgba(255, 255, 255, 0.08);
  }

  .treatment-tab-btn.active {
    background: linear-gradient(135deg, rgba(4, 51, 136, 0.25) 0%, rgba(33, 161, 247, 0.15) 100%);
    border: 2px solid #21A1F7;
    box-shadow: 0 4px 20px rgba(33, 161, 247, 0.15);
  }

  .tab-icon {
    font-size: 28px;
  }

  .tab-label {
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary, #FFFFFF);
    margin-bottom: 2px;
  }

  .tab-sub {
    font-size: 12px;
    color: var(--text-secondary, #94A3B8);
  }

  .suite-stage-grid {
    display: grid;
    grid-template-columns: 1.3fr 1fr;
    gap: 24px;
  }

  .visual-canvas-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 20px;
    padding: 28px;
    display: flex;
    flex-direction: column;
  }

  .canvas-top-tag {
    font-size: 11px;
    font-weight: 700;
    color: #21A1F7;
    letter-spacing: 0.8px;
    margin-bottom: 8px;
  }

  .canvas-treatment-title {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0 0 8px 0;
  }

  .canvas-treatment-desc {
    font-size: 13px;
    color: var(--text-secondary, #94A3B8);
    margin: 0 0 20px 0;
    line-height: 1.5;
  }

  .vector-stage {
    background: rgba(0, 0, 0, 0.25);
    border-radius: 14px;
    padding: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 260px;
    margin-bottom: 16px;
  }

  .anatomy-svg {
    width: 100%;
    height: auto;
  }

  .canvas-footer-note {
    font-size: 11px;
    color: var(--text-secondary, #64748B);
    margin-top: auto;
  }

  /* Phase Timeline Card */
  .phase-timeline-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 20px;
    padding: 28px;
    display: flex;
    flex-direction: column;
  }

  .th-badge {
    font-size: 11px;
    font-weight: 700;
    color: #38BDF8;
    letter-spacing: 0.8px;
  }

  .th-title {
    font-size: 18px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 4px 0 16px 0;
  }

  .phase-pills {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 16px;
  }

  .phase-pill-btn {
    padding: 8px;
    border-radius: 8px;
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.1));
    background: transparent;
    color: var(--text-secondary, #94A3B8);
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .phase-pill-btn.selected {
    background: #043388;
    color: #FFFFFF;
    border-color: #21A1F7;
  }

  .active-phase-box {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 14px;
    padding: 20px;
    margin-bottom: 20px;
  }

  .ap-metric-badge {
    display: inline-block;
    padding: 3px 10px;
    background: rgba(52, 211, 153, 0.15);
    border: 1px solid #10B981;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    color: #34D399;
    margin-bottom: 8px;
  }

  .ap-title {
    font-size: 15px;
    font-weight: 800;
    color: var(--text-primary, #FFFFFF);
    margin: 0 0 6px 0;
  }

  .ap-highlight {
    font-size: 13px;
    font-weight: 600;
    color: #38BDF8;
    margin-bottom: 8px;
  }

  .ap-details {
    font-size: 12px;
    color: var(--text-secondary, #CBD5E1);
    line-height: 1.5;
    margin: 0;
  }

  .slider-wrapper {
    margin-bottom: 20px;
  }

  .slider-labels {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--text-secondary, #94A3B8);
    margin-bottom: 6px;
  }

  .phase-slider {
    width: 100%;
    accent-color: #21A1F7;
    cursor: pointer;
  }

  .doctor-tip-box {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 14px;
    background: rgba(33, 161, 247, 0.06);
    border: 1px dashed rgba(33, 161, 247, 0.3);
    border-radius: 10px;
    font-size: 12px;
    color: #BAE6FD;
    line-height: 1.4;
  }

  /* Modal */
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
    font-size: 18px;
    cursor: pointer;
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
  }

  .input-field:focus {
    border-color: #21A1F7;
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
</style>

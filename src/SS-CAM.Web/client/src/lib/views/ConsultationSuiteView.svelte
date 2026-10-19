<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import copy, { getErrorMessage } from '$lib/copy';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentErrorBanner from '$lib/components/ui/FluentErrorBanner.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import { ApiClient } from '$lib/services/api';

  let selectedTreatment = $state<'eswt' | 'kegel' | 'pshot' | 'trt' | 'fertility' | 'pe_ed'>('eswt');
  let selectedPhase = $state(1); // 1, 2, 3, 4
  let patientName = $state('');
  let patientPhone = $state('');
  let followUpDate = $state('');
  let dispatchModalOpen = $state(false);
  let dispatchResult = $state<any>(null);
  let isDispatching = $state(false);
  let branches = $state<any[]>([]);
  let isLoadingBranches = $state(false);
  let branchError = $state<string | null>(null);
  let selectedBranch = $state('SSC-BSR');
  let dispatchError = $state<string | null>(null);

  onMount(async () => {
    await loadBranches();
  });

  async function loadBranches() {
    isLoadingBranches = true;
    branchError = null;
    try {
      const res = await ApiClient.request('/clinic/branches');
      branches = res.branches || [];
      // Branches come from the Corporate Registry; keep the selection valid for whatever it holds.
      if (branches.length > 0 && !branches.some((b: any) => b.code === selectedBranch)) {
        selectedBranch = branches[0].code;
      }
    } catch (err: any) {
      branchError = getErrorMessage(err, 'We couldn\'t load the clinic branch information. Please try again.');
    } finally {
      isLoadingBranches = false;
    }
  }

  const treatments = {
    eswt: {
      id: 'eswt',
      name: 'Terapi Gelombang Kejutan (ESWT) / Shockwave Therapy',
      title: 'Pemulihan Vaskularisasi & Pengaliran Darah Mikro / Vascular & Microcirculation Recovery',
      description: 'Gelombang akustik berintensiti rendah merangsang faktor pertumbuhan salur darah (VEGF), menguraikan plak mikroskopik dan menyokong pembentukan kapilari darah baharu secara semulajadi.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Penilaian Asas & Rangsangan Selular (Minggu 1-2) / Phase 1: Baseline & Cellular Activation',
          highlight: 'Memulakan pengaktifan metabolik tisu tanpa kesakitan.',
          details: 'Sesi 1 & 2 dimulakan pada paras tenaga terkawal (0.09 mJ/mm²). Sel endotelium mula dirangsang untuk melepaskan molekul nitrik oksida (NO).',
          metric: 'Pengaktifan Tisu Asas / Tissue Activation'
        },
        {
          phase: 2,
          title: 'Fasa 2: Neovaskularisasi & Pembentukan Kapilari (Minggu 3-6) / Phase 2: Neovascularization',
          highlight: 'Pembentukan jaringan salur darah mikro baharu (Angiogenesis).',
          details: 'Peningkatan aliran darah oksigen ke tisu spons korpus kavernosum bagi menyokong respons ereksi semulajadi.',
          metric: 'Perfusi Vaskular Bertambah / Enhanced Perfusion'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengukuhan Struktur & Ketahanan (Minggu 7-10) / Phase 3: Structural Strengthening',
          highlight: 'Penyatuan serat kolagen dan pemulihan elastisiti tisu.',
          details: 'Ketegangan dan daya tahan ereksi mencapai kestabilan yang optimum dengan pengurangan tempoh latensi pemulihan.',
          metric: 'Kestabilan Prestasi Tisu / Tissue Stability'
        },
        {
          phase: 4,
          title: 'Fasa 4: Penyelenggaraan Jangka Panjang (Minggu 12+) / Phase 4: Long-Term Maintenance',
          highlight: 'Mengekalkan tahap kesihatan vaskular secara berterusan.',
          // copy review needed: removed absolute claim 'sepanjang hayat'
          details: 'Semakan berkala setiap 6 bulan bersama bimbingan senaman lantai pelvis bagi menyokong kesihatan vaskular berterusan.',
          metric: 'Sasaran Klinikal Dicapai / Clinical Target Achieved'
        }
      ]
    },
    kegel: {
      id: 'kegel',
      name: 'Kerusi Kegel / Kegel Chair',
      title: 'Latihan Otot Dasar Pelvis Berpandu / Guided Pelvic Floor Training',
      description: 'Sesi latihan otot dasar pelvis yang berpandu bagi menyokong kawalan dan kesihatan pelvis lelaki. Kesan dibina secara berperingkat melalui sesi berjadual.',
      // copy review needed: clinical wording must be confirmed by the Medical Director.
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Pengenalan Otot & Teknik Betul (Sesi 1-2) / Phase 1: Learn the Technique',
          highlight: 'Mengenal pasti otot dasar pelvis dan teknik pengecutan yang betul.',
          details: 'Pesakit dibimbing untuk mengenali otot yang disasarkan dan merasai perbezaan antara pengecutan yang betul dan salah.',
          metric: 'Kesedaran Otot / Muscle Awareness'
        },
        {
          phase: 2,
          title: 'Fasa 2: Pembinaan Ketahanan Otot (Sesi 3-6) / Phase 2: Build Endurance',
          highlight: 'Meningkatkan ketahanan dan kawalan otot secara beransur-ansur.',
          details: 'Tahap latihan dinaikkan mengikut toleransi pesakit; latihan di rumah digalakkan untuk menyokong kemajuan.',
          metric: 'Ketahanan Otot / Muscle Endurance'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengukuhan & Kawalan (Sesi 7-10) / Phase 3: Strengthen & Control',
          highlight: 'Menggabungkan kekuatan otot dengan kawalan pernafasan.',
          details: 'Fokus kepada konsistensi kawalan otot dan penyesuaian program bersama doktor berdasarkan kemajuan.',
          metric: 'Kawalan Konsisten / Consistent Control'
        },
        {
          phase: 4,
          title: 'Fasa 4: Penyelenggaraan (Selepas Pakej) / Phase 4: Maintenance',
          highlight: 'Meneruskan latihan di rumah untuk mengekalkan hasil.',
          details: 'Sesi penyelenggaraan berkala dan latihan harian disyorkan mengikut nasihat doktor.',
          metric: 'Rutin Penyelenggaraan / Maintenance Routine'
        }
      ]
    },
    pshot: {
      id: 'pshot',
      name: 'Rawatan Regeneratif (P-Shot) / Regenerative Therapy',
      title: 'Rawatan Regeneratif Selepas Penilaian Klinikal / Regenerative Care After Clinical Assessment',
      description: 'Rawatan regeneratif dilakukan doktor selepas konsultasi dan ujian darah. Pilihan rawatan dan kesesuaian ditentukan secara individu.',
      // copy review needed: no outcome claims; Medical Director to confirm wording and LIU status.
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Konsultasi & Ujian Darah (Minggu 1) / Phase 1: Consultation & Blood Review',
          highlight: 'Penilaian menyeluruh sebelum sebarang keputusan rawatan.',
          details: 'Doktor menyemak sejarah kesihatan dan keputusan darah untuk menentukan kesesuaian dan pilihan rawatan.',
          metric: 'Penilaian Kesesuaian / Suitability Assessed'
        },
        {
          phase: 2,
          title: 'Fasa 2: Persetujuan & Prosedur (Minggu 2-3) / Phase 2: Consent & Procedure',
          highlight: 'Penerangan risiko dan manfaat sebelum persetujuan termaklum.',
          details: 'Prosedur dijalankan oleh doktor bertauliah selepas pesakit memahami dan menandatangani persetujuan termaklum.',
          metric: 'Persetujuan Termaklum / Informed Consent'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pemulihan & Pemantauan (Minggu 4-8) / Phase 3: Recovery & Monitoring',
          highlight: 'Pemantauan respons dan kesan sampingan oleh doktor.',
          details: 'Pesakit mengikut panduan penjagaan dan melaporkan sebarang perubahan semasa semakan susulan.',
          metric: 'Pemantauan Respons / Response Monitoring'
        },
        {
          phase: 4,
          title: 'Fasa 4: Semakan Susulan & Pelan Lanjut (Minggu 12+) / Phase 4: Follow-Up Review',
          highlight: 'Semakan semula dan pelan penyelenggaraan jika sesuai.',
          details: 'Doktor menilai kemajuan dan menentukan sama ada rawatan lanjut diperlukan.',
          metric: 'Semakan Kemajuan / Progress Review'
        }
      ]
    },
    fertility: {
      id: 'fertility',
      name: 'Program Kesuburan Lelaki / Male Fertility Program',
      title: 'Analisis Sperma & Program Infusi 12 Minggu / Sperm Analysis & 12-Week Infusion Program',
      description: 'Program 12 minggu menggunakan infusi NAD+ dan Signature Drip bagi menyokong kesihatan sperma, termasuk kiraan, motiliti dan mobiliti. Dipantau doktor.',
      // copy review needed: source is the internal Fertility Program Protocol (18 Oct 2026); outcome claims intentionally omitted.
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Analisis Sperma & Ujian Hormon (Minggu 1) / Phase 1: Baseline Testing',
          highlight: 'Penilaian asas sebelum program bermula.',
          details: 'Sampel dihantar ke makmal melalui pengatur operasi klinik. Ujian darah hormon dilakukan mengikut keperluan doktor.',
          metric: 'Titik Asas / Baseline Established'
        },
        {
          phase: 2,
          title: 'Fasa 2: Infusi Berjadual (Minggu 2-6) / Phase 2: Scheduled Infusions',
          highlight: 'Sesi infusi NAD+ dan Signature Drip mengikut jadual.',
          details: 'Pesakit hadir untuk sesi berjadual; doktor memantau toleransi dan menyesuaikan program jika perlu.',
          metric: 'Pematuhan Program / Program Adherence'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pemantauan Pertengahan (Minggu 7-9) / Phase 3: Mid-Program Review',
          highlight: 'Semakan kemajuan dan gaya hidup.',
          details: 'Doktor menyemak kemajuan dan menasihati tentang tidur, pemakanan, merokok dan alkohol.',
          metric: 'Semakan Pertengahan / Mid-Review'
        },
        {
          phase: 4,
          title: 'Fasa 4: Analisis Semula (Minggu 12) / Phase 4: Repeat Analysis',
          highlight: 'Analisis sperma susulan bagi menilai kemajuan.',
          details: 'Keputusan dibincangkan bersama doktor untuk menentukan langkah seterusnya.',
          metric: 'Penilaian Susulan / Follow-Up Assessment'
        }
      ]
    },
    trt: {
      id: 'trt',
      name: 'Terapi Penggantian Testosteron (TRT) / Hormone Therapy',
      title: 'Pengoptimuman Profil Hormon & Kesejahteraan Metabolik / Hormone Profile Optimization',
      description: 'Pelan rawatan perubatan berasaskan ujian darah klinikal bagi mengoptimumkan paras hormon testosteron ke paras fisiologi lelaki aktif.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Ujian Profil Darah & Penentuan Dos (Minggu 1-2) / Phase 1: Blood Profile & Dosing',
          highlight: 'Penetapan dos selamat berasaskan Total T, Free T, PSA & Hct.',
          details: 'Penyelaras klinikal memeriksa fungsi hati, buah pinggang dan kepekatan sel darah merah sebelum memulakan pelan rawatan.',
          metric: 'Penetapan Titik Asas / Baseline Established'
        },
        {
          phase: 2,
          title: 'Fasa 2: Pemulihan Tenaga & Kualiti Tidur (Minggu 3-6) / Phase 2: Energy & Sleep Recovery',
          highlight: 'Penurunan rasa letih kronik dan kejelasan mental meningkat.',
          details: 'Paras androgen mula stabil. Pesakit melaporkan tidur lebih lena, mood positif, dan tenaga harian yang lebih konsisten.',
          metric: 'Peningkatan Stamina & Tenaga / Energy Recovery'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengurangan Lemak Viseral & Komposisi Otot (Minggu 7-10) / Phase 3: Body Composition',
          highlight: 'Metabolisme lipid meningkat dan pembentukan jisim otot tanpa lemak.',
          details: 'Sensitiviti insulin bertambah baik. Pengurangan lemak viseral lebih efektif apabila digandingkan dengan senaman asas.',
          metric: 'Peningkatan Komposisi Badan / Composition Progress'
        },
        {
          phase: 4,
          title: 'Fasa 4: Pemantauan Darah 12-Minggu & Penyelenggaraan (Minggu 12+) / Phase 4: 12-Week Monitoring',
          highlight: 'Ujian darah susulan bagi memantau keselamatan kardiovaskular.',
          details: 'Semakan semula paras hematokrit dan lipid darah bagi memastikan paras hormon kekal dalam zon terapeutik selamat.',
          metric: 'Keseimbangan Endokrin Optimum / Optimal Balance'
        }
      ]
    },
    pe_ed: {
      id: 'pe_ed',
      name: 'Rehabilitasi Prestasi Lelaki / Men\'s Health (PE/ED)',
      title: 'Pendekatan Klinikal Bersepadu & Kawalan Neuromuskular / Integrated Clinical Approach',
      description: 'Gabungan fisioterapi lantai pelvis, modulasi neuro-sensori dan sokongan klinikal berdaftar KKM bagi memulihkan kawalan dan keyakinan intim.',
      phases: [
        {
          phase: 1,
          title: 'Fasa 1: Pemetaan Sensori & Kekuatan Otot Pelvis (Minggu 1-2) / Phase 1: Sensory Mapping',
          highlight: 'Mengenal pasti otot bulbocavernosus dan kawalan reflex.',
          details: 'Doktor menguji ambang kepekaan saraf dan melatih teknik pengecutan otot dasar panggul yang betul.',
          metric: 'Kesedaran Neuromuskular / Neuromuscular Awareness'
        },
        {
          phase: 2,
          title: 'Fasa 2: Kawalan Ambang & Pernafasan (Minggu 3-6) / Phase 2: Threshold & Breathing Control',
          highlight: 'Meningkatkan kawalan ambang rangsangan secara bertahap.',
          details: 'Latihan teknik desensitisasi berperingkat dan kawalan ritma pernafasan bagi mengelakkan lonjakan saraf terlalu awal.',
          metric: 'Peningkatan Kawalan Masa / Latency Control'
        },
        {
          phase: 3,
          title: 'Fasa 3: Pengukuhan Respons Ereksi Berterusan (Minggu 7-10) / Phase 3: Response Strengthening',
          highlight: 'Mengekalkan ketegangan tanpa keresahan prestasi (Performance Anxiety).',
          // copy review needed: adjusted absolute claim 'kepuasan secara konsisten'
          details: 'Kombinasi aliran darah vaskular yang lancar dan ketenangan psikologi menyokong kestabilan tindak balas intim.',
          metric: 'Pengukuhan Keyakinan Diri / Confidence Established'
        },
        {
          phase: 4,
          title: 'Fasa 4: Penyelenggaraan & Kestabilan Lanjutan (Minggu 12+) / Phase 4: Long-Term Stability',
          // copy review needed: adjusted claim 'secara automatik' and 'seumur hidup'
          highlight: 'Kawalan respon seksual yang lebih terlatih dan konsisten.',
          // copy review needed: adjusted absolute claim 'tanpa perlu bergantung kepada ubat'
          details: 'Hasil rawatan diperkukuh melalui memori otot dan latihan neuromuskular dengan sokongan bimbingan klinikal.',
          metric: 'Kawalan Prestasi Mantap / Consistent Control'
        }
      ]
    }
  };

  const activeBranch = $derived(branches.find((b: any) => b.code === selectedBranch) ?? null);
  const pricing = $derived(activeBranch?.pricing ?? null);

  function formatPrice(amount: number | null | undefined): string {
    if (amount === null || amount === undefined) return '-';
    return (pricing?.currency ?? 'RM') + ' ' + Number(amount).toLocaleString('en-MY');
  }

  const activeTreatment = $derived(treatments[selectedTreatment]);
  const activePhaseInfo = $derived(activeTreatment.phases[selectedPhase - 1]);

  async function handleDispatchCare() {
    if (!patientName.trim()) {
      appState.addToast('Sila masukkan nama pesakit. / Please enter patient name.', 'warning');
      return;
    }

    isDispatching = true;
    dispatchError = null;
    try {
      // Uses the signed-in session: this endpoint handles a patient's name and phone number.
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
      appState.addToast('Panduan penjagaan digital berjaya dijana. / Digital care guide generated.', 'success');
    } catch (e: any) {
      const msg = getErrorMessage(e, 'We couldn\'t generate the care guide. Please try again.');
      dispatchError = msg;
      appState.addToast(msg, 'error');
    } finally {
      isDispatching = false;
    }
  }
</script>

<div class="consult-suite-view">
  {#if branchError}
    <FluentErrorBanner
      title="Unable to connect to clinic services"
      message={branchError}
      retryLabel="Retry Connection"
      onRetry={loadBranches}
    />
  {/if}

  <!-- Top Bar -->
  <header class="suite-header">
    <div class="header-titles">
      <div class="suite-pill">IN-CLINIC CONSULTATION SUITE • MODUL BILIK DOKTOR</div>
      <h1 class="suite-title">Consultation kit</h1>
      <p class="suite-desc">
        Interactive anatomical simulation and clinical recovery phases to help patients understand treatment plans with clarity and transparency.
      </p>
      <p class="suite-desc" style="margin-top: 4px; font-size: 13px; opacity: 0.85;">
        Rajah anatomi interaktif dan simulasi fasa pemulihan bagi membantu pesakit memahami pelan rawatan klinikal secara saintifik dan telus.
      </p>
    </div>

    <div class="header-actions">
      <FluentButton appearance="primary" onclick={() => (dispatchModalOpen = true)}>
        <FluentIcons name="phone" size={15} /> Hantar Panduan Selepas Rawatan / Send Guide (WhatsApp)
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
        <div class="tab-label">Terapi ESWT / Shockwave</div>
        <div class="tab-sub">Neovaskularisasi &amp; Aliran Darah / Blood Flow</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'kegel'}
      onclick={() => { selectedTreatment = 'kegel'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🪑</span>
      <div class="tab-meta">
        <div class="tab-label">Kerusi Kegel / Kegel Chair</div>
        <div class="tab-sub">Latihan Otot Pelvis / Pelvic Floor Training</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'pshot'}
      onclick={() => { selectedTreatment = 'pshot'; selectedPhase = 1; }}
    >
      <span class="tab-icon">💉</span>
      <div class="tab-meta">
        <div class="tab-label">Rawatan Regeneratif / P-Shot</div>
        <div class="tab-sub">Penilaian &amp; Pemantauan Doktor / Doctor-Led Care</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'fertility'}
      onclick={() => { selectedTreatment = 'fertility'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🧬</span>
      <div class="tab-meta">
        <div class="tab-label">Kesuburan Lelaki / Male Fertility</div>
        <div class="tab-sub">Program 12 Minggu / 12-Week Program</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'trt'}
      onclick={() => { selectedTreatment = 'trt'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🩸</span>
      <div class="tab-meta">
        <div class="tab-label">Terapi TRT / Hormone</div>
        <div class="tab-sub">Pengoptimuman Profil Darah / Blood Profile</div>
      </div>
    </button>

    <button
      class="treatment-tab-btn"
      class:active={selectedTreatment === 'pe_ed'}
      onclick={() => { selectedTreatment = 'pe_ed'; selectedPhase = 1; }}
    >
      <span class="tab-icon">🎯</span>
      <div class="tab-meta">
        <div class="tab-label">Rehabilitasi PE/ED / Men's Health</div>
        <div class="tab-sub">Kawalan Pelvis / Neuromuscular Control</div>
      </div>
    </button>
  </div>

  <!-- Interactive Visual Stage -->
  <div class="suite-stage-grid">
    <!-- Visual Anatomy Simulation Screen -->
    <div class="visual-canvas-card">
      <div class="canvas-top-tag">SIMULASI ANATOMI &amp; MEKANISME TINDAKAN / ANATOMY SIMULATION</div>
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
        {:else if selectedTreatment !== 'pe_ed'}
          <svg viewBox="0 0 600 240" class="anatomy-svg" aria-label="Treatment roadmap: four phases">
            <line x1="80" y1="120" x2="520" y2="120" stroke="#21A1F7" stroke-width="4" stroke-linecap="round"/>
            {#each [1, 2, 3, 4] as n}
              <circle cx={80 + (n - 1) * 146.7} cy="120" r={n === selectedPhase ? 16 : 10} fill={n === selectedPhase ? '#21A1F7' : '#043388'} stroke="#6DC6EC" stroke-width="2"/>
              <text x={80 + (n - 1) * 146.7} y="125" text-anchor="middle" fill="#FFFFFF" font-size="12" font-weight="700">{n}</text>
              <text x={80 + (n - 1) * 146.7} y="165" text-anchor="middle" fill="#94A3B8" font-size="11">Fasa {n} / Phase {n}</text>
            {/each}
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
        <span class="th-badge">PELAN RAWATAN &amp; SASARAN / TREATMENT PLAN &amp; TARGETS</span>
        <h3 class="th-title">4 Fasa Kemajuan Klinikal / 4 Clinical Progress Phases</h3>
      </div>

      <!-- Phase Selector Pills -->
      <div class="phase-pills">
        {#each activeTreatment.phases as p}
          <button
            class="phase-pill-btn"
            class:selected={selectedPhase === p.phase}
            onclick={() => (selectedPhase = p.phase)}
          >
            Fasa {p.phase} / Phase {p.phase}
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
          <span>Minggu 1 / Wk 1</span>
          <span>Minggu 6 / Wk 6</span>
          <span>Minggu 12+ / Wk 12+</span>
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
          Tunjukkan fasa ini kepada pesakit semasa konsultasi bagi menetapkan jangkaan pemulihan yang realistik dan menyokong kepatuhan rawatan (*treatment adherence*). / Share this timeline with the patient to establish realistic expectations and support treatment adherence.
        </span>
      </div>
    </div>
  </div>

  <!-- Consultation checklist: from the clinics' daily new-case report format -->
  <section class="checklist-card" aria-labelledby="checklist-title">
    <h3 id="checklist-title" class="th-title">Senarai Semak Konsultasi / Consultation Checklist</h3>

    <div class="price-block" aria-live="polite">
      <div class="price-head">
        <label for="branch-select">Cawangan / Branch:</label>
        <select id="branch-select" class="input-field branch-select" bind:value={selectedBranch} disabled={isLoadingBranches || branches.length === 0}>
          {#each branches as b}
            <option value={b.code}>{b.shortName || b.name}</option>
          {/each}
        </select>
      </div>
      {#if isLoadingBranches}
        <p class="price-empty">Memuatkan harga... / Loading pricing...</p>
      {:else if !pricing}
        <p class="price-empty">Harga belum dikonfigurasi untuk cawangan ini. Hubungi pentadbir (Administration &rarr; Companies). / Pricing is not configured for this branch.</p>
      {:else}
        <dl class="price-list">
          <div><dt>Yuran konsultasi / Consultation fee</dt><dd>{formatPrice(pricing.consultationFee)}</dd></div>
          {#if pricing.onlineBookingFee !== null && pricing.onlineBookingFee !== undefined}
            <div><dt>Tempahan dalam talian / Online booking</dt><dd>{formatPrice(pricing.onlineBookingFee)}{pricing.onlineBookingNote ? ' - ' + pricing.onlineBookingNote : ''}</dd></div>
          {/if}
          {#each pricing.packages ?? [] as pk}
            <div><dt>{pk.label}</dt><dd>{formatPrice(pk.price)}</dd></div>
          {/each}
        </dl>
        {#if pricing.validFrom || pricing.validTo}
          <p class="price-note">Sah / Valid: {pricing.validFrom || '-'} &rarr; {pricing.validTo || '-'}</p>
        {/if}
      {/if}
    </div>
    <ul class="checklist-list">
      <li><strong>Yuran konsultasi / Consultation fee:</strong> nyatakan dengan jelas di awal supaya pesakit tidak menganggapnya percuma. / State it clearly up front so it is not assumed free.</li>
      <li><strong>Profil pesakit / Patient profile:</strong> umur, aduan utama (diagnosis), bajet, lokasi. / Age, main complaint, budget, location.</li>
      <li><strong>Isu utama / Main issue:</strong> tahap pengetahuan rawatan, kebimbangan, dan keperluan berbincang dengan pasangan. / Treatment knowledge, concerns, need to discuss with partner.</li>
      <li><strong>Sumber lead / Lead source:</strong> Facebook, TikTok, Instagram, Google, billboard, rujukan. / Facebook, TikTok, Instagram, Google, billboard, referral.</li>
      <li><strong>Pasukan jualan/operasi / Sales or operations contact:</strong> untuk susulan hari berikutnya. / For next-day follow-up.</li>
      <li><strong>Analisis sperma / Sperm analysis:</strong> maklumkan pasukan operasi supaya pengambilan sampel oleh pelari makmal dapat diatur. / Inform operations so a lab runner can be arranged.</li>
      <li><strong>Peringatan / Reminder:</strong> hantar panduan arah &amp; parkir kepada pesakit selepas temujanji disahkan (jika ada penutupan pintu utama). / Send the directions and parking guide once the appointment is confirmed.</li>
    </ul>
  </section>

  <!-- Dispatch Modal -->
  {#if dispatchModalOpen}
    <div class="modal-backdrop">
      <div class="modal-dialog">
        <div class="modal-head">
          <h3 class="modal-title">Hantar Panduan Selepas Rawatan / Send Post-Care Guide (WhatsApp)</h3>
          <button class="modal-close" onclick={() => (dispatchModalOpen = false)} aria-label="Close dialog"><FluentIcons name="close" size={16} /></button>
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
            <label for="pt-name">Nama Penuh Pesakit / Patient Full Name:</label>
            <input id="pt-name" type="text" bind:value={patientName} placeholder="cth: Tuan Ahmad Khairi" class="input-field"/>
          </div>

          <div class="form-group">
            <label for="pt-phone">Nombor Telefon WhatsApp / WhatsApp Phone Number:</label>
            <input id="pt-phone" type="tel" bind:value={patientPhone} placeholder="cth: 0123456789" class="input-field"/>
          </div>

          <div class="form-group">
            <label for="pt-date">Tarikh Temujanji Susulan (Pilihan) / Follow-Up Date (Optional):</label>
            <input id="pt-date" type="text" bind:value={followUpDate} placeholder="cth: 15 Oktober 2026, 11:00 AM" class="input-field"/>
          </div>

          {#if dispatchResult}
            <div class="dispatch-result-box">
              <div class="dr-title">Mesej WhatsApp Bersedia untuk Dihantar / Ready to Send:</div>
              <pre class="dr-preview">{dispatchResult.messageText}</pre>
              <a
                href={dispatchResult.whatsappUrl}
                target="_blank"
                rel="noreferrer"
                class="wa-jump-link"
              >
                👉 Buka WhatsApp &amp; Hantar Mesej / Open WhatsApp &amp; Send Message ↗
              </a>
            </div>
          {/if}
        </div>

        <div class="modal-foot">
          <FluentButton appearance="secondary" onclick={() => (dispatchModalOpen = false)}>Tutup / Close</FluentButton>
          <FluentButton appearance="primary" onclick={handleDispatchCare} disabled={isDispatching}>
            {isDispatching ? 'Menjana / Generating...' : 'Jana Pautan WhatsApp / Generate WhatsApp Link'}
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
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
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

  .checklist-card {
    background: var(--card-bg, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--card-stroke, rgba(255, 255, 255, 0.08));
    border-radius: 20px;
    padding: 28px;
  }

  .price-block {
    margin: 0 0 16px 0;
    padding: 16px;
    border: 1px dashed rgba(33, 161, 247, 0.3);
    border-radius: 12px;
  }

  .price-head {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 12px;
    font-size: 12px;
    font-weight: 600;
    color: #CBD5E1;
  }

  .branch-select {
    min-height: 36px;
    min-width: 220px;
  }

  .price-list {
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
    font-size: 13px;
  }

  .price-list div {
    display: flex;
    justify-content: space-between;
    gap: 16px;
  }

  .price-list dt { color: var(--text-secondary, #CBD5E1); }
  .price-list dd { margin: 0; font-weight: 700; color: var(--text-primary, #FFFFFF); text-align: right; }
  .price-empty, .price-note { margin: 0; font-size: 12px; color: var(--text-secondary, #94A3B8); }
  .price-note { margin-top: 8px; }

  .checklist-list {
    margin: 0;
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    font-size: 13px;
    line-height: 1.5;
    color: var(--text-secondary, #CBD5E1);
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
    box-shadow: var(--focus-ring);
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

/**
 * SS-CAM Consultation Suite Bilingual Dictionary (BM / EN)
 * Clinical reference-backed content supporting evidence-based in-clinic patient education.
 */

export type ConsultationLang = 'ms' | 'en';

export interface TreatmentPhase {
  phase: number;
  title: string;
  highlight: string;
  details: string;
  metric: string;
}

export interface TreatmentEvidence {
  level: 'Guideline-Supported' | 'Investigational / Selected Patients' | 'Clinical Protocol' | 'Standard Clinical Practice';
  levelLabel: string;
  citation: string;
  clinicalNote: string;
  reviewMarker?: string;
  refId: number;
}

export interface MedicalReferenceItem {
  id: number;
  treatmentId: 'eswt' | 'kegel' | 'pshot' | 'fertility' | 'trt' | 'pe_ed';
  citation: string;
  guidelineBody: string;
  year: string;
  evidenceLevel: string;
  recommendation: string;
  clinicalApplication: string;
  reviewMarker?: string;
  url?: string;
}

export interface MedicalReferencesSection {
  title: string;
  subtitle: string;
  badge: string;
  toggleOpen: string;
  toggleClose: string;
  directorNoticeTitle: string;
  directorNoticeText: string;
  allFilterLabel: string;
  currentFilterLabel: string;
  jumpToCitationLabel: string;
  viewGuidelineBtn: string;
  references: MedicalReferenceItem[];
}

export interface TreatmentData {
  id: 'eswt' | 'kegel' | 'pshot' | 'fertility' | 'trt' | 'pe_ed';
  name: string;
  shortName: string;
  tagline: string;
  title: string;
  description: string;
  targetPatient: string;
  contraindications: string;
  evidence: TreatmentEvidence;
  phases: TreatmentPhase[];
}

export interface ConsultationDictionary {
  badge: string;
  title: string;
  desc: string;
  patientViewBtn: string;
  exitPatientViewBtn: string;
  sendGuideBtn: string;
  langToggleAria: string;
  patientViewBadge: string;
  patientViewHint: string;
  doctorOnlyBadge: string;

  stage: {
    topTag: string;
    phaseScrubberTitle: string;
    week1Label: string;
    week6Label: string;
    week12Label: string;
    doctorTip: string;
    patientTip: string;
    illustrativeNote: string;
    evidenceLevelTitle: string;
  };

  tabs: Record<string, { label: string; sub: string }>;

  checklist: {
    title: string;
    subtitle: string;
    items: { title: string; desc: string }[];
  };

  pricing: {
    title: string;
    branchLabel: string;
    loading: string;
    notConfigured: string;
    consultationFee: string;
    onlineBooking: string;
    validDate: string;
  };

  dispatchModal: {
    title: string;
    patientNameLabel: string;
    patientNamePlaceholder: string;
    phoneLabel: string;
    phonePlaceholder: string;
    dateLabel: string;
    datePlaceholder: string;
    readyTitle: string;
    openWaBtn: string;
    closeBtn: string;
    generateBtn: string;
    generatingBtn: string;
    nameWarning: string;
    successToast: string;
    errorDefault: string;
  };

  disclaimer: {
    text: string;
    reviewStamp: string;
  };

  referencesSection: MedicalReferencesSection;

  treatments: Record<'eswt' | 'kegel' | 'pshot' | 'fertility' | 'trt' | 'pe_ed', TreatmentData>;
}

export const CONSULTATION_I18N: Record<ConsultationLang, ConsultationDictionary> = {
  ms: {
    badge: 'SUITE KONSULTASI KLINIK • MODUL BILIK DOKTOR',
    title: 'Kit Konsultasi Doktor',
    desc: 'Simulasi anatomi interaktif dan fasa pemulihan klinikal bagi membantu pesakit memahami pelan rawatan dengan jelas, tepat dan berasaskan bukti saintifik.',
    patientViewBtn: 'Mod Skrin Pesakit',
    exitPatientViewBtn: 'Kembali ke Mod Doktor',
    sendGuideBtn: 'Hantar Panduan Selepas Rawatan (WhatsApp)',
    langToggleAria: 'Pilih bahasa paparan',
    patientViewBadge: 'PAPARAN PESAKIT (MOD SKRIN PENUH)',
    patientViewHint: 'Skrin ini dioptimumkan untuk penerangan pesakit. Yuran cawangan dan senarai semak dalaman disembunyikan.',
    doctorOnlyBadge: 'ALATAN KHAS DOKTOR & KLINIK',

    stage: {
      topTag: 'SIMULASI ANATOMI & MEKANISME TINDAKAN KLINIKAL',
      phaseScrubberTitle: 'Fasa Kemajuan Klinikal',
      week1Label: 'Minggu 1',
      week6Label: 'Minggu 6',
      week12Label: 'Minggu 12+',
      doctorTip: 'Tunjukkan fasa ini kepada pesakit semasa konsultasi bagi menetapkan jangkaan pemulihan yang realistik dan menyokong kepatuhan rawatan (treatment adherence).',
      patientTip: 'Kemajuan fisiologi berlaku secara berperingkat mengikut tindak balas selular dan biologi badan anda.',
      illustrativeNote: 'Rajah ini adalah simulasi ilustrasi mekanisme tindakan, bukan ukuran mutlak atau jaminan hasil pesakit.',
      evidenceLevelTitle: 'Tahap Bukti Klinikal:'
    },

    tabs: {
      eswt: {
        label: 'Terapi ESWT',
        sub: 'Neovaskularisasi & Aliran Darah'
      },
      kegel: {
        label: 'Kerusi Kegel',
        sub: 'Latihan Otot Pelvis'
      },
      pshot: {
        label: 'Rawatan P-Shot',
        sub: 'Prosedur Regeneratif Berpandu'
      },
      fertility: {
        label: 'Program Kesuburan',
        sub: 'Analisis & Infusi 12 Minggu'
      },
      trt: {
        label: 'Terapi TRT',
        sub: 'Profil & Keseimbangan Hormon'
      },
      pe_ed: {
        label: 'Rehabilitasi PE/ED',
        sub: 'Kawalan Neuromuskular Pelvis'
      }
    },

    checklist: {
      title: 'Senarai Semak Konsultasi Doktor',
      subtitle: 'Format semakan kes harian bagi memastikan konsultasi berstruktur dan telus.',
      items: [
        {
          title: 'Yuran Konsultasi:',
          desc: 'Nyatakan dengan jelas di peringkat awal supaya pesakit memahami struktur kos dan tidak menganggapnya percuma.'
        },
        {
          title: 'Profil & Aduan Utama:',
          desc: 'Catat umur, aduan utama (diagnosis), tempoh gejala, bajet dan lokasi pesakit.'
        },
        {
          title: 'Isu Utama & Kebimbangan:',
          desc: 'Kaji tahap pengetahuan pesakit mengenai rawatan, kebimbangan emosi/psikologi, dan keperluan berbincang bersama pasangan.'
        },
        {
          title: 'Sumber Rujukan (Lead Source):',
          desc: 'Kenal pasti punca rujukan: media sosial, portal web rasmi, billboard atau rujukan pesakit sedia ada.'
        },
        {
          title: 'Koordinasi Operasi & Makmal:',
          desc: 'Untuk kes analisis sperma atau profil hormon, maklumkan pasukan operasi klinik bagi pengaturan penghantaran sampel makmal berjadual.'
        },
        {
          title: 'Panduan Arah & Temujanji Susulan:',
          desc: 'Hantar panduan arah dan parkir kepada pesakit selepas temujanji disahkan dan tetapkan tarikh semakan susulan.'
        }
      ]
    },

    pricing: {
      title: 'Yuran & Pakej Rawatan Cawangan',
      branchLabel: 'Cawangan Klinik:',
      loading: 'Memuatkan maklumat yuran cawangan...',
      notConfigured: 'Yuran belum dikonfigurasi untuk cawangan ini. Sila hubungi pentadbir sistem.',
      consultationFee: 'Yuran Konsultasi Doktor',
      onlineBooking: 'Tempahan Dalam Talian',
      validDate: 'Sah sehingga'
    },

    dispatchModal: {
      title: 'Hantar Panduan Selepas Rawatan (WhatsApp)',
      patientNameLabel: 'Nama Penuh Pesakit:',
      patientNamePlaceholder: 'cth: Tuan Ahmad Khairi',
      phoneLabel: 'Nombor Telefon WhatsApp:',
      phonePlaceholder: 'cth: 0123456789',
      dateLabel: 'Tarikh Temujanji Susulan (Pilihan):',
      datePlaceholder: 'cth: 24 Oktober 2026, 11:00 AM',
      readyTitle: 'Mesej WhatsApp Bersedia untuk Dihantar:',
      openWaBtn: 'Buka WhatsApp & Hantar Mesej ↗',
      closeBtn: 'Tutup',
      generateBtn: 'Jana Pautan WhatsApp',
      generatingBtn: 'Menjana...',
      nameWarning: 'Sila masukkan nama pesakit.',
      successToast: 'Panduan penjagaan digital berjaya dijana.',
      errorDefault: 'Kami tidak dapat menjana panduan penjagaan. Sila cuba lagi.'
    },

    disclaimer: {
      text: 'Semua rajah, data fasa pemulihan dan penerangan klinikal disediakan sebagai bahan bantuan komunikasi doktor-pesakit. Pelan rawatan sebenar ditentukan secara individu oleh doktor berdaftar.',
      reviewStamp: 'Disemak selaras dengan Akta Iklan Ubat 1956 & Panduan Lembaga Iklan Ubat (LIU/MAB). Tarikh semakan: Oktober 2026.'
    },

    referencesSection: {
      title: 'Rujukan & Garis Panduan Klinikal Antarabangsa',
      subtitle: 'Garis panduan rasmi EAU, Endocrine Society, WHO dan ISSM sebagai asas amalan perubatan berasaskan bukti (Evidence-Based Medicine).',
      badge: '6 Garis Panduan Antarabangsa',
      toggleOpen: 'Buka Senarai Rujukan & Garis Panduan Klinikal',
      toggleClose: 'Tutup Rujukan Garis Panduan',
      directorNoticeTitle: 'Nota Penasihat Pengarah Perubatan (Medical Director Advisory)',
      directorNoticeText: 'Protokol klinikal SuamiSihat dibangunkan berpandukan garis panduan amalan antarabangsa terkini. Rawatan sebenar sentiasa disesuaikan mengikut penilaian klinikal individu, profil diagnostik darah dan persetujuan termaklum pesakit.',
      allFilterLabel: 'Semua Garis Panduan (6)',
      currentFilterLabel: 'Rujukan Rawatan Semasa',
      jumpToCitationLabel: 'Lompat ke rujukan',
      viewGuidelineBtn: 'Buka Garis Panduan Rasmi',
      references: [
        {
          id: 1,
          treatmentId: 'eswt',
          citation: 'EAU Guidelines on Sexual and Reproductive Health (2024 Edition)',
          guidelineBody: 'European Association of Urology (EAU)',
          year: '2024',
          evidenceLevel: 'Level 1b / Gred Rekomendasi B',
          recommendation: 'Terapi Gelombang Kejutan Luar Badan Berkeamatan Rendah (Li-ESWT) diiktiraf sebagai modaliti pemulihan mikroperedaran vaskular yang merangsang neovaskularisasi melalui pelepasan faktor pertumbuhan endothelial (VEGF & eNOS) bagi pesakit disfungsi ereksi vaskulogenik ringan-ke-sederhana serta pesakit yang kurang respons terhadap perencat PDE5.',
          clinicalApplication: 'Protokol SuamiSihat menggunakan kepadatan aliran tenaga terkawal (0.09 mJ/mm²), 1,500–2,000 denyutan setiap sesi merentasi korpus kavernosum dan krura tanpa sebarang anestesia atau tempoh henti aktiviti (zero downtime).',
          reviewMarker: 'Disahkan selaras panduan amalan klinikal EAU 2024 untuk rawatan andrologi vaskulogenik.',
          url: 'https://uroweb.org/guidelines/sexual-and-reproductive-health'
        },
        {
          id: 2,
          treatmentId: 'kegel',
          citation: 'Pelvic Floor Muscle Training for Male Sexual Dysfunction & Post-Micturition Dribble (Dorey et al., BJU Int; Cochrane Database Review)',
          guidelineBody: 'International Continence Society (ICS) / Cochrane Reviews',
          year: '2021 / 2024',
          evidenceLevel: 'Level 1a / Gred Rekomendasi A',
          recommendation: 'Latihan otot dasar pelvis (PFMT) secara konsisten dan berstruktur terbukti secara saintifik meningkatkan tekanan oklusi intrakavernosa melalui hipertrofi otot bulbocavernosus dan ischiocavernosus, di samping mengawal titisan air kencing pasca-miksi dan memantapkan kawalan refleks ejakulasi.',
          clinicalApplication: 'Program 12 minggu mengintegrasikan stimulasi elektromagnetik intensiti tinggi (HIFEM) bersama latihan kadens pernafasan diafragma (kontraksi 3–7 saat) untuk memaksimumkan pembentukan memori neuromuskular berkekalan.',
          reviewMarker: 'Standard amalan klinikal bukan invasif dengan profil keselamatan tertinggi.',
          url: 'https://www.cochranelibrary.com/'
        },
        {
          id: 3,
          treatmentId: 'pshot',
          citation: 'ESSM Consensus Statement on Platelet-Rich Plasma in Sexual Medicine & Malaysian Medical Advertising Code (Medicines Act 1956)',
          guidelineBody: 'European Society for Sexual Medicine (ESSM) / Lembaga Iklan Ubat (LIU) KKM',
          year: '2023 / 2024',
          evidenceLevel: 'Investigational / Protokol Terapi Selular Autologous',
          recommendation: 'Plasma Kaya Platelet (PRP) autologous merupakan terapi bio-regeneratif menggunakan faktor pertumbuhan terkonsentrasi pesakit sendiri (PDGF, VEGF, EGF, TGF-β). Garis panduan etika perubatan mewajibkan prosedur aseptik ketat dan informed consent tanpa sebarang jaminan hasil mutlak atau tuntutan komersial melampau.',
          clinicalApplication: 'Disediakan secara autologous dalam keadaan aseptik ketat di bilik rawatan klinik; tiada bahan asing dan risiko penolakan biologi atau alahan adalah sifar.',
          reviewMarker: '[Clinical Review Marker: Rawatan autologous regeneratif. Memerlukan penilaian kesesuaian klinikal individu dan borang keizinan bertulis pesakit.]',
          url: 'https://www.essm.org/'
        },
        {
          id: 4,
          treatmentId: 'fertility',
          citation: 'WHO Laboratory Manual for the Examination and Processing of Human Semen (6th Edition, 2021) & AUA/ASRM Guidelines',
          guidelineBody: 'World Health Organization (WHO)',
          year: '2021',
          evidenceLevel: 'Level 1a Global Diagnostic Benchmark',
          recommendation: 'Menetapkan had rujukan persentil ke-5 terendah (lower 5th percentile limits) bagi analisis air mani piawai: Kepekatan (>= 16 juta/mL), Motiliti Progresif (>= 30%), Vitaliti (>= 54%), dan Morfologi Ketat Kruger (>= 4%). Kitaran biologi spermatogenesis mengambil purata 74 hari (10–12 minggu).',
          clinicalApplication: 'Penilaian diagnostik berjadual pada Garis Asas (Minggu 1) dan Ulangan (Minggu 12); protokol infusi nutraseutikal (NAD+ / CoQ10) menyasarkan perlindungan antioksidan dan integriti pembahagian sel sperma.',
          reviewMarker: 'Piawaian rujukan diagnostik global rasmi WHO 2021 bagi penilaian kesuburan lelaki.',
          url: 'https://www.who.int/publications/i/item/9789240030787'
        },
        {
          id: 5,
          treatmentId: 'trt',
          citation: 'Testosterone Therapy in Men with Hypogonadism: An Endocrine Society Clinical Practice Guideline (Bhasin et al., JCEM) & EAU 2024',
          guidelineBody: 'The Endocrine Society & European Association of Urology (EAU)',
          year: '2018 / 2024',
          evidenceLevel: 'Level 1a Garis Panduan Amalan Klinikal',
          recommendation: 'Diagnosis hipogonadisme memerlukan kehadiran simptom klinikal disahkan oleh sekurang-kurangnya dua ujian serum jumlah testosteron pagi berpuasa yang rendah (< 9.2 nmol/L atau 300 ng/dL). Terapi menyasarkan paras fisiologi pertengahan normal (14–25 nmol/L) dengan pemantauan hematokrit (HCT < 54%) dan PSA berjadual.',
          clinicalApplication: 'Protokol pemantauan keselamatan 5 peringkat (Baseline, Bulan 1, 3, 6, 12); dos dipantau rapi oleh doktor bagi mengelakkan polisitemia sekunder dan mengekalkan kesihatan metabolik serta seksual.',
          reviewMarker: 'Garis panduan rasmi antarabangsa Endocrine Society & EAU dengan pengawasan keselamatan berjadual.',
          url: 'https://academic.oup.com/jcem/article/103/5/1715/4939465'
        },
        {
          id: 6,
          treatmentId: 'pe_ed',
          citation: 'ISSM Guidelines for the Pharmacotherapy & Psychosexual Management of Premature Ejaculation & EAU 2024',
          guidelineBody: 'International Society for Sexual Medicine (ISSM) / EAU',
          year: '2024',
          evidenceLevel: 'Level 1b Garis Panduan Multimodal',
          recommendation: 'Garis panduan mengesyorkan pengurusan multimodal yang menyepadukan kawalan farmakoterapi bertindak pendek (Short-acting SSRI/PDE5i mengikut keperluan), modulasi relaksasi otot lantai pelvis (mengurangkan kekejangan bulbocavernosus), dan latihan desensitisasi tingkah laku (Stop-Start dan ritma nafas vagal).',
          clinicalApplication: 'Pesakit dibimbing secara berperingkat untuk mengesan ambang keterujaan 7/10 sebelum titik klimaks refleks yang tidak dapat dielakkan, membina kawalan neuromuskular berkekalan tanpa pergantungan berpanjangan.',
          reviewMarker: 'Protokol multimodal komprehensif mengikut standard amalan antarabangsa ISSM dan EAU.',
          url: 'https://www.issm.info/'
        }
      ]
    },

    treatments: {
      eswt: {
        id: 'eswt',
        name: 'Terapi Gelombang Kejutan (ESWT)',
        shortName: 'ESWT Shockwave',
        tagline: 'Neovaskularisasi & Pengaliran Darah Mikro',
        title: 'Pemulihan Vaskularisasi & Pengaliran Darah Mikro',
        description: 'Gelombang akustik berintensiti rendah merangsang faktor pertumbuhan salur darah (VEGF), menguraikan mikrokalsifikasi dan menyokong pembentukan kapilari darah baharu secara semulajadi.',
        targetPatient: 'Pesakit dengan disfungsi ereksi vaskulogenik, penurunan pengaliran darah penis, atau pemulihan tisu.',
        contraindications: 'Gangguan pembekuan darah aktif, penggunaan antikoagulan dos tinggi, jangkitan aktif atau keganasan pelvis.',
        evidence: {
          level: 'Investigational / Selected Patients',
          levelLabel: 'Pilihan Terpilih / Investigasi Terkawal',
          citation: 'EAU Guidelines on Sexual and Reproductive Health (Li-ESWT for Vasculogenic ED)',
          clinicalNote: 'Gelombang kejutan berintensiti rendah (Li-ESWT) disyorkan untuk kumpulan pesakit terpilih dengan faktor vaskular.',
          reviewMarker: 'Parameter klinikal tipikal 0.09 mJ/mm² berasaskan protokol penyelidikan klinikal antarabangsa.',
          refId: 1
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Penilaian Asas & Rangsangan Selular (Minggu 1-2)',
            highlight: 'Memulakan pengaktifan metabolik tisu tanpa invasif.',
            details: 'Sesi permulaan pada paras tenaga rendah terkawal (0.09 mJ/mm²). Sel endotelium mula dirangsang untuk melepaskan molekul nitrik oksida (NO).',
            metric: 'Pengaktifan Tisu Asas'
          },
          {
            phase: 2,
            title: 'Fasa 2: Neovaskularisasi & Pembentukan Kapilari (Minggu 3-6)',
            highlight: 'Pembentukan jaringan salur darah mikro baharu (Angiogenesis).',
            details: 'Peningkatan perfusi darah beroksigen ke tisu spons korpus kavernosum bagi menyokong respons ereksi semulajadi.',
            metric: 'Perfusi Vaskular Bertambah'
          },
          {
            phase: 3,
            title: 'Fasa 3: Pengukuhan Struktur & Ketahanan (Minggu 7-10)',
            highlight: 'Penyatuan serat kolagen dan pemulihan elastisiti tisu vaskular.',
            details: 'Ketegangan dan daya tahan ereksi mencapai kestabilan lebih tinggi dengan pengurangan tempoh latensi pemulihan.',
            metric: 'Kestabilan Prestasi Tisu'
          },
          {
            phase: 4,
            title: 'Fasa 4: Penyelenggaraan Jangka Panjang (Minggu 12+)',
            highlight: 'Mengekalkan kesihatan endotelium dan vaskular secara berterusan.',
            details: 'Semakan berkala setiap 6 bulan bersama bimbingan senaman lantai pelvis bagi menyokong aliran darah jangka panjang.',
            metric: 'Sasaran Klinikal Tercapai'
          }
        ]
      },

      kegel: {
        id: 'kegel',
        name: 'Kerusi Kegel (Latihan Pelvis Elektromagnetik)',
        shortName: 'Kerusi Kegel',
        tagline: 'Latihan Otot Dasar Pelvis Berpandu',
        title: 'Pengukuhan Otot Dasar Pelvis & Kawalan Ejakulasi',
        description: 'Teknologi rangsangan elektromagnetik intensiti tinggi (HIFEM) merangsang pengecutan supramaksimal otot levator ani dan bulbocavernosus bagi menguatkan kawalan pelvis.',
        targetPatient: 'Lelaki yang mengalami kelemahan otot pelvis, ejakulasi pramatang, atau pemulihan fungsi kontinens.',
        contraindications: 'Implan logam/perentak jantung (pacemaker), implan koklea, jangkitan akut saluran kencing.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'Disokong Garis Panduan Klinikal',
          citation: 'Pelvic Floor Muscle Training for Men with Erectile & Ejaculatory Dysfunction (Trial Evidence & CPG)',
          clinicalNote: 'Latihan otot dasar panggul terbukti secara klinikal memperbaiki daya tahan bulbocavernosus dan sokongan sfinkter.',
          reviewMarker: 'Protokol latihan berjadual dipantau oleh doktor bertauliah.',
          refId: 2
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Pengenalan Otot & Kesedaran Neuromuskular (Sesi 1-2)',
            highlight: 'Mengenal pasti otot dasar pelvis dan teknik pengecutan tepat.',
            details: 'Pesakit dibimbing mengenali otot yang disasarkan dan merasai perbezaan antara pengecutan lantai pelvis dan otot abdomen.',
            metric: 'Kesedaran Otot Asas'
          },
          {
            phase: 2,
            title: 'Fasa 2: Pembinaan Ketahanan Otot (Sesi 3-6)',
            highlight: 'Meningkatkan ketahanan dan kawalan motor secara beransur-ansur.',
            details: 'Tahap intensiti dinaikkan mengikut toleransi fisiologi pesakit; panduan latihan di rumah menyokong kelangsungan kemajuan.',
            metric: 'Ketahanan Otot Meningkat'
          },
          {
            phase: 3,
            title: 'Fasa 3: Pengukuhan & Kawalan Pernafasan (Sesi 7-10)',
            highlight: 'Menggabungkan kekuatan otot dengan ritma kawalan rangsangan.',
            details: 'Fokus kepada konsistensi pengawalan refleks ejakulasi dan penyesuaian program bersama doktor mengikut tindak balas individu.',
            metric: 'Kawalan Konsisten'
          },
          {
            phase: 4,
            title: 'Fasa 4: Penyelenggaraan Jangka Panjang (Selepas Pakej)',
            highlight: 'Mengekalkan tonus otot dan memori neuromuskular.',
            details: 'Sesi penyelenggaraan berkala dan amalan senaman harian disyorkan untuk mengekalkan fungsi otot optimum.',
            metric: 'Rutin Penyelenggaraan'
          }
        ]
      },

      pshot: {
        id: 'pshot',
        name: 'Rawatan Regeneratif (P-Shot / PRP)',
        shortName: 'P-Shot PRP',
        tagline: 'Terapi Plasma Kaya Platelet Berpandu Doktor',
        title: 'Rawatan Regeneratif Autologous Selepas Penilaian Klinikal',
        description: 'Prosedur pemindahan plasma kaya platelet (PRP) autologous daripada darah pesakit sendiri, disediakan secara steril dan ditadbir oleh doktor berdaftar.',
        targetPatient: 'Pesakit dengan penurunan kualiti tisu vaskular atau kesuburan selular selepas saringan darah lengkap.',
        contraindications: 'Trombositopenia (platlet rendah), sindrom disfungsi platlet, sepsis sistemik, keganasan tempatan.',
        evidence: {
          level: 'Investigational / Selected Patients',
          levelLabel: 'Prosedur Regeneratif Terkawal',
          citation: 'Autologous Platelet-Rich Plasma in Sexual Medicine (Clinical Evaluation & Consent Standards)',
          clinicalNote: 'Rawatan berasaskan persetujuan termaklum pesakit (informed consent) tanpa sebarang tuntutan jaminan mutlak.',
          reviewMarker: 'Status LIU/MAB: Tiada tuntutan hasil automatik; penekanan kepada protokol prosedur selamat.',
          refId: 3
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Konsultasi & Ujian Profil Darah Lengkap (Minggu 1)',
            highlight: 'Penilaian menyeluruh sebelum sebarang keputusan prosedur.',
            details: 'Doktor menyemak sejarah klinikal, kiraan platelet, dan fungsi organ bagi menentukan kesesuaian prosedur.',
            metric: 'Penilaian Kesesuaian Klinikal'
          },
          {
            phase: 2,
            title: 'Fasa 2: Persetujuan Termaklum & Prosedur Bersih (Minggu 2-3)',
            highlight: 'Penerangan telus tentang manfaat fisiologi dan jangkaan pemulihan.',
            details: 'Prosedur sentrifugasi steril dan pentadbiran klinikal dijalankan dalam persekitaran aseptik oleh doktor berdaftar.',
            metric: 'Persetujuan Termaklum Dicapai'
          },
          {
            phase: 3,
            title: 'Fasa 3: Fasa Tindak Balas & Pemulihan Selular (Minggu 4-8)',
            highlight: 'Pembebasan faktor pertumbuhan selular (PDGF, VEGF, TGF-β).',
            details: 'Pesakit mengikut panduan penjagaan selepas rawatan dan melaporkan tindak balas semasa semakan susulan.',
            metric: 'Pemantauan Respons Tisu'
          },
          {
            phase: 4,
            title: 'Fasa 4: Semakan Susulan & Penilaian Hasil (Minggu 12+)',
            highlight: 'Semakan objektif bersama doktor bagi menentukan pelan lanjutan.',
            details: 'Doktor menilai kemajuan klinikal dan membincangkan keperluan pelan sokongan gaya hidup atau sesi ulangan.',
            metric: 'Semakan Kemajuan 12-Minggu'
          }
        ]
      },

      fertility: {
        id: 'fertility',
        name: 'Program Kesuburan Lelaki 12-Minggu',
        shortName: 'Kesuburan Lelaki',
        tagline: 'Analisis Sperma & Infusi Nutraseutikal Berpandu',
        title: 'Program Komprehensif Spermatogenesis 12-Minggu',
        description: 'Program berstruktur 12 minggu yang merangkumi analisis parameter sperma berpandukan manual WHO serta protokol sokongan nutrisi/infusi selular dipantau doktor.',
        targetPatient: 'Lelaki yang merancang zuriat dengan isu kiraan, motiliti, mobiliti atau morfologi sperma bawah paras rujukan.',
        contraindications: 'Ketidakseimbangan hormon primer yang tidak disaring, penyakit buah pinggang/hati tahap akhir.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'Berasaskan Parameter Makmal WHO',
          citation: 'WHO Laboratory Manual for the Examination and Processing of Human Semen (6th Edition, 2021)',
          clinicalNote: 'Kitaran spermatogenesis manusia mengambil masa kira-kira 74 hari ditambah tempoh transit epididimis.',
          reviewMarker: 'Protokol dalaman Program Kesuburan diselaraskan mengikut tempoh kitaran biologi sperma 12 minggu.',
          refId: 4
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Analisis Semen Asas & Profil Hormon (Minggu 1)',
            highlight: 'Menetapkan garis dasar kuantitatif bagi kiraan, motiliti dan morfologi.',
            details: 'Sampel dianalisis mengikut piawaian WHO. Saringan darah profil hormon pembiakan (FSH, LH, Prolaktin, Total T) diatur.',
            metric: 'Garis Asas Makmal Ditetapkan'
          },
          {
            phase: 2,
            title: 'Fasa 2: Infusi Berjadual & Sokongan Antioksidan (Minggu 2-6)',
            highlight: 'Mengurangkan stres oksidatif dan menyokong respirasi mitokondria.',
            details: 'Pesakit menerima infusi nutraseutikal berjadual (NAD+ / CoQ10) bersama pengubahsuaian faktor gaya hidup.',
            metric: 'Pematuhan Program Infusi'
          },
          {
            phase: 3,
            title: 'Fasa 3: Pemantauan Pertengahan & Saringan Gaya Hidup (Minggu 7-9)',
            highlight: 'Menilai toleransi dan meminimumkan pendedahan haba/toksin.',
            details: 'Doktor menyemak corak tidur, kawalan berat badan, pemakanan, dan pemberhentian merokok atau vape.',
            metric: 'Semakan Pertengahan Kitaran'
          },
          {
            phase: 4,
            title: 'Fasa 4: Analisis Sperma Ulangan Pasca-Kitaran (Minggu 12)',
            highlight: 'Penilaian objektif terhadap sperma generasi baharu.',
            details: 'Ujian makmal ulangan dijalankan selepas selesainya kitaran spermatogenesis 74-84 hari bagi membandingkan kemajuan.',
            metric: 'Penilaian Pasca-Spermatogenesis'
          }
        ]
      },

      trt: {
        id: 'trt',
        name: 'Terapi Penggantian Testosteron (TRT)',
        shortName: 'Terapi TRT',
        tagline: 'Pengoptimuman Profil Hormon & Kesejahteraan Metabolik',
        title: 'Pengoptimuman Profil Hormon Berasaskan Ujian Klinikal',
        description: 'Pelan perubatan berpandukan ujian darah makmal bagi mengembalikan paras testosteron lelaki hipogonadisme ke paras fisiologi normal yang selamat.',
        targetPatient: 'Lelaki dengan gejala klinikal defisiensi androgen yang disahkan melalui ujian darah pagi berulang.',
        contraindications: 'Kanser prostat atau kanser payudara lelaki aktif, hematokrit > 54%, kegagalan jantung tidak terkawal, keinginan kesuburan jangka pendek.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'Garis Panduan Endocrine Society & EAU',
          citation: 'Endocrine Society 2018 Testosterone Therapy Guideline (Bhasin et al.) & EAU Hypogonadism Section',
          clinicalNote: 'Diagnosis memerlukan kombinasi simptom klinikal dan paras testosteron pagi rendah yang disahkan pada sekurang-kurangnya 2 ujian berasingan.',
          reviewMarker: 'Paras rujukan diagnostik: < 9.2 - 12 nmol/L. Sasaran terapi ialah paras fisiologi pertengahan (14-25 nmol/L), bukan tuntutan "optimum berlebihan".',
          refId: 5
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Ujian Profil Darah & Penentuan Dos Selamat (Minggu 1-2)',
            highlight: 'Pengesahan diagnosis melalui Total T, Free T, PSA, Profil Lipid & Hematokrit.',
            details: 'Doktor memeriksa fungsi hepar, renal, dan kepekatan sel darah merah (Hct) sebelum merangka preskripsi dos fisiologi terkawal.',
            metric: 'Pengesahan Diagnostik Asas'
          },
          {
            phase: 2,
            title: 'Fasa 2: Pemulihan Tenaga & Kualiti Tidur (Minggu 3-6)',
            highlight: 'Penurunan keletihan kronik dan kestabilan mood serta fokus mental.',
            details: 'Paras androgen darah mula stabil dalam julat fisiologi normal. Pesakit melaporkan tidur lebih lena dan daya tahan fizikal meningkat.',
            metric: 'Pemulihan Tenaga Fisiologi'
          },
          {
            phase: 3,
            title: 'Fasa 3: Komposisi Badan & Sensitiviti Insulin (Minggu 7-10)',
            highlight: 'Pengurangan lemak viseral berperingkat dan sokongan jisim otot tanpa lemak.',
            details: 'Metabolisme glukosa dan lipid bertambah baik. Gabungan latihan rintangan asas mempercepatkan pemulihan metabolisme.',
            metric: 'Kemajuan Komposisi Badan'
          },
          {
            phase: 4,
            title: 'Fasa 4: Pemantauan Darah 12-Minggu & Penyelenggaraan (Minggu 12+)',
            highlight: 'Ujian darah keselamatan susulan bagi memantau profil kardiovaskular.',
            details: 'Ujian ulangan paras hematokrit, PSA, dan lipid darah bagi memastikan terapi kekal selamat dalam julat terapeutik klinikal.',
            metric: 'Pemantauan Keselamatan 12-Minggu'
          }
        ]
      },

      pe_ed: {
        id: 'pe_ed',
        name: 'Rehabilitasi Prestasi Seksual Lelaki (PE/ED)',
        shortName: 'Rehabilitasi PE/ED',
        tagline: 'Pendekatan Klinikal Bersepadu & Kawalan Neuromuskular',
        title: 'Integrasi Fisioterapi Pelvis & Modulasi Neuro-Sensori',
        description: 'Gabungan fisioterapi lantai pelvis, modulasi refleks neuro-sensori, dan panduan tingkah laku bagi memulihkan kawalan ereksi dan latensi ejakulasi.',
        targetPatient: 'Pesakit dengan kebimbangan prestasi, ejakulasi pramatang primer/sekunder, atau disfungsi ereksi bercampur.',
        contraindications: 'Patologi saraf tulang belakang akut yang belum dinilai oleh pakar neurologi.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'ISSM & EAU Guideline Practice',
          citation: 'ISSM / EAU Guidelines for the Management of Premature Ejaculation & Erectile Dysfunction',
          clinicalNote: 'Menggabungkan pendekatan farmakoterapi berdaftar, latihan tingkah laku (behavioural conditioning) dan pengukuhan dasar pelvis.',
          reviewMarker: 'Pendekatan holistik tanpa janji "automatik" atau "kekal seumur hidup tanpa penyelenggaraan".',
          refId: 6
        },
        phases: [
          {
            phase: 1,
            title: 'Fasa 1: Pemetaan Sensori & Kekuatan Otot Pelvis (Minggu 1-2)',
            highlight: 'Mengenal pasti otot bulbocavernosus dan ambang rangsangan saraf.',
            details: 'Doktor menguji kepekaan sensori dan melatih teknik pengecutan otot dasar pelvis bagi mengurangkan keresahan prestasi.',
            metric: 'Kesedaran Neuromuskular'
          },
          {
            phase: 2,
            title: 'Fasa 2: Kawalan Ambang & Pernafasan Ritmik (Minggu 3-6)',
            highlight: 'Meningkatkan kawalan ambang rangsangan secara berperingkat.',
            details: 'Latihan teknik desensitisasi beransur dan kawalan pernafasan diafragma bagi mengelakkan lonjakan refleks ejakulasi terlalu pantas.',
            metric: 'Peningkatan Kawalan Ambang'
          },
          {
            phase: 3,
            title: 'Fasa 3: Pengukuhan Respons & Kestabilan Psikologi (Minggu 7-10)',
            highlight: 'Mengekalkan ketegangan yang stabil tanpa keresahan prestasi.',
            details: 'Kombinasi vaskularisasi yang sihat dan pengurusan kebimbangan menyokong kestabilan tindak balas intim yang konsisten.',
            metric: 'Keyakinan & Kestabilan Respons'
          },
          {
            phase: 4,
            title: 'Fasa 4: Penyelenggaraan & Kestabilan Berterusan (Minggu 12+)',
            highlight: 'Pengukuhan kawalan refleks melalui latihan berterusan.',
            details: 'Hasil rawatan diperkukuh melalui memori otot dan panduan gaya hidup dengan sokongan susulan berkala oleh doktor.',
            metric: 'Kawalan Prestasi Stabil'
          }
        ]
      }
    }
  },

  en: {
    badge: 'IN-CLINIC CONSULTATION SUITE • DOCTOR’S ROOM MODULE',
    title: 'Consultation kit',
    desc: 'Interactive anatomical simulation and clinical recovery phases to help patients understand treatment plans with clarity, transparency, and evidence-based medicine.',
    patientViewBtn: 'Patient View Mode',
    exitPatientViewBtn: 'Exit Patient View',
    sendGuideBtn: 'Send Post-Care Guide (WhatsApp)',
    langToggleAria: 'Select display language',
    patientViewBadge: 'PATIENT PRESENTATION MODE',
    patientViewHint: 'Optimized for patient discussions across the desk. Internal branch fees and clinic checklists are hidden.',
    doctorOnlyBadge: 'CLINICAL TOOLKIT & CLINIC OPERATIONS',

    stage: {
      topTag: 'ANATOMICAL SIMULATION & MECHANISM OF ACTION',
      phaseScrubberTitle: 'Clinical Progress Phases',
      week1Label: 'Week 1',
      week6Label: 'Week 6',
      week12Label: 'Week 12+',
      doctorTip: 'Share this timeline with the patient during consultation to establish realistic recovery expectations and support treatment adherence.',
      patientTip: 'Physiological progress occurs gradually based on cellular regeneration and biological healing cycles.',
      illustrativeNote: 'This diagram is an illustrative simulation of biological mechanism, not a scaled diagnostic scan or guaranteed result.',
      evidenceLevelTitle: 'Level of Clinical Evidence:'
    },

    tabs: {
      eswt: {
        label: 'ESWT Shockwave',
        sub: 'Neovascularization & Blood Flow'
      },
      kegel: {
        label: 'Kegel Chair',
        sub: 'Pelvic Floor Training'
      },
      pshot: {
        label: 'P-Shot Therapy',
        sub: 'Doctor-Led Regenerative Care'
      },
      fertility: {
        label: 'Male Fertility',
        sub: '12-Week Spermatogenesis Cycle'
      },
      trt: {
        label: 'TRT Therapy',
        sub: 'Endocrine & Metabolic Profile'
      },
      pe_ed: {
        label: 'PE/ED Rehab',
        sub: 'Neuromuscular Control'
      }
    },

    checklist: {
      title: 'Consultation Checklist',
      subtitle: 'Standardized daily new-case clinical review workflow for transparent, structured patient consultations.',
      items: [
        {
          title: 'Consultation Fee:',
          desc: 'State clearly up front so the patient has full fee transparency and does not assume services are complimentary.'
        },
        {
          title: 'Patient Profile & Chief Complaint:',
          desc: 'Record patient age, primary clinical complaint, symptom duration, budget, and geographic location.'
        },
        {
          title: 'Knowledge & Concerns:',
          desc: 'Evaluate patient baseline understanding, emotional/performance concerns, and need for partner discussion.'
        },
        {
          title: 'Lead Source Attribution:',
          desc: 'Identify referral source: official digital portals, verified social media channels, billboard, or word-of-mouth.'
        },
        {
          title: 'Laboratory & Operations Logistics:',
          desc: 'For sperm analysis or endocrine profiles, alert clinic operations to schedule timely laboratory courier pickup.'
        },
        {
          title: 'Directions & Follow-up Scheduling:',
          desc: 'Dispatch clinic location and parking details once appointment is locked, and confirm scheduled follow-up check date.'
        }
      ]
    },

    pricing: {
      title: 'Branch Pricing & Treatment Packages',
      branchLabel: 'Clinic Branch:',
      loading: 'Loading branch pricing...',
      notConfigured: 'Pricing is not configured for this branch. Please contact system administration.',
      consultationFee: 'Doctor Consultation Fee',
      onlineBooking: 'Online Booking',
      validDate: 'Valid until'
    },

    dispatchModal: {
      title: 'Send Post-Care Guide (WhatsApp)',
      patientNameLabel: 'Patient Full Name:',
      patientNamePlaceholder: 'e.g. Mr. Ahmad Khairi',
      phoneLabel: 'WhatsApp Phone Number:',
      phonePlaceholder: 'e.g. 0123456789',
      dateLabel: 'Follow-Up Date (Optional):',
      datePlaceholder: 'e.g. 24 October 2026, 11:00 AM',
      readyTitle: 'WhatsApp Message Ready to Dispatch:',
      openWaBtn: 'Open WhatsApp & Send Message ↗',
      closeBtn: 'Close',
      generateBtn: 'Generate WhatsApp Link',
      generatingBtn: 'Generating...',
      nameWarning: 'Please enter patient name.',
      successToast: 'Digital care guide generated successfully.',
      errorDefault: 'Could not generate care guide. Please try again.'
    },

    disclaimer: {
      text: 'All diagrams, phase timelines, and clinical mechanism explanations are educational aids for physician-patient communication. Individual treatment plans are determined following medical examination.',
      reviewStamp: 'Reviewed in compliance with the Medicines (Advertisement and Sale) Act 1956 and Medicine Advertisements Board (LIU/MAB) guidelines. Review date: October 2026.'
    },

    referencesSection: {
      title: 'International Clinical Guidelines & Medical References',
      subtitle: 'Official guidelines from EAU, Endocrine Society, WHO, and ISSM serving as the foundation of evidence-based clinical practice.',
      badge: '6 International Guidelines',
      toggleOpen: 'Expand Clinical Guidelines & References',
      toggleClose: 'Collapse Clinical Guidelines',
      directorNoticeTitle: 'Medical Director Advisory Notice',
      directorNoticeText: 'SuamiSihat clinical protocols are formulated in accordance with the latest international peer-reviewed guidelines. Specific clinical interventions are always tailored based on in-person physician examination, diagnostic blood work, and informed patient consent.',
      allFilterLabel: 'All Guidelines (6)',
      currentFilterLabel: 'Current Treatment Reference',
      jumpToCitationLabel: 'Jump to citation',
      viewGuidelineBtn: 'Open Official Guideline',
      references: [
        {
          id: 1,
          treatmentId: 'eswt',
          citation: 'EAU Guidelines on Sexual and Reproductive Health (2024 Edition)',
          guidelineBody: 'European Association of Urology (EAU)',
          year: '2024',
          evidenceLevel: 'Level 1b / Recommendation Grade B',
          recommendation: 'Low-Intensity Extracorporeal Shockwave Therapy (Li-ESWT) is recognized as a restorative microvascular modality that triggers neo-angiogenesis via the release of vascular endothelial growth factors (VEGF & eNOS) in mild-to-moderate vasculogenic erectile dysfunction and PDE5i partial non-responders.',
          clinicalApplication: 'SuamiSihat protocol utilizes a calibrated energy flux density (0.09 mJ/mm²), 1,500–2,000 pulses per session delivered across the penile shaft and crura with no local anesthesia or recovery downtime required.',
          reviewMarker: 'Validated in accordance with EAU 2024 clinical practice guidelines for vasculogenic andrology.',
          url: 'https://uroweb.org/guidelines/sexual-and-reproductive-health'
        },
        {
          id: 2,
          treatmentId: 'kegel',
          citation: 'Pelvic Floor Muscle Training for Male Sexual Dysfunction & Post-Micturition Dribble (Dorey et al., BJU Int; Cochrane Database Review)',
          guidelineBody: 'International Continence Society (ICS) / Cochrane Reviews',
          year: '2021 / 2024',
          evidenceLevel: 'Level 1a / Recommendation Grade A',
          recommendation: 'Consistent and structured pelvic floor muscle training (PFMT) is scientifically proven to elevate intracavernosal occlusion pressure via bulbocavernosus and ischiocavernosus muscle hypertrophy, actively resolving post-micturition dribble and stabilizing ejaculatory reflex control.',
          clinicalApplication: '12-week phased protocol combines high-intensity electromagnetic stimulation (HIFEM) with diaphragmatic breath synchronization (3–7s contraction hold) to optimize long-term neuromuscular memory.',
          reviewMarker: 'Standard non-invasive clinical practice with highest safety profile.',
          url: 'https://www.cochranelibrary.com/'
        },
        {
          id: 3,
          treatmentId: 'pshot',
          citation: 'ESSM Consensus Statement on Platelet-Rich Plasma in Sexual Medicine & Malaysian Medical Advertising Code (Medicines Act 1956)',
          guidelineBody: 'European Society for Sexual Medicine (ESSM) / Medicine Advertisements Board (LIU) MOH',
          year: '2023 / 2024',
          evidenceLevel: 'Investigational / Autologous Cellular Therapy Protocol',
          recommendation: 'Autologous Platelet-Rich Plasma (PRP) represents a biological regenerative therapy releasing concentrated endogenous growth factors (PDGF, VEGF, EGF, TGF-β). Ethical medical guidelines require strict aseptic delivery and comprehensive informed consent without commercial cure claims.',
          clinicalApplication: 'Prepared autologously under strict in-clinic aseptic conditions using calibrated G-force centrifugation; zero foreign additives and zero risk of biological rejection or allergic sensitization.',
          reviewMarker: '[Clinical Review Marker: Autologous regenerative therapy. Requires personalized clinical assessment and written informed patient consent.]',
          url: 'https://www.essm.org/'
        },
        {
          id: 4,
          treatmentId: 'fertility',
          citation: 'WHO Laboratory Manual for the Examination and Processing of Human Semen (6th Edition, 2021) & AUA/ASRM Guidelines',
          guidelineBody: 'World Health Organization (WHO)',
          year: '2021',
          evidenceLevel: 'Level 1a Global Diagnostic Benchmark',
          recommendation: 'Establishes the lower 5th percentile reference distribution limits for standardized semen analysis: Concentration (>= 16 M/mL), Progressive Motility (>= 30%), Vitality (>= 54%), and Kruger Strict Morphology (>= 4%). The human spermatogenesis biological cycle spans an average of 74 days (10–12 weeks).',
          clinicalApplication: 'Scheduled diagnostic tracking at Baseline (Week 1) and Post-Cycle (Week 12); physician-monitored nutraceutical infusions (NAD+ / CoQ10) protect meiotic germ cell division against oxidative stress.',
          reviewMarker: 'Official WHO 2021 global diagnostic standard for male fertility assessment.',
          url: 'https://www.who.int/publications/i/item/9789240030787'
        },
        {
          id: 5,
          treatmentId: 'trt',
          citation: 'Testosterone Therapy in Men with Hypogonadism: An Endocrine Society Clinical Practice Guideline (Bhasin et al., JCEM) & EAU 2024',
          guidelineBody: 'The Endocrine Society & European Association of Urology (EAU)',
          year: '2018 / 2024',
          evidenceLevel: 'Level 1a Clinical Practice Guideline',
          recommendation: 'Hypogonadism diagnosis requires symptomatic presentation confirmed by at least two separate low morning fasting total testosterone levels (< 9.2 nmol/L or 300 ng/dL). Therapy aims to restore levels to the mid-normal physiological range (14–25 nmol/L) with routine hematocrit (HCT < 54%) and PSA surveillance.',
          clinicalApplication: '5-milestone safety protocol (Baseline, Months 1, 3, 6, 12); physician titration prevents secondary polycythemia while restoring metabolic stability and vitality.',
          reviewMarker: 'Official international Endocrine Society & EAU clinical guideline with scheduled safety monitoring.',
          url: 'https://academic.oup.com/jcem/article/103/5/1715/4939465'
        },
        {
          id: 6,
          treatmentId: 'pe_ed',
          citation: 'ISSM Guidelines for the Pharmacotherapy & Psychosexual Management of Premature Ejaculation & EAU 2024',
          guidelineBody: 'International Society for Sexual Medicine (ISSM) / EAU',
          year: '2024',
          evidenceLevel: 'Level 1b Multimodal Clinical Guideline',
          recommendation: 'Guidelines advise a multimodal management strategy integrating short-acting pharmacotherapy (short-acting SSRIs/PDE5i as clinically indicated), pelvic floor relaxation conditioning (relieving bulbocavernosus hypertonicity), and behavioral desensitization techniques (Stop-Start and diaphragmatic pacing).',
          clinicalApplication: 'Patients receive phased guidance to map and recognize the 7/10 arousal threshold prior to the point of ejaculatory inevitability, fostering durable psychosexual confidence and neuromuscular control.',
          reviewMarker: 'Comprehensive multimodal protocol adhering to international ISSM and EAU standards.',
          url: 'https://www.issm.info/'
        }
      ]
    },

    treatments: {
      eswt: {
        id: 'eswt',
        name: 'Extracorporeal Shockwave Therapy (ESWT)',
        shortName: 'ESWT Shockwave',
        tagline: 'Vascular & Microcirculation Recovery',
        title: 'Microvascular Regeneration & Enhanced Tissue Perfusion',
        description: 'Low-intensity acoustic shockwaves stimulate vascular endothelial growth factor (VEGF) release, break down microscopic plaques, and support natural angiogenesis.',
        targetPatient: 'Patients with vasculogenic erectile dysfunction, reduced penile perfusion, or microvascular tissue degeneration.',
        contraindications: 'Active bleeding disorders, high-dose anticoagulant therapy, acute local infection, or pelvic malignancy.',
        evidence: {
          level: 'Investigational / Selected Patients',
          levelLabel: 'Selected Patients / Controlled Evidence',
          citation: 'EAU Guidelines on Sexual and Reproductive Health (Li-ESWT for Vasculogenic ED)',
          clinicalNote: 'Low-intensity shockwave therapy is positioned for selected patients with confirmed vascular etiology.',
          reviewMarker: 'Typical protocol energy flux density of 0.09 mJ/mm² referenced from clinical trial protocols.',
          refId: 1
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Baseline & Cellular Activation (Weeks 1-2)',
            highlight: 'Initiates non-invasive cellular metabolic activation.',
            details: 'Sessions begin at a controlled energy flux density (0.09 mJ/mm²). Endothelial cells are stimulated to release nitric oxide (NO) signaling molecules.',
            metric: 'Baseline Tissue Activation'
          },
          {
            phase: 2,
            title: 'Phase 2: Neovascularization & Capillary Sprouting (Weeks 3-6)',
            highlight: 'Formation of new microvascular networks (Angiogenesis).',
            details: 'Increased oxygenated blood perfusion to the corpus cavernosum sponge architecture to support natural physiological response.',
            metric: 'Enhanced Vascular Perfusion'
          },
          {
            phase: 3,
            title: 'Phase 3: Structural Strengthening & Elasticity (Weeks 7-10)',
            highlight: 'Collagen fiber integration and recovery of vascular elasticity.',
            details: 'Rigidity and endurance achieve improved tissue stability with reduced post-activity refractory intervals.',
            metric: 'Tissue Performance Stability'
          },
          {
            phase: 4,
            title: 'Phase 4: Long-Term Maintenance & Retention (Weeks 12+)',
            highlight: 'Sustaining endothelial health and long-term tissue microcirculation.',
            details: 'Semi-annual clinical review combined with pelvic floor guidance to maintain long-term microvascular health.',
            metric: 'Clinical Target Achieved'
          }
        ]
      },

      kegel: {
        id: 'kegel',
        name: 'High-Intensity Electromagnetic Kegel Chair',
        shortName: 'Kegel Chair',
        tagline: 'Guided Pelvic Floor Neuromuscular Training',
        title: 'Pelvic Floor Strengthening & Ejaculatory Reflex Control',
        description: 'High-intensity focused electromagnetic stimulation induces supramaximal contractions of the levator ani and bulbocavernosus muscles to rebuild pelvic tone.',
        targetPatient: 'Men presenting with pelvic floor laxity, premature ejaculatory latency, or post-surgical continence rehabilitation.',
        contraindications: 'Cardiac pacemakers, metallic implants in pelvis/spine, cochlear implants, acute urinary tract infection.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'Guideline-Supported Practice',
          citation: 'Pelvic Floor Muscle Training for Men with Erectile & Ejaculatory Dysfunction (Trial Evidence & CPG)',
          clinicalNote: 'Pelvic floor muscle training is clinically demonstrated to improve bulbocavernosus tone and continence.',
          reviewMarker: 'Scheduled session protocol supervised by licensed medical personnel.',
          refId: 2
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Neuromuscular Isolation & Proper Technique (Sessions 1-2)',
            highlight: 'Identifying targeted pelvic floor musculature and clean contraction.',
            details: 'Patients are guided to isolate the levator ani and bulbocavernosus without compensating with abdominal or gluteal muscles.',
            metric: 'Neuromuscular Awareness'
          },
          {
            phase: 2,
            title: 'Phase 2: Progressive Muscle Endurance (Sessions 3-6)',
            highlight: 'Gradual escalation of contraction duration and motor endurance.',
            details: 'Intensity parameters are adjusted according to individual physiological tolerance; home exercises reinforce session gains.',
            metric: 'Endurance Development'
          },
          {
            phase: 3,
            title: 'Phase 3: Reflex Control & Breathing Coordination (Sessions 7-10)',
            highlight: 'Integrating pelvic motor control with stimulus pacing.',
            details: 'Focus shifts to consistent neuromuscular pacing and fine-tuning recovery protocols based on individual response.',
            metric: 'Consistent Reflex Control'
          },
          {
            phase: 4,
            title: 'Phase 4: Long-Term Retention & Maintenance (Post-Program)',
            highlight: 'Retaining learned motor patterns and baseline pelvic muscle tone.',
            details: 'Periodic maintenance sessions and routine home exercises are recommended to sustain clinical improvements.',
            metric: 'Maintenance Routine Established'
          }
        ]
      },

      pshot: {
        id: 'pshot',
        name: 'Platelet-Rich Plasma Regenerative Therapy (P-Shot)',
        shortName: 'P-Shot PRP',
        tagline: 'Doctor-Administered Autologous Cellular Care',
        title: 'Autologous Regenerative Procedure Following Clinical Screening',
        description: 'Sterile autologous platelet-rich plasma (PRP) concentrated from patient blood and administered by a registered physician following comprehensive pre-screening.',
        targetPatient: 'Patients seeking microvascular and cellular tissue support following comprehensive diagnostic blood panel review.',
        contraindications: 'Severe thrombocytopenia, platelet dysfunction syndromes, systemic sepsis, or localized malignancy.',
        evidence: {
          level: 'Investigational / Selected Patients',
          levelLabel: 'Autologous Clinical Protocol',
          citation: 'Autologous Platelet-Rich Plasma in Sexual Medicine (Clinical Evaluation & Consent Standards)',
          clinicalNote: 'Conducted under comprehensive informed medical consent without promotional outcome guarantees.',
          reviewMarker: 'MAB Compliance: No absolute efficacy claims; emphasis placed on aseptic technique and medical evaluation.',
          refId: 3
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Diagnostic Blood Panel & Eligibility Review (Week 1)',
            highlight: 'Thorough evaluation before any procedural decision.',
            details: 'Physician reviews clinical history, complete blood count (platelet levels), and organ function markers to determine candidacy.',
            metric: 'Clinical Candidacy Confirmed'
          },
          {
            phase: 2,
            title: 'Phase 2: Informed Consent & Aseptic Procedure (Weeks 2-3)',
            highlight: 'Transparent discussion of procedural expectations and safety.',
            details: 'Centrifugation and autologous administration conducted under strict aseptic clinical standards by a licensed doctor.',
            metric: 'Informed Consent Completed'
          },
          {
            phase: 3,
            title: 'Phase 3: Cellular Response & Tissue Recovery (Weeks 4-8)',
            highlight: 'Release of autologous growth factors (PDGF, VEGF, TGF-β).',
            details: 'Patient adheres to post-care hygiene and monitors physiological responses during scheduled clinical follow-ups.',
            metric: 'Tissue Response Monitoring'
          },
          {
            phase: 4,
            title: 'Phase 4: Follow-up Clinical Review (Weeks 12+)',
            highlight: 'Objective physician assessment to guide lifestyle and follow-up.',
            details: 'Doctor evaluates tissue response and discusses ongoing vascular support or complementary therapies as appropriate.',
            metric: '12-Week Progress Review'
          }
        ]
      },

      fertility: {
        id: 'fertility',
        name: 'Comprehensive 12-Week Male Fertility Protocol',
        shortName: 'Male Fertility',
        tagline: 'Semen Analysis & Guided Cellular Infusion Support',
        title: 'Full 12-Week Spermatogenesis Optimization Program',
        description: 'A 12-week protocol aligned with the human spermatogenesis cycle, incorporating WHO-standard semen parameter tracking and physician-monitored cellular infusions.',
        targetPatient: 'Men planning conception with suboptimal sperm count, progressive motility, vitality, or morphology on baseline testing.',
        contraindications: 'Unscreened primary endocrine disorders, severe renal or hepatic failure.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'WHO Semen Manual Standards',
          citation: 'WHO Laboratory Manual for the Examination and Processing of Human Semen (6th Edition, 2021)',
          clinicalNote: 'Human spermatogenesis requires approximately 74 days plus epididymal transit time to reach completion.',
          reviewMarker: '12-week protocol structure directly reflects the biological cycle of human sperm production.',
          refId: 4
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Baseline Semen Analysis & Endocrine Screen (Week 1)',
            highlight: 'Establishing quantitative baseline for count, motility, and morphology.',
            details: 'Sample analyzed according to 6th Edition WHO reference standards. Reproductive hormone screen (FSH, LH, Prolactin, Total T) ordered.',
            metric: 'Laboratory Baseline Established'
          },
          {
            phase: 2,
            title: 'Phase 2: Scheduled Infusions & Antioxidant Defense (Weeks 2-6)',
            highlight: 'Mitigating reactive oxygen species (ROS) and supporting mitochondria.',
            details: 'Patient receives scheduled cellular nutrient infusions (NAD+ / CoQ10) alongside targeted lifestyle and nutritional adjustments.',
            metric: 'Infusion Adherence Maintained'
          },
          {
            phase: 3,
            title: 'Phase 3: Mid-Program Clinical Review & Heat Mitigation (Weeks 7-9)',
            highlight: 'Monitoring tolerance and eliminating environmental heat and toxin exposure.',
            details: 'Physician reviews sleep, weight management, dietary micronutrients, and cessation of tobacco or vaping exposure.',
            metric: 'Mid-Cycle Physician Review'
          },
          {
            phase: 4,
            title: 'Phase 4: Post-Cycle Repeat Semen Analysis (Week 12)',
            highlight: 'Objective laboratory evaluation of the new sperm generation.',
            details: 'Repeat semen analysis conducted after completion of the 74-84 day spermatogenic window to benchmark progress.',
            metric: 'Post-Spermatogenesis Assessment'
          }
        ]
      },

      trt: {
        id: 'trt',
        name: 'Testosterone Replacement Therapy (TRT)',
        shortName: 'TRT Hormone',
        tagline: 'Laboratory-Guided Endocrine & Metabolic Optimization',
        title: 'Physiological Hormone Optimization Based on Clinical Testing',
        description: 'A medically supervised endocrine protocol designed to restore testosterone to safe physiological levels in hypogonadal men, confirmed via morning lab testing.',
        targetPatient: 'Men presenting with clinical hypogonadism symptoms confirmed on repeat morning serum testosterone tests.',
        contraindications: 'Active prostate or male breast cancer, baseline hematocrit > 54%, uncontrolled congestive heart failure, immediate fertility desires.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'Endocrine Society & EAU Guidelines',
          citation: 'Endocrine Society 2018 Guideline (Bhasin et al.) & EAU Male Hypogonadism Guidelines',
          clinicalNote: 'Diagnosis requires unequivocal clinical symptoms combined with consistently low morning fasting testosterone on at least 2 separate occasions.',
          reviewMarker: 'Diagnostic threshold: < 9.2 - 12 nmol/L. Therapeutic target is mid-normal physiological range (14-25 nmol/L), avoiding supra-physiological claims.',
          refId: 5
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Comprehensive Blood Panel & Physiological Dosing (Weeks 1-2)',
            highlight: 'Baseline confirmation via Total T, Free T, PSA, Lipid Panel & Hematocrit.',
            details: 'Doctor checks hepatic, renal, and red blood cell concentration (Hct) before initiating controlled physiological replacement therapy.',
            metric: 'Diagnostic Baseline Confirmed'
          },
          {
            phase: 2,
            title: 'Phase 2: Energy, Mood & Sleep Architecture Recovery (Weeks 3-6)',
            highlight: 'Reduction in chronic fatigue and stabilization of mental clarity.',
            details: 'Serum androgen concentrations stabilize within normal reference limits. Patients report improved sleep depth and consistent daily stamina.',
            metric: 'Physiological Energy Recovery'
          },
          {
            phase: 3,
            title: 'Phase 3: Body Composition & Metabolic Insulin Sensitivity (Weeks 7-10)',
            highlight: 'Gradual visceral adipose reduction and lean muscle mass support.',
            details: 'Insulin sensitivity and lipid metabolism improve. Coupling therapy with baseline resistance exercise enhances metabolic recovery.',
            metric: 'Metabolic & Composition Progress'
          },
          {
            phase: 4,
            title: 'Phase 4: 12-Week Cardiovascular & Hematology Monitoring (Weeks 12+)',
            highlight: 'Follow-up blood draw to monitor cardiovascular and hematocrit safety.',
            details: 'Follow-up laboratory check of hematocrit, PSA, and lipids ensures endocrine levels remain safely within physiological targets.',
            metric: '12-Week Safety Monitoring'
          }
        ]
      },

      pe_ed: {
        id: 'pe_ed',
        name: 'Integrated Male Performance Rehabilitation (PE/ED)',
        shortName: 'PE/ED Rehab',
        tagline: 'Pelvic Floor Physiotherapy & Neuro-Sensory Modulation',
        title: 'Integrated Neuromuscular & Behavioral Performance Therapy',
        description: 'A multimodal clinical protocol combining pelvic floor physiotherapy, neuro-sensory modulation, and behavioral pacing to improve ejaculatory latency and firmness.',
        targetPatient: 'Patients with performance anxiety, primary or secondary premature ejaculation, or mixed vasculogenic/psychogenic ED.',
        contraindications: 'Acute spinal cord or neurologic pathology requiring specialized neurological evaluation.',
        evidence: {
          level: 'Guideline-Supported',
          levelLabel: 'ISSM & EAU Guideline Framework',
          citation: 'ISSM / EAU Guidelines on Premature Ejaculation & Erectile Dysfunction',
          clinicalNote: 'Integrates approved pharmacotherapy, pelvic floor rehabilitation, and behavioral desensitization techniques.',
          reviewMarker: 'Ethical clinical care: avoids absolute lifetime guarantees, emphasizing muscle conditioning and ongoing doctor guidance.',
          refId: 6
        },
        phases: [
          {
            phase: 1,
            title: 'Phase 1: Sensory Threshold Mapping & Pelvic Awareness (Weeks 1-2)',
            highlight: 'Identifying bulbocavernosus tone and neural trigger thresholds.',
            details: 'Physician tests sensory thresholds and guides pelvic floor contraction techniques to lower performance-related sympathetic tone.',
            metric: 'Neuromuscular Awareness'
          },
          {
            phase: 2,
            title: 'Phase 2: Stimulus Pacing & Diaphragmatic Breath Control (Weeks 3-6)',
            highlight: 'Progressive escalation of stimulus latency thresholds.',
            details: 'Stepwise desensitization techniques and controlled breathing rhythms prevent premature sympathetic nervous system surges.',
            metric: 'Threshold Latency Control'
          },
          {
            phase: 3,
            title: 'Phase 3: Response Firmness & Psychological Confidence (Weeks 7-10)',
            highlight: 'Maintaining stable erectile response without performance anxiety.',
            details: 'Restored microcirculation coupled with anxiety reduction fosters reliable, consistent intimacy response.',
            metric: 'Erectile Stability Confirmed'
          },
          {
            phase: 4,
            title: 'Phase 4: Long-Term Muscle Memory & Retention (Weeks 12+)',
            highlight: 'Reinforcing reflex control through muscle memory.',
            details: 'Gains are consolidated through conditioned neuromuscular memory and lifestyle strategies with ongoing clinic follow-up.',
            metric: 'Consistent Long-Term Control'
          }
        ]
      }
    }
  }
};

const LANG_STORAGE_KEY = 'sscam_consultation_lang';

export function getStoredConsultationLang(): ConsultationLang {
  if (typeof localStorage === 'undefined') return 'ms';
  const val = localStorage.getItem(LANG_STORAGE_KEY);
  return val === 'en' ? 'en' : 'ms';
}

export function setStoredConsultationLang(lang: ConsultationLang): void {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(LANG_STORAGE_KEY, lang);
  }
}

export function getConsultationCopy(lang: ConsultationLang = 'ms'): ConsultationDictionary {
  return CONSULTATION_I18N[lang] || CONSULTATION_I18N.ms;
}

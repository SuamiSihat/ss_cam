const fs = require('fs');
const path = require('path');
const config = require('../config');

// Prohibited terms under KKM / LIU guidelines under Medicines (Advertisement and Sale) Act 1956
const PROHIBITED_TERMS = [
  { term: '100% sembuh', reason: 'Tuntutan jaminan kesembuhan mutlak dilarang di bawah Akta Iklan Ubat 1956.' },
  { term: 'pasti sembuh', reason: 'Tuntutan kesembuhan tanpa syarat tidak dibenarkan oleh KKM.' },
  { term: 'pasti berkesan', reason: 'Keberkesanan klinikal berbeza mengikut individu; perkataan mutlak dilarang.' },
  { term: 'tanpa kesan sampingan', reason: 'Tiada prosedur atau ubat yang boleh dijamin bebas kesan sampingan 100%.' },
  { term: 'ubat kuat', reason: 'Istilah "ubat kuat" dilarang secara mutlak dalam pengiklanan perubatan sah.' },
  { term: 'ajaib', reason: 'Perkataan "ajaib" atau "miracle cure" melanggar standard Lembaga Iklan Ubat (LIU).' },
  { term: 'sembuh serta-merta', reason: 'Tuntutan penyembuhan segera atau magis dilarang oleh KKM.' },
  { term: 'guaranteed cure', reason: 'Absolute cure claims are strictly prohibited in English marketing.' },
  { term: '100% effective', reason: 'Absolute efficacy guarantee violates medical advertising codes.' },
  { term: 'no side effects', reason: 'Claiming zero side-effects violates MAB/LIU safety regulations.' }
];

const APPROVAL_CODE_REGEX = /\b(KKLIU|KKM\/LIU|LIU|MAL)\s*[:\/\-\s]?\s*([A-Za-z0-9\/\-]+)\b/i;

const DISCLAIMER_KEYWORDS = [
  'nasihat doktor',
  'tujuan edukasi',
  'professional medical advice',
  'educational purposes',
  'doktor bertauliah',
  'consult a doctor',
  'sila rujuk doktor'
];

const APPROVED_CLAIMS = [
  {
    category: 'ESWT',
    treatmentName: 'Terapi Gelombang Kejutan (ESWT)',
    approvedClaim: 'Membantu merangsang neovaskularisasi dan melancarkan peredaran darah mikro tisu secara non-invasif.',
    referenceCode: 'KKM/LIU/B/0812/2026'
  },
  {
    category: 'TRT',
    treatmentName: 'Terapi Penggantian Testosteron (TRT)',
    approvedClaim: 'Pelan rawatan perubatan berasaskan ujian profil darah bagi menyokong tahap hormon optimum lelaki dewasa.',
    referenceCode: 'KKM/LIU/B/0813/2026'
  },
  {
    category: 'PE_ED',
    treatmentName: 'Rehabilitasi Kesihatan Lelaki',
    approvedClaim: 'Pendekatan klinikal bersepadu menggabungkan terapi fizikal dan bimbingan gaya hidup sihat.',
    referenceCode: 'KKM/LIU/B/0814/2026'
  },
  {
    category: 'WELLNESS',
    treatmentName: 'Saringan Kesihatan Holistik',
    approvedClaim: 'Pemeriksaan kesihatan menyeluruh meliputi paras glukosa, kolesterol, dan fungsi organ penting.',
    referenceCode: 'KKM/LIU/B/0815/2026'
  }
];

class RegulatoryService {
  constructor() {
    this.ensureSopManuals(config.WORKSPACE_ROOT);
  }

  verifyCopy(text) {
    if (!text || typeof text !== 'string') {
      return { isCompliant: true, infractions: [], hasApprovalCode: false, hasDisclaimer: false, suggestions: [] };
    }

    const lower = text.toLowerCase();
    const infractions = [];

    for (const item of PROHIBITED_TERMS) {
      if (lower.includes(item.term.toLowerCase())) {
        infractions.push({
          term: item.term,
          reason: item.reason,
          recommendation: `Gantikan '${item.term}' dengan penerangan klinikal objektif berasaskan sains perubatan.`
        });
      }
    }

    const match = text.match(APPROVAL_CODE_REGEX);
    const hasApprovalCode = Boolean(match);
    const approvalCode = match ? match[0].trim() : null;

    let hasDisclaimer = false;
    for (const kw of DISCLAIMER_KEYWORDS) {
      if (lower.includes(kw)) {
        hasDisclaimer = true;
        break;
      }
    }

    const suggestions = [];
    if (infractions.length > 0) {
      suggestions.push(`Dikesan ${infractions.length} frasa melanggar garis panduan KKM/LIU.`);
    }
    if (!hasDisclaimer) {
      suggestions.push('Sila tambahkan penafian perubatan (Medical Disclaimer) wajib di bahagian bawah bahan.');
    }

    return {
      isCompliant: infractions.length === 0,
      infractions,
      hasApprovalCode,
      approvalCode,
      hasDisclaimer,
      suggestions
    };
  }

  getApprovedClaims(category = null) {
    if (category) {
      return APPROVED_CLAIMS.filter(c => c.category.toLowerCase() === category.toLowerCase());
    }
    return APPROVED_CLAIMS;
  }

  getMedicalDisclaimer(lang = 'ms') {
    if (lang === 'en') {
      return 'Disclaimer: This material is for patient educational purposes only and does not substitute professional clinical diagnosis. Please consult our certified medical doctors for a personalized consultation.';
    }
    return 'Penafian KKM: Maklumat ini adalah untuk tujuan edukasi pesakit sahaja dan tidak menggantikan nasihat klinikal profesional. Sila rujuk doktor perubatan bertauliah di klinik kami untuk diagnosis dan pelan rawatan yang tepat.';
  }

  getSopDir(workspaceRoot = config.WORKSPACE_ROOT) {
    return path.join(workspaceRoot || config.WORKSPACE_ROOT, '_Clinic', 'SOP_Manuals');
  }

  ensureSopManuals(workspaceRoot = config.WORKSPACE_ROOT) {
    try {
      const sopDir = this.getSopDir(workspaceRoot);
      if (!fs.existsSync(sopDir)) {
        fs.mkdirSync(sopDir, { recursive: true });
      }

      const defaultSops = [
        {
          id: 'SOP-01',
          fileName: 'SOP-01_Patient_Consultation_Protocol.md',
          title: 'SOP-01: Protokol Konsultasi Pesakit & Etika Kerahsiaan Bilik Rawatan',
          category: 'Konsultasi',
          content: `# SOP-01: Protokol Konsultasi Pesakit & Etika Kerahsiaan Bilik Rawatan\n\n## 1. Objektif\nMemastikan setiap pesakit menerima penerangan rawatan yang telus, saintifik, dan beretika dengan tahap kerahsiaan perubatan 100%.\n\n## 2. Standard Prosedur Konsultasi Doktor\n1. **Salam & Bina Keselesaan (Rapport)**: Mulakan dengan suasana santai dan privasi tanpa penghakiman.\n2. **Penerangan Visual Interaktif**: Gunakan rajah anatomi SS-CAM In-Clinic Suite untuk menerangkan punca vaskular/hormon.\n3. **Pelan Rawatan & Jangka Masa**: Bentangkan 4 fasa pemulihan dan jadual lawatan susulan.\n4. **Persetujuan Termaklum (Informed Consent)**: Pastikan borang persetujuan ditandatangani pesakit sebelum rawatan.\n`
        },
        {
          id: 'SOP-02',
          fileName: 'SOP-02_ESWT_Shockwave_Safety.md',
          title: 'SOP-02: Protokol Keselamatan Terapi Gelombang Kejutan (ESWT)',
          category: 'Prosedur Klinikal',
          content: `# SOP-02: Protokol Keselamatan Terapi Gelombang Kejutan (ESWT)\n\n## 1. Indikasi & Kontraindikasi\n- **Indikasi**: Vaskulogenik disfungsi ereksi, penyakit Peyronie fasa kronik.\n- **Kontraindikasi**: Jangkitan kulit aktif, keganasan tempatan (malignancy), gangguan pembekuan darah tidak terkawal.\n\n## 2. Kalibrasi Tenaga Mesin\n- Frekuensi standard: 4-6 Hz.\n- Paras tenaga: 0.09 - 0.16 mJ/mm² mengikut toleransi pesakit.\n- Jumlah tembakan: 1,500 - 2,000 pukulan setiap sesi.\n`
        },
        {
          id: 'SOP-03',
          fileName: 'SOP-03_TRT_Blood_Monitoring.md',
          title: 'SOP-03: Protokol Pemantauan Profil Darah Terapi Penggantian Testosteron (TRT)',
          category: 'Endokrinologi',
          content: `# SOP-03: Protokol Pemantauan Profil Darah Terapi Penggantian Testosteron (TRT)\n\n## 1. Ujian Asas (Baseline Screening)\n- Total & Free Testosterone (ujian darah pagi sebelum 10:00 AM).\n- FBC / Hematokrit (Hct < 50%).\n- PSA (Prostate Specific Antigen) & Ujian Fungsi Hati (LFT).\n\n## 2. Jadual Pemantauan Susulan\n- **Minggu ke-12**: Semak paras testosteron nadir & hematokrit.\n- **Bulan ke-6 & ke-12**: Semakan profil hormon lengkap & skor kualiti hidup pesakit.\n`
        },
        {
          id: 'SOP-04',
          fileName: 'SOP-04_Emergency_Response.md',
          title: 'SOP-04: Tindakan Kecemasan & Kemalangan Bilik Rawatan',
          category: 'Kecemasan',
          content: `# SOP-04: Tindakan Kecemasan & Kemalangan Bilik Rawatan\n\n## 1. Protokol Pesakit Pitam / Vasovagal Syncope\n1. Letakkan pesakit dalam posisi Trendelenburg (kaki ditinggikan).\n2. Longgarkan pakaian ketat dan pastikan laluan udara lancar.\n3. Periksa tekanan darah dan kadar nadi setiap 3 minit.\n4. Berikan oksigen tambahan sekiranya SpO2 < 95%.\n`
        }
      ];

      for (const sop of defaultSops) {
        const filePath = path.join(sopDir, sop.fileName);
        if (!fs.existsSync(filePath)) {
          fs.writeFileSync(filePath, sop.content, 'utf8');
        }
      }
    } catch (err) {
      console.warn('[RegulatoryService] Ensure SOP manuals warning:', err.message);
    }
  }

  getSopManuals(workspaceRoot = config.WORKSPACE_ROOT) {
    try {
      const sopDir = this.getSopDir(workspaceRoot);
      if (!fs.existsSync(sopDir)) return [];

      const files = fs.readdirSync(sopDir).filter(f => f.endsWith('.md'));
      return files.map(file => {
        const id = file.replace(/\.md$/, '');
        const filePath = path.join(sopDir, file);
        const content = fs.readFileSync(filePath, 'utf8');
        const firstLine = content.split('\n')[0].replace(/^#\s*/, '').trim();
        return {
          id,
          fileName: file,
          title: firstLine || file,
          sizeBytes: fs.statSync(filePath).size,
          lastModified: fs.statSync(filePath).mtime
        };
      });
    } catch (err) {
      console.error('[RegulatoryService] getSopManuals error:', err.message);
      return [];
    }
  }

  getSopManualContent(workspaceRoot = config.WORKSPACE_ROOT, id) {
    try {
      const sopDir = this.getSopDir(workspaceRoot);
      const safeId = path.basename(id);
      const fileName = safeId.endsWith('.md') ? safeId : `${safeId}.md`;
      const filePath = path.join(sopDir, fileName);

      if (!fs.existsSync(filePath)) return null;
      return fs.readFileSync(filePath, 'utf8');
    } catch (err) {
      console.error('[RegulatoryService] getSopManualContent error:', err.message);
      return null;
    }
  }
}

module.exports = new RegulatoryService();

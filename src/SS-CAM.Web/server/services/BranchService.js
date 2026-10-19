const CompanyService = require("./CompanyService");

/** Branches are owned by the Healthcare & Clinic entity in the Corporate Registry. */
const CLINIC_COMPANY_CODE = "SSC";

class BranchService {
  constructor() {
    // Built-in fallback, used only while the registry has no branches configured.
    this.branches = [
      {
        code: 'SSC-BSR',
        name: 'SuamiSihat Clinic Bangsar (HQ Induk)',
        shortName: 'Bangsar HQ',
        address: 'No. 45, Jalan Telawi 3, Bangsar Baru, 59100 Kuala Lumpur',
        phone: '+603-2284 1122',
        whatsapp: '+6012-345 6789',
        doctors: ['Dr. Azlan Shah, MD (Cyberjaya), Dip. Men\'s Health', 'Dr. Farhan Kamil, MBBS (Malaya)'],
        operatingHours: 'Isnin - Sabtu: 9:00 AM - 7:00 PM (Ahad: Tutup)',
        kkmLicense: 'KKM/JPS/KL/2024/0912',
        checkInUrl: 'https://suamisihat.clinic/checkin/bangsar',
        googleReviewUrl: 'https://g.page/r/suamisihat-bangsar/review'
      },
      {
        code: 'SSC-KD',
        name: 'SuamiSihat Clinic Kota Damansara',
        shortName: 'Kota Damansara',
        address: '22-1, Jalan PJU 5/10, Dataran Sunway, Kota Damansara, 47810 Petaling Jaya, Selangor',
        phone: '+603-6142 8899',
        whatsapp: '+6012-345 6780',
        doctors: ['Dr. Haris Iskandar, MD (UKM)'],
        operatingHours: 'Isnin - Sabtu: 10:00 AM - 8:00 PM',
        kkmLicense: 'KKM/JPS/SGR/2025/1104',
        checkInUrl: 'https://suamisihat.clinic/checkin/kotadamansara',
        googleReviewUrl: 'https://g.page/r/suamisihat-kd/review'
      },
      {
        code: 'SSC-JB',
        name: 'SuamiSihat Clinic Johor Bahru',
        shortName: 'Johor Bahru',
        address: '15, Jalan Austin Heights 8/3, Taman Mount Austin, 81100 Johor Bahru, Johor',
        phone: '+607-351 4455',
        whatsapp: '+6012-345 6781',
        doctors: ['Dr. Luqman Hakim, MBBS (Monash)'],
        operatingHours: 'Selasa - Ahad: 9:30 AM - 6:30 PM (Isnin: Tutup)',
        kkmLicense: 'KKM/JPS/JHR/2025/0821',
        checkInUrl: 'https://suamisihat.clinic/checkin/jb',
        googleReviewUrl: 'https://g.page/r/suamisihat-jb/review'
      },
      {
        code: 'SSC-PNG',
        name: 'SuamiSihat Clinic Georgetown Penang',
        shortName: 'Penang',
        address: '88, Jalan Kelawai, Georgetown, 10250 Pulau Pinang',
        phone: '+604-226 7733',
        whatsapp: '+6012-345 6782',
        doctors: ['Dr. Kelvin Tan, MD (USM)'],
        operatingHours: 'Isnin - Sabtu: 9:00 AM - 6:00 PM',
        kkmLicense: 'KKM/JPS/PNG/2026/0415',
        checkInUrl: 'https://suamisihat.clinic/checkin/penang',
        googleReviewUrl: 'https://g.page/r/suamisihat-penang/review'
      }
    ];
  }

  getBranches() {
    try {
      const clinic = CompanyService.getByCode(CLINIC_COMPANY_CODE);
      if (clinic && Array.isArray(clinic.branches) && clinic.branches.length > 0) {
        return clinic.branches;
      }
    } catch (err) {
      console.warn("[BranchService] Registry unavailable, using built-in branches:", err.message);
    }
    return this.branches;
  }

  /** Tenant-configured price block for a branch, or null when not configured. */
  getPricing(code) {
    const branch = this.getBranchByCode(code);
    return branch && branch.pricing ? branch.pricing : null;
  }

  getBranchByCode(code) {
    if (!code) return null;
    const clean = code.trim().toUpperCase();
    return this.getBranches().find(b => b.code.toUpperCase() === clean || (b.shortName || "").toUpperCase() === clean) || null;
  }

  /**
   * Updates the public-facing profile of one branch (name, contact, hours, licence, doctors, links).
   * Only whitelisted fields are accepted; the branch code and price block are never changed here.
   * Links must be http(s) because they are rendered as clickable links / QR targets on the TV.
   */
  updateBranch(code, patch = {}) {
    const current = this.getBranchByCode(code);
    if (!current) throw new Error('Branch not found.');
    if (!patch || typeof patch !== 'object') throw new Error('Branch details are required.');

    const text = (v, max) => String(v === undefined || v === null ? '' : v).trim().slice(0, max);
    const url = (v, label) => {
      const value = text(v, 300);
      if (!value) return '';
      let parsed;
      try { parsed = new URL(value); } catch (e) { throw new Error(`${label} must be a full web address starting with https://`); }
      if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
        throw new Error(`${label} must start with https:// or http://`);
      }
      return value;
    };

    const next = {};
    if (patch.name !== undefined) {
      next.name = text(patch.name, 160);
      if (!next.name) throw new Error('Branch name is required.');
    }
    if (patch.shortName !== undefined) next.shortName = text(patch.shortName, 80);
    if (patch.address !== undefined) next.address = text(patch.address, 300);
    if (patch.phone !== undefined) next.phone = text(patch.phone, 40);
    if (patch.whatsapp !== undefined) next.whatsapp = text(patch.whatsapp, 40);
    if (patch.operatingHours !== undefined) next.operatingHours = text(patch.operatingHours, 200);
    if (patch.kkmLicense !== undefined) next.kkmLicense = text(patch.kkmLicense, 80);
    if (patch.checkInUrl !== undefined) next.checkInUrl = url(patch.checkInUrl, 'Check-in link');
    if (patch.googleReviewUrl !== undefined) next.googleReviewUrl = url(patch.googleReviewUrl, 'Review link');
    if (patch.doctors !== undefined) {
      if (!Array.isArray(patch.doctors)) throw new Error('Doctors must be a list.');
      next.doctors = patch.doctors.map(d => text(d, 160)).filter(Boolean).slice(0, 30);
    }

    return CompanyService.updateBranch(CLINIC_COMPANY_CODE, current.code, next, this.branches);
  }

  generateIntakePayload(branchCode, intakeType = 'consult', treatment = 'Umum') {
    const branch = this.getBranchByCode(branchCode) || this.getBranches()[0];
    const phoneDigits = (branch.whatsapp || "").replace(/[^0-9]/g, '');

    if (intakeType === 'checkin') {
      return {
        type: 'checkin',
        branch: branch.name,
        url: branch.checkInUrl,
        label: `Touchless Check-In: ${branch.shortName}`
      };
    }

    if (intakeType === 'review') {
      return {
        type: 'review',
        branch: branch.name,
        url: branch.googleReviewUrl,
        label: `Google Review: ${branch.shortName}`
      };
    }

    // Default: WhatsApp consult
    const textMsg = encodeURIComponent(
      `Salam sejahtera SuamiSihat Clinic ${branch.shortName}. Saya ingin membuat pertanyaan sulit mengenai konsultasi ${treatment}.`
    );
    const waUrl = `https://wa.me/${phoneDigits}?text=${textMsg}`;

    return {
      type: 'consult',
      branch: branch.name,
      url: waUrl,
      label: `WhatsApp Consult: ${branch.shortName} (${treatment})`
    };
  }

  injectBranchDetails(templateText, branchCode, doctorName = null) {
    if (!templateText) return '';
    const branch = this.getBranchByCode(branchCode) || this.getBranches()[0];
    const doctor = doctorName || (branch.doctors && branch.doctors[0]) || "";

    return templateText
      .replace(/\{BRANCH_NAME\}/g, branch.name)
      .replace(/\{BRANCH_SHORT\}/g, branch.shortName)
      .replace(/\{BRANCH_ADDRESS\}/g, branch.address)
      .replace(/\{BRANCH_PHONE\}/g, branch.phone)
      .replace(/\{BRANCH_WHATSAPP\}/g, branch.whatsapp)
      .replace(/\{DOCTOR_NAME\}/g, doctor)
      .replace(/\{OPERATING_HOURS\}/g, branch.operatingHours)
      .replace(/\{KKM_LICENSE\}/g, branch.kkmLicense);
  }
}

module.exports = new BranchService();

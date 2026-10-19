const fs = require('fs');
const path = require('path');
const config = require('../config');

const DEFAULT_COMPANIES = [
  {
    code: 'SS',
    name: 'SuamiSihat Core',
    shortName: 'Core Operations',
    regNo: '202401012344 (1550122-W)',
    address: 'Level 28, Menara SuamiSihat, Jalan Ampang, 50450 Kuala Lumpur, Malaysia',
    contact: '+603-2181-8888 / info@suamisihat.com',
    location: 'Kuala Lumpur, Malaysia',
    status: 'active',
    isParent: false,
    establishedYear: '2020',
    color: '#0078D4'
  },
  {
    code: 'SSH',
    name: 'SuamiSihat Holding Sdn Bhd',
    shortName: 'Holding Group',
    regNo: '202401012345 (1550123-X)',
    address: 'Level 28, Menara SuamiSihat, Jalan Ampang, 50450 Kuala Lumpur, Malaysia',
    contact: '+603-2181-8888 / holding@suamisihat.com',
    location: 'Kuala Lumpur, Malaysia',
    status: 'active',
    isParent: true,
    establishedYear: '2020',
    color: '#022057'
  },
  {
    code: 'SSC',
    name: 'SuamiSihat Healthcare Sdn Bhd',
    shortName: 'Healthcare & Clinic',
    regNo: '202401012346 (1550124-Y)',
    address: 'SuamiSihat Clinic, No. 12, Ground Floor, Jalan Telawi 3, Bangsar, 59100 Kuala Lumpur',
    contact: '+603-2282-7777 / healthcare@suamisihat.com',
    location: 'Bangsar, Kuala Lumpur',
    status: 'active',
    isParent: false,
    establishedYear: '2021',
    color: '#043388'
  },
  {
    code: 'SSW',
    name: 'SuamiSihat Wellness Sdn Bhd',
    shortName: 'Wellness & Nutrition',
    regNo: '202401012347 (1550125-Z)',
    address: 'Unit 3A-01, Oval Damansara, 685 Jalan Damansara, 60000 Kuala Lumpur',
    contact: '+603-7733-6666 / wellness@suamisihat.com',
    location: 'Damansara, Kuala Lumpur',
    status: 'active',
    isParent: false,
    establishedYear: '2022',
    color: '#21A1F7'
  },
  {
    code: 'SSE',
    name: 'SuamiSihat Ecommerce Sdn Bhd',
    shortName: 'E-Commerce & Retail',
    regNo: '202401012348 (1550126-A)',
    address: 'Warehouse Hub 2, Jalan PJU 1A/41B, Ara Damansara, 47301 Petaling Jaya, Selangor',
    contact: '+603-7848-5555 / ecom@suamisihat.com',
    location: 'Petaling Jaya, Selangor',
    status: 'active',
    isParent: false,
    establishedYear: '2023',
    color: '#107C41'
  },
  {
    code: 'SST',
    name: 'SuamiSihat Technology Sdn Bhd',
    shortName: 'Technology & Digital',
    regNo: '202401012349 (1550127-B)',
    address: 'Cyberjaya Tech Park, Block 3, Persiaran APEC, 63000 Cyberjaya, Selangor',
    contact: '+603-8322-4444 / tech@suamisihat.com',
    location: 'Cyberjaya, Selangor',
    status: 'active',
    isParent: false,
    establishedYear: '2024',
    color: '#8764B8'
  }
];

const str = (v, max = 300) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const money = (v) => {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 100) / 100 : null;
};

/**
 * Branches live on a company record in the Corporate Registry (SSC = Healthcare & Clinic).
 * Each branch carries its own contact details and a tenant-configurable price block, so no
 * branch or price is hard-coded in the application.
 */
function sanitizePricing(p) {
  if (!p || typeof p !== "object") return null;
  const packages = (Array.isArray(p.packages) ? p.packages : [])
    .map((pk) => ({ id: str(pk && pk.id, 60), label: str(pk && pk.label, 160), price: money(pk && pk.price) }))
    .filter((pk) => pk.label && pk.price !== null)
    .slice(0, 50);
  return {
    currency: str(p.currency, 8) || "RM",
    consultationFee: money(p.consultationFee),
    onlineBookingFee: money(p.onlineBookingFee),
    onlineBookingNote: str(p.onlineBookingNote, 300),
    packages,
    validFrom: str(p.validFrom, 40),
    validTo: str(p.validTo, 40),
    updatedAt: new Date().toISOString()
  };
}

function sanitizeBranches(list) {
  if (!Array.isArray(list)) return [];
  const seen = new Set();
  const out = [];
  for (const b of list.slice(0, 50)) {
    if (!b || typeof b !== "object") continue;
    const code = str(b.code, 30).toUpperCase();
    const name = str(b.name, 160);
    if (!code || !name || seen.has(code)) continue;
    seen.add(code);
    out.push({
      code,
      name,
      shortName: str(b.shortName, 80) || name,
      address: str(b.address, 300),
      phone: str(b.phone, 40),
      whatsapp: str(b.whatsapp, 40),
      doctors: (Array.isArray(b.doctors) ? b.doctors : []).map((d) => str(d, 160)).filter(Boolean).slice(0, 30),
      operatingHours: str(b.operatingHours, 200),
      kkmLicense: str(b.kkmLicense, 80),
      checkInUrl: str(b.checkInUrl, 300),
      googleReviewUrl: str(b.googleReviewUrl, 300),
      pricing: sanitizePricing(b.pricing)
    });
  }
  return out;
}

class CompanyService {
  constructor() {
    this.memoryCompanies = null;
  }

  getStoragePath() {
    const configDir = path.join(config.WORKSPACE_ROOT, '_Team', '_Config');
    if (!fs.existsSync(configDir)) {
      try {
        fs.mkdirSync(configDir, { recursive: true });
      } catch (e) {
        console.debug('[CompanyService] Failed to create configDir:', e.message);
      }
    }
    return path.join(configDir, 'companies.json');
  }

  loadCompanies() {
    const p = this.getStoragePath();
    if (fs.existsSync(p)) {
      try {
        const raw = fs.readFileSync(p, 'utf8');
        const data = JSON.parse(raw);
        if (Array.isArray(data) && data.length > 0) {
          this.memoryCompanies = data;
          return this.memoryCompanies;
        }
      } catch (err) {
        console.error('[CompanyService] Error reading companies.json:', err.message);
      }
    }

    // Default Seed
    this.memoryCompanies = JSON.parse(JSON.stringify(DEFAULT_COMPANIES));
    this.persistCompanies();
    return this.memoryCompanies;
  }

  persistCompanies() {
    if (!this.memoryCompanies) return;
    const p = this.getStoragePath();
    try {
      fs.writeFileSync(p, JSON.stringify(this.memoryCompanies, null, 2), 'utf8');
    } catch (err) {
      console.error('[CompanyService] Error writing companies.json:', err.message);
    }
  }

  getAll() {
    if (!this.memoryCompanies) {
      this.loadCompanies();
    }
    return this.memoryCompanies || DEFAULT_COMPANIES;
  }

  getByCode(code) {
    const all = this.getAll();
    return all.find((c) => c.code.toUpperCase() === (code || '').toUpperCase()) || null;
  }

  saveCompany(companyData) {
    if (!companyData || !companyData.code || !companyData.name) {
      throw new Error('Company code and name are required.');
    }

    const all = this.getAll();
    const code = companyData.code.trim().toUpperCase();
    const existingIndex = all.findIndex((c) => c.code.toUpperCase() === code);

    const updatedItem = {
      code,
      name: companyData.name.trim(),
      shortName: companyData.shortName ? companyData.shortName.trim() : code,
      regNo: companyData.regNo ? companyData.regNo.trim() : '',
      address: companyData.address ? companyData.address.trim() : '',
      contact: companyData.contact ? companyData.contact.trim() : '',
      location: companyData.location ? companyData.location.trim() : '',
      status: companyData.status || 'active',
      isParent: Boolean(companyData.isParent),
      establishedYear: companyData.establishedYear || new Date().getFullYear().toString(),
      color: companyData.color || '#043388',
      updatedAt: new Date().toISOString()
    };
    // Only touch branches when the caller sends them, so ordinary company edits never wipe them.
    if (Array.isArray(companyData.branches)) {
      updatedItem.branches = sanitizeBranches(companyData.branches);
    }

    if (existingIndex >= 0) {
      all[existingIndex] = { ...all[existingIndex], ...updatedItem };
    } else {
      all.push(updatedItem);
    }

    this.memoryCompanies = all;
    this.persistCompanies();
    return updatedItem;
  }

  /**
   * Updates ONE branch of a company in place. Other branches (and their price blocks) are left
   * exactly as stored. When the company has no branches yet, `seedBranches` is used as the
   * starting list so built-in defaults can be edited and then persisted to the registry.
   */
  updateBranch(companyCode, branchCode, patch, seedBranches = []) {
    const all = this.getAll();
    const companyIdx = all.findIndex((c) => c.code.toUpperCase() === String(companyCode || '').toUpperCase());
    if (companyIdx < 0) throw new Error(`Company "${companyCode}" is not in the Corporate Registry.`);

    const company = all[companyIdx];
    const list = Array.isArray(company.branches) && company.branches.length > 0
      ? company.branches.slice()
      : sanitizeBranches(seedBranches);
    const branchIdx = list.findIndex((b) => b.code.toUpperCase() === String(branchCode || '').toUpperCase());
    if (branchIdx < 0) throw new Error(`Branch "${branchCode}" was not found.`);

    const existing = list[branchIdx];
    const [clean] = sanitizeBranches([{ ...existing, ...patch, code: existing.code }]);
    if (!clean) throw new Error('Branch name is required.');
    // Pricing is managed elsewhere; keep it byte-for-byte (sanitizeBranches would restamp updatedAt).
    clean.pricing = existing.pricing || null;

    list[branchIdx] = clean;
    all[companyIdx] = { ...company, branches: list, updatedAt: new Date().toISOString() };
    this.memoryCompanies = all;
    this.persistCompanies();
    return clean;
  }

  deleteCompany(code) {
    if (!code) throw new Error('Company code is required.');
    const upper = code.trim().toUpperCase();
    const all = this.getAll();
    const filtered = all.filter((c) => c.code.toUpperCase() !== upper);

    if (filtered.length === all.length) {
      throw new Error(`Company with code "${code}" not found.`);
    }

    this.memoryCompanies = filtered;
    this.persistCompanies();
    return { success: true, deletedCode: upper };
  }
}

module.exports = new CompanyService();

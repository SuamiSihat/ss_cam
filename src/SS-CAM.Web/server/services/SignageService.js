const fs = require('fs');
const path = require('path');
const config = require('../config');
const WorkspaceService = require('./WorkspaceService');
const BranchService = require('./BranchService');
const AuditService = require('./AuditService');
const SseService = require('./SseService');

const DEFAULT_SIGNAGE_CONFIG = {
  branchCode: 'SSC-BSR',
  slideDurationSec: 10,
  soundAlertEnabled: true,
  kkmLicense: 'KKM/JPS/KL/2024/0912',
  ticker: {
    enabled: true,
    prefix: 'INFO KLINIK',
    text: 'Selamat datang ke SuamiSihat Clinic • Rawatan kesihatan lelaki beretika, saintifik dan diperakui KKM • Kerahsiaan rekod pesakit dilindungi 100% di bawah Akta Perlindungan Data Peribadi (PDPA 2010) • Sila pastikan telefon dalam mod senyap semasa berada di bilik konsultasi doktor.'
  },
  queue: {
    currentCall: null,
    upcoming: []
  },
  slides: [
    {
      id: 'duty-doctor',
      enabled: true,
      tag: 'DOKTOR BERTUGAS HARI INI',
      title: 'Pakar Konsultasi Kesihatan Lelaki',
      subtitle: 'Sedia membantu anda dengan bimbingan klinikal peribadi dan sulit.',
      type: 'doctors'
    },
    {
      id: 'eswt-info',
      enabled: true,
      tag: 'RAWATAN KLINIKAL TERMAJU',
      title: 'Terapi Gelombang Kejutan (ESWT)',
      subtitle: 'Teknologi non-invasif merangsang neovaskularisasi & pengaliran darah mikro secara semulajadi.',
      type: 'eswt'
    },
    {
      id: 'trt-info',
      enabled: true,
      tag: 'KESEIMBANGAN HORMON LELAKI',
      title: 'Terapi Penggantian Testosteron (TRT)',
      subtitle: 'Diagnosis profil darah menyeluruh bagi mengembalikan tenaga, fokus dan kualiti tidur optimum.',
      type: 'trt'
    },
    {
      id: 'touchless-checkin',
      enabled: true,
      tag: 'PENDAFTARAN PANTAS & PRIVASI',
      title: 'Pendaftaran Tanpa Sentuh (Touchless Intake)',
      subtitle: 'Imbas kod QR di kaunter untuk daftar giliran atau buat pertanyaan sulit WhatsApp.',
      type: 'intake'
    },
    {
      id: 'custom-notice',
      enabled: false,
      tag: 'PENGUMUMAN KHAS',
      title: 'Pemeriksaan Kesihatan Komprehensif',
      subtitle: 'Dapatkan saringan tahap testosteron dan kesihatan prostat anda hari ini di kaunter pendaftaran.',
      type: 'notice'
    }
  ]
};

class SignageService {
  constructor() {
    this.memoryConfig = null;
  }

  getFilePath() {
    const root = WorkspaceService.workspaceRoot || config.WORKSPACE_ROOT;
    const teamDir = path.join(root, '_Team');
    if (!fs.existsSync(teamDir)) {
      try { fs.mkdirSync(teamDir, { recursive: true }); } catch (e) {
        console.debug('[SignageService] Failed to create teamDir:', e.message);
      }
    }
    return path.join(teamDir, 'signage_config.json');
  }

  loadConfig() {
    const filePath = this.getFilePath();
    if (fs.existsSync(filePath)) {
      try {
        let raw = fs.readFileSync(filePath, 'utf8');
        if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') {
          this.memoryConfig = this.mergeWithDefaults(parsed);
          return this.memoryConfig;
        }
      } catch (err) {
        console.warn('[SignageService] Could not read signage_config.json, using fallback:', err.message);
      }
    }

    if (!this.memoryConfig) {
      this.memoryConfig = JSON.parse(JSON.stringify(DEFAULT_SIGNAGE_CONFIG));
      this.saveConfig(this.memoryConfig);
    }
    return this.memoryConfig;
  }

  mergeWithDefaults(loaded) {
    return {
      branchCode: loaded.branchCode || DEFAULT_SIGNAGE_CONFIG.branchCode,
      slideDurationSec: typeof loaded.slideDurationSec === 'number' && loaded.slideDurationSec >= 3 ? loaded.slideDurationSec : 10,
      soundAlertEnabled: loaded.soundAlertEnabled !== false,
      kkmLicense: loaded.kkmLicense || DEFAULT_SIGNAGE_CONFIG.kkmLicense,
      ticker: {
        enabled: loaded.ticker ? loaded.ticker.enabled !== false : true,
        prefix: (loaded.ticker && loaded.ticker.prefix) || DEFAULT_SIGNAGE_CONFIG.ticker.prefix,
        text: (loaded.ticker && loaded.ticker.text) || DEFAULT_SIGNAGE_CONFIG.ticker.text
      },
      queue: {
        currentCall: (loaded.queue && loaded.queue.currentCall !== undefined)
          ? loaded.queue.currentCall
          : null,
        upcoming: (loaded.queue && Array.isArray(loaded.queue.upcoming))
          ? loaded.queue.upcoming
          : []
      },
      slides: Array.isArray(loaded.slides) && loaded.slides.length > 0 ? loaded.slides : DEFAULT_SIGNAGE_CONFIG.slides,
      updatedAt: loaded.updatedAt || new Date().toISOString(),
      updatedBy: loaded.updatedBy || 'System'
    };
  }

  saveConfig(data) {
    this.memoryConfig = data;
    const filePath = this.getFilePath();
    try {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
      return true;
    } catch (err) {
      console.warn('[SignageService] Could not save signage_config.json:', err.message);
      return false;
    }
  }

  /**
   * Retrieves active signage configuration, automatically injecting current branch profile details.
   */
  getConfig(branchCodeOverride = null) {
    const cfg = this.loadConfig();
    const effectiveCode = branchCodeOverride || cfg.branchCode || 'SSC-BSR';
    const branch = BranchService.getBranchByCode(effectiveCode) || BranchService.getBranches()[0];

    return {
      ...cfg,
      branchCode: branch ? branch.code : effectiveCode,
      branch: branch || null,
      effectiveLicense: cfg.kkmLicense || (branch ? branch.kkmLicense : 'KKM/JPS/KL/2024/0912')
    };
  }

  /**
   * Updates global signage settings (ticker, slides, slide duration, active branch, sound alert).
   */
  updateConfig(updates = {}, actor = 'Admin', role = 'admin') {
    const current = this.loadConfig();

    if (updates.branchCode) current.branchCode = String(updates.branchCode).trim().toUpperCase();
    if (typeof updates.slideDurationSec === 'number') current.slideDurationSec = Math.max(3, Math.min(120, updates.slideDurationSec));
    if (typeof updates.soundAlertEnabled === 'boolean') current.soundAlertEnabled = updates.soundAlertEnabled;
    if (updates.kkmLicense !== undefined) current.kkmLicense = String(updates.kkmLicense).trim();

    if (updates.ticker && typeof updates.ticker === 'object') {
      current.ticker = {
        enabled: updates.ticker.enabled !== false,
        prefix: String(updates.ticker.prefix || 'INFO KLINIK').trim(),
        text: String(updates.ticker.text || '').trim()
      };
    }

    if (Array.isArray(updates.slides)) {
      current.slides = updates.slides.map(s => ({
        id: s.id || `slide_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        enabled: s.enabled !== false,
        tag: String(s.tag || 'INFO').trim(),
        title: String(s.title || '').trim(),
        subtitle: String(s.subtitle || '').trim(),
        type: s.type || 'notice'
      }));
    }

    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;

    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'UPDATE_SIGNAGE_CONFIG',
      entityType: 'signage',
      entityId: current.branchCode,
      details: { branchCode: current.branchCode, slideDurationSec: current.slideDurationSec }
    });

    const enriched = this.getConfig(current.branchCode);
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }

  /**
   * Calls a queue ticket to a specific room/station.
   * If popUpcoming is true, removes matching or first upcoming ticket from the queue list.
   */
  callTicket({ ticket, room = 'Bilik Rawatan 1', doctor = null, popUpcoming = false }, actor = 'Staff', role = 'admin') {
    if (!ticket) throw new Error('Ticket number is required to call queue.');

    const current = this.loadConfig();
    const cleanTicket = String(ticket).trim().toUpperCase();
    const cleanRoom = String(room).trim();
    const cleanDoctor = doctor ? String(doctor).trim() : null;

    current.queue = current.queue || { currentCall: null, upcoming: [] };
    current.queue.currentCall = {
      ticket: cleanTicket,
      room: cleanRoom,
      doctor: cleanDoctor,
      calledAt: new Date().toISOString()
    };

    if (popUpcoming && Array.isArray(current.queue.upcoming) && current.queue.upcoming.length > 0) {
      const matchIdx = current.queue.upcoming.findIndex(u => u.ticket.toUpperCase() === cleanTicket);
      if (matchIdx !== -1) {
        current.queue.upcoming.splice(matchIdx, 1);
      } else {
        current.queue.upcoming.shift();
      }
    }

    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;

    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'CALL_SIGNAGE_TICKET',
      entityType: 'queue',
      entityId: cleanTicket,
      details: { ticket: cleanTicket, room: cleanRoom, doctor: cleanDoctor }
    });

    const enriched = this.getConfig(current.branchCode);
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }

  /**
   * Calls the next ticket in the upcoming queue.
   */
  callNext(room = 'Bilik Rawatan 1', doctor = null, actor = 'Staff', role = 'admin') {
    const current = this.loadConfig();
    const upcoming = (current.queue && Array.isArray(current.queue.upcoming)) ? current.queue.upcoming : [];
    if (upcoming.length === 0) {
      throw new Error('No pending tickets in the upcoming queue.');
    }

    const next = upcoming[0];
    return this.callTicket({
      ticket: next.ticket,
      room: next.room || room,
      doctor: doctor || current.queue.currentCall?.doctor || null,
      popUpcoming: true
    }, actor, role);
  }

  /**
   * Sets or updates upcoming queue tickets array.
   */
  updateUpcoming(upcomingList = [], actor = 'Staff', role = 'admin') {
    if (!Array.isArray(upcomingList)) throw new Error('upcomingList must be an array.');

    const current = this.loadConfig();
    current.queue = current.queue || { currentCall: null, upcoming: [] };
    current.queue.upcoming = upcomingList
      .filter(item => item && item.ticket)
      .map(item => ({
        ticket: String(item.ticket).trim().toUpperCase(),
        room: String(item.room || 'Kaunter Saringan').trim()
      }));

    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;

    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'UPDATE_SIGNAGE_UPCOMING_QUEUE',
      entityType: 'queue',
      entityId: 'upcoming',
      details: { count: current.queue.upcoming.length }
    });

    const enriched = this.getConfig(current.branchCode);
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }

  /**
   * Clears or resets the active queue.
   */
  clearQueue(clearCurrentCall = false, actor = 'Staff', role = 'admin') {
    const current = this.loadConfig();
    current.queue = current.queue || {};
    current.queue.upcoming = [];
    if (clearCurrentCall) {
      current.queue.currentCall = null;
    }

    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;

    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'CLEAR_SIGNAGE_QUEUE',
      entityType: 'queue',
      entityId: 'all',
      details: { clearCurrentCall }
    });

    const enriched = this.getConfig(current.branchCode);
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }
}

module.exports = new SignageService();

const fs = require('fs');
const path = require('path');
const config = require('../config');
const WorkspaceService = require('./WorkspaceService');
const BranchService = require('./BranchService');
const AuditService = require('./AuditService');
const SseService = require('./SseService');

/** Slide types the kiosk knows how to render. */
const SLIDE_TYPES = ['doctors', 'eswt', 'trt', 'intake', 'notice', 'video'];

/** Uploaded playlist videos live here and are only ever addressed by this exact URL shape. */
const MEDIA_URL_PREFIX = '/api/clinic/signage/media/';
const MEDIA_FILE_PATTERN = /^[a-f0-9]{16}\.(mp4|webm)$/;
const MAX_SLIDES = 40;
const MAX_ROOMS = 30;
const TICKET_PATTERN = /^[A-Z0-9][A-Z0-9-]{0,11}$/;

const DEFAULT_SIGNAGE_CONFIG = {
  branchCode: 'SSC-BSR',
  slideDurationSec: 10,
  soundAlertEnabled: true,
  rooms: [
    'Bilik Rawatan 1',
    'Bilik Rawatan 2',
    'Bilik Rawatan 3',
    'Bilik Prosedur ESWT',
    'Kaunter Saringan',
    'Makmal Darah TRT',
    'Kaunter Farmasi'
  ],
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

function clip(value, max) {
  return String(value === undefined || value === null ? '' : value).trim().slice(0, max);
}

function newId(prefix) {
  return `${prefix}_${Date.now().toString(36)}${Math.random().toString(36).substring(2, 6)}`;
}

/** Cleans one slide from untrusted input. Returns null when the slide must be dropped. */
function sanitizeSlide(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const type = SLIDE_TYPES.includes(raw.type) ? raw.type : 'notice';
  const slide = {
    id: clip(raw.id, 60) || newId('slide'),
    enabled: raw.enabled !== false,
    tag: clip(raw.tag, 60) || 'INFO',
    title: clip(raw.title, 160),
    subtitle: clip(raw.subtitle, 400),
    type
  };

  if (type === 'video') {
    const src = clip(raw.src, 120);
    if (!src.startsWith(MEDIA_URL_PREFIX) || !MEDIA_FILE_PATTERN.test(src.slice(MEDIA_URL_PREFIX.length))) {
      return null; // only files uploaded through the signage media endpoint can be played
    }
    slide.src = src;
    slide.muted = raw.muted !== false;
    slide.originalName = clip(raw.originalName, 160);
    slide.sizeBytes = Math.max(0, Math.min(Number(raw.sizeBytes) || 0, 10 * 1024 * 1024 * 1024));
    if (!slide.title) slide.title = slide.originalName || 'Video';
  }
  return slide;
}

function sanitizeRooms(list) {
  if (!Array.isArray(list)) return null;
  const seen = new Set();
  const out = [];
  for (const item of list) {
    const room = clip(item, 60);
    const key = room.toLowerCase();
    if (!room || seen.has(key)) continue;
    seen.add(key);
    out.push(room);
    if (out.length >= MAX_ROOMS) break;
  }
  return out;
}

function sanitizeTicket(value) {
  const ticket = clip(value, 24).toUpperCase();
  if (!TICKET_PATTERN.test(ticket)) {
    throw new Error('Ticket number must use letters, digits or "-" only (for example A-1031).');
  }
  return ticket;
}

/** True when the first bytes of the file really look like an MP4 or WebM container. */
function looksLikeVideo(filePath, ext) {
  let fd;
  try {
    fd = fs.openSync(filePath, 'r');
    const head = Buffer.alloc(12);
    const read = fs.readSync(fd, head, 0, 12, 0);
    if (read < 12) return false;
    if (ext === '.webm') return head[0] === 0x1a && head[1] === 0x45 && head[2] === 0xdf && head[3] === 0xa3;
    if (ext === '.mp4') return head.toString('ascii', 4, 8) === 'ftyp';
    return false;
  } catch (err) {
    console.warn('[SignageService] Could not inspect uploaded video:', err.message);
    return false;
  } finally {
    if (fd !== undefined) {
      try { fs.closeSync(fd); } catch (err) { console.debug('[SignageService] closeSync failed:', err.message); }
    }
  }
}

class SignageService {
  constructor() {
    this.memoryConfig = null;
  }

  getTeamDir() {
    const root = WorkspaceService.workspaceRoot || config.WORKSPACE_ROOT;
    const teamDir = path.join(root, '_Team');
    if (!fs.existsSync(teamDir)) {
      try { fs.mkdirSync(teamDir, { recursive: true }); } catch (e) {
        console.debug('[SignageService] Failed to create teamDir:', e.message);
      }
    }
    return teamDir;
  }

  getFilePath() {
    return path.join(this.getTeamDir(), 'signage_config.json');
  }

  /** Folder for uploaded playlist videos (created on demand). */
  getMediaDir() {
    const dir = path.join(this.getTeamDir(), 'signage_media');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  /** Absolute path of an uploaded video, or null when the name is not a valid media file name. */
  resolveMediaFile(fileName) {
    if (!MEDIA_FILE_PATTERN.test(String(fileName || ''))) return null;
    const dir = path.resolve(this.getMediaDir());
    const full = path.resolve(dir, fileName);
    if (path.dirname(full) !== dir) return null;
    return full;
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
    const rooms = sanitizeRooms(loaded.rooms);
    const slides = Array.isArray(loaded.slides)
      ? loaded.slides.map(sanitizeSlide).filter(Boolean)
      : [];
    return {
      branchCode: loaded.branchCode || DEFAULT_SIGNAGE_CONFIG.branchCode,
      slideDurationSec: typeof loaded.slideDurationSec === 'number' && loaded.slideDurationSec >= 3 ? loaded.slideDurationSec : 10,
      soundAlertEnabled: loaded.soundAlertEnabled !== false,
      rooms: rooms && rooms.length > 0 ? rooms : DEFAULT_SIGNAGE_CONFIG.rooms.slice(),
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
      // An empty array is a valid choice (staff removed everything); only a missing list falls back.
      slides: Array.isArray(loaded.slides) ? slides : JSON.parse(JSON.stringify(DEFAULT_SIGNAGE_CONFIG.slides)),
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
   * The licence shown on the TV is always the selected branch's own licence.
   */
  getConfig(branchCodeOverride = null) {
    const cfg = this.loadConfig();
    const effectiveCode = branchCodeOverride || cfg.branchCode || 'SSC-BSR';
    const branch = BranchService.getBranchByCode(effectiveCode) || BranchService.getBranches()[0];

    return {
      ...cfg,
      branchCode: branch ? branch.code : effectiveCode,
      branch: branch || null,
      effectiveLicense: branch ? (branch.kkmLicense || '') : ''
    };
  }

  /** Pushes the current state to every connected TV and admin screen. */
  broadcast() {
    const enriched = this.getConfig();
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }

  /**
   * Updates global signage settings (ticker, playlist, slide duration, active branch, rooms, sound alert).
   */
  updateConfig(updates = {}, actor = 'Admin', role = 'admin') {
    const current = this.loadConfig();

    if (updates.branchCode) {
      const branch = BranchService.getBranchByCode(String(updates.branchCode));
      if (!branch) throw new Error('That branch does not exist.');
      current.branchCode = branch.code;
    }
    if (updates.slideDurationSec !== undefined) {
      const sec = Number(updates.slideDurationSec);
      if (Number.isFinite(sec)) current.slideDurationSec = Math.max(3, Math.min(120, Math.round(sec)));
    }
    if (typeof updates.soundAlertEnabled === 'boolean') current.soundAlertEnabled = updates.soundAlertEnabled;

    if (updates.ticker && typeof updates.ticker === 'object') {
      current.ticker = {
        enabled: updates.ticker.enabled !== false,
        prefix: clip(updates.ticker.prefix, 40) || 'INFO KLINIK',
        text: clip(updates.ticker.text, 800)
      };
    }

    if (updates.rooms !== undefined) {
      const rooms = sanitizeRooms(updates.rooms);
      if (!rooms || rooms.length === 0) throw new Error('Add at least one room or counter.');
      current.rooms = rooms;
    }

    if (Array.isArray(updates.slides)) {
      if (updates.slides.length > MAX_SLIDES) throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
      current.slides = updates.slides.map(sanitizeSlide).filter(Boolean);
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
      details: {
        branchCode: current.branchCode,
        slideDurationSec: current.slideDurationSec,
        playlistItems: current.slides.length
      }
    });

    return this.broadcast();
  }

  /**
   * Registers an uploaded video (already written to the media folder) as a new playlist item.
   * The file is verified to be a real MP4/WebM; otherwise it is deleted and the upload refused.
   */
  addVideo({ fileName, originalName, sizeBytes }, actor = 'Staff', role = 'admin') {
    const full = this.resolveMediaFile(fileName);
    if (!full || !fs.existsSync(full)) throw new Error('The uploaded video could not be found.');

    const ext = path.extname(fileName).toLowerCase();
    if (!looksLikeVideo(full, ext)) {
      this.deleteMediaFile(fileName);
      throw new Error('That file is not a valid MP4 or WebM video.');
    }

    const current = this.loadConfig();
    if (current.slides.length >= MAX_SLIDES) {
      this.deleteMediaFile(fileName);
      throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
    }

    const cleanName = clip(String(originalName || '').replace(/\.[^.]+$/, ''), 120) || 'Video';
    const slide = sanitizeSlide({
      id: newId('video'),
      enabled: true,
      type: 'video',
      tag: 'VIDEO',
      title: cleanName,
      subtitle: '',
      src: `${MEDIA_URL_PREFIX}${fileName}`,
      muted: true,
      originalName: clip(originalName, 160),
      sizeBytes
    });
    current.slides.push(slide);
    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;
    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'ADD_SIGNAGE_VIDEO',
      entityType: 'signage',
      entityId: fileName,
      details: { originalName: slide.originalName, sizeBytes: slide.sizeBytes }
    });

    return this.broadcast();
  }

  /** Deletes one uploaded video file. Returns true when a file was removed. */
  deleteMediaFile(fileName) {
    const full = this.resolveMediaFile(fileName);
    if (!full || !fs.existsSync(full)) return false;
    try {
      fs.unlinkSync(full);
      return true;
    } catch (err) {
      console.warn('[SignageService] Could not delete media file:', err.message);
      return false;
    }
  }

  /** Removes a video from the playlist and deletes its file. */
  removeVideo(fileName, actor = 'Staff', role = 'admin') {
    if (!MEDIA_FILE_PATTERN.test(String(fileName || ''))) throw new Error('Invalid video file name.');

    const current = this.loadConfig();
    const src = `${MEDIA_URL_PREFIX}${fileName}`;
    const before = current.slides.length;
    current.slides = current.slides.filter(s => s.src !== src);
    const removedFile = this.deleteMediaFile(fileName);
    if (current.slides.length === before && !removedFile) throw new Error('That video was not found.');

    current.updatedAt = new Date().toISOString();
    current.updatedBy = actor;
    this.saveConfig(current);

    AuditService.logEvent({
      actor,
      role,
      action: 'REMOVE_SIGNAGE_VIDEO',
      entityType: 'signage',
      entityId: fileName,
      details: { removedFile }
    });

    return this.broadcast();
  }

  /**
   * Calls a queue ticket to a specific room/station.
   * If popUpcoming is true, removes matching or first upcoming ticket from the queue list.
   */
  callTicket({ ticket, room = 'Bilik Rawatan 1', doctor = null, popUpcoming = false }, actor = 'Staff', role = 'admin') {
    if (!ticket) throw new Error('Ticket number is required to call queue.');

    const current = this.loadConfig();
    const cleanTicket = sanitizeTicket(ticket);
    const cleanRoom = clip(room, 80) || 'Bilik Rawatan 1';
    const cleanDoctor = doctor ? clip(doctor, 160) : null;

    current.queue = current.queue || { currentCall: null, upcoming: [] };
    current.queue.currentCall = {
      ticket: cleanTicket,
      room: cleanRoom,
      doctor: cleanDoctor,
      calledAt: new Date().toISOString()
    };

    if (popUpcoming && Array.isArray(current.queue.upcoming) && current.queue.upcoming.length > 0) {
      // Only remove the ticket that was actually called. Never drop a different waiting patient.
      const matchIdx = current.queue.upcoming.findIndex(u => String(u.ticket).toUpperCase() === cleanTicket);
      if (matchIdx !== -1) current.queue.upcoming.splice(matchIdx, 1);
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

    return this.broadcast();
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
    if (upcomingList.length > 100) throw new Error('The waiting list can hold at most 100 tickets.');

    const current = this.loadConfig();
    current.queue = current.queue || { currentCall: null, upcoming: [] };
    const seen = new Set();
    current.queue.upcoming = upcomingList
      .filter(item => item && item.ticket)
      .map(item => ({
        ticket: sanitizeTicket(item.ticket),
        room: clip(item.room, 80) || 'Kaunter Saringan'
      }))
      .filter(item => (seen.has(item.ticket) ? false : seen.add(item.ticket)));

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

    return this.broadcast();
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

    return this.broadcast();
  }
}

module.exports = new SignageService();
module.exports.MEDIA_URL_PREFIX = MEDIA_URL_PREFIX;
module.exports.MEDIA_FILE_PATTERN = MEDIA_FILE_PATTERN;

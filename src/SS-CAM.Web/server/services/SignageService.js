const fs = require('fs');
const path = require('path');
const config = require('../config');
const WorkspaceService = require('./WorkspaceService');
const BranchService = require('./BranchService');
const AuditService = require('./AuditService');
const SseService = require('./SseService');

/** Slide types the kiosk knows how to render. */
const SLIDE_TYPES = ['doctors', 'eswt', 'trt', 'intake', 'notice', 'video', 'banner'];

/** Uploaded playlist media lives here and is only ever addressed by this exact URL shape. */
const MEDIA_URL_PREFIX = '/api/clinic/signage/media/';
const MEDIA_FILE_PATTERN = /^[a-f0-9]{16}\.(mp4|webm|jpg|jpeg|png|webp)$/i;
const MAX_SLIDES = 40;
const MAX_ROOMS = 30;
const TICKET_PATTERN = /^[A-Z0-9][A-Z0-9-]{0,11}$/;

const DEFAULT_BRANCH_STATE = {
  revision: 1,
  slideDurationSec: 10,
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

const DEFAULT_SIGNAGE_CONFIG = {
  version: 2,
  branchCode: 'SSC-BSR',
  shared: {
    soundAlertEnabled: true,
    tickerPrefix: 'INFO KLINIK'
  },
  branches: {
    'SSC-BSR': JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE))
  }
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

  if (raw.durationSec !== undefined && raw.durationSec !== null && raw.durationSec !== '') {
    const sec = Number(raw.durationSec);
    if (Number.isFinite(sec)) {
      slide.durationSec = Math.max(3, Math.min(120, Math.round(sec)));
    }
  }

  if (raw.startsAt) {
    const d = new Date(raw.startsAt);
    if (!isNaN(d.getTime())) slide.startsAt = d.toISOString();
  }
  if (raw.endsAt) {
    const d = new Date(raw.endsAt);
    if (!isNaN(d.getTime())) slide.endsAt = d.toISOString();
  }

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
  } else if (type === 'banner') {
    const src = clip(raw.src, 120);
    if (!src.startsWith(MEDIA_URL_PREFIX) || !MEDIA_FILE_PATTERN.test(src.slice(MEDIA_URL_PREFIX.length))) {
      return null;
    }
    slide.src = src;
    slide.fit = raw.fit === 'contain' ? 'contain' : 'cover';
    slide.fullScreen = Boolean(raw.fullScreen);
    slide.alt = clip(raw.alt, 200);
    slide.originalName = clip(raw.originalName, 160);
    slide.sizeBytes = Math.max(0, Math.min(Number(raw.sizeBytes) || 0, 50 * 1024 * 1024));
    slide.width = Math.max(0, Number(raw.width) || 0);
    slide.height = Math.max(0, Number(raw.height) || 0);
    if (!slide.title) slide.title = slide.originalName || 'Banner';
  }

  return slide;
}

/** Inspects an uploaded image file: checks magic bytes and extracts width & height. */
function inspectImage(filePath, ext) {
  let fd;
  try {
    fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(65536);
    const bytesRead = fs.readSync(fd, buf, 0, 65536, 0);
    if (bytesRead < 16) return { valid: false, error: 'File is too small to be an image.' };

    const cleanExt = String(ext || '').toLowerCase();

    if (cleanExt === '.png') {
      const pngSig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      if (buf.subarray(0, 8).compare(pngSig) !== 0) {
        return { valid: false, error: 'Not a valid PNG file (invalid signature).' };
      }
      if (bytesRead < 24) return { valid: false, error: 'Corrupt PNG header.' };
      const width = buf.readUInt32BE(16);
      const height = buf.readUInt32BE(20);
      return { valid: true, type: 'png', width, height };
    }

    if (cleanExt === '.jpg' || cleanExt === '.jpeg') {
      if (buf[0] !== 0xff || buf[1] !== 0xd8 || buf[2] !== 0xff) {
        return { valid: false, error: 'Not a valid JPEG file (invalid signature).' };
      }
      let offset = 2;
      let width = 0;
      let height = 0;
      while (offset < bytesRead) {
        if (buf[offset] !== 0xff) {
          offset++;
          continue;
        }
        const marker = buf[offset + 1];
        if (
          (marker >= 0xc0 && marker <= 0xc3) ||
          (marker >= 0xc5 && marker <= 0xc7) ||
          (marker >= 0xc9 && marker <= 0xcb)
        ) {
          if (offset + 8 < bytesRead) {
            height = buf.readUInt16BE(offset + 5);
            width = buf.readUInt16BE(offset + 7);
            break;
          }
        }
        if (marker === 0xd9 || marker === 0xda) break;
        if (offset + 3 < bytesRead) {
          const len = buf.readUInt16BE(offset + 2);
          offset += 2 + len;
        } else {
          break;
        }
      }
      if (width === 0 || height === 0) {
        return { valid: false, error: 'Could not determine JPEG dimensions.' };
      }
      return { valid: true, type: 'jpeg', width, height };
    }

    if (cleanExt === '.webp') {
      if (
        buf.toString('ascii', 0, 4) !== 'RIFF' ||
        buf.toString('ascii', 8, 12) !== 'WEBP'
      ) {
        return { valid: false, error: 'Not a valid WebP file (invalid signature).' };
      }
      const chunkType = buf.toString('ascii', 12, 16);
      let width = 0;
      let height = 0;
      if (chunkType === 'VP8 ') {
        if (bytesRead >= 27 && buf[20] === 0x9d && buf[21] === 0x01 && buf[22] === 0x2a) {
          width = buf.readUInt16LE(23) & 0x3fff;
          height = buf.readUInt16LE(25) & 0x3fff;
        }
      } else if (chunkType === 'VP8L') {
        if (bytesRead >= 25 && buf[20] === 0x2f) {
          const b0 = buf[21];
          const b1 = buf[22];
          const b2 = buf[23];
          const b3 = buf[24];
          width = 1 + (((b1 & 0x3f) << 8) | b0);
          height = 1 + (((b3 & 0x0f) << 10) | (b2 << 2) | ((b1 & 0xc0) >> 6));
        }
      } else if (chunkType === 'VP8X') {
        if (bytesRead >= 30) {
          width = 1 + (buf[24] | (buf[25] << 8) | (buf[26] << 16));
          height = 1 + (buf[27] | (buf[28] << 8) | (buf[29] << 16));
        }
      }
      if (width === 0 || height === 0) {
        return { valid: false, error: 'Could not determine WebP dimensions.' };
      }
      return { valid: true, type: 'webp', width, height };
    }

    return { valid: false, error: 'Unsupported image format.' };
  } catch (err) {
    return { valid: false, error: err.message };
  } finally {
    if (fd !== undefined) {
      try { fs.closeSync(fd); } catch (e) {}
    }
  }
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
          if (!parsed.version || parsed.version < 2) {
            this.memoryConfig = this.migrateV1ToV2(parsed, raw);
            this.saveConfig(this.memoryConfig);
            return this.memoryConfig;
          }
          this.memoryConfig = this.normalizeV2(parsed);
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

  migrateV1ToV2(v1, rawText) {
    const bakPath = path.join(this.getTeamDir(), 'signage_config.json.bak-v1');
    if (!fs.existsSync(bakPath)) {
      try {
        fs.writeFileSync(bakPath, rawText || JSON.stringify(v1, null, 2), 'utf8');
        console.log('[SignageService] Backup created at:', bakPath);
      } catch (err) {
        console.warn('[SignageService] Failed to create v1 backup file:', err.message);
      }
    }

    const primaryCode = String(v1.branchCode || 'SSC-BSR').trim().toUpperCase();
    const rooms = sanitizeRooms(v1.rooms) || DEFAULT_BRANCH_STATE.rooms.slice();
    const slides = Array.isArray(v1.slides)
      ? v1.slides.map(sanitizeSlide).filter(Boolean)
      : JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE.slides));

    const branches = {};
    branches[primaryCode] = {
      revision: 1,
      slideDurationSec: typeof v1.slideDurationSec === 'number' && v1.slideDurationSec >= 3 ? v1.slideDurationSec : 10,
      rooms,
      ticker: {
        enabled: v1.ticker ? v1.ticker.enabled !== false : true,
        prefix: (v1.ticker && v1.ticker.prefix) || DEFAULT_BRANCH_STATE.ticker.prefix,
        text: (v1.ticker && v1.ticker.text) || DEFAULT_BRANCH_STATE.ticker.text
      },
      queue: {
        currentCall: (v1.queue && v1.queue.currentCall !== undefined) ? v1.queue.currentCall : null,
        upcoming: (v1.queue && Array.isArray(v1.queue.upcoming)) ? v1.queue.upcoming : []
      },
      slides,
      updatedAt: v1.updatedAt || new Date().toISOString(),
      updatedBy: v1.updatedBy || 'Migration'
    };

    try {
      const allBranches = BranchService.getBranches({ includeArchived: true });
      for (const b of allBranches) {
        const code = b.code.toUpperCase();
        if (!branches[code]) {
          branches[code] = JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE));
        }
      }
    } catch (_) {}

    return {
      version: 2,
      branchCode: primaryCode,
      shared: {
        soundAlertEnabled: v1.soundAlertEnabled !== false,
        tickerPrefix: (v1.ticker && v1.ticker.prefix) || 'INFO KLINIK'
      },
      branches,
      updatedAt: new Date().toISOString(),
      updatedBy: 'System (Migration v2)'
    };
  }

  normalizeV2(parsed) {
    const defaultCode = String(parsed.branchCode || 'SSC-BSR').trim().toUpperCase();
    const branches = (parsed.branches && typeof parsed.branches === 'object') ? parsed.branches : {};
    if (!branches[defaultCode]) {
      branches[defaultCode] = JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE));
    }
    return {
      version: 2,
      branchCode: defaultCode,
      shared: {
        soundAlertEnabled: parsed.shared ? parsed.shared.soundAlertEnabled !== false : true,
        tickerPrefix: (parsed.shared && parsed.shared.tickerPrefix) || 'INFO KLINIK'
      },
      branches,
      updatedAt: parsed.updatedAt || new Date().toISOString(),
      updatedBy: parsed.updatedBy || 'System'
    };
  }

  getBranchState(cfg, branchCode) {
    const code = String(branchCode || cfg.branchCode || 'SSC-BSR').trim().toUpperCase();
    if (!cfg.branches[code]) {
      cfg.branches[code] = JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE));
    }
    return cfg.branches[code];
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

  getConfig(branchCodeOverride = null) {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCodeOverride || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const branch = BranchService.getBranchByCode(effectiveCode, { includeArchived: false });

    if (!branch) {
      return {
        version: 2,
        branchCode: effectiveCode,
        branch: null,
        branchMissing: true,
        effectiveLicense: '',
        shared: cfg.shared,
        slideDurationSec: 10,
        soundAlertEnabled: cfg.shared?.soundAlertEnabled !== false,
        rooms: [],
        ticker: { enabled: false, prefix: '', text: '' },
        queue: { currentCall: null, upcoming: [] },
        slides: [],
        updatedAt: cfg.updatedAt,
        updatedBy: cfg.updatedBy
      };
    }

    const bState = this.getBranchState(cfg, effectiveCode);

    return {
      version: 2,
      branchCode: branch.code,
      branch,
      branchMissing: false,
      effectiveLicense: branch.kkmLicense || '',
      revision: bState.revision || 1,
      slideDurationSec: bState.slideDurationSec || 10,
      soundAlertEnabled: cfg.shared?.soundAlertEnabled !== false,
      rooms: bState.rooms || DEFAULT_BRANCH_STATE.rooms.slice(),
      ticker: bState.ticker || DEFAULT_BRANCH_STATE.ticker,
      queue: bState.queue || { currentCall: null, upcoming: [] },
      slides: bState.slides || [],
      shared: cfg.shared,
      updatedAt: bState.updatedAt || cfg.updatedAt,
      updatedBy: bState.updatedBy || cfg.updatedBy
    };
  }

  broadcast(branchCode = null) {
    const enriched = this.getConfig(branchCode);
    SseService.broadcast('signage:updated', enriched);
    return enriched;
  }

  updateConfig(updates = {}, branchCodeOrActor = null, maybeActor = 'Admin', maybeRole = 'admin') {
    let targetBranch = null;
    let actor = 'Admin';
    let role = 'admin';

    if (typeof branchCodeOrActor === 'string') {
      const clean = branchCodeOrActor.trim().toUpperCase();
      if (/^[A-Z0-9-]{2,12}$/.test(clean)) {
        targetBranch = clean;
        actor = maybeActor || 'Admin';
        role = maybeRole || 'admin';
      } else {
        actor = branchCodeOrActor;
        role = maybeRole || 'admin';
      }
    }

    const cfg = this.loadConfig();
    const effectiveCode = (targetBranch || updates.branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    if (updates.branchCode) {
      const branch = BranchService.getBranchByCode(String(updates.branchCode), { includeArchived: false });
      if (!branch) throw new Error('That branch does not exist or has been archived.');
      cfg.branchCode = branch.code;
    }
    if (typeof updates.soundAlertEnabled === 'boolean') {
      cfg.shared.soundAlertEnabled = updates.soundAlertEnabled;
    }
    if (updates.slideDurationSec !== undefined) {
      const sec = Number(updates.slideDurationSec);
      if (Number.isFinite(sec)) bState.slideDurationSec = Math.max(3, Math.min(120, Math.round(sec)));
    }
    if (updates.ticker && typeof updates.ticker === 'object') {
      bState.ticker = {
        enabled: updates.ticker.enabled !== false,
        prefix: clip(updates.ticker.prefix, 40) || 'INFO KLINIK',
        text: clip(updates.ticker.text, 800)
      };
    }
    if (updates.rooms !== undefined) {
      const rooms = sanitizeRooms(updates.rooms);
      if (!rooms || rooms.length === 0) throw new Error('Add at least one room or counter.');
      bState.rooms = rooms;
    }
    if (Array.isArray(updates.slides)) {
      if (updates.slides.length > MAX_SLIDES) throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
      bState.slides = updates.slides.map(sanitizeSlide).filter(Boolean);
    }

    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'UPDATE_SIGNAGE_CONFIG',
      entityType: 'signage',
      entityId: effectiveCode,
      details: {
        branchCode: effectiveCode,
        slideDurationSec: bState.slideDurationSec,
        playlistItems: bState.slides.length
      }
    });

    return this.broadcast(effectiveCode);
  }

  isMediaReferenced(fileName, currentCfg = null) {
    const src = `${MEDIA_URL_PREFIX}${fileName}`;
    const cfg = currentCfg || this.loadConfig();
    if (!cfg.branches) return false;
    for (const bCode of Object.keys(cfg.branches)) {
      const bState = cfg.branches[bCode];
      if (bState && Array.isArray(bState.slides)) {
        if (bState.slides.some(s => s.src === src)) return true;
      }
    }
    return false;
  }

  addVideo({ fileName, originalName, sizeBytes, branchCode = null }, actor = 'Staff', role = 'admin') {
    const full = this.resolveMediaFile(fileName);
    if (!full || !fs.existsSync(full)) throw new Error('The uploaded video could not be found.');

    const ext = path.extname(fileName).toLowerCase();
    if (!looksLikeVideo(full, ext)) {
      this.deleteMediaFile(fileName);
      throw new Error('That file is not a valid MP4 or WebM video.');
    }

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    if (bState.slides.length >= MAX_SLIDES) {
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
    bState.slides.push(slide);
    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'ADD_SIGNAGE_VIDEO',
      entityType: 'signage',
      entityId: fileName,
      details: { originalName: slide.originalName, sizeBytes: slide.sizeBytes, branchCode: effectiveCode }
    });

    return this.broadcast(effectiveCode);
  }

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

  removeVideo(fileName, branchCodeOrActor = null, maybeActor = 'Staff', maybeRole = 'admin') {
    if (!MEDIA_FILE_PATTERN.test(String(fileName || ''))) throw new Error('Invalid video file name.');

    let targetBranch = null;
    let actor = 'Staff';
    let role = 'admin';

    if (typeof branchCodeOrActor === 'string') {
      const clean = branchCodeOrActor.trim().toUpperCase();
      if (/^[A-Z0-9-]{2,12}$/.test(clean)) {
        targetBranch = clean;
        actor = maybeActor || 'Staff';
        role = maybeRole || 'admin';
      } else {
        actor = branchCodeOrActor;
        role = maybeRole || 'admin';
      }
    }

    const cfg = this.loadConfig();
    const src = `${MEDIA_URL_PREFIX}${fileName}`;
    let removedAny = false;

    if (targetBranch) {
      const bState = this.getBranchState(cfg, targetBranch);
      const before = bState.slides.length;
      bState.slides = bState.slides.filter(s => s.src !== src);
      if (bState.slides.length !== before) {
        removedAny = true;
        bState.revision = (bState.revision || 1) + 1;
        bState.updatedAt = new Date().toISOString();
        bState.updatedBy = actor;
      }
    } else {
      const activeCode = (cfg.branchCode || 'SSC-BSR').toUpperCase();
      const activeState = this.getBranchState(cfg, activeCode);
      const beforeActive = activeState.slides.length;
      activeState.slides = activeState.slides.filter(s => s.src !== src);
      if (activeState.slides.length !== beforeActive) {
        removedAny = true;
        activeState.revision = (activeState.revision || 1) + 1;
        activeState.updatedAt = new Date().toISOString();
        activeState.updatedBy = actor;
      } else {
        for (const bCode of Object.keys(cfg.branches || {})) {
          const bState = cfg.branches[bCode];
          if (bState && Array.isArray(bState.slides)) {
            const before = bState.slides.length;
            bState.slides = bState.slides.filter(s => s.src !== src);
            if (bState.slides.length !== before) {
              removedAny = true;
              bState.revision = (bState.revision || 1) + 1;
              bState.updatedAt = new Date().toISOString();
              bState.updatedBy = actor;
            }
          }
        }
      }
    }

    let removedFile = false;
    if (!this.isMediaReferenced(fileName, cfg)) {
      removedFile = this.deleteMediaFile(fileName);
    }

    if (!removedAny && !removedFile) {
      throw new Error('That video was not found in the playlist.');
    }

    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;
    this.saveConfig(cfg);

    const effectiveCode = (targetBranch || cfg.branchCode || 'SSC-BSR').toUpperCase();
    AuditService.logEvent({
      actor,
      role,
      action: 'REMOVE_SIGNAGE_VIDEO',
      entityType: 'signage',
      entityId: fileName,
      details: { removedFile, branchCode: effectiveCode }
    });

    return this.broadcast(effectiveCode);
  }

  checkRevision(bState, baseRevision) {
    if (baseRevision !== undefined && baseRevision !== null && baseRevision !== '') {
      const rev = Number(baseRevision);
      if (Number.isFinite(rev) && rev !== bState.revision) {
        const err = new Error('Someone else changed the playlist. Reload to see it.');
        err.status = 409;
        err.conflict = true;
        err.currentRevision = bState.revision;
        throw err;
      }
    }
  }

  addSlide(slideData, branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    if (bState.slides.length >= MAX_SLIDES) {
      throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
    }

    const slide = sanitizeSlide(slideData);
    if (!slide) throw new Error('Invalid slide data.');

    bState.slides.push(slide);
    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'ADD_SIGNAGE_SLIDE',
      entityType: 'signage',
      entityId: slide.id,
      details: { title: slide.title, type: slide.type, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      slide,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  updateSlide(slideId, patchData, branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    const slide = bState.slides.find(s => s.id === slideId);
    if (!slide) {
      const err = new Error('Slide not found.');
      err.status = 404;
      throw err;
    }

    if (patchData.enabled !== undefined) slide.enabled = Boolean(patchData.enabled);
    if (patchData.tag !== undefined) slide.tag = clip(patchData.tag, 60) || 'INFO';
    if (patchData.title !== undefined) slide.title = clip(patchData.title, 160);
    if (patchData.subtitle !== undefined) slide.subtitle = clip(patchData.subtitle, 400);

    if (patchData.durationSec !== undefined) {
      if (patchData.durationSec === null || patchData.durationSec === '' || patchData.durationSec === 0) {
        delete slide.durationSec;
      } else {
        const sec = Number(patchData.durationSec);
        if (Number.isFinite(sec)) slide.durationSec = Math.max(3, Math.min(120, Math.round(sec)));
      }
    }

    if (patchData.startsAt !== undefined) {
      if (!patchData.startsAt) {
        delete slide.startsAt;
      } else {
        const d = new Date(patchData.startsAt);
        if (!isNaN(d.getTime())) slide.startsAt = d.toISOString();
      }
    }

    if (patchData.endsAt !== undefined) {
      if (!patchData.endsAt) {
        delete slide.endsAt;
      } else {
        const d = new Date(patchData.endsAt);
        if (!isNaN(d.getTime())) slide.endsAt = d.toISOString();
      }
    }

    if (slide.type === 'video') {
      if (patchData.muted !== undefined) slide.muted = Boolean(patchData.muted);
    } else if (slide.type === 'banner') {
      if (patchData.fit !== undefined) slide.fit = patchData.fit === 'contain' ? 'contain' : 'cover';
      if (patchData.fullScreen !== undefined) slide.fullScreen = Boolean(patchData.fullScreen);
      if (patchData.alt !== undefined) slide.alt = clip(patchData.alt, 200);
    }

    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'UPDATE_SIGNAGE_SLIDE',
      entityType: 'signage',
      entityId: slide.id,
      details: { title: slide.title, type: slide.type, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      slide,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  removeSlide(slideId, branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    const idx = bState.slides.findIndex(s => s.id === slideId);
    if (idx === -1) {
      const err = new Error('Slide not found.');
      err.status = 404;
      throw err;
    }

    const removed = bState.slides.splice(idx, 1)[0];
    let removedFile = false;

    if (removed.src && removed.src.startsWith(MEDIA_URL_PREFIX)) {
      const fileName = removed.src.slice(MEDIA_URL_PREFIX.length);
      if (!this.isMediaReferenced(fileName, cfg)) {
        removedFile = this.deleteMediaFile(fileName);
      }
    }

    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'DELETE_SIGNAGE_SLIDE',
      entityType: 'signage',
      entityId: slideId,
      details: { removedSlideId: slideId, removedFile, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      removedId: slideId,
      removedFile,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  reorderSlides(slideIds, branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    if (!Array.isArray(slideIds)) throw new Error('slideIds must be an array.');

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    const existingMap = new Map(bState.slides.map(s => [s.id, s]));
    for (const id of slideIds) {
      if (!existingMap.has(id)) {
        throw new Error(`Unknown slide ID: ${id}`);
      }
    }

    const reordered = [];
    const seen = new Set();
    for (const id of slideIds) {
      if (!seen.has(id)) {
        seen.add(id);
        reordered.push(existingMap.get(id));
      }
    }
    for (const s of bState.slides) {
      if (!seen.has(s.id)) reordered.push(s);
    }

    bState.slides = reordered;
    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'REORDER_SIGNAGE_SLIDES',
      entityType: 'signage',
      entityId: 'playlist',
      details: { count: reordered.length, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  duplicateSlide(slideId, branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    if (bState.slides.length >= MAX_SLIDES) {
      throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
    }

    const idx = bState.slides.findIndex(s => s.id === slideId);
    if (idx === -1) {
      const err = new Error('Slide not found.');
      err.status = 404;
      throw err;
    }

    const original = bState.slides[idx];
    const clone = JSON.parse(JSON.stringify(original));
    clone.id = newId(clone.type || 'slide');
    if (clone.title) {
      clone.title = clip(`${clone.title} (Salinan)`, 160);
    }

    bState.slides.splice(idx + 1, 0, clone);
    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'DUPLICATE_SIGNAGE_SLIDE',
      entityType: 'signage',
      entityId: clone.id,
      details: { originalId: slideId, cloneId: clone.id, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      slide: clone,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  copyPlaylist(fromBranch, toBranch, baseRevision = null, actor = 'Staff', role = 'admin') {
    if (!fromBranch || !toBranch) throw new Error('Both fromBranch and toBranch are required.');
    const fromCode = String(fromBranch).trim().toUpperCase();
    const toCode = String(toBranch).trim().toUpperCase();
    if (fromCode === toCode) throw new Error('Cannot copy playlist to the same branch.');

    const cfg = this.loadConfig();
    const fromBranchObj = BranchService.getBranchByCode(fromCode, { includeArchived: true });
    const toBranchObj = BranchService.getBranchByCode(toCode, { includeArchived: true });
    if (!fromBranchObj) throw new Error(`Source branch ${fromCode} does not exist.`);
    if (!toBranchObj) throw new Error(`Destination branch ${toCode} does not exist.`);

    const fromState = this.getBranchState(cfg, fromCode);
    const toState = this.getBranchState(cfg, toCode);

    this.checkRevision(toState, baseRevision);

    toState.slides = fromState.slides.map(s => {
      const cloned = JSON.parse(JSON.stringify(s));
      cloned.id = newId(cloned.type || 'slide');
      return cloned;
    });

    toState.revision = (toState.revision || 1) + 1;
    toState.updatedAt = new Date().toISOString();
    toState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'COPY_SIGNAGE_PLAYLIST',
      entityType: 'signage',
      entityId: toCode,
      details: { fromBranch: fromCode, toBranch: toCode, count: toState.slides.length }
    });

    this.broadcast(toCode);
    return {
      config: this.getConfig(toCode),
      revision: toState.revision
    };
  }

  restoreDefaultSlides(branchCode = null, baseRevision = null, actor = 'Staff', role = 'admin') {
    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    const oldSlides = bState.slides || [];
    bState.slides = JSON.parse(JSON.stringify(DEFAULT_BRANCH_STATE.slides));

    for (const old of oldSlides) {
      if (old.src && old.src.startsWith(MEDIA_URL_PREFIX)) {
        const fileName = old.src.slice(MEDIA_URL_PREFIX.length);
        if (!this.isMediaReferenced(fileName, cfg)) {
          this.deleteMediaFile(fileName);
        }
      }
    }

    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'RESTORE_SIGNAGE_DEFAULT_SLIDES',
      entityType: 'signage',
      entityId: effectiveCode,
      details: { count: bState.slides.length, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  addImage({ fileName, originalName, sizeBytes, branchCode = null, baseRevision = null }, actor = 'Staff', role = 'admin') {
    const full = this.resolveMediaFile(fileName);
    if (!full || !fs.existsSync(full)) throw new Error('The uploaded image could not be found.');

    const ext = path.extname(fileName).toLowerCase();
    const inspection = inspectImage(full, ext);
    if (!inspection.valid) {
      this.deleteMediaFile(fileName);
      throw new Error(inspection.error || 'That file is not a valid image.');
    }

    if (inspection.width < 640 || inspection.height < 360) {
      this.deleteMediaFile(fileName);
      throw new Error(`Image dimensions must be at least 640x360 pixels. Uploaded image is ${inspection.width}x${inspection.height}.`);
    }

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    if (bState.slides.length >= MAX_SLIDES) {
      this.deleteMediaFile(fileName);
      throw new Error(`A playlist can hold at most ${MAX_SLIDES} items.`);
    }

    const ratio = inspection.width / inspection.height;
    let warning = null;
    if (ratio < 1.5 || ratio > 2.05) {
      warning = 'This image is not a 16:9 aspect ratio. It may appear letterboxed on widescreen displays.';
    }

    const cleanName = clip(String(originalName || '').replace(/\.[^.]+$/, ''), 120) || 'Banner';
    const slide = sanitizeSlide({
      id: newId('banner'),
      enabled: true,
      type: 'banner',
      tag: 'PROMO',
      title: cleanName,
      subtitle: '',
      src: `${MEDIA_URL_PREFIX}${fileName}`,
      fit: 'cover',
      fullScreen: false,
      alt: cleanName,
      originalName: clip(originalName, 160),
      sizeBytes,
      width: inspection.width,
      height: inspection.height
    });

    bState.slides.push(slide);
    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'ADD_SIGNAGE_BANNER',
      entityType: 'signage',
      entityId: fileName,
      details: {
        originalName: slide.originalName,
        sizeBytes: slide.sizeBytes,
        width: inspection.width,
        height: inspection.height,
        branchCode: effectiveCode
      }
    });

    this.broadcast(effectiveCode);
    return {
      slide,
      warning,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  replaceSlideMedia(slideId, { fileName, originalName, sizeBytes, branchCode = null, baseRevision = null }, actor = 'Staff', role = 'admin') {
    const full = this.resolveMediaFile(fileName);
    if (!full || !fs.existsSync(full)) throw new Error('The uploaded file could not be found.');

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    this.checkRevision(bState, baseRevision);

    const slide = bState.slides.find(s => s.id === slideId);
    if (!slide) {
      this.deleteMediaFile(fileName);
      const err = new Error('Slide not found.');
      err.status = 404;
      throw err;
    }

    if (slide.type !== 'video' && slide.type !== 'banner') {
      this.deleteMediaFile(fileName);
      throw new Error(`Media cannot be replaced on a ${slide.type} slide.`);
    }

    const ext = path.extname(fileName).toLowerCase();
    let warning = null;
    let width = slide.width || 0;
    let height = slide.height || 0;

    if (slide.type === 'banner') {
      const inspection = inspectImage(full, ext);
      if (!inspection.valid) {
        this.deleteMediaFile(fileName);
        throw new Error(inspection.error || 'That file is not a valid image.');
      }
      if (inspection.width < 640 || inspection.height < 360) {
        this.deleteMediaFile(fileName);
        throw new Error(`Image dimensions must be at least 640x360 pixels. Uploaded image is ${inspection.width}x${inspection.height}.`);
      }
      const ratio = inspection.width / inspection.height;
      if (ratio < 1.5 || ratio > 2.05) {
        warning = 'This image is not a 16:9 aspect ratio. It may appear letterboxed on widescreen displays.';
      }
      width = inspection.width;
      height = inspection.height;
    } else if (slide.type === 'video') {
      if (!looksLikeVideo(full, ext)) {
        this.deleteMediaFile(fileName);
        throw new Error('That file is not a valid MP4 or WebM video.');
      }
    }

    const oldSrc = slide.src;
    slide.src = `${MEDIA_URL_PREFIX}${fileName}`;
    slide.originalName = clip(originalName, 160);
    slide.sizeBytes = sizeBytes;
    if (slide.type === 'banner') {
      slide.width = width;
      slide.height = height;
    }

    if (oldSrc && oldSrc.startsWith(MEDIA_URL_PREFIX)) {
      const oldFileName = oldSrc.slice(MEDIA_URL_PREFIX.length);
      if (!this.isMediaReferenced(oldFileName, cfg)) {
        this.deleteMediaFile(oldFileName);
      }
    }

    bState.revision = (bState.revision || 1) + 1;
    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'REPLACE_SIGNAGE_SLIDE_MEDIA',
      entityType: 'signage',
      entityId: slide.id,
      details: { slideId: slide.id, fileName, sizeBytes, branchCode: effectiveCode }
    });

    this.broadcast(effectiveCode);
    return {
      slide,
      warning,
      config: this.getConfig(effectiveCode),
      revision: bState.revision
    };
  }

  callTicket({ ticket, room = 'Bilik Rawatan 1', doctor = null, popUpcoming = false, branchCode = null }, actor = 'Staff', role = 'admin') {
    if (!ticket) throw new Error('Ticket number is required to call queue.');

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    const cleanTicket = sanitizeTicket(ticket);
    const cleanRoom = clip(room, 80) || 'Bilik Rawatan 1';
    const cleanDoctor = doctor ? clip(doctor, 160) : null;

    bState.queue = bState.queue || { currentCall: null, upcoming: [] };
    bState.queue.currentCall = {
      ticket: cleanTicket,
      room: cleanRoom,
      doctor: cleanDoctor,
      calledAt: new Date().toISOString()
    };

    if (popUpcoming && Array.isArray(bState.queue.upcoming) && bState.queue.upcoming.length > 0) {
      const matchIdx = bState.queue.upcoming.findIndex(u => String(u.ticket).toUpperCase() === cleanTicket);
      if (matchIdx !== -1) bState.queue.upcoming.splice(matchIdx, 1);
    }

    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'CALL_SIGNAGE_TICKET',
      entityType: 'queue',
      entityId: cleanTicket,
      details: { ticket: cleanTicket, room: cleanRoom, doctor: cleanDoctor, branchCode: effectiveCode }
    });

    return this.broadcast(effectiveCode);
  }

  callNext(roomOrOptions = 'Bilik Rawatan 1', maybeDoctor = null, maybeActor = 'Staff', maybeRole = 'admin') {
    let room = 'Bilik Rawatan 1';
    let doctor = null;
    let branchCode = null;
    let actor = 'Staff';
    let role = 'admin';

    if (roomOrOptions && typeof roomOrOptions === 'object') {
      room = roomOrOptions.room || 'Bilik Rawatan 1';
      doctor = roomOrOptions.doctor || null;
      branchCode = roomOrOptions.branchCode || null;
      actor = maybeDoctor || 'Staff';
      role = maybeActor || 'admin';
    } else {
      room = roomOrOptions || 'Bilik Rawatan 1';
      doctor = maybeDoctor;
      actor = maybeActor || 'Staff';
      role = maybeRole || 'admin';
    }

    const cfg = this.loadConfig();
    const effectiveCode = (branchCode || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    const upcoming = (bState.queue && Array.isArray(bState.queue.upcoming)) ? bState.queue.upcoming : [];
    if (upcoming.length === 0) {
      throw new Error('No pending tickets in the upcoming queue.');
    }

    const next = upcoming[0];
    return this.callTicket({
      ticket: next.ticket,
      room: next.room || room,
      doctor: doctor || bState.queue.currentCall?.doctor || null,
      popUpcoming: true,
      branchCode: effectiveCode
    }, actor, role);
  }

  updateUpcoming(upcomingList = [], branchCodeOrActor = null, maybeActor = 'Staff', maybeRole = 'admin') {
    if (!Array.isArray(upcomingList)) throw new Error('upcomingList must be an array.');
    if (upcomingList.length > 100) throw new Error('The waiting list can hold at most 100 tickets.');

    let targetBranch = null;
    let actor = 'Staff';
    let role = 'admin';

    if (typeof branchCodeOrActor === 'string') {
      const clean = branchCodeOrActor.trim().toUpperCase();
      if (/^[A-Z0-9-]{2,12}$/.test(clean)) {
        targetBranch = clean;
        actor = maybeActor || 'Staff';
        role = maybeRole || 'admin';
      } else {
        actor = branchCodeOrActor;
        role = maybeRole || 'admin';
      }
    }

    const cfg = this.loadConfig();
    const effectiveCode = (targetBranch || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    bState.queue = bState.queue || { currentCall: null, upcoming: [] };
    const seen = new Set();
    bState.queue.upcoming = upcomingList
      .filter(item => item && item.ticket)
      .map(item => ({
        ticket: sanitizeTicket(item.ticket),
        room: clip(item.room, 80) || 'Kaunter Saringan'
      }))
      .filter(item => (seen.has(item.ticket) ? false : seen.add(item.ticket)));

    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'UPDATE_SIGNAGE_UPCOMING_QUEUE',
      entityType: 'queue',
      entityId: 'upcoming',
      details: { count: bState.queue.upcoming.length, branchCode: effectiveCode }
    });

    return this.broadcast(effectiveCode);
  }

  clearQueue(clearCurrentCall = false, branchCodeOrActor = null, maybeActor = 'Staff', maybeRole = 'admin') {
    let targetBranch = null;
    let actor = 'Staff';
    let role = 'admin';

    if (typeof branchCodeOrActor === 'string') {
      const clean = branchCodeOrActor.trim().toUpperCase();
      if (/^[A-Z0-9-]{2,12}$/.test(clean)) {
        targetBranch = clean;
        actor = maybeActor || 'Staff';
        role = maybeRole || 'admin';
      } else {
        actor = branchCodeOrActor;
        role = maybeRole || 'admin';
      }
    }

    const cfg = this.loadConfig();
    const effectiveCode = (targetBranch || cfg.branchCode || 'SSC-BSR').toUpperCase();
    const bState = this.getBranchState(cfg, effectiveCode);

    bState.queue = bState.queue || {};
    bState.queue.upcoming = [];
    if (clearCurrentCall) {
      bState.queue.currentCall = null;
    }

    bState.updatedAt = new Date().toISOString();
    bState.updatedBy = actor;
    cfg.updatedAt = new Date().toISOString();
    cfg.updatedBy = actor;

    this.saveConfig(cfg);

    AuditService.logEvent({
      actor,
      role,
      action: 'CLEAR_SIGNAGE_QUEUE',
      entityType: 'queue',
      entityId: 'all',
      details: { clearCurrentCall, branchCode: effectiveCode }
    });

    return this.broadcast(effectiveCode);
  }
}

module.exports = new SignageService();
module.exports.MEDIA_URL_PREFIX = MEDIA_URL_PREFIX;
module.exports.MEDIA_FILE_PATTERN = MEDIA_FILE_PATTERN;

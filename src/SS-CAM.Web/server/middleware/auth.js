const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const config = require('../config');
const AuditService = require('../services/AuditService');

// Granular RBAC Permissions Map (Canonical Roles: Designer, Copywriter, Manager, Admin)
const ROLE_PERMISSIONS = {
  designer: [
    'project:view', 'project:create',
    'brief:view',
    'direction:view',
    'copy:view',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment',
    'team:view'
  ],
  copywriter: [
    'project:view', 'project:create',
    'brief:view',
    'direction:view',
    'copy:view', 'copy:draft', 'copy:submit',
    'deliverable:view', 'deliverable:comment',
    'team:view'
  ],
  manager: [
    'project:view', 'project:create', 'project:edit', 'project:assign',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view'
  ],
  admin: [
    'project:view', 'project:create', 'project:edit', 'project:assign', 'project:archive',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:draft', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view',
    'admin:users', 'admin:roles', 'admin:companies', 'admin:system', 'admin:projects', 'admin:system_audit'
  ],
  // Legacy / Title Aliases
  user: [
    'project:view', 'project:create',
    'brief:view',
    'direction:view',
    'copy:view',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment',
    'team:view'
  ],
  Designer: [
    'project:view', 'project:create',
    'brief:view',
    'direction:view',
    'copy:view',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment',
    'team:view'
  ],
  Copywriter: [
    'project:view', 'project:create',
    'brief:view',
    'direction:view',
    'copy:view', 'copy:draft', 'copy:submit',
    'deliverable:view', 'deliverable:comment',
    'team:view'
  ],
  Manager: [
    'project:view', 'project:create', 'project:edit', 'project:assign',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view'
  ],
  Admin: [
    'project:view', 'project:create', 'project:edit', 'project:assign', 'project:archive',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:draft', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view',
    'admin:users', 'admin:roles', 'admin:companies', 'admin:system', 'admin:projects', 'admin:system_audit'
  ],
  Administrator: [
    'project:view', 'project:create', 'project:edit', 'project:assign', 'project:archive',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:draft', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:upload', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view',
    'admin:users', 'admin:roles', 'admin:companies', 'admin:system', 'admin:projects', 'admin:system_audit'
  ],
  CEO: [
    'project:view', 'project:create', 'project:edit', 'project:assign', 'project:archive',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view',
    'admin:system_audit'
  ],
  CreativeManager: [
    'project:view', 'project:create', 'project:edit', 'project:assign',
    'brief:view', 'brief:edit',
    'direction:view', 'direction:edit',
    'copy:view', 'copy:review', 'copy:approve',
    'deliverable:view', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'team:view', 'team:manage_workload', 'report:view'
  ],
  SalesManager: [
    'project:view', 'project:create',
    'brief:view',
    'deliverable:view', 'deliverable:comment', 'deliverable:approve', 'deliverable:revision',
    'report:view'
  ]
};

function getUserRoles(user) {
  if (!user) return ['Designer'];
  if (Array.isArray(user.roles) && user.roles.length > 0) return user.roles;
  if (Array.isArray(user.role) && user.role.length > 0) return user.role;
  if (typeof user.role === 'string' && user.role.trim()) {
    const split = user.role.split(/[,/]/).map(r => r.trim()).filter(Boolean);
    if (split.length > 0) return split;
  }
  return ['Designer'];
}

function getUserPermissions(user) {
  const roles = getUserRoles(user);
  const permSet = new Set();
  
  // Base default view permissions for all staff
  ['project:view', 'brief:view', 'direction:view', 'copy:view', 'deliverable:view', 'team:view'].forEach(p => permSet.add(p));

  roles.forEach(r => {
    const raw = r.trim();
    const low = raw.toLowerCase();
    
    // Direct match
    const perms = ROLE_PERMISSIONS[raw] || ROLE_PERMISSIONS[low] || [];
    perms.forEach(p => permSet.add(p));
    
    // Canonical role matching for admin
    if (low === 'admin' || low === 'administrator') {
      (ROLE_PERMISSIONS.admin || []).forEach(p => permSet.add(p));
    }
    if (low.includes('director') || low.includes('manager') || low.includes('lead') || low.includes('head') || low.includes('ceo') || low.includes('executive')) {
      (ROLE_PERMISSIONS.manager || []).forEach(p => permSet.add(p));
    }
    if (low.includes('designer')) {
      (ROLE_PERMISSIONS.designer || []).forEach(p => permSet.add(p));
    }
    if (low.includes('copywriter') || low.includes('writer')) {
      (ROLE_PERMISSIONS.copywriter || []).forEach(p => permSet.add(p));
    }
  });

  return Array.from(permSet);
}

// Initial Users Directory (All User IDs strictly start with SS)
const SYSTEM_USERS = [
  { id: 'SS0001', username: 'hasan', name: 'Hasan', email: 'hasan@suamisihat.com', role: 'CEO, Manager', roles: ['CEO', 'Manager'], staffId: 'SS0001', department: 'Executive Management' },
  { id: 'SS0071', username: 'gaddafi', name: 'Gaddafi', email: 'gaddafi@suamisihat.com', role: 'CEO', roles: ['CEO'], staffId: 'SS0071', department: 'Executive Management' },
  { id: 'SS0073', username: 'raihan', name: 'Raihan', email: 'raihan.suamisihat@gmail.com', role: 'SalesManager', roles: ['SalesManager'], staffId: 'SS0073', department: 'Marketing & Sales' },
  { id: 'SS0004', username: 'harussani', name: 'Harussani', email: 'harussani.suamisihat@gmail.com', role: 'Head of Creative', roles: ['Designer', 'Admin'], officialTitle: 'Head of Creative', staffId: 'SS0004', department: 'Creative Production' },
  { id: 'SS0035', username: 'haikal', name: 'Haikal', email: 'haikal.suamisihat@gmail.com', role: 'Designer', roles: ['Designer'], staffId: 'SS0035', department: 'Multimedia & Motion' },
  { id: 'SS0037', username: 'aliff', name: 'Aliff', email: 'aliffnaz.suamisihat@gmail.com', role: 'Designer', roles: ['Designer'], staffId: 'SS0037', department: 'Multimedia & Motion' },
  { id: 'SS0000', username: 'admin', name: 'System Administrator', email: 'admin@suamisihat.com', role: 'Administrator', roles: ['Administrator'], staffId: 'SS0000', department: 'IT & Infrastructure' }
];

function getPasswordStorePath() {
  const targetPath = path.join(config.DATA_DIR, 'user_passwords.json');
  // One-time migration: if target does not exist, check legacy workspace path
  if (!fs.existsSync(targetPath)) {
    try {
      const legacyDir = path.join(config.WORKSPACE_ROOT, '_Team', '_Config');
      const legacyPath = path.join(legacyDir, 'user_passwords.json');
      if (fs.existsSync(legacyPath)) {
        console.log(`[Auth] Migrating password store from legacy workspace path (${legacyPath}) to DATA_DIR (${targetPath})...`);
        fs.copyFileSync(legacyPath, targetPath);
        // Rename legacy file to preserve backup while removing active plaintext from workspace
        const backupPath = path.join(legacyDir, `user_passwords.json.migrated.${Date.now()}`);
        try {
          fs.renameSync(legacyPath, backupPath);
          console.log(`[Auth] Legacy password store archived to ${backupPath}`);
        } catch (e) {
          console.warn('[Auth] Note: Legacy password store copied; could not rename legacy file:', e.message);
        }
      }
    } catch (err) {
      console.error('[Auth] Migration from legacy workspace password store failed:', err.message);
    }
  }
  return targetPath;
}

function getStoredPasswords() {
  const pPath = getPasswordStorePath();
  if (!fs.existsSync(pPath)) return {};
  try {
    return JSON.parse(fs.readFileSync(pPath, 'utf8')) || {};
  } catch (e) {
    // Fail closed: returning {} here would let the bootstrap/update paths rewrite the
    // store with a single entry and wipe every other user's password hash.
    console.error(`[Auth] Password store is unreadable (${pPath}):`, e.message);
    throw new Error('Password store is unreadable. Restore it from backup before signing in.');
  }
}

function saveStoredPasswords(passwords) {
  const pPath = getPasswordStorePath();
  const json = JSON.stringify(passwords, null, 2);
  const tmp = `${pPath}.tmp.${Date.now()}`;
  fs.writeFileSync(tmp, json, 'utf8');
  fs.renameSync(tmp, pPath);
}

function isBcryptHash(value) {
  return typeof value === 'string' && /^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$/.test(value);
}

// bcrypt work factor. 12 is the current recommended minimum; the test suite uses a lower value for speed.
const BCRYPT_COST = process.env.NODE_ENV === 'test' ? 4 : 12;

function hashPassword(plain) {
  return bcrypt.hashSync(plain, bcrypt.genSaltSync(BCRYPT_COST));
}

function safeEqual(a, b) {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return ab.length === bb.length && crypto.timingSafeEqual(ab, bb);
}

// ─── SESSION STATE (token versions, forced password change, revoked sessions) ───────────────
// tokenVersion: bumping a person's version signs them out everywhere (password change, reset,
// suspension, role change, deletion). Stored in DATA_DIR so it survives restarts.
// mustChange: the person must choose a new password before doing anything else.
function getAuthStatePath() {
  return path.join(config.DATA_DIR, 'auth_state.json');
}

let authStateCache = null;

function loadAuthState() {
  if (authStateCache) return authStateCache;
  const statePath = getAuthStatePath();
  let state = { tokenVersions: {}, mustChange: {} };
  if (fs.existsSync(statePath)) {
    try {
      const parsed = JSON.parse(fs.readFileSync(statePath, 'utf8')) || {};
      state = {
        tokenVersions: parsed.tokenVersions && typeof parsed.tokenVersions === 'object' ? parsed.tokenVersions : {},
        mustChange: parsed.mustChange && typeof parsed.mustChange === 'object' ? parsed.mustChange : {}
      };
    } catch (e) {
      // Fail closed: an unreadable state file must not silently reset every revocation.
      console.error(`[Auth] Session state file is unreadable (${statePath}):`, e.message);
      throw new Error('Session state is unreadable. Restore data/auth_state.json from backup.');
    }
  }
  authStateCache = state;
  return state;
}

function saveAuthState() {
  if (!authStateCache) return;
  const statePath = getAuthStatePath();
  const tmp = `${statePath}.tmp.${Date.now()}`;
  fs.writeFileSync(tmp, JSON.stringify(authStateCache, null, 2), 'utf8');
  fs.renameSync(tmp, statePath);
}

function stateKey(username) {
  return String(username || '').trim().toLowerCase();
}

function getTokenVersion(username) {
  return Number(loadAuthState().tokenVersions[stateKey(username)] || 0);
}

/** Signs the person out of every device. */
function revokeUserSessions(username) {
  const key = stateKey(username);
  if (!key) return;
  const state = loadAuthState();
  state.tokenVersions[key] = Number(state.tokenVersions[key] || 0) + 1;
  saveAuthState();
}

function isMustChangePassword(username) {
  return loadAuthState().mustChange[stateKey(username)] === true;
}

function setMustChangePassword(username, value) {
  const key = stateKey(username);
  if (!key) return;
  const state = loadAuthState();
  if (value) state.mustChange[key] = true;
  else delete state.mustChange[key];
  saveAuthState();
}

// Individually signed-out sessions (token id -> expiry). Memory only: tokens last at most 12h.
const revokedTokenIds = new Map();

function revokeTokenId(jti, expSeconds) {
  if (!jti) return;
  const now = Date.now();
  for (const [id, exp] of revokedTokenIds) {
    if (exp <= now) revokedTokenIds.delete(id);
  }
  revokedTokenIds.set(jti, (expSeconds ? expSeconds * 1000 : now + 12 * 60 * 60 * 1000));
}

const TEMP_PASSWORD_ALPHABET = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** One-time password handed to a person by an admin. They must change it at first sign-in. */
function generateTemporaryPassword() {
  const groups = [];
  for (let g = 0; g < 3; g++) {
    let chunk = '';
    for (let i = 0; i < 4; i++) {
      chunk += TEMP_PASSWORD_ALPHABET[crypto.randomInt(TEMP_PASSWORD_ALPHABET.length)];
    }
    groups.push(chunk);
  }
  return groups.join('-');
}

/** Hashes any password that is still stored as plain text. Run once at startup. */
function migratePlaintextPasswords() {
  const passwords = getStoredPasswords();
  let migrated = 0;
  for (const key of Object.keys(passwords)) {
    const stored = passwords[key];
    if (typeof stored === 'string' && stored && !isBcryptHash(stored)) {
      passwords[key] = hashPassword(stored);
      migrated++;
    }
  }
  if (migrated > 0) {
    saveStoredPasswords(passwords);
    console.log(`[Auth] Hashed ${migrated} password(s) that were stored as plain text.`);
  }
  return migrated;
}

function verifyUserPassword(username, password) {
  // Reject empty, non-string, or blank passwords immediately
  if (!password || typeof password !== 'string' || password.trim() === '') {
    return false;
  }

  const passwords = getStoredPasswords();
  const userKey = (username || '').toLowerCase();
  const stored = passwords[userKey];

  // 1. If stored password entry exists
  if (stored) {
    // If already hashed with bcrypt
    if (isBcryptHash(stored)) {
      return bcrypt.compareSync(password, stored);
    }
    // If stored as legacy plaintext, check match and lazily migrate to bcrypt
    if (safeEqual(password, stored)) {
      try {
        passwords[userKey] = hashPassword(password);
        saveStoredPasswords(passwords);
      } catch (err) {
        console.error(`[Auth] Lazy migration failed for user ${userKey}:`, err.message);
      }
      return true;
    }
    return false;
  }

  // 2. Admin recovery bootstrap path (honored ONLY when NO admin account has a password configured)
  const bootstrapPassword = (process.env.ADMIN_BOOTSTRAP_PASSWORD || '').trim();
  if (bootstrapPassword && safeEqual(password, bootstrapPassword)) {
    const hasExistingAdminEntry = Object.keys(passwords).some(key => {
      const u = SYSTEM_USERS.find(su => (su.username || '').toLowerCase() === key);
      if (!u) return key === 'admin';
      const uRoles = getUserRoles(u).map(r => (r || '').trim().toLowerCase());
      return uRoles.includes('admin') || uRoles.includes('administrator');
    });

    if (!hasExistingAdminEntry) {
      const isSysAdmin = SYSTEM_USERS.some(u => {
        if ((u.username || '').toLowerCase() !== userKey) return false;
        const uRoles = getUserRoles(u).map(r => (r || '').trim().toLowerCase());
        return uRoles.includes('admin') || uRoles.includes('administrator');
      });
      if (isSysAdmin || userKey === 'admin') {
        try {
          passwords[userKey] = hashPassword(password);
          saveStoredPasswords(passwords);
          setMustChangePassword(userKey, true);
          console.log(`[Auth] Admin bootstrap password accepted and lazily hashed for ${userKey}`);
        } catch (err) {
          console.error('[Auth] Failed to persist bootstrapped admin password:', err.message);
        }
        return true;
      }
    } else {
      console.warn(`[Auth] ADMIN_BOOTSTRAP_PASSWORD ignored: an admin password entry already exists.`);
    }
  }

  return false;
}

/**
 * Sets a person's password, signs them out everywhere and cancels any pending reset links.
 * Pass { mustChange: true } when someone else chose the password (an admin), so the person
 * has to pick their own at the next sign-in.
 */
function updateUserPassword(username, newPassword, options = {}) {
  if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 10) {
    throw new Error('New password must be at least 10 characters long.');
  }

  const passwords = getStoredPasswords();
  const userKey = (username || '').toLowerCase();

  passwords[userKey] = hashPassword(newPassword);
  saveStoredPasswords(passwords);

  revokeUserSessions(userKey);
  setMustChangePassword(userKey, options.mustChange === true);
  invalidateResetTokensFor(userKey);

  return true;
}

/**
 * Signs a session token. With { mustChangePassword: true } the token is restricted:
 * authenticateToken only lets it call POST /auth/change-password.
 */
function generateToken(user, options = {}) {
  const roles = getUserRoles(user);
  const permissions = getUserPermissions(user);
  const officialTitle = user.officialTitle || (typeof user.role === 'string' ? user.role : 'Head of Creative');
  return jwt.sign(
    {
      id: user.id || user.staffId,
      username: user.username,
      name: user.name,
      officialTitle,
      role: roles.join(', '),
      roles: roles,
      staffId: user.staffId,
      department: user.department,
      permissions,
      tv: getTokenVersion(user.username),
      ...(options.mustChangePassword ? { pwc: true } : {})
    },
    config.JWT_SECRET,
    { expiresIn: config.JWT_EXPIRES_IN || '12h', algorithm: 'HS256', jwtid: crypto.randomUUID() }
  );
}

const SESSION_EXPIRED = { error: 'Your session has expired. Please sign in again.', code: 'SESSION_EXPIRED' };

// Routes a restricted (password change required) session may still call.
const RESTRICTED_SESSION_PATHS = ['/auth/change-password', '/auth/logout'];

/** Checks signature, algorithm, sign-out and token version. Returns the payload or null. */
function verifySessionToken(token, expectedType) {
  let payload;
  try {
    payload = jwt.verify(token, config.JWT_SECRET, { algorithms: ['HS256'] });
  } catch (err) {
    return null;
  }
  if ((payload.typ || 'session') !== expectedType) return null;
  if (payload.jti && revokedTokenIds.has(payload.jti)) return null;
  if (Number(payload.tv || 0) !== getTokenVersion(payload.username)) return null;
  return payload;
}

/**
 * Signed-in users only. The token must come in the Authorization header; tokens in the URL are
 * not accepted because URLs end up in logs, browser history and Referer headers.
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Please sign in to continue.' });
  }

  const user = verifySessionToken(token, 'session');
  if (!user) {
    return res.status(403).json(SESSION_EXPIRED);
  }
  // A token issued for a default-password sign-in may only be used to choose a new password.
  if (user.pwc) {
    const requested = String(req.originalUrl || '').split('?')[0];
    if (!RESTRICTED_SESSION_PATHS.some(p => requested.endsWith(p))) {
      return res.status(403).json({ error: 'Please change your password to continue.', code: 'PASSWORD_CHANGE_REQUIRED' });
    }
  }
  req.user = user;
  next();
}

// ─── MEDIA SESSION (images, downloads, live updates) ─────────────────────────────────────────
// Browsers cannot attach an Authorization header to <img>, downloads or EventSource requests.
// After sign-in the client asks for a media cookie: HttpOnly, SameSite=Strict, limited to /api,
// and only accepted by read-only media routes (authenticateMedia). It can never be used as a
// normal API session, and it is revoked together with the session.
const MEDIA_COOKIE = 'ss_media';
const MEDIA_TTL_SECONDS = 8 * 60 * 60;

function generateMediaToken(user) {
  return jwt.sign(
    { typ: 'media', id: user.id || user.staffId, staffId: user.staffId, username: user.username, name: user.name, tv: getTokenVersion(user.username) },
    config.JWT_SECRET,
    { expiresIn: MEDIA_TTL_SECONDS, algorithm: 'HS256' }
  );
}

function readCookie(req, name) {
  const header = req.headers && req.headers.cookie;
  if (!header) return null;
  for (const part of header.split(';')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    if (part.slice(0, idx).trim() === name) {
      try { return decodeURIComponent(part.slice(idx + 1).trim()); } catch (e) { return null; }
    }
  }
  return null;
}

function setMediaCookie(req, res, user) {
  const flags = ['HttpOnly', 'SameSite=Strict', 'Path=/api', `Max-Age=${MEDIA_TTL_SECONDS}`];
  if (req.secure) flags.push('Secure');
  res.append('Set-Cookie', `${MEDIA_COOKIE}=${encodeURIComponent(generateMediaToken(user))}; ${flags.join('; ')}`);
}

function clearMediaCookie(req, res) {
  const flags = ['HttpOnly', 'SameSite=Strict', 'Path=/api', 'Max-Age=0'];
  if (req.secure) flags.push('Secure');
  res.append('Set-Cookie', `${MEDIA_COOKIE}=; ${flags.join('; ')}`);
}

/** For read-only media routes: accepts a normal session header or the media cookie. */
function authenticateMedia(req, res, next) {
  const authHeader = req.headers['authorization'];
  const bearer = authHeader && authHeader.split(' ')[1];
  if (bearer) {
    const user = verifySessionToken(bearer, 'session');
    if (!user) return res.status(403).json(SESSION_EXPIRED);
    if (user.pwc) return res.status(403).json({ error: 'Please change your password to continue.', code: 'PASSWORD_CHANGE_REQUIRED' });
    req.user = user;
    return next();
  }

  const cookieToken = readCookie(req, MEDIA_COOKIE);
  if (!cookieToken) {
    return res.status(401).json({ error: 'Please sign in to continue.' });
  }
  const user = verifySessionToken(cookieToken, 'media');
  if (!user) {
    return res.status(403).json(SESSION_EXPIRED);
  }
  req.user = user;
  next();
}

function hasCanonicalRole(user, targetRole) {
  const roles = getUserRoles(user).map(r => (r || '').trim().toLowerCase());
  const target = (targetRole || '').trim().toLowerCase();
  if (target === 'admin' || target === 'administrator') {
    return roles.includes('admin') || roles.includes('administrator');
  }
  return roles.includes(target);
}

function requireRole(...allowedRoles) {
  const normalizedTargets = allowedRoles.map(r => (r || '').trim().toLowerCase());
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Please sign in to continue.' });
    }
    const userRoles = getUserRoles(req.user).map(r => (r || '').trim().toLowerCase());
    const isAllowed = userRoles.some(r => {
      if ((normalizedTargets.includes('admin') || normalizedTargets.includes('administrator')) && 
          (r === 'admin' || r === 'administrator')) {
        return true;
      }
      return normalizedTargets.includes(r);
    });

    if (!isAllowed) {
      AuditService.logEvent({
        actor: req.user?.name || req.user?.username || 'Unknown',
        role: req.user?.role || 'Unknown',
        action: 'SECURITY_ACCESS_DENIED',
        entityType: 'Endpoint',
        entityId: req.originalUrl || (req.baseUrl ? req.baseUrl + req.path : req.path),
        details: {
          method: req.method,
          path: req.originalUrl || req.path,
          requiredRoles: allowedRoles,
          userRoles
        }
      });
      return res.status(403).json({
        error: "You don't have permission to do this. Ask an admin for access.", requiredRoles: allowedRoles
      });
    }
    next();
  };
}

function requirePermission(permission) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized.' });
    }
    // Dynamic fallback so existing session tokens immediately get proper permissions
    const permissions = (Array.isArray(req.user.permissions) && req.user.permissions.length > 0)
      ? req.user.permissions
      : getUserPermissions(req.user);

    const isCanonicalAdmin = hasCanonicalRole(req.user, 'admin');

    if (!permissions.includes(permission) && !isCanonicalAdmin) {
      AuditService.logEvent({
        actor: req.user?.name || req.user?.username || 'Unknown',
        role: req.user?.role || 'Unknown',
        action: 'SECURITY_PERMISSION_DENIED',
        entityType: 'Endpoint',
        entityId: req.originalUrl || (req.baseUrl ? req.baseUrl + req.path : req.path),
        details: {
          method: req.method,
          path: req.originalUrl || req.path,
          requiredPermission: permission,
          userRoles: getUserRoles(req.user)
        }
      });
      return res.status(403).json({
        error: "You don't have permission to do this. Ask an admin for access.", requiredPermission: permission
      });
    }
    next();
  };
}

// ─── IDENTITY LOOKUP ─────────────────────────────────────────────────────────────────────────
// A person is found by username, then staff ID, then (optionally) email, then display name.
// A display name only counts when exactly one person has it, and an identifier that matches
// more than one person never resolves, so a look-alike name can never stand in for someone else.
function loadCandidateUsers() {
  let roster = [];
  try {
    const TeamService = require('../services/TeamService');
    roster = TeamService.getStaffRoster() || [];
  } catch (e) {
    roster = [];
  }
  const taken = new Set();
  roster.forEach(u => {
    if (u.username) taken.add(`u:${u.username.toLowerCase()}`);
    if (u.staffId) taken.add(`s:${u.staffId.toLowerCase()}`);
  });
  const seeds = SYSTEM_USERS.filter(u =>
    !taken.has(`u:${(u.username || '').toLowerCase()}`) && !taken.has(`s:${(u.staffId || u.id || '').toLowerCase()}`)
  );
  return roster.concat(seeds);
}

function resolveUser(identifier, options = {}) {
  if (!identifier || typeof identifier !== 'string') return null;
  const key = identifier.trim().toLowerCase();
  if (!key || key.length > 200) return null;

  const users = loadCandidateUsers();
  const same = value => typeof value === 'string' && value.trim().toLowerCase() === key;
  const only = list => (list.length === 1 ? list[0] : null);

  const byUsername = users.filter(u => same(u.username));
  if (byUsername.length > 0) return only(byUsername);

  const byStaffId = users.filter(u => same(u.staffId) || same(u.id));
  if (byStaffId.length > 0) return only(byStaffId);

  if (options.allowEmail) {
    const byEmail = users.filter(u => same(u.email));
    if (byEmail.length > 0) return only(byEmail);
  }

  return only(users.filter(u => same(u.name)));
}

/** Sign-in lookup: username, staff ID or name (not email). */
function findLoginUser(identifier) {
  return resolveUser(identifier, { allowEmail: false });
}

/** Password reset / general lookup: also accepts the registered email. */
function findUserByIdentifier(identifier) {
  return resolveUser(identifier, { allowEmail: true });
}

/** Finds the person a session belongs to. The staff ID in the token is the identity; display names are never used. */
function findUserForSession(sessionUser) {
  if (!sessionUser) return null;
  const staffId = String(sessionUser.staffId || sessionUser.id || '').trim().toLowerCase();
  const username = String(sessionUser.username || '').trim().toLowerCase();
  const users = loadCandidateUsers();
  if (staffId) {
    const match = users.find(u => String(u.staffId || u.id || '').toLowerCase() === staffId);
    if (match) return match;
  }
  if (username) {
    return users.find(u => String(u.username || '').toLowerCase() === username) || null;
  }
  return null;
}

/**
 * Returns a plain-language message when a name, username or email already belongs to someone
 * else, or null when it is free. exceptStaffId is the person being edited.
 */
function findIdentityConflict({ name, username, email } = {}, exceptStaffId = '') {
  const except = String(exceptStaffId || '').trim().toLowerCase();
  const others = loadCandidateUsers().filter(u => String(u.staffId || u.id || '').toLowerCase() !== except);
  const norm = v => (typeof v === 'string' ? v.trim().toLowerCase() : '');

  const checks = [
    ['name', norm(name), u => [norm(u.name), norm(u.username)]],
    ['username', norm(username), u => [norm(u.username), norm(u.name)]],
    ['email', norm(email), u => [norm(u.email)]]
  ];
  for (const [label, value, pick] of checks) {
    if (!value) continue;
    if (others.some(u => pick(u).includes(value))) {
      return `That ${label} is already used by another team member.`;
    }
  }
  return null;
}

// ─── PASSWORD RESET LINKS ────────────────────────────────────────────────────────────────────
function getPasswordResetsPath() {
  return path.join(config.DATA_DIR, 'password_resets.json');
}

function getPasswordResets() {
  const targetPath = getPasswordResetsPath();
  if (!fs.existsSync(targetPath)) return {};
  try {
    return JSON.parse(fs.readFileSync(targetPath, 'utf8')) || {};
  } catch (e) {
    console.error('[Auth] Failed to parse password_resets.json:', e.message);
    return {};
  }
}

function savePasswordResets(resets) {
  const targetPath = getPasswordResetsPath();
  const tempPath = `${targetPath}.tmp.${Date.now()}`;
  try {
    fs.writeFileSync(tempPath, JSON.stringify(resets, null, 2), 'utf8');
    fs.renameSync(tempPath, targetPath);
  } catch (e) {
    console.error('[Auth] Failed to save password_resets.json:', e.message);
    try { if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath); } catch (_) {}
  }
}

// Reset links are stored as a SHA-256 digest, so a leaked data file cannot be used to reset accounts.
function hashResetToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

function invalidateResetTokensFor(username) {
  const key = stateKey(username);
  if (!key || !fs.existsSync(getPasswordResetsPath())) return;
  const resets = getPasswordResets();
  let changed = false;
  for (const id of Object.keys(resets)) {
    if (resets[id] && stateKey(resets[id].username) === key) {
      delete resets[id];
      changed = true;
    }
  }
  if (changed) savePasswordResets(resets);
}

function createPasswordResetToken(identifier) {
  const user = findUserByIdentifier(identifier);
  // Suspended accounts cannot start a reset. The caller still answers generically.
  if (!user || user.active === false) return null;

  const resets = getPasswordResets();
  const now = Date.now();

  // Purge expired tokens and any earlier link for this person: only the newest link works.
  for (const t of Object.keys(resets)) {
    if (!resets[t] || resets[t].expiresAt < now || stateKey(resets[t].username) === stateKey(user.username)) {
      delete resets[t];
    }
  }

  const token = crypto.randomBytes(32).toString('hex');
  resets[hashResetToken(token)] = {
    username: user.username,
    email: user.email,
    staffId: user.staffId || user.id,
    expiresAt: now + (30 * 60 * 1000), // 30 minutes
    createdAt: new Date().toISOString()
  };

  savePasswordResets(resets);
  return { user, token };
}

function verifyPasswordResetToken(token) {
  if (!token || typeof token !== 'string') return { valid: false, error: 'Token is required' };
  const resets = getPasswordResets();
  const id = hashResetToken(token);
  const entry = resets[id];
  if (!entry) return { valid: false, error: 'Invalid or expired reset token' };

  if (Date.now() > entry.expiresAt) {
    delete resets[id];
    savePasswordResets(resets);
    return { valid: false, error: 'Reset token has expired (30 minute limit). Please request a new link.' };
  }

  // A suspended or removed account can no longer use an old link.
  const user = findUserByIdentifier(entry.staffId || entry.username);
  if (!user || user.active === false) {
    delete resets[id];
    savePasswordResets(resets);
    return { valid: false, error: 'Invalid or expired reset token' };
  }

  return { valid: true, username: entry.username, email: entry.email };
}

function resetPasswordWithToken(token, newPassword) {
  const check = verifyPasswordResetToken(token);
  if (!check.valid) return { success: false, error: check.error };

  if (!newPassword || typeof newPassword !== 'string' || newPassword.trim().length < 10) {
    return { success: false, error: 'New password must be at least 10 characters long' };
  }

  // Also clears every pending reset link for this person and signs them out everywhere.
  const updated = updateUserPassword(check.username, newPassword.trim());
  if (!updated) {
    return { success: false, error: 'Failed to update password for user' };
  }

  return { success: true, username: check.username };
}

module.exports = {
  SYSTEM_USERS,
  ROLE_PERMISSIONS,
  getUserRoles,
  getUserPermissions,
  hasCanonicalRole,
  getPasswordStorePath,
  getStoredPasswords,
  verifyUserPassword,
  updateUserPassword,
  migratePlaintextPasswords,
  generateTemporaryPassword,
  isMustChangePassword,
  setMustChangePassword,
  revokeUserSessions,
  revokeTokenId,
  findLoginUser,
  findUserByIdentifier,
  findUserForSession,
  findIdentityConflict,
  getPasswordResetsPath,
  getPasswordResets,
  createPasswordResetToken,
  verifyPasswordResetToken,
  resetPasswordWithToken,
  generateToken,
  authenticateToken,
  authenticateMedia,
  setMediaCookie,
  clearMediaCookie,
  requirePermission,
  requireRole
};

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
    return {};
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
    if (password === stored) {
      try {
        const salt = bcrypt.genSaltSync(10);
        passwords[userKey] = bcrypt.hashSync(password, salt);
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
  if (bootstrapPassword && password === bootstrapPassword) {
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
          const salt = bcrypt.genSaltSync(10);
          passwords[userKey] = bcrypt.hashSync(password, salt);
          saveStoredPasswords(passwords);
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

function updateUserPassword(username, newPassword) {
  if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 10) {
    throw new Error('New password must be at least 10 characters long.');
  }

  const passwords = getStoredPasswords();
  const userKey = (username || '').toLowerCase();

  const salt = bcrypt.genSaltSync(10);
  passwords[userKey] = bcrypt.hashSync(newPassword, salt);
  saveStoredPasswords(passwords);

  return true;
}

function generateToken(user) {
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
      permissions
    },
    config.JWT_SECRET,
    { expiresIn: config.JWT_EXPIRES_IN || '12h' }
  );
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = (authHeader && authHeader.split(' ')[1]) || req.query.token;

  if (!token) {
    return res.status(401).json({ error: 'Authentication required. Please log in.' });
  }

  jwt.verify(token, config.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Session expired or invalid token.' });
    }
    req.user = user;
    next();
  });
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
      return res.status(401).json({ error: 'Authentication required. Please log in.' });
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
        error: `Access Denied. Required role: [${allowedRoles.join(', ')}]. Your role: '${req.user.role}'`
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
        error: `Permission Denied. Required: '${permission}'. Your role: '${req.user.role}'`
      });
    }
    next();
  };
}

function findUserByIdentifier(identifier) {
  if (!identifier || typeof identifier !== 'string') return null;
  const searchKey = identifier.trim().toLowerCase();
  
  let staffRoster = [];
  try {
    const TeamService = require('../services/TeamService');
    staffRoster = TeamService.getStaffRoster() || [];
  } catch (e) {
    staffRoster = [];
  }

  // Check live staff roster first
  let user = staffRoster.find(u =>
    (u.username && u.username.toLowerCase() === searchKey) ||
    (u.email && u.email.toLowerCase() === searchKey) ||
    (u.name && u.name.toLowerCase() === searchKey) ||
    (u.staffId && u.staffId.toLowerCase() === searchKey)
  );

  // Fallback to SYSTEM_USERS
  if (!user) {
    user = SYSTEM_USERS.find(u =>
      (u.username && u.username.toLowerCase() === searchKey) ||
      (u.email && u.email.toLowerCase() === searchKey) ||
      (u.name && u.name.toLowerCase() === searchKey) ||
      (u.id && u.id.toLowerCase() === searchKey) ||
      (u.staffId && u.staffId.toLowerCase() === searchKey)
    );
  }

  return user || null;
}

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

function createPasswordResetToken(identifier) {
  const user = findUserByIdentifier(identifier);
  if (!user) return null;

  const resets = getPasswordResets();
  const now = Date.now();

  // Purge expired tokens
  for (const t of Object.keys(resets)) {
    if (!resets[t] || resets[t].expiresAt < now) {
      delete resets[t];
    }
  }

  const token = crypto.randomBytes(32).toString('hex');
  resets[token] = {
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
  const entry = resets[token];
  if (!entry) return { valid: false, error: 'Invalid or expired reset token' };

  if (Date.now() > entry.expiresAt) {
    delete resets[token];
    savePasswordResets(resets);
    return { valid: false, error: 'Reset token has expired (30 minute limit). Please request a new link.' };
  }

  return { valid: true, username: entry.username, email: entry.email };
}

function resetPasswordWithToken(token, newPassword) {
  const check = verifyPasswordResetToken(token);
  if (!check.valid) return { success: false, error: check.error };

  if (!newPassword || typeof newPassword !== 'string' || newPassword.trim().length < 8) {
    return { success: false, error: 'New password must be at least 8 characters long' };
  }

  const updated = updateUserPassword(check.username, newPassword.trim());
  if (!updated) {
    return { success: false, error: 'Failed to update password for user' };
  }

  // Remove the consumed token
  const resets = getPasswordResets();
  delete resets[token];
  savePasswordResets(resets);

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
  findUserByIdentifier,
  getPasswordResetsPath,
  getPasswordResets,
  createPasswordResetToken,
  verifyPasswordResetToken,
  resetPasswordWithToken,
  generateToken,
  authenticateToken,
  requirePermission,
  requireRole
};

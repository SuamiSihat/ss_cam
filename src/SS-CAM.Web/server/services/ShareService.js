const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const config = require('../config');
const WorkspaceService = require('./WorkspaceService');
const DeliverableService = require('./DeliverableService');

const ALLOWED_PERMISSIONS = ['view_only', 'review_approve'];
const DEFAULT_EXPIRY_DAYS = 14;
const MAX_EXPIRY_DAYS = 30;
// Access statistics are written at most this often per link, so browsing a gallery does not rewrite the file for every image.
const STATS_WRITE_INTERVAL_MS = 60 * 1000;

class ShareService {
  constructor() {
    this.memoryTokens = new Map();
    this._loadedStamp = null;
  }

  getTokensFilePath() {
    const root = WorkspaceService.workspaceRoot || config.WORKSPACE_ROOT;
    const teamDir = path.join(root, '_Team');
    if (!fs.existsSync(teamDir)) {
      try { fs.mkdirSync(teamDir, { recursive: true }); } catch (e) {
        console.debug('[ShareService] Failed to create teamDir:', e.message);
      }
    }
    return path.join(teamDir, 'share-tokens.json');
  }

  loadTokens() {
    const filePath = this.getTokensFilePath();
    if (fs.existsSync(filePath)) {
      try {
        // Re-read only when the file changed (it lives on a network share).
        const stat = fs.statSync(filePath);
        const stamp = `${filePath}|${stat.mtimeMs}|${stat.size}`;
        if (stamp !== this._loadedStamp) {
          const raw = fs.readFileSync(filePath, 'utf8');
          const parsed = JSON.parse(raw);
          if (Array.isArray(parsed)) {
            this.memoryTokens.clear();
            for (const item of parsed) {
              this.memoryTokens.set(item.token, item);
            }
          }
          this._loadedStamp = stamp;
        }
      } catch (err) {
        console.warn('[ShareService] Could not read share-tokens.json:', err.message);
      }
    }
    return Array.from(this.memoryTokens.values());
  }

  saveTokens() {
    const filePath = this.getTokensFilePath();
    const list = Array.from(this.memoryTokens.values());
    const json = JSON.stringify(list, null, 2);
    try {
      const tmp = `${filePath}.tmp.${Date.now()}`;
      fs.writeFileSync(tmp, json, 'utf8');
      try {
        fs.renameSync(tmp, filePath);
      } catch (renameErr) {
        // Network share lock fallback
        fs.writeFileSync(filePath, json, 'utf8');
        try { fs.unlinkSync(tmp); } catch (e) { /* temp file already gone */ }
      }
      const stat = fs.statSync(filePath);
      this._loadedStamp = `${filePath}|${stat.mtimeMs}|${stat.size}`;
    } catch (err) {
      console.warn('[ShareService] Could not save share-tokens.json:', err.message);
    }
  }

  /** Lifetime in days: a whole number from 1 to 30. Anything else falls back to the default. Links never last forever. */
  normalizeExpiryDays(value) {
    const days = Math.floor(Number(value));
    if (!Number.isFinite(days) || days < 1) return DEFAULT_EXPIRY_DAYS;
    return Math.min(days, MAX_EXPIRY_DAYS);
  }

  createShareToken({
    projectId,
    deliverableId = null,
    createdBy = 'Designer',
    createdByStaffId = '',
    expiresInDays = DEFAULT_EXPIRY_DAYS,
    permissions = 'review_approve', // 'view_only' | 'review_approve'
    note = ''
  }) {
    if (!ALLOWED_PERMISSIONS.includes(permissions)) {
      throw new Error('Choose either "View only" or "Review and sign off" for this link.');
    }
    this.loadTokens();
    const project = WorkspaceService.getProjectById(projectId);
    if (!project) {
      throw new Error(`Project "${projectId}" not found.`);
    }

    const token = crypto.randomBytes(24).toString('base64url');
    const createdAt = new Date();
    const days = this.normalizeExpiryDays(expiresInDays);
    const expiresAt = new Date(createdAt.getTime() + days * 24 * 60 * 60 * 1000).toISOString();

    const tokenRecord = {
      token,
      projectId: project.id,
      jobId: project.jobId || project.id,
      projectTitle: project.title,
      brand: project.brand || 'SS',
      deliverableId,
      createdBy,
      createdByStaffId,
      permissions,
      note: String(note || '').slice(0, 500),
      createdAt: createdAt.toISOString(),
      expiresAt,
      active: true,
      accessCount: 0,
      lastAccessedAt: null
    };

    this.memoryTokens.set(token, tokenRecord);
    this.saveTokens();

    return tokenRecord;
  }

  /**
   * Checks a link without any side effects or heavy work: is it active, unexpired and attached to a
   * project that still exists? Used for every file, comment and decision request on a share link.
   * Returns { record, project } or null.
   */
  resolveToken(token) {
    if (!token || typeof token !== 'string' || token.length > 200) return null;
    this.loadTokens();
    const record = this.memoryTokens.get(token);
    if (!record || !record.active) return null;

    if (record.expiresAt && new Date() > new Date(record.expiresAt)) {
      record.active = false;
      this.saveTokens();
      return null;
    }

    const project = WorkspaceService.getProjectById(record.projectId);
    if (!project) return null;
    return { record, project };
  }

  /** Is this file inside the project the link was made for (and, for a single-file link, that file)? */
  isPathInScope(scope, filePath) {
    if (!scope || !filePath) return false;
    try {
      const projectRoot = fs.realpathSync(scope.project.fullPath);
      const target = fs.realpathSync(filePath);
      const rootWithSep = projectRoot.endsWith(path.sep) ? projectRoot : projectRoot + path.sep;
      if (!target.startsWith(rootWithSep)) return false;
    } catch (e) {
      return false;
    }

    const only = scope.record.deliverableId;
    if (!only) return true;
    const rootPath = WorkspaceService.workspaceRoot || config.WORKSPACE_ROOT;
    const encodedId = Buffer.from(path.relative(rootPath, filePath).replace(/\\/g, '/')).toString('base64url');
    return only === encodedId || only === path.basename(filePath);
  }

  /** May this link act on the given deliverable? Single-file links only cover their own file. */
  isDeliverableInScope(scope, deliverableId) {
    const only = scope.record.deliverableId;
    if (only) return !deliverableId || deliverableId === only;
    if (!deliverableId) return true;
    const all = DeliverableService.getProjectDeliverables(scope.project.fullPath);
    return all.some(d => d.id === deliverableId || d.filename === deliverableId);
  }

  /** Comments a guest may see: their own side of the conversation, never internal staff notes. */
  publicComments(comments) {
    return (Array.isArray(comments) ? comments : []).filter(c => c && c.authorRole === 'Client Reviewer');
  }

  /** Full review page payload for a share link. Counts as one visit. */
  validateToken(token) {
    const scope = this.resolveToken(token);
    if (!scope) return null;
    const { record, project } = scope;

    // Record the visit, but do not rewrite the file on every request.
    const now = Date.now();
    const last = record.lastAccessedAt ? new Date(record.lastAccessedAt).getTime() : 0;
    record.accessCount = (record.accessCount || 0) + 1;
    if (now - last > STATS_WRITE_INTERVAL_MS) {
      record.lastAccessedAt = new Date(now).toISOString();
      this.saveTokens();
    }

    let deliverables = DeliverableService.getProjectDeliverables(project.fullPath);
    if (record.deliverableId) {
      deliverables = deliverables.filter(d => d.id === record.deliverableId || d.filename === record.deliverableId);
    }
    deliverables.sort((a, b) => (a.filename || '').localeCompare(b.filename || '', undefined, { numeric: true, sensitivity: 'base' }));

    // File links point back at this share link, so guests never need an account and the
    // staff-only /api/deliverables/* routes stay closed.
    const base = `/api/public/review/${encodeURIComponent(record.token)}/file`;
    const rewrite = url => {
      if (typeof url !== 'string') return url;
      const m = url.match(/^\/api\/deliverables\/(preview|stream|download)\?id=(.+)$/);
      return m ? `${base}?mode=${m[1]}&id=${m[2]}` : url;
    };
    deliverables = deliverables.map(d => ({
      ...d,
      url: rewrite(d.url),
      previewUrl: rewrite(d.previewUrl),
      streamUrl: rewrite(d.streamUrl),
      downloadUrl: rewrite(d.downloadUrl)
    }));

    const CommentService = require('./CommentService');
    const comments = this.publicComments(CommentService.getComments(project.fullPath, project.jobId || project.id));

    return {
      shareInfo: {
        token: record.token,
        permissions: record.permissions,
        expiresAt: record.expiresAt,
        createdBy: record.createdBy,
        note: record.note
      },
      // Only what the review page shows. Internal creative direction and copy stay inside the team.
      project: {
        id: project.id,
        jobId: project.jobId || project.id,
        title: project.title,
        brand: project.brand,
        designer: project.designer,
        status: project.status,
        deadline: project.deadline,
        revision: project.revision || 1
      },
      deliverables,
      comments
    };
  }

  getProjectShareLinks(projectId) {
    this.loadTokens();
    return Array.from(this.memoryTokens.values())
      .filter(t => t.projectId === projectId && t.active)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  getRecord(token) {
    this.loadTokens();
    return this.memoryTokens.get(token) || null;
  }

  revokeToken(token) {
    this.loadTokens();
    const record = this.memoryTokens.get(token);
    if (record) {
      record.active = false;
      this.saveTokens();
      return true;
    }
    return false;
  }
}

module.exports = new ShareService();

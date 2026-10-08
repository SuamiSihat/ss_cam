const fs = require('fs');
const path = require('path');

const LOCK_FILE_NAME = '.editor_lock.json';
const DEFAULT_TTL_SECONDS = 300; // 5 minute lease

class CollisionGuardService {
  /**
   * Returns the canonical file path for the project editor lock.
   */
  static getLockFilePath(projectPath) {
    if (!projectPath) return null;
    return path.join(projectPath, LOCK_FILE_NAME);
  }

  /**
   * Helper to format human-readable elapsed duration.
   */
  static formatDuration(dateString) {
    if (!dateString) return 'recently';
    const elapsedMs = Math.max(0, Date.now() - new Date(dateString).getTime());
    const totalMinutes = Math.floor(elapsedMs / 60000);
    if (totalMinutes < 1) return 'just now';
    if (totalMinutes < 60) return `${totalMinutes}m ago`;
    const hours = Math.floor(totalMinutes / 60);
    const mins = totalMinutes % 60;
    return `${hours}h ${mins}m ago`;
  }

  /**
   * Retrieves active lock metadata if valid and not expired.
   * If the lease has exceeded its TTL, the file is automatically purged.
   */
  static getLock(projectPath) {
    const lockPath = this.getLockFilePath(projectPath);
    if (!lockPath || !fs.existsSync(lockPath)) {
      return null;
    }

    try {
      const content = fs.readFileSync(lockPath, 'utf8').replace(/^\uFEFF/, '');
      const lockInfo = JSON.parse(content);

      const heartbeat = new Date(lockInfo.HeartbeatAt || lockInfo.LockedAt).getTime();
      const ttl = (lockInfo.TtlSeconds && lockInfo.TtlSeconds > 0) ? lockInfo.TtlSeconds : DEFAULT_TTL_SECONDS;
      const elapsedSeconds = (Date.now() - heartbeat) / 1000;

      if (elapsedSeconds > ttl) {
        // Expired lease: purge orphan lock file
        try {
          fs.unlinkSync(lockPath);
        } catch (e) {
          console.debug('[CollisionGuardService] Error deleting expired lock:', e.message);
        }
        return null;
      }

      lockInfo.FormattedDuration = this.formatDuration(lockInfo.LockedAt);
      return lockInfo;
    } catch (err) {
      console.warn('[CollisionGuardService] Error parsing lock file:', err.message);
      return null;
    }
  }

  /**
   * Checks whether a project is currently locked and if it conflicts with the requesting user.
   */
  static checkLock(projectPath, userIdentifier) {
    const lock = this.getLock(projectPath);
    if (!lock) {
      return {
        isLocked: false,
        isConflict: false,
        lock: null,
        message: 'No active lock lease on project.'
      };
    }

    const currentId = (userIdentifier || '').toString().trim().toLowerCase();
    const lockEditor = (lock.Editor || '').toString().trim().toLowerCase();
    const isConflict = Boolean(currentId && lockEditor && currentId !== lockEditor);

    return {
      isLocked: true,
      isConflict,
      lock,
      message: isConflict
        ? `Project is actively edited by ${lock.EditorName || lock.Editor} on ${lock.Machine}`
        : 'Active lock held by current user.'
    };
  }

  /**
   * Acquires a project editing lease for the specified user.
   */
  static acquireLock(projectPath, user, options = {}) {
    if (!projectPath || !fs.existsSync(projectPath)) {
      return { success: false, message: 'Project path not found.' };
    }

    const existingLock = this.getLock(projectPath);
    const userId = (user && (user.username || user.name || user.id)) || 'web-user';
    const displayName = (user && (user.displayName || user.name || user.username)) || 'Web User';

    if (existingLock) {
      const existingEditor = (existingLock.Editor || '').toString().trim().toLowerCase();
      const requestingEditor = userId.toString().trim().toLowerCase();

      if (existingEditor !== requestingEditor && !options.force) {
        return {
          success: false,
          conflict: true,
          lock: existingLock,
          message: `Active lease held by ${existingLock.EditorName || existingLock.Editor} (${existingLock.Machine})`
        };
      }
    }

    const lockPath = this.getLockFilePath(projectPath);
    const nowIso = new Date().toISOString();
    const lockInfo = {
      ProjectId: options.projectId || path.basename(projectPath),
      ProjectPath: projectPath,
      Editor: userId,
      EditorName: displayName,
      Machine: options.machine || 'Web Portal',
      Platform: 'Web Portal',
      LockedAt: existingLock && existingLock.Editor === userId ? existingLock.LockedAt : nowIso,
      HeartbeatAt: nowIso,
      TtlSeconds: options.ttlSeconds || DEFAULT_TTL_SECONDS,
      ActiveFiles: options.activeFiles || []
    };

    try {
      fs.writeFileSync(lockPath, JSON.stringify(lockInfo, null, 2), 'utf8');

      // Broadcast SSE notification
      this.broadcastLockChange(projectPath, lockInfo, 'acquired');

      lockInfo.FormattedDuration = this.formatDuration(lockInfo.LockedAt);
      return { success: true, lock: lockInfo };
    } catch (err) {
      console.error('[CollisionGuardService] Error writing lock file:', err.message);
      return { success: false, message: err.message };
    }
  }

  /**
   * Renews heartbeat timestamp to keep the active lease alive.
   */
  static renewHeartbeat(projectPath, user) {
    const lock = this.getLock(projectPath);
    if (!lock) {
      return { success: false, message: 'Lock not found or expired.' };
    }

    const userId = (user && (user.username || user.name || user.id)) || 'web-user';
    if ((lock.Editor || '').toLowerCase() !== userId.toLowerCase()) {
      return { success: false, message: 'Cannot renew lease owned by another editor.' };
    }

    lock.HeartbeatAt = new Date().toISOString();
    const lockPath = this.getLockFilePath(projectPath);

    try {
      fs.writeFileSync(lockPath, JSON.stringify(lock, null, 2), 'utf8');
      return { success: true, lock };
    } catch (err) {
      return { success: false, message: err.message };
    }
  }

  /**
   * Releases an active project editing lock.
   */
  static releaseLock(projectPath, user, force = false) {
    const lockPath = this.getLockFilePath(projectPath);
    if (!lockPath || !fs.existsSync(lockPath)) {
      return { success: true, message: 'No lock present.' };
    }

    const lock = this.getLock(projectPath);
    const userId = (user && (user.username || user.name || user.id)) || 'web-user';

    if (lock && !force) {
      const lockEditor = (lock.Editor || '').toLowerCase();
      if (lockEditor !== userId.toLowerCase()) {
        return { success: false, message: 'Cannot release lock owned by another user without force.' };
      }
    }

    try {
      fs.unlinkSync(lockPath);
      this.broadcastLockChange(projectPath, null, 'released');
      return { success: true };
    } catch (err) {
      console.error('[CollisionGuardService] Error releasing lock:', err.message);
      return { success: false, message: err.message };
    }
  }

  /**
   * Supersedes/takes over an active lock from another editor.
   */
  static takeoverLock(projectPath, user, options = {}) {
    return this.acquireLock(projectPath, user, { ...options, force: true });
  }

  /**
   * Helper to broadcast lock state changes via Server-Sent Events (SSE).
   */
  static broadcastLockChange(projectPath, lockInfo, action) {
    try {
      const SseService = require('./SseService');
      if (SseService && typeof SseService.broadcast === 'function') {
        SseService.broadcast('project:lock_changed', {
          projectPath,
          projectId: lockInfo ? lockInfo.ProjectId : path.basename(projectPath),
          action,
          lock: lockInfo,
          timestamp: new Date().toISOString()
        });
      }
    } catch (e) {
      console.debug('[CollisionGuardService] SSE broadcast error:', e.message);
    }
  }
}

module.exports = CollisionGuardService;

const fs = require('fs');
const path = require('path');
const FrontmatterService = require('./FrontmatterService');
const AuditService = require('./AuditService');
const SseService = require('./SseService');

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

const DESIGN_EXTENSIONS = ['.afdesign', '.afphoto', '.afpub', '.psd', '.psb', '.ai', '.eps', '.pdf', '.svg', '.indd'];

class SnapshotService {
  getSnapshotsDir(projectFullPath) {
    const dir = path.join(projectFullPath, '.snapshots');
    if (!fs.existsSync(dir)) {
      try { fs.mkdirSync(dir, { recursive: true }); } catch (e) {
        console.debug('[SnapshotService] Failed to create snapshots dir:', e.message);
      }
    }
    return dir;
  }

  createSnapshot(projectFullPath, trigger = 'MANUAL_BACKUP', actor = 'Designer', note = '', options = {}) {
    if (!fs.existsSync(projectFullPath)) return null;

    const snapshotsDir = this.getSnapshotsDir(projectFullPath);
    const snapId = `snap_${Date.now()}`;
    const snapDir = path.join(snapshotsDir, snapId);
    fs.mkdirSync(snapDir, { recursive: true });

    let currentRevision = 1;
    let currentStatus = 'in-progress';
    const readmePath = path.join(projectFullPath, 'README.md');
    if (fs.existsSync(readmePath)) {
      try {
        fs.copyFileSync(readmePath, path.join(snapDir, 'README.md'));
        const { frontmatter } = FrontmatterService.readProjectReadme(projectFullPath);
        if (frontmatter.revision) currentRevision = frontmatter.revision;
        if (frontmatter.status) currentStatus = frontmatter.status;
      } catch (e) {
        console.debug('[SnapshotService] Read frontmatter during snapshot error:', e.message);
      }
    }

    const copyPath = path.join(projectFullPath, '03_COPYWRITING', 'COPY.md');
    if (fs.existsSync(copyPath)) {
      try {
        fs.copyFileSync(copyPath, path.join(snapDir, 'COPY.md'));
      } catch (e) {
        console.debug('[SnapshotService] Copy COPY.md during snapshot error:', e.message);
      }
    }

    // 3. Snapshot design source files from 02_SOURCE_FILES
    const sourceFiles = [];
    const sourceDir = path.join(projectFullPath, '02_SOURCE_FILES');
    if (fs.existsSync(sourceDir) && options.includeSourceFiles !== false) {
      try {
        const files = fs.readdirSync(sourceDir);
        const snapSourceDir = path.join(snapDir, '02_SOURCE_FILES');
        for (const f of files) {
          const ext = path.extname(f).toLowerCase();
          if (DESIGN_EXTENSIONS.includes(ext)) {
            const srcPath = path.join(sourceDir, f);
            const stat = fs.statSync(srcPath);
            if (stat.isFile()) {
              if (!fs.existsSync(snapSourceDir)) fs.mkdirSync(snapSourceDir, { recursive: true });
              fs.copyFileSync(srcPath, path.join(snapSourceDir, f));
              sourceFiles.push({
                name: f,
                sizeBytes: stat.size,
                sizeFormatted: formatBytes(stat.size),
                ext,
                modifiedAt: stat.mtime.toISOString()
              });
            }
          }
        }
      } catch (e) {
        console.debug('[SnapshotService] Copy 02_SOURCE_FILES error:', e.message);
      }
    }

    const meta = {
      id: snapId,
      timestamp: new Date().toISOString(),
      trigger,
      actor,
      revision: currentRevision,
      status: currentStatus,
      note: note || `Snapshot captured during ${trigger}`,
      sourceFiles
    };

    fs.writeFileSync(path.join(snapDir, 'meta.json'), JSON.stringify(meta, null, 2), 'utf8');
    return meta;
  }

  getSnapshots(projectFullPath) {
    if (!fs.existsSync(projectFullPath)) return [];
    const snapshotsDir = path.join(projectFullPath, '.snapshots');
    if (!fs.existsSync(snapshotsDir)) return [];

    const list = [];
    try {
      const entries = fs.readdirSync(snapshotsDir, { withFileTypes: true });
      for (const ent of entries) {
        if (ent.isDirectory() && ent.name.startsWith('snap_')) {
          const metaPath = path.join(snapshotsDir, ent.name, 'meta.json');
          if (fs.existsSync(metaPath)) {
            try {
              const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
              list.push(meta);
            } catch (e) {
              console.debug('[SnapshotService] Read meta.json error:', e.message);
            }
          }
        }
      }
    } catch (e) {
      console.debug('[SnapshotService] Read snapshots directory error:', e.message);
    }

    return list.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  }

  listSnapshots(projectFullPath) {
    return this.getSnapshots(projectFullPath);
  }

  rollback(projectFullPath, snapshotId, actor = 'Lead Designer') {
    if (!fs.existsSync(projectFullPath)) {
      throw new Error('Project folder does not exist.');
    }

    const snapshotsDir = path.join(projectFullPath, '.snapshots');
    const targetSnapDir = path.join(snapshotsDir, snapshotId);
    if (!fs.existsSync(targetSnapDir)) {
      throw new Error(`Snapshot "${snapshotId}" not found.`);
    }

    // 1. Create a safety pre-rollback snapshot of the current state
    this.createSnapshot(projectFullPath, 'PRE_ROLLBACK_BACKUP', actor, `Safety backup before rolling back to ${snapshotId}`);

    // 2. Restore README.md
    const snapReadme = path.join(targetSnapDir, 'README.md');
    if (fs.existsSync(snapReadme)) {
      fs.copyFileSync(snapReadme, path.join(projectFullPath, 'README.md'));
    }

    // 3. Restore COPY.md
    const snapCopy = path.join(targetSnapDir, 'COPY.md');
    const targetCopyDir = path.join(projectFullPath, '03_COPYWRITING');
    if (fs.existsSync(snapCopy)) {
      if (!fs.existsSync(targetCopyDir)) fs.mkdirSync(targetCopyDir, { recursive: true });
      fs.copyFileSync(snapCopy, path.join(targetCopyDir, 'COPY.md'));
    }

    // 4. Restore 02_SOURCE_FILES design binaries if snapshotted
    let restoredSourceFilesCount = 0;
    const snapSourceDir = path.join(targetSnapDir, '02_SOURCE_FILES');
    const targetSourceDir = path.join(projectFullPath, '02_SOURCE_FILES');
    if (fs.existsSync(snapSourceDir)) {
      if (!fs.existsSync(targetSourceDir)) fs.mkdirSync(targetSourceDir, { recursive: true });
      try {
        const snapFiles = fs.readdirSync(snapSourceDir);
        for (const sf of snapFiles) {
          fs.copyFileSync(path.join(snapSourceDir, sf), path.join(targetSourceDir, sf));
          restoredSourceFilesCount++;
        }
      } catch (e) {
        console.debug('[SnapshotService] Restore 02_SOURCE_FILES error:', e.message);
      }
    }

    // Read restored meta
    let targetMeta = { revision: 1 };
    const metaPath = path.join(targetSnapDir, 'meta.json');
    if (fs.existsSync(metaPath)) {
      try { targetMeta = JSON.parse(fs.readFileSync(metaPath, 'utf8')); } catch (e) {
        console.debug('[SnapshotService] Read restored meta.json error:', e.message);
      }
    }

    // Audit log
    const projectId = path.basename(projectFullPath);
    AuditService.logEvent({
      actor,
      role: 'Lead Designer',
      action: 'PROJECT_ROLLBACK',
      entityType: 'Project',
      entityId: projectId,
      details: {
        snapshotId,
        restoredRevision: targetMeta.revision,
        timestamp: new Date().toISOString()
      }
    });

    // Notify connected clients
    SseService.broadcast('project:updated', {
      projectId,
      action: 'rollback',
      snapshotId,
      actor
    });

    return {
      success: true,
      snapshotId,
      restoredSnapshot: targetMeta,
      restoredSourceFilesCount,
      message: `Project successfully restored to snapshot ${snapshotId}`
    };
  }
}

module.exports = new SnapshotService();

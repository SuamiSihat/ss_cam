const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const FrontmatterService = require('./FrontmatterService');
const AuditService = require('./AuditService');

class ExportService {
  /**
   * Generates a ZIP stream for an entire creative handover package.
   * @param {string} projectFullPath 
   * @param {string} projectId 
   * @param {object} res Express response stream
   * @param {object} options 
   */
  static streamProjectHandover(projectFullPath, projectId, res, options = {}) {
    if (!fs.existsSync(projectFullPath)) {
      return res.status(404).json({ error: 'Project folder not found.' });
    }

    const folderName = path.basename(projectFullPath);
    const zipFileName = `${folderName}_Handover.zip`;

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${zipFileName}"`);

    const archive = typeof archiver === 'function'
      ? archiver('zip', { zlib: { level: 9 } })
      : (archiver.ZipArchive ? new archiver.ZipArchive({ zlib: { level: 9 } }) : new archiver.Archiver('zip', { zlib: { level: 9 } }));

    archive.on('error', (err) => {
      console.error('[ExportService] Archiver error:', err.message);
      if (!res.headersSent) {
        res.status(500).json({ error: err.message });
      }
    });

    archive.pipe(res);

    const { frontmatter } = FrontmatterService.readProjectReadme(projectFullPath);
    const addedFiles = [];

    // 1. Deliverables & Production Exports
    const delivDirs = ['05_DELIVERABLES', '05_Deliverables', '04_Production', '04_Export_Packages', 'Production', '04_Final_Exports', 'Export', 'Exports', 'Final_Exports', 'Export_Packages'];
    const addedDelivPaths = new Set();
    for (const dir of delivDirs) {
      const p = path.join(projectFullPath, dir);
      if (fs.existsSync(p) && !addedDelivPaths.has(p)) {
        this.addDirectoryToArchive(archive, p, 'Deliverables', addedFiles);
        addedDelivPaths.add(p);
      }
    }
    // Also discover any directory containing 'export' or 'production' in name if none matched
    if (addedDelivPaths.size === 0) {
      try {
        const subdirs = fs.readdirSync(projectFullPath, { withFileTypes: true });
        for (const s of subdirs) {
          if (s.isDirectory()) {
            const lower = s.name.toLowerCase();
            if (lower.includes('export') || lower.includes('production') || lower.includes('deliverable')) {
              const p = path.join(projectFullPath, s.name);
              if (!addedDelivPaths.has(p)) {
                this.addDirectoryToArchive(archive, p, 'Deliverables', addedFiles);
                addedDelivPaths.add(p);
              }
            }
          }
        }
      } catch (e) {
        console.debug('[ExportService] Scan deliverables dirs error:', e.message);
      }
    }

    // 2. Mockups (optional)
    if (options.includeWip) {
      const wipDirs = ['04_WORK_IN_PROGRESS', '04_WIP', '02_Artwork_Mockup', 'Artwork Mockup', 'Mockup'];
      for (const dir of wipDirs) {
        const p = path.join(projectFullPath, dir);
        if (fs.existsSync(p)) {
          this.addDirectoryToArchive(archive, p, 'Mockups', addedFiles);
          break;
        }
      }
    }

    // 3. Copywriting
    const copyFile = path.join(projectFullPath, '03_COPYWRITING', 'COPY.md');
    if (fs.existsSync(copyFile)) {
      archive.file(copyFile, { name: 'Copywriting/COPY.md' });
      addedFiles.push('Copywriting/COPY.md');
    }

    // 4. Project Brief
    const readmeFile = path.join(projectFullPath, 'README.md');
    if (fs.existsSync(readmeFile)) {
      archive.file(readmeFile, { name: 'Project_Brief_README.md' });
      addedFiles.push('Project_Brief_README.md');
    }

    // 5. HTML Handover Summary Sheet
    const htmlSummary = this.generateHtmlSummary(folderName, frontmatter, addedFiles);
    archive.append(htmlSummary, { name: 'HANDOVER_SUMMARY.html' });

    archive.finalize();
  }

  static addDirectoryToArchive(archive, dirPath, prefix, addedFiles) {
    const walk = (current, relPrefix) => {
      const entries = fs.readdirSync(current, { withFileTypes: true });
      for (const entry of entries) {
        const name = entry.name;
        const upper = name.toUpperCase();
        const lower = name.toLowerCase();

        if (name.startsWith('.') || name.startsWith('~') || name.startsWith('@') || lower === 'thumbs.db' || lower === 'desktop.ini' || lower === '.ds_store' || upper.includes('SYNOFILE_THUMB')) continue;
        if (entry.isDirectory() && (lower === '@eadir' || lower.includes('@eadir') || lower === 'node_modules')) continue;

        const full = path.join(current, entry.name);
        const rel = path.join(relPrefix, entry.name).replace(/\\/g, '/');

        if (entry.isDirectory()) {
          walk(full, rel);
        } else {
          archive.file(full, { name: rel });
          addedFiles.push(rel);
        }
      }
    };

    walk(dirPath, prefix);
  }

  static generateHtmlSummary(projectName, frontmatter, files) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>SuamiSihat Creative Handover - ${projectName}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0A0F1D; color: #E2E8F0; margin: 0; padding: 40px; }
    .container { max-width: 800px; margin: 0 auto; background: #131B2E; border: 1px solid #1E293B; border-radius: 12px; padding: 32px; box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
    .header { border-bottom: 1px solid #1E293B; padding-bottom: 20px; margin-bottom: 24px; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; background: #043388; color: #FFFFFF; }
    h1 { color: #FFFFFF; font-size: 24px; margin: 12px 0 6px 0; }
    .meta-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin: 20px 0; background: #0A0F1D; padding: 16px; border-radius: 8px; border: 1px solid #1E293B; }
    .meta-item span { color: #94A3B8; font-size: 13px; display: block; }
    .meta-item strong { color: #F8FAFC; font-size: 15px; }
    .files-list { list-style: none; padding: 0; margin: 20px 0; }
    .files-list li { padding: 10px 14px; border-bottom: 1px solid #1E293B; font-family: monospace; font-size: 13px; color: #CBD5E1; }
    .files-list li:last-child { border-bottom: none; }
    .footer { text-align: center; color: #64748B; font-size: 12px; margin-top: 32px; border-top: 1px solid #1E293B; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">SuamiSihat Creative Handover</span>
      <h1>${projectName}</h1>
      <p style="color: #94A3B8; margin: 0;">Package Generated: ${new Date().toISOString()}</p>
    </div>

    <div class="meta-grid">
      <div class="meta-item"><span>Status</span><strong>${(frontmatter.status || 'UNKNOWN').toUpperCase()}</strong></div>
      <div class="meta-item"><span>Priority</span><strong>${(frontmatter.priority || 'NORMAL').toUpperCase()}</strong></div>
      <div class="meta-item"><span>Designer</span><strong>${frontmatter.designer || 'Unassigned'}</strong></div>
      <div class="meta-item"><span>Revision Round</span><strong>Rev ${frontmatter.revision || 0}</strong></div>
    </div>

    <h3 style="color: #FFFFFF; font-size: 16px; margin-top: 24px;">Included Asset Manifest (${files.length} items)</h3>
    <ul class="files-list">
      ${files.map(f => `<li>📁 ${f}</li>`).join('\n      ')}
    </ul>

    <div class="footer">
      SuamiSihat Creative Assets Management (SS-CAM) • Web Portal Export Service
    </div>
  </div>
</body>
</html>`;
  }

  /**
   * Batch archives multiple projects to cold storage ZIP files and records in catalog JSONL.
   * @param {string[]} projectFullPaths 
   * @param {string} archiveRoot Destination archive root (e.g. NAS /_Archive)
   * @param {object} options { copyOnly: true }
   * @param {string} operator 
   * @returns {Promise<object>} { success, projectCount, zipPath, totalBytes, catalogEntry }
   */
  static async archiveBatch(projectFullPaths, archiveRoot, options = {}, operator = 'system') {
    if (!Array.isArray(projectFullPaths) || projectFullPaths.length === 0) {
      throw new Error('No projects provided for archival.');
    }

    const config = require('../config');
    const now = new Date();
    const yyyy = now.getFullYear().toString();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const yyyymm = `${yyyy}${mm}`;
    const baseArchive = archiveRoot || config.WORKSPACE_ROOT;
    const targetDir = path.join(baseArchive, '_Archive', yyyy, yyyymm);

    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    const timestampStr = now.toISOString().replace(/[:.]/g, '-');
    const zipName = `BatchArchive_${yyyymm}_${timestampStr}.zip`;
    const zipPath = path.join(targetDir, zipName);

    const archivedProjects = [];

    await new Promise((resolve, reject) => {
      const output = fs.createWriteStream(zipPath);
      const archive = typeof archiver === 'function'
        ? archiver('zip', { zlib: { level: 9 } })
        : (archiver.ZipArchive ? new archiver.ZipArchive({ zlib: { level: 9 } }) : new archiver.Archiver('zip', { zlib: { level: 9 } }));

      output.on('close', resolve);
      archive.on('error', reject);
      archive.pipe(output);

      for (const p of projectFullPaths) {
        if (fs.existsSync(p)) {
          const folderName = path.basename(p);
          archivedProjects.push(folderName);
          archive.directory(p, folderName);
        }
      }

      archive.finalize();
    });

    const stat = fs.statSync(zipPath);
    const catalogFile = path.join(baseArchive, '_Archive', '_archive_catalog.jsonl');
    const catalogDir = path.dirname(catalogFile);
    if (!fs.existsSync(catalogDir)) {
      fs.mkdirSync(catalogDir, { recursive: true });
    }

    let reclaimedBytes = 0;
    let prunedCount = 0;

    // Destructive Move-to-Archive & Storage Pruning (v4.14.0):
    if (options.copyOnly === false && stat.size > 0) {
      for (const p of projectFullPaths) {
        if (fs.existsSync(p)) {
          try {
            const getDirSize = (dir) => {
              let sz = 0;
              const items = fs.readdirSync(dir, { withFileTypes: true });
              for (const item of items) {
                const sub = path.join(dir, item.name);
                if (item.isDirectory()) sz += getDirSize(sub);
                else {
                  try { sz += fs.statSync(sub).size; } catch (e) {}
                }
              }
              return sz;
            };
            const pSize = getDirSize(p);
            fs.rmSync(p, { recursive: true, force: true });
            reclaimedBytes += pSize;
            prunedCount++;
          } catch (delErr) {
            console.warn('[ExportService] Source project prune error:', delErr.message);
          }
        }
      }
    }

    const entry = {
      id: Math.random().toString(36).substring(2, 10),
      timestamp: now.toISOString(),
      operator,
      archivedProjects,
      projectCount: archivedProjects.length,
      zipFilePath: zipPath,
      zipSizeBytes: stat.size,
      copyOnly: options.copyOnly !== false,
      reclaimedBytes,
      prunedCount,
      success: true,
      errorMessage: null
    };

    fs.appendFileSync(catalogFile, JSON.stringify(entry) + '\n', 'utf8');

    AuditService.logEvent({
      actor: operator,
      role: 'System',
      action: 'PROJECT_BATCH_ARCHIVE',
      entityType: 'Archive',
      entityId: entry.id,
      details: {
        projectCount: archivedProjects.length,
        zipPath,
        zipSizeBytes: stat.size,
        copyOnly: options.copyOnly !== false,
        reclaimedBytes,
        prunedCount
      }
    });

    try {
      const WebhookService = require('./WebhookService');
      WebhookService.dispatch('PROJECT_ARCHIVED', {
        title: `Cold Storage Archive Created (${archivedProjects.length} Projects)`,
        description: `Archive package saved to ${zipName}. ${options.copyOnly === false ? `Pruned ${prunedCount} projects, reclaiming ${(reclaimedBytes / 1048576).toFixed(1)} MB active NAS storage.` : 'Preserved active source copies (Copy-Only mode).'}`,
        actor: operator,
        brand: 'SS',
        fileCount: archivedProjects.length,
        sizeFormatted: `${(stat.size / 1048576).toFixed(1)} MB`
      });
    } catch (whErr) {
      console.debug('[ExportService] Webhook dispatch skip:', whErr.message);
    }

    return entry;
  }

  /**
   * Transcodes a video or image deliverable via FFmpeg.
   * @param {string} sourcePath 
   * @param {string} preset 'webp' | 'avif' | 'webm' | 'gif' | 'mp4'
   * @param {string} destinationDir 
   * @returns {Promise<object>}
   */
  static async transcodeAsset(sourcePath, preset, destinationDir = null) {
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`Source file not found: ${sourcePath}`);
    }

    const ext = path.extname(sourcePath);
    const stem = path.basename(sourcePath, ext);
    const outDir = destinationDir && fs.existsSync(destinationDir) ? destinationDir : path.dirname(sourcePath);

    let suffix = '_web';
    let targetExt = '.webp';
    let ffmpegArgs = [];

    const normPreset = (preset || 'webp').toLowerCase();
    switch (normPreset) {
      case 'webp':
      case 'webp_image':
        suffix = '_web';
        targetExt = '.webp';
        ffmpegArgs = ['-y', '-hide_banner', '-i', sourcePath, '-c:v', 'libwebp', '-quality', '85'];
        break;
      case 'avif':
      case 'avif_image':
        suffix = '_web';
        targetExt = '.avif';
        ffmpegArgs = ['-y', '-hide_banner', '-i', sourcePath, '-c:v', 'libaom-av1', '-crf', '28', '-b:v', '0'];
        break;
      case 'webm':
      case 'webm_video':
        suffix = '_web';
        targetExt = '.webm';
        ffmpegArgs = ['-y', '-hide_banner', '-i', sourcePath, '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '30', '-c:a', 'libopus'];
        break;
      case 'gif':
      case 'social_gif_10s':
        suffix = '_social';
        targetExt = '.gif';
        ffmpegArgs = ['-y', '-hide_banner', '-i', sourcePath, '-t', '10', '-vf', 'fps=15,scale=480:-1:flags=lanczos'];
        break;
      case 'mp4':
      case 'mp4_compress':
        suffix = '_compressed';
        targetExt = '.mp4';
        ffmpegArgs = ['-y', '-hide_banner', '-i', sourcePath, '-c:v', 'libx264', '-crf', '23', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart'];
        break;
      default:
        throw new Error(`Unsupported transcode preset: ${preset}`);
    }

    const outputPath = path.join(outDir, `${stem}${suffix}${targetExt}`);
    ffmpegArgs.push(outputPath);

    const { spawn } = require('child_process');
    await new Promise((resolve, reject) => {
      const child = spawn('ffmpeg', ffmpegArgs);
      let stderr = '';
      child.stderr.on('data', d => { stderr += d.toString(); });
      child.on('close', code => {
        if (code === 0 && fs.existsSync(outputPath)) {
          resolve();
        } else {
          reject(new Error(`FFmpeg failed with exit code ${code}: ${stderr.slice(-300)}`));
        }
      });
      child.on('error', err => reject(err));
    });

    const stat = fs.statSync(outputPath);
    return {
      success: true,
      sourcePath,
      outputPath,
      outputSizeBytes: stat.size,
      preset: normPreset
    };
  }
}

module.exports = ExportService;

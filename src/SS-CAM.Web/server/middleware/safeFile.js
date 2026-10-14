/**
 * Safe-serving rules for files that people upload (attachments, deliverables, project assets).
 *
 * Uploads are untrusted. An SVG or HTML file can carry script, and if someone opens it directly
 * from this site that script would run with the portal's permissions. So active content is:
 *   - sandboxed with a Content-Security-Policy (no scripts, no network), and
 *   - downloaded instead of displayed when it is opened as a page (Sec-Fetch-Dest: document).
 * It still renders normally inside <img>, where scripts never run.
 */

const path = require('path');

const ACTIVE_EXTENSIONS = new Set(['.svg', '.html', '.htm', '.xhtml', '.xht', '.xml', '.shtml']);

// Types that are safe to show inline as-is.
const PLAIN_MEDIA_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.tiff',
  '.mp4', '.webm', '.mov', '.mkv', '.avi', '.mp3', '.wav', '.ogg', '.m4a', '.pdf'
]);

// Files that must never be accepted as uploads: they run code if someone opens them.
const BLOCKED_UPLOAD_EXTENSIONS = new Set([
  '.html', '.htm', '.xhtml', '.js', '.mjs', '.cjs', '.exe', '.dll', '.msi', '.bat', '.cmd', '.com',
  '.ps1', '.psm1', '.vbs', '.vbe', '.wsf', '.hta', '.scr', '.jar', '.sh', '.lnk', '.reg', '.cpl'
]);

const SANDBOX_CSP = "sandbox; default-src 'none'; style-src 'unsafe-inline'; img-src data:";

function applySafeFileHeaders(req, res, filePath, { download = false, filename } = {}) {
  const ext = path.extname(filePath).toLowerCase();
  const isActive = ACTIVE_EXTENSIONS.has(ext);

  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Uploads belong to the signed-in team; shared caches must not keep copies.
  res.setHeader('Cache-Control', 'private, max-age=3600');
  if (isActive || !PLAIN_MEDIA_EXTENSIONS.has(ext)) {
    res.setHeader('Content-Security-Policy', SANDBOX_CSP);
  }

  const openedAsPage = String(req.headers['sec-fetch-dest'] || '').toLowerCase() === 'document';
  if (download || (isActive && openedAsPage)) {
    const name = filename || path.basename(filePath);
    res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(name)}`);
  }
}

/** Returns a plain-language reason when an upload must be refused, otherwise null. */
function uploadBlockedReason(filename) {
  const ext = path.extname(String(filename || '')).toLowerCase();
  if (BLOCKED_UPLOAD_EXTENSIONS.has(ext)) {
    return `Files of type ${ext} can't be uploaded. Please zip the file first if you need to share it.`;
  }
  return null;
}

module.exports = { applySafeFileHeaders, uploadBlockedReason, ACTIVE_EXTENSIONS };

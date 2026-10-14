/**
 * Canonical project format shared by every SS-CAM client.
 * Mirrors the Windows app (ProjectCreatorPage / CategoryPresetService / ProjectStatusConstants):
 *
 *   <workspace>/<YYYY>/<YYYYMM>_<Month>/<YYYYMM>_<NNNN><Type>_<BRAND>_<Title>/
 *     01_BRIEF_ASSETS  02_SOURCE_FILES  03_COPYWRITING  04_WORK_IN_PROGRESS  05_DELIVERABLES
 *     README.md  (YAML frontmatter)
 */
const fs = require('fs');
const path = require('path');

const PROJECT_SUBFOLDERS = ['01_BRIEF_ASSETS', '02_SOURCE_FILES', '03_COPYWRITING', '04_WORK_IN_PROGRESS', '05_DELIVERABLES'];

// 'done' is kept as-is: the web dashboard shows it as Archived.
const PROJECT_STATUSES = ['backlog', 'in-progress', 'review', 'revision', 'approved', 'on-hold', 'done'];
const PROJECT_PRIORITIES = ['low', 'medium', 'high', 'urgent'];

const STATUS_ALIASES = {
  'in_progress': 'in-progress', 'inprogress': 'in-progress', 'in progress': 'in-progress', 'active': 'in-progress',
  'in_review': 'review', 'in-review': 'review', 'for_approval': 'review',
  'revision_required': 'revision', 'revision-required': 'revision', 'changes_requested': 'revision',
  'completed': 'approved',
  'on_hold': 'on-hold', 'onhold': 'on-hold', 'paused': 'on-hold',
  'todo': 'backlog', 'pending': 'backlog', 'draft': 'backlog'
};

const PRIORITY_ALIASES = { normal: 'medium', med: 'medium', critical: 'urgent' };

const MONTH_NAMES = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

const PROJECT_ID_REGEX = /^\d{6}_(\d{4})[A-Z]/i;

function normalizeProjectStatus(status, fallback = 'backlog') {
  if (!status) return fallback;
  const s = String(status).trim().toLowerCase();
  if (PROJECT_STATUSES.includes(s)) return s;
  return STATUS_ALIASES[s] || fallback;
}

function normalizePriority(priority, fallback = 'medium') {
  if (!priority) return fallback;
  const p = String(priority).trim().toLowerCase();
  if (PROJECT_PRIORITIES.includes(p)) return p;
  return PRIORITY_ALIASES[p] || fallback;
}

function getMonthContainer(workspaceRoot, date = new Date()) {
  const yyyy = String(date.getFullYear());
  const yyyymm = yyyy + String(date.getMonth() + 1).padStart(2, '0');
  return path.join(workspaceRoot, yyyy, `${yyyymm}_${MONTH_NAMES[date.getMonth()]}`);
}

function buildProjectFolderName(date, projectId, brand, title) {
  const yyyymm = String(date.getFullYear()) + String(date.getMonth() + 1).padStart(2, '0');
  // Same invalid-character rule as the Windows app, plus spaces to underscores.
  const safeTitle = String(title).trim().replace(/[\\/:*?"<>|]/g, '_').replace(/\s+/g, '_');
  return `${yyyymm}_${projectId}_${brand}_${safeTitle}`;
}

/**
 * Next sequential project ID (e.g. "0124D"): highest 4-digit ID found in the workspace + 1.
 * `existingFolderNames` should be every project folder name already known (e.g. the scan cache).
 */
function nextProjectId(existingFolderNames, typeLetter = 'D') {
  let maxId = 0;
  for (const name of existingFolderNames || []) {
    const m = PROJECT_ID_REGEX.exec(name || '');
    if (m) {
      const n = parseInt(m[1], 10);
      if (n > maxId) maxId = n;
    }
  }
  return String(maxId + 1).padStart(4, '0') + String(typeLetter || 'D').toUpperCase();
}

function createProjectFolders(projectDir) {
  for (const sub of PROJECT_SUBFOLDERS) {
    fs.mkdirSync(path.join(projectDir, sub), { recursive: true });
  }
}

module.exports = {
  PROJECT_SUBFOLDERS,
  PROJECT_STATUSES,
  PROJECT_PRIORITIES,
  normalizeProjectStatus,
  normalizePriority,
  getMonthContainer,
  buildProjectFolderName,
  nextProjectId,
  createProjectFolders
};

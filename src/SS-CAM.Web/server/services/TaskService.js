const fs = require('fs');
const path = require('path');
const config = require('../config');
const WorkspaceService = require('./WorkspaceService');
const FrontmatterService = require('./FrontmatterService');
const AuditService = require('./AuditService');
const TeamService = require('./TeamService');
const SseService = require('./SseService');
const EmailService = require('./EmailService');
const { findUserByIdentifier } = require('../middleware/auth');

function normalizeStatus(status) {
  if (!status) return 'draft';
  const s = String(status).toLowerCase().trim();
  if (['done', 'completed', 'approved', 'pass'].includes(s)) return 'done';
  if (['review', 'in_review', 'under_review', 'qa'].includes(s)) return 'review';
  if (['in-progress', 'in_progress', 'progress', 'doing', 'active', 'production'].includes(s)) return 'in-progress';
  return 'draft';
}

function normalizeRole(role, taskName = '') {
  if (role) {
    const r = String(role).toLowerCase().trim();
    if (r.includes('copy') || r.includes('content') || r.includes('script') || r.includes('writer')) return 'copywriter';
    if (r.includes('design') || r.includes('visual') || r.includes('art') || r.includes('motion')) return 'designer';
    if (r.includes('manager') || r.includes('director') || r.includes('lead')) return 'manager';
    if (r.includes('review') || r.includes('client')) return 'reviewer';
  }
  const nameLower = (taskName || '').toLowerCase();
  if (nameLower.includes('copy') || nameLower.includes('hook') || nameLower.includes('script') || nameLower.includes('angle') || nameLower.includes('headline')) {
    return 'copywriter';
  }
  return 'designer';
}

class TaskService {
  // =========================================================================
  // SECTION 1: ClickUp-Style Project Subtask Management (README.md frontmatter)
  // =========================================================================

  /**
   * Aggregates tasks across all projects in the workspace.
   * @param {Object} filters
   * @returns {Array} Array of enriched task items
   */
  static getAllTasks(filters = {}) {
    const projects = WorkspaceService.getAllProjects();
    const allTasks = [];

    for (const p of projects) {
      if (!p || !p.id) continue;
      const subtasks = Array.isArray(p.subtasks) ? p.subtasks : [];

      subtasks.forEach((st, idx) => {
        if (!st) return;
        const taskId = st.id || `st_${p.id}_${idx + 1}`;
        const taskName = st.name || st.title || 'Untitled Deliverable';
        const role = normalizeRole(st.role || st.type, taskName);
        const status = normalizeStatus(st.status);

        // Determine appropriate default assignee based on role
        let assignee = st.assignee || 'Unassigned';
        if (assignee === 'Unassigned') {
          if (role === 'copywriter' && p.copywriting && p.copywriting.author) {
            assignee = p.copywriting.author;
          } else if (role === 'designer' && p.designer) {
            assignee = p.designer;
          } else if (p.designer) {
            assignee = p.designer;
          }
        }

        // Calculate deadline metrics
        const deadline = p.deadline || null;
        let isOverdue = false;
        let daysRemaining = null;

        if (deadline && status !== 'done') {
          try {
            const d = new Date(deadline);
            if (!isNaN(d.getTime())) {
              const diffTime = d.getTime() - Date.now();
              daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
              isOverdue = daysRemaining < 0;
            }
          } catch (e) {
            console.debug('[TaskService] Parse deadline error:', e.message);
          }
        }

        const enrichedTask = {
          id: taskId,
          globalId: `${p.id}::${taskId}`,
          name: taskName,
          role,
          assignee,
          assigneeName: st.assigneeName || assignee,
          status,
          weight: typeof st.weight === 'number' ? st.weight : 1.0,
          channel: st.channel || (p.channels && p.channels[0]) || 'general',
          specs: st.specs || '',
          notes: st.notes || '',
          deliverableId: st.deliverableId || '',
          linkedFile: st.linkedFile || '',
          createdAt: st.createdAt || p.created || null,
          updatedAt: st.updatedAt || null,

          // Enriched Project Context
          projectId: p.id,
          projectJobId: p.jobId || p.id,
          projectTitle: p.title || p.id,
          projectBrand: (p.brand || 'SS').toUpperCase(),
          projectStatus: p.status || 'in-progress',
          projectPriority: p.priority || 'medium',
          projectDeadline: deadline,
          projectDesigner: p.designer || 'Unassigned',
          projectManager: p.manager || 'harussani',
          isOverdue,
          daysRemaining
        };

        // Filter evaluation
        if (filters.role && filters.role !== 'all' && enrichedTask.role !== filters.role) return;
        if (filters.assignee && filters.assignee !== 'all') {
          const target = filters.assignee.toLowerCase().trim();
          const matchA = enrichedTask.assignee.toLowerCase().trim() === target;
          const matchN = enrichedTask.assigneeName.toLowerCase().trim().includes(target);
          if (!matchA && !matchN) return;
        }
        if (filters.status && filters.status !== 'all' && enrichedTask.status !== filters.status) return;
        if (filters.projectId && enrichedTask.projectId !== filters.projectId) return;
        if (filters.search && filters.search.trim()) {
          const q = filters.search.toLowerCase().trim();
          const matchName = enrichedTask.name.toLowerCase().includes(q);
          const matchProj = enrichedTask.projectTitle.toLowerCase().includes(q);
          const matchJob = enrichedTask.projectJobId.toLowerCase().includes(q);
          const matchAssignee = enrichedTask.assigneeName.toLowerCase().includes(q);
          if (!matchName && !matchProj && !matchJob && !matchAssignee) return;
        }

        allTasks.push(enrichedTask);
      });
    }

    // Sort order: overdue first, then in-progress, review, draft, done
    const statusWeight = { 'in-progress': 1, 'review': 2, 'draft': 3, 'done': 4 };
    return allTasks.sort((a, b) => {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      const swA = statusWeight[a.status] || 9;
      const swB = statusWeight[b.status] || 9;
      if (swA !== swB) return swA - swB;
      return (a.daysRemaining ?? 999) - (b.daysRemaining ?? 999);
    });
  }

  /**
   * Retrieves quick dashboard stats across all subtasks.
   */
  static getStats() {
    return this.getTaskStats();
  }

  static getTaskStats() {
    const tasks = this.getAllTasks();
    const total = tasks.length;
    const byStatus = {
      draft: tasks.filter(t => t.status === 'draft').length,
      'in-progress': tasks.filter(t => t.status === 'in-progress').length,
      review: tasks.filter(t => t.status === 'review').length,
      done: tasks.filter(t => t.status === 'done').length
    };
    const byRole = {
      copywriter: tasks.filter(t => t.role === 'copywriter').length,
      designer: tasks.filter(t => t.role === 'designer').length,
      manager: tasks.filter(t => t.role === 'manager').length
    };
    const overdue = tasks.filter(t => t.isOverdue && t.status !== 'done').length;

    return { total, byStatus, byRole, overdue };
  }

  /**
   * Creates a new subtask attached to a project's README.md frontmatter.
   */
  static createTask(projectId, taskData, actor = 'Administrator') {
    if (!projectId) throw new Error('projectId is required');
    const project = WorkspaceService.getProjectById(projectId);
    if (!project) throw new Error(`Project not found: ${projectId}`);

    const { frontmatter, body } = FrontmatterService.readProjectReadme(project.fullPath);
    const subtasks = Array.isArray(frontmatter.subtasks) ? [...frontmatter.subtasks] : [];

    const taskId = taskData.id || `st_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const role = normalizeRole(taskData.role, taskData.name || taskData.title);

    const newTask = {
      id: taskId,
      name: (taskData.name || taskData.title || 'New Task').trim(),
      role,
      assignee: (taskData.assignee || 'Unassigned').trim(),
      assigneeName: (taskData.assigneeName || taskData.assignee || 'Unassigned').trim(),
      status: normalizeStatus(taskData.status || 'draft'),
      weight: typeof taskData.weight === 'number' ? taskData.weight : 1.0,
      channel: taskData.channel || 'general',
      specs: taskData.specs || '',
      notes: taskData.notes || '',
      deliverableId: taskData.deliverableId || '',
      linkedFile: taskData.linkedFile || (role === 'copywriter' ? '03_COPYWRITING/COPY.md' : ''),
      createdAt: new Date().toISOString()
    };

    subtasks.push(newTask);
    frontmatter.subtasks = subtasks;

    FrontmatterService.writeProjectReadme(project.fullPath, frontmatter, body);

    // Update in-memory project cache immediately
    project.subtasks = subtasks;

    AuditService.logEvent({
      actor,
      action: 'TASK_CREATED',
      entityType: 'Task',
      entityId: taskId,
      details: { projectId: project.id, taskName: newTask.name, role, assignee: newTask.assignee }
    });

    try {
      SseService.broadcast('task:created', {
        task: newTask,
        projectId: project.id,
        projectTitle: project.title
      });
      SseService.broadcast('project:updated', {
        projectId: project.id,
        subtasks
      });
    } catch (e) {
      console.debug('[TaskService] SSE broadcast error:', e.message);
    }

    // Send email notification if task is assigned to a team member
    try {
      if (newTask.assignee && newTask.assignee !== 'Unassigned') {
        const assigneeUser = findUserByIdentifier(newTask.assignee);
        if (assigneeUser) {
          EmailService.sendTaskAssignedEmail(assigneeUser, newTask, project, actor);
        }
      }
    } catch (err) {
      console.warn('[TaskService] Failed to send assignment email:', err.message);
    }

    return newTask;
  }

  /**
   * Updates an existing subtask inside a project's README.md frontmatter.
   */
  static updateTask(projectId, taskId, updates, actor = 'Administrator') {
    if (!projectId || !taskId) throw new Error('projectId and taskId are required');
    const project = WorkspaceService.getProjectById(projectId);
    if (!project) throw new Error(`Project not found: ${projectId}`);

    const { frontmatter, body } = FrontmatterService.readProjectReadme(project.fullPath);
    const subtasks = Array.isArray(frontmatter.subtasks) ? [...frontmatter.subtasks] : [];

    const taskIndex = subtasks.findIndex(t => t.id === taskId || t.name === taskId);
    if (taskIndex === -1) {
      throw new Error(`Task ${taskId} not found in project ${projectId}`);
    }

    const existing = subtasks[taskIndex];
    const updated = {
      ...existing,
      ...(updates.name ? { name: updates.name.trim() } : {}),
      ...(updates.role ? { role: normalizeRole(updates.role) } : {}),
      ...(updates.assignee !== undefined ? { assignee: updates.assignee.trim() } : {}),
      ...(updates.assigneeName !== undefined ? { assigneeName: updates.assigneeName.trim() } : {}),
      ...(updates.status ? { status: normalizeStatus(updates.status) } : {}),
      ...(updates.weight !== undefined ? { weight: Number(updates.weight) } : {}),
      ...(updates.channel !== undefined ? { channel: updates.channel } : {}),
      ...(updates.specs !== undefined ? { specs: updates.specs } : {}),
      ...(updates.notes !== undefined ? { notes: updates.notes } : {}),
      ...(updates.deliverableId !== undefined ? { deliverableId: updates.deliverableId } : {}),
      ...(updates.linkedFile !== undefined ? { linkedFile: updates.linkedFile } : {}),
      updatedAt: new Date().toISOString()
    };

    subtasks[taskIndex] = updated;
    frontmatter.subtasks = subtasks;

    FrontmatterService.writeProjectReadme(project.fullPath, frontmatter, body);

    // Update in-memory project cache
    project.subtasks = subtasks;

    AuditService.logEvent({
      actor,
      action: 'TASK_UPDATED',
      entityType: 'Task',
      entityId: taskId,
      details: { projectId: project.id, status: updated.status, assignee: updated.assignee }
    });

    try {
      SseService.broadcast('task:updated', {
        task: updated,
        projectId: project.id
      });
      SseService.broadcast('project:updated', {
        projectId: project.id,
        subtasks
      });
    } catch (e) {
      console.debug('[TaskService] SSE broadcast error:', e.message);
    }

    // Send email notification on assignment change or review status
    try {
      if (updates.assignee && updates.assignee !== existing.assignee && updates.assignee !== 'Unassigned') {
        const assigneeUser = findUserByIdentifier(updates.assignee);
        if (assigneeUser) {
          EmailService.sendTaskAssignedEmail(assigneeUser, updated, project, actor);
        }
      }
      if (updated.status === 'review' && existing.status !== 'review') {
        const managerUser = findUserByIdentifier(project.manager || 'harussani');
        if (managerUser) {
          EmailService.sendTaskReviewAlertEmail(managerUser, updated, project, actor);
        }
      }
    } catch (err) {
      console.warn('[TaskService] Failed to send update email notification:', err.message);
    }

    return updated;
  }

  /**
   * Deletes a subtask from a project's README.md.
   */
  static deleteTask(projectId, taskId, actor = 'Administrator') {
    if (!projectId || !taskId) throw new Error('projectId and taskId are required');
    const project = WorkspaceService.getProjectById(projectId);
    if (!project) throw new Error(`Project not found: ${projectId}`);

    const { frontmatter, body } = FrontmatterService.readProjectReadme(project.fullPath);
    const subtasks = Array.isArray(frontmatter.subtasks) ? [...frontmatter.subtasks] : [];

    const filtered = subtasks.filter(t => t.id !== taskId && t.name !== taskId);
    if (filtered.length === subtasks.length) {
      throw new Error(`Task ${taskId} not found in project ${projectId}`);
    }

    frontmatter.subtasks = filtered;
    FrontmatterService.writeProjectReadme(project.fullPath, frontmatter, body);

    project.subtasks = filtered;

    AuditService.logEvent({
      actor,
      action: 'TASK_DELETED',
      entityType: 'Task',
      entityId: taskId,
      details: { projectId: project.id }
    });

    try {
      SseService.broadcast('task:deleted', { taskId, projectId: project.id });
      SseService.broadcast('project:updated', { projectId: project.id, subtasks: filtered });
    } catch (e) {
      console.debug('[TaskService] SSE broadcast error:', e.message);
    }

    return { success: true, taskId, projectId: project.id };
  }

  /**
   * Computes aggregate task statistics across studio tasks and projects.
   */
  static getStats() {
    const all = this.getAllTasks();
    let studioTasks = [];
    try {
      studioTasks = this.getAllStudioTasks();
    } catch (e) {
      /* ignore */
    }

    return {
      total: all.length + studioTasks.length,
      byStatus: {
        draft: all.filter(t => t.status === 'draft').length,
        backlog: studioTasks.filter(t => t.status === 'backlog').length,
        'in-progress': all.filter(t => t.status === 'in-progress').length + studioTasks.filter(t => t.status === 'in-progress').length,
        review: all.filter(t => t.status === 'review').length + studioTasks.filter(t => t.status === 'review').length,
        done: all.filter(t => t.status === 'done').length + studioTasks.filter(t => t.status === 'done').length,
        converted: studioTasks.filter(t => t.status === 'converted').length
      },
      byRole: {
        copywriter: all.filter(t => t.role === 'copywriter').length,
        designer: all.filter(t => t.role === 'designer').length,
        manager: all.filter(t => t.role === 'manager').length
      },
      overdue: all.filter(t => t.isOverdue).length + studioTasks.filter(t => t.dueDate && new Date(t.dueDate) < new Date() && t.status !== 'done' && t.status !== 'converted').length
    };
  }

  /**
   * Computes statistics specifically for decoupled pre-production studio tasks.
   */
  static getStudioTaskStats() {
    let tasks = [];
    try {
      tasks = this.getAllStudioTasks();
    } catch (e) {
      /* ignore */
    }

    return {
      total: tasks.length,
      byStatus: {
        backlog: tasks.filter(t => t.status === 'backlog').length,
        'in-progress': tasks.filter(t => t.status === 'in-progress').length,
        review: tasks.filter(t => t.status === 'review').length,
        done: tasks.filter(t => t.status === 'done').length,
        converted: tasks.filter(t => t.status === 'converted').length
      },
      byPriority: {
        urgent: tasks.filter(t => t.priority === 'urgent').length,
        high: tasks.filter(t => t.priority === 'high').length,
        medium: tasks.filter(t => t.priority === 'medium').length,
        low: tasks.filter(t => t.priority === 'low').length
      },
      byBrand: {
        SS: tasks.filter(t => t.brand === 'SS').length,
        SSH: tasks.filter(t => t.brand === 'SSH').length,
        SSC: tasks.filter(t => t.brand === 'SSC').length,
        SSW: tasks.filter(t => t.brand === 'SSW').length,
        SSE: tasks.filter(t => t.brand === 'SSE').length,
        SST: tasks.filter(t => t.brand === 'SST').length
      },
      overdue: tasks.filter(t => t.dueDate && new Date(t.dueDate) < new Date() && t.status !== 'done' && t.status !== 'converted').length
    };
  }

  // =========================================================================
  // SECTION 2: Pre-Production Studio Tasks (.sscam/tasks/*.md) & NAS Bridge
  // =========================================================================

  /**
   * Returns the directory path for lightweight studio tasks: <WORKSPACE_ROOT>/.sscam/tasks
   */
  static getTasksDir() {
    const tasksDir = path.join(config.WORKSPACE_ROOT, '.sscam', 'tasks');
    if (!fs.existsSync(tasksDir)) {
      try {
        fs.mkdirSync(tasksDir, { recursive: true });
        if (process.env.NODE_ENV !== 'test' && !config.WORKSPACE_ROOT.includes('temp-')) {
          this.seedSampleTasks(tasksDir);
        }
      } catch (err) {
        console.error('[TaskService] Failed to create .sscam/tasks directory:', err.message);
      }
    }
    return tasksDir;
  }

  /**
   * Seeds realistic pre-production tasks if the tasks folder is newly created and empty.
   */
  static seedSampleTasks(tasksDir) {
    try {
      const existing = fs.readdirSync(tasksDir).filter(f => f.endsWith('.md'));
      if (existing.length > 0) return;

      const sampleTasks = [
        {
          id: 'TSK-1001',
          title: 'Ramadan 2026 Gift Box 3D Mockup & Concept Ideation',
          workstream: 'Packaging & 3D Key Visual',
          description: `# Main Task
Pre-production exploration for the upcoming Ramadan exclusive collector's packaging box.

## Brief & Exploration Requirements
- Gold foil stamping accents on deep forest green texture
- Embossed crescent and geometric Islamic motifs
- Internal velvet insert for 2x bottles and premium spoon

### Target Audience
Corporate VIP clients and premium health enthusiasts.`,
          assignee: 'SS0004',
          assigneeName: 'Harussani',
          assigneeAvatarColor: '#0078D4',
          status: 'in-progress',
          priority: 'urgent',
          brand: 'SS',
          tags: ['packaging', '3d-mockup', 'ramadan', 'luxury'],
          startDate: '2026-10-10',
          dueDate: '2026-10-20',
          decisionStatus: 'pending',
          decisionSummary: 'Dieline draft approved; awaiting sample box foil proof.',
          subtasks: [
            { id: 'sub_1001_1', title: 'Dieline structural dimensions & foil stamp coordinates', completed: true, assignee: 'SS0004', assigneeName: 'Harussani', dueDate: '2026-10-14' },
            { id: 'sub_1001_2', title: '3D Blender key visual rendering with studio lighting', completed: true, assignee: 'SS0004', assigneeName: 'Harussani', dueDate: '2026-10-17' },
            { id: 'sub_1001_3', title: 'Velvet insert bottle tolerance test', completed: false, assignee: 'SS0002', assigneeName: 'Aliff', dueDate: '2026-10-19' },
            { id: 'sub_1001_4', title: 'Art Director master sign-off', completed: false, assignee: 'SS0004', assigneeName: 'Harussani', dueDate: '2026-10-20' }
          ],
          blockedBy: [],
          blocks: ['TSK-1002'],
          comments: [
            { id: 'c1', author: 'harussani', authorName: 'Harussani', avatarColor: '#0078D4', message: 'Dieline layout submitted to production printer for quote.', timestamp: new Date(Date.now() - 2 * 86400000).toISOString(), type: 'comment' }
          ],
          createdAt: new Date(Date.now() - 4 * 86400000).toISOString(),
          updatedAt: new Date(Date.now() - 1 * 86400000).toISOString()
        },
        {
          id: 'TSK-1002',
          title: 'TikTok Viral Short-Form Video Hook Scripts (10 Variants)',
          workstream: 'Copywriting & Direct Response',
          description: `# Main Task
Draft and test 10 high-converting video hooks for Q4 TikTok ad campaigns.

## Focus Angles
1. "Rahsia stamina lelaki berkerjaya tanpa gula berlebihan"
2. "Kenapa formula tradisional herba masih relevan di 2026"
3. "Before & After 30 hari ujian makmal"

### Deliverables Needed
- Table of 3-second visual cues and voiceover lines
- Moodboard for studio lighting setup`,
          assignee: 'SS0001',
          assigneeName: 'Haikal',
          assigneeAvatarColor: '#107C41',
          status: 'backlog',
          priority: 'high',
          brand: 'SSE',
          tags: ['video', 'tiktok', 'copywriting', 'hooks'],
          startDate: '2026-10-14',
          dueDate: '2026-10-25',
          decisionStatus: 'changes_requested',
          decisionSummary: 'Hooks 1-4 approved; hooks 5-10 require stronger pain points.',
          subtasks: [
            { id: 'sub_1002_1', title: 'Draft 10 curiosity & transformation hooks', completed: true, assignee: 'SS0001', assigneeName: 'Haikal', dueDate: '2026-10-16' },
            { id: 'sub_1002_2', title: 'Review against TikTok ad policy guidelines', completed: false, assignee: 'SS0001', assigneeName: 'Haikal', dueDate: '2026-10-20' },
            { id: 'sub_1002_3', title: 'Script audio voiceover pacing & B-roll shots', completed: false, assignee: 'SS0001', assigneeName: 'Haikal', dueDate: '2026-10-25' }
          ],
          blockedBy: ['TSK-1001'],
          blocks: [],
          comments: [
            { id: 'c2', author: 'haikal', authorName: 'Haikal', avatarColor: '#107C41', message: 'Waiting on TSK-1001 3D renders to match hook scripts with actual product visuals.', timestamp: new Date(Date.now() - 1 * 86400000).toISOString(), type: 'comment' }
          ],
          createdAt: new Date(Date.now() - 2 * 86400000).toISOString(),
          updatedAt: new Date(Date.now() - 2 * 86400000).toISOString()
        },
        {
          id: 'TSK-1003',
          title: 'Wellness Clinic Outdoor Lightbox & Reception Graphics',
          workstream: 'Retail Signage & Interior Branding',
          description: `# Main Task
Prepare initial visual moodboard and typography specifications for the upcoming Bangsar showroom.

## Specifications
- 4K resolution master graphic layout
- Minimalist Scandinavian medical aesthetic
- Clean SuamiSihat Holdings secondary badge placement`,
          assignee: 'SS0002',
          assigneeName: 'Aliff',
          assigneeAvatarColor: '#D83B01',
          status: 'review',
          priority: 'medium',
          brand: 'SSW',
          tags: ['retail', 'signage', 'print', 'interior'],
          startDate: '2026-10-08',
          dueDate: '2026-10-18',
          decisionStatus: 'approved',
          decisionSummary: 'Master vector layout verified and approved for Bangsar site lightbox vendor.',
          subtasks: [
            { id: 'sub_1003_1', title: 'Bangsar showroom site measurement verification', completed: true, assignee: 'SS0002', assigneeName: 'Aliff', dueDate: '2026-10-10' },
            { id: 'sub_1003_2', title: 'High-resolution vector typography layout', completed: true, assignee: 'SS0002', assigneeName: 'Aliff', dueDate: '2026-10-14' },
            { id: 'sub_1003_3', title: 'Print vendor material color check (CMYK)', completed: true, assignee: 'SS0002', assigneeName: 'Aliff', dueDate: '2026-10-18' }
          ],
          blockedBy: [],
          blocks: [],
          comments: [
            { id: 'c3', author: 'aliff', authorName: 'Aliff', avatarColor: '#D83B01', message: 'Specs verified with Bangsar clinic contractor.', timestamp: new Date(Date.now() - 3 * 86400000).toISOString(), type: 'comment' }
          ],
          createdAt: new Date(Date.now() - 5 * 86400000).toISOString(),
          updatedAt: new Date(Date.now() - 3 * 86400000).toISOString()
        }
      ];

      for (const t of sampleTasks) {
        const filePath = path.join(tasksDir, `${t.id}.md`);
        const { description, ...fm } = t;
        const content = FrontmatterService.serializeContent(fm, description);
        fs.writeFileSync(filePath, content, 'utf8');
      }
      console.log('[TaskService] Seeded initial studio pre-production tasks in .sscam/tasks.');
    } catch (e) {
      console.warn('[TaskService] Seeding warning:', e.message);
    }
  }

  /**
   * Helper to resolve staff roster for populating assignee names and avatars.
   */
  static getStaffDirectoryMap() {
    try {
      const rosterPath = path.join(config.WORKSPACE_ROOT, '_Team', '_Config', 'staff_directory.json');
      if (!fs.existsSync(rosterPath)) return new Map();
      const roster = TeamService.getStaffRoster();
      const map = new Map();
      if (Array.isArray(roster)) {
        for (const u of roster) {
          if (u.staffId) map.set(u.staffId.toUpperCase(), u);
          if (u.username) map.set(u.username.toLowerCase(), u);
          if (u.name) map.set(u.name.toLowerCase(), u);
        }
      }
      return map;
    } catch {
      return new Map();
    }
  }

  /**
   * Lists all studio tasks from .sscam/tasks/*.md
   */
  static getAllStudioTasks(filters = {}) {
    const tasksDir = this.getTasksDir();
    if (!fs.existsSync(tasksDir)) return [];

    try {
      const files = fs.readdirSync(tasksDir).filter(f => f.endsWith('.md'));
      const staffMap = this.getStaffDirectoryMap();
      const tasks = [];

      for (const file of files) {
        try {
          const filePath = path.join(tasksDir, file);
          let raw = fs.readFileSync(filePath, 'utf8');
          if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);

          const { frontmatter, body } = FrontmatterService.parseRawContent(raw);
          const stats = fs.statSync(filePath);
          const taskId = frontmatter.id || path.basename(file, '.md');

          // Enrich assignee details if missing
          let assignee = frontmatter.assignee || '';
          let assigneeName = frontmatter.assigneeName || '';
          let assigneeAvatarColor = frontmatter.assigneeAvatarColor || '';

          if (assignee && (!assigneeName || !assigneeAvatarColor)) {
            const member = staffMap.get(assignee.toUpperCase()) || staffMap.get(assignee.toLowerCase());
            if (member) {
              assigneeName = assigneeName || member.name || member.username;
              assigneeAvatarColor = assigneeAvatarColor || member.avatarColor || '#0078D4';
            }
          }

          const task = {
            id: taskId,
            title: frontmatter.title || 'Untitled Studio Task',
            description: body || '',
            workstream: frontmatter.workstream || 'General Production',
            startDate: frontmatter.startDate || '',
            dueDate: frontmatter.dueDate || frontmatter.deadline || '',
            decisionStatus: frontmatter.decisionStatus || 'pending',
            decisionSummary: frontmatter.decisionSummary || '',
            subtasks: Array.isArray(frontmatter.subtasks) ? frontmatter.subtasks : [],
            blockedBy: Array.isArray(frontmatter.blockedBy) ? frontmatter.blockedBy : [],
            blocks: Array.isArray(frontmatter.blocks) ? frontmatter.blocks : [],
            comments: Array.isArray(frontmatter.comments) ? frontmatter.comments : [],
            assignee: assignee || '',
            assigneeName: assigneeName || assignee || 'Unassigned',
            assigneeAvatarColor: assigneeAvatarColor || '#64748B',
            status: frontmatter.status || 'backlog',
            priority: frontmatter.priority || 'medium',
            brand: frontmatter.brand || 'SS',
            tags: Array.isArray(frontmatter.tags) ? frontmatter.tags : [],
            createdAt: frontmatter.createdAt || frontmatter.created || stats.birthtime.toISOString(),
            updatedAt: frontmatter.updatedAt || stats.mtime.toISOString(),
            jobId: frontmatter.jobId || null,
            projectId: frontmatter.projectId || null,
            projectTitle: frontmatter.projectTitle || null,
            convertedAt: frontmatter.convertedAt || null,
            filePath
          };

          // Apply filters
          if (filters.status && filters.status !== 'all' && task.status !== filters.status) {
            continue;
          }
          if (filters.assignee && filters.assignee !== 'all') {
            const searchAssignee = filters.assignee.toLowerCase();
            if (task.assignee.toLowerCase() !== searchAssignee && task.assigneeName.toLowerCase() !== searchAssignee) {
              continue;
            }
          }
          if (filters.priority && filters.priority !== 'all' && task.priority !== filters.priority) {
            continue;
          }
          if (filters.brand && filters.brand !== 'all' && task.brand !== filters.brand) {
            continue;
          }
          if (filters.query && filters.query.trim()) {
            const q = filters.query.toLowerCase();
            const matchTitle = task.title.toLowerCase().includes(q);
            const matchDesc = task.description.toLowerCase().includes(q);
            const matchId = task.id.toLowerCase().includes(q);
            const matchTags = task.tags.some(t => t.toLowerCase().includes(q));
            if (!matchTitle && !matchDesc && !matchId && !matchTags) {
              continue;
            }
          }

          tasks.push(task);
        } catch (itemErr) {
          console.warn(`[TaskService] Error reading task file ${file}:`, itemErr.message);
        }
      }

      // Sort: Active tasks first (backlog, in-progress, review, done, converted), then by updatedAt desc
      const STATUS_ORDER = { 'in-progress': 1, 'review': 2, 'backlog': 3, 'done': 4, 'converted': 5 };
      return tasks.sort((a, b) => {
        const orderA = STATUS_ORDER[a.status] || 9;
        const orderB = STATUS_ORDER[b.status] || 9;
        if (orderA !== orderB) return orderA - orderB;
        return new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime();
      });
    } catch (err) {
      console.error('[TaskService] getAllStudioTasks error:', err.message);
      return [];
    }
  }

  /**
   * Retrieves a single studio task by ID.
   */
  static getStudioTaskById(taskId) {
    if (!taskId) return null;
    const cleanId = String(taskId).trim();
    const tasksDir = this.getTasksDir();
    const directPath = path.join(tasksDir, `${cleanId}.md`);

    if (fs.existsSync(directPath)) {
      try {
        let raw = fs.readFileSync(directPath, 'utf8');
        if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
        const { frontmatter, body } = FrontmatterService.parseRawContent(raw);
        const stats = fs.statSync(directPath);

        const staffMap = this.getStaffDirectoryMap();
        let assignee = frontmatter.assignee || '';
        let assigneeName = frontmatter.assigneeName || '';
        let assigneeAvatarColor = frontmatter.assigneeAvatarColor || '';

        if (assignee && (!assigneeName || !assigneeAvatarColor)) {
          const member = staffMap.get(assignee.toUpperCase()) || staffMap.get(assignee.toLowerCase());
          if (member) {
            assigneeName = assigneeName || member.name || member.username;
            assigneeAvatarColor = assigneeAvatarColor || member.avatarColor || '#0078D4';
          }
        }

        return {
          id: frontmatter.id || cleanId,
          title: frontmatter.title || 'Untitled Studio Task',
          description: body || '',
          workstream: frontmatter.workstream || 'General Production',
          startDate: frontmatter.startDate || '',
          dueDate: frontmatter.dueDate || frontmatter.deadline || '',
          decisionStatus: frontmatter.decisionStatus || 'pending',
          decisionSummary: frontmatter.decisionSummary || '',
          subtasks: Array.isArray(frontmatter.subtasks) ? frontmatter.subtasks : [],
          blockedBy: Array.isArray(frontmatter.blockedBy) ? frontmatter.blockedBy : [],
          blocks: Array.isArray(frontmatter.blocks) ? frontmatter.blocks : [],
          comments: Array.isArray(frontmatter.comments) ? frontmatter.comments : [],
          assignee: assignee || '',
          assigneeName: assigneeName || assignee || 'Unassigned',
          assigneeAvatarColor: assigneeAvatarColor || '#64748B',
          status: frontmatter.status || 'backlog',
          priority: frontmatter.priority || 'medium',
          brand: frontmatter.brand || 'SS',
          tags: Array.isArray(frontmatter.tags) ? frontmatter.tags : [],
          createdAt: frontmatter.createdAt || frontmatter.created || stats.birthtime.toISOString(),
          updatedAt: frontmatter.updatedAt || stats.mtime.toISOString(),
          jobId: frontmatter.jobId || null,
          projectId: frontmatter.projectId || null,
          projectTitle: frontmatter.projectTitle || null,
          convertedAt: frontmatter.convertedAt || null,
          filePath: directPath
        };
      } catch (err) {
        console.error(`[TaskService] Error reading task ${cleanId}:`, err.message);
      }
    }

    // Fallback: search all tasks in directory
    const all = this.getAllStudioTasks();
    return all.find(t => t.id.toLowerCase() === cleanId.toLowerCase()) || null;
  }

  /**
   * Generates a new clean ID (e.g. TSK-1004).
   */
  static generateNextTaskId() {
    const tasksDir = this.getTasksDir();
    let highestNum = 1000;
    try {
      const files = fs.readdirSync(tasksDir).filter(f => f.endsWith('.md'));
      for (const f of files) {
        const m = f.match(/TSK-(\d+)/i);
        if (m) {
          const n = parseInt(m[1], 10);
          if (n > highestNum) highestNum = n;
        }
      }
    } catch {}
    return `TSK-${highestNum + 1}`;
  }

  /**
   * Creates a new lightweight studio task.
   */
  static createStudioTask(data, actor = 'System', role = 'Creative User') {
    if (!data || !data.title || !String(data.title).trim()) {
      throw new Error('Task title is required');
    }

    const tasksDir = this.getTasksDir();
    const id = data.id || this.generateNextTaskId();
    const nowIso = new Date().toISOString();

    const staffMap = this.getStaffDirectoryMap();
    let assignee = data.assignee || '';
    let assigneeName = data.assigneeName || '';
    let assigneeAvatarColor = data.assigneeAvatarColor || '';

    if (assignee && (!assigneeName || !assigneeAvatarColor)) {
      const member = staffMap.get(assignee.toUpperCase()) || staffMap.get(assignee.toLowerCase());
      if (member) {
        assigneeName = assigneeName || member.name || member.username;
        assigneeAvatarColor = assigneeAvatarColor || member.avatarColor || '#0078D4';
      }
    }

    const frontmatter = {
      id,
      title: String(data.title).trim(),
      workstream: data.workstream || 'General Production',
      startDate: data.startDate || '',
      dueDate: data.dueDate || data.deadline || '',
      decisionStatus: data.decisionStatus || 'pending',
      decisionSummary: data.decisionSummary || '',
      subtasks: Array.isArray(data.subtasks) ? data.subtasks : [],
      blockedBy: Array.isArray(data.blockedBy) ? data.blockedBy : [],
      blocks: Array.isArray(data.blocks) ? data.blocks : [],
      comments: Array.isArray(data.comments) ? data.comments : [],
      assignee,
      assigneeName,
      assigneeAvatarColor,
      status: data.status || 'backlog',
      priority: data.priority || 'medium',
      brand: data.brand || 'SS',
      tags: Array.isArray(data.tags) ? data.tags : (typeof data.tags === 'string' ? data.tags.split(',').map(t => t.trim()).filter(Boolean) : []),
      createdAt: nowIso,
      updatedAt: nowIso,
      jobId: data.jobId || null,
      projectId: data.projectId || null,
      projectTitle: data.projectTitle || null,
      convertedAt: data.convertedAt || null
    };

    const description = typeof data.description === 'string' ? data.description : '';
    const filePath = path.join(tasksDir, `${id}.md`);
    const content = FrontmatterService.serializeContent(frontmatter, description);

    fs.writeFileSync(filePath, content, 'utf8');

    const createdTask = {
      ...frontmatter,
      description,
      filePath
    };

    AuditService.logEvent({
      actor,
      role,
      action: 'task_created',
      entityType: 'StudioTask',
      entityId: id,
      details: { title: createdTask.title, assignee: createdTask.assignee, priority: createdTask.priority }
    });

    SseService.broadcast('studio-task:created', { task: createdTask });
    return createdTask;
  }

  /**
   * Updates an existing studio task.
   */
  static updateStudioTask(taskId, updates, actor = 'System', role = 'Creative User') {
    const existing = this.getStudioTaskById(taskId);
    if (!existing) {
      throw new Error(`Task ${taskId} not found`);
    }

    const tasksDir = this.getTasksDir();
    const filePath = existing.filePath || path.join(tasksDir, `${existing.id}.md`);
    const nowIso = new Date().toISOString();

    const staffMap = this.getStaffDirectoryMap();
    let assignee = updates.assignee !== undefined ? updates.assignee : existing.assignee;
    let assigneeName = updates.assigneeName !== undefined ? updates.assigneeName : existing.assigneeName;
    let assigneeAvatarColor = updates.assigneeAvatarColor !== undefined ? updates.assigneeAvatarColor : existing.assigneeAvatarColor;

    if (assignee && (updates.assignee !== undefined || !assigneeName || !assigneeAvatarColor)) {
      const member = staffMap.get(assignee.toUpperCase()) || staffMap.get(assignee.toLowerCase());
      if (member) {
        assigneeName = member.name || member.username;
        assigneeAvatarColor = member.avatarColor || '#0078D4';
      }
    }

    const frontmatter = {
      id: existing.id,
      title: updates.title !== undefined ? String(updates.title).trim() : existing.title,
      workstream: updates.workstream !== undefined ? updates.workstream : (existing.workstream || 'General Production'),
      startDate: updates.startDate !== undefined ? updates.startDate : (existing.startDate || ''),
      dueDate: updates.dueDate !== undefined ? updates.dueDate : existing.dueDate,
      decisionStatus: updates.decisionStatus !== undefined ? updates.decisionStatus : (existing.decisionStatus || 'pending'),
      decisionSummary: updates.decisionSummary !== undefined ? updates.decisionSummary : (existing.decisionSummary || ''),
      subtasks: updates.subtasks !== undefined ? (Array.isArray(updates.subtasks) ? updates.subtasks : []) : (existing.subtasks || []),
      blockedBy: updates.blockedBy !== undefined ? (Array.isArray(updates.blockedBy) ? updates.blockedBy : []) : (existing.blockedBy || []),
      blocks: updates.blocks !== undefined ? (Array.isArray(updates.blocks) ? updates.blocks : []) : (existing.blocks || []),
      comments: updates.comments !== undefined ? (Array.isArray(updates.comments) ? updates.comments : []) : (existing.comments || []),
      assignee,
      assigneeName,
      assigneeAvatarColor,
      status: updates.status !== undefined ? updates.status : existing.status,
      priority: updates.priority !== undefined ? updates.priority : existing.priority,
      brand: updates.brand !== undefined ? updates.brand : existing.brand,
      tags: updates.tags !== undefined ? (Array.isArray(updates.tags) ? updates.tags : updates.tags.split(',').map(t => t.trim()).filter(Boolean)) : existing.tags,
      createdAt: existing.createdAt,
      updatedAt: nowIso,
      jobId: updates.jobId !== undefined ? updates.jobId : existing.jobId,
      projectId: updates.projectId !== undefined ? updates.projectId : existing.projectId,
      projectTitle: updates.projectTitle !== undefined ? updates.projectTitle : existing.projectTitle,
      convertedAt: updates.convertedAt !== undefined ? updates.convertedAt : existing.convertedAt
    };

    const description = updates.description !== undefined ? String(updates.description) : existing.description;
    const content = FrontmatterService.serializeContent(frontmatter, description);

    fs.writeFileSync(filePath, content, 'utf8');

    const updatedTask = {
      ...frontmatter,
      description,
      filePath
    };

    AuditService.logEvent({
      actor,
      role,
      action: 'task_updated',
      entityType: 'StudioTask',
      entityId: existing.id,
      details: { changes: Object.keys(updates) }
    });

    SseService.broadcast('studio-task:updated', { task: updatedTask });
    return updatedTask;
  }

  /**
   * Deletes a studio task markdown file.
   */
  static deleteStudioTask(taskId, actor = 'System', role = 'Creative User') {
    const existing = this.getStudioTaskById(taskId);
    if (!existing) {
      throw new Error(`Task ${taskId} not found`);
    }

    const tasksDir = this.getTasksDir();
    const filePath = existing.filePath || path.join(tasksDir, `${existing.id}.md`);

    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    AuditService.logEvent({
      actor,
      role,
      action: 'task_deleted',
      entityType: 'StudioTask',
      entityId: existing.id,
      details: { title: existing.title }
    });

    SseService.broadcast('studio-task:deleted', { id: existing.id });
    return { success: true, id: existing.id };
  }

  /**
   * PHASE 3 BRIDGE: Provision NAS Workspace
   * Upgrades a lightweight pre-production StudioTask into a full Synology NAS Project Vault.
   * Generates official JobId, creates canonical 5 folders, migrates brief, and links task.
   */
  static provisionTaskToProject(taskId, options = {}, actor = 'System', role = 'Creative Lead') {
    const task = this.getStudioTaskById(taskId);
    if (!task) {
      throw new Error(`Task ${taskId} not found`);
    }

    if (task.status === 'converted' && task.projectId) {
      return {
        success: true,
        alreadyConverted: true,
        task,
        jobId: task.jobId,
        projectId: task.projectId,
        message: `Task is already provisioned to project ${task.projectId}`
      };
    }

    const ws = require('./WorkspaceService');

    // 1. Calculate official Job ID
    let jobId = options.jobId;
    if (!jobId) {
      let maxNum = 88;
      const projects = ws.projectsCache || [];
      for (const p of projects) {
        const m = (p.jobId || '').match(/(\d+)/);
        if (m) {
          const n = parseInt(m[1], 10);
          if (n > maxNum) maxNum = n;
        }
      }
      const nextNum = maxNum + 1;
      const typeChar = options.presetType === 'video' ? 'V' : options.presetType === 'social' ? 'S' : 'D';
      jobId = `${String(nextNum).padStart(4, '0')}${typeChar}`;
    }

    // 2. Resolve Designer Folder & Naming
    const designer = options.designer || task.assigneeName || task.assignee || 'Design-Studio';
    const cleanDesigner = designer.replace(/[\\/:*?"<>|]/g, '').trim() || 'Design-Studio';
    const now = new Date();
    const yearStr = String(now.getFullYear());
    const monthNum = String(now.getMonth() + 1).padStart(2, '0');
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const monthName = monthNames[now.getMonth()];
    const monthFolder = `${yearStr}${monthNum}_${monthName}`;
    const brandCode = (options.brand || task.brand || 'SS').toUpperCase();
    const cleanTitle = task.title.replace(/[\\/:*?"<>|]/g, '_').replace(/\s+/g, '_');
    const folderName = `${yearStr}${monthNum}_${jobId}_${brandCode}_${cleanTitle}`;

    // Target full directory path in workspace
    const projectDir = path.join(config.WORKSPACE_ROOT, cleanDesigner, `SS-${yearStr}`, monthFolder, folderName);

    // 3. Create canonical 5-folder SS-CAM Vault hierarchy on NAS
    fs.mkdirSync(projectDir, { recursive: true });
    const subFolders = [
      '01_BRIEF_ASSETS',
      '02_SOURCE_FILES',
      '03_COPYWRITING',
      '04_WORK_IN_PROGRESS',
      '05_DELIVERABLES'
    ];
    for (const sub of subFolders) {
      fs.mkdirSync(path.join(projectDir, sub), { recursive: true });
    }

    // Deliverables subfolders
    fs.mkdirSync(path.join(projectDir, '05_DELIVERABLES', 'Final_Exports'), { recursive: true });
    fs.mkdirSync(path.join(projectDir, '05_DELIVERABLES', 'Thumbnails'), { recursive: true });

    // 4. Initial COPY.md in 03_COPYWRITING
    const copyContent = `# Copywriting & Script Studio — ${task.title}\n\n## 1. Campaign Message & Angles\n- **Target Brand**: ${brandCode}\n- **Tone**: Premium, High-Trust, Dynamic\n\n## 2. Copy Outline\n${task.description || 'Deliver high-impact marketing visuals according to SuamiSihat brand guidelines.'}\n`;
    fs.writeFileSync(path.join(projectDir, '03_COPYWRITING', 'COPY.md'), copyContent, 'utf8');

    // 5. Canonical README.md with Frontmatter
    const createdDate = task.createdAt ? task.createdAt.split('T')[0] : now.toISOString().split('T')[0];
    const deadlineDate = task.dueDate || new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0];

    const projectFm = {
      status: 'in-progress',
      designer: cleanDesigner,
      client: brandCode,
      brand: brandCode,
      created: createdDate,
      startDate: createdDate,
      deadline: deadlineDate,
      priority: task.priority || 'medium',
      presetType: options.presetType || 'Graphic & Print Design',
      tags: [...(task.tags || []), 'nas-provisioned', `task-${task.id.toLowerCase()}`],
      revision: 0,
      source_task_id: task.id,
      provisioned_at: now.toISOString(),
      provisioned_by: actor
    };

    const readmeBody = `# 🎨 ${task.title}\n\n## 📋 Creative Campaign Brief (Provisioned from Studio Task ${task.id})\n${task.description || 'Provide high-converting visual assets compliant with SuamiSihat creative standards.'}\n\n## 🧭 Studio Production Pipeline\n- **Project ID**: \`${jobId}\`\n- **NAS Vault Folder**: \`${folderName}\`\n- **Assigned Designer**: ${cleanDesigner}\n- **Originating Pre-Production Task**: [${task.id}]\n`;

    FrontmatterService.writeProjectReadme(projectDir, projectFm, readmeBody);

    // 6. Update Task file in .sscam/tasks/
    const updatedTask = this.updateStudioTask(task.id, {
      status: 'converted',
      jobId,
      projectId: folderName,
      convertedAt: now.toISOString()
    }, actor, role);

    // 7. Request WorkspaceService to refresh cache so the new project is immediately discoverable
    try {
      ws.scan();
    } catch (scanErr) {
      console.warn('[TaskService] WorkspaceService scan warning:', scanErr.message);
    }

    AuditService.logEvent({
      actor,
      role,
      action: 'task_provisioned_to_nas',
      entityType: 'StudioTask',
      entityId: task.id,
      details: { jobId, folderName, projectDir, brand: brandCode }
    });

    SseService.broadcast('project:updated', { projectId: folderName, action: 'created', jobId });
    SseService.broadcast('workspace:updated', { action: 'project_provisioned', jobId });

    return {
      success: true,
      jobId,
      projectId: folderName,
      folderName,
      projectDir,
      task: updatedTask,
      message: `Successfully provisioned NAS workspace ${jobId} for task ${task.id}`
    };
  }
}

module.exports = TaskService;

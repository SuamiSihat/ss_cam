const fs = require('fs');
const path = require('path');
const WorkspaceService = require('./WorkspaceService');
const FrontmatterService = require('./FrontmatterService');
const AuditService = require('./AuditService');
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
          }
        }

        const taskItem = {
          id: taskId,
          name: taskName,
          role,
          assignee,
          assigneeName: st.assigneeName || assignee,
          status,
          weight: typeof st.weight === 'number' ? st.weight : 1.0,
          channel: st.channel || st.type || 'general',
          specs: st.specs || '',
          notes: st.notes || '',
          deliverableId: st.deliverableId || st.filename || '',
          linkedFile: st.linkedFile || (role === 'copywriter' ? '03_COPYWRITING/COPY.md' : ''),
          createdAt: st.createdAt || p.createdDate || new Date().toISOString(),
          updatedAt: st.updatedAt || p.startDate || null,

          // Linked Project Context
          projectId: p.id,
          projectJobId: p.jobId || p.id,
          projectTitle: p.title || p.folderName,
          projectBrand: p.brand || 'SuamiSihat',
          projectStatus: p.status || 'draft',
          projectPriority: p.priority || 'medium',
          projectDeadline: p.deadline || '',
          projectDesigner: p.designer || 'Unassigned',
          projectManager: p.manager || 'Unassigned',
          isOverdue: p.isOverdue || false,
          daysRemaining: typeof p.daysRemaining === 'number' ? p.daysRemaining : null
        };

        allTasks.push(taskItem);
      });
    }

    // Apply filtering
    let filtered = allTasks;

    if (filters.role && filters.role !== 'all') {
      const r = filters.role.toLowerCase().trim();
      filtered = filtered.filter(t => t.role === r);
    }

    if (filters.assignee && filters.assignee !== 'all') {
      const a = filters.assignee.toLowerCase().trim();
      filtered = filtered.filter(t => (t.assignee || '').toLowerCase() === a || (t.assigneeName || '').toLowerCase() === a);
    }

    if (filters.status && filters.status !== 'all') {
      const s = normalizeStatus(filters.status);
      filtered = filtered.filter(t => t.status === s);
    }

    if (filters.projectId) {
      const pid = String(filters.projectId).toLowerCase().trim();
      filtered = filtered.filter(t => t.projectId.toLowerCase() === pid || t.projectJobId.toLowerCase() === pid);
    }

    if (filters.search) {
      const q = String(filters.search).toLowerCase().trim();
      filtered = filtered.filter(t =>
        t.name.toLowerCase().includes(q) ||
        t.projectId.toLowerCase().includes(q) ||
        t.projectTitle.toLowerCase().includes(q) ||
        t.assignee.toLowerCase().includes(q) ||
        t.channel.toLowerCase().includes(q)
      );
    }

    // Sort: highest weight / overdue / newest first
    filtered.sort((a, b) => {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return (b.weight || 0) - (a.weight || 0);
    });

    return filtered;
  }

  /**
   * Retrieves summary metrics across all tasks.
   */
  static getStats() {
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
}

module.exports = TaskService;

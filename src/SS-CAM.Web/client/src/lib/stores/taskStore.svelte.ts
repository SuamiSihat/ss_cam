/**
 * Studio Tasks Store using Svelte 5 Runes
 * Manages lightweight pre-production activities, ideation briefs, and NAS provisioning
 */
import type { StudioTask, StudioTaskStatus, ProjectPriority } from '$lib/types';
import { ApiClient } from '$lib/services/api';
import { appState } from './appState.svelte';

export interface TaskFilterState {
  query: string;
  status: string;
  brand: string;
  assignee: string;
  priority: string;
}

class TaskStore {
  tasks = $state<StudioTask[]>([]);
  isLoading = $state<boolean>(false);
  isSaving = $state<boolean>(false);
  isProvisioning = $state<boolean>(false);
  selectedTask = $state<StudioTask | null>(null);

  activeFilters = $state<TaskFilterState>({
    query: '',
    status: 'all',
    brand: 'all',
    assignee: 'all',
    priority: 'all'
  });

  // Filtered tasks computed via Svelte 5 $derived.by
  filteredTasks = $derived.by(() => {
    return this.tasks.filter(t => {
      const { query, status, brand, assignee, priority } = this.activeFilters;

      if (status !== 'all' && t.status !== status) {
        return false;
      }

      if (brand !== 'all' && t.brand !== brand) {
        return false;
      }

      if (assignee !== 'all') {
        const cleanA = assignee.toLowerCase();
        const matchAssignee = (t.assignee || '').toLowerCase() === cleanA;
        const matchName = (t.assigneeName || '').toLowerCase() === cleanA;
        if (!matchAssignee && !matchName) return false;
      }

      if (priority !== 'all' && t.priority !== priority) {
        return false;
      }

      if (query && query.trim() !== '') {
        const q = query.toLowerCase();
        const matchId = (t.id || '').toLowerCase().includes(q);
        const matchTitle = (t.title || '').toLowerCase().includes(q);
        const matchDesc = (t.description || '').toLowerCase().includes(q);
        const matchAssignee = (t.assigneeName || t.assignee || '').toLowerCase().includes(q);
        const matchTags = t.tags && t.tags.some(tag => tag.toLowerCase().includes(q));
        if (!matchId && !matchTitle && !matchDesc && !matchAssignee && !matchTags) {
          return false;
        }
      }

      return true;
    });
  });

  // Summary counts for filter tabs & headers
  counts = $derived.by(() => {
    const res = {
      all: this.tasks.length,
      backlog: 0,
      'in-progress': 0,
      review: 0,
      done: 0,
      converted: 0
    };
    for (const t of this.tasks) {
      if (t.status in res) {
        (res as any)[t.status] += 1;
      }
    }
    return res;
  });

  async loadTasks(silent = false) {
    if (!silent && this.tasks.length === 0) {
      this.isLoading = true;
    }
    try {
      const res = await ApiClient.getStudioTasks();
      if (res && res.success && Array.isArray(res.tasks)) {
        this.tasks = res.tasks;
      }
    } catch (err: any) {
      if (!silent) {
        appState.addToast(`Failed to load studio tasks: ${err.message}`, 'error');
      }
    } finally {
      this.isLoading = false;
    }
  }

  async createTask(data: Partial<StudioTask>): Promise<StudioTask | null> {
    this.isSaving = true;
    try {
      const res = await ApiClient.createStudioTask(data);
      if (res && res.success && res.task) {
        this.tasks = [res.task, ...this.tasks];
        appState.addToast(`Studio Task ${res.task.id} created!`, 'success');
        return res.task;
      }
      return null;
    } catch (err: any) {
      appState.addToast(`Could not create task: ${err.message}`, 'error');
      return null;
    } finally {
      this.isSaving = false;
    }
  }

  async updateTask(id: string, updates: Partial<StudioTask>): Promise<StudioTask | null> {
    this.isSaving = true;
    try {
      const res = await ApiClient.updateStudioTask(id, updates);
      if (res && res.success && res.task) {
        const idx = this.tasks.findIndex(t => t.id === id);
        if (idx >= 0) {
          this.tasks[idx] = res.task;
        }
        if (this.selectedTask && this.selectedTask.id === id) {
          this.selectedTask = res.task;
        }
        appState.addToast(`Task ${res.task.id} updated`, 'success');
        return res.task;
      }
      return null;
    } catch (err: any) {
      appState.addToast(`Failed to update task: ${err.message}`, 'error');
      return null;
    } finally {
      this.isSaving = false;
    }
  }

  async updateTaskStatus(id: string, newStatus: StudioTaskStatus): Promise<boolean> {
    const task = this.tasks.find(t => t.id === id);
    if (!task) return false;
    const oldStatus = task.status;
    task.status = newStatus;

    try {
      await ApiClient.updateStudioTask(id, { status: newStatus });
      appState.addToast(`Task moved to ${newStatus.replace('-', ' ')}`, 'info');
      return true;
    } catch (err: any) {
      task.status = oldStatus;
      appState.addToast(`Could not move task: ${err.message}`, 'error');
      return false;
    }
  }

  async deleteTask(id: string): Promise<boolean> {
    try {
      await ApiClient.deleteStudioTask(id);
      this.tasks = this.tasks.filter(t => t.id !== id);
      if (this.selectedTask && this.selectedTask.id === id) {
        this.selectedTask = null;
      }
      appState.addToast(`Task ${id} deleted`, 'info');
      return true;
    } catch (err: any) {
      appState.addToast(`Failed to delete task: ${err.message}`, 'error');
      return false;
    }
  }

  async provisionTask(id: string, options: Record<string, any> = {}): Promise<any> {
    this.isProvisioning = true;
    try {
      const res = await ApiClient.provisionTaskWorkspace(id, options);
      if (res && res.success) {
        // Update task locally
        const idx = this.tasks.findIndex(t => t.id === id);
        if (idx >= 0 && res.task) {
          this.tasks[idx] = res.task;
        }
        if (this.selectedTask && this.selectedTask.id === id && res.task) {
          this.selectedTask = res.task;
        }
        appState.addToast(`🚀 NAS Workspace Provisioned! Job ID: ${res.jobId}`, 'success', 'Bridge Complete', 6000);
        return res;
      }
      throw new Error(res?.message || 'Provisioning failed');
    } catch (err: any) {
      appState.addToast(`Failed to provision workspace: ${err.message}`, 'error');
      return null;
    } finally {
      this.isProvisioning = false;
    }
  }

  setFilter(key: keyof TaskFilterState, val: string) {
    this.activeFilters[key] = val;
  }

  resetFilters() {
    this.activeFilters = {
      query: '',
      status: 'all',
      brand: 'all',
      assignee: 'all',
      priority: 'all'
    };
  }
}

export const taskStore = new TaskStore();

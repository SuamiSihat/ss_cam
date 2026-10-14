/**
 * Type-Safe API Client for SS-CAM Web Portal
 */
import type { 
  Project, 
  ProjectFrontmatter, 
  User, 
  DashboardData, 
  DeliverableItem, 
  FilterState, 
  ApprovalRecord,
  CreativeDirectionState,
  CopywritingState,
  TeamMember,
  StudioTask
} from '$lib/types';

const API_BASE = '/api';

export class ApiClient {
  static getToken(): string {
    return localStorage.getItem('ss_cam_token') || '';
  }

  static setToken(token: string): void {
    localStorage.setItem('ss_cam_token', token);
  }

  static removeToken(): void {
    localStorage.removeItem('ss_cam_token');
  }

  static async request<T = any>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE}${endpoint}`;
    const token = this.getToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      ...((options.headers as Record<string, string>) || {})
    };

    let response: Response;
    try {
      response = await fetch(url, { ...options, headers });
    } catch (err: any) {
      console.error(`[API Error] ${endpoint}:`, err.message);
      throw new Error("Can't reach the server. Check your connection and try again.");
    }

    try {
      const data = await response.json().catch(() => ({}));

      if (response.status === 401 && endpoint !== '/auth/login') {
        this.removeToken();
        window.dispatchEvent(new CustomEvent('auth:required'));
        throw new Error('Your session has expired. Please sign in again.');
      }

      // Expired or invalid session: send the person back to the sign-in screen.
      if (response.status === 403 && (data.code === 'SESSION_EXPIRED' || data.code === 'PASSWORD_CHANGE_REQUIRED')) {
        this.removeToken();
        window.dispatchEvent(new CustomEvent('auth:required'));
      }

      if (!response.ok) {
        // Server errors carry technical detail: log it, show a plain message instead.
        if (response.status >= 500) {
          console.error(`[API Error] ${endpoint}: ${response.status}`, data.error);
          throw new Error('Something went wrong on our side. Please try again.');
        }
        const httpErr: any = new Error(data.error || ApiClient.friendlyStatusMessage(response.status));
        httpErr.status = response.status;
        throw httpErr;
      }

      return data as T;
    } catch (err: any) {
      console.error(`[API Error] ${endpoint}:`, err.message);
      throw err;
    }
  }

  private static friendlyStatusMessage(status: number): string {
    if (status === 403) return "You don't have permission to do this. Ask an admin for access.";
    if (status === 404) return "We couldn't find that item. It may have been moved or deleted.";
    if (status === 413) return 'That file is too large to upload.';
    if (status === 429) return 'Too many attempts. Please wait a moment and try again.';
    return 'Something went wrong. Please try again.';
  }

  // ─── Authentication ───
  /** mustChangePassword: the account still uses the default password; the token only allows changePassword(). */
  static login(username: string, password: string): Promise<{ success: boolean; token: string; user: User; mustChangePassword?: boolean }> {
    return this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password })
    });
  }

  static getMe(): Promise<{ user: User }> {
    return this.request('/auth/me');
  }

  /**
   * Signs out on the server (the session stops working everywhere it was copied) and forgets it here.
   * The token is cleared first so nothing can reuse it while the request is in flight.
   */
  static async signOut(): Promise<void> {
    const token = this.getToken();
    this.removeToken();
    this.stopMediaKeepAlive();
    if (!token) return;
    try {
      await fetch(`${API_BASE}/auth/logout`, { method: 'POST', headers: { Authorization: `Bearer ${token}` } });
    } catch (err: any) {
      console.warn('[API] Sign-out request did not reach the server:', err?.message);
    }
  }

  // ─── Media session (images, downloads and live updates) ───
  // Browsers cannot attach a header to <img>, video, download links or EventSource, so the server
  // gives a short-lived, read-only cookie after sign-in. It is renewed while the app is open.
  private static mediaKeepAliveTimer: number | null = null;

  static async refreshMediaSession(): Promise<boolean> {
    if (!this.getToken()) return false;
    try {
      await this.request('/auth/media-session', { method: 'POST' });
      return true;
    } catch (err: any) {
      console.warn('[API] Could not refresh the media session:', err?.message);
      return false;
    }
  }

  static startMediaKeepAlive(): void {
    if (typeof window === 'undefined' || this.mediaKeepAliveTimer !== null) return;
    this.refreshMediaSession();
    this.mediaKeepAliveTimer = window.setInterval(() => this.refreshMediaSession(), 30 * 60 * 1000);
  }

  static stopMediaKeepAlive(): void {
    if (this.mediaKeepAliveTimer !== null) {
      window.clearInterval(this.mediaKeepAliveTimer);
      this.mediaKeepAliveTimer = null;
    }
  }

  /** Pass `token` to use a restricted sign-in token (forced change) instead of the stored session. */
  static changePassword(currentPassword: string, newPassword: string, token?: string): Promise<{ success: boolean; message: string; token?: string; user?: User }> {
    return this.request('/auth/change-password', {
      method: 'POST',
      body: JSON.stringify({ currentPassword, newPassword }),
      ...(token ? { headers: { Authorization: `Bearer ${token}` } } : {})
    });
  }

  /** `currentPassword` is required by the server when the email address changes. */
  static async updateProfile(data: Partial<User> & { staffId?: string; currentPassword?: string }): Promise<{ success: boolean; user: User }> {
    try {
      return await this.request('/auth/profile', {
        method: 'PUT',
        body: JSON.stringify(data)
      });
    } catch (err: any) {
      if (err.status === 404) {
        const id = data.staffId || 'SS0004';
        const res = await this.request<any>(`/users/${encodeURIComponent(id)}`, {
          method: 'PUT',
          body: JSON.stringify(data)
        });
        return { success: true, user: res.user || res.member || res };
      }
      throw err;
    }
  }

  // ─── Dashboard ───
  static getDashboard(params: { timeRange?: string; brand?: string } = {}): Promise<DashboardData> {
    const qs = new URLSearchParams();
    if (params.timeRange && params.timeRange !== 'all') qs.append('timeRange', params.timeRange);
    if (params.brand && params.brand !== 'all') qs.append('brand', params.brand);
    const query = qs.toString() ? `?${qs.toString()}` : '';
    return this.request<DashboardData>(`/dashboard${query}`);
  }

  // ─── Projects ───
  static getProjects(filters: Partial<FilterState> = {}): Promise<{ projects: Project[]; total: number }> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '' && v !== 'all') {
        params.append(k, String(v));
      }
    });
    const qs = params.toString() ? `?${params.toString()}` : '';
    return this.request<{ projects: Project[]; total: number }>(`/projects${qs}`);
  }

  static getProject(id: string): Promise<{ project: Project; deliverables: DeliverableItem[]; exists: boolean }> {
    return this.request(`/projects/${encodeURIComponent(id)}`);
  }

  static updateProject(id: string, payload: Partial<ProjectFrontmatter>): Promise<{ success: boolean; project: Project }> {
    return this.request(`/projects/${encodeURIComponent(id)}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  static deleteProject(id: string): Promise<{ success: boolean; message: string; projectId: string }> {
    return this.request(`/projects/${encodeURIComponent(id)}`, {
      method: 'DELETE'
    });
  }

  static updateBrief(id: string, briefMarkdown: string, expectedHash: string | null = null): Promise<{ success: boolean; versionHash: string }> {
    return this.request(`/projects/${encodeURIComponent(id)}/brief`, {
      method: 'PUT',
      body: JSON.stringify({ briefMarkdown, expectedHash })
    });
  }

  static ingestFile(projectId: string, filename: string, targetSubfolder: string, fileData: string): Promise<{ success: boolean; filename: string; folder: string; sizeBytes: number; relPath: string }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/ingest`, {
      method: 'POST',
      body: JSON.stringify({ filename, targetSubfolder, fileData })
    });
  }

  static updateCreativeDirection(id: string, payload: CreativeDirectionState): Promise<{ success: boolean; creativeDirection: CreativeDirectionState }> {
    return this.request(`/projects/${encodeURIComponent(id)}/direction`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  static getCopywritingMarkdown(id: string): Promise<{ success: boolean; copywriting: { body: string; stats: any; filePath: string; lastUpdated: string } }> {
    return this.request(`/projects/${encodeURIComponent(id)}/copywriting`);
  }

  static updateCopywritingMarkdown(id: string, body: string): Promise<{ success: boolean; copywriting: any }> {
    return this.request(`/projects/${encodeURIComponent(id)}/copywriting`, {
      method: 'PUT',
      body: JSON.stringify({ body })
    });
  }

  static updateCopywriting(id: string, payload: any): Promise<{ success: boolean; copywriting: any }> {
    return this.request(`/projects/${encodeURIComponent(id)}/copywriting`, {
      method: 'PUT',
      body: JSON.stringify(typeof payload === 'string' ? { body: payload } : payload)
    });
  }

  static submitDecision(id: string, payload: { decision: string; comment?: string; deliverableId?: string }): Promise<{ success: boolean }> {
    return this.request(`/projects/${encodeURIComponent(id)}/decision`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Deliverables ───
  static getDeliverables(): Promise<{ deliverables: DeliverableItem[]; count: number }> {
    return this.request('/deliverables');
  }

  // ─── Team & Roster ───
  static getTeam(): Promise<{ team: TeamMember[] }> {
    return this.request<{ team: TeamMember[] }>('/team');
  }

  // ─── User & Staff Management ───
  static async getUsers(): Promise<{ success: boolean; users: any[] }> {
    try {
      return await this.request('/users');
    } catch {
      const res = await this.request('/team/roster');
      return { success: true, users: res.roster || [] };
    }
  }

  static async getStaffAccounts(): Promise<{ success: boolean; users: any[] }> {
    return this.getUsers();
  }

  static async getStaffRoster(): Promise<{ roster: any[]; users?: any[] }> {
    try {
      return await this.request('/team/roster');
    } catch {
      const res = await this.request('/users');
      return { roster: res.users || [] };
    }
  }

  static async addStaffMember(payload: any): Promise<{ success: boolean; member: any }> {
    try {
      return await this.request('/users', {
        method: 'POST',
        body: JSON.stringify(payload)
      });
    } catch {
      return await this.request('/team/roster', {
        method: 'POST',
        body: JSON.stringify(payload)
      });
    }
  }

  static async updateStaffMember(id: string, payload: any): Promise<{ success: boolean; member: any }> {
    try {
      return await this.request(`/users/${encodeURIComponent(id)}`, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });
    } catch {
      return await this.request(`/team/roster/${encodeURIComponent(id)}`, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });
    }
  }

  static deleteUser(id: string): Promise<{ success: boolean; deletedStaffId: string }> {
    return this.request(`/users/${encodeURIComponent(id)}`, {
      method: 'DELETE'
    });
  }

  static resetUserPassword(username: string, newPassword?: string): Promise<{ success: boolean; message: string }> {
    return this.request(`/users/${encodeURIComponent(username)}/reset-password`, {
      method: 'POST',
      body: JSON.stringify({ newPassword })
    });
  }

  // ─── Comments & Visual Annotations ───
  static getComments(projectId: string): Promise<{ success: boolean; comments: any[] }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/comments`);
  }

  static addComment(
    projectId: string,
    data: string | { content: string; deliverableId?: string; annotation?: { x: number; y: number; pinNumber?: number; priority?: string }; mentions?: string[] },
    deliverableId?: string | null
  ): Promise<{ success: boolean; comment: any }> {
    const payload = typeof data === 'string'
      ? { content: data, deliverableId: deliverableId || undefined }
      : data;
    return this.request(`/projects/${encodeURIComponent(projectId)}/comments`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static resolveComment(projectId: string, commentId: string, resolved = true): Promise<{ success: boolean; commentId: string; resolved: boolean }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/comments/${encodeURIComponent(commentId)}/resolve`, {
      method: 'PUT',
      body: JSON.stringify({ resolved })
    });
  }

  static deleteComment(projectId: string, commentId: string): Promise<{ success: boolean; deleted: boolean }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/comments/${encodeURIComponent(commentId)}`, {
      method: 'DELETE'
    });
  }

  // ─── Company & Subsidiary Directory ───
  static getCompanies(): Promise<{ success: boolean; companies: any[] }> {
    return this.request('/companies');
  }

  /** Minimal active-company list for the sign-in page (no sign-in needed, no business details). */
  static getPublicCompanies(): Promise<{ success: boolean; companies: any[] }> {
    return this.request('/companies/public');
  }

  static getCompany(code: string): Promise<{ success: boolean; company: any }> {
    return this.request(`/companies/${encodeURIComponent(code)}`);
  }

  static saveCompany(payload: any): Promise<{ success: boolean; company: any }> {
    return this.request('/companies', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static deleteCompany(code: string): Promise<{ success: boolean; deletedCode: string }> {
    return this.request(`/companies/${encodeURIComponent(code)}`, {
      method: 'DELETE'
    });
  }

  // ─── Notifications & Live Activity ───
  static getNotifications(limit: number = 25): Promise<{ notifications: any[]; unreadCount: number }> {
    return this.request(`/notifications?limit=${limit}`);
  }

  // ─── Real-Time Server-Sent Events (SSE) Stream ───
  // The stream needs the media cookie. If the server refuses it (expired cookie) the browser stops
  // retrying by itself, so we renew the cookie and reconnect with a growing delay.
  static initEventStream(onEvent: (event: string, data: any) => void): () => void {
    let eventSource: EventSource | null = null;
    let stopped = false;
    let retryTimer: number | null = null;
    let retryDelay = 3000;

    const handleMessage = (evt: MessageEvent, eventName: string) => {
      try {
        const parsed = JSON.parse(evt.data);
        onEvent(eventName, parsed);
      } catch {
        onEvent(eventName, evt.data);
      }
    };

    const notifyTaskChange = (e: MessageEvent) => {
      if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('task:updated', { detail: e }));
    };

    const connect = () => {
      if (stopped) return;
      const es = new EventSource('/api/events');
      eventSource = es;

      es.onopen = () => {
        retryDelay = 3000;
        onEvent('connection:status', { status: 'connected' });
      };

      es.addEventListener('connected', (e) => {
        handleMessage(e as MessageEvent, 'connected');
        onEvent('connection:status', { status: 'connected' });
      });
      es.addEventListener('workspace:updated', (e) => handleMessage(e as MessageEvent, 'workspace:updated'));
      es.addEventListener('project:updated', (e) => handleMessage(e as MessageEvent, 'project:updated'));
      es.addEventListener('project:decision', (e) => handleMessage(e as MessageEvent, 'project:decision'));
      es.addEventListener('comment:added', (e) => handleMessage(e as MessageEvent, 'comment:added'));
      es.addEventListener('comment:resolved', (e) => handleMessage(e as MessageEvent, 'comment:resolved'));
      es.addEventListener('team:updated', (e) => handleMessage(e as MessageEvent, 'team:updated'));
      es.addEventListener('company:updated', (e) => handleMessage(e as MessageEvent, 'company:updated'));
      es.addEventListener('task:created', (e) => { handleMessage(e as MessageEvent, 'task:created'); notifyTaskChange(e as MessageEvent); });
      es.addEventListener('task:updated', (e) => { handleMessage(e as MessageEvent, 'task:updated'); notifyTaskChange(e as MessageEvent); });
      es.addEventListener('task:deleted', (e) => { handleMessage(e as MessageEvent, 'task:deleted'); notifyTaskChange(e as MessageEvent); });

      es.onerror = (err) => {
        onEvent('connection:status', { status: 'reconnecting' });
        // CONNECTING: the browser is already retrying. CLOSED: the server refused us, so renew and retry.
        if (es.readyState === EventSource.CLOSED && !stopped) {
          console.warn('[SSE] Connection was refused. Renewing the session and retrying...', err);
          es.close();
          retryTimer = window.setTimeout(async () => {
            if (stopped) return;
            if (await ApiClient.refreshMediaSession()) connect();
            else if (ApiClient.getToken()) { retryDelay = Math.min(retryDelay * 2, 60000); connect(); }
          }, retryDelay);
          retryDelay = Math.min(retryDelay * 2, 60000);
        } else {
          console.warn('[SSE] Connection interrupted, retrying in background...', err);
        }
      };
    };

    connect();

    return () => {
      stopped = true;
      if (retryTimer !== null) window.clearTimeout(retryTimer);
      eventSource?.close();
    };
  }

  // ─── Audit & System ───
  static getAuditLogs(params: Record<string, string> = {}): Promise<{ logs: any[] }> {
    const searchParams = new URLSearchParams(params);
    return this.request(`/audit?${searchParams.toString()}`);
  }

  static getSystemStatus(): Promise<any> {
    return this.request('/system/status');
  }

  static getWorkspaceCandidates(): Promise<{ success: boolean; candidates: Array<{ path: string; accessible: boolean; itemCount: number; isCurrent: boolean }>; current: string }> {
    return this.request('/system/workspace-candidates');
  }

  static updateWorkspaceRoot(workspacePath: string): Promise<{ success: boolean; workspaceRoot: string; cachedProjects: number; message: string }> {
    return this.request('/system/workspace-root', {
      method: 'POST',
      body: JSON.stringify({ workspacePath })
    });
  }

  // ─── Share & Public Review ───
  static generateShareLink(payload: { projectId: string; deliverableId?: string | null; expiresInDays?: number; permissions?: string; note?: string }): Promise<{ success: boolean; share: any }> {
    return this.request('/share/generate', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static getProjectShareLinks(projectId: string): Promise<{ success: boolean; links: any[] }> {
    return this.request(`/share/list/${encodeURIComponent(projectId)}`);
  }

  static revokeShareLink(token: string): Promise<{ success: boolean }> {
    return this.request(`/share/${encodeURIComponent(token)}`, {
      method: 'DELETE'
    });
  }

  static getPublicReview(token: string): Promise<any> {
    return this.request(`/public/review/${encodeURIComponent(token)}`);
  }

  static getPublicComments(token: string): Promise<{ comments: any[] }> {
    return this.request(`/public/review/${encodeURIComponent(token)}/comments`);
  }

  static getPublicDownloadUrl(token: string, preset = 'all'): string {
    return `/api/public/review/${encodeURIComponent(token)}/download?preset=${encodeURIComponent(preset)}`;
  }

  /** Download link. The browser sends the media cookie, so no sign-in token is put in the address. */
  static getProjectExportUrl(projectId: string, preset = 'all'): string {
    return `/api/projects/${encodeURIComponent(projectId)}/export?preset=${encodeURIComponent(preset)}`;
  }

  static submitPublicDecision(token: string, payload: { decision: string; reviewerName: string; reviewerOrg?: string; comment?: string; deliverableId?: string | null }): Promise<any> {
    return this.request(`/public/review/${encodeURIComponent(token)}/decision`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static submitPublicComment(token: string, payload: { content: string; reviewerName?: string; author?: string; authorOrg?: string; reviewerOrg?: string; deliverableId?: string | null; pinX?: number; pinY?: number; annotation?: any }): Promise<any> {
    return this.request(`/public/review/${encodeURIComponent(token)}/comments`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Gemini Creative AI Studio ───
  static getAiStatus(): Promise<{ configured: boolean; maskedKey: string; preferredModel: string; availableModels: string[] }> {
    return this.request('/ai/status');
  }

  static saveAiConfig(payload: { apiKey: string; preferredModel?: string }): Promise<{ success: boolean; status: any }> {
    return this.request('/ai/config', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static generateAiHooks(payload: { brand?: string; product?: string; audience?: string; angle?: string; language?: string }): Promise<{ success: boolean; hooks: string }> {
    return this.request('/ai/generate-hooks', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static generateAiScript(payload: { brand?: string; product?: string; hook?: string; platform?: string; language?: string }): Promise<{ success: boolean; script: string }> {
    return this.request('/ai/generate-script', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static generateAiImagePrompts(payload: { product?: string; style?: string; environment?: string; brandColors?: string }): Promise<{ success: boolean; prompts: string }> {
    return this.request('/ai/generate-image-prompts', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static formatUltraPrompt(payload: { brand?: string; title?: string; audience?: string; goal?: string }): Promise<{ success: boolean; prompt: string }> {
    return this.request('/ai/format-prompt', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Project Snapshots & Version Timeline ───
  static getProjectSnapshots(projectId: string): Promise<{ success: boolean; snapshots: any[] }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/snapshots`);
  }

  static createProjectSnapshot(projectId: string, payload: { trigger?: string; note?: string }): Promise<{ success: boolean; snapshot: any }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/snapshot`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static rollbackProject(projectId: string, snapshotId: string): Promise<{ success: boolean; restoredSnapshot: any; message: string }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/rollback`, {
      method: 'POST',
      body: JSON.stringify({ snapshotId })
    });
  }

  // ─── Workload Reassign ───
  static reassignProject(projectId: string, payload: { newDesigner: string; reason?: string }): Promise<{ success: boolean; designer: string; message: string }> {
    return this.request(`/projects/${encodeURIComponent(projectId)}/reassign`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Webhooks ───
  static getWebhooks(): Promise<{ success: boolean; webhooks: any[] }> {
    return this.request('/webhooks');
  }

  static addWebhook(payload: { name: string; url: string; serviceType?: string; events?: string[]; active?: boolean }): Promise<{ success: boolean; webhook: any }> {
    return this.request('/webhooks', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static deleteWebhook(id: string): Promise<{ success: boolean }> {
    return this.request(`/webhooks/${encodeURIComponent(id)}`, {
      method: 'DELETE'
    });
  }

  static testWebhook(payload: { url: string; serviceType?: string }): Promise<{ success: boolean; result: any }> {
    return this.request('/webhooks/test', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Live Studio Tasks & Telemetry ───
  static getLiveTasks(): Promise<{ success: boolean; liveTasks: any[]; count: number; activeCount: number }> {
    return this.request('/team/live-tasks');
  }

  // ─── ClickUp Tasks & Workstream Engine ───
  static getTasks(params: { role?: string; assignee?: string; status?: string; projectId?: string; search?: string } = {}): Promise<{ success: boolean; tasks: any[]; stats: any }> {
    const query = new URLSearchParams();
    if (params.role) query.set('role', params.role);
    if (params.assignee) query.set('assignee', params.assignee);
    if (params.status) query.set('status', params.status);
    if (params.projectId) query.set('projectId', params.projectId);
    if (params.search) query.set('search', params.search);
    const qs = query.toString();
    return this.request(`/tasks${qs ? `?${qs}` : ''}`);
  }

  static createTask(payload: { projectId: string; name: string; role?: string; assignee?: string; assigneeName?: string; status?: string; weight?: number; channel?: string; specs?: string; notes?: string; deliverableId?: string; linkedFile?: string }): Promise<{ success: boolean; task: any }> {
    return this.request('/tasks', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static updateTask(projectId: string, taskId: string, updates: Record<string, any>): Promise<{ success: boolean; task: any }> {
    return this.request(`/tasks/${encodeURIComponent(projectId)}/${encodeURIComponent(taskId)}`, {
      method: 'PATCH',
      body: JSON.stringify(updates)
    });
  }

  static deleteTask(projectId: string, taskId: string): Promise<{ success: boolean; taskId: string; projectId: string }> {
    return this.request(`/tasks/${encodeURIComponent(projectId)}/${encodeURIComponent(taskId)}`, {
      method: 'DELETE'
    });
  }

  // ─── Studio Tasks Manager (Lightweight Pre-Production Pipeline) ───
  static getStudioTasks(filters: Record<string, any> = {}): Promise<{ success: boolean; tasks: StudioTask[]; stats?: any; count: number }> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, val]) => {
      if (val !== undefined && val !== null && val !== '' && val !== 'all') {
        params.append(key, String(val));
      }
    });
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/studio-tasks${query}`);
  }

  static getStudioTask(id: string): Promise<{ success: boolean; task: StudioTask }> {
    return this.request(`/studio-tasks/${encodeURIComponent(id)}`);
  }

  static createStudioTask(payload: Partial<StudioTask>): Promise<{ success: boolean; task: StudioTask }> {
    return this.request('/studio-tasks', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  static updateStudioTask(id: string, payload: Partial<StudioTask>): Promise<{ success: boolean; task: StudioTask }> {
    return this.request(`/studio-tasks/${encodeURIComponent(id)}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  static deleteStudioTask(id: string): Promise<{ success: boolean; id: string }> {
    return this.request(`/studio-tasks/${encodeURIComponent(id)}`, {
      method: 'DELETE'
    });
  }

  static provisionTaskWorkspace(id: string, options: Record<string, any> = {}): Promise<{
    success: boolean;
    jobId: string;
    projectId: string;
    folderName: string;
    projectDir: string;
    task: StudioTask;
    message: string;
  }> {
    return this.request(`/studio-tasks/${encodeURIComponent(id)}/provision`, {
      method: 'POST',
      body: JSON.stringify(options)
    });
  }

  static aiAssistStudioTask(id: string, payload: { action: string; prompt?: string }): Promise<{
    success: boolean;
    reply: string;
    suggestedSubtasks?: Array<{ id: string; title: string; completed: boolean }>;
    suggestedSpecs?: string;
    preflightIssues?: Array<{ type: 'blocker' | 'warning' | 'info'; message: string }>;
  }> {
    return this.request(`/studio-tasks/${encodeURIComponent(id)}/ai-assist`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // ─── Password Reset & Recovery Suite ───
  static forgotPassword(identifier: string): Promise<{ success: boolean; message: string }> {
    return this.request('/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({ identifier })
    });
  }

  static verifyResetToken(token: string): Promise<{ valid: boolean; username?: string; email?: string; error?: string }> {
    return this.request('/auth/verify-reset-token', {
      method: 'POST',
      body: JSON.stringify({ token })
    });
  }

  static resetPassword(token: string, newPassword: string): Promise<{ success: boolean; message: string }> {
    return this.request('/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token, newPassword })
    });
  }
}



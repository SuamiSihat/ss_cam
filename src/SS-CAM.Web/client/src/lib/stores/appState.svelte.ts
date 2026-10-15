/**
 * Global App State Store using Svelte 5 Runes
 */
import type { User, ThemeName, ToastMessage } from '$lib/types';
import { ApiClient } from '$lib/services/api';

class AppStateStore {
  currentUser = $state<User | null>(null);
  currentRoute = $state<string>('dashboard');
  routeParams = $state<Record<string, any>>({});
  private static readonly VALID_THEMES: ThemeName[] = ['falconia', 'dark'];
  private static getStoredTheme(): ThemeName {
    const stored = localStorage.getItem('ss_cam_theme') as ThemeName;
    return AppStateStore.VALID_THEMES.includes(stored) ? stored : 'falconia';
  }
  theme = $state<ThemeName>(AppStateStore.getStoredTheme());
  sidebarExpanded = $state<boolean>(true);
  sidebarRail = $state<boolean>(false); // icon-only rail mode
  toasts = $state<ToastMessage[]>([]);
  isRescanning = $state<boolean>(false);
  globalSearch = $state<string>('');
  notificationCount = $state<number>(0);
  notificationDrawerOpen = $state<boolean>(false);
  userMenuOpen = $state<boolean>(false);
  contextDrawerOpen = $state<boolean>(false);
  sseStatus = $state<'connected' | 'reconnecting' | 'disconnected'>('disconnected');
  isOnline = $state<boolean>(typeof navigator !== 'undefined' ? navigator.onLine : true);
  lastSyncedAt = $state<Date | null>(null);
  liveTasks = $state<any[]>([]);
  activeLiveTasks = $derived(this.liveTasks.filter(t => (t.State || '').toLowerCase() === 'running'));
  studioDrawerOpen = $state<boolean>(false);

  constructor() {
    this.applyTheme(this.theme);
    if (typeof window !== 'undefined') {
      window.addEventListener('online', () => { this.isOnline = true; });
      window.addEventListener('offline', () => { this.isOnline = false; });
    }
  }

  setTheme(newTheme: ThemeName) {
    this.theme = newTheme;
    localStorage.setItem('ss_cam_theme', newTheme);
    this.applyTheme(newTheme);
  }

  applyTheme(themeName: ThemeName) {
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', themeName);
    }
  }

  toggleSidebar() {
    if (typeof window !== 'undefined' && window.innerWidth < 900) {
      this.sidebarExpanded = !this.sidebarExpanded;
    } else {
      this.sidebarExpanded = true;
      this.sidebarRail = !this.sidebarRail;
    }
  }

  expandSidebar() {
    this.sidebarExpanded = true;
    this.sidebarRail = false;
  }

  navigate(route: string, params: Record<string, any> = {}) {
    this.currentRoute = route;
    this.routeParams = params;
    window.location.hash = route + (params.id ? `/${encodeURIComponent(params.id)}` : '');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  addToast(message: string, type: ToastMessage['type'] = 'info', title?: string, timeoutMs = 4000) {
    const id = `toast-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
    const toast: ToastMessage = { id, message, type, title, timeoutMs };
    this.toasts = [...this.toasts, toast];

    if (timeoutMs > 0) {
      setTimeout(() => {
        this.removeToast(id);
      }, timeoutMs);
    }
  }

  removeToast(id: string) {
    this.toasts = this.toasts.filter(t => t.id !== id);
  }

  hasPermission(permission: string): boolean {
    if (!this.currentUser) return false;
    return this.currentUser.permissions?.includes(permission) ?? false;
  }

  canApprove(): boolean {
    return this.currentUser?.capabilities?.canApproveDeliverables ?? false;
  }

  can(action: keyof import('$lib/types').UserCapabilities): boolean {
    const val = this.currentUser?.capabilities?.[action];
    return typeof val === 'boolean' ? val : false;
  }

  async loadCurrentUser() {
    const token = ApiClient.getToken();
    if (!token) {
      this.currentUser = null;
      return;
    }
    try {
      const res = await ApiClient.getMe();
      const capabilities = (res as any).capabilities || res.user?.capabilities;
      this.currentUser = res.user ? { ...res.user, capabilities } : null;
      ApiClient.startMediaKeepAlive();
      this.loadNotificationCount();
    } catch {
      this.currentUser = null;
    }
  }

  async loadNotificationCount() {
    try {
      const res = await ApiClient.getNotifications(20);
      if (res && typeof res.unreadCount === 'number') {
        this.notificationCount = res.unreadCount;
      }
    } catch (e) {
      // Non-critical
    }
  }

  async loadLiveTasks() {
    try {
      const res = await ApiClient.getLiveTasks();
      if (res && res.success && Array.isArray(res.liveTasks)) {
        this.liveTasks = res.liveTasks;
      }
    } catch {
      // Non-critical telemetry fallback
    }
  }

  logout() {
    // Ends the session on the server too, so a copied token stops working.
    void ApiClient.signOut();
    this.currentUser = null;
    this.navigate('login');
    this.addToast('Signed out', 'info');
  }
}

export const appState = new AppStateStore();

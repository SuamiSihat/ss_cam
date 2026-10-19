import type { User, UserCapabilities } from '../types';

export type RouteGroup = 'Work' | 'Create' | 'Review' | 'Clinic' | 'Manage' | 'Admin' | 'Account';

export interface RouteDefinition {
  id: string;
  hash: string;
  label: string;
  shortLabel: string;
  icon: string;
  group: RouteGroup;
  capability?: keyof UserCapabilities;
  roles?: string[];
  mobileDock?: boolean;
  dockLabel?: string;
  badge?: 'pendingReviewCount';
  matchRoutes?: string[];
  newTab?: boolean;
  paletteKeywords: string[];
  layout: 'layout-page' | 'layout-full' | 'layout-fluid';
  parent?: string;
}

export const ROUTE_ICONS = {
  home: `<path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>`,
  tasks: `<path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-9 14l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/>`,
  projects: `<path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/>`,
  request: `<path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/>`,
  copy: `<path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/>`,
  approvals: `<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>`,
  clinic: `<path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"/>`,
  team: `<path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>`,
  display: `<path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 1.99-.9 1.99-2L23 5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>`,
  admin: `<path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6-3.6z"/>`,
  profile: `<path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>`
};

export const ROUTES: RouteDefinition[] = [
  // ── Work ────────────────────────────────────────────────────────────
  {
    id: 'dashboard',
    hash: 'dashboard',
    label: 'Home',
    shortLabel: 'Home',
    icon: ROUTE_ICONS.home,
    group: 'Work',
    mobileDock: true,
    dockLabel: 'Home',
    paletteKeywords: ['dashboard', 'home', 'overview', 'deck', 'workspace'],
    layout: 'layout-full'
  },
  {
    id: 'tasks',
    hash: 'tasks',
    label: 'My tasks',
    shortLabel: 'Tasks',
    icon: ROUTE_ICONS.tasks,
    group: 'Work',
    mobileDock: true,
    dockLabel: 'Tasks',
    paletteKeywords: ['tasks', 'my tasks', 'studio tasks', 'todo', 'kanban', 'workstream'],
    layout: 'layout-full'
  },
  {
    id: 'projects',
    hash: 'projects',
    label: 'Projects',
    shortLabel: 'Projects',
    icon: ROUTE_ICONS.projects,
    group: 'Work',
    mobileDock: true,
    dockLabel: 'Projects',
    matchRoutes: ['projects', 'project-detail'],
    paletteKeywords: ['projects', 'catalog', 'vault', 'files', 'jobs', 'nas'],
    layout: 'layout-fluid'
  },
  {
    id: 'project-detail',
    hash: 'projects',
    label: 'Project Workspace',
    shortLabel: 'Project',
    icon: ROUTE_ICONS.projects,
    group: 'Work',
    mobileDock: false,
    paletteKeywords: ['project workspace', 'project detail', 'deliverables', 'brief'],
    layout: 'layout-full',
    parent: 'projects'
  },

  // ── Create ──────────────────────────────────────────────────────────
  {
    id: 'order-form',
    hash: 'order-form',
    label: 'New request',
    shortLabel: 'Request',
    icon: ROUTE_ICONS.request,
    group: 'Create',
    mobileDock: false,
    paletteKeywords: ['new request', 'order', 'brief', 'job request', 'creative request'],
    layout: 'layout-page'
  },
  {
    id: 'copy-studio',
    hash: 'copy-studio',
    label: 'Copy studio',
    shortLabel: 'Copy',
    icon: ROUTE_ICONS.copy,
    group: 'Create',
    capability: 'canEditCopy',
    roles: ['admin', 'manager', 'designer', 'copywriter'],
    mobileDock: false,
    paletteKeywords: ['copy studio', 'copywriting', 'scripts', 'angles', 'hooks', 'ai', 'gemini'],
    layout: 'layout-page'
  },

  // ── Review ──────────────────────────────────────────────────────────
  {
    id: 'deliverables',
    hash: 'deliverables',
    label: 'Approvals',
    shortLabel: 'Approvals',
    icon: ROUTE_ICONS.approvals,
    group: 'Review',
    mobileDock: true,
    dockLabel: 'Approvals',
    badge: 'pendingReviewCount',
    paletteKeywords: ['approvals', 'deliverables', 'sign-off', 'review', 'assets', 'pending'],
    layout: 'layout-page'
  },

  // ── Clinic ──────────────────────────────────────────────────────────
  {
    id: 'consultation',
    hash: 'consultation',
    label: 'Consultation kit',
    shortLabel: 'Clinic',
    icon: ROUTE_ICONS.clinic,
    group: 'Clinic',
    capability: 'canViewConsultation',
    roles: ['admin', 'clinic'],
    mobileDock: false,
    paletteKeywords: ['consultation kit', 'consultation', 'clinic', 'medical', 'kit', 'branch', 'sop'],
    layout: 'layout-full'
  },

  // ── Manage ──────────────────────────────────────────────────────────
  {
    id: 'team',
    hash: 'team',
    label: 'Team',
    shortLabel: 'Team',
    icon: ROUTE_ICONS.team,
    group: 'Manage',
    mobileDock: false,
    paletteKeywords: ['team', 'staff', 'members', 'roster', 'workload', 'designers'],
    layout: 'layout-page'
  },
  {
    id: 'studio-display',
    hash: 'studio-display',
    label: 'Studio display',
    shortLabel: 'Display',
    icon: ROUTE_ICONS.display,
    group: 'Manage',
    roles: ['manager', 'admin', 'ceo'],
    mobileDock: false,
    paletteKeywords: ['studio display', 'signage', 'lounge tv', 'tv', 'kiosk', 'screen'],
    layout: 'layout-page'
  },

  // ── Admin ───────────────────────────────────────────────────────────
  {
    id: 'admin',
    hash: 'admin',
    label: 'Administration',
    shortLabel: 'Admin',
    icon: ROUTE_ICONS.admin,
    group: 'Admin',
    capability: 'canViewAdmin',
    roles: ['admin'],
    mobileDock: false,
    paletteKeywords: ['administration', 'admin', 'settings', 'system', 'audit', 'users', 'logs'],
    layout: 'layout-full'
  },

  // ── Account / System ────────────────────────────────────────────────
  {
    id: 'profile',
    hash: 'profile',
    label: 'Profile',
    shortLabel: 'Profile',
    icon: ROUTE_ICONS.profile,
    group: 'Account',
    mobileDock: false,
    paletteKeywords: ['profile', 'account', 'password', 'user settings'],
    layout: 'layout-full'
  }
];

export function getRouteById(id: string): RouteDefinition | undefined {
  return ROUTES.find(r => r.id === id);
}

export function getRouteByHash(hash: string): RouteDefinition | undefined {
  const clean = hash.replace(/^#\/?/, '').split('/')[0];
  return ROUTES.find(r => r.hash === clean || r.id === clean);
}

export function isRouteAllowed(route: RouteDefinition | string, user: User | null): boolean {
  if (!user) return false;
  const def = typeof route === 'string' ? getRouteById(route) || getRouteByHash(route) : route;
  if (!def) return false;

  // Check server-returned allowedRoutes first if available
  if (user.capabilities?.allowedRoutes && Array.isArray(user.capabilities.allowedRoutes)) {
    if (user.capabilities.allowedRoutes.includes(def.id)) return true;
    if (def.parent && user.capabilities.allowedRoutes.includes(def.parent)) return true;
  }

  // Admin always has access to all routes
  if (user.roleKey === 'admin' || user.capabilities?.canViewAdmin) return true;

  // If a capability is required on this route
  if (def.capability) {
    return !!user.capabilities?.[def.capability];
  }

  // If specific roles are required
  if (def.roles && def.roles.length > 0) {
    const roleKey = user.roleKey || (user.roles && user.roles[0]) || '';
    return def.roles.includes(roleKey);
  }

  return true;
}

export interface NavGroupSection {
  section: string;
  items: RouteDefinition[];
}

export function getNavGroups(user: User | null): NavGroupSection[] {
  const groups: { section: RouteGroup; label: string }[] = [
    { section: 'Work', label: 'Work' },
    { section: 'Create', label: 'Create' },
    { section: 'Review', label: 'Review' },
    { section: 'Clinic', label: 'Clinic' },
    { section: 'Manage', label: 'Manage' },
    { section: 'Admin', label: 'Admin' }
  ];

  const result: NavGroupSection[] = [];

  for (const g of groups) {
    const items = ROUTES.filter(r => r.group === g.section && !r.parent && r.id !== 'profile' && isRouteAllowed(r, user));
    if (items.length > 0) {
      result.push({
        section: g.label,
        items
      });
    }
  }

  return result;
}

export function getMobileDockRoutes(user: User | null): RouteDefinition[] {
  return ROUTES.filter(r => r.mobileDock && isRouteAllowed(r, user));
}

export const PAGE_CONFIG: Record<string, { title: string; layout: string; parent?: string }> = Object.fromEntries(
  ROUTES.map(r => [
    r.id,
    {
      title: r.label,
      layout: r.layout,
      ...(r.parent ? { parent: r.parent } : {})
    }
  ])
);

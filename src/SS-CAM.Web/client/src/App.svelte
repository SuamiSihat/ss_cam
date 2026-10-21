<script lang="ts">
  import { onMount } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import { projectStore } from '$lib/stores/projectStore.svelte';
  import { ApiClient } from '$lib/services/api';
  import FluentToast from '$lib/components/ui/FluentToast.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';
  import DashboardView from '$lib/views/DashboardView.svelte';
  import TasksView from '$lib/views/TasksView.svelte';
  import ProjectsView from '$lib/views/ProjectsView.svelte';
  import ProjectDetailView from '$lib/views/ProjectDetailView.svelte';
  import DeliverablesView from '$lib/views/DeliverablesView.svelte';
  import CopyStudioView from '$lib/views/CopyStudioView.svelte';
  import TeamView from '$lib/views/TeamView.svelte';
  import AdminView from '$lib/views/AdminView.svelte';
  import ProfileView from '$lib/views/ProfileView.svelte';
  import LoginView from '$lib/views/LoginView.svelte';
  import ResetPasswordView from '$lib/views/ResetPasswordView.svelte';
  import ClientReviewView from '$lib/views/ClientReviewView.svelte';
  import OrderFormView from '$lib/views/OrderFormView.svelte';
  import SignageView from '$lib/views/SignageView.svelte';
  import StudioDisplayView from '$lib/views/StudioDisplayView.svelte';
  import ConsultationSuiteView from '$lib/views/ConsultationSuiteView.svelte';
  import NotificationDrawer from '$lib/components/features/NotificationDrawer.svelte';
  import CommandPaletteModal from '$lib/components/features/CommandPaletteModal.svelte';
  import { ROUTES, PAGE_CONFIG, getNavGroups, getMobileDockRoutes, isRouteAllowed, getRouteById, getRouteByHash, type RouteDefinition } from '$lib/config/routes';

  let showDownloadModal = $state(false);
  let commandPaletteOpen = $state(false);
  let serverVersion = $state('5.3.0');

  function handleGlobalKeydown(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      commandPaletteOpen = !commandPaletteOpen;
    }
  }

  onMount(() => {
    function handleRouteFromHash() {
      const hash = window.location.hash.replace(/^#\/?/, '');
      if (hash.startsWith('reset-password')) {
        appState.currentRoute = 'reset-password';
        return;
      }
      if (hash.startsWith('review') || (window.location.search.includes('token=') && !hash.startsWith('reset-password'))) {
        appState.currentRoute = 'review';
        return;
      }
      if (hash.startsWith('signage') || hash.startsWith('kiosk')) {
        appState.currentRoute = 'kiosk';
        return;
      }
      if (!hash) {
        appState.currentRoute = 'dashboard';
        appState.routeParams = {};
        return;
      }
      const parts = hash.split('/');
      const route = parts[0];
      const id = parts[1] ? decodeURIComponent(parts[1]) : undefined;

      if (route === 'login') {
        appState.currentRoute = 'login';
        appState.routeParams = {};
        return;
      }

      const matchedRoute = getRouteByHash(route) || getRouteById(route);
      if (!matchedRoute) {
        appState.currentRoute = 'not-found';
        appState.routeParams = {};
        return;
      }

      if (appState.currentUser && !isRouteAllowed(matchedRoute, appState.currentUser)) {
        appState.navigate('dashboard');
        appState.addToast("You don't have access to that page.", 'error');
        return;
      }

      appState.currentRoute = matchedRoute.id;
      appState.routeParams = id ? { id } : {};
    }

    window.addEventListener('hashchange', handleRouteFromHash);
    handleRouteFromHash();

    if (appState.currentRoute !== 'review' && appState.currentRoute !== 'reset-password') {
      appState.loadCurrentUser().then(() => {
        appState.loadLiveTasks();
        const matched = getRouteById(appState.currentRoute);
        if (matched && appState.currentUser && !isRouteAllowed(matched, appState.currentUser)) {
          appState.navigate('dashboard');
          appState.addToast("You don't have access to that page.", 'error');
        }
      });
    }
    window.addEventListener('auth:required', () => appState.navigate('login'));

    // Fetch live server version for sidebar badge
    fetch('/api/status')
      .then(res => res.ok ? res.json() : null)
      .then(statusData => {
        if (statusData?.version) serverVersion = statusData.version;
      })
      .catch(() => { /* non-critical */ });

    window.addEventListener('click', (e) => {
      const target = e.target as HTMLElement;
      if (!target.closest('.user-menu-wrapper')) {
        appState.userMenuOpen = false;
      }
      if (!target.closest('.studio-pulse-container')) {
        appState.studioDrawerOpen = false;
      }
    });

    function handleResize() {
      if (window.innerWidth < 900) {
        appState.sidebarExpanded = false;
        appState.sidebarRail = false;
      } else {
        if (!appState.sidebarExpanded && !appState.sidebarRail) {
          appState.sidebarExpanded = true;
        }
      }
    }
    window.addEventListener('resize', handleResize);
    handleResize();

    // Initialize real-time SSE listener
    const closeSse = ApiClient.initEventStream((event, data) => {
      if (event === 'connection:status') {
        appState.sseStatus = data.status;
        if (data.status === 'connected') {
          appState.lastSyncedAt = new Date();
        }
      } else if (event === 'live_tasks:updated') {
        appState.lastSyncedAt = new Date();
        if (Array.isArray(data.liveTasks)) {
          appState.liveTasks = data.liveTasks;
        }
        window.dispatchEvent(new CustomEvent('live_tasks:updated', { detail: data }));
      } else if (event === 'workspace:updated' || event === 'project:updated') {
        appState.lastSyncedAt = new Date();
        projectStore.loadProjects(true);
        if (appState.currentRoute === 'dashboard') {
          projectStore.loadDashboard(undefined, true);
        } else if (appState.currentRoute === 'project-detail' && appState.routeParams.id) {
          projectStore.loadProjectDetail(appState.routeParams.id, true);
        } else if (appState.currentRoute === 'deliverables') {
          projectStore.loadDeliverables(true);
        }
        window.dispatchEvent(new CustomEvent('workspace:updated', { detail: data }));
      } else if (event === 'team:updated') {
        appState.lastSyncedAt = new Date();
        appState.loadCurrentUser();
        window.dispatchEvent(new CustomEvent('team:updated', { detail: data }));
      } else if (event === 'company:updated') {
        appState.lastSyncedAt = new Date();
        window.dispatchEvent(new CustomEvent('company:updated', { detail: data }));
      } else if (event === 'signage:updated') {
        appState.lastSyncedAt = new Date();
        window.dispatchEvent(new CustomEvent('signage:updated', { detail: data }));
      } else if (event === 'task:created' || event === 'task:updated' || event === 'task:deleted') {
        appState.lastSyncedAt = new Date();
        window.dispatchEvent(new CustomEvent('task:updated', { detail: data }));
      } else if (event === 'project:decision') {
        appState.lastSyncedAt = new Date();
        appState.notificationCount += 1;
        appState.addToast(`${data.reviewer} marked ${data.projectId} as ${(data.decision || '').replace('_', ' ')}`, 'info', 'Decision Updated');
        projectStore.loadProjects(true);
        if (appState.currentRoute === 'dashboard') {
          projectStore.loadDashboard(undefined, true);
        } else if (appState.currentRoute === 'project-detail' && appState.routeParams.id === data.projectId) {
          projectStore.loadProjectDetail(data.projectId, true);
        }
        window.dispatchEvent(new CustomEvent('workspace:updated', { detail: data }));
      } else if (event === 'comment:added') {
        appState.lastSyncedAt = new Date();
        if (data.comment?.author !== appState.currentUser?.name) {
          appState.notificationCount += 1;
          appState.addToast(`${data.comment?.author}: ${data.comment?.content?.substring(0, 40) || ''}...`, 'info', 'New Project Comment');
        }
        if (appState.currentRoute === 'project-detail' && appState.routeParams.id === data.projectId) {
          projectStore.loadProjectDetail(data.projectId, true);
        }
      } else if (event === 'workspace:archived') {
        appState.lastSyncedAt = new Date();
        appState.notificationCount += 1;
        projectStore.loadProjects(true);
        window.dispatchEvent(new CustomEvent('workspace:updated', { detail: data }));
      } else if (event === 'project:created') {
        appState.lastSyncedAt = new Date();
        appState.notificationCount += 1;
        projectStore.loadProjects(true);
        if (appState.currentRoute === 'dashboard') {
          projectStore.loadDashboard(undefined, true);
        }
        window.dispatchEvent(new CustomEvent('workspace:updated', { detail: data }));
      } else if (event === 'comment:resolved') {
        appState.lastSyncedAt = new Date();
        if (appState.currentRoute === 'project-detail' && appState.routeParams.id === data.projectId) {
          projectStore.loadProjectDetail(data.projectId, true);
        }
      } else if (event === 'order:new' || event === 'order:updated' || event === 'order:cancelled') { appState.lastSyncedAt = new Date(); window.dispatchEvent(new CustomEvent('order:updated', { detail: data })); }
    });

    return () => {
      closeSse();
    };
  });

  const currentConfig = $derived(PAGE_CONFIG[appState.currentRoute] ?? { title: 'SS-CAM', layout: 'layout-page' });
  const currentTitle  = $derived(
    appState.currentRoute === 'project-detail' && appState.routeParams.id
      ? appState.routeParams.id
      : currentConfig.title
  );

  const breadcrumbs = $derived.by(() => {
    const crumbs: { label: string; route?: string }[] = [{ label: 'SS-CAM Portal' }];
    const cfg = PAGE_CONFIG[appState.currentRoute];
    if (!cfg) return crumbs;
    if (cfg.parent) {
      const p = PAGE_CONFIG[cfg.parent];
      crumbs.push({ label: p?.title ?? cfg.parent, route: cfg.parent });
    }
    crumbs.push({ label: currentTitle });
    return crumbs;
  });

  const userInitial = $derived((appState.currentUser?.name ?? 'U').charAt(0).toUpperCase());
  const isRail = $derived(appState.sidebarRail && appState.sidebarExpanded);
  const isAdmin = $derived(appState.currentUser?.roleKey === 'admin' || !!appState.currentUser?.capabilities?.canViewAdmin);

  // Gated Navigation and Dock derived from routes config and server capabilities
  const visibleNavGroups = $derived(getNavGroups(appState.currentUser));
  const mobileDockRoutes = $derived(getMobileDockRoutes(appState.currentUser));

  function isActive(item: RouteDefinition) {
    if (item.newTab) return false;
    return item.matchRoutes ? item.matchRoutes.includes(appState.currentRoute) : appState.currentRoute === item.id;
  }
</script>

<svelte:window onkeydown={handleGlobalKeydown} />

{#if appState.currentRoute === 'kiosk'}
  <SignageView />
{:else if appState.currentRoute === 'review'}
  <ClientReviewView />
{:else if appState.currentRoute === 'reset-password'}
  <ResetPasswordView />
{:else if !appState.currentUser}
  <LoginView />
{:else}
  <div
    class="app-shell"
    class:sidebar-rail={isRail}
    class:sidebar-hidden={!appState.sidebarExpanded}
  >
    <!-- ═══ SIDEBAR ════════════════════════════════════════════════ -->
    <aside class="app-sidebar" class:is-rail={isRail}>

      <div class="sidebar-header" class:rail-header={isRail}>
        {#if !isRail}
          <img src="brand/suamisihat-logo-on-dark.svg" alt="SuamiSihat" class="sidebar-logo" />
          <span class="portal-pill">PORTAL</span>
        {:else}
          <div class="sidebar-logomark-wrap" title="SuamiSihat Portal">
            <img src="brand/ss-logomark.svg" alt="SuamiSihat Logomark" class="sidebar-logomark-svg" />
          </div>
        {/if}
      </div>

      <nav class="sidebar-nav" class:rail-nav={isRail} aria-label="Main Navigation">
        {#each visibleNavGroups as group}
          {#if !isRail}
            <div class="nav-section-label">{group.section}</div>
          {:else}
            <div class="nav-section-divider"></div>
          {/if}
          {#each group.items as item}
            {@const active = isActive(item)}
            {@const count  = item.badge ? projectStore.pendingReviewCount : 0}
            <a
              href="#{item.hash}"
              class="nav-link"
              class:active
              class:rail-link={isRail}
              title={isRail ? item.label : undefined}
              aria-current={active ? 'page' : undefined}
              target={item.newTab ? '_blank' : undefined}
              rel={item.newTab ? 'noopener noreferrer' : undefined}
            >
              <svg class="nav-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                {@html item.icon}
              </svg>
              {#if !isRail}
                <span class="nav-label">{item.label}</span>
              {/if}
              {#if count > 0}
                <span class="nav-badge" class:rail-badge={isRail}>{count}</span>
              {/if}
            </a>
          {/each}
        {/each}

        <div class="nav-spacer"></div>

        <!-- ═══ LIVE STUDIO PULSE (Above Download Badge) ═══ -->
        <div class="sidebar-pulse-container studio-pulse-container" class:rail-pulse-container={isRail} role="region" aria-label="Studio activity & shared drive sync">
          {#if !isRail}
            <button
              type="button"
              class="sidebar-pulse-btn unified-status-pill"
              class:has-active={appState.activeLiveTasks.length > 0}
              class:is-reconnecting={appState.sseStatus === 'reconnecting'}
              onclick={() => (appState.studioDrawerOpen = !appState.studioDrawerOpen)}
              title={appState.activeLiveTasks.length > 0
                ? `${appState.activeLiveTasks.length} active studio session(s) · Live synced with shared drive`
                : appState.sseStatus === 'connected' ? 'Studio idle · Live synced with shared drive' : 'Reconnecting to shared drive...'}
              aria-expanded={appState.studioDrawerOpen}
            >
              <span class="studio-pulse-dot" class:pulsing={appState.activeLiveTasks.length > 0} class:dot-reconnect={appState.sseStatus === 'reconnecting'}></span>
              <span class="sidebar-pulse-label">
                {#if appState.sseStatus === 'reconnecting'}
                  Reconnecting...
                {:else if appState.activeLiveTasks.length > 0}
                  <strong>{appState.activeLiveTasks.length}</strong> in Studio · Synced
                {:else}
                  Studio idle · Synced
                {/if}
              </span>
              <svg class="studio-pulse-chevron" width="10" height="10" viewBox="0 0 24 24" fill="currentColor" class:open={appState.studioDrawerOpen}>
                <path d="M7 10l5 5 5-5z"/>
              </svg>
            </button>
          {:else}
            <button
              type="button"
              class="nav-link rail-link rail-pulse-btn"
              class:has-active={appState.activeLiveTasks.length > 0}
              class:is-reconnecting={appState.sseStatus === 'reconnecting'}
              onclick={() => (appState.studioDrawerOpen = !appState.studioDrawerOpen)}
              title={appState.activeLiveTasks.length > 0
                ? `${appState.activeLiveTasks.length} active studio session(s) · Live synced with shared drive`
                : appState.sseStatus === 'connected' ? 'Studio idle · Live synced with shared drive' : 'Reconnecting to shared drive...'}
              aria-expanded={appState.studioDrawerOpen}
            >
              <span class="studio-pulse-dot" class:pulsing={appState.activeLiveTasks.length > 0} class:dot-reconnect={appState.sseStatus === 'reconnecting'}></span>
            </button>
          {/if}

          {#if appState.studioDrawerOpen}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <div class="studio-flyout" role="presentation" tabindex="-1" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
              <div class="studio-flyout-header">
                <div class="studio-flyout-title">
                  <span class="pulse-indicator"></span>
                  Live Studio Pulse
                </div>
                <span class="studio-badge-count">{appState.activeLiveTasks.length} Active</span>
              </div>
              <div class="studio-flyout-body">
                {#if appState.activeLiveTasks.length === 0}
                  <div class="studio-empty-state">
                    <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                      <circle cx="12" cy="12" r="10" />
                      <polyline points="12 6 12 12 16 14" />
                    </svg>
                    <p>No active sessions right now</p>
                    <span>Designers will appear here when desktop SS-CAM timers start.</span>
                  </div>
                {:else}
                  <div class="studio-task-list">
                    {#each appState.activeLiveTasks as task}
                      <div class="studio-task-row">
                        <div class="designer-avatar-sm" style="background: {task.AvatarColor || '#21A1F7'}">
                          {(task.DesignerName || task.StaffId || 'D').slice(0, 2).toUpperCase()}
                        </div>
                        <div class="studio-task-info">
                          <div class="studio-task-top">
                            <span class="designer-name">{task.DesignerName || task.StaffId}</span>
                            <span class="studio-client-tag">{task.Client || 'Internal'}</span>
                          </div>
                          <div class="studio-task-project" title={task.ProjectName || task.ProjectId}>
                            {task.ProjectName || task.ProjectId}
                          </div>
                          {#if task.SessionNotes}
                            <div class="studio-task-notes">"{task.SessionNotes}"</div>
                          {/if}
                        </div>
                        {#if task.ProjectId}
                          <button
                            class="studio-task-jump-btn"
                            onclick={() => {
                              appState.studioDrawerOpen = false;
                              appState.navigate('project-detail', { id: task.ProjectId });
                            }}
                            title="Open workspace"
                          >
                            ↗
                          </button>
                        {/if}
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>
              <div class="studio-flyout-footer">
                <button
                  class="studio-flyout-footer-btn"
                  onclick={() => {
                    appState.studioDrawerOpen = false;
                    appState.navigate('dashboard');
                  }}
                >
                  View Studio Stream in Dashboard →
                </button>
              </div>
            </div>
          {/if}
        </div>

        {#if !isRail}
          <div class="sidebar-desktop-link-wrap">
            <a
              href="https://suamisihat.github.io/ss_cam/"
              class="sidebar-desktop-link"
              target="_blank"
              rel="noreferrer"
              title="Download SS-CAM Desktop (Windows, Linux, Android)"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
              </svg>
              <span>Native Apps (v{serverVersion}) ↗</span>
            </a>
          </div>
        {:else}
          <a
            href="https://suamisihat.github.io/ss_cam/"
            class="nav-link rail-link"
            target="_blank"
            rel="noreferrer"
            title="Download SS-CAM Desktop Apps"
          >
            <svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
            </svg>
          </a>
        {/if}
      </nav>
    </aside>

    <!-- ═══ MAIN ════════════════════════════════════════════════════ -->
    <div class="app-main">

      <!-- TOP HEADER -->
      <header class="app-header">
        <div class="header-left">
          <button class="icon-btn" onclick={() => appState.toggleSidebar()} title="Toggle Sidebar" aria-label="Toggle sidebar">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
            </svg>
          </button>
          <nav class="breadcrumb" aria-label="Breadcrumb">
            {#each breadcrumbs as crumb, i}
              {#if i > 0}<span class="bc-sep" aria-hidden="true">›</span>{/if}
              {#if crumb.route && i < breadcrumbs.length - 1}
                <a href="#{crumb.route}" class="bc-link">{crumb.label}</a>
              {:else}
                <span class="bc-current" aria-current="page">{crumb.label}</span>
              {/if}
            {/each}
          </nav>
        </div>

        <div class="header-center">
          <button class="header-search-btn" onclick={() => (commandPaletteOpen = true)} aria-label="Open Command Palette (Ctrl K)">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" class="search-ico" aria-hidden="true">
              <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
            </svg>
            <span class="search-placeholder">Search projects, colors, team, actions…</span>
            <kbd class="search-shortcut">Ctrl K</kbd>
          </button>
        </div>

        <div class="header-right">
          {#if !appState.isOnline}
            <div class="header-stream-pill is-offline" role="status" aria-live="polite" title="Network offline">
              <span class="pill-dot offline"></span>
              <span>Offline</span>
            </div>
          {:else if appState.sseStatus === 'reconnecting'}
            <div class="header-stream-pill is-reconnecting" role="status" aria-live="polite" title="Reconnecting to real-time events...">
              <span class="pill-dot reconnecting"></span>
              <span>Reconnecting…</span>
            </div>
          {/if}

          <button
            class="icon-btn notif-btn"
            onclick={() => (appState.notificationDrawerOpen = !appState.notificationDrawerOpen)}
            title="Notifications & Activity"
            aria-label="Notifications & Activity"
          >
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/>
            </svg>
            {#if appState.notificationCount > 0}
              <span class="notif-count">{appState.notificationCount > 9 ? '9+' : appState.notificationCount}</span>
            {/if}
          </button>

          <!-- User Dropdown -->
          <div class="user-menu-wrapper">
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div
              class="user-chip"
              onclick={(e) => { e.stopPropagation(); appState.userMenuOpen = !appState.userMenuOpen; }}
              onkeydown={(e) => e.key === 'Enter' && (appState.userMenuOpen = !appState.userMenuOpen)}
              role="button"
              tabindex="0"
              aria-haspopup="menu"
              aria-expanded={appState.userMenuOpen}
            >
              <div class="user-avatar" style="background: {appState.currentUser?.avatarColor || 'var(--brand-gradient)'};">
                {#if appState.currentUser?.avatar}
                  <img src={appState.currentUser.avatar} alt={appState.currentUser.name} class="avatar-photo" />
                {:else}
                  <span>{userInitial}</span>
                {/if}
              </div>
              <div class="user-info">
                <span class="user-name">{appState.currentUser?.name ?? 'User'}</span>
                <span class="user-role-label">{appState.currentUser?.officialTitle || appState.currentUser?.role}</span>
              </div>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" class="chevron" class:open={appState.userMenuOpen} aria-hidden="true">
                <path d="M7 10l5 5 5-5z"/>
              </svg>
            </div>

            {#if appState.userMenuOpen}
              <!-- svelte-ignore a11y_no_static_element_interactions -->
              <!-- svelte-ignore a11y_click_events_have_key_events -->
              <div class="user-dropdown" role="menu" tabindex="-1" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
                <div class="dd-header">
                  <div class="dd-avatar" style="background: {appState.currentUser?.avatarColor || 'var(--brand-gradient)'};">
                    {#if appState.currentUser?.avatar}
                      <img src={appState.currentUser.avatar} alt={appState.currentUser.name} class="avatar-photo" />
                    {:else}
                      <span>{userInitial}</span>
                    {/if}
                  </div>
                  <div>
                    <div class="dd-name">{appState.currentUser?.name}</div>
                    <div class="dd-meta">{appState.currentUser?.staffId} · {appState.currentUser?.officialTitle || appState.currentUser?.role}</div>
                  </div>
                </div>
                <div class="dd-divider"></div>
                <button class="dd-item" onclick={() => { appState.userMenuOpen = false; appState.navigate('profile'); }} role="menuitem">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
                  My Profile & Themes
                </button>
                {#if isAdmin}
                  <button class="dd-item" onclick={() => { appState.userMenuOpen = false; appState.navigate('admin'); }} role="menuitem">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6-3.6z"/></svg>
                    Administration
                  </button>
                {/if}
                <button class="dd-item" onclick={() => { appState.userMenuOpen = false; appState.addToast('Rescanning workspace…', 'info'); projectStore.loadProjects(); projectStore.loadDashboard(); }} role="menuitem">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z"/></svg>
                  Rescan Workspace
                </button>
                <div class="dd-divider"></div>
                <button class="dd-item danger" onclick={() => { appState.userMenuOpen = false; appState.logout(); }} role="menuitem">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/></svg>
                  Sign Out
                </button>
              </div>
            {/if}
          </div>
        </div>
      </header>

      <!-- Global Connectivity / SSE Status Alert -->
      {#if !appState.isOnline}
        <div class="offline-global-banner" role="alert">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="1" y1="1" x2="23" y2="23"></line>
            <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"></path>
            <path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"></path>
            <path d="M10.71 5.05A16 16 0 0 1 22.58 9"></path>
            <path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"></path>
            <path d="M8.53 16.11a6 6 0 0 1 6.95 0"></path>
            <line x1="12" y1="20" x2="12.01" y2="20"></line>
          </svg>
          <span>You are currently working offline. Cached data is accessible; updates will sync when your network reconnects.</span>
        </div>
      {:else if appState.sseStatus === 'reconnecting'}
        <div class="stream-warning-banner" role="status" aria-live="polite">
          <span class="stream-pulse-dot"></span>
          <span>Live update stream interrupted. Reconnecting to shared drive in the background…</span>
        </div>
      {/if}

      <!-- PAGE CONTENT -->
      <div class="page-body">
        <section class="view-pane {currentConfig.layout}">
          {#if appState.currentRoute === 'dashboard'}
            <DashboardView />
          {:else if appState.currentRoute === 'tasks'}
            <TasksView />
          {:else if appState.currentRoute === 'projects'}
            <ProjectsView />
          {:else if appState.currentRoute === 'project-detail'}
            <ProjectDetailView projectId={appState.routeParams.id} />
          {:else if appState.currentRoute === 'deliverables'}
            <DeliverablesView />
          {:else if appState.currentRoute === 'order-form'}
            <OrderFormView />
          {:else if appState.currentRoute === 'copy-studio'}
            <CopyStudioView />
          {:else if appState.currentRoute === 'team'}
            <TeamView />
          {:else if appState.currentRoute === 'consultation'}
            <ConsultationSuiteView />
          {:else if appState.currentRoute === 'admin'}
            <AdminView />
          {:else if appState.currentRoute === 'studio-display'}
            <StudioDisplayView />
          {:else if appState.currentRoute === 'profile'}
            <ProfileView />
          {:else}
            <div class="not-found-pane">
              <div class="not-found-card">
                <div class="not-found-icon">
                  <svg width="48" height="48" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                  </svg>
                </div>
                <h2>Page not found</h2>
                <p>The page you are looking for does not exist or may have moved.</p>
                <button type="button" class="fluent-btn btn-primary btn-md" onclick={() => appState.navigate('dashboard')}>
                  Home
                </button>
              </div>
            </div>
          {/if}
        </section>
      </div>

      <!-- ═══ MOBILE BOTTOM NAVIGATION DOCK (<768px) ═════════════════ -->
      <nav class="mobile-bottom-dock" aria-label="Mobile Navigation">
        {#each mobileDockRoutes as item}
          {@const active = item.matchRoutes ? item.matchRoutes.includes(appState.currentRoute) : appState.currentRoute === item.id}
          {@const count = item.badge ? projectStore.pendingReviewCount : 0}
          <a
            href="#{item.hash}"
            class="dock-link"
            class:active
            aria-label={item.label}
          >
            {#if count > 0}
              <div class="dock-icon-wrap">
                <svg class="dock-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  {@html item.icon}
                </svg>
                <span class="dock-badge">{count}</span>
              </div>
            {:else}
              <svg class="dock-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                {@html item.icon}
              </svg>
            {/if}
            <span class="dock-text">{item.dockLabel || item.shortLabel}</span>
          </a>
        {/each}
        <button
          type="button"
          class="dock-link dock-btn"
          onclick={() => { appState.sidebarExpanded = !appState.sidebarExpanded; }}
          aria-label="Toggle Full Menu"
        >
          <svg class="dock-icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
          </svg>
          <span class="dock-text">More</span>
        </button>
      </nav>
    </div>
  </div>

  {#if appState.sidebarExpanded && !isRail}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="mobile-overlay" onclick={() => { appState.sidebarExpanded = false; }}></div>
  {/if}

  <CommandPaletteModal
    bind:open={commandPaletteOpen}
    onClose={() => (commandPaletteOpen = false)}
  />

  <NotificationDrawer
    bind:open={appState.notificationDrawerOpen}
    onclose={() => (appState.notificationDrawerOpen = false)}
  />

  <FluentDialog
    bind:open={showDownloadModal}
    title="Download SS-CAM Clients (v{serverVersion})"
    onClose={() => (showDownloadModal = false)}
  >
    <div class="download-modal-content">
      <div class="download-platform-card">
        <div class="platform-header">
          <div class="platform-icon win-icon"><FluentIcons name="windows" size={24} color="#00ADEF" /></div>
          <div class="platform-meta">
            <div class="platform-title">Windows Desktop Application</div>
            <div class="platform-desc">Single-file portable .exe with Fluent 2 Mica design (~5.6 MB)</div>
          </div>
        </div>
        <div class="platform-actions">
          <a
            href="https://suamisihat.github.io/ss_cam/"
            class="platform-download-btn win-btn"
            target="_blank"
            rel="noreferrer"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
            </svg>
            Download App (suamisihat.github.io) ↗
          </a>
        </div>
      </div>

      <div class="download-platform-card">
        <div class="platform-header">
          <div class="platform-icon android-icon"><FluentIcons name="phone" size={24} color="#3DDC84" /></div>
          <div class="platform-meta">
            <div class="platform-title">Android Mobile Studio Companion</div>
            <div class="platform-desc">Jetpack Compose native app with 2×2 Bento KPI & live ICY radio</div>
          </div>
        </div>
        <div class="platform-actions" style="display: flex; gap: 8px; flex-wrap: wrap;">
          <a
            href="https://play.google.com/store/apps/details?id=com.suamisihat.creative&hl=en-US&ah=4fxu9FCVL39aFVxQdNL2fGvtHd4&pli=1"
            class="platform-download-btn android-btn"
            target="_blank"
            rel="noreferrer"
            style="background: #01875f; flex: 1; min-width: 150px;"
          >
            Google Play Store ↗
          </a>
          <a
            href="https://github.com/SuamiSihat/ss_cam/releases/download/v{serverVersion}/SS-CAM-v{serverVersion}-android-release.apk"
            class="platform-download-btn"
            target="_blank"
            rel="noreferrer"
            style="flex: 1; min-width: 140px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15);"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
            </svg>
            Direct APK ↗
          </a>
        </div>
      </div>

      <div class="download-platform-card">
        <div class="platform-header">
          <div class="platform-icon linux-icon">🐧</div>
          <div class="platform-meta">
            <div class="platform-title">Linux Native Desktop Client (Fedora, Ubuntu, Arch)</div>
            <div class="platform-desc">Standalone Avalonia GUI app with Skia rendering & app launcher</div>
          </div>
        </div>
        <div class="linux-terminal-box">
          <code>curl -fsSL https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/install-linux.sh | sudo bash</code>
          <button
            type="button"
            class="copy-cmd-btn"
            onclick={() => {
              navigator.clipboard.writeText('curl -fsSL https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/install-linux.sh | sudo bash');
              appState.addToast('Linux installer command copied to clipboard.', 'success');
            }}
          >
            Copy Command
          </button>
        </div>
      </div>

      <div class="download-platform-card">
        <div class="platform-header">
          <div class="platform-icon web-icon">🌐</div>
          <div class="platform-meta">
            <div class="platform-title">Studio Web Portal</div>
            <div class="platform-desc">Live production portal hosted on NAS (Docker Compose)</div>
          </div>
        </div>
        <div class="platform-actions">
          <a href="https://github.com/SuamiSihat/ss_cam/tree/SS-Master/src/SS-CAM.Web" class="platform-link-btn" target="_blank" rel="noreferrer">
            View Docker Setup Guide ↗
          </a>
        </div>
      </div>
    </div>

    {#snippet footer()}
      <FluentButton appearance="secondary" onclick={() => (showDownloadModal = false)}>
        Close
      </FluentButton>
    {/snippet}
  </FluentDialog>
{/if}

<FluentToast />

<style>
  /* ═══ SHELL ════════════════════════════════════════════════════ */
  .app-shell {
    display: grid;
    grid-template-columns: 260px 1fr;
    height: 100vh;
    width: 100vw;
    overflow: hidden;
    transition: grid-template-columns 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .app-shell.sidebar-rail   { grid-template-columns: 68px 1fr; }
  .app-shell.sidebar-hidden { grid-template-columns: 0px 1fr; }

  /* ═══ SIDEBAR ══════════════════════════════════════════════════ */
  .app-sidebar {
    background: var(--bg-sidebar);
    color: var(--sidebar-text);
    border-right: 1px solid var(--sidebar-border);
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow-x: hidden;
    overflow-y: auto;
    width: 100%;
    box-sizing: border-box;
  }

  .sidebar-header {
    height: 56px;
    padding: 0 16px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    border-bottom: 1px solid var(--sidebar-border);
    box-sizing: border-box;
  }
  .sidebar-header.rail-header {
    padding: 0;
    justify-content: center;
  }
  .sidebar-logo {
    height: 26px;
    max-width: 148px;
    object-fit: contain;
    filter: drop-shadow(0 2px 6px rgba(0,0,0,.25));
  }
  .sidebar-logomark-wrap {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .sidebar-logomark-svg {
    width: 32px;
    height: 32px;
    object-fit: contain;
    filter: drop-shadow(0 2px 6px rgba(0,0,0,0.3));
    transition: transform 0.15s ease;
  }
  .sidebar-logomark-svg:hover {
    transform: scale(1.08);
  }
  .portal-pill {
    font-size: 9.5px;
    font-weight: 900;
    letter-spacing: 0.8px;
    padding: 2px 7px;
    border-radius: 4px;
    background: rgba(33,161,247,.18);
    color: #6DC6EC;
    border: 1px solid rgba(33,161,247,.35);
    white-space: nowrap;
  }

  .sidebar-nav {
    flex: 1;
    padding: 12px 10px;
    display: flex;
    flex-direction: column;
    gap: 3px;
    overflow-y: auto;
    overflow-x: hidden;
  }
  .sidebar-nav.rail-nav {
    padding: 12px 0;
    align-items: center;
  }
  .nav-section-label {
    font-size: 10px;
    font-weight: 800;
    color: var(--sidebar-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.6px;
    padding: 14px 10px 4px 10px;
    white-space: nowrap;
  }
  .nav-section-divider {
    height: 1px;
    width: 36px;
    background: var(--sidebar-border);
    margin: 8px auto;
  }
  .nav-link {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 9px 12px;
    border-radius: 8px;
    color: var(--sidebar-text);
    text-decoration: none;
    font-size: 13px;
    font-weight: 600;
    transition: background .14s, color .14s;
    position: relative;
    white-space: nowrap;
    box-sizing: border-box;
  }
  .nav-link:hover  {
    background: rgba(255,255,255,.09);
    color: #fff;
  }
  .nav-link.active {
    background: var(--sidebar-active-bg);
    color: var(--sidebar-active-text);
    font-weight: 700;
    border-left: 3px solid var(--sidebar-active-indicator);
    padding-left: 9px;
  }

  /* Compact Mode Rail Item: perfectly centered 44x44 icon button with 12px margins */
  .nav-link.rail-link {
    width: 44px;
    height: 44px;
    margin: 3px auto;
    padding: 0;
    justify-content: center;
    border-radius: 8px;
    border-left: none !important;
    gap: 0;
  }
  .nav-link.rail-link.active {
    background: var(--sidebar-active-bg);
    color: #fff;
    box-shadow: 0 0 0 1px var(--sidebar-active-indicator);
  }

  .nav-icon  {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }
  .nav-label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .nav-badge {
    margin-left: auto;
    background: #EF4444;
    color: #fff;
    font-size: 10px;
    font-weight: 800;
    padding: 1px 6px;
    border-radius: 9999px;
    flex-shrink: 0;
  }
  .nav-badge.rail-badge {
    position: absolute;
    top: 4px;
    right: 4px;
    padding: 0 4px;
    font-size: 9px;
    margin: 0;
  }
  .nav-spacer {
    flex: 1;
    min-height: 14px;
  }

  .sidebar-desktop-link-wrap {
    padding: 8px 10px;
    margin: 4px 6px 8px;
  }
  .sidebar-desktop-link {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-decoration: none;
    padding: 6px 8px;
    border-radius: 6px;
    transition: all 0.15s ease;
    border: 1px solid transparent;
  }
  .sidebar-desktop-link:hover {
    color: var(--text-primary);
    background: var(--fill-subtle);
    border-color: var(--stroke-subtle);
  }

  .unified-status-pill .dot-reconnect {
    background: #D97706 !important;
    box-shadow: 0 0 6px rgba(217, 119, 6, 0.4) !important;
  }

  /* ═══ MAIN ══════════════════════════════════════════════════════ */
  .app-main {
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
    min-width: 0;
    background: var(--bg-app);
  }

  /* ═══ HEADER ════════════════════════════════════════════════════ */
  .app-header {
    height: 56px;
    flex-shrink: 0;
    background: var(--surface-card);
    border-bottom: 1px solid var(--surface-card-border);
    padding: 0 24px;
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: 16px;
    position: sticky;
    top: 0;
    z-index: 200;
    box-shadow: var(--shadow-sm);
  }
  .header-left  { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .header-center { min-width: 0; display: flex; justify-content: center; }
  .header-right { display: flex; align-items: center; gap: 8px; }

  .breadcrumb {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    min-width: 0;
    overflow: hidden;
  }
  .bc-sep     { color: var(--text-tertiary); font-size: 12px; }
  .bc-link    { color: var(--text-secondary); text-decoration: none; font-weight: 600; white-space: nowrap; transition: color .14s; }
  .bc-link:hover { color: var(--brand-accent); }
  .bc-current {
    color: var(--text-primary);
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 280px;
  }

  .header-search-btn {
    display: flex;
    align-items: center;
    gap: 9px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    padding: 0 14px;
    width: 100%;
    max-width: 460px;
    height: 36px;
    cursor: pointer;
    text-align: left;
    transition: all .18s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: var(--shadow-sm);
  }
  .header-search-btn:hover {
    border-color: var(--brand-accent);
    box-shadow: 0 0 0 3px rgba(33, 161, 247, 0.15), var(--shadow-sm);
    background: var(--surface-card);
  }
  .header-search-btn:focus-visible {
    outline: none;
    border-color: var(--brand-accent);
    box-shadow: 0 0 0 3px rgba(33, 161, 247, 0.25);
  }
  .search-ico { color: var(--brand-accent); flex-shrink: 0; opacity: 0.85; transition: opacity .15s; }
  .header-search-btn:hover .search-ico { opacity: 1; }
  .search-placeholder {
    flex: 1;
    color: var(--text-secondary);
    font-size: 12.5px;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .search-shortcut {
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 0.3px;
    padding: 2px 7px;
    border-radius: 4px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    color: var(--text-tertiary);
    font-family: var(--font-mono, monospace);
    box-shadow: 0 1px 2px rgba(0,0,0,0.04);
  }

  .icon-btn {
    width: 36px;
    height: 36px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    border-radius: 8px;
    cursor: pointer;
    transition: background .14s, color .14s;
  }
  .icon-btn:hover { background: var(--surface-card-hover); color: var(--text-primary); }

  .notif-btn { position: relative; }
  .notif-count {
    position: absolute;
    top: 3px;
    right: 3px;
    background: #EF4444;
    color: #fff;
    font-size: 9px;
    font-weight: 800;
    padding: 0 4px;
    border-radius: 9999px;
    min-width: 14px;
    height: 14px;
    line-height: 14px;
    text-align: center;
    border: 1.5px solid var(--surface-card);
  }

  /* Studio Pulse Pill & Flyout in Sidebar */
  .sidebar-pulse-container {
    padding: 2px 10px;
    margin: 2px 0;
    position: relative;
    box-sizing: border-box;
  }
  .sidebar-pulse-container.rail-pulse-container {
    padding: 0;
    margin: 2px auto;
  }
  .sidebar-pulse-btn {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 7px 10px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 8px;
    color: var(--sidebar-text, #E2E8F0);
    font-size: 11.5px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
    box-sizing: border-box;
    text-align: left;
    font-family: inherit;
  }
  .sidebar-pulse-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.2);
    color: #FFFFFF;
  }
  .sidebar-pulse-btn.has-active {
    background: rgba(16, 185, 129, 0.14);
    border-color: rgba(16, 185, 129, 0.35);
    color: #34D399;
  }
  .sidebar-pulse-btn.has-active:hover {
    background: rgba(16, 185, 129, 0.2);
    border-color: #10B981;
  }
  .sidebar-pulse-label {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .rail-pulse-btn {
    width: 44px;
    height: 44px;
    margin: 3px auto;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    border: none;
    background: transparent;
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .rail-pulse-btn:hover {
    background: rgba(255, 255, 255, 0.09);
  }
  .rail-pulse-btn.has-active {
    background: rgba(16, 185, 129, 0.14);
  }

  .studio-pulse-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--text-tertiary, #94A3B8);
    flex-shrink: 0;
  }
  .studio-pulse-dot.pulsing {
    background: #10B981;
    box-shadow: 0 0 8px rgba(16, 185, 129, 0.7);
    animation: livePulse 1.8s infinite;
  }
  .studio-pulse-chevron {
    transition: transform 0.2s ease;
    opacity: 0.6;
    flex-shrink: 0;
  }
  .studio-pulse-chevron.open {
    transform: rotate(180deg);
  }

  /* Flyout Drawer positioned to the right of the sidebar */
  .studio-flyout {
    position: fixed;
    bottom: 24px;
    left: 270px;
    width: 340px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: 12px;
    box-shadow: var(--shadow-xl, 0 16px 36px rgba(0, 0, 0, 0.25));
    z-index: 1200;
    overflow: hidden;
    animation: flyoutFadeIn 0.18s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .app-shell.sidebar-rail .studio-flyout {
    left: 78px;
  }
  @media (max-width: 768px) {
    .studio-flyout {
      left: 12px !important;
      right: 12px !important;
      width: auto !important;
      bottom: 70px !important;
    }
  }

  @keyframes flyoutFadeIn {
    from { opacity: 0; transform: translateY(-4px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .studio-flyout-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 14px;
    background: var(--surface-card-subtle);
    border-bottom: 1px solid var(--surface-card-border);
  }
  .studio-flyout-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .pulse-indicator {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #10B981;
    box-shadow: 0 0 6px #10B981;
  }
  .studio-badge-count {
    font-size: 11px;
    font-weight: 700;
    padding: 2px 7px;
    border-radius: 9999px;
    background: rgba(16, 185, 129, 0.12);
    color: #059669;
    border: 1px solid rgba(16, 185, 129, 0.25);
  }
  .studio-flyout-body {
    max-height: 280px;
    overflow-y: auto;
    padding: 8px;
  }
  .studio-empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 24px 16px;
    text-align: center;
    color: var(--text-tertiary);
  }
  .studio-empty-state svg {
    margin-bottom: 10px;
  }
  .studio-task-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .studio-task-row {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 8px 10px;
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: 8px;
    transition: background 0.12s ease;
  }
  .studio-task-row:hover {
    background: var(--surface-card-hover, rgba(0,0,0,0.04));
  }
  .designer-avatar-sm {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: 800;
    color: #FFFFFF;
    flex-shrink: 0;
  }
  .studio-task-info {
    flex: 1;
    min-width: 0;
  }
  .studio-task-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }
  .designer-name {
    font-size: 12px;
    font-weight: 700;
    color: var(--text-primary);
  }
  .studio-client-tag {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    background: var(--bg-app);
    border-radius: 4px;
    color: var(--text-tertiary);
  }
  .studio-task-project {
    font-size: 11px;
    color: var(--text-secondary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    margin-top: 2px;
  }
  .studio-task-notes {
    font-size: 10.5px;
    font-style: italic;
    color: var(--text-tertiary);
    margin-top: 2px;
  }
  .studio-task-jump-btn {
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    font-size: 13px;
    padding: 2px 4px;
    border-radius: 4px;
  }
  .studio-task-jump-btn:hover {
    color: var(--brand-primary);
    background: var(--brand-tint, rgba(0,120,212,0.1));
  }
  .studio-flyout-footer {
    padding: 8px 12px;
    background: var(--surface-card-subtle);
    border-top: 1px solid var(--surface-card-border);
  }
  .studio-flyout-footer-btn {
    width: 100%;
    padding: 6px 10px;
    border: 1px solid var(--surface-card-border);
    border-radius: 6px;
    background: var(--surface-card);
    color: var(--text-secondary);
    font-size: 11.5px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.12s ease;
    text-align: center;
  }
  .studio-flyout-footer-btn:hover {
    background: var(--brand-tint, rgba(0,120,212,0.08));
    color: var(--brand-primary);
    border-color: var(--brand-accent, #38BDF8);
  }

  .vault-link {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    text-decoration: none;
    font-size: 12px;
    font-weight: 700;
    color: var(--brand-accent);
    background: var(--brand-tint);
    border: 1px solid rgba(4,51,136,.12);
    padding: 5px 12px;
    border-radius: 8px;
    white-space: nowrap;
    transition: background .14s;
  }
  .vault-link:hover { background: #dbeeff; }

  /* User Menu */
  .user-menu-wrapper { position: relative; }
  .user-chip {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 10px 4px 4px;
    border-radius: 8px;
    cursor: pointer;
    transition: background .14s;
    border: 1px solid transparent;
  }
  .user-chip:hover { background: var(--surface-card-hover); border-color: var(--surface-card-border); }
  .user-avatar {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: var(--brand-gradient);
    color: #fff;
    font-size: 13px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    overflow: hidden;
    position: relative;
    border: 1px solid rgba(255, 255, 255, 0.15);
  }
  .avatar-photo {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .user-info  { display: flex; flex-direction: column; }
  .user-name  { font-size: 12.5px; font-weight: 700; color: var(--text-primary); white-space: nowrap; }
  .user-role-label { font-size: 10.5px; color: var(--text-tertiary); white-space: nowrap; }
  .chevron { color: var(--text-tertiary); transition: transform .2s; flex-shrink: 0; }
  .chevron.open { transform: rotate(180deg); }

  .user-dropdown {
    position: absolute;
    top: calc(100% + 6px);
    right: 0;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: 10px;
    box-shadow: var(--shadow-xl);
    min-width: 220px;
    z-index: 500;
    overflow: hidden;
    animation: dropIn .15s ease;
  }
  @keyframes dropIn {
    from { opacity: 0; transform: translateY(-6px); }
    to   { opacity: 1; transform: translateY(0); }
  }
  .dd-header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 14px;
    background: var(--bg-app);
  }
  .dd-avatar {
    width: 38px;
    height: 38px;
    border-radius: 50%;
    background: var(--brand-gradient);
    color: #fff;
    font-size: 16px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    overflow: hidden;
    position: relative;
    border: 1px solid rgba(255, 255, 255, 0.15);
  }
  .dd-name { font-size: 13px; font-weight: 700; color: var(--text-primary); }
  .dd-meta { font-size: 11px; color: var(--text-secondary); }
  .dd-divider { height: 1px; background: var(--surface-card-border); }
  .dd-item {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 10px 14px;
    border: none;
    background: none;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    cursor: pointer;
    text-align: left;
    transition: background .12s;
    font-family: inherit;
  }
  .dd-item:hover { background: var(--surface-card-hover); }
  .dd-item.danger { color: var(--color-danger); }
  .dd-item.danger:hover { background: var(--color-danger-bg); }

  /* ═══ PAGE BODY ═════════════════════════════════════════════════ */
  .page-body {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    min-height: 0;
  }

  /* Layout Contracts with Generous Breathing Room */
  .view-pane {
    min-height: calc(100vh - 56px);
    box-sizing: border-box;
  }
  .view-pane.layout-fluid {
    padding: 20px 24px;
    max-width: 100%;
    width: 100%;
    margin: 0;
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: calc(100vh - 56px);
    box-sizing: border-box;
  }
  .view-pane.layout-page {
    padding: 28px 32px;
    max-width: 1480px;
    width: 100%;
    margin: 0 auto;
  }
  .view-pane.layout-full {
    padding: 24px 32px;
    max-width: 100%;
    width: 100%;
    margin: 0;
    box-sizing: border-box;
  }
  .view-pane.layout-narrow {
    padding: 36px 48px;
    max-width: 960px;
    margin: 0 auto;
  }

  /* Mobile bottom dock - strictly hidden on desktop */
  .mobile-bottom-dock {
    display: none;
  }
  .dock-icon {
    width: 20px;
    height: 20px;
  }

  /* Mobile overlay */
  .mobile-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,.4);
    z-index: 150;
    backdrop-filter: blur(2px);
  }

  /* ═══ RESPONSIVE ════════════════════════════════════════════════ */
  @media (max-width: 900px) {
    .app-shell { grid-template-columns: 1fr !important; }
    .app-sidebar {
      position: fixed;
      left: 0;
      top: 0;
      bottom: 0;
      width: 260px !important;
      z-index: 300;
      overflow-y: auto;
      transform: translateX(-100%);
      transition: transform .25s cubic-bezier(0.4,0,0.2,1);
      box-shadow: var(--shadow-xl);
    }
    .app-shell:not(.sidebar-hidden) .app-sidebar { transform: translateX(0); }
    .mobile-overlay  { display: block; }
    .vault-link      { display: none; }
    .mobile-bottom-dock {
      display: none;
    }
  }

  @media (max-width: 768px) {
    .mobile-bottom-dock {
      display: flex;
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 56px;
      background: var(--bg-sidebar);
      border-top: 1px solid var(--sidebar-border);
      align-items: center;
      justify-content: space-around;
      padding: 0 4px calc(env(safe-area-inset-bottom, 0px) + 2px) 4px;
      z-index: 900;
      backdrop-filter: blur(12px);
      box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.25);
    }
    .dock-link {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 2px;
      flex: 1;
      padding: 6px 2px;
      color: var(--sidebar-text-muted);
      text-decoration: none;
      border-radius: var(--radius-md);
      transition: color 0.15s, background 0.15s;
      background: transparent;
      border: none;
      cursor: pointer;
      min-height: 44px;
    }
    .dock-link.active {
      color: #FFFFFF;
      background: rgba(255, 255, 255, 0.12);
    }
    .dock-link.active .dock-icon {
      color: var(--brand-accent);
    }
    .dock-icon {
      width: 20px;
      height: 20px;
    }
    .dock-icon-wrap {
      position: relative;
      display: inline-flex;
    }
    .dock-badge {
      position: absolute;
      top: -4px;
      right: -8px;
      background: var(--color-danger);
      color: #FFFFFF;
      font-size: 9px;
      font-weight: 800;
      min-width: 15px;
      height: 15px;
      border-radius: 9999px;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0 3px;
    }
    .dock-text {
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.2px;
    }
    .page-body {
      padding-bottom: 64px;
    }
  }

  @media (max-width: 600px) {
    .header-center { display: none; }
    .breadcrumb    { display: none; }
    .user-info     { display: none; }
    .chevron       { display: none; }
    .app-header    { padding: 0 16px; }
  }

  /* ═══ DOWNLOAD MODAL ═════════════════════════════════════════════ */
  .download-modal-content {
    display: flex;
    flex-direction: column;
    gap: 14px;
    padding: 6px 0;
  }
  .download-platform-card {
    background: var(--surface-card-subtle);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg);
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .platform-header {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .platform-icon {
    font-size: 1.8rem;
    width: 44px;
    height: 44px;
    border-radius: var(--radius-md);
    background: var(--surface-card);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid var(--surface-card-border);
    flex-shrink: 0;
  }
  .platform-meta {
    flex: 1;
    min-width: 0;
  }
  .platform-title {
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--text-primary);
  }
  .platform-desc {
    font-size: 0.8rem;
    color: var(--text-secondary);
    margin-top: 2px;
  }
  .platform-actions {
    display: flex;
    gap: 10px;
  }
  .platform-download-btn {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    background: var(--brand-primary);
    color: #ffffff;
    font-weight: 600;
    font-size: 0.85rem;
    padding: 9px 16px;
    border-radius: var(--radius-md);
    text-decoration: none;
    transition: background 0.15s, transform 0.15s;
  }
  .platform-download-btn:hover {
    background: var(--brand-secondary);
    transform: translateY(-1px);
    color: #ffffff;
  }
  .platform-link-btn {
    display: inline-flex;
    align-items: center;
    background: var(--surface-card);
    color: var(--brand-accent);
    border: 1px solid var(--surface-card-border);
    font-weight: 600;
    font-size: 0.85rem;
    padding: 8px 14px;
    border-radius: var(--radius-md);
    text-decoration: none;
    transition: background 0.15s;
  }
  .platform-link-btn:hover {
    background: var(--surface-card-hover);
  }
  .linux-terminal-box {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: #0F172A;
    border: 1px solid #1E293B;
    border-radius: var(--radius-md);
    padding: 10px 14px;
    gap: 12px;
    overflow-x: auto;
  }
  .linux-terminal-box code {
    font-family: var(--font-mono);
    font-size: 0.78rem;
    color: #38BDF8;
    white-space: nowrap;
  }
  .copy-cmd-btn {
    background: #1E293B;
    color: #F8FAFC;
    border: 1px solid #334155;
    font-size: 0.75rem;
    font-weight: 600;
    padding: 5px 10px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.15s;
  }
  .copy-cmd-btn:hover {
    background: #334155;
  }

  .not-found-pane {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 55vh;
    padding: 32px 16px;
  }
  .not-found-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    max-width: 440px;
    padding: 36px 28px;
    background: var(--surface-card);
    border: 1px solid var(--surface-card-border);
    border-radius: var(--radius-lg, 12px);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  }
  .not-found-icon {
    color: var(--ss-azure, #21A1F7);
    margin-bottom: 16px;
  }
  .not-found-card h2 {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 8px 0;
    color: var(--text-primary);
  }
  .not-found-card p {
    font-size: 0.95rem;
    color: var(--text-secondary);
    margin: 0 0 24px 0;
    line-height: 1.5;
  }

  /* ─── Offline & Stream Status Banners ─── */
  .offline-global-banner {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 20px;
    background: rgba(239, 68, 68, 0.15);
    border-bottom: 1px solid rgba(239, 68, 68, 0.35);
    color: #FCA5A5;
    font-size: 13px;
    font-weight: 500;
    animation: fadeIn 0.25s ease;
  }

  .stream-warning-banner {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 20px;
    background: rgba(245, 158, 11, 0.12);
    border-bottom: 1px solid rgba(245, 158, 11, 0.3);
    color: #FCD34D;
    font-size: 12.5px;
    font-weight: 500;
    animation: fadeIn 0.25s ease;
  }

  .stream-pulse-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #F59E0B;
    box-shadow: 0 0 6px rgba(245, 158, 11, 0.7);
    animation: pulseDot 1.4s infinite;
  }

  .header-stream-pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 20px;
    font-size: 11.5px;
    font-weight: 600;
    letter-spacing: 0.2px;
  }

  .header-stream-pill.is-offline {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.35);
    color: #FCA5A5;
  }

  .header-stream-pill.is-reconnecting {
    background: rgba(245, 158, 11, 0.15);
    border: 1px solid rgba(245, 158, 11, 0.35);
    color: #FCD34D;
  }

  .pill-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }

  .pill-dot.offline {
    background: #EF4444;
  }

  .pill-dot.reconnecting {
    background: #F59E0B;
    animation: pulseDot 1.4s infinite;
  }

  @keyframes pulseDot {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.3; transform: scale(0.8); }
  }
</style>

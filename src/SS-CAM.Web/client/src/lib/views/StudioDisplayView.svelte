<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { ApiClient } from '$lib/services/api';
  import { appState } from '$lib/stores/appState.svelte';
  import FluentCard from '$lib/components/ui/FluentCard.svelte';
  import FluentButton from '$lib/components/ui/FluentButton.svelte';
  import FluentDialog from '$lib/components/ui/FluentDialog.svelte';
  import FluentBadge from '$lib/components/ui/FluentBadge.svelte';
  import FluentIcons from '$lib/components/ui/FluentIcons.svelte';

  type Tab = 'queue' | 'playlist' | 'branch' | 'display';

  interface Slide {
    id: string;
    enabled: boolean;
    tag?: string;
    title: string;
    subtitle?: string;
    type: string;
    src?: string;
    muted?: boolean;
    originalName?: string;
    sizeBytes?: number;
    durationSec?: number;
    startsAt?: string | null;
    endsAt?: string | null;
    fit?: 'cover' | 'contain';
    fullScreen?: boolean;
    alt?: string;
  }

  interface Config {
    version?: number;
    revision?: number;
    branchCode: string;
    slideDurationSec: number;
    soundAlertEnabled: boolean;
    rooms: string[];
    ticker: { enabled: boolean; prefix: string; text: string };
    queue: {
      currentCall: { ticket: string; room: string; doctor?: string | null; calledAt?: string } | null;
      upcoming: Array<{ ticket: string; room?: string }>;
    };
    slides: Slide[];
    branch?: any;
    updatedAt?: string;
  }

  interface Branch {
    code: string;
    name: string;
    shortName: string;
    address?: string;
    phone?: string;
    whatsapp?: string;
    operatingHours?: string;
    kkmLicense?: string;
    checkInUrl?: string;
    googleReviewUrl?: string;
    doctors: string[];
    archived?: boolean;
  }

  const TABS: Array<{ id: Tab; label: string }> = [
    { id: 'queue', label: 'Queue' },
    { id: 'playlist', label: 'Playlist' },
    { id: 'branch', label: 'Branch info' },
    { id: 'display', label: 'Display' }
  ];

  const PREFIXES = ['A', 'B', 'C', 'D', 'E', 'F'];
  const BUILT_IN_TYPES = ['doctors', 'eswt', 'trt', 'intake'];
  const TYPE_LABEL: Record<string, string> = {
    banner: 'Banner Image',
    video: 'Video',
    notice: 'Notice',
    doctors: 'Duty doctors',
    eswt: 'ESWT Treatment',
    trt: 'TRT Treatment',
    intake: 'Check-in'
  };

  let tab = $state<Tab>('queue');
  let config = $state<Config | null>(null);
  let activeBranchCode = $state<string>('');
  let branches = $state<Branch[]>([]);
  let archivedBranches = $state<Branch[]>([]);
  let isLoading = $state(true);
  let loadError = $state('');
  let busy = $state(false);
  let liveAt = $state('');
  let showLivePreview = $state(false);
  let conflictAlert = $state('');

  // ── Queue entry state ──
  let prefix = $state('A');
  let digits = $state('');
  let room = $state('');
  let doctor = $state('');

  // ── Playlist state ──
  let uploadPct = $state<number | null>(null);
  let uploadWarning = $state('');
  let uploadXhr = $state<XMLHttpRequest | null>(null);

  // Add Slide Modal
  let addModalOpen = $state(false);
  let addSlideType = $state<'banner' | 'video' | 'notice'>('banner');
  let addSlideTitle = $state('');
  let addSlideSubtitle = $state('');
  let addSlideTag = $state('');
  let addSlideDuration = $state<number | ''>('');
  let addSlideFit = $state<'cover' | 'contain'>('cover');
  let addSlideFullScreen = $state(false);
  let addSlideStartsAt = $state('');
  let addSlideEndsAt = $state('');
  let addFileToUpload = $state<File | null>(null);
  let addFilePreviewUrl = $state<string | null>(null);

  // Edit Slide Modal
  let editModalOpen = $state(false);
  let editingSlide = $state<Slide | null>(null);
  let editTitle = $state('');
  let editSubtitle = $state('');
  let editTag = $state('');
  let editDuration = $state<number | ''>('');
  let editFit = $state<'cover' | 'contain'>('cover');
  let editFullScreen = $state(false);
  let editMuted = $state(true);
  let editStartsAt = $state('');
  let editEndsAt = $state('');
  let editAlt = $state('');

  // Replace Media Modal
  let replaceModalOpen = $state(false);
  let replacingSlide = $state<Slide | null>(null);
  let replaceFile = $state<File | null>(null);
  let replacePreviewUrl = $state<string | null>(null);

  // Copy Playlist Modal
  let copyModalOpen = $state(false);
  let copyFromBranchCode = $state('');

  // Confirmation Dialog
  let confirmOpen = $state(false);
  let confirmTitle = $state('');
  let confirmText = $state('Confirm');
  let confirmDesc = $state('This action cannot be undone.');
  let confirmAppearance = $state<'primary' | 'danger'>('danger');
  let confirmAction: (() => Promise<void>) | null = null;

  // ── Branch Editor state ──
  let branchForm = $state<Branch | null>(null);
  let newDoctorName = $state('');
  let branchSaveError = $state('');
  let archivedExpanded = $state(false);

  // Add Branch Modal
  let addBranchModalOpen = $state(false);
  let newBranchName = $state('');
  let newBranchShortName = $state('');
  let newBranchCode = $state('');
  let newBranchAddress = $state('');
  let newBranchPhone = $state('');
  let newBranchWhatsapp = $state('');
  let newBranchHours = $state('Mon–Sat: 9:00 AM – 6:00 PM');
  let newBranchKkm = $state('');
  let newBranchCheckIn = $state('');
  let newBranchCopyPlaylistFrom = $state('');
  let addBranchError = $state('');

  // Delete Branch Dialog (Requires typing code)
  let deleteBranchModalOpen = $state(false);
  let branchToDelete = $state<Branch | null>(null);
  let deleteConfirmCode = $state('');
  let deleteBranchError = $state('');

  // ── Display Settings state ──
  let newRoomName = $state('');
  let tickerDraft = $state<{ prefix: string; text: string } | null>(null);

  const canManage = $derived(appState.can('canManageStudioDisplay'));
  const visibleTabs = $derived(canManage ? TABS : TABS.filter(t => t.id === 'queue'));

  $effect(() => {
    if (!canManage && tab !== 'queue') tab = 'queue';
  });

  const ticket = $derived(digits ? `${prefix}-${digits}` : '');
  const activeBranch = $derived(branches.find(b => b.code === activeBranchCode) || config?.branch || null);
  const doctors = $derived<string[]>(Array.isArray(activeBranch?.doctors) ? activeBranch.doctors : []);
  const rooms = $derived<string[]>(config?.rooms || []);
  const current = $derived(config?.queue.currentCall || null);
  const waiting = $derived(config?.queue.upcoming || []);
  const tvBranchCode = $derived(config?.branchCode || '');

  // ─── Lifecycle & Data Loading ───
  function applyConfig(next: Config | undefined | null) {
    if (!next) return;
    config = next;
    liveAt = new Date().toLocaleTimeString();
    if (!activeBranchCode) {
      activeBranchCode = next.branchCode;
    }
    if (!room || !next.rooms?.includes(room)) {
      room = next.rooms?.[0] || '';
    }
    if (config?.ticker && !tickerDraft) {
      tickerDraft = { prefix: config.ticker.prefix || 'PENGUMUMAN', text: config.ticker.text || '' };
    }
  }

  function syncBranchForm() {
    if (!activeBranchCode) return;
    const b = branches.find(x => x.code === activeBranchCode) || (config?.branch && config.branch.code === activeBranchCode ? config.branch : null);
    branchForm = b ? { ...b, doctors: [...(b.doctors || [])] } : null;
    branchSaveError = '';
  }

  async function loadBranches() {
    try {
      const [activeRes, allRes] = await Promise.all([
        ApiClient.getClinicBranches(false),
        ApiClient.getClinicBranches(true)
      ]);
      branches = activeRes.branches || [];
      const all = allRes.branches || [];
      archivedBranches = all.filter(b => b.archived);
      syncBranchForm();
    } catch (err: any) {
      console.warn('[StudioDisplayView] loadBranches error:', err);
    }
  }

  async function loadConfigForBranch(code?: string) {
    try {
      const res = await ApiClient.getSignageConfig(code);
      applyConfig(res.config);
      syncBranchForm();
      loadError = '';
      conflictAlert = '';
    } catch (err: any) {
      console.error('[StudioDisplayView] loadConfigForBranch error:', err);
      loadError = err?.message || 'Could not load Studio Display configuration.';
    }
  }

  async function loadAll() {
    isLoading = true;
    try {
      await loadBranches();
      await loadConfigForBranch(activeBranchCode || undefined);
    } finally {
      isLoading = false;
    }
  }

  function onLiveUpdated() {
    loadConfigForBranch(activeBranchCode);
    loadBranches();
  }

  onMount(() => {
    loadAll();
    window.addEventListener('signage:updated', onLiveUpdated);
  });

  onDestroy(() => {
    window.removeEventListener('signage:updated', onLiveUpdated);
    if (addFilePreviewUrl) URL.revokeObjectURL(addFilePreviewUrl);
    if (replacePreviewUrl) URL.revokeObjectURL(replacePreviewUrl);
  });

  async function run<T>(fn: () => Promise<T>, okMsg?: string): Promise<T | undefined> {
    if (busy) return;
    busy = true;
    try {
      const out = await fn();
      if (okMsg) appState.addToast(okMsg, 'success');
      return out;
    } catch (err: any) {
      if (err?.conflict || err?.status === 409) {
        conflictAlert = 'Someone else modified this branch while you were editing. The latest playlist has been loaded.';
        await loadConfigForBranch(activeBranchCode);
      } else {
        appState.addToast(err?.message || 'Action could not be completed.', 'error');
      }
      return undefined;
    } finally {
      busy = false;
    }
  }

  function confirmActionModal(title: string, text: string, desc: string, appearance: 'primary' | 'danger', action: () => Promise<void>) {
    confirmTitle = title;
    confirmText = text;
    confirmDesc = desc;
    confirmAppearance = appearance;
    confirmAction = action;
    confirmOpen = true;
  }

  async function executeConfirm() {
    const fn = confirmAction;
    confirmOpen = false;
    confirmAction = null;
    if (fn) await fn();
  }

  // ─── Branch Switching ───
  async function selectBranch(code: string) {
    if (activeBranchCode === code) return;
    activeBranchCode = code;
    syncBranchForm();
    await loadConfigForBranch(code);
  }

  async function setAsTvBranch(code: string) {
    await run(async () => {
      const res = await ApiClient.updateSignageConfig({ branchCode: code }, code);
      applyConfig(res.config);
      await loadBranches();
    }, `TV display switched to ${code}`);
  }

  // ─── Queue Methods ───
  function pressKeypad(d: string) {
    if (digits.length < 4) digits += d;
  }

  function backspaceKeypad() {
    digits = digits.slice(0, -1);
  }

  async function callTicket(t: string, r: string, fromWaiting = false) {
    await run(async () => {
      const res = await ApiClient.callSignageTicket({
        ticket: t,
        room: r || room,
        doctor: doctor || undefined,
        popUpcoming: true,
        branchCode: activeBranchCode
      });
      applyConfig(res.config);
    }, `Calling ticket ${t}`);
    if (!fromWaiting) digits = '';
  }

  async function callNow() {
    if (!ticket) {
      appState.addToast('Please enter a ticket number first.', 'warning');
      return;
    }
    await callTicket(ticket, room);
  }

  async function callNext() {
    await run(async () => {
      const res = await ApiClient.callSignageNext({
        room,
        doctor: doctor || undefined,
        branchCode: activeBranchCode
      });
      applyConfig(res.config);
    }, 'Calling next ticket');
  }

  async function recallCurrent() {
    if (!current) return;
    await run(async () => {
      const res = await ApiClient.callSignageTicket({
        ticket: current.ticket,
        room: current.room,
        doctor: current.doctor || undefined,
        popUpcoming: false,
        branchCode: activeBranchCode
      });
      applyConfig(res.config);
    }, `Re-calling ticket ${current.ticket}`);
  }

  async function addToWaiting() {
    if (!ticket || !config) {
      appState.addToast('Please enter a ticket number first.', 'warning');
      return;
    }
    if (waiting.some(w => w.ticket === ticket)) {
      appState.addToast(`${ticket} is already in the waiting list.`, 'warning');
      return;
    }
    const list = [...waiting, { ticket, room }];
    await run(async () => {
      const res = await ApiClient.updateSignageUpcoming(list, activeBranchCode);
      applyConfig(res.config);
      digits = '';
    }, `${ticket} added to waiting`);
  }

  async function moveWaitingItem(i: number, dir: -1 | 1) {
    const list = [...waiting];
    const j = i + dir;
    if (j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    await run(async () => {
      const res = await ApiClient.updateSignageUpcoming(list, activeBranchCode);
      applyConfig(res.config);
    });
  }

  async function removeWaitingItem(i: number) {
    const list = waiting.filter((_, k) => k !== i);
    await run(async () => {
      const res = await ApiClient.updateSignageUpcoming(list, activeBranchCode);
      applyConfig(res.config);
    });
  }

  function promptClearQueue() {
    confirmActionModal(
      'Clear live queue?',
      'Clear queue',
      'This will reset the current call and remove all waiting tickets for this branch.',
      'danger',
      async () => {
        await run(async () => {
          const res = await ApiClient.clearSignageQueue(true, activeBranchCode);
          applyConfig(res.config);
        }, 'Queue cleared');
      }
    );
  }

  // ─── Playlist Methods ───
  async function changeGlobalDuration(delta: number) {
    if (!config) return;
    const v = Math.min(120, Math.max(3, (config.slideDurationSec || 10) + delta));
    await run(async () => {
      const res = await ApiClient.updateSignageConfig({ slideDurationSec: v }, activeBranchCode);
      applyConfig(res.config);
    });
  }

  async function toggleSlideEnabled(slide: Slide) {
    if (!config) return;
    await run(async () => {
      const res = await ApiClient.updateSignageSlide(
        slide.id,
        { enabled: !slide.enabled },
        activeBranchCode,
        config.revision
      );
      applyConfig(res.config);
    }, `${slide.title || 'Slide'} ${!slide.enabled ? 'activated' : 'hidden'}`);
  }

  async function moveSlideOrder(i: number, dir: -1 | 1) {
    if (!config) return;
    const list = [...config.slides];
    const j = i + dir;
    if (j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    const slideIds = list.map(s => s.id);
    await run(async () => {
      const res = await ApiClient.reorderSignageSlides(slideIds, activeBranchCode, config!.revision);
      applyConfig(res.config);
    });
  }

  async function duplicateSlideAction(slide: Slide) {
    if (!config) return;
    await run(async () => {
      const res = await ApiClient.duplicateSignageSlide(slide.id, activeBranchCode, config!.revision);
      applyConfig(res.config);
    }, `Duplicated "${slide.title}"`);
  }

  function promptRemoveSlide(slide: Slide) {
    const isBuiltIn = BUILT_IN_TYPES.includes(slide.type);
    const desc = isBuiltIn
      ? `This will remove "${slide.title || TYPE_LABEL[slide.type]}". You can restore default slides at any time.`
      : `This will remove "${slide.title || TYPE_LABEL[slide.type]}". If no other branch uses its media file, the file will be cleaned up.`;

    confirmActionModal(
      `Remove slide "${slide.title || TYPE_LABEL[slide.type]}"?`,
      'Remove slide',
      desc,
      'danger',
      async () => {
        await run(async () => {
          const res = await ApiClient.deleteSignageSlide(slide.id, activeBranchCode, config?.revision);
          applyConfig(res.config);
        }, 'Slide removed from playlist');
      }
    );
  }

  // ─── Add Slide Modal & Uploading ───
  function openAddSlideModal(type: 'banner' | 'video' | 'notice' = 'banner') {
    addSlideType = type;
    addSlideTitle = '';
    addSlideSubtitle = '';
    addSlideTag = type === 'banner' ? 'PROMO' : type === 'video' ? 'FEATURE' : 'ANNOUNCEMENT';
    addSlideDuration = '';
    addSlideFit = 'cover';
    addSlideFullScreen = false;
    addSlideStartsAt = '';
    addSlideEndsAt = '';
    addFileToUpload = null;
    if (addFilePreviewUrl) URL.revokeObjectURL(addFilePreviewUrl);
    addFilePreviewUrl = null;
    uploadWarning = '';
    uploadPct = null;
    addModalOpen = true;
  }

  function onAddFileSelected(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    addFileToUpload = file;
    if (addFilePreviewUrl) URL.revokeObjectURL(addFilePreviewUrl);
    if (file.type.startsWith('image/')) {
      addFilePreviewUrl = URL.createObjectURL(file);
    } else {
      addFilePreviewUrl = null;
    }
    if (!addSlideTitle) {
      addSlideTitle = file.name.replace(/\.[^/.]+$/, '').replace(/[-_]/g, ' ');
    }
  }

  async function submitAddSlide() {
    if (!config) return;
    if (addSlideType === 'notice') {
      if (!addSlideTitle.trim()) {
        appState.addToast('Please enter a notice title.', 'warning');
        return;
      }
      await run(async () => {
        const payload = {
          type: 'notice',
          enabled: true,
          title: addSlideTitle.trim(),
          subtitle: addSlideSubtitle.trim(),
          tag: addSlideTag.trim() || 'ANNOUNCEMENT',
          durationSec: addSlideDuration ? Number(addSlideDuration) : undefined,
          startsAt: addSlideStartsAt || undefined,
          endsAt: addSlideEndsAt || undefined
        };
        const res = await ApiClient.addSignageSlide(payload, activeBranchCode, config!.revision);
        applyConfig(res.config);
        addModalOpen = false;
      }, 'Notice added to playlist');
      return;
    }

    if (!addFileToUpload) {
      appState.addToast(`Please select a ${addSlideType === 'banner' ? 'banner image' : 'video'} file.`, 'warning');
      return;
    }

    if (addSlideType === 'banner') {
      uploadPct = 0;
      await run(async () => {
        const res = await ApiClient.uploadSignageImage(
          addFileToUpload!,
          activeBranchCode,
          config!.revision,
          pct => (uploadPct = pct)
        );
        if (res.warning) {
          appState.addToast(res.warning, 'info');
        }
        // If extra metadata was specified, update the newly added slide
        if (addSlideTitle.trim() || addSlideSubtitle.trim() || addSlideTag.trim() || addSlideFit !== 'cover' || addSlideFullScreen || addSlideDuration) {
          const patch: any = {};
          if (addSlideTitle.trim()) patch.title = addSlideTitle.trim();
          if (addSlideSubtitle.trim()) patch.subtitle = addSlideSubtitle.trim();
          if (addSlideTag.trim()) patch.tag = addSlideTag.trim();
          if (addSlideFit !== 'cover') patch.fit = addSlideFit;
          if (addSlideFullScreen) patch.fullScreen = true;
          if (addSlideDuration) patch.durationSec = Number(addSlideDuration);
          if (addSlideStartsAt) patch.startsAt = addSlideStartsAt;
          if (addSlideEndsAt) patch.endsAt = addSlideEndsAt;

          const updated = await ApiClient.updateSignageSlide(res.slide.id, patch, activeBranchCode, res.revision);
          applyConfig(updated.config);
        } else {
          applyConfig(res.config);
        }
        addModalOpen = false;
      }, 'Banner image added to playlist');
      uploadPct = null;
      return;
    }

    if (addSlideType === 'video') {
      uploadPct = 0;
      await run(async () => {
        const res = await ApiClient.uploadSignageVideo(
          addFileToUpload!,
          activeBranchCode,
          pct => (uploadPct = pct)
        );
        applyConfig(res.config);
        addModalOpen = false;
      }, 'Video added to playlist');
      uploadPct = null;
    }
  }

  // ─── Edit Slide Modal ───
  function openEditSlideModal(slide: Slide) {
    editingSlide = slide;
    editTitle = slide.title || '';
    editSubtitle = slide.subtitle || '';
    editTag = slide.tag || '';
    editDuration = slide.durationSec || '';
    editFit = slide.fit || 'cover';
    editFullScreen = Boolean(slide.fullScreen);
    editMuted = slide.muted !== false;
    editStartsAt = slide.startsAt ? slide.startsAt.slice(0, 16) : '';
    editEndsAt = slide.endsAt ? slide.endsAt.slice(0, 16) : '';
    editAlt = slide.alt || '';
    editModalOpen = true;
  }

  async function submitEditSlide() {
    if (!config || !editingSlide) return;
    const patch: any = {
      title: editTitle.trim(),
      subtitle: editSubtitle.trim(),
      tag: editTag.trim(),
      durationSec: editDuration ? Number(editDuration) : null,
      startsAt: editStartsAt || null,
      endsAt: editEndsAt || null
    };

    if (editingSlide.type === 'banner') {
      patch.fit = editFit;
      patch.fullScreen = editFullScreen;
      patch.alt = editAlt.trim();
    } else if (editingSlide.type === 'video') {
      patch.muted = editMuted;
    }

    await run(async () => {
      const res = await ApiClient.updateSignageSlide(
        editingSlide!.id,
        patch,
        activeBranchCode,
        config!.revision
      );
      applyConfig(res.config);
      editModalOpen = false;
    }, 'Slide updated');
  }

  // ─── Replace Media Modal ───
  function openReplaceMediaModal(slide: Slide) {
    replacingSlide = slide;
    replaceFile = null;
    if (replacePreviewUrl) URL.revokeObjectURL(replacePreviewUrl);
    replacePreviewUrl = null;
    uploadPct = null;
    replaceModalOpen = true;
  }

  function onReplaceFileSelected(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    replaceFile = file;
    if (replacePreviewUrl) URL.revokeObjectURL(replacePreviewUrl);
    if (file.type.startsWith('image/')) {
      replacePreviewUrl = URL.createObjectURL(file);
    } else {
      replacePreviewUrl = null;
    }
  }

  async function submitReplaceMedia() {
    if (!config || !replacingSlide || !replaceFile) {
      appState.addToast('Please choose a replacement file.', 'warning');
      return;
    }

    uploadPct = 0;
    await run(async () => {
      const res = await ApiClient.replaceSignageSlideMedia(
        replacingSlide!.id,
        replaceFile!,
        activeBranchCode,
        config!.revision,
        pct => (uploadPct = pct)
      );
      if (res.warning) {
        appState.addToast(res.warning, 'info');
      }
      applyConfig(res.config);
      replaceModalOpen = false;
    }, 'Media file replaced');
    uploadPct = null;
  }

  // ─── Copy Playlist & Restore Defaults ───
  function openCopyPlaylistModal() {
    const otherBranches = branches.filter(b => b.code !== activeBranchCode);
    if (otherBranches.length === 0) {
      appState.addToast('There are no other active branches to copy from.', 'info');
      return;
    }
    copyFromBranchCode = otherBranches[0].code;
    copyModalOpen = true;
  }

  async function submitCopyPlaylist() {
    if (!config || !copyFromBranchCode) return;
    confirmActionModal(
      `Copy playlist from ${copyFromBranchCode}?`,
      'Copy playlist',
      `This will replace all slides in ${activeBranchCode} with slides from ${copyFromBranchCode}. Any custom items here will be replaced.`,
      'danger',
      async () => {
        await run(async () => {
          const res = await ApiClient.copySignagePlaylist(copyFromBranchCode, activeBranchCode, config?.revision);
          applyConfig(res.config);
          copyModalOpen = false;
        }, `Playlist copied from ${copyFromBranchCode}`);
      }
    );
  }

  function promptRestoreDefaults() {
    confirmActionModal(
      'Restore default slides?',
      'Restore defaults',
      'This will reset this branch\'s playlist to the standard 5 clinical slides (Doctors, Treatments, Check-in).',
      'danger',
      async () => {
        await run(async () => {
          const res = await ApiClient.restoreSignageDefaultSlides(activeBranchCode, config?.revision);
          applyConfig(res.config);
        }, 'Default slides restored');
      }
    );
  }

  // ─── Branch Management Methods ───
  function addDoctorChip() {
    const v = newDoctorName.trim();
    if (!v || !branchForm) return;
    if (!branchForm.doctors.includes(v)) {
      branchForm.doctors = [...branchForm.doctors, v];
    }
    newDoctorName = '';
  }

  function removeDoctorChip(i: number) {
    if (!branchForm) return;
    branchForm.doctors = branchForm.doctors.filter((_, k) => k !== i);
  }

  async function saveActiveBranch() {
    if (!branchForm) return;
    branchSaveError = '';
    const patch = {
      name: branchForm.name,
      shortName: branchForm.shortName,
      address: branchForm.address,
      phone: branchForm.phone,
      whatsapp: branchForm.whatsapp,
      operatingHours: branchForm.operatingHours,
      kkmLicense: branchForm.kkmLicense,
      checkInUrl: branchForm.checkInUrl,
      googleReviewUrl: branchForm.googleReviewUrl,
      doctors: branchForm.doctors
    };

    await run(async () => {
      const res = await ApiClient.updateClinicBranch(activeBranchCode, patch);
      branches = branches.map(b => (b.code === activeBranchCode ? res.branch : b));
      syncBranchForm();
      await loadConfigForBranch(activeBranchCode);
    }, 'Branch details saved and TV screens updated');
  }

  function promptArchiveBranch(target?: Branch | null) {
    const b = target || activeBranch;
    if (!b) return;
    const isTvBranch = tvBranchCode === b.code;
    const isLastBranch = branches.length <= 1;

    if (isLastBranch) {
      appState.addToast('Cannot remove the last active branch. The clinic must have at least one branch.', 'error');
      return;
    }
    if (isTvBranch) {
      appState.addToast(`Branch "${b.name}" is currently broadcasting on the TV screen. Please switch the TV display to another branch in "Branch Info" before removing it.`, 'error');
      return;
    }

    confirmActionModal(
      `Remove branch "${b.name}"?`,
      'Remove branch',
      `Archiving removes "${b.name}" from TV displays, queue management, and selectors. All historical queue records, doctor rosters, and licences remain safely stored and can be restored at any time from "Branch Info" > "Removed branches".`,
      'danger',
      async () => {
        await run(async () => {
          await ApiClient.archiveClinicBranch(b.code);
          await loadBranches();
          const fallback = branches.find(x => x.code !== b.code);
          if (fallback) {
            await selectBranch(fallback.code);
          }
        }, `Branch "${b.name}" removed`);
      }
    );
  }

  async function restoreArchivedBranch(code: string) {
    await run(async () => {
      await ApiClient.restoreClinicBranch(code);
      await loadBranches();
    }, `Branch ${code} restored`);
  }

  function promptPermanentDelete(branch: Branch) {
    branchToDelete = branch;
    deleteConfirmCode = '';
    deleteBranchError = '';
    deleteBranchModalOpen = true;
  }

  async function executePermanentDelete() {
    if (!branchToDelete) return;
    if (deleteConfirmCode.trim().toUpperCase() !== branchToDelete.code.toUpperCase()) {
      deleteBranchError = `Please type "${branchToDelete.code}" exactly to confirm permanent deletion.`;
      return;
    }

    await run(async () => {
      await ApiClient.deleteClinicBranch(branchToDelete!.code);
      deleteBranchModalOpen = false;
      branchToDelete = null;
      await loadBranches();
    }, `Branch ${branchToDelete.code} deleted permanently`);
  }

  // ─── Add Branch Modal ───
  function openAddBranchModal() {
    newBranchName = '';
    newBranchShortName = '';
    newBranchCode = '';
    newBranchAddress = '';
    newBranchPhone = '';
    newBranchWhatsapp = '';
    newBranchHours = 'Mon–Sat: 9:00 AM – 6:00 PM';
    newBranchKkm = '';
    newBranchCheckIn = '';
    newBranchCopyPlaylistFrom = activeBranchCode || (branches[0]?.code || '');
    addBranchError = '';
    addBranchModalOpen = true;
  }

  function onShortNameInput() {
    if (!newBranchCode || newBranchCode.startsWith('SSC-')) {
      const slug = newBranchShortName.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (slug) {
        newBranchCode = `SSC-${slug.slice(0, 4)}`;
      }
    }
  }

  async function submitAddBranch() {
    addBranchError = '';
    const code = newBranchCode.trim().toUpperCase();
    const name = newBranchName.trim();
    const shortName = newBranchShortName.trim() || name;

    if (!code || !name) {
      addBranchError = 'Branch name and code are required.';
      return;
    }
    if (!/^[A-Z0-9-]{2,12}$/.test(code)) {
      addBranchError = 'Branch code must be 2 to 12 uppercase letters, numbers or hyphens (e.g. SSC-MK).';
      return;
    }

    await run(async () => {
      const payload = {
        code,
        name,
        shortName,
        address: newBranchAddress.trim(),
        phone: newBranchPhone.trim(),
        whatsapp: newBranchWhatsapp.trim(),
        operatingHours: newBranchHours.trim(),
        kkmLicense: newBranchKkm.trim(),
        checkInUrl: newBranchCheckIn.trim(),
        copyPlaylistFrom: newBranchCopyPlaylistFrom || undefined
      };
      const res = await ApiClient.addClinicBranch(payload);
      addBranchModalOpen = false;
      await loadBranches();
      await selectBranch(res.branch.code);
    }, `Branch ${code} created`);
  }

  // ─── Display & Ticker Methods ───
  async function saveDisplaySettings(patch: any, successMessage?: string) {
    await run(async () => {
      const res = await ApiClient.updateSignageConfig(patch, activeBranchCode);
      applyConfig(res.config);
    }, successMessage);
  }

  async function addRoomAction() {
    const v = newRoomName.trim();
    if (!v || !config) return;
    if (config.rooms.includes(v)) {
      appState.addToast('That room or counter already exists.', 'warning');
      return;
    }
    newRoomName = '';
    await saveDisplaySettings({ rooms: [...config.rooms, v] }, `Added room "${v}"`);
  }

  async function removeRoomAction(r: string) {
    if (!config || config.rooms.length <= 1) {
      appState.addToast('Please keep at least one room or counter.', 'warning');
      return;
    }
    await saveDisplaySettings({ rooms: config.rooms.filter(x => x !== r) }, `Removed room "${r}"`);
  }

  function formatBytes(n?: number) {
    if (!n) return '';
    return n >= 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;
  }
</script>

<div class="sd-page">
  <!-- ═══ HEADER ═══════════════════════════════════════════════════ -->
  <header class="sd-head">
    <div class="sd-head-text">
      <h1 class="sd-title">Studio display</h1>
      <p class="sd-sub">Run the clinic TV: call tickets, manage the playlist and keep branch details current.</p>
    </div>
    <div class="sd-head-actions">
      <span class="sd-live-pill" title="Live synchronized with shared drive and connected TV screens">
        <span class="sd-live-dot"></span>
        <span>Live{liveAt ? ` · ${liveAt}` : ''}</span>
      </span>
      <a
        class="sd-tv-link"
        href="#signage?branch={activeBranchCode}"
        target="_blank"
        rel="noopener noreferrer"
        title="Open full-screen TV view for {activeBranch?.shortName || activeBranchCode}"
      >
        <span class="sd-tv-icon"><FluentIcons name="tv" /></span>
        <span>Open TV screen</span>
      </a>
      {#if tab === 'playlist'}
        <button
          type="button"
          class="sd-preview-toggle-btn"
          class:active={showLivePreview}
          onclick={() => (showLivePreview = !showLivePreview)}
          title="Toggle live TV preview frame"
        >
          <FluentIcons name="fit" />
          <span>{showLivePreview ? 'Hide preview' : 'Live preview'}</span>
        </button>
      {/if}
    </div>
  </header>

  <!-- ═══ CONFLICT NOTIFICATION (409 SAFEGUARD) ═══════════════════ -->
  {#if conflictAlert}
    <div class="sd-conflict-banner" role="alert">
      <span class="sd-conflict-icon"><FluentIcons name="warning" /></span>
      <span class="sd-conflict-text">{conflictAlert}</span>
      <button type="button" class="sd-conflict-dismiss" onclick={() => (conflictAlert = '')}>✕</button>
    </div>
  {/if}

  <!-- ═══ BRANCH SWITCHER BAR (ALWAYS VISIBLE) ════════════════════ -->
  <section class="sd-branch-bar" aria-label="Branch selector">
    <span class="sd-branch-label">Branch:</span>
    <div class="sd-branch-pills">
      {#each branches as b (b.code)}
        {@const isSelected = activeBranchCode === b.code}
        {@const isOnTv = tvBranchCode === b.code}
        <button
          type="button"
          class="sd-branch-chip"
          class:selected={isSelected}
          onclick={() => selectBranch(b.code)}
          aria-pressed={isSelected}
        >
          <span class="sd-branch-name">{b.shortName || b.name}</span>
          {#if isOnTv}
            <span class="sd-tv-badge" title="Currently showing on connected TV displays">
              <FluentIcons name="tv" />
              <span>On TV</span>
            </span>
          {/if}
          {#if !b.kkmLicense}
            <span class="sd-warn-dot" title="KKM licence missing">!</span>
          {/if}
          {#if isSelected && canManage && !isOnTv && branches.length > 1}
            <span
              role="button"
              tabindex="0"
              class="sd-chip-remove-btn"
              title="Remove branch {b.name}"
              aria-label="Remove branch {b.name}"
              onclick={(e) => { e.stopPropagation(); promptArchiveBranch(b); }}
              onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.stopPropagation(); promptArchiveBranch(b); } }}
            >
              ✕
            </span>
          {/if}
        </button>
      {/each}

      {#if canManage}
        <button
          type="button"
          class="sd-add-branch-chip"
          onclick={openAddBranchModal}
          title="Add a new branch"
        >
          <FluentIcons name="add" />
          <span>Add branch</span>
        </button>

        {#if activeBranch && branches.length > 1}
          <button
            type="button"
            class="sd-remove-branch-chip"
            onclick={() => promptArchiveBranch(activeBranch)}
            title={tvBranchCode === activeBranchCode ? 'Currently on TV — switch TV branch first' : `Remove branch ${activeBranch.shortName || activeBranch.name}`}
          >
            <FluentIcons name="trash" />
            <span>Remove branch</span>
          </button>
        {/if}
      {/if}
    </div>
  </section>

  <!-- ═══ NAVIGATION TABS (ROYAL BLUE ACCENT, NO LOW CONTRAST) ═════ -->
  <nav class="sd-tabs" role="tablist" aria-label="Studio display sections">
    {#each visibleTabs as t (t.id)}
      <button
        type="button"
        role="tab"
        id="sd-tab-{t.id}"
        class="sd-tab"
        class:active={tab === t.id}
        aria-selected={tab === t.id}
        onclick={() => (tab = t.id)}
      >
        {t.label}
      </button>
    {/each}
  </nav>

  <!-- ═══ BODY / ACTIVE TAB CONTENT ═══════════════════════════════ -->
  {#if isLoading}
    <FluentCard padding="48px">
      <div class="sd-loading-state">
        <span class="sd-loading-spinner"></span>
        <p class="sd-loading-text">Loading Studio display for {activeBranchCode || 'clinic'}…</p>
      </div>
    </FluentCard>
  {:else if loadError || !config}
    <FluentCard padding="32px">
      <div class="sd-error-state">
        <span class="sd-error-icon"><FluentIcons name="warning" /></span>
        <h2 class="sd-error-title">Studio display not available</h2>
        <p class="sd-error-text">{loadError || 'Could not connect to the signage service.'}</p>
        <FluentButton appearance="primary" size="touch" onclick={loadAll}>Try again</FluentButton>
      </div>
    </FluentCard>
  {:else}
    <main class="sd-body" class:is-busy={busy}>
      <!-- ─── QUEUE TAB ─────────────────────────────────────────── -->
      {#if tab === 'queue'}
        <!-- Active Call Banner -->
        <FluentCard padding="20px">
          <div class="sd-now-card" class:idle={!current}>
            <span class="sd-now-tag">Now Calling</span>
            <span class="sd-now-ticket">{current ? current.ticket : '—'}</span>
            <span class="sd-now-room">{current ? current.room : 'No ticket currently being called'}</span>
            {#if current?.doctor}
              <span class="sd-now-doctor">{current.doctor}</span>
            {/if}
          </div>
          <div class="sd-call-actions">
            <FluentButton
              appearance="secondary"
              size="touch"
              onclick={callNext}
              disabled={busy || waiting.length === 0}
              class="sd-btn-grow"
            >
              <span>Call next</span>
              {#if waiting.length > 0}
                <span class="sd-next-pill">{waiting[0].ticket}</span>
              {/if}
            </FluentButton>
            <FluentButton
              appearance="secondary"
              size="touch"
              onclick={recallCurrent}
              disabled={busy || !current}
              class="sd-btn-grow"
            >
              Recall current
            </FluentButton>
            <FluentButton
              appearance="danger"
              size="touch"
              onclick={promptClearQueue}
              disabled={busy || (!current && waiting.length === 0)}
            >
              Clear queue
            </FluentButton>
          </div>
        </FluentCard>

        <!-- Ticket Keypad & Waiting List Grid -->
        <div class="sd-queue-grid">
          <!-- Keypad & Selector -->
          <FluentCard padding="20px">
            <h2 class="sd-section-title">New Ticket</h2>

            <!-- Prefix Selection Chips -->
            <div class="sd-chips-group" aria-label="Ticket prefix">
              {#each PREFIXES as p (p)}
                <button
                  type="button"
                  class="sd-prefix-chip"
                  class:selected={prefix === p}
                  onclick={() => (prefix = p)}
                >
                  {p}
                </button>
              {/each}
            </div>

            <!-- Ticket Digits Display -->
            <div class="sd-ticket-display" aria-live="polite">
              {ticket || `${prefix}-…`}
            </div>

            <!-- 3x4 Touch Keypad -->
            <div class="sd-keypad">
              {#each ['1','2','3','4','5','6','7','8','9'] as d (d)}
                <button type="button" class="sd-key" onclick={() => pressKeypad(d)}>{d}</button>
              {/each}
              <button type="button" class="sd-key sd-key-action" onclick={() => (digits = '')} aria-label="Clear digits">C</button>
              <button type="button" class="sd-key" onclick={() => pressKeypad('0')}>0</button>
              <button type="button" class="sd-key sd-key-action" onclick={backspaceKeypad} aria-label="Delete last digit">⌫</button>
            </div>

            <!-- Room Chips -->
            <h3 class="sd-sub-title">Destination Room</h3>
            <div class="sd-chips-group">
              {#each rooms as r (r)}
                <button
                  type="button"
                  class="sd-room-chip"
                  class:selected={room === r}
                  onclick={() => (room = r)}
                >
                  {r}
                </button>
              {/each}
            </div>

            <!-- Doctor Chips -->
            {#if doctors.length > 0}
              <h3 class="sd-sub-title">Duty Doctor <span class="sd-optional">(optional)</span></h3>
              <div class="sd-chips-group">
                <button
                  type="button"
                  class="sd-doctor-chip"
                  class:selected={doctor === ''}
                  onclick={() => (doctor = '')}
                >
                  None
                </button>
                {#each doctors as d (d)}
                  <button
                    type="button"
                    class="sd-doctor-chip"
                    class:selected={doctor === d}
                    onclick={() => (doctor = d)}
                  >
                    {d}
                  </button>
                {/each}
              </div>
            {/if}

            <!-- CTA Row: Exactly ONE Banana Yellow CTA per tab! -->
            <div class="sd-queue-cta-row">
              <FluentButton
                appearance="cta"
                size="touch"
                onclick={callNow}
                disabled={busy || !ticket}
                class="sd-btn-grow"
              >
                Call now
              </FluentButton>
              <FluentButton
                appearance="secondary"
                size="touch"
                onclick={addToWaiting}
                disabled={busy || !ticket}
                class="sd-btn-grow"
              >
                Add to waiting
              </FluentButton>
            </div>
          </FluentCard>

          <!-- Waiting List -->
          <FluentCard padding="20px">
            <div class="sd-card-header">
              <h2 class="sd-section-title">Waiting List ({waiting.length})</h2>
              <span class="sd-branch-tag">{activeBranch?.shortName || activeBranchCode}</span>
            </div>

            {#if waiting.length === 0}
              <div class="sd-empty-box">
                <span class="sd-empty-icon"><FluentIcons name="users" /></span>
                <p class="sd-empty-text">No patients waiting right now.</p>
                <span class="sd-empty-sub">Type a ticket number on the keypad and tap "Add to waiting".</span>
              </div>
            {:else}
              <ul class="sd-waiting-list" aria-label="Upcoming tickets">
                {#each waiting as w, i (w.ticket)}
                  <li class="sd-waiting-item">
                    <div class="sd-waiting-info">
                      <span class="sd-waiting-num">{i + 1}.</span>
                      <span class="sd-waiting-ticket">{w.ticket}</span>
                      <span class="sd-waiting-room">{w.room || room}</span>
                    </div>
                    <div class="sd-waiting-actions">
                      <FluentButton
                        appearance="secondary"
                        size="sm"
                        onclick={() => callTicket(w.ticket, w.room || room, true)}
                        disabled={busy}
                        title="Call {w.ticket} now"
                      >
                        Call
                      </FluentButton>
                      <button
                        type="button"
                        class="sd-icon-btn"
                        aria-label="Move {w.ticket} up"
                        onclick={() => moveWaitingItem(i, -1)}
                        disabled={busy || i === 0}
                      >
                        <FluentIcons name="arrowUp" />
                      </button>
                      <button
                        type="button"
                        class="sd-icon-btn"
                        aria-label="Move {w.ticket} down"
                        onclick={() => moveWaitingItem(i, 1)}
                        disabled={busy || i === waiting.length - 1}
                      >
                        <FluentIcons name="arrowDown" />
                      </button>
                      <button
                        type="button"
                        class="sd-icon-btn sd-icon-danger"
                        aria-label="Remove {w.ticket} from queue"
                        onclick={() => removeWaitingItem(i)}
                        disabled={busy}
                      >
                        <FluentIcons name="close" />
                      </button>
                    </div>
                  </li>
                {/each}
              </ul>
            {/if}
          </FluentCard>
        </div>
      {/if}

      <!-- ─── PLAYLIST TAB ──────────────────────────────────────── -->
      {#if tab === 'playlist'}
        <FluentCard padding="20px">
          <!-- Playlist Top Controls -->
          <div class="sd-playlist-top">
            <div>
              <h2 class="sd-section-title">TV Playlist · {activeBranch?.shortName || activeBranchCode}</h2>
              <p class="sd-sub">Slides loop continuously on the TV screen. Video items play full duration.</p>
            </div>
            <div class="sd-playlist-actions">
              <!-- Global Slide Duration Stepper -->
              <div class="sd-duration-stepper" title="Default duration for standard slides">
                <button
                  type="button"
                  class="sd-step-btn"
                  aria-label="Decrease slide duration"
                  onclick={() => changeGlobalDuration(-1)}
                  disabled={busy || (config.slideDurationSec || 10) <= 3}
                >
                  −
                </button>
                <span class="sd-step-label">{config.slideDurationSec || 10}s per slide</span>
                <button
                  type="button"
                  class="sd-step-btn"
                  aria-label="Increase slide duration"
                  onclick={() => changeGlobalDuration(1)}
                  disabled={busy || (config.slideDurationSec || 10) >= 120}
                >
                  +
                </button>
              </div>

              <!-- Action buttons -->
              <FluentButton appearance="secondary" size="md" onclick={openCopyPlaylistModal} title="Copy slides from another branch">
                <FluentIcons name="copy" />
                <span>Copy from branch</span>
              </FluentButton>
              <FluentButton appearance="secondary" size="md" onclick={promptRestoreDefaults} title="Restore standard 5 clinical slides">
                <FluentIcons name="refresh" />
                <span>Restore defaults</span>
              </FluentButton>
              <!-- Exactly ONE Banana Yellow CTA per tab! -->
              <FluentButton appearance="cta" size="touch" onclick={() => openAddSlideModal('banner')} class="sd-cta-button">
                <FluentIcons name="plus" />
                <span>Add to playlist</span>
              </FluentButton>
            </div>
          </div>

          <!-- Main Layout: Slide List + Live TV Preview -->
          <div class="sd-playlist-layout" class:has-preview={showLivePreview}>
            <!-- Slides List -->
            <div class="sd-slides-container">
              {#if config.slides.length === 0}
                <div class="sd-empty-box">
                  <span class="sd-empty-icon"><FluentIcons name="tv" /></span>
                  <p class="sd-empty-text">Playlist is empty for {activeBranchCode}.</p>
                  <FluentButton appearance="cta" size="touch" onclick={promptRestoreDefaults}>
                    Restore default clinical slides
                  </FluentButton>
                </div>
              {:else}
                <ul class="sd-slides-list" aria-label="Playlist slides">
                  {#each config.slides as s, i (s.id)}
                    {@const isBuiltIn = BUILT_IN_TYPES.includes(s.type)}
                    <li class="sd-slide-card" class:disabled-slide={!s.enabled}>
                      <!-- Slide 16:9 Thumbnail -->
                      <div class="sd-thumbnail-box">
                        {#if s.type === 'banner' && s.src}
                          <img
                            src={s.src}
                            alt={s.alt || s.title}
                            class="sd-thumb-img"
                            style="object-fit: {s.fit || 'cover'};"
                            loading="lazy"
                          />
                        {:else if s.type === 'video' && s.src}
                          <div class="sd-thumb-video-placeholder">
                            <span class="sd-thumb-video-icon"><FluentIcons name="video" /></span>
                            <span class="sd-thumb-video-badge">{s.muted ? 'Muted' : 'Sound on'}</span>
                          </div>
                        {:else}
                          <div class="sd-thumb-glyph-tile" class:doctors-tile={s.type === 'doctors'} class:treatment-tile={s.type === 'eswt' || s.type === 'trt'} class:notice-tile={s.type === 'notice'}>
                            {#if s.type === 'doctors'}
                              <FluentIcons name="users" />
                            {:else if s.type === 'eswt' || s.type === 'trt'}
                              <FluentIcons name="sparkles" />
                            {:else if s.type === 'intake'}
                              <FluentIcons name="checkmark" />
                            {:else}
                              <FluentIcons name="info" />
                            {/if}
                            <span class="sd-thumb-tile-tag">{s.tag || TYPE_LABEL[s.type] || s.type}</span>
                          </div>
                        {/if}
                        {#if s.fullScreen}
                          <span class="sd-fs-pill" title="Fills entire screen overlaying queue panel">Full screen</span>
                        {/if}
                      </div>

                      <!-- Slide Metadata -->
                      <div class="sd-slide-info">
                        <div class="sd-slide-header-row">
                          <span class="sd-slide-title">{s.title || TYPE_LABEL[s.type] || s.type}</span>
                          <div class="sd-badges-wrap">
                            <span class="sd-badge-type">{TYPE_LABEL[s.type] || s.type}</span>
                            {#if s.durationSec}
                              <span class="sd-badge-timing">{s.durationSec}s</span>
                            {/if}
                            {#if s.startsAt || s.endsAt}
                              <span class="sd-badge-schedule" title="Scheduled slide">Scheduled</span>
                            {/if}
                          </div>
                        </div>

                        {#if s.subtitle}
                          <p class="sd-slide-subtitle">{s.subtitle}</p>
                        {/if}

                        <div class="sd-slide-meta-row">
                          <span class="sd-slide-meta-item">
                            {#if s.type === 'video'}
                              {formatBytes(s.sizeBytes)} · {s.muted ? 'Muted' : 'Sound on'}
                            {:else if s.type === 'banner'}
                              Fit: {s.fit || 'cover'}
                            {:else}
                              Standard clinical layout
                            {/if}
                          </span>
                        </div>
                      </div>

                      <!-- Slide Actions (2-Tier Compact Cluster to prevent overflow/clipping) -->
                      <div class="sd-slide-actions">
                        <!-- Upper Action Row: TV Status & Reorder -->
                        <div class="sd-actions-row sd-actions-status">
                          <span class="sd-toggle-label" class:is-on={s.enabled}>
                            {s.enabled ? 'On TV' : 'Hidden'}
                          </span>
                          <button
                            type="button"
                            class="sd-toggle-switch"
                            class:is-active={s.enabled}
                            role="switch"
                            aria-checked={s.enabled}
                            aria-label="Toggle {s.title} on TV"
                            onclick={() => toggleSlideEnabled(s)}
                            disabled={busy}
                            title={s.enabled ? 'Slide is live on TV. Click to hide.' : 'Slide is hidden. Click to show on TV.'}
                          >
                            <span class="sd-toggle-knob"></span>
                          </button>
                          <div class="sd-reorder-cluster" role="group" aria-label="Reorder slide">
                            <button
                              type="button"
                              class="sd-icon-btn sd-btn-sm"
                              aria-label="Move slide up"
                              onclick={() => moveSlideOrder(i, -1)}
                              disabled={busy || i === 0}
                              title="Move up"
                            >
                              <FluentIcons name="arrowUp" />
                            </button>
                            <button
                              type="button"
                              class="sd-icon-btn sd-btn-sm"
                              aria-label="Move slide down"
                              onclick={() => moveSlideOrder(i, 1)}
                              disabled={busy || i === config.slides.length - 1}
                              title="Move down"
                            >
                              <FluentIcons name="arrowDown" />
                            </button>
                          </div>
                        </div>

                        <!-- Lower Action Row: Content Management Tools -->
                        <div class="sd-actions-row sd-actions-tools">
                          <button
                            type="button"
                            class="sd-icon-btn sd-btn-sm"
                            aria-label="Edit slide properties"
                            onclick={() => openEditSlideModal(s)}
                            disabled={busy}
                            title="Edit slide properties"
                          >
                            <FluentIcons name="edit" />
                          </button>

                          {#if s.type === 'banner' || s.type === 'video'}
                            <button
                              type="button"
                              class="sd-icon-btn sd-btn-sm"
                              aria-label="Replace media file"
                              onclick={() => openReplaceMediaModal(s)}
                              disabled={busy}
                              title="Replace media file"
                            >
                              <FluentIcons name="upload" />
                            </button>
                          {/if}

                          <button
                            type="button"
                            class="sd-icon-btn sd-btn-sm"
                            aria-label="Duplicate slide"
                            onclick={() => duplicateSlideAction(s)}
                            disabled={busy}
                            title="Duplicate slide"
                          >
                            <FluentIcons name="copy" />
                          </button>

                          <button
                            type="button"
                            class="sd-icon-btn sd-btn-sm sd-icon-danger"
                            aria-label="Remove slide"
                            onclick={() => promptRemoveSlide(s)}
                            disabled={busy}
                            title="Delete slide"
                          >
                            <FluentIcons name="trash" />
                          </button>
                        </div>
                      </div>
                    </li>
                  {/each}
                </ul>
              {/if}
            </div>

            <!-- Live TV Preview Frame -->
            {#if showLivePreview}
              <aside class="sd-preview-pane">
                <div class="sd-preview-card">
                  <div class="sd-preview-header">
                    <span class="sd-preview-title">TV Screen Preview</span>
                    <span class="sd-preview-badge">16:9 Scaled</span>
                  </div>
                  <div class="sd-preview-frame-wrap">
                    <iframe
                      src="#signage?branch={activeBranchCode}&preview=1"
                      title="Live TV preview for {activeBranchCode}"
                      class="sd-preview-iframe"
                    ></iframe>
                  </div>
                  <p class="sd-preview-hint">Audio muted in preview. Updates in real-time as you make changes.</p>
                </div>
              </aside>
            {/if}
          </div>
        </FluentCard>
      {/if}

      <!-- ─── BRANCH INFO TAB ──────────────────────────────────── -->
      {#if tab === 'branch'}
        <div class="sd-branch-container">
          <FluentCard padding="24px">
            <div class="sd-card-header">
              <div>
                <h2 class="sd-section-title">Branch Profile · {branchForm?.name || activeBranchCode}</h2>
                <p class="sd-sub">These details appear on the TV display, patient check-in screens, and consultation kits.</p>
              </div>
              <div class="sd-branch-status-tags">
                {#if tvBranchCode === activeBranchCode}
                  <span class="sd-active-tv-tag">
                    <FluentIcons name="tv" />
                    <span>Showing on TV</span>
                  </span>
                {:else}
                  <FluentButton appearance="secondary" size="sm" onclick={() => setAsTvBranch(activeBranchCode)} disabled={busy}>
                    Show this branch on TV
                  </FluentButton>
                {/if}
                {#if canManage && activeBranch && branches.length > 1}
                  <FluentButton
                    appearance="danger"
                    size="sm"
                    onclick={() => promptArchiveBranch(activeBranch)}
                    disabled={busy || tvBranchCode === activeBranchCode}
                    title={tvBranchCode === activeBranchCode ? 'Currently on TV — switch TV branch first' : `Remove branch ${activeBranch.name}`}
                  >
                    <FluentIcons name="trash" />
                    <span>Remove branch</span>
                  </FluentButton>
                {/if}
              </div>
            </div>

            {#if branchForm}
              <form class="sd-form-grid" onsubmit={(e) => { e.preventDefault(); saveActiveBranch(); }}>
                <label class="sd-field">
                  <span class="sd-field-label">Branch name <span class="sd-req">*</span></span>
                  <input class="sd-text-input" bind:value={branchForm.name} maxlength="160" required />
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">Short name <span class="sd-req">*</span></span>
                  <input class="sd-text-input" bind:value={branchForm.shortName} maxlength="80" required />
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">Branch code</span>
                  <input class="sd-text-input" value={branchForm.code} disabled title="Branch codes are permanent and cannot be changed" />
                </label>

                <label class="sd-field full-row">
                  <span class="sd-field-label">Address</span>
                  <textarea class="sd-text-input sd-textarea" rows="2" bind:value={branchForm.address} maxlength="300"></textarea>
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">Phone</span>
                  <input class="sd-text-input" type="tel" bind:value={branchForm.phone} maxlength="40" />
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">WhatsApp</span>
                  <input class="sd-text-input" type="tel" bind:value={branchForm.whatsapp} maxlength="40" />
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">Operating hours</span>
                  <input class="sd-text-input" bind:value={branchForm.operatingHours} maxlength="200" />
                </label>

                <label class="sd-field">
                  <span class="sd-field-label">KKM licence</span>
                  <input class="sd-text-input" bind:value={branchForm.kkmLicense} maxlength="80" placeholder="e.g. 190506-00045-12" />
                  {#if !branchForm.kkmLicense}
                    <span class="sd-field-warning">Required for TV display regulatory compliance.</span>
                  {/if}
                </label>

                <label class="sd-field full-row">
                  <span class="sd-field-label">Patient check-in URL</span>
                  <input class="sd-text-input" type="url" bind:value={branchForm.checkInUrl} placeholder="https://checkin.suamisihat.clinic" />
                </label>

                <label class="sd-field full-row">
                  <span class="sd-field-label">Google review URL</span>
                  <input class="sd-text-input" type="url" bind:value={branchForm.googleReviewUrl} placeholder="https://g.page/r/..." />
                </label>

                <!-- Doctors List -->
                <div class="sd-doctors-section full-row">
                  <h3 class="sd-sub-title">Duty Doctors ({branchForm.doctors.length})</h3>
                  <div class="sd-chips-group">
                    {#each branchForm.doctors as d, i (d)}
                      <span class="sd-doctor-tag">
                        <span>{d}</span>
                        <button type="button" class="sd-tag-del" aria-label="Remove {d}" onclick={() => removeDoctorChip(i)}>✕</button>
                      </span>
                    {/each}
                    {#if branchForm.doctors.length === 0}
                      <span class="sd-empty-text">No doctors currently assigned to this branch.</span>
                    {/if}
                  </div>
                  <div class="sd-add-doctor-row">
                    <input
                      class="sd-text-input"
                      placeholder="Add doctor name (e.g. Dr. Aiman)"
                      bind:value={newDoctorName}
                      onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addDoctorChip())}
                    />
                    <FluentButton appearance="secondary" size="touch" onclick={addDoctorChip}>Add</FluentButton>
                  </div>
                </div>

                {#if branchSaveError}
                  <p class="sd-form-error full-row" role="alert">{branchSaveError}</p>
                {/if}

                <!-- CTA Row: Exactly ONE Banana Yellow CTA per tab! -->
                <div class="sd-form-cta-row full-row">
                  <FluentButton appearance="cta" size="touch" type="submit" disabled={busy} class="sd-btn-grow">
                    Save branch info
                  </FluentButton>
                </div>
              </form>
            {:else}
              <p class="sd-empty-text">Branch details could not be loaded.</p>
            {/if}
          </FluentCard>

          <!-- Danger Zone / Archive Branch -->
          <FluentCard padding="20px" class="sd-danger-card">
            <div class="sd-danger-wrap">
              <div>
                <h3 class="sd-danger-title">Remove branch · {activeBranch?.name || activeBranchCode}</h3>
                <p class="sd-danger-desc">
                  Removing safely archives this branch so it no longer appears in TV displays, queues, or navigation. All patient logs, doctor assignments, and licences are kept intact and can be restored anytime from <strong>Removed branches</strong> below.
                </p>
                {#if tvBranchCode === activeBranchCode}
                  <p class="sd-danger-hint">
                    ⚠️ <strong>Currently broadcasting on TV:</strong> To remove this branch, please select another branch first (e.g. from the branch bar above) and click <em>"Show this branch on TV"</em>.
                  </p>
                {/if}
              </div>
              <FluentButton
                appearance="danger"
                size="touch"
                onclick={() => promptArchiveBranch(activeBranch)}
                disabled={busy || branches.length <= 1 || tvBranchCode === activeBranchCode}
              >
                Remove this branch
              </FluentButton>
            </div>
          </FluentCard>

          <!-- Removed / Archived Branches Disclosure -->
          {#if archivedBranches.length > 0}
            <FluentCard padding="20px">
              <button
                type="button"
                class="sd-accordion-head"
                onclick={() => (archivedExpanded = !archivedExpanded)}
                aria-expanded={archivedExpanded}
              >
                <div class="sd-accordion-title-wrap">
                  <FluentIcons name="archive" />
                  <span class="sd-accordion-title">Removed branches ({archivedBranches.length})</span>
                </div>
                <FluentIcons name={archivedExpanded ? 'chevronDown' : 'chevronRight'} />
              </button>

              {#if archivedExpanded}
                <ul class="sd-archived-list">
                  {#each archivedBranches as ab (ab.code)}
                    <li class="sd-archived-item">
                      <div class="sd-archived-info">
                        <span class="sd-archived-code">{ab.code}</span>
                        <span class="sd-archived-name">{ab.name}</span>
                        <span class="sd-archived-sub">{ab.doctors?.length || 0} doctors · Archived</span>
                      </div>
                      <div class="sd-archived-actions">
                        <FluentButton appearance="secondary" size="sm" onclick={() => restoreArchivedBranch(ab.code)} disabled={busy}>
                          Restore
                        </FluentButton>
                        <FluentButton appearance="danger" size="sm" onclick={() => promptPermanentDelete(ab)} disabled={busy}>
                          Delete permanently
                        </FluentButton>
                      </div>
                    </li>
                  {/each}
                </ul>
              {/if}
            </FluentCard>
          {/if}
        </div>
      {/if}

      <!-- ─── DISPLAY TAB ───────────────────────────────────────── -->
      {#if tab === 'display'}
        <div class="sd-display-settings-grid">
          <!-- Audio Settings -->
          <FluentCard padding="20px">
            <h2 class="sd-section-title">Call Sound & Audio</h2>
            <div class="sd-setting-row">
              <div class="sd-setting-info">
                <span class="sd-setting-title">Chime and voice announcement</span>
                <span class="sd-setting-sub">
                  Plays a pleasant clinical chime and ticket callout on the TV when a patient is called.
                  (Note: TV browser must be touched once after startup to grant audio playback permission).
                </span>
              </div>
              <button
                type="button"
                class="sd-toggle-switch"
                class:is-active={config.soundAlertEnabled}
                role="switch"
                aria-checked={config.soundAlertEnabled}
                aria-label="Sound alert"
                onclick={() => saveDisplaySettings({ soundAlertEnabled: !config!.soundAlertEnabled }, 'Audio alert settings saved')}
                disabled={busy}
              >
                <span class="sd-toggle-knob"></span>
              </button>
            </div>
          </FluentCard>

          <!-- Ticker Settings -->
          <FluentCard padding="20px">
            <h2 class="sd-section-title">Scrolling Announcement Ticker</h2>
            <div class="sd-setting-row">
              <div class="sd-setting-info">
                <span class="sd-setting-title">Show scrolling ticker</span>
                <span class="sd-setting-sub">Displays a smooth news ticker ribbon along the bottom edge of the TV.</span>
              </div>
              <button
                type="button"
                class="sd-toggle-switch"
                class:is-active={config.ticker.enabled}
                role="switch"
                aria-checked={config.ticker.enabled}
                aria-label="Show ticker"
                onclick={() => saveDisplaySettings({ ticker: { ...config!.ticker, enabled: !config!.ticker.enabled } }, 'Ticker visibility saved')}
                disabled={busy}
              >
                <span class="sd-toggle-knob"></span>
              </button>
            </div>

            {#if tickerDraft}
              <div class="sd-ticker-form">
                <label class="sd-field">
                  <span class="sd-field-label">Ticker Prefix</span>
                  <input class="sd-text-input" bind:value={tickerDraft.prefix} maxlength="40" placeholder="e.g. PENGUMUMAN" />
                </label>
                <label class="sd-field full-row">
                  <span class="sd-field-label">Message</span>
                  <textarea class="sd-text-input sd-textarea" rows="3" bind:value={tickerDraft.text} maxlength="600" placeholder="Enter message text to scroll across the TV..."></textarea>
                </label>
                <!-- Exactly ONE Banana Yellow CTA per tab! -->
                <div class="sd-form-cta-row full-row">
                  <FluentButton
                    appearance="cta"
                    size="touch"
                    onclick={() => saveDisplaySettings({ ticker: { ...config!.ticker, ...tickerDraft } }, 'Ticker message updated')}
                    disabled={busy}
                    class="sd-btn-grow"
                  >
                    Save ticker
                  </FluentButton>
                </div>
              </div>
            {/if}
          </FluentCard>

          <!-- Rooms & Counters Settings -->
          <FluentCard padding="20px">
            <h2 class="sd-section-title">Rooms & Consultation Counters ({rooms.length})</h2>
            <p class="sd-sub">Rooms selectable when calling tickets for this branch.</p>
            <div class="sd-chips-group">
              {#each rooms as r (r)}
                <span class="sd-doctor-tag">
                  <span>{r}</span>
                  <button type="button" class="sd-tag-del" aria-label="Remove room {r}" onclick={() => removeRoomAction(r)}>✕</button>
                </span>
              {/each}
            </div>
            <div class="sd-add-doctor-row">
              <input
                class="sd-text-input"
                placeholder="Add room name (e.g. Bilik Rawatan 3)"
                bind:value={newRoomName}
                onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addRoomAction())}
              />
              <FluentButton appearance="secondary" size="touch" onclick={addRoomAction}>Add</FluentButton>
            </div>
          </FluentCard>
        </div>
      {/if}
    </main>
  {/if}
</div>

<!-- ═══ MODAL: ADD SLIDE (BANNER / VIDEO / NOTICE) ══════════════ -->
<FluentDialog
  bind:open={addModalOpen}
  title="Add to Playlist"
  confirmText="Add to playlist"
  onConfirm={submitAddSlide}
  onClose={() => (addModalOpen = false)}
  confirmAppearance="primary"
  loading={busy || uploadPct !== null}
>
  <div class="sd-modal-tabs">
    <button
      type="button"
      class="sd-modal-tab"
      class:selected={addSlideType === 'banner'}
      onclick={() => (addSlideType = 'banner')}
    >
      <FluentIcons name="image" />
      <span>Banner image</span>
    </button>
    <button
      type="button"
      class="sd-modal-tab"
      class:selected={addSlideType === 'video'}
      onclick={() => (addSlideType = 'video')}
    >
      <FluentIcons name="video" />
      <span>Video</span>
    </button>
    <button
      type="button"
      class="sd-modal-tab"
      class:selected={addSlideType === 'notice'}
      onclick={() => (addSlideType = 'notice')}
    >
      <FluentIcons name="info" />
      <span>Notice</span>
    </button>
  </div>

  {#if addSlideType === 'banner'}
    <div class="sd-modal-content">
      <div class="sd-spec-callout">
        <strong>Recommended banner specifications:</strong>
        <span>1920×1080 (16:9), JPG, PNG, or WebP up to 10 MB. Keep text 5% away from edges.</span>
      </div>

      <label class="sd-file-dropzone">
        <input type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" onchange={onAddFileSelected} hidden />
        {#if addFilePreviewUrl}
          <img src={addFilePreviewUrl} alt="Preview" class="sd-dropzone-preview" />
          <span class="sd-dropzone-change">Click to choose a different image</span>
        {:else}
          <FluentIcons name="upload" />
          <span class="sd-dropzone-label">Tap or click to select a banner image</span>
          <span class="sd-dropzone-sub">Max 10 MB · JPG, PNG, WebP</span>
        {/if}
      </label>

      <div class="sd-form-grid">
        <label class="sd-field">
          <span class="sd-field-label">Slide title</span>
          <input class="sd-text-input" bind:value={addSlideTitle} placeholder="e.g. November Promotion" maxlength="120" />
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Header tag</span>
          <input class="sd-text-input" bind:value={addSlideTag} placeholder="e.g. PROMO" maxlength="40" />
        </label>
        <label class="sd-field full-row">
          <span class="sd-field-label">Subtitle / Caption <span class="sd-optional">(optional)</span></span>
          <input class="sd-text-input" bind:value={addSlideSubtitle} placeholder="Short caption shown at bottom of slide" maxlength="200" />
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Duration (seconds)</span>
          <input class="sd-text-input" type="number" min="3" max="120" bind:value={addSlideDuration} placeholder="Default ({config?.slideDurationSec || 10}s)" />
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Fit Mode</span>
          <select class="sd-text-input" bind:value={addSlideFit}>
            <option value="cover">Cover (Fill screen, crop edges)</option>
            <option value="contain">Contain (Fit full image inside)</option>
          </select>
        </label>
      </div>

      {#if uploadPct !== null}
        <div class="sd-upload-progress-wrap">
          <div class="sd-progress-bar" style="width: {uploadPct}%"></div>
          <span class="sd-progress-label">Uploading image… {uploadPct}%</span>
        </div>
      {/if}
    </div>
  {:else if addSlideType === 'video'}
    <div class="sd-modal-content">
      <div class="sd-spec-callout">
        <strong>Recommended video specifications:</strong>
        <span>1080p MP4 or WebM up to 300 MB. Will loop smoothly in sequence.</span>
      </div>

      <label class="sd-file-dropzone">
        <input type="file" accept="video/mp4,video/webm,.mp4,.webm" onchange={onAddFileSelected} hidden />
        <FluentIcons name="video" />
        <span class="sd-dropzone-label">{addFileToUpload ? addFileToUpload.name : 'Tap or click to select video file'}</span>
        <span class="sd-dropzone-sub">Max 300 MB · MP4, WebM</span>
      </label>

      <div class="sd-form-grid">
        <label class="sd-field">
          <span class="sd-field-label">Video title</span>
          <input class="sd-text-input" bind:value={addSlideTitle} placeholder="e.g. SuamiSihat Clinic Intro" maxlength="120" />
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Category tag</span>
          <input class="sd-text-input" bind:value={addSlideTag} placeholder="FEATURE" maxlength="40" />
        </label>
      </div>

      {#if uploadPct !== null}
        <div class="sd-upload-progress-wrap">
          <div class="sd-progress-bar" style="width: {uploadPct}%"></div>
          <span class="sd-progress-label">Uploading video… {uploadPct}%</span>
        </div>
      {/if}
    </div>
  {:else if addSlideType === 'notice'}
    <div class="sd-modal-content">
      <div class="sd-form-grid">
        <label class="sd-field full-row">
          <span class="sd-field-label">Notice title <span class="sd-req">*</span></span>
          <input class="sd-text-input" bind:value={addSlideTitle} placeholder="e.g. Waktu Rehat & Solat Jumaat" maxlength="120" required />
        </label>
        <label class="sd-field full-row">
          <span class="sd-field-label">Message / Details</span>
          <textarea class="sd-text-input sd-textarea" rows="3" bind:value={addSlideSubtitle} placeholder="Klinik akan ditutup sementara dari 12:30 PM hingga 2:30 PM..." maxlength="300"></textarea>
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Tag</span>
          <input class="sd-text-input" bind:value={addSlideTag} placeholder="ANNOUNCEMENT" maxlength="40" />
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Duration (seconds)</span>
          <input class="sd-text-input" type="number" min="3" max="120" bind:value={addSlideDuration} placeholder="Default ({config?.slideDurationSec || 10}s)" />
        </label>
      </div>
    </div>
  {/if}
</FluentDialog>

<!-- ═══ MODAL: EDIT SLIDE ═══════════════════════════════════════ -->
<FluentDialog
  bind:open={editModalOpen}
  title="Edit Slide: {editingSlide?.title || 'Slide'}"
  confirmText="Save changes"
  onConfirm={submitEditSlide}
  onClose={() => (editModalOpen = false)}
  confirmAppearance="primary"
  loading={busy}
>
  <div class="sd-modal-content">
    <div class="sd-form-grid">
      <label class="sd-field full-row">
        <span class="sd-field-label">Slide title</span>
        <input class="sd-text-input" bind:value={editTitle} maxlength="120" />
      </label>
      <label class="sd-field full-row">
        <span class="sd-field-label">Subtitle / Caption</span>
        <textarea class="sd-text-input sd-textarea" rows="2" bind:value={editSubtitle} maxlength="300"></textarea>
      </label>
      <label class="sd-field">
        <span class="sd-field-label">Tag</span>
        <input class="sd-text-input" bind:value={editTag} maxlength="40" />
      </label>
      <label class="sd-field">
        <span class="sd-field-label">Custom Duration (seconds)</span>
        <input class="sd-text-input" type="number" min="3" max="120" bind:value={editDuration} placeholder="Global ({config?.slideDurationSec || 10}s)" />
      </label>

      {#if editingSlide?.type === 'banner'}
        <label class="sd-field">
          <span class="sd-field-label">Image Fit</span>
          <select class="sd-text-input" bind:value={editFit}>
            <option value="cover">Cover (Fill screen)</option>
            <option value="contain">Contain (Letterbox)</option>
          </select>
        </label>
        <label class="sd-field">
          <span class="sd-field-label">Accessibility Alt Text</span>
          <input class="sd-text-input" bind:value={editAlt} placeholder="Describe the image content" maxlength="160" />
        </label>
        <label class="sd-checkbox-field full-row">
          <input type="checkbox" bind:checked={editFullScreen} />
          <span>Full-screen overlay (covers queue panel while showing)</span>
        </label>
      {/if}

      {#if editingSlide?.type === 'video'}
        <label class="sd-checkbox-field full-row">
          <input type="checkbox" bind:checked={editMuted} />
          <span>Play video muted (recommended for busy waiting rooms)</span>
        </label>
      {/if}
    </div>
  </div>
</FluentDialog>

<!-- ═══ MODAL: REPLACE MEDIA ════════════════════════════════════ -->
<FluentDialog
  bind:open={replaceModalOpen}
  title="Replace Media: {replacingSlide?.title || 'Slide'}"
  confirmText="Upload replacement"
  onConfirm={submitReplaceMedia}
  onClose={() => (replaceModalOpen = false)}
  confirmAppearance="primary"
  loading={busy || uploadPct !== null}
>
  <div class="sd-modal-content">
    <p class="sd-sub">Replaces the file while keeping this slide's slot and settings intact.</p>
    <label class="sd-file-dropzone">
      <input
        type="file"
        accept={replacingSlide?.type === 'video' ? 'video/mp4,video/webm,.mp4,.webm' : 'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp'}
        onchange={onReplaceFileSelected}
        hidden
      />
      {#if replacePreviewUrl}
        <img src={replacePreviewUrl} alt="Replacement Preview" class="sd-dropzone-preview" />
        <span class="sd-dropzone-change">Click to choose a different file</span>
      {:else}
        <FluentIcons name="upload" />
        <span class="sd-dropzone-label">{replaceFile ? replaceFile.name : 'Tap or click to select new file'}</span>
        <span class="sd-dropzone-sub">{replacingSlide?.type === 'video' ? 'MP4, WebM up to 300 MB' : 'JPG, PNG, WebP up to 10 MB'}</span>
      {/if}
    </label>

    {#if uploadPct !== null}
      <div class="sd-upload-progress-wrap">
        <div class="sd-progress-bar" style="width: {uploadPct}%"></div>
        <span class="sd-progress-label">Uploading replacement… {uploadPct}%</span>
      </div>
    {/if}
  </div>
</FluentDialog>

<!-- ═══ MODAL: COPY PLAYLIST FROM BRANCH ════════════════════════ -->
<FluentDialog
  bind:open={copyModalOpen}
  title="Copy Playlist from Another Branch"
  confirmText="Copy playlist"
  onConfirm={submitCopyPlaylist}
  onClose={() => (copyModalOpen = false)}
  confirmAppearance="primary"
  loading={busy}
>
  <div class="sd-modal-content">
    <p class="sd-sub">Select which branch's playlist to duplicate into <strong>{activeBranchCode}</strong>:</p>
    <label class="sd-field full-row">
      <span class="sd-field-label">Source Branch</span>
      <select class="sd-text-input" bind:value={copyFromBranchCode}>
        {#each branches.filter(b => b.code !== activeBranchCode) as b (b.code)}
          <option value={b.code}>{b.shortName || b.name} ({b.code})</option>
        {/each}
      </select>
    </label>
    <div class="sd-spec-callout">
      <span>Media files are linked by reference — no extra NAS storage will be consumed.</span>
    </div>
  </div>
</FluentDialog>

<!-- ═══ MODAL: ADD BRANCH ═══════════════════════════════════════ -->
<FluentDialog
  bind:open={addBranchModalOpen}
  title="Add New Clinic Branch"
  confirmText="Create branch"
  onConfirm={submitAddBranch}
  onClose={() => (addBranchModalOpen = false)}
  confirmAppearance="primary"
  loading={busy}
>
  <div class="sd-modal-content">
    <div class="sd-form-grid">
      <label class="sd-field">
        <span class="sd-field-label">Branch name <span class="sd-req">*</span></span>
        <input class="sd-text-input" bind:value={newBranchName} placeholder="e.g. SuamiSihat Clinic Mont Kiara" maxlength="160" required />
      </label>
      <label class="sd-field">
        <span class="sd-field-label">Short name <span class="sd-req">*</span></span>
        <input class="sd-text-input" bind:value={newBranchShortName} oninput={onShortNameInput} placeholder="e.g. Mont Kiara" maxlength="80" required />
      </label>
      <label class="sd-field">
        <span class="sd-field-label">Branch code <span class="sd-req">*</span></span>
        <input class="sd-text-input" bind:value={newBranchCode} placeholder="e.g. SSC-MK" maxlength="12" required />
      </label>
      <label class="sd-field">
        <span class="sd-field-label">KKM licence</span>
        <input class="sd-text-input" bind:value={newBranchKkm} placeholder="e.g. 190506-00045-12" maxlength="80" />
      </label>
      <label class="sd-field full-row">
        <span class="sd-field-label">Address</span>
        <textarea class="sd-text-input sd-textarea" rows="2" bind:value={newBranchAddress} maxlength="300"></textarea>
      </label>
      <label class="sd-field">
        <span class="sd-field-label">Phone</span>
        <input class="sd-text-input" type="tel" bind:value={newBranchPhone} maxlength="40" />
      </label>
      <label class="sd-field">
        <span class="sd-field-label">WhatsApp</span>
        <input class="sd-text-input" type="tel" bind:value={newBranchWhatsapp} maxlength="40" />
      </label>
      <label class="sd-field full-row">
        <span class="sd-field-label">Initialize playlist from</span>
        <select class="sd-text-input" bind:value={newBranchCopyPlaylistFrom}>
          <option value="">Standard 5 default slides</option>
          {#each branches as b (b.code)}
            <option value={b.code}>Copy from {b.shortName || b.name} ({b.code})</option>
          {/each}
        </select>
      </label>
    </div>

    {#if addBranchError}
      <p class="sd-form-error" role="alert">{addBranchError}</p>
    {/if}
  </div>
</FluentDialog>

<!-- ═══ MODAL: DELETE PERMANENTLY (TYPING CODE CONFIRMATION) ═════ -->
<FluentDialog
  bind:open={deleteBranchModalOpen}
  title="Permanent Deletion: {branchToDelete?.name}"
  confirmText="Permanently delete"
  confirmAppearance="danger"
  onConfirm={executePermanentDelete}
  onClose={() => (deleteBranchModalOpen = false)}
  loading={busy}
>
  <div class="sd-modal-content">
    <p class="sd-danger-text">
      This will permanently delete branch <strong>{branchToDelete?.code}</strong> and remove all its configuration, queues, and playlist settings. This cannot be undone.
    </p>
    <label class="sd-field full-row">
      <span class="sd-field-label">Type <strong>{branchToDelete?.code}</strong> to confirm:</span>
      <input class="sd-text-input" bind:value={deleteConfirmCode} placeholder={branchToDelete?.code} />
    </label>
    {#if deleteBranchError}
      <p class="sd-form-error" role="alert">{deleteBranchError}</p>
    {/if}
  </div>
</FluentDialog>

<!-- ═══ MODAL: GENERAL CONFIRMATION DIALOG ═══════════════════════ -->
<FluentDialog
  bind:open={confirmOpen}
  title={confirmTitle}
  confirmText={confirmText}
  confirmAppearance={confirmAppearance}
  onConfirm={executeConfirm}
  onClose={() => (confirmOpen = false)}
  loading={busy}
>
  <p class="sd-dialog-desc">{confirmDesc}</p>
</FluentDialog>

<style>
  /* ═══ PAGE ROOT & 60:30:10 THEME TOKENS ═════════════════════════ */
  .sd-page {
    display: flex;
    flex-direction: column;
    gap: 20px;
    width: 100%;
    padding: 0 0 56px;
    touch-action: manipulation;
    box-sizing: border-box;
  }

  /* ═══ HEADER ════════════════════════════════════════════════════ */
  .sd-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    flex-wrap: wrap;
  }
  .sd-head-text {
    flex: 1 1 300px;
  }
  .sd-title {
    font-size: 24px;
    font-weight: 800;
    line-height: 1.25;
    letter-spacing: -0.02em;
    margin: 0;
    color: var(--text-primary, #19191A);
  }
  .sd-sub {
    margin: 6px 0 0;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    font-size: 13.5px;
    line-height: 1.5;
  }
  .sd-head-actions {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }

  .sd-live-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 14px;
    border-radius: 20px;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-live-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #107C10;
    box-shadow: 0 0 0 2px rgba(16, 124, 16, 0.2);
    animation: sdpulse 2s infinite ease-in-out;
  }
  @keyframes sdpulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.35; transform: scale(0.9); }
  }

  .sd-tv-link {
    min-height: 48px;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 0 18px;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-md, 8px);
    background: var(--surface-card, #FFFFFF);
    color: var(--brand-primary, #043388);
    font-weight: 600;
    font-size: 14px;
    text-decoration: none;
    box-shadow: var(--shadow-sm);
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-tv-link:hover {
    border-color: var(--brand-accent, #21A1F7);
    color: var(--brand-accent, #21A1F7);
    transform: translateY(-1px);
    box-shadow: var(--shadow-md);
  }
  .sd-tv-icon {
    width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .sd-preview-toggle-btn {
    min-height: 48px;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 0 16px;
    border-radius: var(--radius-md, 8px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #19191A);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-preview-toggle-btn.active {
    background: var(--surface-card-subtle, #F8FAFC);
    border-color: var(--brand-accent, #21A1F7);
    color: var(--brand-accent, #21A1F7);
  }

  /* ═══ CONFLICT NOTIFICATION ═════════════════════════════════════ */
  .sd-conflict-banner {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 18px;
    border-radius: var(--radius-md, 8px);
    background: #FFF9DB;
    border: 1px solid #FFE066;
    color: #5C3D00;
    font-size: 13.5px;
    font-weight: 600;
  }
  .sd-conflict-icon {
    width: 20px;
    height: 20px;
    flex-shrink: 0;
  }
  .sd-conflict-text {
    flex: 1;
  }
  .sd-conflict-dismiss {
    border: none;
    background: transparent;
    font-size: 16px;
    cursor: pointer;
    color: inherit;
    padding: 4px 8px;
  }

  /* ═══ BRANCH SWITCHER BAR ═══════════════════════════════════════ */
  .sd-branch-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 14px;
    border-radius: var(--radius-lg, 12px);
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    box-shadow: var(--shadow-sm);
    flex-wrap: wrap;
  }
  .sd-branch-label {
    font-size: 13px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    margin-right: 4px;
  }
  .sd-branch-pills {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    flex: 1;
  }
  .sd-branch-chip {
    min-height: 48px;
    padding: 0 16px;
    border-radius: 24px;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card-subtle, #F8FAFC);
    color: var(--text-primary, #19191A);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-branch-chip:hover {
    border-color: var(--ss-azure, #21A1F7);
    transform: translateY(-1px);
  }
  .sd-branch-chip.selected {
    background: var(--ss-blue, #043388);
    border-color: var(--ss-blue, #043388);
    color: #FFFFFF;
    box-shadow: 0 2px 8px rgba(4, 51, 136, 0.25);
  }
  .sd-tv-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.25);
    color: inherit;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .sd-branch-chip:not(.selected) .sd-tv-badge {
    background: #EBF8FF;
    color: #0369A1;
    border: 1px solid #BAE6FD;
  }
  .sd-warn-dot {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: #E5D15C;
    color: #1C1C1C;
    font-size: 11px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .sd-add-branch-chip {
    min-height: 48px;
    padding: 0 16px;
    border-radius: 24px;
    border: 1px dashed var(--ss-azure, #21A1F7);
    background: transparent;
    color: var(--ss-blue, #043388);
    font-size: 13.5px;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-add-branch-chip:hover {
    background: rgba(33, 161, 247, 0.08);
  }
  .sd-chip-remove-btn {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.25);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    font-weight: 700;
    margin-left: 2px;
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-chip-remove-btn:hover {
    background: #DC2626;
    color: #FFFFFF;
    transform: scale(1.1);
  }
  .sd-remove-branch-chip {
    min-height: 48px;
    padding: 0 16px;
    border-radius: 24px;
    border: 1px dashed #FCA5A5;
    background: transparent;
    color: #DC2626;
    font-size: 13.5px;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-remove-branch-chip:hover {
    background: #FEF2F2;
    border-color: #DC2626;
  }
  .sd-remove-branch-chip svg {
    width: 16px;
    height: 16px;
  }

  /* ═══ NAVIGATION TABS ═══════════════════════════════════════════ */
  .sd-tabs {
    display: flex;
    gap: 6px;
    padding: 6px;
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-lg, 12px);
    box-shadow: var(--shadow-sm);
    flex-wrap: wrap;
  }
  .sd-tab {
    flex: 1 1 120px;
    min-height: 52px;
    border: none;
    border-radius: var(--radius-md, 8px);
    background: transparent;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    font-size: 15px;
    font-weight: 700;
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-tab:hover:not(.active) {
    background: var(--surface-card-subtle, #F8FAFC);
    color: var(--text-primary, #19191A);
  }
  /* ROYAL BLUE ACCENT PASSES WCAG AA (>4.5:1 ON WHITE TEXT) */
  .sd-tab.active {
    background: var(--ss-blue, #043388);
    color: #FFFFFF;
    box-shadow: 0 2px 6px rgba(4, 51, 136, 0.2);
  }
  .sd-tab:focus-visible,
  .sd-branch-chip:focus-visible,
  .sd-prefix-chip:focus-visible,
  .sd-room-chip:focus-visible,
  .sd-doctor-chip:focus-visible,
  .sd-key:focus-visible,
  .sd-toggle-switch:focus-visible,
  .sd-icon-btn:focus-visible,
  .sd-text-input:focus-visible {
    outline: 2px solid var(--ss-azure, #21A1F7);
    outline-offset: 2px;
  }

  /* ═══ CONTENT BODY & GRIDS ══════════════════════════════════════ */
  .sd-body {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  .sd-body.is-busy {
    cursor: progress;
  }
  .sd-section-title {
    font-size: 18px;
    font-weight: 700;
    letter-spacing: -0.01em;
    margin: 0 0 14px;
    color: var(--text-primary, #19191A);
  }
  .sd-sub-title {
    font-size: 14px;
    font-weight: 600;
    margin: 18px 0 8px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-optional {
    font-weight: 400;
    font-size: 12px;
  }

  /* ═══ QUEUE TAB STYLING ═════════════════════════════════════════ */
  .sd-now-card {
    text-align: center;
    padding: 24px 20px;
    border-radius: var(--radius-lg, 12px);
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .sd-now-card.idle {
    opacity: 0.7;
  }
  .sd-now-tag {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--ss-blue, #043388);
  }
  .sd-now-ticket {
    font-size: 56px;
    font-weight: 800;
    line-height: 1.1;
    color: var(--ss-blue, #043388);
  }
  .sd-now-room {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
  }
  .sd-now-doctor {
    font-size: 14px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-call-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    margin-top: 16px;
  }
  .sd-btn-grow {
    flex: 1 1 140px;
  }
  .sd-next-pill {
    padding: 2px 8px;
    background: rgba(0, 0, 0, 0.1);
    border-radius: 10px;
    font-size: 12px;
  }

  .sd-queue-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(340px, 1fr));
    gap: 20px;
    align-items: start;
  }

  .sd-chips-group {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 12px;
  }
  .sd-prefix-chip,
  .sd-room-chip,
  .sd-doctor-chip {
    min-height: 48px;
    min-width: 48px;
    padding: 0 16px;
    border-radius: 24px;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #19191A);
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-prefix-chip.selected,
  .sd-room-chip.selected,
  .sd-doctor-chip.selected {
    background: var(--ss-blue, #043388);
    border-color: var(--ss-blue, #043388);
    color: #FFFFFF;
  }

  .sd-ticket-display {
    margin: 14px 0;
    text-align: center;
    font-size: 42px;
    font-weight: 800;
    letter-spacing: 0.05em;
    min-height: 56px;
    color: var(--ss-blue, #043388);
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px dashed var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-md, 8px);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .sd-keypad {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
    margin-bottom: 16px;
  }
  .sd-key {
    min-height: 58px;
    font-size: 24px;
    font-weight: 700;
    border-radius: var(--radius-md, 10px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #19191A);
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-key:active {
    transform: scale(0.97);
  }
  .sd-key-action {
    background: var(--surface-card-subtle, #F8FAFC);
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    font-size: 20px;
  }

  .sd-queue-cta-row {
    display: flex;
    gap: 12px;
    margin-top: 20px;
  }

  .sd-waiting-list {
    list-style: none;
    margin: 14px 0 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .sd-waiting-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 12px 16px;
    border-radius: var(--radius-md, 10px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    min-height: 58px;
  }
  .sd-waiting-info {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
    min-width: 0;
  }
  .sd-waiting-num {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-waiting-ticket {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary, #19191A);
  }
  .sd-waiting-room {
    font-size: 13px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-waiting-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* ═══ PLAYLIST TAB STYLING ══════════════════════════════════════ */
  .sd-playlist-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
    margin-bottom: 20px;
  }
  .sd-playlist-actions {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }
  .sd-duration-stepper {
    display: inline-flex;
    align-items: center;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-md, 8px);
    background: var(--surface-card-subtle, #F8FAFC);
    padding: 2px;
  }
  .sd-step-btn {
    min-width: 44px;
    min-height: 44px;
    border: none;
    background: transparent;
    font-size: 18px;
    font-weight: 700;
    cursor: pointer;
    border-radius: var(--radius-sm, 6px);
  }
  .sd-step-btn:hover:not(:disabled) {
    background: var(--surface-card, #FFFFFF);
  }
  .sd-step-label {
    padding: 0 12px;
    font-size: 13.5px;
    font-weight: 600;
    color: var(--text-primary, #19191A);
    white-space: nowrap;
  }

  .sd-playlist-layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: 20px;
    width: 100%;
    min-width: 0;
  }
  .sd-playlist-layout.has-preview {
    grid-template-columns: minmax(0, 1fr) 380px;
  }

  .sd-slides-container {
    width: 100%;
    min-width: 0;
  }

  .sd-slides-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 12px;
    width: 100%;
    min-width: 0;
  }
  .sd-slide-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 12px 16px;
    border-radius: var(--radius-lg, 12px);
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    transition: all var(--transition-fast, 0.15s ease);
    width: 100%;
    min-width: 0;
    box-sizing: border-box;
  }
  .sd-slide-card:hover {
    border-color: var(--brand-accent, #21A1F7);
    box-shadow: var(--shadow-sm);
  }
  .sd-slide-card.disabled-slide {
    opacity: 0.55;
    background: var(--surface-card-subtle, #F8FAFC);
  }

  .sd-thumbnail-box {
    width: 128px;
    height: 72px; /* 16:9 ratio */
    border-radius: var(--radius-md, 8px);
    overflow: hidden;
    position: relative;
    background: #022057; /* Prussian Navy ground */
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .sd-thumb-img {
    width: 100%;
    height: 100%;
    display: block;
  }
  .sd-thumb-video-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    color: #FFFFFF;
  }
  .sd-thumb-video-icon {
    width: 24px;
    height: 24px;
  }
  .sd-thumb-video-badge {
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    background: rgba(0, 0, 0, 0.5);
    border-radius: 6px;
  }
  .sd-thumb-glyph-tile {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
    width: 100%;
    height: 100%;
    color: #FFFFFF;
    padding: 8px;
    box-sizing: border-box;
  }
  .sd-thumb-glyph-tile svg {
    width: 22px;
    height: 22px;
  }
  .sd-thumb-tile-tag {
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    text-align: center;
  }
  .sd-thumb-glyph-tile.doctors-tile { background: #043388; }
  .sd-thumb-glyph-tile.treatment-tile { background: #022057; }
  .sd-thumb-glyph-tile.notice-tile { background: #1C1C1C; }

  .sd-fs-pill {
    position: absolute;
    bottom: 4px;
    right: 4px;
    background: rgba(0, 0, 0, 0.7);
    color: #FCE53D;
    font-size: 9px;
    font-weight: 800;
    padding: 2px 5px;
    border-radius: 4px;
    text-transform: uppercase;
  }

  .sd-slide-info {
    flex: 1 1 0;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
    overflow: hidden;
  }
  .sd-slide-header-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    min-width: 0;
  }
  .sd-slide-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }
  .sd-badges-wrap {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-shrink: 0;
  }
  .sd-badge-type {
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    text-transform: uppercase;
  }
  .sd-badge-timing {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 8px;
    background: #EBF8FF;
    color: #0369A1;
  }
  .sd-badge-schedule {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 8px;
    background: #FEF3C7;
    color: #92400E;
  }

  .sd-slide-subtitle {
    font-size: 13px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }
  .sd-slide-meta-row {
    font-size: 12px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }

  .sd-slide-actions {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 8px;
    flex-shrink: 0;
    min-width: 180px;
  }
  .sd-actions-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .sd-actions-status {
    gap: 8px;
  }
  .sd-toggle-label {
    font-size: 12px;
    font-weight: 700;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    min-width: 44px;
    text-align: right;
    user-select: none;
  }
  .sd-toggle-label.is-on {
    color: var(--ss-blue, #043388);
  }
  .sd-reorder-cluster {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-left: 2px;
  }
  .sd-icon-btn.sd-btn-sm {
    min-width: 36px;
    min-height: 36px;
    width: 36px;
    height: 36px;
  }
  .sd-icon-btn.sd-btn-sm svg {
    width: 16px;
    height: 16px;
  }

  /* Preview Pane */
  .sd-preview-pane {
    position: sticky;
    top: 20px;
  }
  .sd-preview-card {
    background: var(--surface-card, #FFFFFF);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-lg, 12px);
    padding: 16px;
    box-shadow: var(--shadow-sm);
  }
  .sd-preview-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }
  .sd-preview-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
  }
  .sd-preview-badge {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--surface-card-subtle, #F8FAFC);
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-preview-frame-wrap {
    width: 100%;
    aspect-ratio: 16 / 9;
    border-radius: var(--radius-md, 8px);
    overflow: hidden;
    background: #022057;
    position: relative;
    border: 1px solid var(--surface-card-border, #E2E8F0);
  }
  .sd-preview-iframe {
    width: 100%;
    height: 100%;
    border: none;
    pointer-events: none;
  }
  .sd-preview-hint {
    margin: 10px 0 0;
    font-size: 12px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    line-height: 1.4;
  }

  /* ═══ BRANCH INFO TAB STYLING ═══════════════════════════════════ */
  .sd-branch-container {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  .sd-card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    flex-wrap: wrap;
    margin-bottom: 18px;
  }
  .sd-active-tv-tag {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 14px;
    border-radius: 20px;
    background: #EBF8FF;
    border: 1px solid #BAE6FD;
    color: #0369A1;
    font-size: 13px;
    font-weight: 700;
  }
  .sd-danger-card {
    border-color: #FED7AA;
    background: #FFF7ED;
  }
  .sd-danger-wrap {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
  }
  .sd-danger-title {
    font-size: 16px;
    font-weight: 700;
    color: #9A3412;
    margin: 0 0 4px;
  }
  .sd-danger-desc {
    margin: 0;
    font-size: 13px;
    color: #7C2D12;
    max-width: 600px;
    line-height: 1.4;
  }
  .sd-danger-hint {
    margin: 8px 0 0;
    font-size: 13px;
    color: #9A3412;
    background: #FFEDD5;
    padding: 8px 12px;
    border-radius: 6px;
    line-height: 1.4;
  }

  .sd-accordion-head {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 4px 0;
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
  }
  .sd-accordion-title-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .sd-archived-list {
    list-style: none;
    margin: 16px 0 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .sd-archived-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 12px 16px;
    border-radius: var(--radius-md, 8px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card-subtle, #F8FAFC);
  }
  .sd-archived-info {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }
  .sd-archived-code {
    font-size: 14px;
    font-weight: 800;
    color: var(--text-primary, #19191A);
  }
  .sd-archived-name {
    font-size: 14px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-archived-sub {
    font-size: 12px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-archived-actions {
    display: flex;
    gap: 8px;
  }

  /* ═══ DISPLAY TAB STYLING ═══════════════════════════════════════ */
  .sd-display-settings-grid {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  .sd-setting-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
  }
  .sd-setting-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .sd-setting-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
  }
  .sd-setting-sub {
    font-size: 13px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    line-height: 1.4;
  }
  .sd-ticker-form {
    margin-top: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  /* ═══ FORM CONTROLS & SHARED ATOMS ══════════════════════════════ */
  .sd-form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 16px;
  }
  .full-row {
    grid-column: 1 / -1;
  }
  .sd-field {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .sd-field-label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-req {
    color: #DC2626;
  }
  .sd-field-warning {
    font-size: 12px;
    color: #D97706;
    margin-top: 2px;
  }
  .sd-text-input {
    min-height: 48px;
    padding: 10px 14px;
    font-size: 15px;
    border-radius: var(--radius-md, 8px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #19191A);
    font-family: inherit;
    box-sizing: border-box;
    width: 100%;
  }
  .sd-text-input:disabled {
    opacity: 0.65;
    background: var(--surface-card-subtle, #F8FAFC);
    cursor: not-allowed;
  }
  .sd-textarea {
    min-height: 80px;
    resize: vertical;
  }
  .sd-form-cta-row {
    display: flex;
    gap: 12px;
    margin-top: 10px;
  }
  .sd-form-error {
    color: #DC2626;
    font-size: 13.5px;
    font-weight: 600;
    margin: 8px 0;
  }

  .sd-doctor-tag {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-height: 44px;
    padding: 0 6px 0 14px;
    border-radius: 22px;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card-subtle, #F8FAFC);
    color: var(--text-primary, #19191A);
    font-size: 14px;
    font-weight: 600;
  }
  .sd-tag-del {
    min-width: 32px;
    min-height: 32px;
    border: none;
    background: transparent;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    font-size: 14px;
    cursor: pointer;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .sd-tag-del:hover {
    background: rgba(0, 0, 0, 0.08);
    color: #DC2626;
  }
  .sd-add-doctor-row {
    display: flex;
    gap: 10px;
    margin-top: 10px;
  }

  /* ═══ INTERACTIVE ATOMS ═════════════════════════════════════════ */
  .sd-toggle-switch {
    width: 58px;
    height: 34px;
    min-width: 58px;
    border-radius: 17px;
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card-border, #E2E8F0);
    position: relative;
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    transition: background 0.15s ease;
  }
  .sd-toggle-knob {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 26px;
    height: 26px;
    border-radius: 50%;
    background: #FFFFFF;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.25);
    transition: transform 0.15s ease;
  }
  .sd-toggle-switch.is-active {
    background: var(--ss-blue, #043388);
    border-color: var(--ss-blue, #043388);
  }
  .sd-toggle-switch.is-active .sd-toggle-knob {
    transform: translateX(24px);
  }

  .sd-icon-btn {
    min-width: 44px;
    min-height: 44px;
    padding: 0;
    border-radius: var(--radius-md, 8px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-primary, #19191A);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-icon-btn svg {
    width: 18px;
    height: 18px;
  }
  .sd-icon-btn:hover:not(:disabled) {
    background: var(--surface-card-subtle, #F8FAFC);
    border-color: var(--brand-accent, #21A1F7);
    color: var(--brand-accent, #21A1F7);
  }
  .sd-icon-btn.sd-icon-danger:hover:not(:disabled) {
    border-color: #DC2626;
    color: #DC2626;
  }
  .sd-icon-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  /* ═══ MODAL STYLES ══════════════════════════════════════════════ */
  .sd-modal-tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
    border-bottom: 1px solid var(--surface-card-border, #E2E8F0);
    padding-bottom: 12px;
  }
  .sd-modal-tab {
    flex: 1;
    min-height: 44px;
    border-radius: var(--radius-md, 8px);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    background: var(--surface-card, #FFFFFF);
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    font-size: 13.5px;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    cursor: pointer;
  }
  .sd-modal-tab.selected {
    background: var(--ss-blue, #043388);
    border-color: var(--ss-blue, #043388);
    color: #FFFFFF;
  }
  .sd-modal-content {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .sd-spec-callout {
    padding: 10px 14px;
    border-radius: var(--radius-md, 8px);
    background: var(--surface-card-subtle, #F8FAFC);
    border: 1px solid var(--surface-card-border, #E2E8F0);
    font-size: 12.5px;
    line-height: 1.4;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .sd-file-dropzone {
    min-height: 140px;
    border: 2px dashed var(--surface-card-border, #E2E8F0);
    border-radius: var(--radius-lg, 12px);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 6px;
    cursor: pointer;
    padding: 16px;
    box-sizing: border-box;
    text-align: center;
    background: var(--surface-card-subtle, #F8FAFC);
    transition: all var(--transition-fast, 0.15s ease);
  }
  .sd-file-dropzone:hover {
    border-color: var(--ss-azure, #21A1F7);
    background: rgba(33, 161, 247, 0.04);
  }
  .sd-dropzone-preview {
    max-width: 100%;
    max-height: 180px;
    border-radius: var(--radius-md, 8px);
    object-fit: contain;
  }
  .sd-dropzone-change {
    font-size: 12px;
    color: var(--ss-blue, #043388);
    font-weight: 600;
    margin-top: 4px;
  }
  .sd-dropzone-label {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary, #19191A);
  }
  .sd-dropzone-sub {
    font-size: 12px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-checkbox-field {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13.5px;
    cursor: pointer;
    color: var(--text-primary, #19191A);
  }
  .sd-upload-progress-wrap {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-top: 8px;
  }
  .sd-progress-bar {
    height: 8px;
    border-radius: 4px;
    background: var(--ss-blue, #043388);
    transition: width 0.2s ease;
  }
  .sd-progress-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    text-align: right;
  }

  /* ═══ EMPTY & LOADING STATES ════════════════════════════════════ */
  .sd-empty-box {
    text-align: center;
    padding: 36px 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
  }
  .sd-empty-icon {
    width: 36px;
    height: 36px;
    opacity: 0.6;
    margin-bottom: 4px;
  }
  .sd-empty-text {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary, #19191A);
    margin: 0;
  }
  .sd-empty-sub {
    font-size: 13px;
  }
  .sd-loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .sd-loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid var(--surface-card-border, #E2E8F0);
    border-top-color: var(--ss-blue, #043388);
    border-radius: 50%;
    animation: sdspin 0.8s linear infinite;
  }
  @keyframes sdspin {
    to { transform: rotate(360deg); }
  }
  .sd-loading-text {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    margin: 0;
  }

  .sd-error-state {
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .sd-error-icon {
    width: 40px;
    height: 40px;
    color: #DC2626;
  }
  .sd-error-title {
    font-size: 18px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary, #19191A);
  }
  .sd-error-text {
    font-size: 14px;
    color: var(--text-secondary, rgba(25, 25, 26, 0.65));
    max-width: 400px;
    margin: 0;
  }

  /* ═══ RESPONSIVE ADJUSTMENTS ════════════════════════════════════ */
  @media (max-width: 900px) {
    .sd-playlist-layout.has-preview {
      grid-template-columns: 1fr;
    }
  }
  @media (max-width: 768px) {
    .sd-slide-card {
      flex-wrap: wrap;
    }
    .sd-slide-actions {
      width: 100%;
      max-width: 100%;
      flex-direction: row;
      justify-content: space-between;
      min-width: 0;
      padding-top: 10px;
      border-top: 1px solid var(--surface-card-border, #E2E8F0);
    }
  }
  @media (max-width: 640px) {
    .sd-slide-card {
      flex-direction: column;
      align-items: flex-start;
    }
    .sd-thumbnail-box {
      width: 100%;
      height: 180px;
    }
    .sd-now-ticket {
      font-size: 42px;
    }
    .sd-tab {
      font-size: 14px;
    }
  }
</style>

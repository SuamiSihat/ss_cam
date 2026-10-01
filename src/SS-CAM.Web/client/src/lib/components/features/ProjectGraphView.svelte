<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { appState } from '$lib/stores/appState.svelte';
  import type { Project } from '$lib/types';

  interface Props {
    projects: Project[];
  }

  let { projects }: Props = $props();

  let canvasEl: HTMLCanvasElement | null = $state(null);
  let containerEl: HTMLDivElement | null = $state(null);
  let animFrameId: number | null = null;
  let hoveredNode: HierarchyNode | null = $state(null);
  let tooltipX = $state(0);
  let tooltipY = $state(0);
  let dpr = 1;

  // Camera / pan state
  let camX = 0;
  let camY = 0;
  let zoom = 1;
  let isPanning = false;
  let panStartX = 0;
  let panStartY = 0;

  // ─── Data Types ───
  type NodeType = 'root' | 'brand' | 'media' | 'project';

  interface StatusBreakdown {
    'in-progress': number;
    'review': number;
    'revision': number;
    'approved': number;
    'done': number;
    'backlog': number;
    'on-hold': number;
    'rejected': number;
    [key: string]: number;
  }

  interface HierarchyNode {
    id: string;
    type: NodeType;
    label: string;
    sublabel: string;
    color: string;
    x: number;
    y: number;
    radius: number;
    children: HierarchyNode[];
    parent: HierarchyNode | null;
    projectCount: number;
    statusBreakdown: StatusBreakdown;
    // Project-only fields
    project?: Project;
    jobId?: string;
    designer?: string;
    status?: string;
    priority?: string;
    mediaType?: string;
    deadline?: string;
    tags?: string[];
  }

  interface HierarchyEdge {
    source: HierarchyNode;
    target: HierarchyNode;
  }

  let rootNode: HierarchyNode | null = null;
  let allNodes: HierarchyNode[] = [];
  let allEdges: HierarchyEdge[] = [];

  const statusColors: Record<string, string> = {
    'in-progress': '#0078D4',
    'review': '#F59E0B',
    'revision': '#EF4444',
    'approved': '#10B981',
    'done': '#10B981',
    'backlog': '#6B7280',
    'on-hold': '#8B5CF6',
    'rejected': '#DC2626'
  };

  const statusLabels: Record<string, string> = {
    'in-progress': 'In Progress',
    'review': 'In Review',
    'revision': 'Revision',
    'approved': 'Approved',
    'done': 'Done',
    'backlog': 'Backlog',
    'on-hold': 'On Hold',
    'rejected': 'Rejected'
  };

  const brandColors: Record<string, string> = {
    SSH: '#022057',
    SS: '#043388',
    SSC: '#0078D4',
    SSW: '#10B981',
    SSE: '#F59E0B',
    SST: '#8B5CF6'
  };

  const brandNames: Record<string, string> = {
    SSH: 'SuamiSihat Holdings',
    SS: 'SuamiSihat',
    SSC: 'SS Clinic',
    SSW: 'SS Wellness',
    SSE: 'SS Enterprise',
    SST: 'SS Tech'
  };

  const mediaIcons: Record<string, string> = {
    'Social Media': 'social',
    'Video': 'video',
    'Brand Identity': 'brand',
    'Graphic / Print': 'print'
  };

  // ─── Build Hierarchy ───
  function emptyBreakdown(): StatusBreakdown {
    return { 'in-progress': 0, 'review': 0, 'revision': 0, 'approved': 0, 'done': 0, 'backlog': 0, 'on-hold': 0, 'rejected': 0 };
  }

  function mergeBreakdown(target: StatusBreakdown, source: StatusBreakdown) {
    for (const key of Object.keys(source)) {
      target[key] = (target[key] || 0) + source[key];
    }
  }

  function buildHierarchy() {
    const w = canvasEl?.width ? canvasEl.width / dpr : 800;
    const h = canvasEl?.height ? canvasEl.height / dpr : 600;
    const cx = w / 2;
    const cy = h / 2;

    // Group: brand → mediaType → projects
    const brandMap: Record<string, Record<string, Project[]>> = {};
    for (const p of projects) {
      const brand = p.brand || 'SS';
      const media = p.presetType || 'Other';
      if (!brandMap[brand]) brandMap[brand] = {};
      if (!brandMap[brand][media]) brandMap[brand][media] = [];
      brandMap[brand][media].push(p);
    }

    // Root node = SSH (SuamiSihat Holdings)
    rootNode = {
      id: 'root-ssh',
      type: 'root',
      label: 'SSH',
      sublabel: 'SuamiSihat Holdings',
      color: '#022057',
      x: cx,
      y: cy,
      radius: 42,
      children: [],
      parent: null,
      projectCount: projects.length,
      statusBreakdown: emptyBreakdown()
    };

    const brandKeys = Object.keys(brandMap);
    const brandOrbitRadius = Math.min(w, h) * 0.22;

    for (let bi = 0; bi < brandKeys.length; bi++) {
      const brand = brandKeys[bi];
      const brandAngle = (bi / brandKeys.length) * Math.PI * 2 - Math.PI / 2;
      const brandX = cx + Math.cos(brandAngle) * brandOrbitRadius;
      const brandY = cy + Math.sin(brandAngle) * brandOrbitRadius;

      const brandBreakdown = emptyBreakdown();
      let brandProjectCount = 0;

      const brandNode: HierarchyNode = {
        id: `brand-${brand}`,
        type: 'brand',
        label: brand,
        sublabel: brandNames[brand] || brand,
        color: brandColors[brand] || '#043388',
        x: brandX,
        y: brandY,
        radius: 30,
        children: [],
        parent: rootNode,
        projectCount: 0,
        statusBreakdown: brandBreakdown
      };

      const mediaTypes = Object.keys(brandMap[brand]);
      const mediaOrbitRadius = Math.min(w, h) * 0.13;

      for (let mi = 0; mi < mediaTypes.length; mi++) {
        const media = mediaTypes[mi];
        const mediaAngle = brandAngle + ((mi - (mediaTypes.length - 1) / 2) / Math.max(1, mediaTypes.length)) * (Math.PI * 0.7);
        const mediaX = brandX + Math.cos(mediaAngle) * mediaOrbitRadius;
        const mediaY = brandY + Math.sin(mediaAngle) * mediaOrbitRadius;

        const mediaBreakdown = emptyBreakdown();
        const mediaProjects = brandMap[brand][media];

        const mediaNode: HierarchyNode = {
          id: `media-${brand}-${media}`,
          type: 'media',
          label: media,
          sublabel: `${mediaProjects.length} project${mediaProjects.length !== 1 ? 's' : ''}`,
          color: brandColors[brand] || '#043388',
          x: mediaX,
          y: mediaY,
          radius: 18,
          children: [],
          parent: brandNode,
          projectCount: mediaProjects.length,
          statusBreakdown: mediaBreakdown
        };

        const projectOrbitRadius = Math.min(w, h) * 0.065;

        for (let pi = 0; pi < mediaProjects.length; pi++) {
          const p = mediaProjects[pi];
          const projectAngle = mediaAngle + ((pi - (mediaProjects.length - 1) / 2) / Math.max(1, mediaProjects.length)) * (Math.PI * 0.5);
          const projectX = mediaX + Math.cos(projectAngle) * projectOrbitRadius;
          const projectY = mediaY + Math.sin(projectAngle) * projectOrbitRadius;

          const status = p.status || 'backlog';

          const projectNode: HierarchyNode = {
            id: p.id || p.jobId,
            type: 'project',
            label: p.jobId,
            sublabel: p.title,
            color: statusColors[status] || '#6B7280',
            x: projectX,
            y: projectY,
            radius: 8,
            children: [],
            parent: mediaNode,
            projectCount: 1,
            statusBreakdown: emptyBreakdown(),
            project: p,
            jobId: p.jobId,
            designer: p.designer || '',
            status,
            priority: p.priority || 'medium',
            mediaType: p.presetType || '',
            deadline: p.deadline || '',
            tags: p.tags || []
          };
          projectNode.statusBreakdown[status] = 1;

          mediaNode.children.push(projectNode);
          mediaBreakdown[status] = (mediaBreakdown[status] || 0) + 1;
        }

        brandNode.children.push(mediaNode);
        mergeBreakdown(brandBreakdown, mediaBreakdown);
        brandProjectCount += mediaProjects.length;
      }

      brandNode.projectCount = brandProjectCount;
      rootNode.children.push(brandNode);
      mergeBreakdown(rootNode.statusBreakdown, brandBreakdown);
    }

    // Flatten all nodes + edges
    allNodes = [];
    allEdges = [];
    function collect(node: HierarchyNode) {
      allNodes.push(node);
      for (const child of node.children) {
        allEdges.push({ source: node, target: child });
        collect(child);
      }
    }
    collect(rootNode);
  }

  // ─── Drawing ───
  function drawStatusRing(ctx: CanvasRenderingContext2D, x: number, y: number, radius: number, breakdown: StatusBreakdown, total: number, lineWidth: number) {
    if (total === 0) return;
    const ringRadius = radius + lineWidth / 2 + 1;
    let startAngle = -Math.PI / 2;

    const order: string[] = ['approved', 'done', 'in-progress', 'review', 'revision', 'on-hold', 'backlog', 'rejected'];
    for (const status of order) {
      const count = breakdown[status] || 0;
      if (count === 0) continue;
      const sweep = (count / total) * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(x, y, ringRadius, startAngle, startAngle + sweep);
      ctx.strokeStyle = statusColors[status] || '#6B7280';
      ctx.lineWidth = lineWidth;
      ctx.lineCap = 'round';
      ctx.stroke();
      startAngle += sweep;
    }
  }

  function drawMediaTypeIcon(ctx: CanvasRenderingContext2D, x: number, y: number, mediaType: string, size: number) {
    ctx.save();
    ctx.translate(x, y);
    const s = size;
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.strokeStyle = 'rgba(255,255,255,0.85)';
    ctx.lineWidth = 1.2;

    const mt = (mediaType || '').toLowerCase();
    if (mt.includes('social')) {
      // Share/network nodes
      const r = s * 0.13;
      ctx.beginPath(); ctx.arc(-s * 0.28, -s * 0.18, r, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(s * 0.28, -s * 0.18, r, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(0, s * 0.25, r, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-s * 0.16, -s * 0.1); ctx.lineTo(s * 0.16, -s * 0.1);
      ctx.moveTo(-s * 0.14, -s * 0.06); ctx.lineTo(-s * 0.04, s * 0.16);
      ctx.moveTo(s * 0.14, -s * 0.06); ctx.lineTo(s * 0.04, s * 0.16);
      ctx.stroke();
    } else if (mt.includes('video')) {
      // Camera icon
      ctx.beginPath();
      ctx.roundRect(-s * 0.32, -s * 0.2, s * 0.44, s * 0.4, s * 0.05);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(s * 0.16, -s * 0.12);
      ctx.lineTo(s * 0.34, -s * 0.2);
      ctx.lineTo(s * 0.34, s * 0.2);
      ctx.lineTo(s * 0.16, s * 0.12);
      ctx.closePath();
      ctx.fill();
    } else if (mt.includes('brand') || mt.includes('identity')) {
      // Pen nib / vector
      ctx.beginPath();
      ctx.moveTo(0, -s * 0.32);
      ctx.lineTo(s * 0.14, -s * 0.06);
      ctx.lineTo(0, s * 0.08);
      ctx.lineTo(-s * 0.14, -s * 0.06);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(0, s * 0.08);
      ctx.lineTo(0, s * 0.32);
      ctx.lineWidth = 1.5;
      ctx.stroke();
    } else {
      // Image/print — landscape icon
      ctx.beginPath();
      ctx.roundRect(-s * 0.3, -s * 0.22, s * 0.6, s * 0.44, s * 0.04);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(-s * 0.12, -s * 0.06, s * 0.07, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-s * 0.3, s * 0.14);
      ctx.lineTo(-s * 0.08, 0);
      ctx.lineTo(s * 0.08, s * 0.1);
      ctx.lineTo(s * 0.2, 0);
      ctx.lineTo(s * 0.3, s * 0.14);
      ctx.lineWidth = 1.2;
      ctx.stroke();
    }
    ctx.restore();
  }

  function draw() {
    if (!canvasEl) return;
    const ctx = canvasEl.getContext('2d');
    if (!ctx) return;

    const w = canvasEl.width / dpr;
    const h = canvasEl.height / dpr;

    ctx.save();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    ctx.save();
    ctx.translate(camX, camY);
    ctx.scale(zoom, zoom);

    // ─── Draw edges (hierarchy links) ───
    for (const edge of allEdges) {
      const isHovered = hoveredNode &&
        (edge.source === hoveredNode || edge.target === hoveredNode ||
         edge.source === hoveredNode?.parent || edge.target.parent === hoveredNode);
      const isDimmed = hoveredNode && !isHovered;

      ctx.beginPath();
      // Curved link
      const mx = (edge.source.x + edge.target.x) / 2;
      const my = (edge.source.y + edge.target.y) / 2;
      ctx.moveTo(edge.source.x, edge.source.y);
      ctx.quadraticCurveTo(mx + (edge.source.y - edge.target.y) * 0.08, my + (edge.target.x - edge.source.x) * 0.08, edge.target.x, edge.target.y);

      if (isHovered) {
        ctx.strokeStyle = 'rgba(33, 161, 247, 0.35)';
        ctx.lineWidth = 1.8;
      } else if (isDimmed) {
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.02)';
        ctx.lineWidth = 0.5;
      } else {
        const alpha = edge.target.type === 'project' ? 0.06 : 0.12;
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
        ctx.lineWidth = edge.target.type === 'project' ? 0.6 : 1;
      }
      ctx.stroke();
    }

    // ─── Draw nodes ───
    for (const node of allNodes) {
      const isHovered = hoveredNode === node;
      const isAncestor = hoveredNode && isAncestorOf(node, hoveredNode);
      const isDescendant = hoveredNode && isAncestorOf(hoveredNode, node);
      const isRelated = isHovered || isAncestor || isDescendant;
      const isDimmed = hoveredNode && !isRelated;

      const alpha = isDimmed ? 0.12 : 1;
      const r = isHovered ? node.radius * 1.2 : node.radius;

      // ─── Glow for hovered ───
      if (isHovered) {
        const grad = ctx.createRadialGradient(node.x, node.y, r, node.x, node.y, r + 20);
        grad.addColorStop(0, `${node.color}30`);
        grad.addColorStop(1, `${node.color}00`);
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 20, 0, Math.PI * 2);
        ctx.fillStyle = grad;
        ctx.fill();
      }

      // ─── Node fill ───
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);

      if (node.type === 'root') {
        // Gradient fill for root
        const grad = ctx.createRadialGradient(node.x - r * 0.2, node.y - r * 0.2, 0, node.x, node.y, r);
        grad.addColorStop(0, alpha < 1 ? '#02205720' : '#043388');
        grad.addColorStop(1, alpha < 1 ? '#02205710' : '#022057');
        ctx.fillStyle = grad;
      } else if (node.type === 'brand') {
        const grad = ctx.createRadialGradient(node.x - r * 0.2, node.y - r * 0.2, 0, node.x, node.y, r);
        grad.addColorStop(0, alpha < 1 ? `${lighten(node.color, 30)}20` : lighten(node.color, 30));
        grad.addColorStop(1, alpha < 1 ? `${node.color}20` : node.color);
        ctx.fillStyle = grad;
      } else if (node.type === 'media') {
        ctx.fillStyle = alpha < 1 ? `${node.color}14` : `${node.color}CC`;
      } else {
        // Project node — filled with status color
        ctx.fillStyle = alpha < 1 ? `${node.color}14` : node.color;
      }
      ctx.fill();

      // ─── Base border ───
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
      ctx.strokeStyle = alpha < 1 ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.15)';
      ctx.lineWidth = 1;
      ctx.stroke();

      // ─── Status percentage ring ───
      if (node.type !== 'project' && alpha >= 1) {
        const ringWidth = node.type === 'root' ? 5 : node.type === 'brand' ? 4 : 3;
        drawStatusRing(ctx, node.x, node.y, r, node.statusBreakdown, node.projectCount, ringWidth);
      }

      // ─── Inner content ───
      if (alpha >= 1) {
        if (node.type === 'root') {
          // SSH logo text
          ctx.font = '800 16px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText('SSH', node.x, node.y - 3);
          ctx.font = '600 8px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.fillStyle = 'rgba(255,255,255,0.6)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + 12);
        } else if (node.type === 'brand') {
          ctx.font = '800 13px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText(node.label, node.x, node.y - 2);
          ctx.font = '600 8px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.fillStyle = 'rgba(255,255,255,0.6)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + 11);
        } else if (node.type === 'media') {
          drawMediaTypeIcon(ctx, node.x, node.y - 1, node.label, node.radius * 0.7);
          ctx.font = '600 7px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = 'rgba(255,255,255,0.5)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + node.radius + 3);
        }
      }

      // ─── External label ───
      if (alpha >= 1) {
        if (node.type === 'brand') {
          ctx.font = '600 9px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = 'rgba(255,255,255,0.5)';
          ctx.fillText(brandNames[node.label] || node.label, node.x, node.y + r + 8);
        } else if (node.type === 'media') {
          ctx.font = '500 8px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = 'rgba(255,255,255,0.35)';
          const shortLabel = node.label.length > 16 ? node.label.substring(0, 14) + '\u2026' : node.label;
          ctx.fillText(shortLabel, node.x, node.y + r + 14);
        } else if (node.type === 'project' && (isHovered || zoom > 1.2)) {
          ctx.font = '500 7px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = 'rgba(255,255,255,0.4)';
          const jid = (node.jobId || '').length > 14 ? (node.jobId || '').substring(0, 12) + '\u2026' : (node.jobId || '');
          ctx.fillText(jid, node.x, node.y + r + 3);
        }
      }
    }

    ctx.restore();
    ctx.restore();
  }

  function isAncestorOf(potentialAncestor: HierarchyNode, node: HierarchyNode): boolean {
    let current: HierarchyNode | null = node.parent;
    while (current) {
      if (current === potentialAncestor) return true;
      current = current.parent;
    }
    return false;
  }

  function lighten(hex: string, amount: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, (num >> 16) + amount);
    const g = Math.min(255, ((num >> 8) & 0x00FF) + amount);
    const b = Math.min(255, (num & 0x0000FF) + amount);
    return `#${(r << 16 | g << 8 | b).toString(16).padStart(6, '0')}`;
  }

  function animate() {
    draw();
    animFrameId = requestAnimationFrame(animate);
  }

  // ─── Interaction ───
  function screenToWorld(sx: number, sy: number): [number, number] {
    return [(sx - camX) / zoom, (sy - camY) / zoom];
  }

  function findNodeAt(wx: number, wy: number): HierarchyNode | null {
    // Reverse: projects first (smallest, on top)
    for (let i = allNodes.length - 1; i >= 0; i--) {
      const n = allNodes[i];
      const dx = wx - n.x;
      const dy = wy - n.y;
      const hitR = n.radius + 4;
      if (dx * dx + dy * dy <= hitR * hitR) return n;
    }
    return null;
  }

  function handleMouseDown(e: MouseEvent) {
    const rect = canvasEl!.getBoundingClientRect();
    const [wx, wy] = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
    const node = findNodeAt(wx, wy);
    if (!node) {
      isPanning = true;
      panStartX = e.clientX - camX;
      panStartY = e.clientY - camY;
    }
  }

  function handleMouseMove(e: MouseEvent) {
    if (!canvasEl) return;
    const rect = canvasEl.getBoundingClientRect();
    const [wx, wy] = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);

    tooltipX = e.clientX - rect.left;
    tooltipY = e.clientY - rect.top;

    if (isPanning) {
      camX = e.clientX - panStartX;
      camY = e.clientY - panStartY;
    } else {
      hoveredNode = findNodeAt(wx, wy);
      canvasEl.style.cursor = hoveredNode ? 'pointer' : 'grab';
    }
  }

  function handleMouseUp() {
    if (!isPanning && hoveredNode) {
      if (hoveredNode.type === 'project' && hoveredNode.project) {
        appState.navigate('project-detail', { id: hoveredNode.id });
      }
    }
    isPanning = false;
  }

  function handleWheel(e: WheelEvent) {
    e.preventDefault();
    const rect = canvasEl!.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const factor = e.deltaY < 0 ? 1.08 : 0.92;
    const newZoom = Math.max(0.3, Math.min(5, zoom * factor));
    camX = mx - ((mx - camX) / zoom) * newZoom;
    camY = my - ((my - camY) / zoom) * newZoom;
    zoom = newZoom;
  }

  function fitView() {
    if (allNodes.length === 0 || !canvasEl) return;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const n of allNodes) {
      minX = Math.min(minX, n.x - n.radius - 30);
      minY = Math.min(minY, n.y - n.radius - 30);
      maxX = Math.max(maxX, n.x + n.radius + 30);
      maxY = Math.max(maxY, n.y + n.radius + 30);
    }
    const gw = maxX - minX;
    const gh = maxY - minY;
    const cw = canvasEl.width / dpr;
    const ch = canvasEl.height / dpr;
    zoom = Math.min(cw / gw, ch / gh, 2) * 0.9;
    camX = (cw - gw * zoom) / 2 - minX * zoom;
    camY = (ch - gh * zoom) / 2 - minY * zoom;
  }

  function resetView() {
    zoom = 1;
    camX = 0;
    camY = 0;
  }

  function resizeCanvas() {
    if (!canvasEl || !containerEl) return;
    dpr = window.devicePixelRatio || 1;
    const cw = containerEl.clientWidth;
    const ch = containerEl.clientHeight;
    canvasEl.width = cw * dpr;
    canvasEl.height = ch * dpr;
    canvasEl.style.width = cw + 'px';
    canvasEl.style.height = ch + 'px';
  }

  onMount(() => {
    resizeCanvas();
    buildHierarchy();
    setTimeout(() => fitView(), 100);
    animate();
    window.addEventListener('resize', () => { resizeCanvas(); buildHierarchy(); });
  });

  onDestroy(() => {
    if (animFrameId) cancelAnimationFrame(animFrameId);
  });

  $effect(() => {
    if (projects && canvasEl) {
      buildHierarchy();
      setTimeout(() => fitView(), 50);
    }
  });

  function formatDeadline(d: string): string {
    if (!d) return '\u2014';
    try {
      return new Date(d).toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });
    } catch { return d; }
  }

  function getStatusPercent(breakdown: StatusBreakdown, total: number, status: string): string {
    if (total === 0) return '0';
    return Math.round(((breakdown[status] || 0) / total) * 100).toString();
  }

  // Computed tooltip data for hovered node
  let tooltipStatusEntries = $derived.by(() => {
    if (!hoveredNode) return [];
    const bd = hoveredNode.statusBreakdown;
    const total = hoveredNode.projectCount;
    if (total === 0) return [];
    return Object.entries(bd)
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1])
      .map(([status, count]) => ({
        status,
        label: statusLabels[status] || status,
        count,
        percent: Math.round((count / total) * 100),
        color: statusColors[status] || '#6B7280'
      }));
  });
</script>

<div class="graph-container" bind:this={containerEl}>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <canvas
    bind:this={canvasEl}
    class="graph-canvas"
    onmousedown={handleMouseDown}
    onmousemove={handleMouseMove}
    onmouseup={handleMouseUp}
    onmouseleave={() => { hoveredNode = null; isPanning = false; }}
    onwheel={handleWheel}
  ></canvas>

  <!-- ─── Rich HTML Tooltip ─── -->
  {#if hoveredNode}
    {@const cw = containerEl?.clientWidth || 800}
    {@const ch = containerEl?.clientHeight || 600}
    <div
      class="graph-tooltip"
      style="left: {Math.min(tooltipX + 18, cw - 310)}px; top: {Math.min(Math.max(tooltipY - 8, 8), ch - 280)}px;"
    >
      <!-- Root / Brand / Media node tooltip -->
      {#if hoveredNode.type !== 'project'}
        <div class="tooltip-header">
          <span class="tooltip-brand-badge" style="background: {hoveredNode.color}">
            {hoveredNode.label}
          </span>
          <span class="tooltip-count">{hoveredNode.projectCount} project{hoveredNode.projectCount !== 1 ? 's' : ''}</span>
        </div>
        <div class="tooltip-title">{hoveredNode.sublabel}</div>

        <!-- Status breakdown bars -->
        {#if tooltipStatusEntries.length > 0}
          <div class="tooltip-status-section">
            <div class="tooltip-section-label">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
              Status Breakdown
            </div>
            {#each tooltipStatusEntries as entry}
              <div class="tooltip-status-bar-row">
                <span class="tooltip-status-dot" style="background: {entry.color}"></span>
                <span class="tooltip-status-label">{entry.label}</span>
                <div class="tooltip-status-bar-track">
                  <div class="tooltip-status-bar-fill" style="width: {entry.percent}%; background: {entry.color}"></div>
                </div>
                <span class="tooltip-status-pct">{entry.percent}%</span>
              </div>
            {/each}
          </div>
        {/if}

        <!-- Children summary -->
        {#if hoveredNode.children.length > 0}
          <div class="tooltip-children-section">
            <div class="tooltip-section-label">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v3A1.5 1.5 0 0 0 2.5 9h3A1.5 1.5 0 0 0 7 7.5v-3A1.5 1.5 0 0 0 5.5 3h-3zm8 0A1.5 1.5 0 0 0 10 4.5v3A1.5 1.5 0 0 0 11.5 9h3A1.5 1.5 0 0 0 16 7.5v-3A1.5 1.5 0 0 0 14.5 3h-3zm-8 8A1.5 1.5 0 0 0 2 12.5v3A1.5 1.5 0 0 0 3.5 17h3a1.5 1.5 0 0 0 1.5-1.5v-3A1.5 1.5 0 0 0 6.5 11h-3zm8 0a1.5 1.5 0 0 0-1.5 1.5v3a1.5 1.5 0 0 0 1.5 1.5h3a1.5 1.5 0 0 0 1.5-1.5v-3a1.5 1.5 0 0 0-1.5-1.5h-3z"/></svg>
              {hoveredNode.type === 'root' ? 'Brands' : hoveredNode.type === 'brand' ? 'Media Types' : 'Projects'}
            </div>
            <div class="tooltip-children-list">
              {#each hoveredNode.children.slice(0, 6) as child}
                <div class="tooltip-child-item">
                  <span class="tooltip-child-dot" style="background: {child.color}"></span>
                  <span class="tooltip-child-name">{child.label}</span>
                  <span class="tooltip-child-count">{child.projectCount}</span>
                </div>
              {/each}
              {#if hoveredNode.children.length > 6}
                <div class="tooltip-child-item tooltip-child-more">+{hoveredNode.children.length - 6} more</div>
              {/if}
            </div>
          </div>
        {/if}

      {:else}
        <!-- Project node tooltip -->
        <div class="tooltip-header">
          <span class="tooltip-brand-badge" style="background: {hoveredNode.parent?.parent?.color || '#043388'}">
            {hoveredNode.parent?.parent?.label || ''}
          </span>
          <span class="tooltip-job-id">{hoveredNode.jobId}</span>
        </div>
        <div class="tooltip-title">{hoveredNode.sublabel}</div>
        <div class="tooltip-meta-grid">
          <div class="tooltip-meta-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8zm-2.5 4a2.5 2.5 0 1 1 5 0 2.5 2.5 0 0 1-5 0zm-3 8a3.5 3.5 0 0 1 3.5-3.5h4a3.5 3.5 0 0 1 3.5 3.5v1.5a1 1 0 0 1-1 1h-9a1 1 0 0 1-1-1V14z"/></svg>
            <span class="tooltip-meta-label">Designer</span>
            <span class="tooltip-meta-value">{hoveredNode.designer || '\u2014'}</span>
          </div>
          <div class="tooltip-meta-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
            <span class="tooltip-meta-label">Status</span>
            <span class="tooltip-meta-value">
              <span class="tooltip-status-dot" style="background: {statusColors[hoveredNode.status || 'backlog'] || '#6B7280'}"></span>
              {statusLabels[hoveredNode.status || 'backlog'] || hoveredNode.status}
            </span>
          </div>
          <div class="tooltip-meta-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13z"/></svg>
            <span class="tooltip-meta-label">Media</span>
            <span class="tooltip-meta-value">{hoveredNode.mediaType || 'General'}</span>
          </div>
          <div class="tooltip-meta-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10.9 1.15a.75.75 0 0 1 .73.88l-1.3 5.47h4.92a.75.75 0 0 1 .59 1.21l-7.5 9.5a.75.75 0 0 1-1.33-.74l1.8-6.47H3.75a.75.75 0 0 1-.6-1.2l7.15-8.5a.75.75 0 0 1 .6-.15z"/></svg>
            <span class="tooltip-meta-label">Priority</span>
            <span class="tooltip-meta-value">{hoveredNode.priority}</span>
          </div>
          {#if hoveredNode.deadline}
            <div class="tooltip-meta-row">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M6 2a.75.75 0 0 1 .75.75V4h6.5v-1.25a.75.75 0 0 1 1.5 0V4h1.75A2.5 2.5 0 0 1 19 6.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 1 15.5v-9A2.5 2.5 0 0 1 3.5 4H5.25V2.75A.75.75 0 0 1 6 2z"/></svg>
              <span class="tooltip-meta-label">Deadline</span>
              <span class="tooltip-meta-value">{formatDeadline(hoveredNode.deadline)}</span>
            </div>
          {/if}
          {#if hoveredNode.tags && hoveredNode.tags.length > 0}
            <div class="tooltip-meta-row tooltip-tags-row">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v4.59a1.5 1.5 0 0 0 .44 1.06l7.5 7.5a1.5 1.5 0 0 0 2.12 0l4.59-4.59a1.5 1.5 0 0 0 0-2.12l-7.5-7.5A1.5 1.5 0 0 0 7.09 3H2.5zM5 6.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z"/></svg>
              <div class="tooltip-tags">
                {#each hoveredNode.tags.slice(0, 3) as tag}
                  <span class="tooltip-tag">{tag}</span>
                {/each}
              </div>
            </div>
          {/if}
        </div>
        <div class="tooltip-footer">
          <span class="tooltip-hint">Click to open project</span>
        </div>
      {/if}
    </div>
  {/if}

  <!-- ─── Graph Controls ─── -->
  <div class="graph-controls">
    <button class="graph-ctrl-btn" onclick={fitView} title="Fit all nodes in view">
      <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M3 3h4a.5.5 0 0 1 0 1H4v3a.5.5 0 0 1-1 0V3.5a.5.5 0 0 1 .5-.5H3zm10 0h3.5a.5.5 0 0 1 .5.5V7a.5.5 0 0 1-1 0V4h-3a.5.5 0 0 1 0-1zM3.5 13a.5.5 0 0 1 .5.5V16h3a.5.5 0 0 1 0 1H3.5a.5.5 0 0 1-.5-.5V13.5a.5.5 0 0 1 .5-.5zM17 13.5v3a.5.5 0 0 1-.5.5H13a.5.5 0 0 1 0-1h3v-2.5a.5.5 0 0 1 1 0z"/></svg>
    </button>
    <button class="graph-ctrl-btn" onclick={resetView} title="Reset zoom">
      <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M10 3a7 7 0 0 0-5.8 3.1l-1.5-1.5A.5.5 0 0 0 2 5v4.5a.5.5 0 0 0 .5.5H7a.5.5 0 0 0 .35-.85L5.8 7.6A5.5 5.5 0 1 1 4.5 10a.75.75 0 0 0-1.5 0A7 7 0 1 0 10 3z"/></svg>
    </button>
    <span class="graph-zoom-label">{Math.round(zoom * 100)}%</span>
  </div>

  <!-- ─── Stats Bar ─── -->
  <div class="graph-stats">
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><circle cx="10" cy="10" r="5"/></svg>
      {projects.length} projects
    </span>
    <span class="graph-stat-divider"></span>
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v3A1.5 1.5 0 0 0 2.5 9h3A1.5 1.5 0 0 0 7 7.5v-3A1.5 1.5 0 0 0 5.5 3h-3z"/></svg>
      {rootNode?.children.length || 0} brands
    </span>
  </div>

  <!-- ─── Legend ─── -->
  <div class="graph-legend">
    <div class="legend-title">
      <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
      How to Read
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M15 4a3 3 0 1 0-2.6 4.5l-5.3 2.65a3 3 0 0 0 0 1.7l5.3 2.65A3 3 0 1 0 15 14z"/></svg>
        Hierarchy: SSH  &rarr;  Brand  &rarr;  Media  &rarr;  Project
      </span>
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><circle cx="10" cy="10" r="6" stroke="currentColor" stroke-width="3" fill="none"/></svg>
        Border Ring = Status %
      </span>
      <div class="legend-items">
        {#each [['in-progress','Active'],['review','Review'],['approved','Done'],['backlog','Backlog'],['on-hold','On Hold']] as [s, label]}
          <span class="legend-swatch"><span class="swatch-ring" style="border-color:{statusColors[s]}"></span>{label}</span>
        {/each}
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13z"/></svg>
        Node Color = Brand
      </span>
      <div class="legend-items">
        {#each Object.entries(brandColors) as [brand, color]}
          <span class="legend-swatch"><span class="swatch-dot" style="background:{color}"></span>{brand}</span>
        {/each}
      </div>
    </div>
    <div class="legend-hint">
      <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16z"/></svg>
      Scroll to zoom / Hover for details / Click project to open
    </div>
  </div>
</div>

<style>
  .graph-container {
    position: relative;
    width: 100%;
    height: calc(100vh - 240px);
    min-height: 500px;
    background: var(--bg-canvas, #0A1128);
    border-radius: var(--radius-lg, 12px);
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.08));
    overflow: hidden;
  }
  .graph-canvas {
    width: 100%;
    height: 100%;
    display: block;
  }

  /* ─── Tooltip ─── */
  .graph-tooltip {
    position: absolute;
    z-index: 100;
    background: var(--surface-card, rgba(15, 26, 58, 0.95));
    backdrop-filter: blur(16px);
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 12px);
    padding: 14px 16px 12px;
    min-width: 240px;
    max-width: 300px;
    pointer-events: none;
    box-shadow: var(--shadow-xl, 0 20px 28px -5px rgba(0,0,0,0.4));
    animation: ttFadeIn 0.12s ease-out;
  }
  @keyframes ttFadeIn {
    from { opacity: 0; transform: translateY(4px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .tooltip-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }
  .tooltip-brand-badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 8px;
    border-radius: var(--radius-pill, 9999px);
    font-size: 10px;
    font-weight: 800;
    color: #FFFFFF;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .tooltip-count {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
  }
  .tooltip-job-id {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    font-family: var(--font-mono, 'Cascadia Code', monospace);
  }
  .tooltip-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary, #F1F5F9);
    line-height: 1.35;
    margin-bottom: 10px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .tooltip-section-label {
    font-size: 9.5px;
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.35));
    text-transform: uppercase;
    letter-spacing: 0.4px;
    margin-bottom: 6px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .tooltip-icon {
    width: 12px;
    height: 12px;
    min-width: 12px;
    color: var(--text-tertiary, rgba(255,255,255,0.35));
  }

  /* Status breakdown bars */
  .tooltip-status-section {
    margin-bottom: 10px;
  }
  .tooltip-status-bar-row {
    display: flex;
    align-items: center;
    gap: 5px;
    margin-bottom: 3px;
    font-size: 10.5px;
  }
  .tooltip-status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    display: inline-block;
    flex-shrink: 0;
  }
  .tooltip-status-label {
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.6));
    min-width: 68px;
  }
  .tooltip-status-bar-track {
    flex: 1;
    height: 4px;
    background: rgba(255,255,255,0.06);
    border-radius: 2px;
    overflow: hidden;
  }
  .tooltip-status-bar-fill {
    height: 100%;
    border-radius: 2px;
    transition: width 0.2s ease;
  }
  .tooltip-status-pct {
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    min-width: 28px;
    text-align: right;
    font-family: var(--font-mono, monospace);
    font-size: 10px;
  }

  /* Children list */
  .tooltip-children-section {
    margin-bottom: 4px;
  }
  .tooltip-children-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .tooltip-child-item {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 10.5px;
    padding: 2px 0;
  }
  .tooltip-child-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .tooltip-child-name {
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.6));
    flex: 1;
  }
  .tooltip-child-count {
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    font-family: var(--font-mono, monospace);
    font-size: 10px;
  }
  .tooltip-child-more {
    color: var(--text-tertiary, rgba(255,255,255,0.3));
    font-style: italic;
    font-size: 10px;
  }

  /* Project tooltip meta */
  .tooltip-meta-grid {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .tooltip-meta-row {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
  }
  .tooltip-meta-label {
    font-weight: 600;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    min-width: 55px;
  }
  .tooltip-meta-value {
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.7));
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .tooltip-tags-row { margin-top: 2px; align-items: flex-start; }
  .tooltip-tags { display: flex; flex-wrap: wrap; gap: 3px; }
  .tooltip-tag {
    display: inline-block;
    padding: 1px 6px;
    border-radius: var(--radius-pill, 9999px);
    font-size: 9.5px;
    font-weight: 600;
    background: var(--brand-tint, rgba(33, 161, 247, 0.1));
    color: var(--brand-accent, #21A1F7);
  }
  .tooltip-footer {
    margin-top: 8px;
    padding-top: 7px;
    border-top: 1px solid var(--surface-card-border, rgba(255,255,255,0.08));
  }
  .tooltip-hint {
    font-size: 10px;
    font-weight: 500;
    color: var(--text-tertiary, rgba(255,255,255,0.3));
    font-style: italic;
  }

  /* ─── Controls ─── */
  .graph-controls {
    position: absolute;
    top: 12px;
    right: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
    background: var(--glass-bg, rgba(15, 26, 58, 0.85));
    backdrop-filter: var(--glass-blur, blur(12px));
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.1));
    border-radius: var(--radius-md, 8px);
    padding: 4px;
  }
  .graph-ctrl-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: none;
    border-radius: var(--radius-sm, 4px);
    background: transparent;
    color: var(--text-secondary, rgba(255,255,255,0.5));
    cursor: pointer;
    transition: all var(--transition-fast, 0.15s ease);
  }
  .graph-ctrl-btn:hover {
    background: var(--sidebar-active-bg, rgba(255,255,255,0.1));
    color: var(--text-primary, #F1F5F9);
  }
  .graph-zoom-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.35));
    padding: 0 6px;
    min-width: 36px;
    text-align: center;
    font-family: var(--font-mono, monospace);
  }

  /* ─── Stats ─── */
  .graph-stats {
    position: absolute;
    top: 12px;
    left: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--glass-bg, rgba(15, 26, 58, 0.85));
    backdrop-filter: var(--glass-blur, blur(12px));
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.1));
    border-radius: var(--radius-md, 8px);
    padding: 6px 12px;
    pointer-events: none;
  }
  .graph-stat-item {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10.5px;
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.5));
  }
  .graph-stat-item svg { color: var(--brand-accent, #21A1F7); }
  .graph-stat-divider {
    width: 1px;
    height: 12px;
    background: var(--surface-card-border, rgba(255,255,255,0.1));
  }

  /* ─── Legend ─── */
  .graph-legend {
    position: absolute;
    bottom: 16px;
    left: 16px;
    background: var(--glass-bg, rgba(15, 26, 58, 0.88));
    backdrop-filter: var(--glass-blur, blur(12px));
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.1));
    border-radius: var(--radius-lg, 10px);
    padding: 12px 16px;
    max-width: 360px;
    pointer-events: none;
  }
  .legend-title {
    font-size: 11px;
    font-weight: 800;
    color: var(--text-secondary, rgba(255,255,255,0.6));
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .legend-title svg { color: var(--brand-accent, #21A1F7); }
  .legend-section { margin-bottom: 6px; }
  .legend-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    display: flex;
    align-items: center;
    gap: 4px;
    margin-bottom: 3px;
  }
  .legend-label svg { color: var(--text-tertiary, rgba(255,255,255,0.35)); }
  .legend-items { display: flex; flex-wrap: wrap; gap: 6px; }
  .legend-swatch {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.55));
  }
  .swatch-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }
  .swatch-ring {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
    border: 2px solid;
    background: transparent;
  }
  .legend-hint {
    font-size: 9.5px;
    color: var(--text-tertiary, rgba(255,255,255,0.3));
    margin-top: 8px;
    font-style: italic;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .legend-hint svg { color: var(--text-tertiary, rgba(255,255,255,0.25)); }
</style>

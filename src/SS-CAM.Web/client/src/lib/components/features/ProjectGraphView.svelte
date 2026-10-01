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

  // ─── Camera / Pan / Zoom State ───
  let camX = 0;
  let camY = 0;
  let zoom = 1;
  let isPanning = false;
  let panStartX = 0;
  let panStartY = 0;

  // ─── Dragging State (Interactive Physics) ───
  let draggedNode: HierarchyNode | null = null;
  let isDragging = false;
  let dragMoved = false;
  let dragStartScreenX = 0;
  let dragStartScreenY = 0;

  // ─── Obsidian-Inspired Controls & Forces State ───
  let showSettingsPanel = $state(false);
  let showLegend = $state(true);

  // Filters
  let searchQuery = $state('');
  let selectedBrand = $state('ALL');
  let showCrossLinks = $state(true);

  // Display
  let showArrows = $state(true);
  let textFadeThreshold = $state(0.20);
  let nodeSizeScale = $state(1.30);
  let linkThickness = $state(0.70);

  // Forces (Obsidian Default Calibration)
  let centerForce = $state(0.45);
  let repelForce = $state(11.50);
  let linkForce = $state(0.80);
  let linkDistance = $state(115);

  // Simulation activity tracker
  let simulationAlpha = 1.0; // 1.0 = fully dynamic, settles to ~0.01 with micro-drift
  let lastTime = 0;

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
    vx: number;
    vy: number;
    fx: number;
    fy: number;
    mass: number;
    baseRadius: number;
    radius: number;
    isPinned: boolean;
    children: HierarchyNode[];
    parent: HierarchyNode | null;
    projectCount: number;
    statusBreakdown: StatusBreakdown;
    // Project-specific fields
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
    type: 'hierarchy' | 'crosslink';
    reason?: string;
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
    SSH: 'SuamiSihat Holding',
    SS: 'SuamiSihat',
    SSC: 'SS Clinic',
    SSW: 'SS Wellness',
    SSE: 'SS Enterprise',
    SST: 'SS Tech'
  };

  function emptyBreakdown(): StatusBreakdown {
    return { 'in-progress': 0, 'review': 0, 'revision': 0, 'approved': 0, 'done': 0, 'backlog': 0, 'on-hold': 0, 'rejected': 0 };
  }

  function mergeBreakdown(target: StatusBreakdown, source: StatusBreakdown) {
    for (const key of Object.keys(source)) {
      target[key] = (target[key] || 0) + source[key];
    }
  }

  // ─── Build Graph Hierarchy & Cross-Links ───
  function buildHierarchy() {
    const w = canvasEl?.width ? canvasEl.width / dpr : 900;
    const h = canvasEl?.height ? canvasEl.height / dpr : 650;
    const cx = w / 2;
    const cy = h / 2;

    // Filter projects based on search and brand
    const query = searchQuery.trim().toLowerCase();
    const filteredProjects = projects.filter(p => {
      if (selectedBrand !== 'ALL' && (p.brand || 'SS') !== selectedBrand) return false;
      if (!query) return true;
      const matchTitle = (p.title || '').toLowerCase().includes(query);
      const matchJob = (p.jobId || '').toLowerCase().includes(query);
      const matchDesigner = (p.designer || '').toLowerCase().includes(query);
      const matchTags = (p.tags || []).some(t => t.toLowerCase().includes(query));
      const matchMedia = (p.presetType || '').toLowerCase().includes(query);
      return matchTitle || matchJob || matchDesigner || matchTags || matchMedia;
    });

    // Group: brand -> mediaType -> projects
    const brandMap: Record<string, Record<string, Project[]>> = {};
    for (const p of filteredProjects) {
      const brand = p.brand || 'SS';
      const media = p.presetType || 'Other';
      if (!brandMap[brand]) brandMap[brand] = {};
      if (!brandMap[brand][media]) brandMap[brand][media] = [];
      brandMap[brand][media].push(p);
    }

    // 1. Root Node = SSH (SuamiSihat Holding)
    rootNode = {
      id: 'root-ssh',
      type: 'root',
      label: 'SSH',
      sublabel: 'SuamiSihat Holding',
      color: '#022057',
      x: cx,
      y: cy,
      vx: 0,
      vy: 0,
      fx: 0,
      fy: 0,
      mass: 8.0,
      baseRadius: 40,
      radius: 40 * nodeSizeScale,
      isPinned: false,
      children: [],
      parent: null,
      projectCount: filteredProjects.length,
      statusBreakdown: emptyBreakdown()
    };

    const brandKeys = Object.keys(brandMap);
    const brandOrbitRadius = Math.min(w, h) * 0.23;

    for (let bi = 0; bi < brandKeys.length; bi++) {
      const brand = brandKeys[bi];
      const brandAngle = (bi / Math.max(1, brandKeys.length)) * Math.PI * 2 - Math.PI / 2;
      const brandX = cx + Math.cos(brandAngle) * brandOrbitRadius + (Math.random() - 0.5) * 20;
      const brandY = cy + Math.sin(brandAngle) * brandOrbitRadius + (Math.random() - 0.5) * 20;

      const brandBreakdown = emptyBreakdown();
      let brandProjectCount = 0;

      // 2. Brand Subsidiaries
      const brandNode: HierarchyNode = {
        id: `brand-${brand}`,
        type: 'brand',
        label: brand,
        sublabel: brandNames[brand] || brand,
        color: brandColors[brand] || '#043388',
        x: brandX,
        y: brandY,
        vx: 0,
        vy: 0,
        fx: 0,
        fy: 0,
        mass: 4.5,
        baseRadius: 28,
        radius: 28 * nodeSizeScale,
        isPinned: false,
        children: [],
        parent: rootNode,
        projectCount: 0,
        statusBreakdown: brandBreakdown
      };

      const mediaTypes = Object.keys(brandMap[brand]);
      const mediaOrbitRadius = Math.min(w, h) * 0.14;

      for (let mi = 0; mi < mediaTypes.length; mi++) {
        const media = mediaTypes[mi];
        const mediaAngle = brandAngle + ((mi - (mediaTypes.length - 1) / 2) / Math.max(1, mediaTypes.length)) * (Math.PI * 0.7);
        const mediaX = brandX + Math.cos(mediaAngle) * mediaOrbitRadius + (Math.random() - 0.5) * 15;
        const mediaY = brandY + Math.sin(mediaAngle) * mediaOrbitRadius + (Math.random() - 0.5) * 15;

        const mediaBreakdown = emptyBreakdown();
        const mediaProjects = brandMap[brand][media];

        // 3. Media Types
        const mediaNode: HierarchyNode = {
          id: `media-${brand}-${media}`,
          type: 'media',
          label: media,
          sublabel: `${mediaProjects.length} project${mediaProjects.length !== 1 ? 's' : ''}`,
          color: brandColors[brand] || '#043388',
          x: mediaX,
          y: mediaY,
          vx: 0,
          vy: 0,
          fx: 0,
          fy: 0,
          mass: 2.5,
          baseRadius: 18,
          radius: 18 * nodeSizeScale,
          isPinned: false,
          children: [],
          parent: brandNode,
          projectCount: mediaProjects.length,
          statusBreakdown: mediaBreakdown
        };

        const projectOrbitRadius = Math.min(w, h) * 0.08;

        for (let pi = 0; pi < mediaProjects.length; pi++) {
          const p = mediaProjects[pi];
          const projectAngle = mediaAngle + ((pi - (mediaProjects.length - 1) / 2) / Math.max(1, mediaProjects.length)) * (Math.PI * 0.6);
          const projectX = mediaX + Math.cos(projectAngle) * projectOrbitRadius + (Math.random() - 0.5) * 10;
          const projectY = mediaY + Math.sin(projectAngle) * projectOrbitRadius + (Math.random() - 0.5) * 10;

          const status = p.status || 'backlog';

          // 4. Projects (Leaf Files)
          const projectNode: HierarchyNode = {
            id: p.id || p.jobId,
            type: 'project',
            label: p.jobId,
            sublabel: p.title,
            color: statusColors[status] || '#6B7280',
            x: projectX,
            y: projectY,
            vx: 0,
            vy: 0,
            fx: 0,
            fy: 0,
            mass: 1.0,
            baseRadius: 9,
            radius: 9 * nodeSizeScale,
            isPinned: false,
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

    // Flatten all nodes & primary hierarchy edges
    allNodes = [];
    allEdges = [];
    function collect(node: HierarchyNode) {
      allNodes.push(node);
      for (const child of node.children) {
        allEdges.push({ source: node, target: child, type: 'hierarchy' });
        collect(child);
      }
    }
    collect(rootNode);

    // 5. Cross-Links (Obsidian-Style File Linking: Shared Tags or Same Designer)
    const projectNodes = allNodes.filter(n => n.type === 'project');
    const crossLinkSet = new Set<string>();

    for (let i = 0; i < projectNodes.length; i++) {
      const a = projectNodes[i];
      let linksForA = 0;
      for (let j = i + 1; j < projectNodes.length; j++) {
        if (linksForA >= 2) break; // Keep graph clean & readable
        const b = projectNodes[j];
        if (a.parent === b.parent) continue; // Skip siblings in same media cluster

        // Check shared tags
        const commonTags = (a.tags || []).filter(t => (b.tags || []).includes(t));
        if (commonTags.length > 0) {
          const key = `${a.id}--${b.id}`;
          if (!crossLinkSet.has(key)) {
            crossLinkSet.add(key);
            allEdges.push({
              source: a,
              target: b,
              type: 'crosslink',
              reason: `Tag #${commonTags[0]}`
            });
            linksForA++;
          }
        }
      }
    }

    simulationAlpha = 1.0;
  }

  // ─── Force-Directed Physics Simulation (Obsidian-Inspired Engine) ───
  function stepPhysics() {
    if (!canvasEl) return;
    const w = canvasEl.width / dpr;
    const h = canvasEl.height / dpr;
    const cx = w / 2;
    const cy = h / 2;

    const dt = 1.0;
    const activeNodes = allNodes;

    // Reset forces
    for (const node of activeNodes) {
      node.fx = 0;
      node.fy = 0;
      node.radius = node.baseRadius * nodeSizeScale;
    }

    // 1. Center Gravity Force
    const cForce = centerForce * 0.00045;
    for (const node of activeNodes) {
      const dx = cx - node.x;
      const dy = cy - node.y;
      node.fx += dx * cForce * node.mass;
      node.fy += dy * cForce * node.mass;
    }

    // 2. Repel Force (Coulomb Repulsion)
    const rForce = repelForce * 650;
    const len = activeNodes.length;
    for (let i = 0; i < len; i++) {
      const ni = activeNodes[i];
      for (let j = i + 1; j < len; j++) {
        const nj = activeNodes[j];
        const dx = ni.x - nj.x;
        const dy = ni.y - nj.y;
        const distSq = dx * dx + dy * dy;
        const minDist = (ni.radius + nj.radius) * 1.35;
        const dist = Math.sqrt(distSq) || 0.1;

        if (dist < 450) {
          const rep = (rForce * (ni.mass * nj.mass)) / (distSq + 300);
          const fx = (dx / dist) * rep;
          const fy = (dy / dist) * rep;
          ni.fx += fx;
          ni.fy += fy;
          nj.fx -= fx;
          nj.fy -= fy;
        }

        // Hard collision push to prevent circle overlapping
        if (dist < minDist) {
          const overlap = minDist - dist;
          const push = overlap * 0.45;
          const px = (dx / dist) * push;
          const py = (dy / dist) * push;
          if (!ni.isPinned) { ni.x += px; ni.y += py; }
          if (!nj.isPinned) { nj.x -= px; nj.y -= py; }
        }
      }
    }

    // 3. Link Spring Force (Hooke's Law)
    const activeEdges = showCrossLinks ? allEdges : allEdges.filter(e => e.type === 'hierarchy');
    const sStrength = linkForce * 0.04;

    for (const edge of activeEdges) {
      const s = edge.source;
      const t = edge.target;
      const dx = t.x - s.x;
      const dy = t.y - s.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 0.1;

      let targetDist = linkDistance;
      if (edge.type === 'crosslink') {
        targetDist = linkDistance * 1.4;
      } else if (s.type === 'root') {
        targetDist = linkDistance * 1.5;
      } else if (s.type === 'brand') {
        targetDist = linkDistance * 1.0;
      } else {
        targetDist = linkDistance * 0.55;
      }

      const displacement = dist - targetDist;
      const spring = displacement * sStrength;
      const fx = (dx / dist) * spring;
      const fy = (dy / dist) * spring;

      if (!t.isPinned) {
        t.fx -= fx;
        t.fy -= fy;
      }
      if (!s.isPinned) {
        s.fx += fx;
        s.fy += fy;
      }
    }

    // 4. Subtle Ambient Living Drift (Cosmic Breathing when Idle)
    const time = performance.now() * 0.001;
    for (let i = 0; i < activeNodes.length; i++) {
      const node = activeNodes[i];
      if (node.isPinned || node.type === 'root') continue;
      const drift = 0.035 * Math.sin(time * 1.2 + i * 0.7);
      node.fx += Math.cos(time + i) * drift;
      node.fy += Math.sin(time + i) * drift;
    }

    // 5. Velocity Integration & Damping
    const damping = isDragging ? 0.90 : 0.86;
    for (const node of activeNodes) {
      if (node.isPinned) {
        node.vx = 0;
        node.vy = 0;
        continue;
      }
      node.vx = (node.vx + (node.fx / node.mass) * dt) * damping;
      node.vy = (node.vy + (node.fy / node.mass) * dt) * damping;

      // Speed clamp
      const speed = Math.sqrt(node.vx * node.vx + node.vy * node.vy);
      if (speed > 18) {
        node.vx = (node.vx / speed) * 18;
        node.vy = (node.vy / speed) * 18;
      }

      node.x += node.vx;
      node.y += node.vy;
    }
  }

  // ─── Trigger Animate Pulse (Obsidian-Style Kinetic Replay) ───
  function triggerAnimatePulse() {
    if (!canvasEl) return;
    const w = canvasEl.width / dpr;
    const h = canvasEl.height / dpr;
    const cx = w / 2;
    const cy = h / 2;

    for (const node of allNodes) {
      if (node.type === 'root') continue;
      const angle = Math.atan2(node.y - cy, node.x - cx) + (Math.random() - 0.5) * 0.8;
      const impulse = (Math.random() * 10 + 6) / Math.sqrt(node.mass);
      node.vx += Math.cos(angle) * impulse;
      node.vy += Math.sin(angle) * impulse;
    }
    simulationAlpha = 1.0;
  }

  function resetForces() {
    centerForce = 0.45;
    repelForce = 11.50;
    linkForce = 0.80;
    linkDistance = 115;
    nodeSizeScale = 1.30;
    linkThickness = 0.70;
    textFadeThreshold = 0.20;
    triggerAnimatePulse();
  }

  // ─── Drawing ───
  function drawStatusRing(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    radius: number,
    breakdown: StatusBreakdown,
    total: number,
    lineWidth: number
  ) {
    if (total === 0) return;
    const ringRadius = radius + lineWidth / 2 + 1.5;
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

  function drawArrowhead(ctx: CanvasRenderingContext2D, fromX: number, fromY: number, toX: number, toY: number, targetRadius: number, size: number) {
    const angle = Math.atan2(toY - fromY, toX - fromX);
    // Place tip right outside node circle
    const tipX = toX - Math.cos(angle) * (targetRadius + 2.5);
    const tipY = toY - Math.sin(angle) * (targetRadius + 2.5);

    ctx.save();
    ctx.translate(tipX, tipY);
    ctx.rotate(angle);
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(-size, -size * 0.45);
    ctx.lineTo(-size * 0.7, 0);
    ctx.lineTo(-size, size * 0.45);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawMediaTypeIcon(ctx: CanvasRenderingContext2D, x: number, y: number, mediaType: string, size: number) {
    ctx.save();
    ctx.translate(x, y);
    const s = size;
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.strokeStyle = 'rgba(255,255,255,0.9)';
    ctx.lineWidth = 1.2;

    const mt = (mediaType || '').toLowerCase();
    if (mt.includes('social')) {
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
      ctx.lineWidth = 1.4;
      ctx.stroke();
    } else {
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

  function isConnected(a: HierarchyNode, b: HierarchyNode): boolean {
    if (a === b) return true;
    if (a.parent === b || b.parent === a) return true;
    for (const edge of allEdges) {
      if ((edge.source === a && edge.target === b) || (edge.source === b && edge.target === a)) return true;
    }
    return false;
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

    const activeEdges = showCrossLinks ? allEdges : allEdges.filter(e => e.type === 'hierarchy');

    // ─── 1. Draw Links / Edges ───
    for (const edge of activeEdges) {
      const isCross = edge.type === 'crosslink';
      const isDirectlyConnected = hoveredNode && (edge.source === hoveredNode || edge.target === hoveredNode);
      const isClusterConnected = hoveredNode && (
        isConnected(edge.source, hoveredNode) && isConnected(edge.target, hoveredNode)
      );
      const isHighlighted = isDirectlyConnected || isClusterConnected;
      const isDimmed = hoveredNode && !isHighlighted;

      ctx.save();
      ctx.beginPath();

      if (isCross) {
        // Cross-file link: subtle curved dashed line
        ctx.setLineDash([4, 4]);
        const mx = (edge.source.x + edge.target.x) / 2;
        const my = (edge.source.y + edge.target.y) / 2;
        ctx.moveTo(edge.source.x, edge.source.y);
        ctx.quadraticCurveTo(mx + (edge.source.y - edge.target.y) * 0.12, my + (edge.target.x - edge.source.x) * 0.12, edge.target.x, edge.target.y);

        if (isHighlighted) {
          ctx.strokeStyle = '#21A1F7';
          ctx.lineWidth = 1.8 * linkThickness;
          ctx.fillStyle = '#21A1F7';
        } else if (isDimmed) {
          ctx.strokeStyle = 'rgba(33, 161, 247, 0.03)';
          ctx.lineWidth = 0.5 * linkThickness;
          ctx.fillStyle = 'rgba(33, 161, 247, 0.03)';
        } else {
          ctx.strokeStyle = 'rgba(33, 161, 247, 0.22)';
          ctx.lineWidth = 0.8 * linkThickness;
          ctx.fillStyle = 'rgba(33, 161, 247, 0.22)';
        }
      } else {
        // Hierarchy link: clean direct line
        ctx.moveTo(edge.source.x, edge.source.y);
        ctx.lineTo(edge.target.x, edge.target.y);

        if (isHighlighted) {
          ctx.strokeStyle = '#38BDF8';
          ctx.lineWidth = 2.0 * linkThickness;
          ctx.fillStyle = '#38BDF8';
        } else if (isDimmed) {
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.02)';
          ctx.lineWidth = 0.4 * linkThickness;
          ctx.fillStyle = 'rgba(255, 255, 255, 0.02)';
        } else {
          const alpha = edge.target.type === 'project' ? 0.09 : edge.source.type === 'root' ? 0.28 : 0.18;
          ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
          ctx.lineWidth = (edge.target.type === 'project' ? 0.8 : 1.3) * linkThickness;
          ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
        }
      }

      ctx.stroke();

      // Draw arrowhead if enabled and not dimmed
      if (showArrows && !isDimmed) {
        const arrowSize = 6 * linkThickness;
        drawArrowhead(ctx, edge.source.x, edge.source.y, edge.target.x, edge.target.y, edge.target.radius, arrowSize);
      }

      ctx.restore();
    }

    // ─── 2. Draw Nodes ───
    for (const node of allNodes) {
      const isHovered = hoveredNode === node;
      const isNeighbor = hoveredNode && isConnected(node, hoveredNode);
      const isDimmed = hoveredNode && !isHovered && !isNeighbor;

      const alpha = isDimmed ? 0.12 : 1;
      const r = isHovered ? node.radius * 1.18 : node.radius;

      // Glow on hovered
      if (isHovered) {
        const grad = ctx.createRadialGradient(node.x, node.y, r, node.x, node.y, r + 24);
        grad.addColorStop(0, `${node.color}45`);
        grad.addColorStop(1, `${node.color}00`);
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 24, 0, Math.PI * 2);
        ctx.fillStyle = grad;
        ctx.fill();
      }

      // Base circle fill
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);

      if (node.type === 'root') {
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
        ctx.fillStyle = alpha < 1 ? `${node.color}14` : `${node.color}DD`;
      } else {
        // Project node: filled with status color
        ctx.fillStyle = alpha < 1 ? `${node.color}14` : node.color;
      }
      ctx.fill();

      // Border outline
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
      ctx.strokeStyle = alpha < 1 ? 'rgba(255,255,255,0.04)' : isHovered ? '#38BDF8' : 'rgba(255,255,255,0.2)';
      ctx.lineWidth = isHovered ? 2 : 1;
      ctx.stroke();

      // ─── Status Percentage Ring (Arcs) ───
      if (node.type !== 'project' && alpha >= 1) {
        const ringWidth = node.type === 'root' ? 5 : node.type === 'brand' ? 4 : 3;
        drawStatusRing(ctx, node.x, node.y, r, node.statusBreakdown, node.projectCount, ringWidth);
      }

      // ─── Inner Glyphs / Icons ───
      if (alpha >= 1) {
        if (node.type === 'root') {
          ctx.font = '800 15px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText('SSH', node.x, node.y - 3);
          ctx.font = '600 8.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.fillStyle = 'rgba(255,255,255,0.65)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + 12);
        } else if (node.type === 'brand') {
          ctx.font = '800 12.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText(node.label, node.x, node.y - 2);
          ctx.font = '600 8px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.fillStyle = 'rgba(255,255,255,0.65)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + 11);
        } else if (node.type === 'media') {
          drawMediaTypeIcon(ctx, node.x, node.y - 2, node.label, node.radius * 0.7);
          ctx.font = '600 7.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = 'rgba(255,255,255,0.55)';
          ctx.fillText(`${node.projectCount}`, node.x, node.y + node.radius + 3);
        }
      }

      // ─── Labels (Controlled by textFadeThreshold & Zoom) ───
      const shouldShowLabel = isHovered || isNeighbor || zoom >= textFadeThreshold;
      if (alpha >= 1 && shouldShowLabel) {
        if (node.type === 'brand') {
          ctx.font = '600 9.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = isHovered ? '#FFFFFF' : 'rgba(255,255,255,0.65)';
          ctx.fillText(brandNames[node.label] || node.label, node.x, node.y + r + 8);
        } else if (node.type === 'media') {
          ctx.font = '500 8.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = isHovered ? '#FFFFFF' : 'rgba(255,255,255,0.45)';
          const shortLabel = node.label.length > 16 ? node.label.substring(0, 14) + '\u2026' : node.label;
          ctx.fillText(shortLabel, node.x, node.y + r + 14);
        } else if (node.type === 'project' && (isHovered || isNeighbor || zoom > 0.8)) {
          ctx.font = '500 7.5px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = isHovered ? '#FFFFFF' : isNeighbor ? 'rgba(56, 189, 248, 0.85)' : 'rgba(255,255,255,0.4)';
          const jid = (node.jobId || '').length > 14 ? (node.jobId || '').substring(0, 12) + '\u2026' : (node.jobId || '');
          ctx.fillText(jid, node.x, node.y + r + 3);
        }
      }
    }

    ctx.restore();
    ctx.restore();
  }

  function lighten(hex: string, amount: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, (num >> 16) + amount);
    const g = Math.min(255, ((num >> 8) & 0x00FF) + amount);
    const b = Math.min(255, (num & 0x0000FF) + amount);
    return `#${(r << 16 | g << 8 | b).toString(16).padStart(6, '0')}`;
  }

  function animate() {
    stepPhysics();
    draw();
    animFrameId = requestAnimationFrame(animate);
  }

  // ─── Interaction & Physics Dragging ───
  function screenToWorld(sx: number, sy: number): [number, number] {
    return [(sx - camX) / zoom, (sy - camY) / zoom];
  }

  function findNodeAt(wx: number, wy: number): HierarchyNode | null {
    // Reverse order: project nodes on top
    for (let i = allNodes.length - 1; i >= 0; i--) {
      const n = allNodes[i];
      const dx = wx - n.x;
      const dy = wy - n.y;
      const hitR = n.radius + 6;
      if (dx * dx + dy * dy <= hitR * hitR) return n;
    }
    return null;
  }

  function handleMouseDown(e: MouseEvent) {
    if (!canvasEl) return;
    const rect = canvasEl.getBoundingClientRect();
    const [wx, wy] = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
    const node = findNodeAt(wx, wy);

    dragStartScreenX = e.clientX;
    dragStartScreenY = e.clientY;
    dragMoved = false;

    if (node) {
      // Pick up node with physics spring
      draggedNode = node;
      node.isPinned = true;
      isDragging = true;
      simulationAlpha = 1.0;
    } else {
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

    const moveDist = Math.hypot(e.clientX - dragStartScreenX, e.clientY - dragStartScreenY);
    if (moveDist > 4) dragMoved = true;

    if (draggedNode) {
      draggedNode.x = wx;
      draggedNode.y = wy;
      draggedNode.vx = 0;
      draggedNode.vy = 0;
      canvasEl.style.cursor = 'grabbing';
    } else if (isPanning) {
      camX = e.clientX - panStartX;
      camY = e.clientY - panStartY;
      canvasEl.style.cursor = 'move';
    } else {
      hoveredNode = findNodeAt(wx, wy);
      canvasEl.style.cursor = hoveredNode ? 'pointer' : 'default';
    }
  }

  function handleMouseUp() {
    if (draggedNode) {
      if (!dragMoved && draggedNode.type === 'project' && draggedNode.project) {
        // Quick click -> open project detail
        appState.navigate('project-detail', { id: draggedNode.id });
      }
      draggedNode.isPinned = false;
      draggedNode = null;
    }
    isDragging = false;
    isPanning = false;
    if (canvasEl) {
      canvasEl.style.cursor = hoveredNode ? 'pointer' : 'default';
    }
  }

  function handleWheel(e: WheelEvent) {
    e.preventDefault();
    if (!canvasEl) return;
    const rect = canvasEl.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    const factor = e.deltaY < 0 ? 1.08 : 0.92;
    const newZoom = Math.max(0.2, Math.min(6, zoom * factor));
    camX = mx - ((mx - camX) / zoom) * newZoom;
    camY = my - ((my - camY) / zoom) * newZoom;
    zoom = newZoom;
  }

  function fitView() {
    if (allNodes.length === 0 || !canvasEl) return;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const n of allNodes) {
      minX = Math.min(minX, n.x - n.radius - 40);
      minY = Math.min(minY, n.y - n.radius - 40);
      maxX = Math.max(maxX, n.x + n.radius + 40);
      maxY = Math.max(maxY, n.y + n.radius + 40);
    }
    const gw = maxX - minX || 1;
    const gh = maxY - minY || 1;
    const cw = canvasEl.width / dpr;
    const ch = canvasEl.height / dpr;
    zoom = Math.min(cw / gw, ch / gh, 2.5) * 0.88;
    camX = (cw - gw * zoom) / 2 - minX * zoom;
    camY = (ch - gh * zoom) / 2 - minY * zoom;
  }

  function resetView() {
    zoom = 1;
    camX = 0;
    camY = 0;
    fitView();
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
    setTimeout(() => fitView(), 120);
    animate();
    window.addEventListener('resize', () => { resizeCanvas(); });
  });

  onDestroy(() => {
    if (animFrameId) cancelAnimationFrame(animFrameId);
  });

  $effect(() => {
    if (projects && canvasEl) {
      buildHierarchy();
      setTimeout(() => fitView(), 60);
    }
  });

  function formatDeadline(d: string): string {
    if (!d) return '\u2014';
    try {
      return new Date(d).toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });
    } catch { return d; }
  }

  // Computed tooltip data
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
    onmouseleave={() => { hoveredNode = null; isPanning = false; if (draggedNode) { draggedNode.isPinned = false; draggedNode = null; } }}
    onwheel={handleWheel}
  ></canvas>

  <!-- ─── Rich HTML Tooltip ─── -->
  {#if hoveredNode}
    {@const cw = containerEl?.clientWidth || 800}
    {@const ch = containerEl?.clientHeight || 600}
    <div
      class="graph-tooltip"
      style="left: {Math.min(tooltipX + 18, cw - 320)}px; top: {Math.min(Math.max(tooltipY - 8, 8), ch - 290)}px;"
    >
      {#if hoveredNode.type !== 'project'}
        <div class="tooltip-header">
          <span class="tooltip-brand-badge" style="background: {hoveredNode.color}">
            {hoveredNode.label}
          </span>
          <span class="tooltip-count">{hoveredNode.projectCount} project{hoveredNode.projectCount !== 1 ? 's' : ''}</span>
        </div>
        <div class="tooltip-title">{hoveredNode.sublabel}</div>

        <!-- Status Breakdown Progress Bars -->
        {#if tooltipStatusEntries.length > 0}
          <div class="tooltip-status-section">
            <div class="tooltip-section-label">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
              Workflow Status Breakdown (Border Ring)
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

        <!-- Direct Children Summary -->
        {#if hoveredNode.children.length > 0}
          <div class="tooltip-children-section">
            <div class="tooltip-section-label">
              <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v3A1.5 1.5 0 0 0 2.5 9h3A1.5 1.5 0 0 0 7 7.5v-3A1.5 1.5 0 0 0 5.5 3h-3zm8 0A1.5 1.5 0 0 0 10 4.5v3A1.5 1.5 0 0 0 11.5 9h3A1.5 1.5 0 0 0 16 7.5v-3A1.5 1.5 0 0 0 14.5 3h-3zm-8 8A1.5 1.5 0 0 0 2 12.5v3A1.5 1.5 0 0 0 3.5 17h3a1.5 1.5 0 0 0 1.5-1.5v-3A1.5 1.5 0 0 0 6.5 11h-3zm8 0a1.5 1.5 0 0 0-1.5 1.5v3a1.5 1.5 0 0 0 1.5 1.5h3a1.5 1.5 0 0 0 1.5-1.5v-3a1.5 1.5 0 0 0-1.5-1.5h-3z"/></svg>
              {hoveredNode.type === 'root' ? 'Brand Subsidiaries' : hoveredNode.type === 'brand' ? 'Media Types' : 'Linked Deliverables'}
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
        <!-- Project Node Tooltip -->
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
                  <span class="tooltip-tag">#{tag}</span>
                {/each}
              </div>
            </div>
          {/if}
        </div>
        <div class="tooltip-footer">
          <span class="tooltip-hint">Click to open project • Drag to stretch node</span>
        </div>
      {/if}
    </div>
  {/if}

  <!-- ─── Top-Right Action Controls ─── -->
  <div class="graph-top-actions">
    <div class="graph-quick-tools">
      <button
        class="graph-ctrl-btn"
        class:active={showSettingsPanel}
        onclick={() => showSettingsPanel = !showSettingsPanel}
        title="Obsidian Graph Forces & Display Controls"
      >
        <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14">
          <path d="M3 4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4zm0 6a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-2zm0 6a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-2z"/>
        </svg>
      </button>
      <button class="graph-ctrl-btn" onclick={fitView} title="Fit all nodes in view">
        <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M3 3h4a.5.5 0 0 1 0 1H4v3a.5.5 0 0 1-1 0V3.5a.5.5 0 0 1 .5-.5H3zm10 0h3.5a.5.5 0 0 1 .5.5V7a.5.5 0 0 1-1 0V4h-3a.5.5 0 0 1 0-1zM3.5 13a.5.5 0 0 1 .5.5V16h3a.5.5 0 0 1 0 1H3.5a.5.5 0 0 1-.5-.5V13.5a.5.5 0 0 1 .5-.5zM17 13.5v3a.5.5 0 0 1-.5.5H13a.5.5 0 0 1 0-1h3v-2.5a.5.5 0 0 1 1 0z"/></svg>
      </button>
      <button class="graph-ctrl-btn" onclick={resetView} title="Reset zoom">
        <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M10 3a7 7 0 0 0-5.8 3.1l-1.5-1.5A.5.5 0 0 0 2 5v4.5a.5.5 0 0 0 .5.5H7a.5.5 0 0 0 .35-.85L5.8 7.6A5.5 5.5 0 1 1 4.5 10a.75.75 0 0 0-1.5 0A7 7 0 1 0 10 3z"/></svg>
      </button>
      <button class="graph-ctrl-btn" onclick={triggerAnimatePulse} title="Replay kinetic animation pulse">
        <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M6.3 2.84A1.5 1.5 0 0 0 4 4.11v11.78a1.5 1.5 0 0 0 2.3 1.27l9.42-5.89a1.5 1.5 0 0 0 0-2.54L6.3 2.84z"/></svg>
      </button>
      <span class="graph-zoom-label">{Math.round(zoom * 100)}%</span>
    </div>
  </div>

  <!-- ─── Obsidian-Style Floating Controls Drawer ─── -->
  {#if showSettingsPanel}
    <div class="obsidian-panel">
      <div class="obsidian-panel-header">
        <div class="obsidian-panel-title">
          <svg viewBox="0 0 20 20" fill="currentColor" width="13" height="13"><path d="M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM2 10a8 8 0 1 1 16 0 8 8 0 0 1-16 0z"/></svg>
          Graph Settings
        </div>
        <div class="obsidian-header-actions">
          <button class="obsidian-icon-btn" onclick={resetForces} title="Reset to default forces">
            <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M4 2a1 1 0 0 1 1 1v2.1A7 7 0 1 1 3.07 11.5a1 1 0 1 1 1.94-.48A5 5 0 1 0 5.6 6.8H8a1 1 0 1 1 0 2H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z"/></svg>
          </button>
          <button class="obsidian-icon-btn" onclick={() => showSettingsPanel = false} title="Close settings">
            <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22z"/></svg>
          </button>
        </div>
      </div>

      <div class="obsidian-panel-body">
        <!-- ─── 1. Filters Section ─── -->
        <div class="obsidian-section">
          <div class="obsidian-section-title">
            <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.938a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06z"/></svg>
            Filters
          </div>
          <div class="obsidian-search-box">
            <svg class="search-icon" viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M9 3.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11zM2 9a7 7 0 1 1 12.45 4.39l3.58 3.58a.75.75 0 1 1-1.06 1.06l-3.58-3.58A7 7 0 0 1 2 9z"/></svg>
            <input
              type="text"
              class="obsidian-search-input"
              placeholder="Search title, tag, designer..."
              bind:value={searchQuery}
              oninput={() => { buildHierarchy(); }}
            />
            {#if searchQuery}
              <button class="obsidian-clear-btn" onclick={() => { searchQuery = ''; buildHierarchy(); }}>&times;</button>
            {/if}
          </div>

          <!-- Brand Filter Chips -->
          <div class="obsidian-brand-chips">
            {#each ['ALL', 'SS', 'SSC', 'SSW', 'SSE', 'SST'] as b}
              <button
                class="brand-chip"
                class:active={selectedBrand === b}
                onclick={() => { selectedBrand = b; buildHierarchy(); }}
              >
                {b}
              </button>
            {/each}
          </div>

          <!-- Cross-Links Toggle -->
          <div class="obsidian-toggle-row">
            <span class="obsidian-toggle-label">File Cross-Links (Tags)</span>
            <label class="obsidian-switch">
              <input type="checkbox" bind:checked={showCrossLinks} />
              <span class="obsidian-slider"></span>
            </label>
          </div>
        </div>

        <!-- ─── 2. Display Section ─── -->
        <div class="obsidian-section">
          <div class="obsidian-section-title">
            <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.938a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06z"/></svg>
            Display
          </div>

          <div class="obsidian-toggle-row">
            <span class="obsidian-toggle-label">Directional Arrows</span>
            <label class="obsidian-switch">
              <input type="checkbox" bind:checked={showArrows} />
              <span class="obsidian-slider"></span>
            </label>
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Text fade threshold</span>
              <span class="slider-val">{textFadeThreshold.toFixed(2)}</span>
            </div>
            <input type="range" min="0.05" max="1.0" step="0.05" bind:value={textFadeThreshold} />
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Node size</span>
              <span class="slider-val">{nodeSizeScale.toFixed(2)}</span>
            </div>
            <input type="range" min="0.6" max="2.5" step="0.1" bind:value={nodeSizeScale} />
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Link thickness</span>
              <span class="slider-val">{linkThickness.toFixed(2)}</span>
            </div>
            <input type="range" min="0.2" max="2.5" step="0.1" bind:value={linkThickness} />
          </div>

          <button class="obsidian-animate-btn" onclick={triggerAnimatePulse}>
            <svg viewBox="0 0 20 20" fill="currentColor" width="13" height="13"><path d="M6.3 2.84A1.5 1.5 0 0 0 4 4.11v11.78a1.5 1.5 0 0 0 2.3 1.27l9.42-5.89a1.5 1.5 0 0 0 0-2.54L6.3 2.84z"/></svg>
            Animate
          </button>
        </div>

        <!-- ─── 3. Forces Section (Gravity, Repel, Springs) ─── -->
        <div class="obsidian-section">
          <div class="obsidian-section-title">
            <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.938a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06z"/></svg>
            Forces
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Center force (Gravity)</span>
              <span class="slider-val">{centerForce.toFixed(2)}</span>
            </div>
            <input type="range" min="0.05" max="1.50" step="0.05" bind:value={centerForce} />
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Repel force</span>
              <span class="slider-val">{repelForce.toFixed(2)}</span>
            </div>
            <input type="range" min="2.0" max="25.0" step="0.5" bind:value={repelForce} />
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Link force</span>
              <span class="slider-val">{linkForce.toFixed(2)}</span>
            </div>
            <input type="range" min="0.1" max="1.8" step="0.05" bind:value={linkForce} />
          </div>

          <div class="obsidian-slider-row">
            <div class="slider-label-row">
              <span>Link distance</span>
              <span class="slider-val">{Math.round(linkDistance)}</span>
            </div>
            <input type="range" min="40" max="220" step="5" bind:value={linkDistance} />
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- ─── Top-Left Stats Bar ─── -->
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
    <span class="graph-stat-divider"></span>
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16z"/></svg>
      Force Gravity Active
    </span>
  </div>

  <!-- ─── Bottom-Left Graph Guide & File Linking Legend ─── -->
  {#if showLegend}
    <div class="graph-legend">
      <div class="legend-header">
        <div class="legend-title">
          <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
          How to Read the Graph & File Linking
        </div>
        <button class="legend-close-btn" onclick={() => showLegend = false}>&times;</button>
      </div>

      <!-- 1. Hierarchy -->
      <div class="legend-section">
        <span class="legend-label">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M15 4a3 3 0 1 0-2.6 4.5l-5.3 2.65a3 3 0 0 0 0 1.7l5.3 2.65A3 3 0 1 0 15 14z"/></svg>
          Hierarchy & Lineage:
        </span>
        <div class="legend-flow-badge">
          <strong>SSH Holding</strong> &rarr; <span>Brand</span> &rarr; <span>Media Type</span> &rarr; <span>Project File</span>
        </div>
      </div>

      <!-- 2. Status Ring -->
      <div class="legend-section">
        <span class="legend-label">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><circle cx="10" cy="10" r="6" stroke="currentColor" stroke-width="3" fill="none"/></svg>
          Border Ring = Workflow Status %:
        </span>
        <div class="legend-items">
          {#each [['approved','Done / Approved'], ['in-progress','In Progress'], ['review','Review'], ['revision','Revision'], ['backlog','Backlog']] as [s, label]}
            <span class="legend-swatch"><span class="swatch-ring" style="border-color:{statusColors[s]}"></span>{label}</span>
          {/each}
        </div>
      </div>

      <!-- 3. File Linking Lines -->
      <div class="legend-section">
        <span class="legend-label">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13z"/></svg>
          File Linking Indicators:
        </span>
        <div class="legend-links-guide">
          <div class="guide-link-item">
            <span class="guide-solid-line"></span>
            <span><strong>Solid Line:</strong> Asset hierarchy & parent lineage</span>
          </div>
          <div class="guide-link-item">
            <span class="guide-dashed-line"></span>
            <span><strong>Dashed Cyan:</strong> Cross-links (shared tags & campaign files)</span>
          </div>
        </div>
      </div>

      <div class="legend-hint">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16z"/></svg>
        Click & drag any node to test physics • Hover to trace linking • Click project to open
      </div>
    </div>
  {:else}
    <button class="legend-reopen-btn" onclick={() => showLegend = true} title="Open Graph Guide">
      <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
      Graph Guide
    </button>
  {/if}
</div>

<style>
  .graph-container {
    position: relative;
    width: 100%;
    height: calc(100vh - 240px);
    min-height: 520px;
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
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.14));
    border-radius: var(--radius-lg, 12px);
    padding: 14px 16px 12px;
    min-width: 250px;
    max-width: 310px;
    pointer-events: none;
    box-shadow: 0 20px 30px -5px rgba(0,0,0,0.5), 0 0 15px rgba(33, 161, 247, 0.15);
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
    border-radius: 9999px;
    font-size: 10px;
    font-weight: 800;
    color: #FFFFFF;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .tooltip-count {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, rgba(255,255,255,0.45));
  }
  .tooltip-job-id {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary, rgba(255,255,255,0.45));
    font-family: var(--font-mono, monospace);
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
    color: var(--text-tertiary, rgba(255,255,255,0.4));
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
    color: var(--brand-accent, #21A1F7);
  }

  /* Status Breakdown */
  .tooltip-status-section { margin-bottom: 10px; }
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
    min-width: 72px;
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

  /* Children */
  .tooltip-children-section { margin-bottom: 4px; }
  .tooltip-children-list { display: flex; flex-direction: column; gap: 2px; }
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

  /* Project Meta */
  .tooltip-meta-grid { display: flex; flex-direction: column; gap: 5px; }
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
    border-radius: 9999px;
    font-size: 9.5px;
    font-weight: 600;
    background: rgba(33, 161, 247, 0.12);
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
    color: var(--text-tertiary, rgba(255,255,255,0.35));
    font-style: italic;
  }

  /* ─── Top Actions ─── */
  .graph-top-actions {
    position: absolute;
    top: 12px;
    right: 12px;
    z-index: 40;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .graph-quick-tools {
    display: flex;
    align-items: center;
    gap: 4px;
    background: rgba(15, 26, 58, 0.88);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 4px;
  }
  .graph-ctrl-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: rgba(255,255,255,0.6);
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .graph-ctrl-btn:hover, .graph-ctrl-btn.active {
    background: rgba(33, 161, 247, 0.2);
    color: #38BDF8;
  }
  .graph-zoom-label {
    font-size: 10px;
    font-weight: 700;
    color: rgba(255,255,255,0.4);
    padding: 0 6px;
    min-width: 36px;
    text-align: center;
    font-family: var(--font-mono, monospace);
  }

  /* ─── Obsidian Floating Controls Drawer ─── */
  .obsidian-panel {
    position: absolute;
    top: 48px;
    right: 12px;
    width: 280px;
    max-height: calc(100% - 64px);
    overflow-y: auto;
    z-index: 50;
    background: rgba(18, 24, 38, 0.94);
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 10px;
    box-shadow: 0 16px 36px rgba(0,0,0,0.6), 0 0 20px rgba(0,0,0,0.3);
    animation: panelSlide 0.15s ease-out;
  }
  @keyframes panelSlide {
    from { opacity: 0; transform: translateY(-6px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .obsidian-panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 14px;
    border-bottom: 1px solid rgba(255,255,255,0.08);
  }
  .obsidian-panel-title {
    font-size: 11px;
    font-weight: 700;
    color: #F1F5F9;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .obsidian-panel-title svg { color: #38BDF8; }
  .obsidian-header-actions { display: flex; align-items: center; gap: 4px; }
  .obsidian-icon-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border: none;
    background: transparent;
    color: rgba(255,255,255,0.5);
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.12s;
  }
  .obsidian-icon-btn:hover { background: rgba(255,255,255,0.1); color: #FFF; }
  .obsidian-panel-body { padding: 12px 14px; }
  .obsidian-section {
    margin-bottom: 14px;
    padding-bottom: 12px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
  }
  .obsidian-section:last-child {
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
  }
  .obsidian-section-title {
    font-size: 10.5px;
    font-weight: 700;
    color: rgba(255,255,255,0.7);
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 4px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }
  .obsidian-section-title svg { color: rgba(255,255,255,0.4); }

  /* Search Box */
  .obsidian-search-box {
    position: relative;
    display: flex;
    align-items: center;
    margin-bottom: 8px;
  }
  .obsidian-search-box .search-icon {
    position: absolute;
    left: 8px;
    color: rgba(255,255,255,0.4);
    pointer-events: none;
  }
  .obsidian-search-input {
    width: 100%;
    height: 28px;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 6px;
    padding: 0 24px 0 26px;
    font-size: 11px;
    color: #F8FAFC;
    outline: none;
    transition: border-color 0.15s;
  }
  .obsidian-search-input:focus { border-color: #38BDF8; }
  .obsidian-clear-btn {
    position: absolute;
    right: 6px;
    background: transparent;
    border: none;
    color: rgba(255,255,255,0.5);
    cursor: pointer;
    font-size: 14px;
    line-height: 1;
  }

  /* Brand Chips */
  .obsidian-brand-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-bottom: 8px;
  }
  .brand-chip {
    padding: 2px 7px;
    font-size: 9.5px;
    font-weight: 700;
    border-radius: 4px;
    border: 1px solid rgba(255,255,255,0.1);
    background: rgba(255,255,255,0.04);
    color: rgba(255,255,255,0.6);
    cursor: pointer;
    transition: all 0.12s;
  }
  .brand-chip:hover { background: rgba(255,255,255,0.1); color: #FFF; }
  .brand-chip.active {
    background: #0284C7;
    border-color: #38BDF8;
    color: #FFF;
  }

  /* Sliders & Toggles */
  .obsidian-toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 7px;
  }
  .obsidian-toggle-label {
    font-size: 10.5px;
    color: rgba(255,255,255,0.65);
    font-weight: 500;
  }
  .obsidian-switch {
    position: relative;
    display: inline-block;
    width: 32px;
    height: 18px;
  }
  .obsidian-switch input { opacity: 0; width: 0; height: 0; }
  .obsidian-slider {
    position: absolute;
    cursor: pointer;
    top: 0; left: 0; right: 0; bottom: 0;
    background-color: rgba(255,255,255,0.15);
    transition: .2s;
    border-radius: 18px;
  }
  .obsidian-slider:before {
    position: absolute;
    content: "";
    height: 12px;
    width: 12px;
    left: 3px;
    bottom: 3px;
    background-color: white;
    transition: .2s;
    border-radius: 50%;
  }
  input:checked + .obsidian-slider { background-color: #0284C7; }
  input:checked + .obsidian-slider:before { transform: translateX(14px); }

  .obsidian-slider-row { margin-bottom: 8px; }
  .slider-label-row {
    display: flex;
    justify-content: space-between;
    font-size: 10px;
    color: rgba(255,255,255,0.6);
    margin-bottom: 2px;
  }
  .slider-val {
    font-family: var(--font-mono, monospace);
    color: #38BDF8;
    font-weight: 700;
  }
  .obsidian-slider-row input[type="range"] {
    width: 100%;
    height: 4px;
    appearance: none;
    background: rgba(255,255,255,0.12);
    border-radius: 2px;
    outline: none;
  }
  .obsidian-slider-row input[type="range"]::-webkit-slider-thumb {
    appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #38BDF8;
    cursor: pointer;
    box-shadow: 0 0 6px rgba(56, 189, 248, 0.5);
  }

  .obsidian-animate-btn {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 6px 10px;
    margin-top: 4px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 6px;
    font-size: 11px;
    font-weight: 600;
    color: #F1F5F9;
    cursor: pointer;
    transition: all 0.15s;
  }
  .obsidian-animate-btn:hover {
    background: rgba(56, 189, 248, 0.18);
    border-color: #38BDF8;
    color: #38BDF8;
  }

  /* ─── Top Stats ─── */
  .graph-stats {
    position: absolute;
    top: 12px;
    left: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(15, 26, 58, 0.88);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 6px 12px;
    pointer-events: none;
  }
  .graph-stat-item {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10.5px;
    font-weight: 600;
    color: rgba(255,255,255,0.65);
  }
  .graph-stat-item svg { color: #38BDF8; }
  .graph-stat-divider {
    width: 1px;
    height: 12px;
    background: rgba(255,255,255,0.12);
  }

  /* ─── Bottom-Left Graph Guide & Legend ─── */
  .graph-legend {
    position: absolute;
    bottom: 16px;
    left: 16px;
    background: rgba(15, 26, 58, 0.92);
    backdrop-filter: blur(16px);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 10px;
    padding: 12px 16px;
    max-width: 380px;
    box-shadow: 0 12px 28px rgba(0,0,0,0.5);
    animation: ttFadeIn 0.15s ease-out;
  }
  .legend-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .legend-title {
    font-size: 11px;
    font-weight: 800;
    color: rgba(255,255,255,0.75);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .legend-title svg { color: #38BDF8; }
  .legend-close-btn {
    background: transparent;
    border: none;
    color: rgba(255,255,255,0.4);
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    padding: 0 2px;
  }
  .legend-close-btn:hover { color: #FFF; }
  .legend-reopen-btn {
    position: absolute;
    bottom: 16px;
    left: 16px;
    display: flex;
    align-items: center;
    gap: 5px;
    background: rgba(15, 26, 58, 0.88);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 8px;
    padding: 6px 12px;
    font-size: 11px;
    font-weight: 700;
    color: rgba(255,255,255,0.7);
    cursor: pointer;
    transition: all 0.15s;
  }
  .legend-reopen-btn:hover { background: rgba(56, 189, 248, 0.18); color: #38BDF8; }
  .legend-section { margin-bottom: 7px; }
  .legend-label {
    font-size: 10px;
    font-weight: 700;
    color: rgba(255,255,255,0.45);
    display: flex;
    align-items: center;
    gap: 4px;
    margin-bottom: 3px;
  }
  .legend-label svg { color: rgba(255,255,255,0.35); }
  .legend-flow-badge {
    font-size: 10.5px;
    color: rgba(255,255,255,0.6);
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 4px;
    padding: 3px 8px;
  }
  .legend-flow-badge strong { color: #38BDF8; font-weight: 700; }
  .legend-items { display: flex; flex-wrap: wrap; gap: 6px; }
  .legend-swatch {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 600;
    color: rgba(255,255,255,0.6);
  }
  .swatch-ring {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
    border: 2px solid;
    background: transparent;
  }
  .legend-links-guide {
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 10px;
    color: rgba(255,255,255,0.6);
  }
  .guide-link-item { display: flex; align-items: center; gap: 6px; }
  .guide-solid-line {
    width: 16px;
    height: 2px;
    background: rgba(255,255,255,0.4);
    border-radius: 1px;
  }
  .guide-dashed-line {
    width: 16px;
    height: 2px;
    border-top: 2px dashed #38BDF8;
  }
  .legend-hint {
    font-size: 9.5px;
    color: rgba(255,255,255,0.35);
    margin-top: 8px;
    font-style: italic;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .legend-hint svg { color: rgba(255,255,255,0.25); }
</style>

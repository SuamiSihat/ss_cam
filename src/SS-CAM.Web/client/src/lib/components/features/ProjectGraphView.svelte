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
  let hoveredNode: GraphNode | null = $state(null);
  let draggedNode: GraphNode | null = null;
  let isDragging = false;
  let tooltipX = $state(0);
  let tooltipY = $state(0);

  // Camera / pan state
  let camX = 0;
  let camY = 0;
  let zoom = 1;
  let isPanning = false;
  let panStartX = 0;
  let panStartY = 0;

  interface GraphNode {
    id: string;
    label: string;
    jobId: string;
    brand: string;
    designer: string;
    status: string;
    priority: string;
    mediaType: string;
    deadline: string;
    tags: string[];
    deliverableCount: number;
    x: number;
    y: number;
    vx: number;
    vy: number;
    radius: number;
    color: string;
    borderColor: string;
  }

  interface GraphEdge {
    source: GraphNode;
    target: GraphNode;
    type: 'brand' | 'designer';
    color: string;
  }

  interface BrandCluster {
    brand: string;
    color: string;
    cx: number;
    cy: number;
    nodes: GraphNode[];
  }

  let nodes: GraphNode[] = [];
  let edges: GraphEdge[] = [];
  let brandClusters: BrandCluster[] = [];

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
    SS: '#043388',
    SSH: '#022057',
    SSC: '#0078D4',
    SSW: '#10B981',
    SSE: '#F59E0B',
    SST: '#8B5CF6'
  };

  const brandNames: Record<string, string> = {
    SS: 'SuamiSihat',
    SSH: 'SS Holdings',
    SSC: 'SS Clinic',
    SSW: 'SS Wellness',
    SSE: 'SS Enterprise',
    SST: 'SS Tech'
  };

  const prioritySize: Record<string, number> = {
    P1: 26, P2: 22, P3: 18, P4: 15, P5: 12,
    urgent: 26, high: 22, medium: 18, low: 15
  };

  const priorityLabels: Record<string, string> = {
    P1: 'Urgent', P2: 'High', P3: 'Medium', P4: 'Low', P5: 'Lowest',
    urgent: 'Urgent', high: 'High', medium: 'Medium', low: 'Low'
  };

  // Media type icon drawing functions (using canvas paths)
  function drawMediaIcon(ctx: CanvasRenderingContext2D, x: number, y: number, mediaType: string, size: number) {
    ctx.save();
    ctx.translate(x, y);
    const s = size * 0.4;
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.strokeStyle = 'rgba(255,255,255,0.9)';
    ctx.lineWidth = 1.2;

    const mt = (mediaType || '').toLowerCase();
    if (mt.includes('social')) {
      // Grid/share icon for social media
      ctx.beginPath();
      ctx.arc(-s * 0.3, -s * 0.3, s * 0.18, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(s * 0.3, -s * 0.3, s * 0.18, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(0, s * 0.3, s * 0.18, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-s * 0.15, -s * 0.2);
      ctx.lineTo(s * 0.15, -s * 0.2);
      ctx.moveTo(-s * 0.15, -s * 0.15);
      ctx.lineTo(-s * 0.05, s * 0.18);
      ctx.moveTo(s * 0.15, -s * 0.15);
      ctx.lineTo(s * 0.05, s * 0.18);
      ctx.stroke();
    } else if (mt.includes('video')) {
      // Video camera icon
      ctx.beginPath();
      ctx.roundRect(-s * 0.4, -s * 0.25, s * 0.55, s * 0.5, s * 0.06);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(s * 0.2, -s * 0.15);
      ctx.lineTo(s * 0.4, -s * 0.25);
      ctx.lineTo(s * 0.4, s * 0.25);
      ctx.lineTo(s * 0.2, s * 0.15);
      ctx.closePath();
      ctx.fill();
    } else if (mt.includes('brand') || mt.includes('identity')) {
      // Pen/vector tool icon
      ctx.beginPath();
      ctx.moveTo(-s * 0.05, -s * 0.35);
      ctx.lineTo(s * 0.35, s * 0.05);
      ctx.lineTo(s * 0.2, s * 0.2);
      ctx.lineTo(-s * 0.35, -s * 0.15);
      ctx.closePath();
      ctx.fill();
      ctx.beginPath();
      ctx.arc(-s * 0.28, s * 0.28, s * 0.12, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // Image/print icon (default)
      ctx.beginPath();
      ctx.roundRect(-s * 0.35, -s * 0.25, s * 0.7, s * 0.5, s * 0.06);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(-s * 0.15, -s * 0.08, s * 0.08, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(-s * 0.35, s * 0.15);
      ctx.lineTo(-s * 0.1, -s * 0.02);
      ctx.lineTo(s * 0.1, s * 0.12);
      ctx.lineTo(s * 0.25, s * 0.02);
      ctx.lineTo(s * 0.35, s * 0.15);
      ctx.stroke();
    }
    ctx.restore();
  }

  function buildGraph() {
    const w = canvasEl?.width || 800;
    const h = canvasEl?.height || 600;
    const cx = w / 2;
    const cy = h / 2;

    // Group projects by brand for cluster layout
    const brandGroups: Record<string, Project[]> = {};
    for (const p of projects) {
      const brand = p.brand || 'SS';
      if (!brandGroups[brand]) brandGroups[brand] = [];
      brandGroups[brand].push(p);
    }

    const brandKeys = Object.keys(brandGroups);
    const clusterRadius = Math.min(w, h) * 0.28;

    // Calculate brand cluster center positions (arranged in a circle)
    const clusterCenters: Record<string, { x: number; y: number }> = {};
    brandKeys.forEach((brand, i) => {
      const angle = (i / Math.max(1, brandKeys.length)) * Math.PI * 2 - Math.PI / 2;
      clusterCenters[brand] = {
        x: cx + Math.cos(angle) * clusterRadius,
        y: cy + Math.sin(angle) * clusterRadius
      };
    });

    nodes = projects.map((p) => {
      const brand = p.brand || 'SS';
      const cluster = clusterCenters[brand] || { x: cx, y: cy };
      const spread = Math.min(w, h) * 0.12;
      return {
        id: p.id || p.jobId,
        label: p.title,
        jobId: p.jobId,
        brand,
        designer: p.designer || '',
        status: p.status || 'backlog',
        priority: p.priority || 'medium',
        mediaType: p.presetType || '',
        deadline: p.deadline || '',
        tags: p.tags || [],
        deliverableCount: p.deliverables?.length || 0,
        x: cluster.x + (Math.random() - 0.5) * spread * 2,
        y: cluster.y + (Math.random() - 0.5) * spread * 2,
        vx: 0,
        vy: 0,
        radius: prioritySize[p.priority] || 18,
        color: brandColors[brand] || '#043388',
        borderColor: statusColors[p.status] || '#6B7280'
      };
    });

    // Build brand clusters reference
    brandClusters = brandKeys.map(brand => ({
      brand,
      color: brandColors[brand] || '#043388',
      cx: clusterCenters[brand].x,
      cy: clusterCenters[brand].y,
      nodes: nodes.filter(n => n.brand === brand)
    }));

    edges = [];
    // Connect nodes that share the same designer
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        if (nodes[i].designer && nodes[i].designer === nodes[j].designer) {
          edges.push({
            source: nodes[i],
            target: nodes[j],
            type: 'designer',
            color: 'rgba(255, 255, 255, 0.06)'
          });
        }
      }
    }
  }

  function simulate() {
    const centerX = (canvasEl?.width || 800) / 2;
    const centerY = (canvasEl?.height || 600) / 2;

    // Force simulation with brand clustering
    for (const node of nodes) {
      if (draggedNode === node) continue;

      // Gravity toward overall center (weak)
      node.vx += (centerX - node.x) * 0.0001;
      node.vy += (centerY - node.y) * 0.0001;

      // Strong attraction toward brand cluster center
      const cluster = brandClusters.find(c => c.brand === node.brand);
      if (cluster) {
        node.vx += (cluster.cx - node.x) * 0.003;
        node.vy += (cluster.cy - node.y) * 0.003;
      }

      // Repulsion between all nodes
      for (const other of nodes) {
        if (other === node) continue;
        const dx = node.x - other.x;
        const dy = node.y - other.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const sameBrand = node.brand === other.brand;
        const minDist = node.radius + other.radius + (sameBrand ? 20 : 50);
        if (dist < minDist * 2.5) {
          const force = (minDist / dist) * (sameBrand ? 0.5 : 1.2);
          node.vx += (dx / dist) * force;
          node.vy += (dy / dist) * force;
        }
      }
    }

    // Edge attraction (spring) — designer connections
    for (const edge of edges) {
      const dx = edge.target.x - edge.source.x;
      const dy = edge.target.y - edge.source.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const idealDist = edge.source.brand === edge.target.brand ? 80 : 160;
      const force = (dist - idealDist) * 0.0005;

      if (draggedNode !== edge.source) {
        edge.source.vx += (dx / dist) * force;
        edge.source.vy += (dy / dist) * force;
      }
      if (draggedNode !== edge.target) {
        edge.target.vx -= (dx / dist) * force;
        edge.target.vy -= (dy / dist) * force;
      }
    }

    // Apply velocities with damping
    for (const node of nodes) {
      if (draggedNode === node) continue;
      node.vx *= 0.86;
      node.vy *= 0.86;
      node.x += node.vx;
      node.y += node.vy;
    }

    // Update cluster centers based on actual node positions
    for (const cluster of brandClusters) {
      if (cluster.nodes.length === 0) continue;
      let sx = 0, sy = 0;
      for (const n of cluster.nodes) { sx += n.x; sy += n.y; }
      cluster.cx = cluster.cx * 0.95 + (sx / cluster.nodes.length) * 0.05;
      cluster.cy = cluster.cy * 0.95 + (sy / cluster.nodes.length) * 0.05;
    }
  }

  function computeHull(pts: { x: number; y: number }[], pad: number): string {
    if (pts.length === 0) return '';
    if (pts.length === 1) {
      const p = pts[0];
      return `M ${p.x - pad} ${p.y} A ${pad} ${pad} 0 1 0 ${p.x + pad} ${p.y} A ${pad} ${pad} 0 1 0 ${p.x - pad} ${p.y}`;
    }

    // Simple convex hull with padding
    const sorted = [...pts].sort((a, b) => a.x - b.x || a.y - b.y);
    const cross = (O: typeof pts[0], A: typeof pts[0], B: typeof pts[0]) =>
      (A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x);

    const lower: typeof pts = [];
    for (const p of sorted) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
      lower.push(p);
    }
    const upper: typeof pts = [];
    for (const p of sorted.reverse()) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
      upper.push(p);
    }
    lower.pop();
    upper.pop();
    const hull = [...lower, ...upper];
    if (hull.length < 2) {
      const cx = pts.reduce((s, p) => s + p.x, 0) / pts.length;
      const cy = pts.reduce((s, p) => s + p.y, 0) / pts.length;
      return `M ${cx - pad} ${cy} A ${pad} ${pad} 0 1 0 ${cx + pad} ${cy} A ${pad} ${pad} 0 1 0 ${cx - pad} ${cy}`;
    }

    // Expand hull outward by pad
    const expanded = hull.map((p, i) => {
      const prev = hull[(i - 1 + hull.length) % hull.length];
      const next = hull[(i + 1) % hull.length];
      const nx = -(next.y - prev.y);
      const ny = next.x - prev.x;
      const len = Math.sqrt(nx * nx + ny * ny) || 1;
      return { x: p.x + (nx / len) * pad, y: p.y + (ny / len) * pad };
    });

    // Build smooth path with curves
    let path = `M ${expanded[0].x} ${expanded[0].y}`;
    for (let i = 1; i < expanded.length; i++) {
      const prev = expanded[i - 1];
      const curr = expanded[i];
      const cpx = (prev.x + curr.x) / 2;
      const cpy = (prev.y + curr.y) / 2;
      path += ` Q ${prev.x} ${prev.y} ${cpx} ${cpy}`;
    }
    const last = expanded[expanded.length - 1];
    const first = expanded[0];
    path += ` Q ${last.x} ${last.y} ${(last.x + first.x) / 2} ${(last.y + first.y) / 2}`;
    path += ' Z';
    return path;
  }

  function draw() {
    if (!canvasEl) return;
    const ctx = canvasEl.getContext('2d');
    if (!ctx) return;

    const w = canvasEl.width;
    const h = canvasEl.height;

    ctx.clearRect(0, 0, w, h);

    ctx.save();
    ctx.translate(camX, camY);
    ctx.scale(zoom, zoom);

    // Draw brand cluster regions (convex hulls)
    for (const cluster of brandClusters) {
      if (cluster.nodes.length < 1) continue;
      const pts = cluster.nodes.map(n => ({ x: n.x, y: n.y }));
      const padding = 40;

      // Draw cluster hull background
      const path2d = new Path2D(computeHull(pts, padding));
      ctx.fillStyle = `${cluster.color}0A`;
      ctx.fill(path2d);
      ctx.strokeStyle = `${cluster.color}18`;
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 4]);
      ctx.stroke(path2d);
      ctx.setLineDash([]);

      // Draw brand label at top of cluster
      const topNode = cluster.nodes.reduce((best, n) => n.y < best.y ? n : best, cluster.nodes[0]);
      ctx.font = '700 11px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'bottom';
      ctx.fillStyle = `${cluster.color}88`;

      const labelText = `${cluster.brand}`;
      const labelY = topNode.y - padding - 6;
      const labelX = cluster.nodes.reduce((s, n) => s + n.x, 0) / cluster.nodes.length;

      // Brand label background pill
      const metrics = ctx.measureText(labelText);
      const pillW = metrics.width + 16;
      const pillH = 20;
      ctx.fillStyle = `${cluster.color}14`;
      ctx.beginPath();
      ctx.roundRect(labelX - pillW / 2, labelY - pillH + 2, pillW, pillH, 10);
      ctx.fill();

      ctx.fillStyle = `${cluster.color}CC`;
      ctx.fillText(labelText, labelX, labelY);

      // Media type count badges below brand label
      const mediaGroups: Record<string, number> = {};
      for (const n of cluster.nodes) {
        const mt = n.mediaType || 'Other';
        mediaGroups[mt] = (mediaGroups[mt] || 0) + 1;
      }
      const mediaEntries = Object.entries(mediaGroups);
      ctx.font = '600 9px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif';
      const totalBadgeW = mediaEntries.reduce((s, [label]) => s + ctx.measureText(`${label}`).width + 22, 0) + (mediaEntries.length - 1) * 4;
      let badgeX = labelX - totalBadgeW / 2;
      const badgeY = labelY + 4;
      for (const [label, count] of mediaEntries) {
        const btext = `${count}`;
        const bw = ctx.measureText(label).width + 22;
        ctx.fillStyle = `${cluster.color}0D`;
        ctx.beginPath();
        ctx.roundRect(badgeX, badgeY, bw, 16, 8);
        ctx.fill();
        ctx.fillStyle = `${cluster.color}88`;

        // Draw tiny media icon
        const iconX = badgeX + 8;
        const iconY = badgeY + 8;
        drawMediaIcon(ctx, iconX, iconY, label, 14);

        ctx.fillStyle = `${cluster.color}99`;
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillText(btext, badgeX + 16, badgeY + 8);
        badgeX += bw + 4;
      }
    }

    // Draw edges
    for (const edge of edges) {
      const isHighlighted = hoveredNode && (edge.source === hoveredNode || edge.target === hoveredNode);
      ctx.beginPath();
      ctx.moveTo(edge.source.x, edge.source.y);

      // Curved edges for better readability
      const midX = (edge.source.x + edge.target.x) / 2;
      const midY = (edge.source.y + edge.target.y) / 2;
      const dx = edge.target.x - edge.source.x;
      const dy = edge.target.y - edge.source.y;
      const cpx = midX - dy * 0.1;
      const cpy = midY + dx * 0.1;
      ctx.quadraticCurveTo(cpx, cpy, edge.target.x, edge.target.y);

      if (isHighlighted) {
        ctx.strokeStyle = 'rgba(33, 161, 247, 0.3)';
        ctx.lineWidth = 1.8;
        ctx.setLineDash([]);
      } else {
        ctx.strokeStyle = edge.color;
        ctx.lineWidth = 0.5;
        ctx.setLineDash([2, 3]);
      }
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Draw nodes
    for (const node of nodes) {
      const isHovered = hoveredNode === node;
      const isConnected = hoveredNode && edges.some(e =>
        (e.source === hoveredNode && e.target === node) ||
        (e.target === hoveredNode && e.source === node)
      );
      const isSameBrand = hoveredNode && hoveredNode.brand === node.brand;
      const dimmed = hoveredNode && !isHovered && !isConnected && !isSameBrand;

      const r = isHovered ? node.radius * 1.35 : node.radius;
      const alpha = dimmed ? 0.12 : 1;

      // Outer glow for hovered node
      if (isHovered) {
        const gradient = ctx.createRadialGradient(node.x, node.y, r, node.x, node.y, r + 16);
        gradient.addColorStop(0, `${node.borderColor}40`);
        gradient.addColorStop(1, `${node.borderColor}00`);
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 16, 0, Math.PI * 2);
        ctx.fillStyle = gradient;
        ctx.fill();
      }

      // Connected node highlight ring
      if (isConnected) {
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 4, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(33, 161, 247, 0.3)';
        ctx.lineWidth = 2;
        ctx.stroke();
      }

      // Node circle with gradient fill
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
      if (alpha < 1) {
        ctx.fillStyle = `${node.color}1A`;
      } else {
        const grad = ctx.createRadialGradient(node.x - r * 0.3, node.y - r * 0.3, 0, node.x, node.y, r);
        grad.addColorStop(0, lightenColor(node.color, 25));
        grad.addColorStop(1, node.color);
        ctx.fillStyle = grad;
      }
      ctx.fill();

      // Status border ring
      ctx.lineWidth = isHovered ? 3.5 : 2.5;
      ctx.strokeStyle = alpha < 1 ? `${node.borderColor}1A` : node.borderColor;
      ctx.stroke();

      // Media type icon on node (if big enough)
      if (r >= 15 && alpha >= 1) {
        drawMediaIcon(ctx, node.x, node.y, node.mediaType, r * 0.8);
      }

      // Label below node
      if (alpha >= 1 && (isHovered || r >= 16)) {
        ctx.font = `${isHovered ? '700' : '600'} ${isHovered ? 11 : 9}px "Segoe UI Variable Text", "Segoe UI", Inter, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        ctx.fillStyle = isHovered ? 'rgba(255,255,255,0.92)' : 'rgba(255,255,255,0.65)';
        const label = node.jobId.length > 16 ? node.jobId.substring(0, 16) + '\u2026' : node.jobId;
        ctx.fillText(label, node.x, node.y + r + 5);
      }
    }

    ctx.restore();
  }

  function lightenColor(hex: string, percent: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, (num >> 16) + percent);
    const g = Math.min(255, ((num >> 8) & 0x00FF) + percent);
    const b = Math.min(255, (num & 0x0000FF) + percent);
    return `#${(r << 16 | g << 8 | b).toString(16).padStart(6, '0')}`;
  }

  function animate() {
    simulate();
    draw();
    animFrameId = requestAnimationFrame(animate);
  }

  function screenToWorld(sx: number, sy: number): [number, number] {
    return [(sx - camX) / zoom, (sy - camY) / zoom];
  }

  function findNodeAt(wx: number, wy: number): GraphNode | null {
    for (let i = nodes.length - 1; i >= 0; i--) {
      const n = nodes[i];
      const dx = wx - n.x;
      const dy = wy - n.y;
      if (dx * dx + dy * dy <= (n.radius + 6) * (n.radius + 6)) return n;
    }
    return null;
  }

  function handleMouseDown(e: MouseEvent) {
    const rect = canvasEl!.getBoundingClientRect();
    const [wx, wy] = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
    const node = findNodeAt(wx, wy);
    if (node) {
      draggedNode = node;
      isDragging = false;
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

    // Track screen-space tooltip position
    tooltipX = e.clientX - rect.left;
    tooltipY = e.clientY - rect.top;

    if (draggedNode) {
      isDragging = true;
      draggedNode.x = wx;
      draggedNode.y = wy;
      draggedNode.vx = 0;
      draggedNode.vy = 0;
    } else if (isPanning) {
      camX = e.clientX - panStartX;
      camY = e.clientY - panStartY;
    } else {
      hoveredNode = findNodeAt(wx, wy);
      canvasEl.style.cursor = hoveredNode ? 'pointer' : 'grab';
    }
  }

  function handleMouseUp() {
    if (draggedNode && !isDragging) {
      appState.navigate('project-detail', { id: draggedNode.id });
    }
    draggedNode = null;
    isDragging = false;
    isPanning = false;
  }

  function handleWheel(e: WheelEvent) {
    e.preventDefault();
    const rect = canvasEl!.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;

    const factor = e.deltaY < 0 ? 1.08 : 0.92;
    const newZoom = Math.max(0.15, Math.min(5, zoom * factor));

    camX = mx - ((mx - camX) / zoom) * newZoom;
    camY = my - ((my - camY) / zoom) * newZoom;
    zoom = newZoom;
  }

  function resetView() {
    zoom = 1;
    camX = 0;
    camY = 0;
  }

  function fitView() {
    if (nodes.length === 0 || !canvasEl) return;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const n of nodes) {
      minX = Math.min(minX, n.x - n.radius);
      minY = Math.min(minY, n.y - n.radius);
      maxX = Math.max(maxX, n.x + n.radius);
      maxY = Math.max(maxY, n.y + n.radius);
    }
    const gw = maxX - minX + 100;
    const gh = maxY - minY + 100;
    const cw = canvasEl.width;
    const ch = canvasEl.height;
    zoom = Math.min(cw / gw, ch / gh, 2);
    camX = (cw - gw * zoom) / 2 - minX * zoom + 50 * zoom;
    camY = (ch - gh * zoom) / 2 - minY * zoom + 50 * zoom;
  }

  function resizeCanvas() {
    if (!canvasEl || !containerEl) return;
    const dpr = window.devicePixelRatio || 1;
    canvasEl.width = containerEl.clientWidth * dpr;
    canvasEl.height = containerEl.clientHeight * dpr;
    canvasEl.style.width = containerEl.clientWidth + 'px';
    canvasEl.style.height = containerEl.clientHeight + 'px';
    const ctx = canvasEl.getContext('2d');
    if (ctx) ctx.scale(dpr, dpr);
  }

  onMount(() => {
    resizeCanvas();
    buildGraph();
    // Wait a beat then fit
    setTimeout(() => fitView(), 600);
    animate();
    window.addEventListener('resize', resizeCanvas);
  });

  onDestroy(() => {
    if (animFrameId) cancelAnimationFrame(animFrameId);
    window.removeEventListener('resize', resizeCanvas);
  });

  // Rebuild graph when projects change
  $effect(() => {
    if (projects && canvasEl) {
      buildGraph();
    }
  });

  function formatDeadline(d: string): string {
    if (!d) return '\u2014';
    try {
      const dt = new Date(d);
      return dt.toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });
    } catch {
      return d;
    }
  }

  function getMediaTypeIcon(mediaType: string): string {
    const mt = (mediaType || '').toLowerCase();
    if (mt.includes('social')) return 'share';
    if (mt.includes('video')) return 'video';
    if (mt.includes('brand') || mt.includes('identity')) return 'vector';
    return 'image';
  }

  function getZoomPercent(): string {
    return `${Math.round(zoom * 100)}%`;
  }
</script>

<div class="graph-container" bind:this={containerEl}>
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <canvas
    bind:this={canvasEl}
    class="graph-canvas"
    onmousedown={handleMouseDown}
    onmousemove={handleMouseMove}
    onmouseup={handleMouseUp}
    onmouseleave={() => { hoveredNode = null; draggedNode = null; isPanning = false; }}
    onwheel={handleWheel}
  ></canvas>

  <!-- Rich HTML Tooltip -->
  {#if hoveredNode}
    <div
      class="graph-tooltip"
      style="left: {Math.min(tooltipX + 16, (containerEl?.clientWidth || 800) - 300)}px; top: {Math.min(tooltipY - 10, (containerEl?.clientHeight || 600) - 200)}px;"
    >
      <div class="tooltip-header">
        <span class="tooltip-brand-badge" style="background: {hoveredNode.color}">
          {hoveredNode.brand}
        </span>
        <span class="tooltip-job-id">{hoveredNode.jobId}</span>
      </div>
      <div class="tooltip-title">{hoveredNode.label}</div>
      <div class="tooltip-meta-grid">
        <div class="tooltip-meta-row">
          <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8zm-2.5 4a2.5 2.5 0 1 1 5 0 2.5 2.5 0 0 1-5 0zm-3 8a3.5 3.5 0 0 1 3.5-3.5h4a3.5 3.5 0 0 1 3.5 3.5v1.5a1 1 0 0 1-1 1h-9a1 1 0 0 1-1-1V14zm1-1.5A2.5 2.5 0 0 1 8 10h4a2.5 2.5 0 0 1 2.5 2.5V14h-9v-1.5z"/></svg>
          <span class="tooltip-meta-label">Designer</span>
          <span class="tooltip-meta-value">{hoveredNode.designer || '\u2014'}</span>
        </div>
        <div class="tooltip-meta-row">
          <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
          <span class="tooltip-meta-label">Status</span>
          <span class="tooltip-meta-value">
            <span class="tooltip-status-dot" style="background: {statusColors[hoveredNode.status] || '#6B7280'}"></span>
            {statusLabels[hoveredNode.status] || hoveredNode.status}
          </span>
        </div>
        <div class="tooltip-meta-row">
          <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13zm0 1h13A1.5 1.5 0 0 1 18 5.5V12l-3.15-3.15a1.5 1.5 0 0 0-2.12 0l-5.23 5.23-1.65-1.65a1.5 1.5 0 0 0-2.12 0L2 14.15V5.5A1.5 1.5 0 0 1 3.5 4zm4.25 2.5a1.75 1.75 0 1 0 0 3.5 1.75 1.75 0 0 0 0-3.5z"/></svg>
          <span class="tooltip-meta-label">Media</span>
          <span class="tooltip-meta-value">{hoveredNode.mediaType || 'General'}</span>
        </div>
        <div class="tooltip-meta-row">
          <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M10.9 1.15a.75.75 0 0 1 .73.88l-1.3 5.47h4.92a.75.75 0 0 1 .59 1.21l-7.5 9.5a.75.75 0 0 1-1.33-.74l1.8-6.47H3.75a.75.75 0 0 1-.6-1.2l7.15-8.5a.75.75 0 0 1 .6-.15z"/></svg>
          <span class="tooltip-meta-label">Priority</span>
          <span class="tooltip-meta-value">{priorityLabels[hoveredNode.priority] || hoveredNode.priority}</span>
        </div>
        {#if hoveredNode.deadline}
          <div class="tooltip-meta-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M6 2a.75.75 0 0 1 .75.75V4h6.5v-1.25a.75.75 0 0 1 1.5 0V4h1.75A2.5 2.5 0 0 1 19 6.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 1 15.5v-9A2.5 2.5 0 0 1 3.5 4H5.25V2.75A.75.75 0 0 1 6 2zm10.5 3.5h-13a1.5 1.5 0 0 0-1.5 1.5V8h16V7a1.5 1.5 0 0 0-1.5-1.5zM2 9.5v6A1.5 1.5 0 0 0 3.5 17h13a1.5 1.5 0 0 0 1.5-1.5v-6H2z"/></svg>
            <span class="tooltip-meta-label">Deadline</span>
            <span class="tooltip-meta-value">{formatDeadline(hoveredNode.deadline)}</span>
          </div>
        {/if}
        {#if hoveredNode.tags.length > 0}
          <div class="tooltip-meta-row tooltip-tags-row">
            <svg class="tooltip-icon" viewBox="0 0 20 20" fill="currentColor"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v4.59a1.5 1.5 0 0 0 .44 1.06l7.5 7.5a1.5 1.5 0 0 0 2.12 0l4.59-4.59a1.5 1.5 0 0 0 0-2.12l-7.5-7.5A1.5 1.5 0 0 0 7.09 3H2.5zM5 6.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z"/></svg>
            <div class="tooltip-tags">
              {#each hoveredNode.tags.slice(0, 3) as tag}
                <span class="tooltip-tag">{tag}</span>
              {/each}
              {#if hoveredNode.tags.length > 3}
                <span class="tooltip-tag tooltip-tag-more">+{hoveredNode.tags.length - 3}</span>
              {/if}
            </div>
          </div>
        {/if}
      </div>
      <div class="tooltip-footer">
        <span class="tooltip-hint">Click to open project</span>
      </div>
    </div>
  {/if}

  <!-- Graph Controls -->
  <div class="graph-controls">
    <button class="graph-ctrl-btn" onclick={fitView} title="Fit all nodes in view">
      <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M3 3h4a.5.5 0 0 1 0 1H4v3a.5.5 0 0 1-1 0V3.5a.5.5 0 0 1 .5-.5H3zm10 0h3.5a.5.5 0 0 1 .5.5V7a.5.5 0 0 1-1 0V4h-3a.5.5 0 0 1 0-1zM3.5 13a.5.5 0 0 1 .5.5V16h3a.5.5 0 0 1 0 1H3.5a.5.5 0 0 1-.5-.5V13.5a.5.5 0 0 1 .5-.5zM17 13.5v3a.5.5 0 0 1-.5.5H13a.5.5 0 0 1 0-1h3v-2.5a.5.5 0 0 1 1 0z"/></svg>
    </button>
    <button class="graph-ctrl-btn" onclick={resetView} title="Reset zoom and pan">
      <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path d="M10 3a7 7 0 0 0-5.8 3.1l-1.5-1.5A.5.5 0 0 0 2 5v4.5a.5.5 0 0 0 .5.5H7a.5.5 0 0 0 .35-.85L5.8 7.6A5.5 5.5 0 1 1 4.5 10a.75.75 0 0 0-1.5 0A7 7 0 1 0 10 3z"/></svg>
    </button>
    <span class="graph-zoom-label">{getZoomPercent()}</span>
  </div>

  <!-- Legend -->
  <div class="graph-legend">
    <div class="legend-title">
      <svg viewBox="0 0 20 20" fill="currentColor" width="12" height="12"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
      Graph Legend
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
        Node Fill = Brand
      </span>
      <div class="legend-items">
        {#each Object.entries(brandColors) as [brand, color]}
          <span class="legend-swatch"><span class="swatch-dot" style="background:{color}"></span>{brand}</span>
        {/each}
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><circle cx="10" cy="10" r="6" stroke="currentColor" stroke-width="3" fill="none"/></svg>
        Border Ring = Status
      </span>
      <div class="legend-items">
        {#each [['in-progress','Active'],['review','Review'],['approved','Done'],['backlog','Backlog'],['on-hold','On Hold']] as [s, label]}
          <span class="legend-swatch"><span class="swatch-ring" style="border-color:{statusColors[s]}"></span>{label}</span>
        {/each}
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13zm0 1h13A1.5 1.5 0 0 1 18 5.5V12l-3.15-3.15a1.5 1.5 0 0 0-2.12 0l-5.23 5.23-1.65-1.65a1.5 1.5 0 0 0-2.12 0L2 14.15V5.5A1.5 1.5 0 0 1 3.5 4zm4.25 2.5a1.75 1.75 0 1 0 0 3.5 1.75 1.75 0 0 0 0-3.5z"/></svg>
        Icon = Media Type
      </span>
      <div class="legend-items">
        <span class="legend-swatch">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3.5 3A2.5 2.5 0 0 0 1 5.5v9A2.5 2.5 0 0 0 3.5 17h13a2.5 2.5 0 0 0 2.5-2.5v-9A2.5 2.5 0 0 0 16.5 3h-13zm0 1h13A1.5 1.5 0 0 1 18 5.5V12l-3.15-3.15a1.5 1.5 0 0 0-2.12 0l-5.23 5.23-1.65-1.65a1.5 1.5 0 0 0-2.12 0L2 14.15V5.5A1.5 1.5 0 0 1 3.5 4zm4.25 2.5a1.75 1.75 0 1 0 0 3.5 1.75 1.75 0 0 0 0-3.5z"/></svg>
          Print
        </span>
        <span class="legend-swatch">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M15 4a3 3 0 1 0-2.6 4.5l-5.3 2.65a3 3 0 0 0 0 1.7l5.3 2.65A3 3 0 1 0 15 14a3 3 0 0 0-.25-1.2l-5.3-2.65a3 3 0 0 0 0-.3l5.3-2.65A3 3 0 0 0 15 4z"/></svg>
          Social
        </span>
        <span class="legend-swatch">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3.5 4A2.5 2.5 0 0 0 1 6.5v7A2.5 2.5 0 0 0 3.5 16h8a2.5 2.5 0 0 0 2.5-2.5v-1.12l3.15 1.89A1 1 0 0 0 19 13.4V6.6a1 1 0 0 0-1.85-.87L14 7.62V6.5A2.5 2.5 0 0 0 11.5 4h-8z"/></svg>
          Video
        </span>
        <span class="legend-swatch">
          <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M3 3h4v4H3V3zm1 1v2h2V4H4zm9-1h4v4h-4V3zm1 1v2h2V4h-2zM3 13h4v4H3v-4zm1 1v2h2v-2H4zm9-1h4v4h-4v-4zm1 1v2h2v-2h-2zM7 4.5h6v1H7v-1zm0 10h6v1H7v-1zm-2.5-7v5h-1v-5h1zm11 0v5h-1v-5h1z"/></svg>
          Brand
        </span>
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">
        <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><circle cx="6" cy="10" r="4"/><circle cx="14" cy="10" r="2.5"/></svg>
        Node Size = Priority (larger = higher)
      </span>
    </div>
    <div class="legend-hint">
      <svg viewBox="0 0 20 20" fill="currentColor" width="10" height="10"><path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 4.25a.87.87 0 1 1 0 1.75.87.87 0 0 1 0-1.75zM10 9a.75.75 0 0 1 .75.75v4a.75.75 0 0 1-1.5 0v-4A.75.75 0 0 1 10 9z"/></svg>
      Scroll to zoom / Drag nodes / Click to open
    </div>
  </div>

  <!-- Graph Stats -->
  <div class="graph-stats">
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><circle cx="10" cy="10" r="5"/></svg>
      {nodes.length} projects
    </span>
    <span class="graph-stat-divider"></span>
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M2.5 3A1.5 1.5 0 0 0 1 4.5v3A1.5 1.5 0 0 0 2.5 9h3A1.5 1.5 0 0 0 7 7.5v-3A1.5 1.5 0 0 0 5.5 3h-3z"/></svg>
      {brandClusters.length} brands
    </span>
    <span class="graph-stat-divider"></span>
    <span class="graph-stat-item">
      <svg viewBox="0 0 20 20" fill="currentColor" width="11" height="11"><path d="M10 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"/></svg>
      {new Set(nodes.map(n => n.designer).filter(Boolean)).size} designers
    </span>
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

  /* ─── Rich HTML Tooltip ─── */
  .graph-tooltip {
    position: absolute;
    z-index: 100;
    background: var(--surface-card, rgba(15, 26, 58, 0.95));
    backdrop-filter: blur(16px);
    border: 1px solid var(--surface-card-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 12px);
    padding: 14px 16px 10px;
    min-width: 240px;
    max-width: 300px;
    pointer-events: none;
    box-shadow: var(--shadow-xl, 0 20px 28px -5px rgba(0,0,0,0.4));
    animation: tooltipFadeIn 0.15s ease-out;
  }

  @keyframes tooltipFadeIn {
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

  .tooltip-icon {
    width: 12px;
    height: 12px;
    min-width: 12px;
    color: var(--text-tertiary, rgba(255,255,255,0.35));
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

  .tooltip-status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    display: inline-block;
  }

  .tooltip-tags-row {
    margin-top: 2px;
    align-items: flex-start;
  }

  .tooltip-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 3px;
  }

  .tooltip-tag {
    display: inline-block;
    padding: 1px 6px;
    border-radius: var(--radius-pill, 9999px);
    font-size: 9.5px;
    font-weight: 600;
    background: var(--brand-tint, rgba(33, 161, 247, 0.1));
    color: var(--brand-accent, #21A1F7);
  }

  .tooltip-tag-more {
    background: rgba(255,255,255,0.06);
    color: var(--text-tertiary, rgba(255,255,255,0.4));
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

  /* ─── Graph Controls ─── */
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

  /* ─── Graph Stats ─── */
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

  .graph-stat-item svg {
    color: var(--brand-accent, #21A1F7);
  }

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
    max-width: 340px;
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

  .legend-title svg {
    color: var(--brand-accent, #21A1F7);
  }

  .legend-section {
    margin-bottom: 6px;
  }

  .legend-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-tertiary, rgba(255,255,255,0.4));
    display: flex;
    align-items: center;
    gap: 4px;
    margin-bottom: 3px;
  }

  .legend-label svg {
    color: var(--text-tertiary, rgba(255,255,255,0.35));
  }

  .legend-items {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .legend-swatch {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.55));
  }

  .legend-swatch svg {
    color: var(--text-secondary, rgba(255,255,255,0.5));
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

  .legend-hint svg {
    color: var(--text-tertiary, rgba(255,255,255,0.25));
  }
</style>

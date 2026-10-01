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

  let nodes: GraphNode[] = [];
  let edges: GraphEdge[] = [];

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

  const brandColors: Record<string, string> = {
    SS: '#043388',
    SSH: '#022057',
    SSC: '#0078D4',
    SSW: '#10B981',
    SSE: '#F59E0B',
    SST: '#8B5CF6'
  };

  const prioritySize: Record<string, number> = {
    P1: 24, P2: 20, P3: 16, P4: 14, P5: 12
  };

  function buildGraph() {
    const w = canvasEl?.width || 800;
    const h = canvasEl?.height || 600;
    const cx = w / 2;
    const cy = h / 2;

    nodes = projects.map((p, i) => {
      const angle = (i / Math.max(1, projects.length)) * Math.PI * 2;
      const spread = Math.min(w, h) * 0.35;
      return {
        id: p.id || p.jobId,
        label: p.title,
        jobId: p.jobId,
        brand: p.brand || 'SS',
        designer: p.designer || '',
        status: p.status || 'backlog',
        priority: p.priority || 'P3',
        mediaType: p.presetType || '',
        x: cx + Math.cos(angle) * spread * (0.5 + Math.random() * 0.5),
        y: cy + Math.sin(angle) * spread * (0.5 + Math.random() * 0.5),
        vx: 0,
        vy: 0,
        radius: prioritySize[p.priority] || 16,
        color: brandColors[p.brand] || '#043388',
        borderColor: statusColors[p.status] || '#6B7280'
      };
    });

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
    // Connect nodes that share the same brand (lighter)
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        if (nodes[i].brand && nodes[i].brand === nodes[j].brand && nodes[i].designer !== nodes[j].designer) {
          edges.push({
            source: nodes[i],
            target: nodes[j],
            type: 'brand',
            color: 'rgba(255, 255, 255, 0.025)'
          });
        }
      }
    }
  }

  function simulate() {
    const centerX = (canvasEl?.width || 800) / 2;
    const centerY = (canvasEl?.height || 600) / 2;

    // Force simulation
    for (const node of nodes) {
      if (draggedNode === node) continue;

      // Gravity toward center
      node.vx += (centerX - node.x) * 0.0003;
      node.vy += (centerY - node.y) * 0.0003;

      // Repulsion between all nodes
      for (const other of nodes) {
        if (other === node) continue;
        const dx = node.x - other.x;
        const dy = node.y - other.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const minDist = node.radius + other.radius + 30;
        if (dist < minDist * 3) {
          const force = (minDist / dist) * 0.8;
          node.vx += (dx / dist) * force;
          node.vy += (dy / dist) * force;
        }
      }
    }

    // Edge attraction (spring)
    for (const edge of edges) {
      const dx = edge.target.x - edge.source.x;
      const dy = edge.target.y - edge.source.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const idealDist = edge.type === 'designer' ? 120 : 200;
      const force = (dist - idealDist) * 0.0008;

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
      node.vx *= 0.88;
      node.vy *= 0.88;
      node.x += node.vx;
      node.y += node.vy;
    }
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

    // Draw edges
    for (const edge of edges) {
      const isHighlighted = hoveredNode && (edge.source === hoveredNode || edge.target === hoveredNode);
      ctx.beginPath();
      ctx.moveTo(edge.source.x, edge.source.y);
      ctx.lineTo(edge.target.x, edge.target.y);
      ctx.strokeStyle = isHighlighted
        ? (edge.type === 'designer' ? 'rgba(33, 161, 247, 0.35)' : 'rgba(189, 154, 115, 0.25)')
        : edge.color;
      ctx.lineWidth = isHighlighted ? 1.5 : 0.5;
      ctx.stroke();
    }

    // Draw nodes
    for (const node of nodes) {
      const isHovered = hoveredNode === node;
      const isConnected = hoveredNode && edges.some(e =>
        (e.source === hoveredNode && e.target === node) ||
        (e.target === hoveredNode && e.source === node)
      );
      const dimmed = hoveredNode && !isHovered && !isConnected;

      const r = isHovered ? node.radius * 1.3 : node.radius;
      const alpha = dimmed ? 0.15 : 1;

      // Glow
      if (isHovered) {
        ctx.beginPath();
        ctx.arc(node.x, node.y, r + 8, 0, Math.PI * 2);
        ctx.fillStyle = `${node.borderColor}33`;
        ctx.fill();
      }

      // Node circle
      ctx.beginPath();
      ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
      ctx.fillStyle = alpha < 1 ? `${node.color}26` : node.color;
      ctx.fill();
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = alpha < 1 ? `${node.borderColor}26` : node.borderColor;
      ctx.stroke();

      // Label
      if (isHovered || r >= 16) {
        ctx.font = `${isHovered ? '700' : '600'} ${isHovered ? 11 : 9}px "Segoe UI", Inter, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        ctx.fillStyle = alpha < 1 ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.85)';
        const label = node.jobId.length > 14 ? node.jobId.substring(0, 14) + '…' : node.jobId;
        ctx.fillText(label, node.x, node.y + r + 4);
      }

      // Hovered tooltip info
      if (isHovered) {
        ctx.font = '600 10px "Segoe UI", Inter, sans-serif';
        ctx.fillStyle = 'rgba(255,255,255,0.65)';
        const titleText = node.label.length > 28 ? node.label.substring(0, 28) + '…' : node.label;
        ctx.fillText(titleText, node.x, node.y + r + 17);
        ctx.font = '500 9px "Segoe UI", Inter, sans-serif';
        ctx.fillStyle = 'rgba(255,255,255,0.4)';
        ctx.fillText(`${node.brand} · ${node.designer} · ${node.status}`, node.x, node.y + r + 29);
      }
    }

    ctx.restore();
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
    // Reverse order so topmost node is picked
    for (let i = nodes.length - 1; i >= 0; i--) {
      const n = nodes[i];
      const dx = wx - n.x;
      const dy = wy - n.y;
      if (dx * dx + dy * dy <= (n.radius + 4) * (n.radius + 4)) return n;
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

  function handleMouseUp(e: MouseEvent) {
    if (draggedNode && !isDragging) {
      // Click — navigate to project
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
    const newZoom = Math.max(0.2, Math.min(4, zoom * factor));

    // Zoom toward mouse position
    camX = mx - ((mx - camX) / zoom) * newZoom;
    camY = my - ((my - camY) / zoom) * newZoom;
    zoom = newZoom;
  }

  function resizeCanvas() {
    if (!canvasEl || !containerEl) return;
    canvasEl.width = containerEl.clientWidth;
    canvasEl.height = containerEl.clientHeight;
  }

  onMount(() => {
    resizeCanvas();
    buildGraph();
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

  <!-- Legend -->
  <div class="graph-legend">
    <div class="legend-title">Graph Legend</div>
    <div class="legend-section">
      <span class="legend-label">Node Fill = Brand</span>
      <div class="legend-items">
        {#each Object.entries(brandColors) as [brand, color]}
          <span class="legend-swatch"><span class="swatch-dot" style="background:{color}"></span>{brand}</span>
        {/each}
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">Node Border = Status</span>
      <div class="legend-items">
        {#each [['in-progress','Active'],['review','Review'],['approved','Done'],['backlog','Backlog']] as [s, label]}
          <span class="legend-swatch"><span class="swatch-dot" style="background:{statusColors[s]}"></span>{label}</span>
        {/each}
      </div>
    </div>
    <div class="legend-section">
      <span class="legend-label">Node Size = Priority (P1 largest)</span>
    </div>
    <div class="legend-hint">Scroll to zoom · Drag nodes · Click to open</div>
  </div>
</div>

<style>
  .graph-container {
    position: relative;
    width: 100%;
    height: calc(100vh - 240px);
    min-height: 500px;
    background: #0B1120;
    border-radius: 12px;
    border: 1px solid rgba(255,255,255,0.08);
    overflow: hidden;
  }

  .graph-canvas {
    width: 100%;
    height: 100%;
    display: block;
  }

  .graph-legend {
    position: absolute;
    bottom: 16px;
    left: 16px;
    background: rgba(11, 17, 32, 0.88);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 12px 16px;
    max-width: 320px;
    pointer-events: none;
  }

  .legend-title {
    font-size: 11px;
    font-weight: 800;
    color: rgba(255,255,255,0.6);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
  }

  .legend-section {
    margin-bottom: 6px;
  }

  .legend-label {
    font-size: 10px;
    font-weight: 700;
    color: rgba(255,255,255,0.4);
    display: block;
    margin-bottom: 3px;
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
    color: rgba(255,255,255,0.55);
  }

  .swatch-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }

  .legend-hint {
    font-size: 9.5px;
    color: rgba(255,255,255,0.3);
    margin-top: 8px;
    font-style: italic;
  }
</style>

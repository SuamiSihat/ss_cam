<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { ApiClient } from '$lib/services/api';
  import { appState } from '$lib/stores/appState.svelte';

  interface UserProfile {
    username: string;
    name: string;
    staffId: string;
    role: string;
  }

  // Active Subsidiaries Configuration
  // Represents SuamiSihat entities (Holding, Healthcare, Wellness, E-Commerce, Technology)
  // Dynamically fetched from Company Manager API!
  let subsidiaryList = $state<any[]>([
    { code: 'SSH', name: 'SuamiSihat Holding Sdn Bhd' },
    { code: 'SSC', name: 'SuamiSihat Healthcare Sdn Bhd' },
    { code: 'SSW', name: 'SuamiSihat Wellness Sdn Bhd' },
    { code: 'SSE', name: 'SuamiSihat E-Commerce Sdn Bhd' },
    { code: 'SST', name: 'SuamiSihat Technology Sdn Bhd' }
  ]);

  const defaultStaffList: UserProfile[] = [
    { username: 'harussani', name: 'Harussani', staffId: 'SS0004', role: 'Head of Creative' },
    { username: 'haikal', name: 'Haikal', staffId: 'SS0035', role: 'Multimedia Designer' },
    { username: 'aliff', name: 'Aliff', staffId: 'SS0037', role: 'Multimedia Designer' },
    { username: 'raihan', name: 'Raihan', staffId: 'SS0073', role: 'Head of Marketing & Sale' },
    { username: 'hasan', name: 'Hasan', staffId: 'SS0001', role: 'Chief Executive Officer' },
    { username: 'gaddafi', name: 'Gaddafi', staffId: 'SS0071', role: 'Co-Chief Executive Officer' }
  ];

  let staffProfiles = $state<UserProfile[]>(defaultStaffList);

  // Guaranteed sorted by Staff ID Descending (SS0073 -> SS0071 -> SS0037 -> ... -> SS0001)
  const sortedUsers = $derived.by<UserProfile[]>(() =>
    [...staffProfiles].sort((a, b) => (b.staffId || '').localeCompare(a.staffId || ''))
  );

  // Remember Me state initialization
  const isRemembered = typeof localStorage !== 'undefined' && localStorage.getItem('ss_cam_remember_me') === 'true';
  const savedUser = typeof localStorage !== 'undefined' ? localStorage.getItem('ss_cam_remember_user') : null;

  // Recent Active Logins (Dynamic, strictly limited to 3)
  function getStoredRecentUsers(): string[] {
    if (typeof localStorage === 'undefined') return ['harussani', 'haikal', 'aliff'];
    try {
      const stored = JSON.parse(localStorage.getItem('ss_cam_recent_users') || '[]');
      if (Array.isArray(stored) && stored.length > 0) {
        return stored.slice(0, 3);
      }
    } catch {}
    return ['harussani', 'haikal', 'aliff'];
  }

  let recentUsernames = $state<string[]>(getStoredRecentUsers());
  let recentProfiles = $derived.by<UserProfile[]>(() => {
    const list: UserProfile[] = [];
    for (const uName of recentUsernames) {
      const profile = staffProfiles.find((p) => p.username === uName || p.staffId === uName);
      if (profile && !list.some((p) => p.username === profile.username)) {
        list.push(profile);
      }
    }
    // Fill up to 3 from sortedUsers if less than 3
    if (list.length < 3) {
      for (const p of sortedUsers) {
        if (!list.some((item) => item.username === p.username)) {
          list.push(p);
        }
        if (list.length >= 3) break;
      }
    }
    return list.slice(0, 3);
  });

  let rememberMe = $state<boolean>(isRemembered);
  let username = $state<string>(savedUser || sortedUsers[0]?.username || 'harussani');
  let password = $state<string>('');
  let showPassword = $state<boolean>(false);
  let isLoading = $state<boolean>(false);
  let errorMessage = $state<string | null>(null);

  let showForgotModal = $state<boolean>(false);
  let forgotUsername = $state<string>('');
  let forgotStatus = $state<string | null>(null);
  let forgotLoading = $state<boolean>(false);

  let canvasEl: HTMLCanvasElement | null = $state(null);
  let animFrameId: number | null = null;
  let resizeListener: (() => void) | null = null;
  let brandLogoImg: HTMLImageElement | null = null;

  onMount(async () => {
    // Preload brand logo for canvas drawing
    brandLogoImg = new Image();
    brandLogoImg.src = 'brand/ss-logomark-full.png';

    // Fetch live staff roster dynamically from Synology NAS / Server API
    try {
      const rosterRes = await ApiClient.getAuthRoster();
      if (rosterRes && rosterRes.staff && Array.isArray(rosterRes.staff) && rosterRes.staff.length > 0) {
        staffProfiles = rosterRes.staff.map((s: any) => ({
          username: s.username,
          name: s.name,
          staffId: s.staffId,
          role: s.role
        }));
        if (!savedUser && staffProfiles.length > 0) {
          username = staffProfiles[0].username;
        }
      }
    } catch (e) {
      console.warn('[LoginView] Failed to fetch live auth roster, using defaults:', e);
    }

    // Fetch active companies to dynamically set floating brand logos count
    try {
      const res = await ApiClient.getCompanies();
      if (res && res.companies && res.companies.length > 0) {
        subsidiaryList = res.companies.filter((c: any) => c.status === 'active');
      }
    } catch {}

    initHeroWaveCanvas();
  });

  onDestroy(() => {
    if (animFrameId) cancelAnimationFrame(animFrameId);
    if (resizeListener) window.removeEventListener('resize', resizeListener);
  });

  function updateRecentUsers(loggedUser: string) {
    const updated = [loggedUser, ...recentUsernames.filter((u) => u !== loggedUser)].slice(0, 3);
    recentUsernames = updated;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ss_cam_recent_users', JSON.stringify(updated));
    }
  }

  function initHeroWaveCanvas() {
    if (!canvasEl) return;
    const ctx = canvasEl.getContext('2d');
    if (!ctx) return;

    let width = (canvasEl.width = window.innerWidth);
    let height = (canvasEl.height = window.innerHeight);
    let step = 0;

    interface Particle {
      x: number;
      y: number;
      vx: number;
      vy: number;
      size: number;
      alpha: number;
      rotation: number;
      vRot: number;
      type: 'brand_logo' | 'men' | 'shards';
    }

    let particles: Particle[] = [];

    const initParticles = () => {
      particles = [];

      // 1. Dedicated Floating SuamiSihat Brand Logos (Matching exact count of active subsidiaries)
      const subCount = Math.max(1, subsidiaryList.length);
      for (let i = 0; i < subCount; i++) {
        particles.push({
          x: (width / (subCount + 1)) * (i + 1) + (Math.random() - 0.5) * 60,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.45,
          vy: -Math.random() * 0.45 - 0.25, // gentle upward drift
          size: Math.random() * 8 + 24, // 24px to 32px
          alpha: Math.random() * 0.35 + 0.35,
          rotation: (Math.random() - 0.5) * 0.3,
          vRot: (Math.random() - 0.5) * 0.012,
          type: 'brand_logo'
        });
      }

      // 2. Standard Background Particles (Men's Symbols & Shards)
      const numBgParticles = Math.min(35, Math.floor(width / 30));
      for (let i = 0; i < numBgParticles; i++) {
        particles.push({
          x: Math.random() * width,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.6,
          vy: -Math.random() * 0.5 - 0.2,
          size: Math.random() * 12 + 8,
          alpha: Math.random() * 0.4 + 0.15,
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.02,
          type: Math.random() > 0.45 ? 'men' : 'shards'
        });
      }
    };

    const resizeCanvas = () => {
      if (!canvasEl) return;
      width = canvasEl.width = window.innerWidth;
      height = canvasEl.height = window.innerHeight;
      initParticles();
    };

    resizeListener = resizeCanvas;
    window.addEventListener('resize', resizeCanvas);
    initParticles();

    const drawBrandLogo = (
      c: CanvasRenderingContext2D,
      x: number,
      y: number,
      size: number,
      alpha: number,
      rotation: number
    ) => {
      c.save();
      c.translate(x, y);
      c.rotate(rotation);

      if (brandLogoImg && brandLogoImg.complete && brandLogoImg.naturalWidth > 0) {
        c.globalAlpha = Math.min(1, alpha * 1.3);
        const aspect = brandLogoImg.naturalWidth / brandLogoImg.naturalHeight;
        const h = size * 1.35;
        const w = h * aspect;
        c.drawImage(brandLogoImg, -w / 2, -h / 2, w, h);
      } else {
        // High-fidelity fallback badge
        c.strokeStyle = `rgba(33, 161, 247, ${alpha})`;
        c.fillStyle = `rgba(4, 51, 136, ${alpha * 0.7})`;
        c.lineWidth = 1.6;
        const r = size * 0.45;
        c.beginPath();
        c.arc(0, 0, r, 0, Math.PI * 2);
        c.fill();
        c.stroke();

        c.fillStyle = `rgba(33, 161, 247, ${Math.min(1, alpha * 1.5)})`;
        c.font = `900 ${size * 0.4}px Segoe UI, sans-serif`;
        c.textAlign = 'center';
        c.textBaseline = 'middle';
        c.fillText('SS', 0, 0);
      }

      c.restore();
    };

    const drawMenSymbol = (
      c: CanvasRenderingContext2D,
      x: number,
      y: number,
      size: number,
      alpha: number,
      rotation: number
    ) => {
      c.save();
      c.translate(x, y);
      c.rotate(rotation);
      c.strokeStyle = `rgba(33, 161, 247, ${alpha})`;
      c.lineWidth = 1.8;

      const r = size * 0.35;
      c.beginPath();
      c.arc(0, r * 0.4, r, 0, Math.PI * 2);
      c.stroke();

      const arrowLen = size * 0.6;
      const startX = r * 0.7;
      const startY = -r * 0.3;
      const endX = startX + arrowLen * 0.7;
      const endY = startY - arrowLen * 0.7;

      c.beginPath();
      c.moveTo(startX, startY);
      c.lineTo(endX, endY);
      c.stroke();

      const headLen = size * 0.25;
      c.beginPath();
      c.moveTo(endX - headLen, endY);
      c.lineTo(endX, endY);
      c.lineTo(endX, endY + headLen);
      c.stroke();

      c.restore();
    };

    const drawShard = (
      c: CanvasRenderingContext2D,
      x: number,
      y: number,
      size: number,
      alpha: number,
      rotation: number
    ) => {
      c.save();
      c.translate(x, y);
      c.rotate(rotation);
      c.fillStyle = `rgba(189, 154, 115, ${alpha * 0.7})`;

      c.beginPath();
      c.moveTo(0, -size / 2);
      c.lineTo(size / 3, size / 2);
      c.lineTo(-size / 3, size / 2);
      c.closePath();
      c.fill();

      c.restore();
    };

    const animate = () => {
      ctx.clearRect(0, 0, width, height);

      // Background sine wave layers
      step += 0.012;
      const waves = [
        { color: 'rgba(33, 161, 247, 0.14)', speed: 0.8, amp: 35, freq: 0.008, yRatio: 0.6 },
        { color: 'rgba(109, 198, 236, 0.10)', speed: 1.2, amp: 25, freq: 0.01, yRatio: 0.55 },
        { color: 'rgba(189, 154, 115, 0.08)', speed: 0.5, amp: 45, freq: 0.006, yRatio: 0.65 }
      ];

      waves.forEach((w) => {
        // Filled Wave Silhouette
        ctx.beginPath();
        ctx.moveTo(0, height);
        for (let x = 0; x <= width; x += 10) {
          const y = Math.sin(x * w.freq + step * w.speed) * w.amp + height * w.yRatio;
          ctx.lineTo(x, y);
        }
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = w.color;
        ctx.fill();

        // Wave Line Stroke
        ctx.beginPath();
        ctx.strokeStyle = w.color.replace(/0\.\d+/, '0.30');
        ctx.lineWidth = 1.5;
        for (let x = 0; x <= width; x += 10) {
          const y = Math.sin(x * w.freq + step * w.speed) * w.amp + height * w.yRatio;
          if (x === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
      });

      // Update & Draw Floating Particles
      particles.forEach((p) => {
        p.x += p.vx;
        p.y += p.vy;
        p.rotation += p.vRot;

        if (p.y < -40) {
          p.y = height + 40;
          p.x = Math.random() * width;
        }
        if (p.x < -40) p.x = width + 40;
        if (p.x > width + 40) p.x = -40;

        if (p.type === 'brand_logo') {
          drawBrandLogo(ctx, p.x, p.y, p.size, p.alpha, p.rotation);
        } else if (p.type === 'men') {
          drawMenSymbol(ctx, p.x, p.y, p.size, p.alpha, p.rotation);
        } else {
          drawShard(ctx, p.x, p.y, p.size, p.alpha, p.rotation);
        }
      });

      animFrameId = requestAnimationFrame(animate);
    };

    animate();
  }

  async function handleLogin(e?: Event) {
    if (e) e.preventDefault();
    isLoading = true;
    errorMessage = null;

    try {
      const res = await ApiClient.login(username, password);
      if (res.success && res.token) {
        // Handle Remember Me persistence
        if (rememberMe) {
          localStorage.setItem('ss_cam_remember_me', 'true');
          localStorage.setItem('ss_cam_remember_user', username);
        } else {
          localStorage.removeItem('ss_cam_remember_me');
          localStorage.removeItem('ss_cam_remember_user');
        }

        // Update Recent Active Users (Top 3)
        updateRecentUsers(username);

        ApiClient.setToken(res.token);
        appState.currentUser = res.user;
        appState.addToast(`Welcome back, ${res.user.name}! (${res.user.role})`, 'success');
        appState.navigate('dashboard');
      }
    } catch (err: any) {
      errorMessage = err.message || 'Invalid username or password.';
    } finally {
      isLoading = false;
    }
  }

  async function handleForgotPassword() {
    if (!forgotUsername.trim()) return;
    forgotLoading = true;
    forgotStatus = null;
    try {
      await ApiClient.request('/auth/forgot-password', {
        method: 'POST',
        body: JSON.stringify({ username: forgotUsername.trim() })
      });
      forgotStatus = 'success';
    } catch (err: any) {
      forgotStatus = 'error';
    } finally {
      forgotLoading = false;
    }
  }

  function selectUser(user: string) {
    username = user;
    // Focus password field so user can type their password, do not auto-submit
    const pwField = document.getElementById('login-password-field');
    if (pwField) (pwField as HTMLInputElement).focus();
  }
</script>

<div class="login-hero-bg" id="login-hero-viewport">
  <!-- Animated Background Canvas -->
  <canvas bind:this={canvasEl} class="hero-wave-canvas" id="heroWaveCanvas"></canvas>

  <!-- Ambient Radial Glow -->
  <div class="login-ambient-glow"></div>

  <!-- Static Glassmorphism Card -->
  <div class="login-card-static">
    <!-- Official SuamiSihat Logo Header -->
    <div class="card-header-logo">
      <img src="brand/ss-logomark-full.png" alt="SuamiSihat Logo" class="brand-logo-img" />
    </div>

    <h1 class="portal-heading">SuamiSihat Creative Portal</h1>
    <p class="portal-subheading">Production Management & Creative Assets System</p>

    <div role="alert" aria-live="assertive" aria-atomic="true" id="login-error-region" class={errorMessage ? 'login-error-alert' : 'login-error-hidden'} aria-hidden={errorMessage ? 'false' : 'true'}>
      {#if errorMessage}{errorMessage}{/if}
    </div>

    <form onsubmit={handleLogin} class="login-form-body">
      <!-- User Profile Selector (Sorted by Staff ID Descending) -->
      <div class="form-group">
        <label for="login-account-select" class="field-label">Select Account Profile (Staff ID ↓)</label>
        <select id="login-account-select" class="field-select" bind:value={username} autocomplete="username">
          {#each sortedUsers as u}
            <option value={u.username}>
              {u.staffId} — {u.name}
            </option>
          {/each}
        </select>
      </div>

      <!-- Password Field -->
      <div class="form-group">
        <label for="login-password-field" class="field-label">Password</label>
        <div class="password-input-wrapper">
          <input
            id="login-password-field"
            type={showPassword ? 'text' : 'password'}
            class="field-input"
            bind:value={password}
            placeholder="Enter password"
            autocomplete="current-password"
            aria-invalid={errorMessage ? 'true' : 'false'}
            aria-describedby="login-error-region"
          />
          <button
            type="button"
            class="eye-btn"
            onclick={() => (showPassword = !showPassword)}
            title="Toggle Password Visibility"
          >
            {#if showPassword}
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
            {:else}
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
            {/if}
          </button>
        </div>
      </div>

      <!-- Remember Me Checkbox -->
      <div class="remember-row">
        <label class="remember-label">
          <input type="checkbox" bind:checked={rememberMe} class="fluent-checkbox" />
          <span>Remember me on this device</span>
        </label>
      </div>

      <div class="forgot-row">
        <button type="button" class="forgot-link" onclick={() => { showForgotModal = true; forgotUsername = username; forgotStatus = null; }}>
          Forgot password?
        </button>
      </div>

      <button type="submit" class="submit-btn" disabled={isLoading}
        aria-label={isLoading ? 'Authenticating, please wait' : 'Sign In to Portal'}>
        {#if isLoading}
          <span>Authenticating...</span>
        {:else}
          <span>Sign In to Portal</span>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
        {/if}
      </button>


    </form>

    <!-- Forgot Password Modal -->
    {#if showForgotModal}
      <div class="forgot-modal-backdrop" role="dialog" aria-modal="true" aria-label="Reset Password Request" onclick={(e) => { if (e.target === e.currentTarget) showForgotModal = false; }}>
        <div class="forgot-modal-card">
          <button class="forgot-modal-close" onclick={() => (showForgotModal = false)} aria-label="Close">&#x2715;</button>
          <div class="forgot-modal-icon">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#043388" stroke-width="1.8"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/></svg>
          </div>
          <h3 class="forgot-modal-title">Reset Password Request</h3>
          {#if forgotStatus === 'success'}
            <div class="forgot-success">
              <strong>Request sent!</strong><br/>
              Your administrator has been notified via the Audit Log.<br/>
              Ask <strong>Harussani</strong> to reset your password to the default from <em>Admin Panel → Staff → Reset to Default</em>.
            </div>
          {:else}
            <p class="forgot-modal-desc">Enter your username and we'll log a reset request for the administrator.</p>
            <div class="forgot-modal-field">
              <label class="field-label" for="forgot-username-input">Your Username</label>
              <input
                id="forgot-username-input"
                type="text"
                class="field-input"
                bind:value={forgotUsername}
                placeholder="e.g. harussani"
                autocomplete="username"
              />
            </div>
            {#if forgotStatus === 'error'}
              <div class="login-error-alert" role="alert">Request failed. Please contact your administrator directly.</div>
            {/if}
            <button class="submit-btn" disabled={forgotLoading} onclick={handleForgotPassword} type="button">
              {forgotLoading ? 'Sending...' : 'Send Reset Request'}
            </button>
            <p class="forgot-hint">
              Default password after reset: <code>SuamiSihat123!</code>
            </p>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Official 2026 Brand Footer -->
    <div class="portal-footer-meta">
      2026® SuamiSihat Holding Sdn Bhd • Creative-Team
    </div>
  </div>
</div>

<style>
  @keyframes fAmbientPulse {
    0% { opacity: 0.6; transform: translateX(-50%) scale(0.95); }
    100% { opacity: 1; transform: translateX(-50%) scale(1.1); }
  }

  .login-hero-bg {
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(180deg, #022057 0%, #043388 60%, #021233 100%);
    overflow: hidden;
    z-index: 1000;
  }

  .hero-wave-canvas {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 0;
    opacity: 0.75;
  }

  .login-ambient-glow {
    position: absolute;
    inset: 0;
    pointer-events: none;
    overflow: hidden;
    z-index: 1;
  }

  .login-ambient-glow::before {
    content: '';
    position: absolute;
    top: -20%;
    left: 50%;
    transform: translateX(-50%);
    width: 800px;
    height: 500px;
    background: radial-gradient(ellipse at center, rgba(33, 161, 247, 0.22) 0%, rgba(4, 51, 136, 0.15) 50%, transparent 75%);
    filter: blur(60px);
    animation: fAmbientPulse 8s ease-in-out infinite alternate;
  }

  .login-card-static {
    width: 100%;
    max-width: 440px;
    padding: 34px 32px;
    border-radius: 20px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(24px) saturate(180%);
    -webkit-backdrop-filter: blur(24px) saturate(180%);
    border: 1px solid rgba(255, 255, 255, 0.6);
    box-shadow: 0 24px 60px rgba(2, 32, 87, 0.45), 0 0 40px rgba(33, 161, 247, 0.25);
    position: relative;
    z-index: 10;
    text-align: center;
  }

  /* .card-header-logo-interactive removed - logo click trap eliminated (WCAG 2.1.1) */
  .card-header-logo {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 12px;
    cursor: pointer;
    transition: transform 0.3s cubic-bezier(0.1, 0.9, 0.2, 1.0), filter 0.3s ease;
  }

  .card-header-logo-interactive:hover {
    transform: scale(1.08) rotate(-3deg);
    filter: drop-shadow(0 8px 25px rgba(33, 161, 247, 0.65));
  }

  .brand-logo-img {
    height: 64px;
    width: auto;
    object-fit: contain;
    filter: drop-shadow(0 4px 10px rgba(2, 32, 87, 0.2));
  }

  .portal-heading {
    font-size: 22px;
    font-weight: 900;
    color: #022057;
    margin: 0;
    letter-spacing: -0.3px;
  }

  .portal-subheading {
    font-size: 13px;
    color: #575756;
    margin-top: 5px;
    margin-bottom: 18px;
    font-weight: 500;
  }

  .login-error-alert {
    padding: 10px 14px;
    border-radius: 8px;
    background: #FEF2F2;
    border: 1px solid #FCA5A5;
    color: #B91C1C; /* WCAG 1.4.3: ratio 6.1:1 on #FEF2F2 */
    font-size: 12.5px;
    font-weight: 600;
    margin-bottom: 18px;
    text-align: left;
  }

  .login-error-hidden {
    display: none;
  }

  .login-form-body {
    display: flex;
    flex-direction: column;
    gap: 14px;
    text-align: left;
  }

  .field-label {
    font-weight: 700;
    color: #022057;
    font-size: 13px;
    display: block;
    margin-bottom: 6px;
  }

  .field-select,
  .field-input {
    width: 100%;
    height: 42px;
    padding: 0 12px;
    font-family: inherit;
    font-size: 13.5px;
    font-weight: 600;
    border-radius: 8px;
    border: 1px solid #CCCCCC;
    background: #FFFFFF;
    color: #1A1A1A;
    outline: none;
    transition: border-color 0.2s;
  }

  .field-select:focus,
  .field-input:focus {
    border-color: #0078D4;
    outline: 2px solid #0078D4; /* WCAG 2.4.7: solid focus ring, not invisible box-shadow */
    outline-offset: 2px;
    box-shadow: none;
  }

  .password-input-wrapper {
    position: relative;
  }

  .password-input-wrapper .field-input {
    padding-right: 40px;
  }

  .eye-btn {
    position: absolute;
    right: 4px;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    color: #666666;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 11px; /* WCAG 2.5.8: minimum 44x44px touch target */
    min-width: 44px;
    min-height: 44px;
  }
  .eye-btn:hover { color: #043388; }

  /* Remember Me */
  .remember-row {
    display: flex;
    align-items: center;
    margin: -2px 0 2px 0;
  }

  .remember-label {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 12.5px;
    color: #475569;
    cursor: pointer;
    user-select: none;
  }

  .fluent-checkbox {
    width: 16px;
    height: 16px;
    accent-color: #043388;
    cursor: pointer;
  }

  .submit-btn {
    width: 100%;
    height: 44px;
    font-size: 14.5px;
    font-weight: 800;
    background: linear-gradient(90deg, #022057 0%, #043388 50%, #21A1F7 100%);
    color: #FFFFFF;
    border: none;
    border-radius: 10px;
    box-shadow: 0 4px 16px rgba(4, 51, 136, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    cursor: pointer;
    transition: transform 0.15s, box-shadow 0.15s;
    margin-top: 4px;
  }

  .submit-btn:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 6px 20px rgba(33, 161, 247, 0.45);
  }

  .submit-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .quick-roster-section {
    margin-top: 14px;
    padding-top: 14px;
    border-top: 1px solid rgba(0, 0, 0, 0.08);
  }

  .roster-title {
    font-size: 11px;
    font-weight: 700;
    color: #666666;
    text-transform: uppercase;
    display: block;
    margin-bottom: 8px;
  }

  .roster-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .roster-chip {
    background: #F1F5F9;
    border: 1px solid #CBD5E1;
    border-radius: 9999px;
    padding: 4px 10px;
    font-size: 11.5px;
    font-weight: 600;
    color: #334155;
    cursor: pointer;
    transition: all 0.15s;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .roster-chip:hover {
    color: #043388;
    border-color: #21A1F7;
    background: #EBF4FE;
  }

  .chip-id {
    font-family: monospace;
    color: #043388;
    font-weight: 800;
    font-size: 11px;
  }

  /* Forgot Password Link */
  .forgot-row {
    display: flex;
    justify-content: flex-end;
    margin: -6px 0 2px 0;
  }

  .forgot-link {
    background: none;
    border: none;
    color: #043388;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    padding: 2px 0;
    text-decoration: underline;
    text-underline-offset: 2px;
  }
  .forgot-link:hover { color: #21A1F7; }

  /* Forgot Password Modal */
  .forgot-modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 999;
  }

  .forgot-modal-card {
    background: #FFFFFF;
    border-radius: 16px;
    padding: 32px 28px 24px;
    width: 340px;
    max-width: 90vw;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    position: relative;
    text-align: center;
  }

  .forgot-modal-close {
    position: absolute;
    top: 12px;
    right: 14px;
    background: none;
    border: none;
    font-size: 16px;
    cursor: pointer;
    color: #94A3B8;
    padding: 4px 8px;
    border-radius: 4px;
  }
  .forgot-modal-close:hover { color: #1E293B; background: #F1F5F9; }\n
  .forgot-modal-icon {
    display: flex;
    justify-content: center;
    margin-bottom: 12px;
  }

  .forgot-modal-title {
    font-size: 17px;
    font-weight: 800;
    color: #022057;
    margin: 0 0 8px;
  }

  .forgot-modal-desc {
    font-size: 13px;
    color: #475569;
    margin: 0 0 16px;
    line-height: 1.5;
  }

  .forgot-modal-field {
    text-align: left;
    margin-bottom: 14px;
  }

  .forgot-hint {
    font-size: 11.5px;
    color: #64748B;
    margin-top: 12px;
    line-height: 1.5;
  }
  .forgot-hint code {
    background: #F1F5F9;
    padding: 1px 5px;
    border-radius: 4px;
    font-size: 11px;
    color: #043388;
    font-weight: 700;
  }

  .forgot-success {
    background: #F0FDF4;
    border: 1px solid #86EFAC;
    color: #166534;
    border-radius: 8px;
    padding: 14px;
    font-size: 13px;
    line-height: 1.6;
    text-align: left;
    margin: 8px 0;
  }

  .portal-footer-meta {
    margin-top: 22px;
    text-align: center;
    font-size: 11.5px;
    font-weight: 600;
    color: #666666;
    border-top: 1px solid rgba(0, 0, 0, 0.08);
    padding-top: 14px;
    line-height: 1.6;
  }
</style>

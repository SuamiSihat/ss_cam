/**
 * SS-CAM Product Landing Page — Art Director Edition
 * Minimalist Particle Canvas & Interactive Module Switcher
 */

document.addEventListener('DOMContentLoaded', () => {

  // ── 1. Animated Hero Ambient Canvas (Waves + Shards + Men Symbols) ────────
  const canvas = document.getElementById('heroWaveCanvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let width, height;
    let particles = [];
    let step = 0;

    function resizeCanvas() {
      width = canvas.width = canvas.parentElement.offsetWidth;
      height = canvas.height = canvas.parentElement.offsetHeight;
      initParticles();
    }

    function initParticles() {
      particles = [];
      const numParticles = Math.min(36, Math.floor(width / 32));
      for (let i = 0; i < numParticles; i++) {
        particles.push({
          x: Math.random() * width,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.4,
          vy: -Math.random() * 0.35 - 0.15,
          size: Math.random() * 10 + 6,
          alpha: Math.random() * 0.35 + 0.1,
          rotation: Math.random() * Math.PI * 2,
          vRot: (Math.random() - 0.5) * 0.015,
          type: Math.random() > 0.5 ? 'men' : 'shards'
        });
      }
    }

    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    function drawMenSymbol(ctx, x, y, size, alpha, rotation) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rotation);
      ctx.strokeStyle = `rgba(33, 161, 247, ${alpha})`;
      ctx.lineWidth = 1.6;
      const r = size * 0.35;
      ctx.beginPath();
      ctx.arc(0, r * 0.4, r, 0, Math.PI * 2);
      ctx.stroke();
      const arrowLen = size * 0.6;
      const startX = r * 0.7;
      const startY = -r * 0.3;
      const endX = startX + arrowLen * 0.7;
      const endY = startY - arrowLen * 0.7;
      ctx.beginPath();
      ctx.moveTo(startX, startY);
      ctx.lineTo(endX, endY);
      ctx.stroke();
      const headLen = size * 0.25;
      ctx.beginPath();
      ctx.moveTo(endX - headLen, endY);
      ctx.lineTo(endX, endY);
      ctx.lineTo(endX, endY + headLen);
      ctx.stroke();
      ctx.restore();
    }

    function drawShard(ctx, x, y, size, alpha, rotation) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rotation);
      ctx.fillStyle = `rgba(189, 154, 115, ${alpha * 0.7})`;
      ctx.beginPath();
      ctx.moveTo(0, -size / 2);
      ctx.lineTo(size / 3, size / 2);
      ctx.lineTo(-size / 3, size / 2);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    function animate() {
      ctx.clearRect(0, 0, width, height);
      step += 0.009;
      const waves = [
        { color: 'rgba(33, 161, 247, 0.12)', speed: 0.8, amp: 30, freq: 0.006 },
        { color: 'rgba(109, 198, 236, 0.08)', speed: 1.1, amp: 20, freq: 0.008 },
        { color: 'rgba(189, 154, 115, 0.07)', speed: 0.5, amp: 38, freq: 0.005 }
      ];
      waves.forEach((w) => {
        ctx.beginPath();
        ctx.strokeStyle = w.color;
        ctx.lineWidth = 1.2;
        for (let x = 0; x <= width; x += 16) {
          const y = Math.sin(x * w.freq + step * w.speed) * w.amp + height * 0.5;
          if (x === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
      });
      particles.forEach((p) => {
        p.x += p.vx;
        p.y += p.vy;
        p.rotation += p.vRot;
        if (p.y < -30) { p.y = height + 30; p.x = Math.random() * width; }
        if (p.x < -30) p.x = width + 30;
        if (p.x > width + 30) p.x = -30;
        if (p.type === 'men') drawMenSymbol(ctx, p.x, p.y, p.size, p.alpha, p.rotation);
        else drawShard(ctx, p.x, p.y, p.size, p.alpha, p.rotation);
      });
      requestAnimationFrame(animate);
    }

    animate();
  }

  // ── 2. Mobile Nav Toggle ──────────────────────────────────────────────────
  const mobileToggle = document.getElementById('mobile-toggle');
  const navMenu = document.getElementById('nav-menu');
  if (mobileToggle && navMenu) {
    mobileToggle.addEventListener('click', () => {
      const isVisible = navMenu.style.display === 'flex';
      navMenu.style.display = isVisible ? 'none' : 'flex';
      if (!isVisible) {
        navMenu.style.position = 'absolute';
        navMenu.style.top = 'var(--nav-h)';
        navMenu.style.left = '0';
        navMenu.style.width = '100%';
        navMenu.style.flexDirection = 'column';
        navMenu.style.background = 'rgba(7, 8, 11, 0.95)';
        navMenu.style.backdropFilter = 'blur(20px)';
        navMenu.style.padding = '20px';
        navMenu.style.borderBottom = '1px solid var(--border-subtle)';
      }
    });

    navMenu.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => {
        if (window.innerWidth <= 900) {
          navMenu.style.display = 'none';
        }
      });
    });
  }

  // ── 3. 3D Tilt Perspective on Hero Window Frame ───────────────────────────
  const heroWindow = document.getElementById('hero-window-tilt');
  if (heroWindow) {
    heroWindow.addEventListener('mousemove', (e) => {
      const rect = heroWindow.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const rotateX = ((y - rect.height / 2) / rect.height * 2) * -3.5;
      const rotateY = ((x - rect.width / 2) / rect.width * 2) * 3.5;
      heroWindow.style.transform = `perspective(1200px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.008)`;
    });
    heroWindow.addEventListener('mouseleave', () => {
      heroWindow.style.transform = 'perspective(1200px) rotateX(0deg) rotateY(0deg) scale(1)';
    });
  }

  // ── 4. Scroll Reveal via IntersectionObserver ────────────────────────────
  const revealElements = document.querySelectorAll('.reveal');
  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -40px 0px', threshold: 0.1 });

  revealElements.forEach(el => revealObserver.observe(el));

  // ── 5. Hero Mockup Module Switcher Pills ──────────────────────────────────
  const mockupPills = document.querySelectorAll('.mockup-pill-btn');
  const heroPreviewImg = document.getElementById('hero-preview-img');
  const windowStatusText = document.getElementById('window-status-text');

  mockupPills.forEach(pill => {
    pill.addEventListener('click', () => {
      mockupPills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');

      const targetImg = pill.getAttribute('data-img');
      const targetTitle = pill.getAttribute('data-title');

      if (heroPreviewImg && targetImg) {
        heroPreviewImg.style.opacity = '0.3';
        setTimeout(() => {
          heroPreviewImg.src = targetImg;
          heroPreviewImg.style.opacity = '1';
        }, 120);
      }

      if (windowStatusText && targetTitle) {
        windowStatusText.innerHTML = `<iconify-icon icon="fluent:window-24-regular"></iconify-icon> <span>SuamiSihat Creative Assets Management &bull; ${targetTitle}</span>`;
      }
    });
  });

  // ── 6. App Tour Tabs ──────────────────────────────────────────────────────
  const tourTabs = document.querySelectorAll('.tour-tab-btn');
  const tourPanels = document.querySelectorAll('.tour-panel');

  tourTabs.forEach(btn => {
    btn.addEventListener('click', () => {
      const tourId = btn.getAttribute('data-tour');
      tourTabs.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      tourPanels.forEach(panel => {
        panel.classList.toggle('active', panel.id === tourId);
      });
    });
  });

  // ── 7. 1-Click Terminal Snippet Copy Buttons ──────────────────────────────
  document.querySelectorAll('.btn-copy-mini').forEach(btn => {
    btn.addEventListener('click', () => {
      const textToCopy = btn.getAttribute('data-copy-text');
      if (!textToCopy) return;

      navigator.clipboard.writeText(textToCopy).then(() => {
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 2200);
      }).catch(() => {
        const ta = document.createElement('textarea');
        ta.value = textToCopy;
        ta.style.position = 'fixed';
        ta.style.top = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        ta.remove();
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 2200);
      });
    });
  });

  // ── 8. Navbar Scroll-Spy ──────────────────────────────────────────────────
  const navLinks = document.querySelectorAll('.nav-link[href^="#"]');
  const trackedSections = ['whats-new', 'capabilities', 'design-rules', 'showcase', 'download-v4', 'specs']
    .map(id => document.getElementById(id))
    .filter(Boolean);

  const navObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.id;
        navLinks.forEach(link => {
          link.classList.toggle('active', link.getAttribute('href') === `#${id}`);
        });
      }
    });
  }, { rootMargin: '-25% 0px -55% 0px', threshold: 0 });

  trackedSections.forEach(section => navObserver.observe(section));

});

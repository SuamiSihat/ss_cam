<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  interface BranchData {
    name: string;
    shortName: string;
    address: string;
    phone: string;
    whatsapp: string;
    doctors: string[];
    operatingHours: string;
    kkmLicense: string;
    checkInUrl: string;
  }

  let branch = $state<BranchData>({
    name: 'SuamiSihat Clinic Bangsar (HQ Induk)',
    shortName: 'Bangsar HQ',
    address: 'No. 45, Jalan Telawi 3, Bangsar Baru, 59100 Kuala Lumpur',
    phone: '+603-2284 1122',
    whatsapp: '+6012-345 6789',
    doctors: ['Dr. Azlan Shah, MD (Cyberjaya), Dip. Men\'s Health', 'Dr. Farhan Kamil, MBBS (Malaya)'],
    operatingHours: 'Isnin - Sabtu: 9:00 AM - 7:00 PM',
    kkmLicense: 'KKM/JPS/KL/2024/0912',
    checkInUrl: 'https://suamisihat.clinic/checkin/bangsar'
  });

  let currentTime = $state('');
  let currentDate = $state('');
  let currentSlide = $state(0);
  let timer: any = null;
  let clockTimer: any = null;

  const slides = [
    {
      id: 'duty-doctor',
      tag: 'DOKTOR BERTUGAS HARI INI',
      title: 'Pakar Konsultasi Kesihatan Lelaki',
      subtitle: 'Sedia membantu anda dengan bimbingan klinikal peribadi dan sulit.'
    },
    {
      id: 'eswt-info',
      tag: 'RAWATAN KLINIKAL TERMAJU',
      title: 'Terapi Gelombang Kejutan (ESWT)',
      subtitle: 'Teknologi non-invasif merangsang neovaskularisasi & pengaliran darah mikro secara semulajadi.'
    },
    {
      id: 'trt-info',
      tag: 'KESEIMBANGAN HORMON LELAKI',
      title: 'Terapi Penggantian Testosteron (TRT)',
      subtitle: 'Diagnosis profil darah menyeluruh bagi mengembalikan tenaga, fokus dan kualiti tidur optimum.'
    },
    {
      id: 'touchless-checkin',
      tag: 'PENDAFTARAN PANTAS & PRIVASI',
      title: 'Pendaftaran Tanpa Sentuh (Touchless Intake)',
      subtitle: 'Imbas kod QR di kaunter untuk daftar giliran atau buat pertanyaan sulit WhatsApp.'
    }
  ];

  function updateClock() {
    const now = new Date();
    currentTime = now.toLocaleTimeString('ms-MY', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true });
    currentDate = now.toLocaleDateString('ms-MY', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  }

  onMount(async () => {
    updateClock();
    clockTimer = setInterval(updateClock, 1000);

    // Auto-advance slides every 10 seconds
    timer = setInterval(() => {
      currentSlide = (currentSlide + 1) % slides.length;
    }, 10000);

    try {
      const res = await fetch('/api/clinic/branches/SSC-BSR');
      if (res.ok) {
        const data = await res.json();
        if (data.branch) branch = data.branch;
      }
    } catch {
      // Use defaults
    }
  });

  onDestroy(() => {
    if (timer) clearInterval(timer);
    if (clockTimer) clearInterval(clockTimer);
  });
</script>

<div class="signage-kiosk">
  <!-- Top Bar -->
  <header class="signage-header">
    <div class="header-brand">
      <div class="brand-logo-badge">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="#21A1F7">
          <circle cx="12" cy="12" r="10" fill="none" stroke="#21A1F7" stroke-width="2.5"/>
          <path d="M12 6v12M6 12h12" stroke="#21A1F7" stroke-width="2.5" stroke-linecap="round"/>
        </svg>
        <div class="brand-text">
          <span class="brand-title">SUAMISIHAT CLINIC</span>
          <span class="brand-branch">{branch.name}</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      <div class="license-pill">LESEN KKM: {branch.kkmLicense}</div>
      <div class="clock-display">
        <span class="clock-time">{currentTime}</span>
        <span class="clock-date">{currentDate}</span>
      </div>
    </div>
  </header>

  <!-- Main Billboard Arena -->
  <main class="signage-arena">
    <!-- Active Slide Showcase -->
    <div class="slide-card">
      <div class="slide-tag">{slides[currentSlide].tag}</div>
      <h1 class="slide-title">{slides[currentSlide].title}</h1>
      <p class="slide-subtitle">{slides[currentSlide].subtitle}</p>

      {#if currentSlide === 0}
        <!-- Doctor Spotlight Card -->
        <div class="doctor-roster-grid">
          {#each branch.doctors as doc, idx}
            <div class="doctor-badge">
              <div class="doctor-avatar">👨‍⚕️</div>
              <div class="doctor-info">
                <div class="doc-label">Doktor Bertugas {idx + 1}</div>
                <div class="doc-name">{doc}</div>
                <div class="doc-status">🟢 Tersedia untuk Konsultasi</div>
              </div>
            </div>
          {/each}
        </div>
      {:else if currentSlide === 1}
        <!-- ESWT Shockwave Spotlight -->
        <div class="tech-graphic-grid">
          <div class="tech-feature-card">
            <div class="tech-icon">⚡</div>
            <div class="tech-headline">Gelombang Akustik</div>
            <div class="tech-desc">Menembusi tisu lembut untuk mengaktifkan pertumbuhan salur darah baharu.</div>
          </div>
          <div class="tech-feature-card">
            <div class="tech-icon">🛡️</div>
            <div class="tech-headline">100% Non-Invasif</div>
            <div class="tech-desc">Tanpa pembedahan, tanpa bius, dan pesakit boleh pulang segera.</div>
          </div>
          <div class="tech-feature-card">
            <div class="tech-icon">📈</div>
            <div class="tech-headline">Kadar Kejayaan 80%+</div>
            <div class="tech-desc">Terbukti melalui ujian klinikal antarabangsa untuk kesihatan vaskular.</div>
          </div>
        </div>
      {:else if currentSlide === 2}
        <!-- TRT Spotlight -->
        <div class="tech-graphic-grid">
          <div class="tech-feature-card">
            <div class="tech-icon">🩸</div>
            <div class="tech-headline">Ujian Darah Komprehensif</div>
            <div class="tech-desc">Pemantauan paras hormon dan penanda biometrik darah setiap 12 minggu.</div>
          </div>
          <div class="tech-feature-card">
            <div class="tech-icon">🔋</div>
            <div class="tech-headline">Peningkatan Tenaga</div>
            <div class="tech-desc">Menghapuskan keletihan kronik, memulihkan stamina dan pembentukan otot.</div>
          </div>
          <div class="tech-feature-card">
            <div class="tech-icon">🧠</div>
            <div class="tech-headline">Fokus & Ketajaman Minda</div>
            <div class="tech-desc">Mengurangkan 'brain fog' dan menyokong kestabilan emosi optimum.</div>
          </div>
        </div>
      {:else}
        <!-- Intake Check-In -->
        <div class="qr-intake-showcase">
          <div class="qr-placeholder">
            <svg width="180" height="180" viewBox="0 0 100 100" fill="#022057">
              <rect x="10" y="10" width="30" height="30" rx="4"/>
              <rect x="15" y="15" width="20" height="20" fill="#FFFFFF"/>
              <rect x="20" y="20" width="10" height="10" fill="#022057"/>
              <rect x="60" y="10" width="30" height="30" rx="4"/>
              <rect x="65" y="15" width="20" height="20" fill="#FFFFFF"/>
              <rect x="70" y="20" width="10" height="10" fill="#022057"/>
              <rect x="10" y="60" width="30" height="30" rx="4"/>
              <rect x="15" y="65" width="20" height="20" fill="#FFFFFF"/>
              <rect x="20" y="70" width="10" height="10" fill="#022057"/>
              <rect x="45" y="45" width="15" height="15" fill="#21A1F7"/>
              <rect x="45" y="15" width="8" height="20"/>
              <rect x="15" y="45" width="20" height="8"/>
              <rect x="65" y="45" width="25" height="8"/>
              <rect x="45" y="70" width="45" height="20"/>
            </svg>
          </div>
          <div class="qr-instructions">
            <div class="qr-inst-title">Imbas Kod QR di Telefon Pintar Anda</div>
            <div class="qr-inst-step">1. Buka kamera telefon anda dan halakan ke skrin ini.</div>
            <div class="qr-inst-step">2. Tekan pautan pendaftaran atau buka chat sulit WhatsApp rasmi kami.</div>
            <div class="qr-inst-step">3. Kakitangan klinik akan memanggil nombor giliran anda dengan serta-merta.</div>
          </div>
        </div>
      {/if}
    </div>

    <!-- Live Queue Call Sidebar -->
    <aside class="signage-queue-panel">
      <div class="queue-header">
        <span class="queue-icon">🔔</span>
        <span class="queue-title">PANGGILAN GILIRAN</span>
      </div>

      <div class="queue-current-call">
        <div class="call-badge">NOMBOR TERKINI</div>
        <div class="call-number">A-1028</div>
        <div class="call-room">Bilik Rawatan 1</div>
        <div class="call-doc">{branch.doctors[0]}</div>
      </div>

      <div class="queue-upcoming">
        <div class="upcoming-label">Giliran Seterusnya:</div>
        <div class="upcoming-item">
          <span class="up-num">A-1029</span>
          <span class="up-dest">Bilik 2</span>
        </div>
        <div class="upcoming-item">
          <span class="up-num">B-2004</span>
          <span class="up-dest">Bilik Prosedur ESWT</span>
        </div>
        <div class="upcoming-item">
          <span class="up-num">A-1030</span>
          <span class="up-dest">Kaunter Saringan</span>
        </div>
      </div>

      <div class="branch-contact-box">
        <div class="cb-label">Bantuan Kaunter:</div>
        <div class="cb-val">{branch.phone}</div>
        <div class="cb-wa">WhatsApp: {branch.whatsapp}</div>
      </div>
    </aside>
  </main>

  <!-- Bottom Running Ticker -->
  <footer class="signage-footer">
    <div class="ticker-prefix">INFO KLINIK</div>
    <div class="ticker-content">
      <div class="ticker-text">
        Selamat datang ke {branch.name} • Rawatan kesihatan lelaki beretika, saintifik dan diperakui KKM • Kerahsiaan rekod pesakit dilindungi 100% di bawah Akta Perlindungan Data Peribadi (PDPA 2010) • Sila pastikan telefon dalam mod senyap semasa berada di bilik konsultasi doktor.
      </div>
    </div>
  </footer>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: #020C1F;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI Variable Display", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }

  .signage-kiosk {
    width: 100vw;
    height: 100vh;
    display: flex;
    flex-direction: column;
    background: radial-gradient(circle at 15% 20%, #061938 0%, #020C1F 100%);
    color: #F8FAFC;
    overflow: hidden;
    user-select: none;
  }

  .signage-header {
    height: 80px;
    padding: 0 40px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(2, 12, 31, 0.7);
    backdrop-filter: blur(12px);
  }

  .header-brand {
    display: flex;
    align-items: center;
  }

  .brand-logo-badge {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .brand-text {
    display: flex;
    flex-direction: column;
  }

  .brand-title {
    font-size: 20px;
    font-weight: 800;
    letter-spacing: 1.5px;
    color: #FFFFFF;
  }

  .brand-branch {
    font-size: 13px;
    color: #21A1F7;
    font-weight: 500;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 28px;
  }

  .license-pill {
    padding: 6px 14px;
    background: rgba(33, 161, 247, 0.12);
    border: 1px solid rgba(33, 161, 247, 0.3);
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    color: #6DC6EC;
    letter-spacing: 0.5px;
  }

  .clock-display {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }

  .clock-time {
    font-size: 26px;
    font-weight: 700;
    color: #FFFFFF;
    font-variant-numeric: tabular-nums;
  }

  .clock-date {
    font-size: 12px;
    color: #94A3B8;
  }

  .signage-arena {
    flex: 1;
    display: grid;
    grid-template-columns: 1fr 380px;
    gap: 32px;
    padding: 32px 40px;
    overflow: hidden;
  }

  .slide-card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 24px;
    padding: 44px;
    display: flex;
    flex-direction: column;
    position: relative;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
  }

  .slide-tag {
    align-self: flex-start;
    padding: 6px 16px;
    background: #043388;
    color: #FFFFFF;
    font-size: 12px;
    font-weight: 700;
    border-radius: 8px;
    letter-spacing: 1px;
    margin-bottom: 20px;
  }

  .slide-title {
    font-size: 42px;
    font-weight: 800;
    margin: 0 0 12px 0;
    line-height: 1.2;
    background: linear-gradient(135deg, #FFFFFF 0%, #BAE6FD 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .slide-subtitle {
    font-size: 20px;
    color: #94A3B8;
    margin: 0 0 36px 0;
    line-height: 1.5;
  }

  .doctor-roster-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    margin-top: auto;
  }

  .doctor-badge {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    align-items: center;
    gap: 20px;
  }

  .doctor-avatar {
    font-size: 44px;
  }

  .doc-label {
    font-size: 11px;
    font-weight: 700;
    color: #21A1F7;
    letter-spacing: 0.5px;
    margin-bottom: 4px;
  }

  .doc-name {
    font-size: 17px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 6px;
  }

  .doc-status {
    font-size: 13px;
    color: #34D399;
    font-weight: 500;
  }

  .tech-graphic-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    margin-top: auto;
  }

  .tech-feature-card {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    flex-direction: column;
  }

  .tech-icon {
    font-size: 32px;
    margin-bottom: 16px;
  }

  .tech-headline {
    font-size: 18px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 8px;
  }

  .tech-desc {
    font-size: 14px;
    color: #94A3B8;
    line-height: 1.5;
  }

  .qr-intake-showcase {
    display: flex;
    align-items: center;
    gap: 40px;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 20px;
    padding: 32px;
    margin-top: auto;
  }

  .qr-placeholder {
    background: #FFFFFF;
    padding: 16px;
    border-radius: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .qr-inst-title {
    font-size: 24px;
    font-weight: 700;
    color: #FFFFFF;
    margin-bottom: 16px;
  }

  .qr-inst-step {
    font-size: 16px;
    color: #CBD5E1;
    margin-bottom: 10px;
    line-height: 1.4;
  }

  /* Queue Panel */
  .signage-queue-panel {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 24px;
    padding: 28px;
    display: flex;
    flex-direction: column;
  }

  .queue-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 24px;
    padding-bottom: 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .queue-icon {
    font-size: 20px;
  }

  .queue-title {
    font-size: 14px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #BAE6FD;
  }

  .queue-current-call {
    background: linear-gradient(135deg, rgba(33, 161, 247, 0.15) 0%, rgba(4, 51, 136, 0.3) 100%);
    border: 2px solid #21A1F7;
    border-radius: 18px;
    padding: 24px;
    text-align: center;
    margin-bottom: 24px;
    box-shadow: 0 10px 30px rgba(33, 161, 247, 0.2);
  }

  .call-badge {
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #6DC6EC;
    margin-bottom: 6px;
  }

  .call-number {
    font-size: 54px;
    font-weight: 900;
    color: #FFFFFF;
    letter-spacing: 2px;
    line-height: 1.1;
  }

  .call-room {
    font-size: 18px;
    font-weight: 700;
    color: #21A1F7;
    margin-top: 6px;
  }

  .call-doc {
    font-size: 13px;
    color: #CBD5E1;
    margin-top: 4px;
  }

  .queue-upcoming {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: auto;
  }

  .upcoming-label {
    font-size: 12px;
    font-weight: 700;
    color: #94A3B8;
    margin-bottom: 4px;
  }

  .upcoming-item {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 12px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .up-num {
    font-size: 18px;
    font-weight: 800;
    color: #FFFFFF;
  }

  .up-dest {
    font-size: 13px;
    color: #94A3B8;
  }

  .branch-contact-box {
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    font-size: 12px;
    color: #94A3B8;
  }

  .cb-val {
    font-weight: 700;
    color: #FFFFFF;
    margin-top: 2px;
  }

  .cb-wa {
    color: #34D399;
    margin-top: 2px;
    font-weight: 600;
  }

  /* Ticker Footer */
  .signage-footer {
    height: 54px;
    background: #043388;
    display: flex;
    align-items: center;
    padding: 0 40px;
    overflow: hidden;
  }

  .ticker-prefix {
    background: #022057;
    padding: 4px 12px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1px;
    color: #6DC6EC;
    margin-right: 24px;
    white-space: nowrap;
  }

  .ticker-content {
    flex: 1;
    overflow: hidden;
    white-space: nowrap;
  }

  .ticker-text {
    display: inline-block;
    padding-left: 100%;
    animation: ticker 35s linear infinite;
    font-size: 14px;
    font-weight: 500;
    color: #FFFFFF;
  }

  @keyframes ticker {
    0% { transform: translate3d(0, 0, 0); }
    100% { transform: translate3d(-100%, 0, 0); }
  }
</style>

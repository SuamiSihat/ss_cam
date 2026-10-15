const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9334;
const outDir = path.resolve(__dirname, '../screenshots/phase3');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

class CdpClient {
  constructor(wsUrl) {
    this.wsUrl = wsUrl;
    this.ws = null;
    this.id = 1;
    this.pending = new Map();
  }

  async connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.wsUrl);
      this.ws.onopen = () => resolve();
      this.ws.onerror = (err) => reject(err);
      this.ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.id && this.pending.has(msg.id)) {
          const { resolve, reject } = this.pending.get(msg.id);
          this.pending.delete(msg.id);
          if (msg.error) reject(new Error(msg.error.message));
          else resolve(msg.result);
        }
      };
    });
  }

  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this.id++;
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const res = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true
    });
    return res && res.result ? res.result.value : null;
  }

  async setViewport(width, height) {
    await this.send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: width < 600
    });
    await this.send('Emulation.setVisibleSize', { width, height }).catch(() => {});
  }

  async navigate(url) {
    await this.send('Page.navigate', { url });
    await sleep(1500);
  }

  async screenshot(filename) {
    const res = await this.send('Page.captureScreenshot', { format: 'png' });
    const buffer = Buffer.from(res.data, 'base64');
    const filePath = path.join(outDir, filename);
    fs.writeFileSync(filePath, buffer);
    console.log(`  [Screenshot] Saved ${filename} (${Math.round(buffer.length / 1024)} KB)`);
  }

  async pressTab() {
    await this.send('Input.dispatchKeyEvent', {
      type: 'rawKeyDown',
      key: 'Tab',
      code: 'Tab',
      windowsVirtualKeyCode: 9
    });
    await this.send('Input.dispatchKeyEvent', {
      type: 'keyUp',
      key: 'Tab',
      code: 'Tab',
      windowsVirtualKeyCode: 9
    });
    await sleep(100);
  }

  async getActiveElementInfo() {
    return await this.evaluate(`(() => {
      const el = document.activeElement;
      if (!el) return { tag: 'none' };
      const comp = window.getComputedStyle(el);
      return {
        tag: el.tagName,
        id: el.id || '',
        class: el.className || '',
        text: (el.innerText || el.value || el.getAttribute('aria-label') || '').slice(0, 30).trim(),
        outline: comp.outline,
        outlineOffset: comp.outlineOffset,
        boxShadow: comp.boxShadow,
        hasVisibleFocus: comp.outlineStyle !== 'none' || comp.boxShadow !== 'none'
      };
    })()`);
  }
}

async function run() {
  console.log('[Phase3Capture] Starting Chrome...');
  const tmpUserData = path.join(os.tmpdir(), 'chrome-phase3-' + Date.now());
  const chrome = spawn(chromePath, [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    '--no-sandbox',
    '--disable-gpu',
    `--user-data-dir=${tmpUserData}`
  ]);

  await sleep(2000);

  let version;
  for (let i = 0; i < 15; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      version = await res.json();
      break;
    } catch (e) {
      await sleep(400);
    }
  }

  if (!version) {
    console.error('Failed to connect to Chrome');
    chrome.kill();
    process.exit(1);
  }

  const targetsRes = await fetch(`http://127.0.0.1:${port}/json`);
  const targets = await targetsRes.json();
  const pageTarget = targets.find(t => t.type === 'page') || targets[0];

  const cdp = new CdpClient(pageTarget.webSocketDebuggerUrl);
  await cdp.connect();
  await cdp.send('Page.enable');
  await cdp.send('DOM.enable');
  await cdp.send('Runtime.enable');

  const tabAudit = {};

  try {
    // ══════════════════════════════════════════════════════════════
    // 1. LOGIN PAGE (1440px & 390px)
    // ══════════════════════════════════════════════════════════════
    console.log('\n[1/5] Capturing Login Page...');
    await cdp.setViewport(1440, 900);
    await cdp.navigate('http://127.0.0.1:4107/#login');
    await sleep(1500);
    await cdp.screenshot('login-1440.png');

    await cdp.setViewport(390, 844);
    await sleep(500);
    await cdp.screenshot('login-390.png');

    // Tab pass on Login (1440)
    await cdp.setViewport(1440, 900);
    tabAudit['login'] = [];
    for (let i = 0; i < 6; i++) {
      await cdp.pressTab();
      const info = await cdp.getActiveElementInfo();
      tabAudit['login'].push(info);
    }

    // ══════════════════════════════════════════════════════════════
    // LOG IN AS ADMIN
    // ══════════════════════════════════════════════════════════════
    console.log('\nLogging in as Admin via API...');
    const loginRes = await fetch('http://127.0.0.1:4107/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'AdminPassword123!' })
    });
    const loginData = await loginRes.json();
    console.log('Login result success:', loginData.success);

    await cdp.evaluate(`(() => {
      localStorage.setItem('ss_cam_token', ${JSON.stringify(loginData.token)});
    })()`);
    await sleep(300);

    // ══════════════════════════════════════════════════════════════
    // 2. DASHBOARD / HOME (1440px & 390px)
    // ══════════════════════════════════════════════════════════════
    console.log('\n[2/5] Capturing Dashboard / Home...');
    await cdp.evaluate(`window.location.hash = '#dashboard'; window.location.reload();`);
    await sleep(2500);
    const dashText = await cdp.evaluate(`document.body.innerText.slice(0, 100)`);
    console.log('  Dashboard preview:', JSON.stringify(dashText));

    await cdp.setViewport(1440, 900);
    await cdp.screenshot('dashboard-1440.png');

    await cdp.setViewport(390, 844);
    await sleep(500);
    await cdp.screenshot('dashboard-390.png');

    // Tab pass on Dashboard
    await cdp.setViewport(1440, 900);
    tabAudit['dashboard'] = [];
    for (let i = 0; i < 6; i++) {
      await cdp.pressTab();
      const info = await cdp.getActiveElementInfo();
      tabAudit['dashboard'].push(info);
    }

    // ══════════════════════════════════════════════════════════════
    // 3. TASKS (1440px & 390px)
    // ══════════════════════════════════════════════════════════════
    console.log('\n[3/5] Capturing Tasks View...');
    await cdp.evaluate(`window.location.hash = '#tasks'; window.location.reload();`);
    await sleep(2500);
    const tasksText = await cdp.evaluate(`document.body.innerText.slice(0, 100)`);
    console.log('  Tasks preview:', JSON.stringify(tasksText));

    await cdp.setViewport(1440, 900);
    await cdp.screenshot('tasks-1440.png');

    await cdp.setViewport(390, 844);
    await sleep(500);
    await cdp.screenshot('tasks-390.png');

    // Tab pass on Tasks
    await cdp.setViewport(1440, 900);
    tabAudit['tasks'] = [];
    for (let i = 0; i < 6; i++) {
      await cdp.pressTab();
      const info = await cdp.getActiveElementInfo();
      tabAudit['tasks'].push(info);
    }

    // ══════════════════════════════════════════════════════════════
    // 4. PROJECTS (1440px & 390px)
    // ══════════════════════════════════════════════════════════════
    console.log('\n[4/5] Capturing Projects Catalog...');
    await cdp.evaluate(`window.location.hash = '#projects'; window.location.reload();`);
    await sleep(2500);
    const projText = await cdp.evaluate(`document.body.innerText.slice(0, 100)`);
    console.log('  Projects preview:', JSON.stringify(projText));

    await cdp.setViewport(1440, 900);
    await cdp.screenshot('projects-1440.png');

    await cdp.setViewport(390, 844);
    await sleep(500);
    await cdp.screenshot('projects-390.png');

    // Tab pass on Projects
    await cdp.setViewport(1440, 900);
    tabAudit['projects'] = [];
    for (let i = 0; i < 6; i++) {
      await cdp.pressTab();
      const info = await cdp.getActiveElementInfo();
      tabAudit['projects'].push(info);
    }

    // ══════════════════════════════════════════════════════════════
    // 5. MODAL / DIALOG (1440px & 390px)
    // ══════════════════════════════════════════════════════════════
    console.log('\n[5/5] Capturing Dialog / Modal...');
    await cdp.evaluate(`window.location.hash = '#tasks'; window.location.reload();`);
    await sleep(2500);
    const openedModal = await cdp.evaluate(`(() => {
      const btn = document.querySelector('.clickup-add-task-btn') || Array.from(document.querySelectorAll('button')).find(b => (b.innerText || '').includes('New Task'));
      if (btn) {
        btn.click();
        return true;
      }
      return false;
    })()`);
    console.log('  Modal open clicked:', openedModal);
    await sleep(1500);

    await cdp.setViewport(1440, 900);
    await cdp.screenshot('dialog-1440.png');

    await cdp.setViewport(390, 844);
    await sleep(500);
    await cdp.screenshot('dialog-390.png');

    // Tab pass in Dialog
    await cdp.setViewport(1440, 900);
    tabAudit['dialog'] = [];
    for (let i = 0; i < 6; i++) {
      await cdp.pressTab();
      const info = await cdp.getActiveElementInfo();
      tabAudit['dialog'].push(info);
    }

    // Write audit output
    const auditFile = path.resolve(__dirname, '../tab-pass-results.json');
    fs.writeFileSync(auditFile, JSON.stringify(tabAudit, null, 2), 'utf8');
    console.log('\n[Success] Tab audit saved to:', auditFile);

  } catch (err) {
    console.error('Error during capture:', err);
  } finally {
    chrome.kill();
    console.log('[Done] Chrome terminated.');
  }
}

run();

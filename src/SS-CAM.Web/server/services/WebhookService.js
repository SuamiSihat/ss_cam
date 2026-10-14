const fs = require('fs');
const path = require('path');
const config = require('../config');
const dns = require('dns').promises;
const net = require('net');
const WorkspaceService = require('./WorkspaceService');

// Chat services have fixed addresses. Anything else (a custom gateway) must be HTTPS and must not point at
// a private network, unless an admin lists the host in WEBHOOK_ALLOWED_HOSTS (comma separated).
const KNOWN_SERVICE_HOSTS = {
  discord: ['discord.com', 'discordapp.com'],
  slack: ['hooks.slack.com'],
  telegram: ['api.telegram.org']
};

function allowedHosts() {
  return (process.env.WEBHOOK_ALLOWED_HOSTS || '').split(',').map(h => h.trim().toLowerCase()).filter(Boolean);
}

function isPrivateAddress(address) {
  if (net.isIPv4(address)) {
    const [a, b] = address.split('.').map(Number);
    return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  if (net.isIPv6(address)) {
    const low = address.toLowerCase();
    if (low.startsWith('::ffff:')) return isPrivateAddress(low.slice(7));
    return low === '::1' || low === '::' || low.startsWith('fc') || low.startsWith('fd') || low.startsWith('fe80');
  }
  return true;
}

function webhookError(message) {
  return Object.assign(new Error(message), { status: 400 });
}

/** Shape check that needs no network: scheme and, for known chat services, the host name. */
function assertWebhookShape(url, serviceType) {
  let parsed;
  try { parsed = new URL(String(url || '').trim()); } catch (e) { throw webhookError('That webhook address is not a valid web address.'); }
  const host = parsed.hostname.toLowerCase();
  const listed = allowedHosts().includes(host);
  if (parsed.protocol !== 'https:' && !listed) throw webhookError('Webhook addresses must start with https://.');
  if (parsed.username || parsed.password) throw webhookError('Webhook addresses cannot contain a username or password.');
  const known = KNOWN_SERVICE_HOSTS[serviceType];
  if (known && !listed && !known.some(d => host === d || host.endsWith('.' + d))) {
    throw webhookError('That address does not belong to the selected chat service.');
  }
  return parsed;
}

/** Full check before sending: shape plus the addresses the host name really resolves to. */
async function assertWebhookTarget(url, serviceType) {
  const parsed = assertWebhookShape(url, serviceType);
  const host = parsed.hostname.toLowerCase();
  if (allowedHosts().includes(host) || KNOWN_SERVICE_HOSTS[serviceType]) return parsed;
  const addresses = net.isIP(host) ? [{ address: host }] : await dns.lookup(host, { all: true });
  if (addresses.length === 0 || addresses.some(a => isPrivateAddress(a.address))) {
    throw webhookError('Webhook addresses cannot point to a private network.');
  }
  return parsed;
}

class WebhookService {
  constructor() {
    this.memoryWebhooks = [];
  }

  getFilePath() {
    const root = WorkspaceService.workspaceRoot || config.WORKSPACE_ROOT;
    const teamDir = path.join(root, '_Team');
    if (!fs.existsSync(teamDir)) {
      try { fs.mkdirSync(teamDir, { recursive: true }); } catch (e) {
        console.debug('[WebhookService] Failed to create teamDir:', e.message);
      }
    }
    return path.join(teamDir, 'webhooks.json');
  }

  loadWebhooks() {
    const filePath = this.getFilePath();
    if (fs.existsSync(filePath)) {
      try {
        const raw = fs.readFileSync(filePath, 'utf8');
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          this.memoryWebhooks = parsed;
          return this.memoryWebhooks;
        }
      } catch (e) {
        console.warn('[WebhookService] Could not read webhooks.json:', e.message);
      }
    }
    return this.memoryWebhooks;
  }

  saveWebhooks(list) {
    this.memoryWebhooks = list;
    const filePath = this.getFilePath();
    try {
      fs.writeFileSync(filePath, JSON.stringify(list, null, 2), 'utf8');
      return true;
    } catch (e) {
      console.warn('[WebhookService] Could not save webhooks.json:', e.message);
      return false;
    }
  }

  getWebhooks() {
    return this.loadWebhooks();
  }

  addWebhook({ name = 'Studio Webhook', url, serviceType = 'discord', events = ['all'], active = true }) {
    if (!url) throw new Error('Webhook URL is required.');
    assertWebhookShape(url, serviceType);
    const list = this.loadWebhooks();
    const newHook = {
      id: `wh_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      name,
      url: url.trim(),
      serviceType, // 'discord' | 'slack' | 'telegram' | 'whatsapp' | 'generic'
      events: Array.isArray(events) && events.length ? events : ['all'],
      active: active !== false,
      createdAt: new Date().toISOString(),
      lastDispatchedAt: null,
      lastStatus: null
    };

    list.push(newHook);
    this.saveWebhooks(list);
    return newHook;
  }

  deleteWebhook(id) {
    const list = this.loadWebhooks().filter(w => w.id !== id);
    return this.saveWebhooks(list);
  }

  async dispatch(eventName, payload = {}) {
    const hooks = this.loadWebhooks().filter(w => w.active);
    if (!hooks.length) return;

    for (const hook of hooks) {
      if (!hook.events.includes('all') && !hook.events.includes(eventName)) {
        continue;
      }

      this.sendToHook(hook, eventName, payload).catch(err => {
        console.warn(`[WebhookService] Delivery to ${hook.name} failed:`, err.message);
      });
    }
  }

  async sendToHook(hook, eventName, payload) {
    let body = {};
    const title = payload.title || payload.projectTitle || `SuamiSihat CAM Alert: ${eventName}`;
    const desc = payload.description || payload.message || payload.comment || 'A creative studio update has occurred.';

    if (hook.serviceType === 'discord') {
      let embedColor = 0x043388; // Default Royal Blue
      if (eventName.includes('APPROVED')) embedColor = 0x10B981; // Emerald Green
      else if (eventName.includes('REVISION')) embedColor = 0xD97706; // Amber Orange
      else if (eventName.includes('REJECTED')) embedColor = 0xEF4444; // Critical Red
      else if (eventName.includes('EXPORT')) embedColor = 0x0284C7; // Sky Blue
      else if (eventName.includes('ARCHIVE')) embedColor = 0x64748B; // Slate Neutral

      const fields = [
        { name: 'Brand', value: payload.brand || 'SS', inline: true },
        { name: 'Actor', value: payload.actor || payload.reviewer || 'Studio Lead', inline: true }
      ];

      if (payload.jobId) fields.push({ name: 'Job ID', value: String(payload.jobId), inline: true });
      if (payload.deliverableId) fields.push({ name: 'Deliverable', value: String(payload.deliverableId), inline: true });
      if (payload.revision !== undefined) fields.push({ name: 'Revision Round', value: `v${payload.revision}`, inline: true });
      if (payload.fileCount !== undefined) fields.push({ name: 'Files Packaged', value: `${payload.fileCount} file(s)`, inline: true });
      if (payload.sizeFormatted) fields.push({ name: 'Package Size', value: String(payload.sizeFormatted), inline: true });
      if (payload.downloadUrl) fields.push({ name: 'Vault Link', value: `[Direct Access](${payload.downloadUrl})`, inline: false });

      body = {
        username: 'SuamiSihat Creative Studio Bot',
        avatar_url: 'https://creative.suamisihat.myds.me/brand/suamisihat-logo-on-dark.svg',
        embeds: [
          {
            title: `🎨 [${eventName}] ${title}`,
            description: desc,
            color: embedColor,
            timestamp: new Date().toISOString(),
            fields
          }
        ]
      };
    } else if (hook.serviceType === 'slack') {
      const statusIcon = eventName.includes('APPROVED') ? '✅' : (eventName.includes('REVISION') ? '⚠️' : '🎨');
      body = {
        text: `*${statusIcon} SuamiSihat CAM [${eventName}]:* ${title}\n>${desc}\n_By: ${payload.actor || payload.reviewer || 'Studio Lead'}_`
      };
    } else {
      // Generic / WhatsApp Webhook Gateway
      body = {
        event: eventName,
        timestamp: new Date().toISOString(),
        title,
        description: desc,
        payload
      };
    }

    // Checked on every send, so older saved webhooks and DNS changes are covered too.
    await assertWebhookTarget(hook.url, hook.serviceType);
    try {
      const res = await fetch(hook.url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        redirect: 'error',
        signal: AbortSignal.timeout(10000)
      });
      hook.lastDispatchedAt = new Date().toISOString();
      hook.lastStatus = res.ok ? 200 : res.status;
      this.saveWebhooks(this.memoryWebhooks);
      return { success: res.ok, status: res.status };
    } catch (err) {
      hook.lastStatus = 500;
      this.saveWebhooks(this.memoryWebhooks);
      throw err;
    }
  }

  async testPing(url, serviceType = 'discord') {
    const testHook = { url, serviceType, name: 'Test Ping' };
    return await this.sendToHook(testHook, 'STUDIO_TEST_PING', {
      title: 'SuamiSihat CAM Notification Test',
      description: 'Webhook connection established successfully with Synology NAS studio vault.',
      actor: 'Studio Admin',
      brand: 'SSH'
    });
  }
}

module.exports = new WebhookService();

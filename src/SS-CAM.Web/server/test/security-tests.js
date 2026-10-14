/**
 * Security regression tests for the SS-CAM Web Portal.
 *
 * Runs entirely in a throwaway workspace and data directory; it never touches the real NAS,
 * real accounts or the real data/ folder.
 *   node server/test/security-tests.js
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');
const os = require('os');
const http = require('http');
const { spawnSync } = require('child_process');

process.env.NODE_ENV = 'test';

const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'sscam-sec-ws-'));
const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sscam-sec-data-'));
fs.cpSync(path.resolve(__dirname, '../../sample-workspace'), sandbox, { recursive: true });
process.env.WORKSPACE_ROOT = sandbox;
process.env.DATA_DIR = dataDir;
process.on('exit', () => {
  fs.rmSync(sandbox, { recursive: true, force: true });
  fs.rmSync(dataDir, { recursive: true, force: true });
});

const express = require('express');
const jwt = require('jsonwebtoken');
const config = require('../config');
const AuditService = require('../services/AuditService');
AuditService.getAuditLogPath = () => path.join(dataDir, 'audit.jsonl');
const TeamService = require('../services/TeamService');
const auth = require('../middleware/auth');

const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

let server;
let port;

function request(method, url, { token, body, headers = {}, cookie } = {}) {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? null : JSON.stringify(body);
    const req = http.request({
      host: '127.0.0.1', port, path: url, method,
      headers: {
        ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(cookie ? { Cookie: cookie } : {}),
        ...headers
      }
    }, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try { json = JSON.parse(raw); } catch (e) { /* not JSON */ }
        resolve({ status: res.statusCode, headers: res.headers, json, raw });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function signIn(username, password) {
  const res = await request('POST', '/api/auth/login', { body: { username, password } });
  return res;
}

const STRONG = 'Correct-Horse-Battery-9';

function addPerson(staffId, name, role, password) {
  const member = TeamService.addStaffMember({ staffId, name, username: name.toLowerCase().replace(/\s+/g, ''), email: `${name.toLowerCase().replace(/\s+/g, '')}@example.test`, role });
  auth.updateUserPassword(member.username, password || STRONG);
  return member;
}

// ─── Identity and account takeover ─────────────────────────────────────────────

test('C2: a user cannot take over another account by choosing a look-alike name', async () => {
  const victim = TeamService.getStaffRoster().find(m => m.staffId === 'SS0004');
  const victimEmail = victim.email;
  addPerson('SS9001', 'Mallory', 'Designer');
  const { json } = await signIn('mallory', STRONG);
  const token = json.token;

  // Renaming to the admin's name is refused.
  const rename = await request('PUT', '/api/auth/profile', { token, body: { name: 'Harussani' } });
  assert.strictEqual(rename.status, 409, 'Taking another person\'s name must be refused');

  // Sending the victim's staffId / name / username in the body must not redirect the edit.
  const hijack = await request('PUT', '/api/auth/profile', {
    token,
    body: { staffId: 'SS0004', username: 'harussani', email: 'mallory-owns-this@example.test', currentPassword: STRONG }
  });
  assert.strictEqual(hijack.status, 200);
  const after = TeamService.getStaffRoster();
  assert.strictEqual(after.find(m => m.staffId === 'SS0004').email, victimEmail, 'Victim email must be unchanged');
  assert.strictEqual(after.find(m => m.staffId === 'SS9001').email, 'mallory-owns-this@example.test', 'Edit must apply to the caller only');
});

test('C2: changing your own email needs the current password', async () => {
  addPerson('SS9002', 'Niaz', 'Designer');
  const { json } = await signIn('niaz', STRONG);
  const noPw = await request('PUT', '/api/auth/profile', { token: json.token, body: { email: 'new-niaz@example.test' } });
  assert.strictEqual(noPw.status, 400);
  assert.strictEqual(noPw.json.code, 'CURRENT_PASSWORD_REQUIRED');
  const wrong = await request('PUT', '/api/auth/profile', { token: json.token, body: { email: 'new-niaz@example.test', currentPassword: 'wrong-password-123' } });
  assert.strictEqual(wrong.status, 400);
  const ok = await request('PUT', '/api/auth/profile', { token: json.token, body: { email: 'new-niaz@example.test', currentPassword: STRONG } });
  assert.strictEqual(ok.status, 200);
});

test('C2: sign-in by an ambiguous name never resolves to anyone', async () => {
  const roster = TeamService.getStaffRoster();
  roster.push({ staffId: 'SS9003', username: 'twin1', name: 'Shared Name', email: 'twin1@example.test', role: 'Designer', roles: ['Designer'], active: true });
  roster.push({ staffId: 'SS9004', username: 'twin2', name: 'Shared Name', email: 'twin2@example.test', role: 'Designer', roles: ['Designer'], active: true });
  TeamService.saveStaffRoster(roster);
  auth.updateUserPassword('twin1', STRONG);
  auth.updateUserPassword('twin2', STRONG);
  assert.strictEqual((await signIn('Shared Name', STRONG)).status, 401, 'Duplicate display name must not sign anyone in');
  assert.strictEqual((await signIn('twin1', STRONG)).status, 200, 'Username still works');
});

// ─── Passwords and sessions ────────────────────────────────────────────────────

test('H1: admin password edits are never stored in staff files or sent to other people', async () => {
  const admin = await signIn('admin', STRONG);
  assert.strictEqual(admin.status, 200);
  const res = await request('PUT', '/api/users/SS9002', { token: admin.json.token, body: { password: 'Brand-New-Passw0rd!', department: 'Ops' } });
  assert.strictEqual(res.status, 200);
  assert.ok(!('password' in res.json.user), 'Response must not echo the password');
  const roster = JSON.stringify(TeamService.getStaffRoster());
  assert.ok(!roster.includes('Brand-New-Passw0rd!'), 'Password must not be written to the staff directory');
  const profile = fs.readFileSync(path.join(TeamService.getUserDir('SS9002'), 'profile.json'), 'utf8');
  assert.ok(!profile.includes('Brand-New-Passw0rd!'), 'Password must not be written to the profile file');
  // The person must replace an admin-chosen password at next sign-in.
  const next = await signIn('niaz', 'Brand-New-Passw0rd!');
  assert.strictEqual(next.status, 200);
  assert.strictEqual(next.json.mustChangePassword, true);
});

test('H1: stored passwords left by earlier versions are scrubbed', () => {
  const roster = TeamService.getStaffRoster();
  roster.find(m => m.staffId === 'SS9001').password = 'leftover-plain-text';
  TeamService.saveStaffRoster(roster);
  assert.ok(TeamService.scrubStoredCredentials() >= 1);
  assert.ok(!JSON.stringify(TeamService.getStaffRoster()).includes('leftover-plain-text'));
});

test('H4: new accounts get a random one-time password and must change it', async () => {
  const admin = await signIn('admin', STRONG);
  const created = await request('POST', '/api/users', {
    token: admin.json.token,
    body: { staffId: 'SS9010', name: 'Fresh Starter', role: 'Designer' }
  });
  assert.strictEqual(created.status, 200);
  const temp = created.json.temporaryPassword;
  assert.ok(temp && temp.length >= 10 && temp !== config.DEFAULT_STAFF_PASSWORD, 'A random temporary password is returned once');
  assert.ok(!JSON.stringify(created.json.member).includes(temp));
  const first = await signIn('freshstarter', temp);
  assert.strictEqual(first.json.mustChangePassword, true);
  const blocked = await request('GET', '/api/projects', { token: first.json.token });
  assert.strictEqual(blocked.status, 403, 'A restricted session can do nothing but change its password');
  assert.strictEqual(blocked.json.code, 'PASSWORD_CHANGE_REQUIRED');
  const changed = await request('POST', '/api/auth/change-password', { token: first.json.token, body: { currentPassword: temp, newPassword: 'My-Own-Strong-Pass-1' } });
  assert.strictEqual(changed.status, 200);
  assert.strictEqual(changed.json.mustChangePassword, false);
  const ok = await request('GET', '/api/projects', { token: changed.json.token });
  assert.strictEqual(ok.status, 200);
});

test('H4: legacy plain-text passwords are hashed at startup', async () => {
  const file = auth.getPasswordStorePath();
  const store = JSON.parse(fs.readFileSync(file, 'utf8'));
  store.legacyuser = 'Plain-Text-Legacy-1';
  fs.writeFileSync(file, JSON.stringify(store));
  assert.ok(auth.migratePlaintextPasswords() >= 1);
  const after = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.ok(after.legacyuser.startsWith('$2'), 'Stored value must now be a bcrypt hash');
  assert.ok(auth.verifyUserPassword('legacyuser', 'Plain-Text-Legacy-1'));
});

test('H5: changing a password signs out every older session', async () => {
  addPerson('SS9020', 'Revoke Me', 'Designer');
  const a = await signIn('revokeme', STRONG);
  assert.strictEqual((await request('GET', '/api/projects', { token: a.json.token })).status, 200);
  const changed = await request('POST', '/api/auth/change-password', { token: a.json.token, body: { currentPassword: STRONG, newPassword: 'Another-Strong-Pass-2' } });
  assert.strictEqual(changed.status, 200);
  const old = await request('GET', '/api/projects', { token: a.json.token });
  assert.strictEqual(old.status, 403);
  assert.strictEqual(old.json.code, 'SESSION_EXPIRED');
  assert.strictEqual((await request('GET', '/api/projects', { token: changed.json.token })).status, 200, 'The replacement session works');
});

test('H5: suspending a person ends their session at once', async () => {
  addPerson('SS9021', 'Suspend Me', 'Designer');
  const user = await signIn('suspendme', STRONG);
  const admin = await signIn('admin', STRONG);
  assert.strictEqual((await request('PUT', '/api/users/SS9021', { token: admin.json.token, body: { active: false } })).status, 200);
  assert.strictEqual((await request('GET', '/api/projects', { token: user.json.token })).status, 403);
  assert.strictEqual((await signIn('suspendme', STRONG)).status, 401, 'A suspended account is told the same thing as a wrong password');
});

test('H5: signing out ends that session', async () => {
  addPerson('SS9022', 'Logout Tester', 'Designer');
  const s = await signIn('logouttester', STRONG);
  assert.strictEqual((await request('POST', '/api/auth/logout', { token: s.json.token })).status, 200);
  assert.strictEqual((await request('GET', '/api/projects', { token: s.json.token })).status, 403);
});

test('H5: a token in the URL is not accepted', async () => {
  addPerson('SS9023', 'Query Tester', 'Designer');
  const s = await signIn('querytester', STRONG);
  const res = await request('GET', `/api/projects?token=${encodeURIComponent(s.json.token)}`);
  assert.strictEqual(res.status, 401);
});

test('H5: only HS256 tokens signed with the server secret are accepted', async () => {
  const base = { id: 'SS0000', username: 'admin', name: 'System Administrator', role: 'Administrator', roles: ['Administrator'], staffId: 'SS0000' };
  const hs512 = jwt.sign(base, config.JWT_SECRET, { algorithm: 'HS512', expiresIn: '1h' });
  assert.strictEqual((await request('GET', '/api/projects', { token: hs512 })).status, 403);
  const none = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url') + '.' + Buffer.from(JSON.stringify(base)).toString('base64url') + '.';
  assert.strictEqual((await request('GET', '/api/projects', { token: none })).status, 403);
  const wrongSecret = jwt.sign(base, 'not-the-real-secret', { algorithm: 'HS256', expiresIn: '1h' });
  assert.strictEqual((await request('GET', '/api/projects', { token: wrongSecret })).status, 403);
});

// ─── Brute force and reset links ───────────────────────────────────────────────

test('H3: repeated bad sign-ins lock the account, but only that account', async () => {
  process.env.RATE_GUARD_ENFORCE = '1';
  try {
    addPerson('SS9030', 'Lock Target', 'Designer');
    addPerson('SS9031', 'Bystander', 'Designer');
    for (let i = 0; i < 10; i++) {
      assert.strictEqual((await signIn('locktarget', 'wrong-password-' + i)).status, 401);
    }
    const locked = await signIn('locktarget', STRONG);
    assert.strictEqual(locked.status, 429, 'The correct password is refused while locked');
    assert.ok(locked.headers['retry-after']);
    // Typing the person's name instead of the username shares the same budget.
    assert.strictEqual((await signIn('Lock Target', STRONG)).status, 429);
    assert.strictEqual((await signIn('bystander', STRONG)).status, 200, 'Colleagues are not affected');
    // Admin unlock.
    const admin = await signIn('admin', STRONG);
    assert.strictEqual((await request('POST', '/api/auth/clear-lockout', { token: admin.json.token, body: { username: 'locktarget' } })).status, 200);
    assert.strictEqual((await signIn('locktarget', STRONG)).status, 200);
  } finally {
    delete process.env.RATE_GUARD_ENFORCE;
  }
});

test('H3: one address spraying many accounts is throttled', async () => {
  process.env.RATE_GUARD_ENFORCE = '1';
  try {
    const { LoginGuard } = require('../middleware/rateGuard');
    LoginGuard.clearAccount('x');
    let blocked = 0;
    for (let i = 0; i < 40; i++) {
      const res = await signIn('nobody-' + i, 'wrong-password-123');
      if (res.status === 429) blocked++;
    }
    assert.ok(blocked > 0, 'A single address must be stopped after too many failures');
  } finally {
    delete process.env.RATE_GUARD_ENFORCE;
  }
});

test('M2: password reset links are stored hashed, single-use and replaced by newer links', async () => {
  const first = auth.createPasswordResetToken('mallory');
  const second = auth.createPasswordResetToken('mallory');
  const stored = fs.readFileSync(auth.getPasswordResetsPath(), 'utf8');
  assert.ok(!stored.includes(first.token) && !stored.includes(second.token), 'Raw tokens must not be on disk');
  assert.strictEqual(auth.verifyPasswordResetToken(first.token).valid, false, 'An older link stops working');
  assert.strictEqual(auth.verifyPasswordResetToken(second.token).valid, true);
  assert.strictEqual(auth.resetPasswordWithToken(second.token, 'Reset-To-This-Pass-3').success, true);
  assert.strictEqual(auth.verifyPasswordResetToken(second.token).valid, false, 'Used link cannot be reused');
});

test('M2: suspended accounts cannot request a reset link; masked email on verify', async () => {
  assert.strictEqual(auth.createPasswordResetToken('suspendme'), null);
  const made = auth.createPasswordResetToken('bystander');
  const verify = await request('POST', '/api/auth/verify-reset-token', { body: { token: made.token } });
  assert.strictEqual(verify.status, 200);
  assert.ok(verify.json.email.includes('*') && !verify.json.email.includes('bystander@'), 'Email must be masked');
});

test('M2: the reset link host comes from configuration, not the request', async () => {
  const EmailService = require('../services/EmailService');
  const original = EmailService.sendPasswordResetEmail;
  let seenBase = null;
  EmailService.sendPasswordResetEmail = async (user, token, base) => { seenBase = base; };
  try {
    const res = await request('POST', '/api/auth/forgot-password', { body: { identifier: 'bystander' }, headers: { Origin: 'https://evil.example' } });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(seenBase, config.APP_URL);
  } finally {
    EmailService.sendPasswordResetEmail = original;
  }
});

test('H8: the server refuses to start in production with a placeholder or weak JWT secret', () => {
  const run = secret => spawnSync(process.execPath, ['-e', "require('./server/config'); process.exit(0)"], {
    cwd: path.resolve(__dirname, '../..'),
    env: { ...process.env, NODE_ENV: 'production', JWT_SECRET: secret, DATA_DIR: dataDir, WORKSPACE_ROOT: sandbox },
    encoding: 'utf8'
  });
  assert.notStrictEqual(run('replace-this-with-a-random-64-character-hex-string-for-production').status, 0);
  assert.notStrictEqual(run('a'.repeat(64)).status, 0);
  assert.notStrictEqual(run('short').status, 0);
  assert.strictEqual(run(require('crypto').randomBytes(32).toString('hex')).status, 0);
});

// ─── Formerly public endpoints ─────────────────────────────────────────────────

const WorkspaceService = require('../services/WorkspaceService');
const DeliverableService = require('../services/DeliverableService');
const ShareService = require('../services/ShareService');

function projectByJobId(jobId) {
  return WorkspaceService.getAllProjects({}).find(p => p.jobId === jobId);
}

function openStream(urlPath, { cookie, token } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.get({ host: '127.0.0.1', port, path: urlPath, headers: { ...(cookie ? { Cookie: cookie } : {}), ...(token ? { Authorization: 'Bearer ' + token } : {}) } }, res => {
      resolve({ status: res.statusCode, type: res.headers['content-type'] });
      res.destroy();
    });
    req.on('error', reject);
  });
}

function cookieFrom(res) {
  const raw = [].concat(res.headers['set-cookie'] || []).find(c => c.startsWith('ss_media='));
  return raw ? { header: raw, pair: raw.split(';')[0] } : null;
}

test('C1: data endpoints that used to be public now need a sign-in', async () => {
  const project = projectByJobId('0086S');
  const deliverable = DeliverableService.getProjectDeliverables(project.fullPath)[0];
  const anonymous = [
    ['GET', '/api/team/live-tasks'],
    ['GET', `/api/projects/${project.id}/asset?path=${encodeURIComponent(deliverable.filename)}`],
    ['GET', `/api/deliverables/preview?id=${deliverable.id}`],
    ['GET', `/api/deliverables/stream?id=${deliverable.id}`],
    ['GET', `/api/deliverables/download?id=${deliverable.id}`],
    ['GET', '/api/orders/ORD-1/attachments/x.png'],
    ['GET', '/api/companies'],
    ['GET', '/api/companies/SSH'],
    ['GET', '/api/regulatory/rules'],
    ['POST', '/api/regulatory/verify'],
    ['GET', '/api/clinic/sops'],
    ['GET', '/api/clinic/care-protocols'],
    ['POST', '/api/clinic/care-dispatch'],
    ['POST', '/api/clinic/branch-inject']
  ];
  for (const [method, url] of anonymous) {
    const res = await request(method, url, method === 'POST' ? { body: {} } : {});
    assert.strictEqual(res.status, 401, `${method} ${url} must require sign-in (got ${res.status})`);
  }
  const events = await openStream('/api/events');
  assert.strictEqual(events.status, 401, 'The live-update stream must require sign-in');
});

test('C1: only clinic branch details stay public (needed by the Signage screen)', async () => {
  assert.strictEqual((await request('GET', '/api/clinic/branches/SSC-BSR')).status, 200);
  assert.strictEqual((await request('GET', '/api/clinic/branches')).status, 200);
  const pub = await request('GET', '/api/companies/public');
  assert.strictEqual(pub.status, 200);
  assert.ok(pub.json.companies.length > 0);
  assert.ok(!('regNo' in pub.json.companies[0]) && !('address' in pub.json.companies[0]) && !('contact' in pub.json.companies[0]));
});

test('C1: the media cookie opens images and live updates, but nothing else', async () => {
  const project = projectByJobId('0086S');
  const deliverable = DeliverableService.getProjectDeliverables(project.fullPath)[0];
  const login = await signIn('admin', STRONG);
  const cookie = cookieFrom(login);
  assert.ok(cookie, 'Sign-in must set the media cookie');
  assert.ok(/HttpOnly/i.test(cookie.header) && /SameSite=Strict/i.test(cookie.header) && /Path=\/api/i.test(cookie.header), 'Cookie must be HttpOnly, SameSite=Strict and limited to /api');

  const preview = await request('GET', `/api/deliverables/preview?id=${deliverable.id}`, { cookie: cookie.pair });
  assert.strictEqual(preview.status, 200, 'Cookie opens a deliverable preview');
  const stream = await openStream('/api/events', { cookie: cookie.pair });
  assert.strictEqual(stream.status, 200);
  assert.ok(String(stream.type).includes('text/event-stream'));

  // It is not a sign-in: normal API routes ignore it, and it is refused as a bearer token.
  assert.strictEqual((await request('GET', '/api/projects', { cookie: cookie.pair })).status, 401);
  const mediaJwt = decodeURIComponent(cookie.pair.split('=')[1]);
  assert.strictEqual((await request('GET', '/api/projects', { token: mediaJwt })).status, 403, 'A media token must not work as an API session');
  assert.strictEqual((await request('PUT', '/api/auth/profile', { cookie: cookie.pair, body: { name: 'x' } })).status, 401);
});

test('C1: revoking a session also ends its media cookie', async () => {
  addPerson('SS9040', 'Cookie Tester', 'Designer');
  const s = await signIn('cookietester', STRONG);
  const cookie = cookieFrom(s).pair;
  const project = projectByJobId('0086S');
  const url = `/api/deliverables/preview?id=${DeliverableService.getProjectDeliverables(project.fullPath)[0].id}`;
  assert.strictEqual((await request('GET', url, { cookie })).status, 200);
  auth.revokeUserSessions('cookietester');
  assert.strictEqual((await request('GET', url, { cookie })).status, 403, 'The cookie stops working when the session is revoked');
});

test('H2: uploaded SVG cannot run scripts and is downloaded when opened as a page', async () => {
  const project = projectByJobId('0086S');
  const dir = path.join(project.fullPath, '05_DELIVERABLES');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'evil.svg'), '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(document.cookie)</script></svg>');
  const admin = await signIn('admin', STRONG);
  const asPage = await request('GET', `/api/projects/${project.id}/asset?path=evil.svg`, { token: admin.json.token, headers: { 'Sec-Fetch-Dest': 'document' } });
  assert.strictEqual(asPage.status, 200);
  assert.ok(/sandbox/.test(asPage.headers['content-security-policy'] || ''), 'SVG must be served with a sandbox CSP');
  assert.ok(/attachment/.test(asPage.headers['content-disposition'] || ''), 'SVG opened as a page must download instead');
  assert.strictEqual(asPage.headers['x-content-type-options'], 'nosniff');
  const asImage = await request('GET', `/api/projects/${project.id}/asset?path=evil.svg`, { token: admin.json.token, headers: { 'Sec-Fetch-Dest': 'image' } });
  assert.ok(!/attachment/.test(asImage.headers['content-disposition'] || ''), 'SVG inside <img> still displays');
});

test('H2: runnable file types are refused as uploads', async () => {
  const project = projectByJobId('0086S');
  const admin = await signIn('admin', STRONG);
  for (const name of ['payload.html', 'run.exe', 'x.ps1']) {
    const res = await request('POST', `/api/projects/${project.id}/ingest`, {
      token: admin.json.token, body: { filename: name, fileData: Buffer.from('x').toString('base64'), targetSubfolder: '01_BRIEF_ASSETS' }
    });
    assert.strictEqual(res.status, 400, name + ' must be refused');
  }
  const ok = await request('POST', `/api/projects/${project.id}/ingest`, {
    token: admin.json.token, body: { filename: 'brief.png', fileData: Buffer.from('x').toString('base64'), targetSubfolder: '01_BRIEF_ASSETS' }
  });
  assert.strictEqual(ok.status, 200);
});

// ─── Share links ───────────────────────────────────────────────────────────────

test('H6: share links: only the designer or a manager can manage them, expiry is capped', async () => {
  const project = projectByJobId('0086S'); // designer: Aliff
  const mallory = await signIn('mallory', 'Reset-To-This-Pass-3');
  assert.strictEqual((await request('POST', '/api/share/generate', { token: mallory.json.token, body: { projectId: project.id } })).status, 403);
  assert.strictEqual((await request('GET', `/api/share/list/${project.id}`, { token: mallory.json.token })).status, 403);

  auth.updateUserPassword('aliff', STRONG);
  const aliff = await signIn('aliff', STRONG);
  const bad = await request('POST', '/api/share/generate', { token: aliff.json.token, body: { projectId: project.id, permissions: 'edit_everything' } });
  assert.strictEqual(bad.status, 400, 'Unknown permission values are refused');
  const forever = await request('POST', '/api/share/generate', { token: aliff.json.token, body: { projectId: project.id, expiresInDays: 0 } });
  assert.strictEqual(forever.status, 201);
  const days = (new Date(forever.json.share.expiresAt) - Date.now()) / 86400000;
  assert.ok(days > 13 && days < 15, 'Zero/permanent becomes the 14 day default');
  const long = await request('POST', '/api/share/generate', { token: aliff.json.token, body: { projectId: project.id, expiresInDays: 9999 } });
  assert.ok((new Date(long.json.share.expiresAt) - Date.now()) / 86400000 <= 30.01, 'Expiry is capped at 30 days');

  assert.strictEqual((await request('DELETE', `/api/share/${long.json.share.token}`, { token: mallory.json.token })).status, 403);
  assert.strictEqual((await request('DELETE', `/api/share/${long.json.share.token}`, { token: aliff.json.token })).status, 200);
});

test('H6: a share link only reaches its own project, and single-file links only their file', async () => {
  const project = projectByJobId('0086S');
  const other = projectByJobId('0085D');
  const [first, second] = DeliverableService.getProjectDeliverables(project.fullPath);
  const otherFile = DeliverableService.getProjectDeliverables(other.fullPath)[0];
  const whole = ShareService.createShareToken({ projectId: project.id, createdBy: 'test', expiresInDays: 7 });
  const single = ShareService.createShareToken({ projectId: project.id, deliverableId: first.id, createdBy: 'test', expiresInDays: 7 });

  const page = await request('GET', `/api/public/review/${whole.token}`);
  assert.strictEqual(page.status, 200);
  assert.ok(!('creative_direction' in page.json.project) && !('copywriting' in page.json.project), 'Internal direction and copy are not sent to guests');
  assert.ok(page.json.deliverables.every(d => String(d.url).startsWith('/api/public/review/')), 'File links point back at the share link');

  const fileUrl = page.json.deliverables[0].previewUrl;
  assert.strictEqual((await request('GET', fileUrl)).status, 200, 'A guest can load a file from their own link');
  assert.strictEqual((await request('GET', `/api/public/review/${whole.token}/file?mode=preview&id=${otherFile.id}`)).status, 404, 'A file from another project is out of scope');
  assert.strictEqual((await request('GET', `/api/public/review/${single.token}/file?mode=preview&id=${second.id}`)).status, 404, 'A single-file link cannot open its sibling');
  assert.strictEqual((await request('GET', `/api/public/review/${single.token}/file?mode=preview&id=${first.id}`)).status, 200);
  assert.strictEqual((await request('GET', `/api/public/review/${single.token}/download`)).status, 403, 'A single-file link cannot download the whole project');
  assert.strictEqual((await request('GET', '/api/public/review/not-a-real-token/file?mode=preview&id=' + first.id)).status, 404);

  // Decisions and comments are scoped too.
  const decide = await request('POST', `/api/public/review/${single.token}/decision`, { body: { decision: 'approved', reviewerName: 'Guest', deliverableId: second.id } });
  assert.strictEqual(decide.status, 403);
  const long = await request('POST', `/api/public/review/${whole.token}/comments`, { body: { content: 'x'.repeat(5000), reviewerName: 'Guest' } });
  assert.strictEqual(long.status, 201);
  assert.ok(long.json.comment.content.length <= 2000, 'Guest comments are length-limited');
});

test('H6: guests never see internal staff comments', async () => {
  const project = projectByJobId('0086S');
  const CommentService = require('../services/CommentService');
  CommentService.addComment(project.fullPath, project.jobId, { author: 'Staff', authorRole: 'Designer', content: 'INTERNAL: client is difficult' });
  const link = ShareService.createShareToken({ projectId: project.id, createdBy: 'test', expiresInDays: 7 });
  const page = await request('GET', `/api/public/review/${link.token}`);
  assert.ok(!JSON.stringify(page.json).includes('client is difficult'));
  const list = await request('GET', `/api/public/review/${link.token}/comments`);
  assert.ok(!JSON.stringify(list.json).includes('client is difficult'));
});

test('H6: view-only links cannot approve or comment', async () => {
  const project = projectByJobId('0086S');
  const link = ShareService.createShareToken({ projectId: project.id, permissions: 'view_only', createdBy: 'test', expiresInDays: 7 });
  assert.strictEqual((await request('POST', `/api/public/review/${link.token}/decision`, { body: { decision: 'approved', reviewerName: 'G' } })).status, 403);
  assert.strictEqual((await request('POST', `/api/public/review/${link.token}/comments`, { body: { content: 'hi', reviewerName: 'G' } })).status, 403);
});

// ─── Other server-side hardening ───────────────────────────────────────────────

test('H7: archive is admin-only, stays inside the workspace and never deletes without confirmation', async () => {
  const project = projectByJobId('0088D');
  const mallory = await signIn('mallory', 'Reset-To-This-Pass-3');
  assert.strictEqual((await request('POST', '/api/projects/archive', { token: mallory.json.token, body: { projectIds: [project.id] } })).status, 403, 'Designers cannot archive');
  const admin = await signIn('admin', STRONG);
  const outside = await request('POST', '/api/projects/archive', { token: admin.json.token, body: { projectIds: [project.id], archiveRoot: os.tmpdir() } });
  assert.strictEqual(outside.status, 400, 'An archive location outside the workspace is refused');
  const noConfirm = await request('POST', '/api/projects/archive', { token: admin.json.token, body: { projectIds: [project.id], copyOnly: false } });
  assert.strictEqual(noConfirm.status, 400, 'Removing originals needs explicit confirmation');
  assert.ok(fs.existsSync(project.fullPath), 'Nothing was deleted');
});

test('M8: the full seed-account list is admin-only', async () => {
  const mallory = await signIn('mallory', 'Reset-To-This-Pass-3');
  assert.strictEqual((await request('GET', '/api/auth/users', { token: mallory.json.token })).status, 403);
  const admin = await signIn('admin', STRONG);
  assert.strictEqual((await request('GET', '/api/auth/users', { token: admin.json.token })).status, 200);
});

test('M6: server errors never reveal internal messages or paths', async () => {
  const original = WorkspaceService.getProjectById;
  WorkspaceService.getProjectById = () => { throw new Error('ENOENT: no such file \\\\SSNAS\\Creative-Team\\secret'); };
  try {
    const admin = await signIn('admin', STRONG);
    const res = await request('GET', '/api/projects/anything', { token: admin.json.token });
    assert.strictEqual(res.status, 500);
    assert.ok(!res.raw.includes('SSNAS') && !res.raw.includes('ENOENT'), 'Internal details must not be returned');
    assert.ok(res.json.reference, 'A reference is returned so an admin can find the log entry');
  } finally {
    WorkspaceService.getProjectById = original;
  }
});

// ─── Role enforcement and remaining hardening ──────────────────────────────────

test('M8: orders can only be changed by the requester or the design team (no fuzzy name matching)', async () => {
  addPerson('SS9050', 'Cora Writer', 'Copywriter');
  addPerson('SS9051', 'Cora', 'Copywriter'); // a name that is a prefix of the first one
  addPerson('SS9052', 'Dan Writer', 'Copywriter');
  const cora = await signIn('corawriter', STRONG);
  const coraShort = await signIn('cora', STRONG);
  const dan = await signIn('danwriter', STRONG);
  const admin = await signIn('admin', STRONG);

  const created = await request('POST', '/api/orders', {
    token: cora.json.token,
    body: { title: 'Poster', entity: 'SS', priority: 'normal', format: 'social_1x1', copy: 'Hello', targetDate: '2030-01-01' }
  });
  assert.strictEqual(created.status, 201);
  const id = created.json.order.id;
  assert.strictEqual(created.json.order.requesterStaffId, 'SS9050');

  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: dan.json.token, body: { title: 'Hacked' } })).status, 403, 'Another team member cannot edit the brief');
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: coraShort.json.token, body: { title: 'Hacked' } })).status, 403, 'A name that is only a prefix does not make you the owner');
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: dan.json.token, body: { status: 'done' } })).status, 403);
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: cora.json.token, body: { status: 'done' } })).status, 403, 'The requester cannot mark their own request done');
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: cora.json.token, body: { assignedTo: 'Someone' } })).status, 403);
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: cora.json.token, body: { title: 'Poster v2' } })).status, 200, 'The requester can edit their brief');
  assert.strictEqual((await request('DELETE', `/api/orders/${id}`, { token: dan.json.token })).status, 403);
  assert.strictEqual((await request('POST', `/api/orders/${id}/attachments`, { token: dan.json.token, body: { filename: 'a.png', fileData: 'eA==' } })).status, 403);
  assert.strictEqual((await request('POST', `/api/orders/${id}/import-to-project`, { token: cora.json.token, body: {} })).status, 403, 'Only the design team imports into a project');
  assert.strictEqual((await request('PATCH', `/api/orders/${id}`, { token: admin.json.token, body: { status: 'in_progress' } })).status, 200, 'The design team can move it along');
  assert.strictEqual((await request('DELETE', `/api/orders/${id}`, { token: cora.json.token })).status, 200, 'The requester can cancel their own request');
});

test('M8: only project managers can reassign a project', async () => {
  const project = projectByJobId('0086S');
  const mallory = await signIn('mallory', 'Reset-To-This-Pass-3');
  const res = await request('POST', `/api/projects/${project.id}/reassign`, { token: mallory.json.token, body: { newDesigner: 'Mallory' } });
  assert.strictEqual(res.status, 403);
});

test('M8: personal notes stay private and only their owner can delete them', async () => {
  const alice = addPerson('SS9060', 'Alice Notes', 'Designer');
  const bob = addPerson('SS9061', 'Bob Notes', 'Designer');
  const a = await signIn('alicenotes', STRONG);
  const b = await signIn('bobnotes', STRONG);
  const saved = await request('POST', '/api/notes', { token: a.json.token, body: { id: 'alice_private', title: 'Alice secret', body: 'for my eyes only' } });
  assert.strictEqual(saved.status, 200);
  const bobView = await request('GET', '/api/notes', { token: b.json.token });
  assert.ok(!bobView.raw.includes('Alice secret'), "Bob must not see Alice's personal note");
  const aliceView = await request('GET', '/api/notes', { token: a.json.token });
  assert.ok(aliceView.raw.includes('Alice secret'), 'Alice still sees her own note');
  const bobDelete = await request('DELETE', '/api/notes/alice_private', { token: b.json.token });
  assert.strictEqual(bobDelete.json.deleted, false, "Bob cannot delete Alice's note");
  assert.strictEqual((await request('DELETE', '/api/notes/alice_private', { token: a.json.token })).json.deleted, true);
});

test('M4: webhooks accept only real chat addresses and are admin-only, with masked addresses', async () => {
  const admin = await signIn('admin', STRONG);
  const mallory = await signIn('mallory', 'Reset-To-This-Pass-3');
  const post = body => request('POST', '/api/webhooks', { token: admin.json.token, body });

  assert.strictEqual((await post({ name: 'x', url: 'http://discord.com/api/webhooks/1/abc', serviceType: 'discord' })).status, 400, 'http is refused');
  assert.strictEqual((await post({ name: 'x', url: 'https://evil.example/hook', serviceType: 'discord' })).status, 400, 'A different host is refused for a chat service');
  assert.strictEqual((await post({ name: 'x', url: 'https://user:pw@discord.com/api/webhooks/1/abc', serviceType: 'discord' })).status, 400, 'Credentials in the address are refused');
  const ok = await post({ name: 'Studio', url: 'https://discord.com/api/webhooks/123456/SECRETTOKENabcd', serviceType: 'discord' });
  assert.strictEqual(ok.status, 201);

  const list = await request('GET', '/api/webhooks', { token: admin.json.token });
  assert.strictEqual(list.status, 200);
  assert.ok(!list.raw.includes('SECRETTOKEN'), 'The secret part of the address must not be returned');
  assert.strictEqual((await request('GET', '/api/webhooks', { token: mallory.json.token })).status, 403, 'Only admins can list webhooks');

  // Internal addresses are refused when testing a custom gateway.
  const probe = await request('POST', '/api/webhooks/test', { token: admin.json.token, body: { url: 'https://127.0.0.1/hook', serviceType: 'generic' } });
  assert.strictEqual(probe.status, 400);
  assert.ok(/private network/i.test(probe.json.error));
  const meta = await request('POST', '/api/webhooks/test', { token: admin.json.token, body: { url: 'https://169.254.169.254/latest/meta-data', serviceType: 'generic' } });
  assert.strictEqual(meta.status, 400);

  await request('DELETE', `/api/webhooks/${ok.json.webhook.id}`, { token: admin.json.token });
});

test('M1: names and task titles cannot inject markup into emails', async () => {
  const EmailService = require('../services/EmailService');
  const original = EmailService.sendMail;
  let sent = null;
  EmailService.sendMail = async (mail) => { sent = mail; return { success: true }; };
  try {
    await EmailService.sendTaskAssignedEmail(
      { email: 'a@example.test', name: '<script>alert(1)</script>' },
      { name: '<img src=x onerror=alert(1)>', notes: '<b onmouseover=x>hi</b>', role: 'designer' },
      { id: 'P1', title: '"><svg onload=alert(1)>', brand: 'SS' },
      '<i>Boss</i>'
    );
    assert.ok(sent && sent.html, 'An email was produced');
    assert.ok(!/<script>alert|<img src=x|<svg onload|<b onmouseover|<i>Boss/.test(sent.html), 'No raw markup from user data may appear in the email');
    assert.ok(sent.html.includes('&lt;img src=x'), 'The text is shown, escaped');
  } finally {
    EmailService.sendMail = original;
  }
});

test('M5: the AI key is only ever shown by its last four characters', () => {
  const GeminiService = require('../services/GeminiService');
  process.env.GEMINI_API_KEY = 'AIzaSyEXAMPLEKEY0123456789abcd';
  try {
    const status = GeminiService.getStatus();
    assert.strictEqual(status.configured, true);
    assert.ok(status.maskedKey.endsWith('abcd') && !status.maskedKey.includes('AIza') && !status.maskedKey.includes('EXAMPLE'));
  } finally {
    delete process.env.GEMINI_API_KEY;
  }
});

// ─── Runner ────────────────────────────────────────────────────────────────────

(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api', require('../routes/api'));
  server = await new Promise(r => { const s = app.listen(0, '127.0.0.1', () => r(s)); });
  port = server.address().port;

  // A known admin password for the test data directory only.
  auth.updateUserPassword('admin', STRONG);

  let passed = 0;
  let failed = 0;
  for (const { name, fn } of tests) {
    try {
      await fn();
      console.log(`  ✅ PASS: ${name}`);
      passed++;
    } catch (err) {
      console.log(`  ❌ FAIL: ${name}\n     ${err && err.message}`);
      failed++;
    }
  }
  server.close();
  console.log(`\nSecurity tests: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();

const fs = require('fs');
const path = require('path');
const os = require('os');
const bcrypt = require('../../src/SS-CAM.Web/node_modules/bcryptjs');

const tempBase = path.join(os.tmpdir(), 'sscam-phase3-' + Date.now());
const dataDir = path.join(tempBase, 'data');
const wsDir = path.join(tempBase, 'workspace');

fs.mkdirSync(dataDir, { recursive: true });
fs.mkdirSync(wsDir, { recursive: true });

// Copy sample-workspace to wsDir
function copyDir(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

const sampleWs = path.resolve(__dirname, '../../src/SS-CAM.Web/sample-workspace');
copyDir(sampleWs, wsDir);

// Setup admin password (AdminPassword123!)
const hash = bcrypt.hashSync('AdminPassword123!', 4);
fs.writeFileSync(path.join(dataDir, 'user_passwords.json'), JSON.stringify({ admin: hash }, null, 2), 'utf8');
fs.writeFileSync(path.join(dataDir, 'auth_state.json'), JSON.stringify({ tokenVersions: { admin: 1 }, mustChange: {} }, null, 2), 'utf8');

process.env.PORT = '4107';
process.env.HOST = '127.0.0.1';
process.env.NODE_ENV = 'test';
process.env.WORKSPACE_ROOT = wsDir;
process.env.DATA_DIR = dataDir;
process.env.ALLOWED_ORIGINS = 'http://localhost:4107,http://127.0.0.1:4107';
process.env.JWT_SECRET = 'phase3-verification-secret-32-chars-long-rnd-abc123';

console.log('[Phase3Server] Starting server with:');
console.log('  WORKSPACE_ROOT:', wsDir);
console.log('  DATA_DIR:', dataDir);

require('../../src/SS-CAM.Web/server/index.js');

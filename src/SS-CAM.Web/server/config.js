const path = require('path');
const fs = require('fs');

// Load environment variables from .env file if present (override ensures .env values take precedence)
try {
  const envCandidates = [
    path.resolve(__dirname, '../.env'),
    path.resolve(process.cwd(), '.env'),
    path.resolve(__dirname, '../../.env')
  ];
  for (const envPath of envCandidates) {
    if (fs.existsSync(envPath)) {
      require('dotenv').config({ path: envPath, override: true });
      break;
    }
  }
} catch (e) {
  console.error('[Config] Failed to load .env file:', e.message);
}

const envWorkspace = process.env.WORKSPACE_ROOT;
const uncNasPath = '\\\\SSNAS\\Creative-Team';
const localSyncCandidates = [
  'D:\\SynologyDrive\\Creative-Team',
  'C:\\SynologyDrive\\Creative-Team',
  'E:\\SynologyDrive\\Creative-Team',
  path.join(process.env.USERPROFILE || '', 'SynologyDrive', 'Creative-Team'),
  path.join(process.env.USERPROFILE || '', 'Synology Drive', 'Creative-Team')
];
const linuxNasPath = '/volume1/Creative-Team';
const linuxNasVolume2Path = '/volume2/Creative-Team';
const fallbackLocalWorkspace = path.resolve(__dirname, '../sample-workspace');

function isPathAccessible(dirPath) {
  try {
    if (!dirPath) return false;
    fs.readdirSync(dirPath);
    return true;
  } catch (e) {
    return false;
  }
}

const overrideConfigPath = path.resolve(__dirname, 'workspace_config.json');
let userOverridePath = null;
if (fs.existsSync(overrideConfigPath)) {
  try {
    const raw = JSON.parse(fs.readFileSync(overrideConfigPath, 'utf8'));
    if (raw && raw.workspaceRoot && isPathAccessible(raw.workspaceRoot)) {
      userOverridePath = raw.workspaceRoot;
    }
  } catch (e) {
    console.debug('[Config] Failed to read workspace_config.json:', e.message);
  }
}

let resolvedWorkspace = fallbackLocalWorkspace;

if (envWorkspace && isPathAccessible(envWorkspace)) {
  resolvedWorkspace = envWorkspace;
} else if (userOverridePath) {
  resolvedWorkspace = userOverridePath;
} else if (process.platform === 'win32' && isPathAccessible(uncNasPath)) {
  resolvedWorkspace = uncNasPath;
} else if (process.platform === 'win32') {
  const foundLocal = localSyncCandidates.find(p => isPathAccessible(p));
  if (foundLocal) {
    resolvedWorkspace = foundLocal;
  } else if (isPathAccessible(fallbackLocalWorkspace)) {
    resolvedWorkspace = fallbackLocalWorkspace;
  }
} else if (isPathAccessible(linuxNasPath)) {
  resolvedWorkspace = linuxNasPath;
} else if (isPathAccessible(linuxNasVolume2Path)) {
  resolvedWorkspace = linuxNasVolume2Path;
} else {
  resolvedWorkspace = fallbackLocalWorkspace;
}

const isProduction = (process.env.NODE_ENV || '').toLowerCase() === 'production';
const rawJwtSecret = (process.env.JWT_SECRET || '').trim();
if (isProduction && (!rawJwtSecret || rawJwtSecret.length < 32)) {
  console.error('[Config] CRITICAL SECURITY ERROR: JWT_SECRET environment variable is missing, empty, or shorter than 32 characters in production mode.');
  console.error('[Config] Refusing to start server without a strong explicit JWT_SECRET (min 32 characters).');
  process.exit(1);
}

const envDataDir = process.env.DATA_DIR;
const resolvedDataDir = envDataDir ? path.resolve(envDataDir) : path.resolve(__dirname, '../data');
if (!fs.existsSync(resolvedDataDir)) {
  try {
    fs.mkdirSync(resolvedDataDir, { recursive: true });
  } catch (e) {
    console.error('[Config] Failed to create DATA_DIR:', e.message);
  }
}

const defaultOrigins = [
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:4000',
  'http://127.0.0.1:4000',
  'https://creative.suamisihat.myds.me'
];
const configuredOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim()).filter(Boolean)
  : defaultOrigins;

module.exports = {
  PORT: process.env.PORT || 4000,
  HOST: process.env.HOST || '0.0.0.0',
  JWT_SECRET: process.env.JWT_SECRET || (isProduction ? '' : 'ss-cam-creative-dev-secret-only-rotate-in-production'),
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '12h',
  DATA_DIR: resolvedDataDir,
  ALLOWED_ORIGINS: configuredOrigins,
  WORKSPACE_ROOT: resolvedWorkspace,
  DEFAULT_NAS_PATH: process.platform === 'win32' ? uncNasPath : linuxNasPath,
  FALLBACK_LOCAL_WORKSPACE: fallbackLocalWorkspace,
  APP_TITLE: 'SuamiSihat Creative Team Portal',
  VERSION: '4.12.2'
};

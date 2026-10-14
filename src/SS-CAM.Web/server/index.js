const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const config = require('./config');
const apiRoutes = require('./routes/api');

const compression = require('compression');

const app = express();

// Trust the first hop from Synology Nginx Reverse Proxy.
// Without this, Express sees req.ip as the Docker bridge gateway (172.17.0.1)
// for ALL users, causing the rate limiter to lock out the entire office after
// just 5 failed login attempts by anyone.
app.set('trust proxy', 1);

// Security Headers via Helmet (CSP tuned for Vite bundle, Svelte, and Mermaid SVG/Worker rendering)
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      // Scripts only from this site: the built client has no inline scripts and uses no eval.
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      imgSrc: ["'self'", "data:", "blob:"],
      fontSrc: ["'self'", "data:", "https://fonts.gstatic.com"],
      mediaSrc: ["'self'", "blob:"],
      connectSrc: ["'self'", ...config.ALLOWED_ORIGINS],
      workerSrc: ["'self'", "blob:"],
      objectSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"]
    }
  },
  crossOriginEmbedderPolicy: false
}));

// High-performance gzip/deflate response compression
app.use(compression({
  threshold: 1024, // Compress responses larger than 1KB
  filter: (req, res) => {
    if (req.headers.accept && req.headers.accept.includes('text/event-stream')) {
      return false; // Never compress SSE stream
    }
    return compression.filter(req, res);
  }
}));

const corsOptions = {
  origin: (origin, callback) => {
    // Allow non-browser requests with no origin (e.g. mobile app, SS-CAM desktop, curl)
    if (!origin) return callback(null, true);
    if (config.ALLOWED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }
    return callback(Object.assign(new Error('This site is not allowed to use the portal.'), { status: 403 }));
  }
};

app.use(cors(corsOptions));
// Request size limits depend on the route. Anything that anonymous visitors can reach is tiny;
// only file uploads sent as base64 get a large allowance.
const jsonTiny = express.json({ limit: '100kb', strict: false });
const jsonStandard = express.json({ limit: '2mb', strict: false });
const jsonProfile = express.json({ limit: '8mb', strict: false });
const jsonUpload = express.json({ limit: '60mb', strict: false });
app.use((req, res, next) => {
  const p = req.path;
  const tinyAuthPaths = ['/api/auth/login', '/api/auth/forgot-password', '/api/auth/verify-reset-token', '/api/auth/reset-password'];
  if (tinyAuthPaths.includes(p) || p.startsWith('/api/public/')) return jsonTiny(req, res, next);
  const isIngest = p.startsWith('/api/projects/') && p.endsWith('/ingest');
  if (isIngest || p.startsWith('/api/orders') || p.startsWith('/api/assets/')) return jsonUpload(req, res, next);
  if (p === '/api/auth/profile' || p.startsWith('/api/users') || p.startsWith('/api/team/roster') || p.startsWith('/api/notes')) return jsonProfile(req, res, next);
  return jsonStandard(req, res, next);
});
app.use(express.urlencoded({ extended: true, limit: '100kb' }));

// API Routes (mounted at /api)
app.use('/api', apiRoutes);

// Static client assets (Prioritize Vite production build dist)
const fs = require('fs');
const candidates = [
  path.resolve(__dirname, '../client/dist'),
  path.resolve(__dirname, '../../src/SS-CAM.Web/client/dist'),
  path.resolve(__dirname, '../src/SS-CAM.Web/client/dist'),
  path.resolve(__dirname, './src/SS-CAM.Web/client/dist'),
  path.resolve(__dirname, './client/dist'),
  path.resolve(__dirname, '../client')
];
const clientPath = candidates.find(p => fs.existsSync(path.join(p, 'index.html'))) || path.resolve(__dirname, '../client');
console.log(`[Static] Serving client assets from: ${clientPath}`);

app.use(express.static(clientPath, {
  maxAge: '1y',
  immutable: true,
  setHeaders: (res, filePath) => {
    // HTML must NEVER be cached so users always receive latest code
    if (filePath.endsWith('.html') || filePath.endsWith('sw.js')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (filePath.includes('/assets/') || filePath.includes('\\assets\\')) {
      // Hashed assets from Vite can be cached permanently
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    }
  }
}));

// SPA fallback
app.get('*', (req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ error: 'Endpoint not found' });
  }
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.sendFile(path.join(clientPath, 'index.html'));
});

// Error handling middleware. People never see stack traces, file paths or internal messages:
// the details go to the server log under a short reference they can quote to an admin.
app.use((err, req, res, next) => {
  const status = err.status || err.statusCode || 500;
  if (status >= 500) {
    const reference = crypto.randomUUID().slice(0, 8);
    console.error(`[Server Error ${reference}] ${req.method} ${req.originalUrl}`, err);
    return res.status(status).json({
      error: 'Something went wrong on our side. Please try again, and tell an admin if it keeps happening.',
      reference
    });
  }
  res.status(status).json({ error: err.expose || err.status ? (err.message || 'Bad request.') : 'Bad request.' });
});

// One-time clean-up of credentials and roster roleKey migration.
try {
  require('./middleware/auth').migratePlaintextPasswords();
  require('./services/TeamService').scrubStoredCredentials();
  require('./services/TeamService').migrateRosterRoleKeys();
} catch (e) {
  console.error('[Startup] Credential clean-up or roleKey migration did not complete:', e.message);
}

app.listen(config.PORT, config.HOST, () => {
  console.log('================================================================');
  console.log(`🚀 SuamiSihat Creative Team Management Web Portal`);
  console.log(`🌐 Server running at: http://${config.HOST === '0.0.0.0' ? 'localhost' : config.HOST}:${config.PORT}`);
  console.log(`📂 Workspace Root:   ${config.WORKSPACE_ROOT}`);
  console.log(`🔒 Environment:      Production Ready`);
  console.log('================================================================');
});

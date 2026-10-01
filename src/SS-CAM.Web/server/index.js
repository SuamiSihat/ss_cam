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
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:"],
      fontSrc: ["'self'", "data:"],
      connectSrc: ["'self'", ...config.ALLOWED_ORIGINS],
      workerSrc: ["'self'", "blob:"]
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
    return callback(new Error(`CORS policy blocked access from origin: ${origin}`));
  },
  credentials: true
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '1mb', strict: false }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

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

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('[Server Error]', err);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: status === 500 ? 'Internal Server Error' : (err.message || 'Bad Request'),
    message: err.message
  });
});

app.listen(config.PORT, config.HOST, () => {
  console.log('================================================================');
  console.log(`🚀 SuamiSihat Creative Team Management Web Portal`);
  console.log(`🌐 Server running at: http://${config.HOST === '0.0.0.0' ? 'localhost' : config.HOST}:${config.PORT}`);
  console.log(`📂 Workspace Root:   ${config.WORKSPACE_ROOT}`);
  console.log(`🔒 Environment:      Production Ready`);
  console.log('================================================================');
});

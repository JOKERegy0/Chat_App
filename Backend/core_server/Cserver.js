const http = require('http');
const https = require('https');
const express = require('express');

const app = express();
// Render puts one proxy in front of us: req.ip is the address that proxy saw,
// so a client cannot fake it by sending its own X-Forwarded-For header.
app.set('trust proxy', 1);

const INTERNAL_SERVICE_SECRET = process.env.INTERNAL_SERVICE_SECRET;
if (!INTERNAL_SERVICE_SECRET) {
  console.error('Missing INTERNAL_SERVICE_SECRET environment variable');
  process.exit(1);
}

// upstream services (set these in Render environment variables)
const UPSTREAMS = {
  auth: process.env.INTERNAL_AUTH_SERVER,
  security: process.env.INTERNAL_SECURITY_SERVER,
  media: process.env.INTERNAL_MEDIA_SERVER,
  daily: process.env.INTERNAL_DAILY_SERVER,
};

// ---------- simple per-IP rate limit ----------
const WINDOW_MS = 60 * 1000;
const MAX_REQUESTS = 120;
const hits = new Map();

setInterval(() => hits.clear(), WINDOW_MS).unref();

app.use((req, res, next) => {
  const count = (hits.get(req.ip) || 0) + 1;
  hits.set(req.ip, count);
  if (count > MAX_REQUESTS) {
    return res.status(429).json({ error: 'Too many requests' });
  }
  next();
});

// ---------- streaming reverse proxy (works for JSON and file uploads) ----------
function proxy(targetBase, mapPath) {
  return (req, res) => {
    if (!targetBase) {
      return res.status(503).json({ error: 'Service not configured' });
    }
    const target = new URL(targetBase);
    const lib = target.protocol === 'https:' ? https : http;

    const headers = { ...req.headers };
    delete headers['x-forwarded-for'];
    delete headers['x-client-ip'];
    headers['host'] = target.host;
    headers['x-client-ip'] = req.ip;
    headers['x-forwarded-by'] = 'kiura-gateway';
    headers['x-service-secret'] = INTERNAL_SERVICE_SECRET;

    const upstream = lib.request(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port || undefined,
        method: req.method,
        path: mapPath(req.originalUrl),
        headers,
        timeout: 20000,
      },
      (upRes) => {
        res.writeHead(upRes.statusCode, upRes.headers);
        upRes.pipe(res);
      }
    );

    upstream.on('timeout', () => upstream.destroy(new Error('timeout')));
    upstream.on('error', () => {
      if (!res.headersSent) res.status(502).json({ error: 'Upstream unavailable' });
      else res.end();
    });

    req.pipe(upstream);
  };
}

app.get('/health', (req, res) => {
  res.json({ status: 'ONLINE', service: 'kiura-gateway' });
});

// public path on the gateway  ->  path on the internal service
app.use('/api/auth', proxy(UPSTREAMS.auth, (u) => u.replace(/^\/api\/auth/, '/api/v1/auth')));
app.use('/api/security', proxy(UPSTREAMS.security, (u) => u.replace(/^\/api\/security/, '/api/v1/security')));
app.use('/api/media', proxy(UPSTREAMS.media, (u) => u.replace(/^\/api\/media/, '/api/v1/media')));
app.use('/api/daily', proxy(UPSTREAMS.daily, (u) => u.replace(/^\/api\/daily/, '/api/requests')));

app.use((req, res) => res.status(404).json({ error: 'Not found' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`KIURA gateway running on port ${PORT}`);
});

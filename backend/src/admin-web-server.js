'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.ADMIN_WEB_PORT || '8082', 10);
const HOST = process.env.ADMIN_WEB_HOST || '0.0.0.0';
const ROOT_DIR = path.resolve(__dirname, '..', 'public', 'admin');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
};

function sendError(res, status, message) {
  res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(message);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return sendError(res, 405, 'Method Not Allowed');
  }

  let reqPath = '/';
  try {
    const parsed = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    reqPath = decodeURIComponent(parsed.pathname);
  } catch {
    return sendError(res, 400, 'Bad Request');
  }

  const relative = reqPath === '/' ? 'index.html' : reqPath.replace(/^\/+/, '');
  const resolved = path.resolve(ROOT_DIR, relative);
  if (resolved !== ROOT_DIR && !resolved.startsWith(ROOT_DIR + path.sep)) {
    return sendError(res, 403, 'Forbidden');
  }

  fs.stat(resolved, (statErr, stat) => {
    const targetFile = !statErr && stat.isDirectory()
      ? path.join(resolved, 'index.html')
      : resolved;

    fs.readFile(targetFile, (readErr, data) => {
      if (readErr) {
        return sendError(res, 404, 'Not Found');
      }
      const ext = path.extname(targetFile).toLowerCase();
      res.writeHead(200, {
        'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
        'Cache-Control': 'no-store, no-cache, must-revalidate',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'SAMEORIGIN',
      });
      if (req.method === 'HEAD') return res.end();
      return res.end(data);
    });
  });
});

server.listen(PORT, HOST, () => {
  console.log(`STA Admin Web listening on ${HOST}:${PORT}`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    server.close(() => process.exit(0));
  });
}

// prepare_web_pwa.mjs injects the exact release hashes and complete file list.
const VERSION = '__BUILD_VERSION__';
const FILES = /* __PRECACHE_FILES__ */ [];
const ROOT = self.registration.scope;
const PREFIX = `boomerang-arena-pwa-${encodeURIComponent(ROOT)}-`;
const CACHE = `${PREFIX}${VERSION}`;
const URLS = new Set(FILES.map(file => new URL(file.path, ROOT).href));
const HOME = new URL('index.html', ROOT).href;
let repairJob;

async function broadcast(message) {
  const clients = await self.clients.matchAll({ includeUncontrolled: true, type: 'window' });
  clients.filter(client => client.url.startsWith(ROOT)).forEach(client => client.postMessage(message));
}

async function prepare(cache, onlyMissing = false) {
  let complete = 0, bytes = 0;
  const totalBytes = FILES.reduce((sum, file) => sum + file.bytes, 0);
  for (const file of FILES) {
    const url = new URL(file.path, ROOT).href;
    if (!onlyMissing || !await cache.match(url)) {
      const response = await fetch(new Request(url, { cache: 'reload' }));
      if (!response.ok) throw new Error(`Download failed: ${file.path}`);
      const content = await response.clone().arrayBuffer();
      const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', content))]
        .map(byte => byte.toString(16).padStart(2, '0')).join('');
      if (content.byteLength !== file.bytes || hash !== file.sha256) throw new Error(`Release mismatch: ${file.path}`);
      await cache.put(url, response);
    }
    bytes += file.bytes;
    await broadcast({ type: 'PWA_PROGRESS', version: VERSION, complete: ++complete, total: FILES.length, bytes, totalBytes });
  }
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    if (!FILES.length) throw new Error('Build the PWA before installing it');
    const cache = await caches.open(CACHE);
    try {
      await prepare(cache);
    } catch (error) {
      await caches.delete(CACHE);
      await broadcast({ type: 'PWA_FAILED', version: VERSION });
      throw error;
    }
    // A new release stays waiting until the user accepts or all old tabs close.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith(PREFIX) && key !== CACHE).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', event => {
  if (event.data?.type === 'SKIP_WAITING') event.waitUntil(self.skipWaiting());
  if (event.data?.type === 'PWA_STATUS') {
    event.waitUntil((async () => {
      const cache = await caches.open(CACHE);
      const responses = await Promise.all([...URLS].map(url => cache.match(url)));
      event.source?.postMessage({ type: responses.every(Boolean) ? 'PWA_READY' : 'PWA_MISSING', version: VERSION });
    })());
  }
  if (event.data?.type === 'PWA_REPAIR') {
    event.waitUntil((async () => {
      try {
        if (!repairJob) repairJob = caches.open(CACHE).then(cache => prepare(cache, true)).finally(() => { repairJob = undefined; });
        await repairJob;
        event.source?.postMessage({ type: 'PWA_READY', version: VERSION });
      } catch {
        event.source?.postMessage({ type: 'PWA_FAILED', version: VERSION });
      }
    })());
  }
});

async function cachedResponse(request, key) {
  const response = await (await caches.open(CACHE)).match(key);
  if (!response) return fetch(request);
  const range = request.headers.get('Range');
  if (!range) return response;
  const match = /^bytes=(\d*)-(\d*)$/.exec(range);
  if (!match || (!match[1] && !match[2])) return response;
  const body = await response.arrayBuffer();
  const start = match[1] ? Number(match[1]) : Math.max(0, body.byteLength - Number(match[2]));
  const end = match[1] && match[2] ? Math.min(Number(match[2]), body.byteLength - 1) : body.byteLength - 1;
  if (start > end || start >= body.byteLength) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${body.byteLength}` } });
  const headers = new Headers(response.headers);
  headers.set('Content-Range', `bytes ${start}-${end}/${body.byteLength}`);
  headers.set('Content-Length', String(end - start + 1));
  return new Response(body.slice(start, end + 1), { status: 206, headers });
}

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !url.href.startsWith(ROOT)) return;
  url.search = '';
  url.hash = '';
  const key = event.request.mode === 'navigate' && (url.href === ROOT || url.href === HOME) ? HOME : url.href;
  // Do not intercept /health, other Pages projects or the worker update request.
  if (URLS.has(key)) event.respondWith(cachedResponse(event.request, key));
});

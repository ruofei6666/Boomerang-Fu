// prepare_web_pwa.mjs injects the exact release hashes and complete file list.
const VERSION = "955358fa1efbd9d55bf8";
const FILES = [{"path":"index.html","bytes":8865,"sha256":"126ab64dbab5f985e6844dc741930cb49e7ba2620bbb0b4b51c9c3e3a9620458"},{"path":"index.js","bytes":279850,"sha256":"49e4c8182c9d38e96d98848dfd611708d2d13516d70bf1cae6bfdfad4707c90d"},{"path":"index.wasm","bytes":39514754,"sha256":"fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0"},{"path":"index.pck","bytes":1857140,"sha256":"fe085ac6433736f2e2182dbcf783c232d7998e65d1727e91840fc7a4f0c734fe"},{"path":"index.png","bytes":21443,"sha256":"3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e"},{"path":"index.audio.worklet.js","bytes":7298,"sha256":"5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3"},{"path":"index.audio.position.worklet.js","bytes":2973,"sha256":"be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8"},{"path":"pwa.js","bytes":10211,"sha256":"acbd4a102fac769d3892fe95d1493df3110484a96cf5aa8433f7ee2601d5ee36"},{"path":"pwa.css","bytes":5686,"sha256":"3240ce485932f3d3b5c35c8b858059534514560043141167bbf371aba7aaab0c"},{"path":"manifest.webmanifest","bytes":700,"sha256":"cad2c61e60f91237311b6c2078b26c785193510a13bbbfe5f8194200690e3110"},{"path":"icons/icon-192.png","bytes":25348,"sha256":"351e7f437d43584702391bff8bd6d9568cf655a6454bf4c14d411e5a4c34fe0b"},{"path":"icons/icon-512.png","bytes":138197,"sha256":"4ca150a6e65e14d1004de8c349cf32a1658804860c34e86eb917295b086cf8f7"},{"path":"icons/icon-maskable-512.png","bytes":87096,"sha256":"0e11b8b88e73f2541eabb2f856b8425c75a4fd6d82f17824f29a82b0d7df0ae7"},{"path":"icons/apple-touch-icon.png","bytes":22816,"sha256":"d5c3e90e488de0be4dda9b2a491fb03bdce565aba08f87228734ac180651fb27"}];
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

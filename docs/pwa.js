(() => {
  'use strict';
  const element = id => document.getElementById(id);
  const dialog = element('pwa-dialog');
  const canvas = element('canvas');
  const base = new URL('./', document.baseURI);
  const workerUrl = new URL('sw.js', base).href;
  const ios = /iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const mobile = ios || /Android/i.test(navigator.userAgent);
  const supported = 'serviceWorker' in navigator && window.isSecureContext;
  let registration, installPrompt, candidate;
  let ready = false, requestedUpdate = false, checking = false;
  let lastCheck = 0;
  const watched = new WeakSet();

  const standalone = () => navigator.standalone === true || ['standalone', 'fullscreen', 'minimal-ui'].some(mode => matchMedia(`(display-mode: ${mode})`).matches);
  function feedback(message = '') {
    element('pwa-feedback').textContent = message;
    element('pwa-feedback').hidden = !message;
  }
  function status(message) { element('pwa-status').textContent = message; }
  function pendingWorker() {
    const worker = registration?.waiting || candidate;
    return worker?.state === 'installed' ? worker : undefined;
  }
  function inspectUpdate() {
    const waiting = !!pendingWorker() && !!navigator.serviceWorker.controller;
    element('pwa-update').hidden = !waiting;
    element('pwa-menu').dataset.state = waiting ? 'update' : ready ? 'ready' : 'pending';
    element('pwa-menu-label').textContent = waiting ? '有新版本' : '安装 / 离线';
    element('pwa-update-now').disabled = requestedUpdate;
  }
  function askStatus() { navigator.serviceWorker.controller?.postMessage({ type: 'PWA_STATUS' }); }
  function syncInstalled() {
    const installed = standalone();
    element('pwa-installed').hidden = !installed;
    element('pwa-install').hidden = !installPrompt || installed;
    element('pwa-continue').textContent = installed ? '继续游戏' : '暂时用浏览器玩';
  }
  function selectPlatform(platform) {
    for (const name of ['android', 'ios']) {
      element(`pwa-${name}-tab`).setAttribute('aria-pressed', String(name === platform));
      element(`pwa-${name}-guide`).hidden = name !== platform;
    }
  }
  function syncDialog() {
    document.documentElement.classList.toggle('pwa-guide-open', dialog.open);
    canvas.setAttribute('data-pwa-dialog', dialog.open ? 'open' : 'closed');
    window.dispatchEvent(new Event('boomerang-pwa-dialog'));
    if (!dialog.open && !element('loading')) canvas.focus();
  }
  function openGuide() {
    syncInstalled();
    inspectUpdate();
    if (!dialog.open) dialog.showModal();
    syncDialog();
    if (supported) askStatus();
  }
  function closeGuide() { dialog.close(); }

  element('pwa-menu').addEventListener('click', openGuide);
  element('pwa-close').addEventListener('click', closeGuide);
  element('pwa-continue').addEventListener('click', closeGuide);
  element('pwa-update-later').addEventListener('click', closeGuide);
  dialog.addEventListener('close', syncDialog);
  for (const name of ['android', 'ios']) element(`pwa-${name}-tab`).addEventListener('click', () => selectPlatform(name));
  selectPlatform(ios ? 'ios' : 'android');
  element('pwa-in-app').hidden = !/MicroMessenger|\bQQ\//i.test(navigator.userAgent);
  element('pwa-insecure').hidden = supported;
  syncInstalled();

  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    installPrompt = event;
    syncInstalled();
  });
  window.addEventListener('appinstalled', () => {
    installPrompt = undefined;
    syncInstalled();
    feedback('安装完成！请回到桌面，点击「水果乱斗」图标进入。');
  });
  element('pwa-install').addEventListener('click', async () => {
    const prompt = installPrompt;
    if (!prompt) return;
    element('pwa-install').disabled = true;
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      feedback(choice.outcome === 'accepted' ? '请完成安装，再从桌面「水果乱斗」图标进入。' : '已取消安装，可按上方教程操作，或继续用浏览器玩。');
    } catch {
      feedback('未能打开安装窗口，请按上方教程从浏览器菜单安装。');
    } finally {
      installPrompt = undefined;
      element('pwa-install').disabled = false;
      syncInstalled();
    }
  });

  function failed() {
    element('pwa-progress').hidden = true;
    status(ready ? '离线可玩' : '离线准备未完成');
    feedback(ready ? '新版下载失败，旧版离线包已保留。联网后点「检查更新」重试。' : '请保持联网并留出存储空间，再点「检查更新」重试下载。');
    inspectUpdate();
  }

  function watchRegistration(result) {
    registration = result;
    lastCheck = Date.now();
    if (!watched.has(result)) {
      watched.add(result);
      function track() {
        const worker = result.installing;
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          if (worker.state === 'redundant') failed();
          if (worker.state === 'installed') {
            candidate = worker;
            element('pwa-progress').hidden = true;
            status(ready ? '离线可玩' : '离线包已下载，正在启用…');
          }
          if (worker.state === 'activated') {
            if (candidate === worker) candidate = undefined;
            askStatus();
          }
          inspectUpdate();
          // Some browsers publish registration.waiting after this event.
          if (worker.state === 'installed') setTimeout(inspectUpdate, 0);
        });
      }
      result.addEventListener('updatefound', track);
      track();
    }
    inspectUpdate();
    askStatus();
  }
  async function registerWorker() {
    watchRegistration(await navigator.serviceWorker.register(workerUrl, { scope: base.href, updateViaCache: 'none' }));
  }
  async function reachUpdateServer() {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await fetch(workerUrl, { cache: 'no-store', signal: controller.signal });
      if (!response.ok) throw new Error('Update server unavailable');
    } finally { clearTimeout(timer); }
  }

  async function checkUpdate(manual = false) {
    if (checking || requestedUpdate || !supported) return;
    if (!navigator.onLine) {
      if (manual) feedback(ready ? '当前离线，继续使用已下载的版本；联网后可检查更新。' : '请先联网下载离线包。');
      return;
    }
    checking = true;
    lastCheck = Date.now();
    element('pwa-check').disabled = true;
    if (manual) feedback('正在检查更新…');
    try {
      // navigator.onLine is only a hint; it may remain true without a usable
      // connection. This URL is deliberately excluded from the offline cache.
      await reachUpdateServer();
      if (!registration) await registerWorker();
      if (!ready && navigator.serviceWorker.controller) navigator.serviceWorker.controller.postMessage({ type: 'PWA_REPAIR' });
      await registration.update();
      inspectUpdate();
      if (manual) feedback(pendingWorker() ? '新版本已下载完成，可以更新。' : registration.installing ? '发现新版本，正在下载；完成后会提示更新。' : '已检查更新。');
      askStatus();
    } catch {
      if (manual) feedback(ready ? '当前离线或网络不可用，继续使用已下载的版本；联网后可检查更新。' : '连接失败，请联网后重试。');
    } finally {
      checking = false;
      element('pwa-check').disabled = false;
    }
  }
  element('pwa-check').addEventListener('click', () => { void checkUpdate(true); });
  element('pwa-update-now').addEventListener('click', () => {
    const worker = pendingWorker();
    if (!worker || requestedUpdate) return;
    requestedUpdate = true;
    inspectUpdate();
    feedback('正在更新，游戏即将重新打开…');
    worker.postMessage({ type: 'SKIP_WAITING' });
  });

  if (supported) {
    navigator.serviceWorker.addEventListener('message', event => {
      if (event.source?.scriptURL !== workerUrl) return;
      const message = event.data;
      if (message?.type === 'PWA_PROGRESS') {
        const progress = element('pwa-progress');
        progress.hidden = false;
        progress.max = message.totalBytes || 1;
        progress.value = message.bytes;
        status(`${ready ? '离线可玩 · 下载新版' : '准备离线包'} ${message.complete} / ${message.total}`);
      } else if (message?.type === 'PWA_READY' && event.source === navigator.serviceWorker.controller) {
        ready = true;
        status('离线可玩');
        element('pwa-progress').hidden = true;
        inspectUpdate();
      } else if (message?.type === 'PWA_MISSING' && event.source === navigator.serviceWorker.controller) {
        ready = false;
        status('离线包不完整，请联网后点「检查更新」重新准备');
        inspectUpdate();
      } else if (message?.type === 'PWA_FAILED') failed();
    });
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (requestedUpdate) location.reload();
      else { inspectUpdate(); askStatus(); }
    });
    void navigator.serviceWorker.getRegistration(base.href).then(existing => {
      const own = existing?.scope === base.href;
      if (own) watchRegistration(existing);
      // An offline relaunch reuses its active worker immediately, without waiting
      // for an impossible network registration/update to settle.
      if (navigator.onLine || !own) return registerWorker();
    }).catch(failed);
    window.addEventListener('online', () => { void checkUpdate(); });
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && Date.now() - lastCheck > 60_000) { askStatus(); void checkUpdate(); }
    });
  } else {
    status(window.isSecureContext ? '当前浏览器不支持离线保存，请换用 Chrome / Safari' : '离线保存需要 HTTPS 网址');
    element('pwa-check').disabled = true;
  }

  if (mobile && !standalone()) openGuide();
})();

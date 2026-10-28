// MindQuest offline cache (service worker).
//
// Network first: with internet, every file comes fresh from the server (so a
// new version shows at once) and a copy is saved. Without internet, the saved
// copy is used, so the app still opens. The app's own data (check-ins, chats,
// articles) is not cached here: the app saves that itself and syncs it later
// (lib/core/offline/offline_store.dart).

const CACHE = 'mindquest-web-v1';

// Other sites whose files the app needs: Flutter's fonts (e.g. emoji).
const OTHER_HOSTS = ['fonts.gstatic.com', 'fonts.googleapis.com', 'www.gstatic.com'];

function cacheable(url) {
  const u = new URL(url);
  if (u.protocol !== 'https:' && u.hostname !== 'localhost') return false;
  return u.origin === self.location.origin || OTHER_HOSTS.includes(u.hostname);
}

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    // Remove caches from older versions of this file.
    for (const name of await caches.keys()) {
      if (name !== CACHE) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

// The page sends the files it loaded before the cache was ready.
self.addEventListener('message', function (event) {
  const data = event.data || {};
  if (data.type !== 'cache' || !Array.isArray(data.urls)) return;
  event.waitUntil((async function () {
    const cache = await caches.open(CACHE);
    for (const url of data.urls) {
      if (!cacheable(url) || await cache.match(url)) continue;
      try {
        const res = await fetch(url);
        if (res.ok) await cache.put(url, res);
      } catch (e) {
        // Try again next time.
      }
    }
  })());
});

self.addEventListener('fetch', function (event) {
  const req = event.request;
  if (req.method !== 'GET' || !cacheable(req.url)) return;
  event.respondWith((async function () {
    const cache = await caches.open(CACHE);
    try {
      const fresh = await fetch(req);
      if (fresh.ok) await cache.put(req, fresh.clone());
      return fresh;
    } catch (e) {
      const saved = await cache.match(req);
      if (saved) return saved;
      // Opening the site offline: the saved start page.
      if (req.mode === 'navigate') {
        const start = await cache.match(new URL('./', self.registration.scope).href) ||
          await cache.match(new URL('index.html', self.registration.scope).href);
        if (start) return start;
      }
      throw e;
    }
  })());
});

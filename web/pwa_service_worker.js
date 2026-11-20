'use strict';

const release = null;
const scope = new URL(self.registration.scope);
const cachePrefix = 'kingdom-foundry:' + scope.href + ':';
const cacheName = cachePrefix + (release?.id ?? 'unprepared');

self.addEventListener('install', (event) => {
  if (!release) {
    event.waitUntil(Promise.reject(new Error('Prepare the web release before installing.')));
    return;
  }
  event.waitUntil(caches.open(cacheName).then((cache) =>
    cache.addAll(release.files.map((path) => new Request(new URL(path, scope), { cache: 'reload' }))),
  ));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(cachePrefix) && name !== cacheName) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== scope.origin ||
      !url.pathname.startsWith(scope.pathname)) return;

  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    const index = new URL('index.html', scope);
    const isAppEntry = request.mode === 'navigate' &&
      (url.pathname === scope.pathname || url.pathname === index.pathname);
    const cached = await cache.match(isAppEntry ? index.href : request);
    return cached ?? fetch(request);
  })());
});

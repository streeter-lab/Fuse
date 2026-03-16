// FUSE Fitness Service Worker
const CACHE_NAME = 'fuse-v1';

const APP_SHELL = [
  '/',
  '/index.html',
  '/login.html',
  '/register.html',
  '/dashboard.html',
  '/schedule.html',
  '/book.html',
  '/admin.html',
  '/offline.html',
  '/css/style.css',
  '/css/admin.css',
  '/js/supabase.js',
  '/js/utils.js',
  '/js/auth.js',
  '/js/bookings.js',
  '/js/schedule.js',
  '/js/admin.js',
  '/manifest.json',
  '/icons/icon-192.svg',
  '/icons/icon-512.svg'
];

// Install: pre-cache app shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

// Activate: clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

// Fetch: route requests by type
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Network-only for Supabase API and CDN requests
  if (url.hostname.includes('supabase') || url.hostname.includes('cdn.jsdelivr.net')) {
    return;
  }

  // Navigation requests: network-first, fallback to cache, then offline page
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() =>
          caches.match(event.request)
            .then((cached) => cached || caches.match('/offline.html'))
        )
    );
    return;
  }

  // Static assets: cache-first, fallback to network
  event.respondWith(
    caches.match(event.request)
      .then((cached) => {
        if (cached) return cached;
        return fetch(event.request).then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        });
      })
  );
});

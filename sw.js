// Simple offline cache for the clock PWA.
const CACHE = "clock-v3";
const ASSETS = [
  "./",
  "index.html",
  "style.css",
  "app.js",
  "manifest.webmanifest",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/icon-maskable-512.png",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);

  // Daily photo: network-first so a freshly-downloaded image shows up, but cache
  // the latest copy so it still appears when offline.
  if (url.pathname.endsWith("/today.jpg") || url.pathname.endsWith("images/today.jpg")) {
    e.respondWith(
      fetch(e.request).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put("images/today.jpg", copy));
        return res;
      }).catch(() => caches.match("images/today.jpg"))
    );
    return;
  }

  // Everything else: cache-first (fully static). Navigations fall back to the
  // cached index.html so the app still opens with no server running (offline).
  e.respondWith(
    caches.match(e.request).then((hit) => {
      if (hit) return hit;
      return fetch(e.request).catch(() => {
        if (e.request.mode === "navigate") return caches.match("index.html");
        return Response.error();
      });
    })
  );
});

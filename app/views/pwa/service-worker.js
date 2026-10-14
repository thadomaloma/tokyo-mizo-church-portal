const CACHE_NAME = "tmc-pwa-shell-v3"
const OFFLINE_URL = "/offline"
const STATIC_ASSETS = [
  "/icon.png",
  "/icon-192.png",
  "/icon-512.png",
  "/apple-touch-icon.png",
  OFFLINE_URL
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS))
  )
  // Intentionally no skipWaiting() here: an updated worker should sit in
  // "waiting" so the app can offer the user a Refresh Now control instead of
  // silently swapping code out from under an open session. See the message
  // listener below.
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  )
  self.clients.claim()
})

self.addEventListener("message", (event) => {
  if (event.data === "SKIP_WAITING") self.skipWaiting()
})

// Only the static app-shell assets above are ever cache-served; everything
// else (finance, members, auth) stays network-only
// so authenticated data is never served stale after logout or role changes.
// The one exception is full-page navigation: if the network is unreachable,
// fall back to the generic branded offline page rather than a browser error.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return

  const url = new URL(event.request.url)
  const isCachedAsset = url.origin === self.location.origin && STATIC_ASSETS.includes(url.pathname)

  if (isCachedAsset) {
    event.respondWith(
      caches.match(event.request).then((cached) => cached || fetch(event.request))
    )
    return
  }

  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(OFFLINE_URL))
    )
  }
})

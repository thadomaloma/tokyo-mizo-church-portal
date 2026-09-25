const CACHE_NAME = "tmc-pwa-shell-v2"
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
// else (finance, notifications, members, minutes, auth) stays network-only
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

// Web Push: payload shape is produced by PushNotificationService and is kept
// intentionally minimal (title, body, url, icon) — never sensitive finance,
// member, or minutes content.
self.addEventListener("push", (event) => {
  if (!event.data) return

  let payload
  try {
    payload = event.data.json()
  } catch (error) {
    return
  }

  const title = payload.title || "TMC Portal"
  const options = {
    body: payload.body || "",
    icon: payload.icon || "/icon-192.png",
    badge: "/icon-192.png",
    data: { url: payload.url || "/" }
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const targetUrl = new URL(event.notification.data?.url || "/", self.location.origin).href

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      const exactMatch = clientList.find((client) => client.url === targetUrl)
      if (exactMatch) return exactMatch.focus()

      const anyClient = clientList[0]
      if (anyClient) {
        return anyClient.focus().then(() => {
          if ("navigate" in anyClient) return anyClient.navigate(targetUrl)
        })
      }

      if (self.clients.openWindow) return self.clients.openWindow(targetUrl)
    })
  )
})

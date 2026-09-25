import { Controller } from "@hotwired/stimulus"

const PANELS = ["unsupportedPanel", "iosInstallPanel", "deniedPanel", "disabledPanel", "enabledPanel"]

export default class extends Controller {
  static targets = PANELS
  static values = { publicKey: String, createUrl: String, destroyUrl: String }

  async connect() {
    if (!this.publicKeyValue || !this.isSupported()) {
      this.show(this.isIOS() && !this.isStandalone() ? "iosInstallPanel" : "unsupportedPanel")
      return
    }

    if (Notification.permission === "denied") {
      this.show("deniedPanel")
      return
    }

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()

    this.show(subscription ? "enabledPanel" : "disabledPanel")
  }

  async enable() {
    try {
      const registration = await navigator.serviceWorker.ready
      const permission = await Notification.requestPermission()

      if (permission !== "granted") {
        this.show(permission === "denied" ? "deniedPanel" : "disabledPanel")
        return
      }

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.publicKeyValue)
      })

      await this.postSubscription(subscription)
      this.show("enabledPanel")
    } catch (error) {
      this.show("disabledPanel")
    }
  }

  async disable() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        await this.deleteSubscription(subscription.endpoint)
        await subscription.unsubscribe()
      }
    } catch (error) {
      // Fall through to reflect "disabled" locally either way — a stale
      // server-side row without a live browser subscription is harmless.
    } finally {
      this.show("disabledPanel")
    }
  }

  async postSubscription(subscription) {
    const json = subscription.toJSON()

    await fetch(this.createUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken() },
      body: JSON.stringify({
        subscription: {
          endpoint: json.endpoint,
          p256dh: json.keys.p256dh,
          auth_key: json.keys.auth
        }
      })
    })
  }

  async deleteSubscription(endpoint) {
    await fetch(this.destroyUrlValue, {
      method: "DELETE",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken() },
      body: JSON.stringify({ endpoint })
    })
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  show(stateName) {
    PANELS.forEach((name) => {
      this[`${name}Target`].classList.toggle("hidden", name !== stateName)
    })
  }

  isSupported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  isStandalone() {
    return window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
  }

  isIOS() {
    const userAgent = window.navigator.userAgent || ""
    const platform = window.navigator.platform || ""
    const isAppleTouchDevice = /iPad|iPhone|iPod/.test(userAgent)
    const isIpadOSDesktopMode = platform === "MacIntel" && navigator.maxTouchPoints > 1

    return isAppleTouchDevice || isIpadOSDesktopMode
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)

    return Uint8Array.from(rawData, (char) => char.charCodeAt(0))
  }
}

import { Controller } from "@hotwired/stimulus"

const DISMISSED_KEY = "tmc-pwa-install-dismissed"
const DISMISSED_DURATION_MS = 7 * 24 * 60 * 60 * 1000

export default class extends Controller {
  static targets = ["androidPanel", "iosPanel"]

  connect() {
    this.deferredPrompt = null
    this.handleBeforeInstallPrompt = this.handleBeforeInstallPrompt.bind(this)
    this.handleAppInstalled = this.handleAppInstalled.bind(this)

    window.addEventListener("beforeinstallprompt", this.handleBeforeInstallPrompt)
    window.addEventListener("appinstalled", this.handleAppInstalled)

    if (this.isStandalone()) {
      this.hide()
      return
    }

    if (this.isIOS() && !this.isDismissed()) {
      this.showIOS()
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.handleBeforeInstallPrompt)
    window.removeEventListener("appinstalled", this.handleAppInstalled)
  }

  handleBeforeInstallPrompt(event) {
    event.preventDefault()
    this.deferredPrompt = event

    if (!this.isDismissed()) this.showAndroid()
  }

  handleAppInstalled() {
    this.deferredPrompt = null
    this.hide()
  }

  async install() {
    if (!this.deferredPrompt) return

    const promptEvent = this.deferredPrompt
    this.deferredPrompt = null

    promptEvent.prompt()
    // The prompt can only be used once, whether accepted or dismissed, so the
    // card is hidden either way; appinstalled fires separately on success.
    await promptEvent.userChoice
    this.hide()
  }

  dismiss() {
    localStorage.setItem(DISMISSED_KEY, String(Date.now()))
    this.hide()
  }

  showAndroid() {
    this.element.classList.remove("hidden")
    this.androidPanelTarget.classList.remove("hidden")
    this.iosPanelTarget.classList.add("hidden")
  }

  showIOS() {
    this.element.classList.remove("hidden")
    this.iosPanelTarget.classList.remove("hidden")
    this.androidPanelTarget.classList.add("hidden")
  }

  hide() {
    this.element.classList.add("hidden")
  }

  isDismissed() {
    const dismissedAt = Number(localStorage.getItem(DISMISSED_KEY))

    if (!dismissedAt) return false

    return Date.now() - dismissedAt < DISMISSED_DURATION_MS
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
}

import { Controller } from "@hotwired/stimulus"

const ONLINE_BANNER_DURATION_MS = 3000

export default class extends Controller {
  static targets = ["offlineBanner", "onlineBanner"]

  connect() {
    this.handleOffline = this.handleOffline.bind(this)
    this.handleOnline = this.handleOnline.bind(this)

    window.addEventListener("offline", this.handleOffline)
    window.addEventListener("online", this.handleOnline)

    if (!navigator.onLine) this.handleOffline()
  }

  disconnect() {
    window.removeEventListener("offline", this.handleOffline)
    window.removeEventListener("online", this.handleOnline)
    clearTimeout(this.onlineTimeout)
  }

  handleOffline() {
    clearTimeout(this.onlineTimeout)
    this.onlineBannerTarget.classList.add("hidden")
    this.offlineBannerTarget.classList.remove("hidden")
  }

  handleOnline() {
    this.offlineBannerTarget.classList.add("hidden")
    this.onlineBannerTarget.classList.remove("hidden")

    this.onlineTimeout = setTimeout(() => {
      this.onlineBannerTarget.classList.add("hidden")
    }, ONLINE_BANNER_DURATION_MS)
  }
}

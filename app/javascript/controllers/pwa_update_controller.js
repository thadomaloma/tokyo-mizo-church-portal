import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!("serviceWorker" in navigator)) return

    this.refreshing = false
    this.handleControllerChange = this.handleControllerChange.bind(this)
    navigator.serviceWorker.addEventListener("controllerchange", this.handleControllerChange)

    navigator.serviceWorker.ready
      .then((registration) => this.watch(registration))
      .catch(() => {})
  }

  disconnect() {
    if (!("serviceWorker" in navigator)) return

    navigator.serviceWorker.removeEventListener("controllerchange", this.handleControllerChange)
  }

  watch(registration) {
    this.registration = registration

    // An update already installed and waiting from a previous visit.
    if (registration.waiting && navigator.serviceWorker.controller) this.show()

    registration.addEventListener("updatefound", () => {
      const newWorker = registration.installing
      if (!newWorker) return

      newWorker.addEventListener("statechange", () => {
        if (newWorker.state === "installed" && navigator.serviceWorker.controller) this.show()
      })
    })
  }

  refresh() {
    if (!this.registration?.waiting) {
      window.location.reload()
      return
    }

    this.registration.waiting.postMessage("SKIP_WAITING")
  }

  dismiss() {
    this.hide()
  }

  handleControllerChange() {
    if (this.refreshing) return

    this.refreshing = true
    window.location.reload()
  }

  show() {
    this.element.classList.remove("hidden")
  }

  hide() {
    this.element.classList.add("hidden")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this.boundDismiss = this.dismiss.bind(this)
    this.boundKeydown = this.keydown.bind(this)

    document.addEventListener("click", this.boundDismiss)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundDismiss)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    document.dispatchEvent(new CustomEvent("dropdown:open", { detail: this.element }))
    const willShow = this.menuTarget.classList.contains("hidden")
    this.menuTarget.classList.toggle("hidden")
    this.setExpanded(willShow)

    if (willShow) this.focusFirstItem()
  }

  hide() {
    const wasOpen = !this.menuTarget.classList.contains("hidden")
    this.menuTarget.classList.add("hidden")
    this.setExpanded(false)

    if (wasOpen && this.hasTriggerTarget && this.menuTarget.contains(document.activeElement)) {
      this.triggerTarget.focus()
    }
  }

  focusFirstItem() {
    const focusable = this.menuTarget.querySelector("a[href], button:not([disabled])")
    if (focusable) focusable.focus()
  }

  dismiss(event) {
    if (event.type === "dropdown:open") {
      if (event.detail !== this.element) this.hide()
      return
    }

    if (!this.element.contains(event.target)) this.hide()
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
  }

  setExpanded(expanded) {
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", String(expanded))
  }
}

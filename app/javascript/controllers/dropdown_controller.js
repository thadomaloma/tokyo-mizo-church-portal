import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

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
    this.menuTarget.classList.toggle("hidden")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
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
}

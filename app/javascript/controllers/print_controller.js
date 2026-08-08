import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  print() {
    window.requestAnimationFrame(() => window.print())
  }
}

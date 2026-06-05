import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "input"]

  connect() {
    this.sync()
  }

  command(event) {
    event.preventDefault()
    this.editorTarget.focus()
    document.execCommand(event.currentTarget.dataset.command, false, null)
    this.sync()
  }

  paste(event) {
    event.preventDefault()
    const text = event.clipboardData.getData("text/plain")
    document.execCommand("insertText", false, text)
    this.sync()
  }

  sync() {
    if (this.editorTarget.innerText.trim() === "") {
      this.inputTarget.value = ""
      return
    }

    this.inputTarget.value = this.editorTarget.innerHTML.trim()
  }
}

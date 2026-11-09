import { Controller } from "@hotwired/stimulus"

// Counts a figure up from zero when it first scrolls into view. Wraps the
// markup from the `money` helper (or any "42%"-style text): only the digits
// change, so signs, the ¥ and the % stay put, and the real figure is always
// what the server rendered.
// Skipped entirely for people who prefer reduced motion.
//
// <span data-controller="count-up"><%= money(amount) %></span>
const DURATION = 1100
const easeOutExpo = (t) => (t === 1 ? 1 : 1 - Math.pow(2, -10 * t))

export default class extends Controller {
  connect() {
    this.node = this.digitsNode()
    if (!this.node) return

    this.finalText = this.node.textContent
    this.digits = this.finalText.match(/\d[\d,]*/)[0]
    this.amount = parseInt(this.digits.replace(/,/g, ""), 10)
    if (!this.amount || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.finish = this.finish.bind(this)
    document.addEventListener("turbo:before-cache", this.finish)
    this.render(0)
    this.observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return
      this.observer.disconnect()
      this.start()
    }, { threshold: 0.4 })
    this.observer.observe(this.element)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.finish)
    this.finish()
  }

  // Put the real figure back, so Turbo's page cache never keeps a
  // half-counted number.
  finish() {
    this.observer?.disconnect()
    cancelAnimationFrame(this.frame)
    if (this.node && this.finalText) this.node.textContent = this.finalText
  }

  start() {
    const startedAt = performance.now()
    const step = (now) => {
      const progress = Math.min((now - startedAt) / DURATION, 1)
      this.render(Math.round(this.amount * easeOutExpo(progress)))
      if (progress < 1) this.frame = requestAnimationFrame(step)
    }
    this.frame = requestAnimationFrame(step)
  }

  render(value) {
    this.node.textContent = this.finalText.replace(this.digits, value.toLocaleString("en-US"))
  }

  // The last text node holding digits: the amount after the ¥ sign.
  digitsNode() {
    const walker = document.createTreeWalker(this.element, NodeFilter.SHOW_TEXT)
    let found = null
    while (walker.nextNode()) {
      if (/\d/.test(walker.currentNode.textContent)) found = walker.currentNode
    }
    return found
  }
}

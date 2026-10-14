import { Controller } from "@hotwired/stimulus"

// Live total for the Sunday offering form, so counters can compare it with
// the cash they have just counted before saving.
export default class extends Controller {
  static targets = ["amount", "total"]

  connect() {
    this.update()
  }

  update() {
    const total = this.amountTargets.reduce((sum, input) => {
      const value = parseInt(input.value.replace(/,/g, ""), 10)
      return sum + (Number.isFinite(value) && value > 0 ? value : 0)
    }, 0)

    this.totalTarget.textContent = `¥${total.toLocaleString("en-US")}`
  }
}

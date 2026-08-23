import { Controller } from "@hotwired/stimulus"

const STAGGER_MS = 400

export default class extends Controller {
  static targets = ["row", "total", "button"]

  connect() {
    this.ready = false
    this.reveal()
  }

  reveal() {
    this.rowTargets.forEach((row, index) => {
      setTimeout(() => row.classList.add("wizard-xp-summary__row--visible"), index * STAGGER_MS)
    })

    const totalDelay = this.rowTargets.length * STAGGER_MS + 200

    setTimeout(() => {
      this.totalTarget.classList.add("wizard-xp-summary__total--visible")
      this.ready = true
      this.buttonTarget.classList.remove("wizard-button--disabled")
    }, totalDelay)
  }

  handleClick(event) {
    if (!this.ready) {
      event.preventDefault()
    }
  }
}

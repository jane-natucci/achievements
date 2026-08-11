import { Controller } from "@hotwired/stimulus"

const HOVER_DELAY_MS = 5000
const HIDE_GRACE_MS = 300

export default class extends Controller {
  static targets = ["popup"]

  show() {
    clearTimeout(this.hideTimeout)
    clearTimeout(this.showTimeout)
    this.showTimeout = setTimeout(() => {
      this.popupTarget.classList.add("build-popup--visible")
    }, HOVER_DELAY_MS)
  }

  hide() {
    clearTimeout(this.showTimeout)
    clearTimeout(this.hideTimeout)
    this.hideTimeout = setTimeout(() => {
      this.popupTarget.classList.remove("build-popup--visible")
    }, HIDE_GRACE_MS)
  }
}

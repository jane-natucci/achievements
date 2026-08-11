import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup"]

  show() {
    clearTimeout(this.hideTimeout)
    this.popupTarget.classList.add("build-popup--visible")
  }

  hide() {
    clearTimeout(this.hideTimeout)
    this.hideTimeout = setTimeout(() => {
      this.popupTarget.classList.remove("build-popup--visible")
    }, 300)
  }
}

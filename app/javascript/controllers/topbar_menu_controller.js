import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "toggle"]

  toggle() {
    const isOpen = this.navTarget.classList.toggle("topbar__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", isOpen ? "true" : "false")
  }
}

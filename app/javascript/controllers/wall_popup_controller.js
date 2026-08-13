import { Controller } from "@hotwired/stimulus"

const SHOW_DELAY_MS = 120
const HIDE_GRACE_MS = 500

export default class extends Controller {
  static targets = ["popup"]

  show() {
    clearTimeout(this.hideTimeout)
    clearTimeout(this.showTimeout)
    this.showTimeout = setTimeout(() => {
      this.reveal()
    }, SHOW_DELAY_MS)
  }

  hide() {
    clearTimeout(this.showTimeout)
    clearTimeout(this.hideTimeout)
    this.hideTimeout = setTimeout(() => {
      this.popupTarget.classList.remove("wall-popup--visible")
      this.popupTarget.style.removeProperty("--wall-popup-shift")
    }, HIDE_GRACE_MS)
  }

  // Popups are centered on their tile by default (see .wall-popup CSS), which
  // clips off-screen for tiles near the left/right edge of a dense grid --
  // nudge back into view with a CSS variable rather than fighting the
  // centering transform directly.
  reveal() {
    this.popupTarget.classList.add("wall-popup--visible")
    this.popupTarget.style.removeProperty("--wall-popup-shift")

    const rect = this.popupTarget.getBoundingClientRect()
    const margin = 8
    let shift = 0
    if (rect.left < margin) {
      shift = margin - rect.left
    } else if (rect.right > window.innerWidth - margin) {
      shift = window.innerWidth - margin - rect.right
    }

    if (shift !== 0) {
      this.popupTarget.style.setProperty("--wall-popup-shift", `${shift}px`)
    }
  }
}

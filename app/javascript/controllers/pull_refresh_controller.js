import { Controller } from "@hotwired/stimulus"

const PULL_THRESHOLD = 70
const MAX_PULL = 120
const DAMPING = 0.5

export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.startY = null
    this.currentPull = 0
    this.pulling = false
    this.refreshing = false

    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchMove = this.onTouchMove.bind(this)
    this.onTouchEnd = this.onTouchEnd.bind(this)

    document.addEventListener("touchstart", this.onTouchStart, { passive: true })
    document.addEventListener("touchmove", this.onTouchMove, { passive: false })
    document.addEventListener("touchend", this.onTouchEnd, { passive: true })
  }

  disconnect() {
    document.removeEventListener("touchstart", this.onTouchStart)
    document.removeEventListener("touchmove", this.onTouchMove)
    document.removeEventListener("touchend", this.onTouchEnd)
  }

  onTouchStart(event) {
    if (this.refreshing || window.scrollY > 0) return

    this.startY = event.touches[0].clientY
    this.pulling = true
  }

  onTouchMove(event) {
    if (!this.pulling || this.refreshing) return

    const deltaY = event.touches[0].clientY - this.startY
    if (deltaY <= 0 || window.scrollY > 0) {
      this.reset()
      return
    }

    event.preventDefault()

    this.currentPull = Math.min(deltaY * DAMPING, MAX_PULL)
    this.indicatorTarget.style.opacity = Math.min(this.currentPull / PULL_THRESHOLD, 1)
    this.indicatorTarget.style.transform =
      `translateX(-50%) translateY(${this.currentPull - 40}px) rotate(${this.currentPull * 3}deg)`
  }

  onTouchEnd() {
    if (!this.pulling || this.refreshing) return

    this.pulling = false

    if (this.currentPull >= PULL_THRESHOLD) {
      this.refresh()
    } else {
      this.reset()
    }
  }

  refresh() {
    this.refreshing = true
    this.indicatorTarget.classList.add("pull-refresh-indicator--spinning")
    this.indicatorTarget.style.opacity = 1
    this.indicatorTarget.style.transform = "translateX(-50%) translateY(30px) rotate(0deg)"

    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }

  reset() {
    this.pulling = false
    this.currentPull = 0
    this.indicatorTarget.style.opacity = 0
    this.indicatorTarget.style.transform = "translateX(-50%) translateY(-40px) rotate(0deg)"
  }
}

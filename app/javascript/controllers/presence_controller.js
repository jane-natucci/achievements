import { Controller } from "@hotwired/stimulus"

const HEARTBEAT_INTERVAL_MS = 60000

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.ping()
    this.timer = setInterval(() => this.ping(), HEARTBEAT_INTERVAL_MS)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  ping() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token },
    }).catch(() => {})
  }
}

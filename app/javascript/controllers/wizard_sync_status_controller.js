import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "message"]
  static values = { url: String }

  connect() {
    this.ready = false
    this.poll()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  poll() {
    fetch(this.urlValue, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        if (data.done) {
          this.markReady()
        } else {
          this.timeout = setTimeout(() => this.poll(), 1500)
        }
      })
      .catch(() => {
        this.timeout = setTimeout(() => this.poll(), 3000)
      })
  }

  markReady() {
    this.ready = true
    this.buttonTarget.classList.remove("wizard-button--disabled")

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = "All set!"
    }
  }

  handleClick(event) {
    if (!this.ready) {
      event.preventDefault()
    }
  }
}

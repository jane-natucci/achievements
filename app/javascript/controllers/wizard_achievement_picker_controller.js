import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "hiddenInput", "submit", "description"]

  select(event) {
    const card = event.currentTarget
    const achievementId = card.dataset.achievementId

    this.cardTargets.forEach((target) => {
      target.classList.toggle("wizard-achievement-card--selected", target === card)
    })

    this.hiddenInputTarget.value = achievementId
    this.submitTarget.disabled = false

    if (this.hasDescriptionTarget) {
      this.descriptionTarget.textContent = card.dataset.description || "No description available."
    }
  }
}

import { Controller } from "@hotwired/stimulus"

const AI_MOVE_DELAY_MS = 2500

export default class extends Controller {
  static targets = ["board", "status", "stancePicker", "readyButton", "hint", "log"]
  static values = { turnUrl: String, active: Boolean }

  connect() {
    this.resetSelection()
  }

  resetSelection() {
    this.selectedCardId = null
    this.selectedSlot = null
    this.selectedTargetType = null
    this.selectedTargetId = null
    this.stance = "neutral"

    if (this.hasReadyButtonTarget) {
      this.readyButtonTarget.disabled = true
      this.readyButtonTarget.textContent = "Ready"
    }

    this.updateHint()
  }

  selectCard(event) {
    if (!this.canAct()) return

    const el = event.currentTarget
    if (el.dataset.zone === "dead") return

    if (el.dataset.side === "player") {
      if (el.dataset.zone !== "hand" && el.dataset.zone !== "board") return

      this.clearCardHighlight()
      this.selectedCardId = el.dataset.battleCardId
      this.selectedSlot = el.dataset.zone === "board" ? el.closest(".battle-slot")?.dataset.slot : null
      el.classList.add("battle-card--selected")
    } else {
      if (!this.selectedCardId) return

      this.clearTargetHighlight()
      this.selectedTargetType = "card"
      this.selectedTargetId = el.dataset.battleCardId
      el.classList.add("battle-card--targeted")
    }

    this.updateHint()
    this.maybeEnableReady()
  }

  selectSlot(event) {
    if (!this.canAct() || !this.selectedCardId) return

    const slotEl = event.currentTarget
    if (slotEl.querySelector(".battle-card")) return // occupied

    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${this.selectedCardId}"]`)
    if (!cardEl || cardEl.dataset.zone !== "hand") return

    this.boardTarget.querySelectorAll(".battle-slot--selected").forEach((el) => el.classList.remove("battle-slot--selected"))
    slotEl.classList.add("battle-slot--selected")
    this.selectedSlot = slotEl.dataset.slot

    this.updateHint()
    this.maybeEnableReady()
  }

  selectPlayerTarget() {
    if (!this.canAct() || !this.selectedCardId) return

    this.clearTargetHighlight()
    this.selectedTargetType = "player"
    this.selectedTargetId = null
    this.element.querySelector(".battle-target-player-button")?.classList.add("battle-target-player-button--selected")

    this.updateHint()
    this.maybeEnableReady()
  }

  chooseStance(event) {
    if (!this.canAct()) return

    this.stance = event.currentTarget.dataset.stance
    this.stancePickerTarget.querySelectorAll(".battle-stance-button").forEach((button) => {
      button.classList.toggle("battle-stance-button--active", button === event.currentTarget)
    })
  }

  submitTurn() {
    if (!this.readyButtonTarget || this.readyButtonTarget.disabled) return

    this.readyButtonTarget.disabled = true
    this.readyButtonTarget.textContent = "Resolving..."

    const body = new URLSearchParams({
      acting_card_id: this.selectedCardId,
      stance: this.stance,
      target_type: this.selectedTargetType
    })
    if (this.selectedSlot) body.set("slot", this.selectedSlot)
    if (this.selectedTargetId) body.set("target_battle_card_id", this.selectedTargetId)

    fetch(this.turnUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        Accept: "application/json"
      },
      body
    })
      .then((response) => response.json())
      .then((data) => this.handleTurnResponse(data))
      .catch(() => {
        this.hintTarget.textContent = "Something went wrong submitting that turn. Try again."
        this.readyButtonTarget.disabled = false
        this.readyButtonTarget.textContent = "Ready"
      })
  }

  handleTurnResponse(data) {
    if (data.error) {
      this.hintTarget.textContent = data.error
      this.readyButtonTarget.disabled = false
      this.readyButtonTarget.textContent = "Ready"
      return
    }

    this.boardTarget.innerHTML = data.mid_html
    if (data.mid_move_html) this.logTarget.insertAdjacentHTML("beforeend", data.mid_move_html)
    this.resetSelection()

    if (data.final_html) {
      this.statusTarget.textContent = "Opponent's turn..."
      setTimeout(() => {
        this.boardTarget.innerHTML = data.final_html
        if (data.final_move_html) this.logTarget.insertAdjacentHTML("beforeend", data.final_move_html)
        this.finishTurn(data)
      }, AI_MOVE_DELAY_MS)
    } else {
      this.finishTurn(data)
    }
  }

  finishTurn(data) {
    if (data.battle_over) {
      this.statusTarget.textContent = data.battle_over === "won" ? "You won!" : "You lost."
      this.activeValue = false
      const controls = this.element.querySelector(".battle-controls")
      if (controls) controls.remove()
    } else {
      this.statusTarget.textContent = "Your turn"
    }
  }

  canAct() {
    return this.activeValue
  }

  maybeEnableReady() {
    const cardChosen = !!this.selectedCardId
    const placementDone = !this.needsPlacement() || !!this.selectedSlot
    const targetChosen = !!this.selectedTargetType

    this.readyButtonTarget.disabled = !(cardChosen && placementDone && targetChosen)
  }

  needsPlacement() {
    if (!this.selectedCardId) return false
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${this.selectedCardId}"]`)
    return cardEl && cardEl.dataset.zone === "hand" && !this.selectedSlot
  }

  updateHint() {
    if (!this.hasHintTarget) return

    if (!this.selectedCardId) {
      this.hintTarget.textContent = "Select a card to attack with."
    } else if (this.needsPlacement()) {
      this.hintTarget.textContent = "Choose a slot to place it in."
    } else if (!this.selectedTargetType) {
      this.hintTarget.textContent = "Choose a target -- an enemy card, or attack the opponent directly."
    } else {
      this.hintTarget.textContent = "Ready when you are."
    }
  }

  clearCardHighlight() {
    this.boardTarget.querySelectorAll(".battle-card--selected").forEach((el) => el.classList.remove("battle-card--selected"))
  }

  clearTargetHighlight() {
    this.boardTarget.querySelectorAll(".battle-card--targeted").forEach((el) => el.classList.remove("battle-card--targeted"))
    this.element.querySelector(".battle-target-player-button--selected")?.classList.remove("battle-target-player-button--selected")
  }

  highlightCard(event) {
    const id = event.currentTarget.dataset.battleCardId
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${id}"]`)
    cardEl?.classList.add("battle-card--log-highlight")
  }

  unhighlightCard(event) {
    const id = event.currentTarget.dataset.battleCardId
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${id}"]`)
    cardEl?.classList.remove("battle-card--log-highlight")
  }
}

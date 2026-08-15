import { Controller } from "@hotwired/stimulus"

const AI_MOVE_DELAY_MS = 2500

export default class extends Controller {
  static targets = ["board", "status", "readyButton", "hint", "log"]
  static values = { placeUrl: String, attackUrl: String, endTurnUrl: String, active: Boolean }

  connect() {
    this.requestInFlight = false
    this.resetSelection()
  }

  resetSelection() {
    this.selectedCardId = null
    this.clearAttackerHighlight()
    this.updateHint()
  }

  // A hand card has no attack decision to make -- placing it *is* its
  // whole action for the turn (it can't also attack until next turn) --
  // so this resolves immediately on click, no target needed.
  placeCard(event) {
    if (!this.canAct() || this.requestInFlight) return

    const el = event.currentTarget
    if (el.dataset.acted === "true") return

    el.classList.add("battle-card--attacking")

    const body = new URLSearchParams({ card_id: el.dataset.battleCardId })
    this.requestInFlight = true

    fetch(this.placeUrlValue, { method: "POST", headers: this.jsonHeaders(), body })
      .then((response) => response.json())
      .then((data) => this.handlePlaceResponse(data))
      .catch(() => this.handleRequestError())
      .finally(() => {
        this.requestInFlight = false
      })
  }

  handlePlaceResponse(data) {
    if (data.error) {
      this.hintTarget.textContent = data.error
      return
    }

    this.applyBoardHtml(data.board_html)
    this.resetSelection()

    if (data.battle_over) this.endBattle(data.battle_over, data.result_log_html)
  }

  // Step 1 of "select card, select target": arms one of the player's own
  // board cards as the attacker. Nothing is submitted yet.
  selectAttacker(event) {
    if (!this.canAct() || this.requestInFlight) return

    const el = event.currentTarget
    if (el.dataset.zone === "dead" || el.dataset.acted === "true") return

    this.clearAttackerHighlight()
    this.selectedCardId = el.dataset.battleCardId
    el.classList.add("battle-card--selected")
    this.updateHint()
  }

  // Step 2: an enemy card, or the opponent avatar itself. Resolves the
  // attack immediately -- no staging, no separate submit step.
  selectTarget(event) {
    if (!this.canAct() || !this.selectedCardId || this.requestInFlight) return

    const el = event.currentTarget
    if (el.dataset.zone === "dead") return

    const targetType = el.dataset.targetType
    const targetBattleCardId = targetType === "card" ? el.dataset.battleCardId : null

    el.classList.add(targetType === "player" ? "battle-avatar-card--attacking" : "battle-card--attacking")

    this.performAttack(targetType, targetBattleCardId)
  }

  performAttack(targetType, targetBattleCardId) {
    const body = new URLSearchParams({ acting_card_id: this.selectedCardId, target_type: targetType })
    if (targetBattleCardId) body.set("target_battle_card_id", targetBattleCardId)

    this.requestInFlight = true

    fetch(this.attackUrlValue, { method: "POST", headers: this.jsonHeaders(), body })
      .then((response) => response.json())
      .then((data) => this.handleAttackResponse(data))
      .catch(() => this.handleRequestError())
      .finally(() => {
        this.requestInFlight = false
      })
  }

  handleAttackResponse(data) {
    if (data.error) {
      this.hintTarget.textContent = data.error
      return
    }

    this.applyBoardHtml(data.board_html)
    if (data.move_html) this.logTarget.insertAdjacentHTML("beforeend", data.move_html)
    this.resetSelection()

    if (data.battle_over) this.endBattle(data.battle_over, data.result_log_html)
  }

  // "Ready": ends the player's turn regardless of how many cards they used,
  // then reveals the opponent's whole reply turn a step at a time.
  endTurn() {
    if (!this.hasReadyButtonTarget || this.readyButtonTarget.disabled || this.requestInFlight) return

    this.requestInFlight = true
    this.readyButtonTarget.disabled = true
    this.readyButtonTarget.textContent = "Resolving..."
    this.hintTarget.textContent = ""

    fetch(this.endTurnUrlValue, { method: "POST", headers: this.jsonHeaders() })
      .then((response) => response.json())
      .then((data) => this.handleEndTurnResponse(data))
      .catch(() => this.handleRequestError())
      .finally(() => {
        this.requestInFlight = false
      })
  }

  handleEndTurnResponse(data) {
    if (data.error) {
      this.hintTarget.textContent = data.error
      this.readyButtonTarget.disabled = false
      this.readyButtonTarget.textContent = "Ready"
      return
    }

    this.statusTarget.textContent = "Opponent's turn..."
    this.revealSteps(data.steps, 0, data)
  }

  revealSteps(steps, index, data) {
    if (index >= steps.length) {
      this.applyBoardHtml(data.final_html)
      this.finishEndTurn(data)
      return
    }

    setTimeout(() => {
      const step = steps[index]
      this.applyBoardHtml(step.board_html)
      if (step.move_html) this.logTarget.insertAdjacentHTML("beforeend", step.move_html)
      this.revealSteps(steps, index + 1, data)
    }, AI_MOVE_DELAY_MS)
  }

  finishEndTurn(data) {
    this.readyButtonTarget.disabled = false
    this.readyButtonTarget.textContent = "Ready"
    this.resetSelection()

    if (data.battle_over) {
      this.endBattle(data.battle_over, data.result_log_html)
    } else {
      this.statusTarget.textContent = "Your turn"
    }
  }

  endBattle(status, resultLogHtml) {
    this.statusTarget.textContent = status === "won" ? "You won!" : "You lost."
    if (resultLogHtml) this.logTarget.insertAdjacentHTML("beforeend", resultLogHtml)
    this.activeValue = false
    this.element.querySelector(".battle-controls")?.remove()
  }

  handleRequestError() {
    this.hintTarget.textContent = "Something went wrong. Try again."
    if (this.hasReadyButtonTarget) {
      this.readyButtonTarget.disabled = false
      this.readyButtonTarget.textContent = "Ready"
    }
  }

  canAct() {
    return this.activeValue
  }

  jsonHeaders() {
    return {
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      Accept: "application/json"
    }
  }

  // Swaps in new board HTML and flashes red-then-fading on any HP that
  // changed (dealt or received, card or avatar) -- shared by attack
  // responses, each AI-turn step, and the final post-turn snapshot, so the
  // effect is consistent no matter which side did the damage.
  applyBoardHtml(html) {
    const before = this.captureHpSnapshot()
    this.boardTarget.innerHTML = html
    this.flashChangedHp(before)
  }

  captureHpSnapshot() {
    const snapshot = {}
    this.boardTarget.querySelectorAll("[data-hp-node]").forEach((node) => {
      const key = this.hpKeyFor(node)
      if (key) snapshot[key] = node.textContent
    })
    return snapshot
  }

  flashChangedHp(before) {
    this.boardTarget.querySelectorAll("[data-hp-node]").forEach((node) => {
      const key = this.hpKeyFor(node)
      if (!key || before[key] === undefined || before[key] === node.textContent) return

      this.flashNode(node, "battle-hp-flash")
      const fill = node.closest(".battle-hp")?.querySelector(".battle-hp__fill")
      if (fill) this.flashNode(fill, "battle-hp-bar-flash")
    })
  }

  flashNode(node, className) {
    node.classList.add(className)
    node.addEventListener("animationend", () => node.classList.remove(className), { once: true })
  }

  hpKeyFor(node) {
    return node.closest("[data-battle-card-id]")?.dataset.battleCardId
      ?? node.closest("[data-hp-avatar]")?.dataset.hpAvatar
  }

  clearAttackerHighlight() {
    this.boardTarget.querySelectorAll(".battle-card--selected").forEach((el) => el.classList.remove("battle-card--selected"))
  }

  updateHint() {
    if (!this.hasHintTarget) return

    this.hintTarget.textContent = this.selectedCardId
      ? "Choose a target -- an enemy card, or the opponent."
      : "Click a hand card to place it, or select a board card then a target to attack."
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

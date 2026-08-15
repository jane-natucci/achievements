import { Controller } from "@hotwired/stimulus"

const AI_MOVE_DELAY_MS = 2500
// How long a dying card sits at 0 hp, flashed red, before it's actually
// removed from the board -- matches the .battle-hp-flash CSS duration so
// the card disappears right as the flash finishes, not mid-animation.
const DEATH_FLASH_DELAY_MS = 1400

export default class extends Controller {
  static targets = ["board", "status", "readyButton", "hint", "log", "timer"]
  static values = {
    placeUrl: String,
    attackUrl: String,
    endTurnUrl: String,
    active: Boolean,
    turnStartedAt: Number,
    turnSeconds: Number
  }

  connect() {
    this.requestInFlight = false
    this.resetSelection()
    this.updateReadyGlow()
    this.turnDeadline = this.turnStartedAtValue ? (this.turnStartedAtValue * 1000) + (this.turnSecondsValue * 1000) : null
    this.timerIntervalId = setInterval(() => this.tickTimer(), 1000)
    this.tickTimer()
  }

  disconnect() {
    if (this.timerIntervalId) clearInterval(this.timerIntervalId)
  }

  resetSelection() {
    this.selectedCardId = null
    this.selectedCardRole = null
    this.clearAttackerHighlight()
    this.markEmptySlotsPlaceable(false)
    this.updateHint()
  }

  // Step 1 of placing: arms a hand card. Nothing is submitted yet --
  // placing still needs a slot (step 2, see selectPlacementSlot).
  placeCard(event) {
    if (!this.canAct() || this.requestInFlight) return

    const el = event.currentTarget
    if (el.dataset.acted === "true") return

    this.clearAttackerHighlight()
    this.selectedCardId = el.dataset.battleCardId
    this.selectedCardRole = "place"
    el.classList.add("battle-card--selected")
    this.markEmptySlotsPlaceable(true)
    this.updateHint()
  }

  // Step 2 of placing: an empty slot on the player's own side. Resolves
  // the placement immediately once chosen.
  selectPlacementSlot(event) {
    if (!this.canAct() || this.selectedCardRole !== "place" || this.requestInFlight) return

    const slotEl = event.currentTarget
    if (slotEl.querySelector(".battle-card")) return // occupied

    const body = new URLSearchParams({ card_id: this.selectedCardId, slot: slotEl.dataset.slot })
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
    this.markEmptySlotsPlaceable(false)
    this.selectedCardId = el.dataset.battleCardId
    this.selectedCardRole = "attacker"
    el.classList.add("battle-card--selected")
    this.updateHint()
  }

  // Step 2: an enemy card, or the opponent avatar itself. Resolves the
  // attack immediately -- no staging, no separate submit step.
  selectTarget(event) {
    if (!this.canAct() || this.selectedCardRole !== "attacker" || this.requestInFlight) return

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
    if (data.move_html) this.logTarget.insertAdjacentHTML("afterbegin", data.move_html)
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
      this.applyBoardHtml(data.final_html).then(() => this.finishEndTurn(data))
      return
    }

    setTimeout(() => {
      const step = steps[index]
      // Waits for the swap (and any death-flash delay it triggered) to
      // fully finish before scheduling the next step -- otherwise a kill
      // on this step could still be mid-animation when the next step's
      // own board swap lands, stepping on it.
      this.applyBoardHtml(step.board_html).then(() => {
        if (step.move_html) this.logTarget.insertAdjacentHTML("afterbegin", step.move_html)
        this.highlightAiStep(step)
        this.revealSteps(steps, index + 1, data)
      })
    }, AI_MOVE_DELAY_MS)
  }

  // Spotlights what the AI just did for this step, using the same visual
  // language as the player's own selection (blue outline = acting card,
  // red pulse = whatever it hit) -- otherwise a step is just an HP diff
  // you have to spot yourself. Lasts until the next applyBoardHtml swap
  // replaces the board wholesale, no manual cleanup needed.
  highlightAiStep(step) {
    if (step.acting_card_id) {
      this.boardTarget.querySelector(`[data-battle-card-id="${step.acting_card_id}"]`)?.classList.add("battle-card--selected")
    }

    if (step.target_card_id) {
      this.boardTarget.querySelector(`[data-battle-card-id="${step.target_card_id}"]`)?.classList.add("battle-card--attacking")
    } else if (step.target_player) {
      this.boardTarget.querySelector('[data-hp-avatar="player"]')?.classList.add("battle-avatar-card--attacking")
    }
  }

  finishEndTurn(data) {
    this.readyButtonTarget.disabled = false
    this.readyButtonTarget.textContent = "Ready"
    this.resetSelection()

    if (data.battle_over) {
      this.endBattle(data.battle_over, data.result_log_html)
    } else {
      this.statusTarget.textContent = "Your turn"
      this.resetTurnTimer()
    }
  }

  endBattle(status, resultLogHtml) {
    this.statusTarget.textContent = status === "won" ? "You won!" : "You lost."
    if (resultLogHtml) this.logTarget.insertAdjacentHTML("afterbegin", resultLogHtml)
    this.activeValue = false
    this.element.querySelector(".battle-controls")?.remove()
    if (this.timerIntervalId) clearInterval(this.timerIntervalId)
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
  //
  // A card that died this update would otherwise just vanish the instant
  // this swap happens -- one frame it's at full hp, the next it's gone,
  // with no visible moment where it actually took the killing blow. So a
  // card about to disappear gets shown at 0 hp with the normal red flash
  // *first*, on the still-current DOM, and only actually gets removed
  // (via the real swap) once that's had time to register. Returns a
  // promise so callers that chain further board mutations (the AI-turn
  // reveal) can wait for the whole thing, deaths included, before moving
  // on to the next step.
  applyBoardHtml(html) {
    const before = this.captureHpSnapshot()
    const dyingIds = this.findDyingCardIds(html)

    if (dyingIds.length === 0) {
      this.finishBoardSwap(html, before)
      return Promise.resolve()
    }

    this.flashDyingCards(dyingIds)
    return new Promise((resolve) => {
      setTimeout(() => {
        this.finishBoardSwap(html, before)
        resolve()
      }, DEATH_FLASH_DELAY_MS)
    })
  }

  finishBoardSwap(html, before) {
    this.boardTarget.innerHTML = html
    this.flashChangedHp(before)
    this.updateReadyGlow()
  }

  // A card id currently rendered on the board that won't appear anywhere
  // in the incoming html at all means it just died -- zone flips to
  // "dead" the instant hp hits 0, which drops it out of every zone the
  // board renders (hand/board). Nothing else makes an id disappear
  // outright within a single attack/place diff (a hand->board move keeps
  // the same id findable, just under different markup).
  findDyingCardIds(newHtml) {
    return [...this.boardTarget.querySelectorAll(".battle-card[data-battle-card-id]")]
      .map((el) => el.dataset.battleCardId)
      .filter((id) => !newHtml.includes(`data-battle-card-id="${id}"`))
  }

  flashDyingCards(dyingIds) {
    dyingIds.forEach((id) => {
      const hpNode = this.boardTarget.querySelector(`.battle-card[data-battle-card-id="${id}"] [data-hp-node]`)
      if (!hpNode) return

      const max = hpNode.textContent.match(/\/(\d+)/)?.[1] ?? "0"
      hpNode.textContent = `♥ 0/${max}`
      this.flashNode(hpNode, "battle-hp-flash")
    })
  }

  // Green halo on Ready once the player has nothing left to do this turn
  // (every card acted or can't act) -- a nudge that there's no more
  // benefit to looking for a move, not just an empty hint line. The CSS
  // itself also gates this on the button being enabled, so it can never
  // show mid-request or during the opponent's reveal.
  updateReadyGlow() {
    if (!this.hasReadyButtonTarget) return

    const actionable = this.boardTarget.querySelector(".battle-board")?.dataset.playerActionable === "true"
    this.readyButtonTarget.classList.toggle("battle-controls__ready--glow", this.activeValue && !actionable)
  }

  // Ticks the visible countdown once a second and auto-submits Ready once
  // it hits zero -- a turn is capped at TURN_SECONDS, not just advisory.
  // Gated on the board's own data-current-turn (recomputed fresh every
  // tick) rather than a locally-tracked flag, so it automatically goes
  // quiet for the whole opponent-turn reveal without separate bookkeeping.
  tickTimer() {
    if (!this.hasTimerTarget) return

    if (!this.canAct() || !this.isPlayerTurnInDom() || !this.turnDeadline) {
      this.timerTarget.textContent = ""
      return
    }

    const remainingMs = this.turnDeadline - Date.now()
    if (remainingMs <= 0) {
      this.timerTarget.textContent = "0:00"
      this.endTurn() // no-ops via its own guards if a request is already in flight
      return
    }

    const totalSeconds = Math.ceil(remainingMs / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    this.timerTarget.textContent = `${minutes}:${String(seconds).padStart(2, "0")}`
  }

  // Called once a fresh player turn actually begins (not on every
  // place/attack -- those spend from the same turn's budget, they don't
  // renew it). Client-side "now" rather than a server timestamp: simpler,
  // and avoids clock-skew weirdness between server and browser time.
  resetTurnTimer() {
    this.turnDeadline = Date.now() + this.turnSecondsValue * 1000
    this.tickTimer()
  }

  isPlayerTurnInDom() {
    return this.boardTarget.querySelector(".battle-board")?.dataset.currentTurn === "player"
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

  markEmptySlotsPlaceable(active) {
    this.boardTarget.querySelectorAll('.battle-slot[data-side="player"]').forEach((slotEl) => {
      if (slotEl.querySelector(".battle-card")) return

      slotEl.classList.toggle("battle-slot--placeable", active)
    })
  }

  updateHint() {
    if (!this.hasHintTarget) return

    if (this.selectedCardRole === "place") {
      this.hintTarget.textContent = "Choose an empty slot to place it in -- left, center, or right."
    } else if (this.selectedCardRole === "attacker") {
      this.hintTarget.textContent = "Choose a target -- an enemy card, or the opponent."
    } else {
      this.hintTarget.textContent = "Click a hand card to place it, or select a board card then a target to attack."
    }
  }

  highlightCard(event) {
    const id = event.currentTarget.dataset.battleCardId
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${id}"]`)
    cardEl?.classList.add("battle-card--log-highlight")
  }

  highlightTargetCard(event) {
    const id = event.currentTarget.dataset.battleCardId
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${id}"]`)
    cardEl?.classList.add("battle-card--log-highlight-target")
  }

  unhighlightCard(event) {
    const id = event.currentTarget.dataset.battleCardId
    const cardEl = this.boardTarget.querySelector(`[data-battle-card-id="${id}"]`)
    cardEl?.classList.remove("battle-card--log-highlight", "battle-card--log-highlight-target")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["achievementSelect", "count", "emptyState", "gameSelect", "hiddenInput", "list"]
  // achievements: the chosen game's, when the page already has one (editing a chain). achievementsUrl: where to fetch
  // another game's, with ":game_id" in it.
  static values = { achievements: Array, achievementsUrl: String, placeholderIcon: String }

  connect() {
    this.achievements = this.achievementsValue
    this.selectedAchievements = this.initialSelectedAchievements()
    this.syncAchievementOptions()
    this.render()
  }

  async changeGame() {
    const gameId = this.gameSelectTarget.value
    this.selectedAchievements = []
    this.achievements = []
    this.loading = Boolean(gameId)
    this.syncAchievementOptions()
    this.render()
    if (!gameId) return

    const url = this.achievementsUrlValue.replace(":game_id", encodeURIComponent(gameId))
    let achievements = []
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (response.ok) achievements = await response.json()
    } catch {
      // Leaves the list empty; picking the game again retries.
    }
    if (this.gameSelectTarget.value !== gameId) return // another game was picked meanwhile

    this.achievements = achievements
    this.loading = false
    this.syncAchievementOptions()
  }

  addAchievement() {
    const achievementId = Number(this.achievementSelectTarget.value)

    if (!achievementId) {
      return
    }

    const achievement = this.achievements.find((item) => item.id === achievementId)

    if (!achievement || this.selectedAchievements.some((item) => item.id === achievement.id)) {
      return
    }

    this.selectedAchievements.push({ ...achievement, note: "" })
    this.syncAchievementOptions()
    this.render()
  }

  removeAchievement(event) {
    const achievementId = Number(event.currentTarget.dataset.achievementId)
    this.selectedAchievements = this.selectedAchievements.filter((item) => item.id !== achievementId)
    this.syncAchievementOptions()
    this.render()
  }

  updateNote(event) {
    const achievementId = Number(event.currentTarget.dataset.achievementId)
    const achievement = this.selectedAchievements.find((item) => item.id === achievementId)

    if (!achievement) {
      return
    }

    achievement.note = event.currentTarget.value
    this.syncHiddenInput()
  }

  initialSelectedAchievements() {
    const selectedPayload = this.parseHiddenPayload()
    const achievementMap = new Map(this.achievements.map((achievement) => [achievement.id, achievement]))

    return selectedPayload
      .map((item) => {
        const achievement = achievementMap.get(item.id)
        return achievement ? { ...achievement, note: item.note || "" } : null
      })
      .filter(Boolean)
  }

  availableAchievements() {
    const selectedIds = new Set(this.selectedAchievements.map((item) => item.id))
    return this.achievements.filter((achievement) => !selectedIds.has(achievement.id))
  }

  syncAchievementOptions() {
    const gameChosen = Boolean(this.gameSelectTarget.value)
    const availableAchievements = this.availableAchievements()

    this.achievementSelectTarget.innerHTML = ""

    const promptOption = document.createElement("option")
    promptOption.value = ""
    promptOption.textContent = !gameChosen ? "Select a game first" : this.loading ? "Loading achievements…" : "Select an achievement"
    this.achievementSelectTarget.append(promptOption)

    availableAchievements.forEach((achievement) => {
      const option = document.createElement("option")
      option.value = achievement.id
      option.textContent = achievement.title
      this.achievementSelectTarget.append(option)
    })

    this.achievementSelectTarget.disabled = !gameChosen || this.loading || availableAchievements.length === 0
  }

  render() {
    this.syncHiddenInput()
    this.listTarget.innerHTML = ""

    this.selectedAchievements.forEach((achievement, index) => {
      const item = document.createElement("li")
      item.className = "chain-builder-item"

      // onerror covers a present-but-dead icon URL (e.g. achievements
      // imported from Steam's now-retired steamcdn-a.akamaihd.net) --
      // blank URLs already get the CSS-styled placeholder div below.
      const iconMarkup = achievement.icon_unlocked
        ? `<img src="${this.escapeHtml(achievement.icon_unlocked)}" alt="" class="chain-builder-item__icon" onerror="this.onerror=null;this.src='${this.escapeHtml(this.placeholderIconValue)}';">`
        : `<div class="chain-builder-item__icon chain-builder-item__icon--placeholder">${index + 1}</div>`

      item.innerHTML = `
        <div class="chain-builder-item__media">${iconMarkup}</div>
        <div class="chain-builder-item__body">
          <h3>${this.escapeHtml(achievement.title)}</h3>
          <p>${this.escapeHtml(achievement.description || "No description available.")}</p>
          <label class="chain-builder-item__note-label" for="chain_builder_note_${achievement.id}">Narration note</label>
          <textarea
            id="chain_builder_note_${achievement.id}"
            class="chain-builder-item__note"
            rows="3"
            data-action="input->chain-builder#updateNote"
            data-achievement-id="${achievement.id}"
            placeholder="Add the journey text for this step."
          >${this.escapeHtml(achievement.note || "")}</textarea>
        </div>
        <button
          type="button"
          class="chain-builder-item__remove"
          data-action="click->chain-builder#removeAchievement"
          data-achievement-id="${achievement.id}"
        >
          Remove
        </button>
      `

      this.listTarget.append(item)
    })

    this.countTarget.textContent = `${this.selectedAchievements.length} selected`
    this.emptyStateTarget.hidden = this.selectedAchievements.length > 0
  }

  syncHiddenInput() {
    this.hiddenInputTarget.value = JSON.stringify(
      this.selectedAchievements.map((item) => ({
        id: item.id,
        note: item.note || "",
      })),
    )
  }

  parseHiddenPayload() {
    try {
      const parsed = JSON.parse(this.hiddenInputTarget.value || "[]")
      if (!Array.isArray(parsed)) {
        return []
      }

      return parsed.flatMap((value) => {
        if (Number.isInteger(Number(value))) {
          return [{ id: Number(value), note: "" }]
        }

        if (value && Number.isInteger(Number(value.id))) {
          return [{ id: Number(value.id), note: String(value.note || "") }]
        }

        return []
      })
    } catch {
      return []
    }
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["achievementSelect", "count", "emptyState", "gameSelect", "hiddenInput", "list"]
  static values = { games: Array }

  connect() {
    this.selectedAchievements = this.initialSelectedAchievements()
    this.syncAchievementOptions()
    this.render()
  }

  changeGame() {
    this.selectedAchievements = []
    this.syncAchievementOptions()
    this.render()
  }

  addAchievement() {
    const selectedGame = this.currentGame()
    const achievementId = Number(this.achievementSelectTarget.value)

    if (!selectedGame || !achievementId) {
      return
    }

    const achievement = selectedGame.achievements.find((item) => item.id === achievementId)

    if (!achievement || this.selectedAchievements.some((item) => item.id === achievement.id)) {
      return
    }

    this.selectedAchievements.push(achievement)
    this.syncAchievementOptions()
    this.render()
  }

  removeAchievement(event) {
    const achievementId = Number(event.currentTarget.dataset.achievementId)
    this.selectedAchievements = this.selectedAchievements.filter((item) => item.id !== achievementId)
    this.syncAchievementOptions()
    this.render()
  }

  currentGame() {
    const gameId = Number(this.gameSelectTarget.value)
    return this.gamesValue.find((game) => game.id === gameId)
  }

  initialSelectedAchievements() {
    const selectedIds = this.parseHiddenIds()
    const currentAchievements = this.currentGame()?.achievements || []
    const achievementMap = new Map(currentAchievements.map((achievement) => [achievement.id, achievement]))

    return selectedIds
      .map((id) => achievementMap.get(id))
      .filter(Boolean)
  }

  availableAchievements() {
    const selectedIds = new Set(this.selectedAchievements.map((item) => item.id))
    return (this.currentGame()?.achievements || []).filter((achievement) => !selectedIds.has(achievement.id))
  }

  syncAchievementOptions() {
    const selectedGame = this.currentGame()
    const availableAchievements = this.availableAchievements()

    this.achievementSelectTarget.innerHTML = ""

    const promptOption = document.createElement("option")
    promptOption.value = ""
    promptOption.textContent = selectedGame ? "Select an achievement" : "Select a game first"
    this.achievementSelectTarget.append(promptOption)

    availableAchievements.forEach((achievement) => {
      const option = document.createElement("option")
      option.value = achievement.id
      option.textContent = achievement.title
      this.achievementSelectTarget.append(option)
    })

    this.achievementSelectTarget.disabled = !selectedGame || availableAchievements.length === 0
  }

  render() {
    this.hiddenInputTarget.value = JSON.stringify(this.selectedAchievements.map((item) => item.id))
    this.listTarget.innerHTML = ""

    this.selectedAchievements.forEach((achievement, index) => {
      const item = document.createElement("li")
      item.className = "chain-builder-item"

      item.innerHTML = `
        <div class="chain-builder-item__order">${index + 1}</div>
        <div class="chain-builder-item__body">
          <h3>${this.escapeHtml(achievement.title)}</h3>
          <p>${this.escapeHtml(achievement.description || "No description available.")}</p>
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

  parseHiddenIds() {
    try {
      const parsed = JSON.parse(this.hiddenInputTarget.value || "[]")
      return Array.isArray(parsed) ? parsed.map((value) => Number(value)).filter((value) => Number.isInteger(value)) : []
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

import { Controller } from "@hotwired/stimulus"

const COOKIE_NAME = "cookie_consent"
const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365

export default class extends Controller {
  static values = { amplitudeKey: String }

  accept() {
    this.#setCookie("accepted")
    this.#loadAmplitude()
    this.element.remove()
  }

  decline() {
    this.#setCookie("declined")
    this.element.remove()
  }

  #setCookie(value) {
    document.cookie = `${COOKIE_NAME}=${value}; path=/; max-age=${COOKIE_MAX_AGE_SECONDS}; samesite=lax`
  }

  // Starts tracking immediately on accept, rather than waiting for the next
  // full page load to pick up the now-set cookie server-side (Turbo drive
  // navigations don't re-run <head> scripts, so that could be a while).
  #loadAmplitude() {
    const script = document.createElement("script")
    script.src = `https://cdn.amplitude.com/script/${this.amplitudeKeyValue}.js`
    script.onload = () => {
      window.amplitude.add(window.sessionReplay.plugin({ sampleRate: 1 }))
      window.amplitude.init(this.amplitudeKeyValue, { fetchRemoteConfig: true, autocapture: true })
    }
    document.head.appendChild(script)
  }
}

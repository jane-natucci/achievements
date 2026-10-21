// First-party pageview logging -- see counter's BeaconController/PageView.
// Replaces third-party analytics (Amplitude): no cookie, no persistent
// visitor id, just app/path/referrer per request.

// The follow-up beacon: sent once per page, the first time something on it moves or is
// pressed (scroll, key, touch, pointer). Most scripted visits never do, so the server
// can tell "a page was loaded" from "a page was used" -- see BeaconController.
const ENGAGEMENT_EVENTS = ["pointerdown", "pointermove", "keydown", "scroll", "touchstart", "wheel"]
let stopWatching = null

function watchForEngagement(payload) {
  if (stopWatching) stopWatching()
  const body = JSON.stringify({ ...payload, event: "engaged" })
  const onEvent = () => {
    if (document.visibilityState !== "visible") return
    stopWatching()
    if (navigator.sendBeacon) {
      navigator.sendBeacon("https://jane.berlin/beacon", body)
    } else {
      fetch("https://jane.berlin/beacon", { method: "POST", body, keepalive: true })
    }
  }
  stopWatching = () => {
    ENGAGEMENT_EVENTS.forEach((name) => window.removeEventListener(name, onEvent, true))
    stopWatching = null
  }
  ENGAGEMENT_EVENTS.forEach((name) => window.addEventListener(name, onEvent, { capture: true, passive: true }))
}

// Hooks turbo:load (fires on the initial page load AND every subsequent
// Turbo-driven navigation) rather than running once at module-load time --
// this app uses Turbo, so most navigations after the first never trigger a
// full page (re)load.
document.addEventListener("turbo:load", () => {
  const page = {
    app: "achievements",
    path: location.pathname,
    referrer: document.referrer,
  }
  const payload = JSON.stringify(page)

  if (navigator.sendBeacon) {
    navigator.sendBeacon("https://jane.berlin/beacon", payload)
  } else {
    fetch("https://jane.berlin/beacon", { method: "POST", body: payload, keepalive: true })
  }

  watchForEngagement({ app: page.app, subdomain: page.subdomain, path: page.path })
})

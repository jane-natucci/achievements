// First-party pageview logging -- see counter's BeaconController/PageView.
// Replaces third-party analytics (Amplitude): no cookie, no persistent
// visitor id, just app/path/referrer per request.
//
// Hooks turbo:load (fires on the initial page load AND every subsequent
// Turbo-driven navigation) rather than running once at module-load time --
// this app uses Turbo, so most navigations after the first never trigger a
// full page (re)load.
document.addEventListener("turbo:load", () => {
  const payload = JSON.stringify({
    app: "achievements",
    path: location.pathname,
    referrer: document.referrer,
  })

  if (navigator.sendBeacon) {
    navigator.sendBeacon("https://jane.berlin/beacon", payload)
  } else {
    fetch("https://jane.berlin/beacon", { method: "POST", body: payload, keepalive: true })
  }
})

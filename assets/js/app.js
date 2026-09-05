// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/neko"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Play the welcome ceremony on every visit
const welcome = document.querySelector("[data-wedding-welcome]")
if (welcome) {
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  welcome.dataset.welcomeState = reducedMotion ? "seen" : "playing"
}

// Wedding countdown
const countdown = document.querySelector("[data-countdown]")
if (countdown) {
  const target = new Date(countdown.dataset.countdown).getTime()
  const cell = (k) => countdown.querySelector(`[data-count-${k}]`)
  const pad = (n) => String(n).padStart(2, "0")
  const tick = () => {
    const diff = Math.max(0, target - Date.now())
    if (diff === 0) { countdown.dataset.married = "true" }
    cell("d").textContent = Math.floor(diff / 864e5)
    cell("h").textContent = pad(Math.floor(diff / 36e5) % 24)
    cell("m").textContent = pad(Math.floor(diff / 6e4) % 60)
    cell("s").textContent = pad(Math.floor(diff / 1e3) % 60)
  }
  tick()
  setInterval(tick, 1000)
}

// Attempt soft autoplay and always expose an honest play/pause state
const musicPlayer = document.querySelector("[data-music-player]")
if (musicPlayer) {
  const audio = musicPlayer.querySelector("[data-music-audio]")
  const toggle = musicPlayer.querySelector("[data-music-toggle]")
  const status = musicPlayer.querySelector("[data-music-status]")
  const openInvitation = document.querySelector("#wedding-open-invitation")
  let autoplayBlocked = false

  const syncMusicPlayer = () => {
    const playing = !audio.paused && !audio.ended
    musicPlayer.dataset.state = playing ? "playing" : "paused"
    toggle.setAttribute("aria-pressed", String(playing))
    toggle.setAttribute("aria-label", playing ? "Pause Canon in D" : "Play Canon in D")
    status.textContent = playing
      ? "Canon in D · Playing softly"
      : autoplayBlocked
        ? "Canon in D · Tap to play"
        : "Canon in D · Music paused"
  }

  const playMusic = async () => {
    try {
      await audio.play()
      autoplayBlocked = false
    } catch (_error) {
      autoplayBlocked = true
    }
    syncMusicPlayer()
  }

  audio.volume = 0.45
  audio.addEventListener("play", syncMusicPlayer)
  audio.addEventListener("pause", syncMusicPlayer)
  toggle.addEventListener("click", () => audio.paused ? playMusic() : audio.pause())
  openInvitation.addEventListener("click", () => {
    if (autoplayBlocked && audio.paused) playMusic()
  }, {once: true})
  playMusic()
}

// Reveal sections as they scroll into view
document.documentElement.classList.add("reveal-ready")
const revealEls = document.querySelectorAll("[data-reveal]")
if ("IntersectionObserver" in window) {
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible")
        io.unobserve(entry.target)
      }
    })
  }, {threshold: 0.12})
  revealEls.forEach((el) => io.observe(el))
} else {
  revealEls.forEach((el) => el.classList.add("is-visible"))
}

// Native swipe gallery with keyboard and button controls
const photoStory = document.querySelector("#wedding-story")
if (photoStory) {
  const rail = photoStory.querySelector("[data-photo-rail]")
  const slides = [...photoStory.querySelectorAll("[data-photo-slide]")]
  const previous = photoStory.querySelector("[data-photo-previous]")
  const next = photoStory.querySelector("[data-photo-next]")
  const current = photoStory.querySelector("[data-photo-current]")
  const autoplay = photoStory.querySelector("[data-photo-autoplay]")
  const pauseIcon = photoStory.querySelector(".photo-story-pause")
  const playIcon = photoStory.querySelector(".photo-story-play")
  let active = 0
  let autoplayPaused = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  let autoplayTimer
  let galleryVisible = false
  let frame

  const updateGallery = () => {
    const center = rail.scrollLeft + rail.clientWidth / 2
    const maxScroll = rail.scrollWidth - rail.clientWidth

    active = rail.scrollLeft <= 1
      ? 0
      : rail.scrollLeft >= maxScroll - 1
        ? slides.length - 1
        : slides.reduce((nearest, slide, index) => {
          const distance = Math.abs(slide.offsetLeft + slide.offsetWidth / 2 - center)
          const nearestDistance = Math.abs(
            slides[nearest].offsetLeft + slides[nearest].offsetWidth / 2 - center
          )
          return distance < nearestDistance ? index : nearest
        }, 0)

    slides.forEach((slide, index) => slide.dataset.active = String(index === active))
    current.textContent = String(active + 1).padStart(2, "0")
    previous.disabled = active === 0
    next.disabled = active === slides.length - 1
  }

  const showPhoto = (index, behavior = "smooth") => {
    const boundedIndex = Math.max(0, Math.min(index, slides.length - 1))
    const slide = slides[boundedIndex]
    const left = boundedIndex === 0
      ? 0
      : boundedIndex === slides.length - 1
        ? rail.scrollWidth - rail.clientWidth
        : slide.offsetLeft - (rail.clientWidth - slide.offsetWidth) / 2
    rail.scrollTo({left, behavior})
  }

  const startAutoplay = () => {
    window.clearInterval(autoplayTimer)
    if (autoplayPaused || document.hidden || !galleryVisible) return
    autoplayTimer = window.setInterval(() => {
      if (active === slides.length - 1) showPhoto(0, "auto")
      else showPhoto(active + 1)
    }, 2000)
  }

  const syncAutoplay = () => {
    autoplay.setAttribute("aria-pressed", String(autoplayPaused))
    autoplay.setAttribute(
      "aria-label",
      autoplayPaused ? "เล่นภาพอัตโนมัติ" : "หยุดการเลื่อนภาพอัตโนมัติ"
    )
    pauseIcon.classList.toggle("hidden", autoplayPaused)
    playIcon.classList.toggle("hidden", !autoplayPaused)
    startAutoplay()
  }

  const navigateTo = (index) => {
    showPhoto(index)
    startAutoplay()
  }

  rail.addEventListener("scroll", () => {
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(updateGallery)
  }, {passive: true})
  rail.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return
    event.preventDefault()
    navigateTo(active + (event.key === "ArrowRight" ? 1 : -1))
  })
  previous.addEventListener("click", () => navigateTo(active - 1))
  next.addEventListener("click", () => navigateTo(active + 1))
  slides.forEach((slide, index) => slide.addEventListener("click", () => navigateTo(index)))
  autoplay.addEventListener("click", () => {
    autoplayPaused = !autoplayPaused
    syncAutoplay()
  })
  if ("IntersectionObserver" in window) {
    const galleryObserver = new IntersectionObserver(([entry]) => {
      galleryVisible = entry.intersectionRatio >= 0.35
      startAutoplay()
    }, {threshold: [0, 0.35]})
    galleryObserver.observe(rail)
  } else {
    galleryVisible = true
  }
  document.addEventListener("visibilitychange", startAutoplay)
  window.addEventListener("resize", updateGallery)
  updateGallery()
  syncAutoplay()
}

// Enhance the RSVP form without losing the current scroll, music, or gallery state
const syncPartySizeField = () => {
  const attendance = document.querySelector("#rsvp-attending")
  const field = document.querySelector("#rsvp-party-size-field")
  const partySize = document.querySelector("#rsvp-party-size")
  if (!attendance || !field || !partySize) return

  const attending = attendance.value === "true"
  field.classList.toggle("is-visible", attending)
  field.setAttribute("aria-hidden", String(!attending))
  partySize.disabled = !attending
}

document.addEventListener("change", (event) => {
  if (event.target.matches("#rsvp-attending")) syncPartySizeField()
})
syncPartySizeField()

document.addEventListener("submit", async (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || form.id !== "wedding-rsvp-form") return

  event.preventDefault()
  const submitter = event.submitter || form.querySelector('[type="submit"]')
  form.setAttribute("aria-busy", "true")
  if (submitter) submitter.disabled = true

  try {
    const response = await fetch(form.action, {
      method: form.method,
      body: new FormData(form),
      credentials: "same-origin",
    })
    const documentCopy = new DOMParser().parseFromString(await response.text(), "text/html")
    const currentPanel = document.querySelector("#rsvp-panel")
    const nextPanel = documentCopy.querySelector("#rsvp-panel")
    if (!currentPanel || !nextPanel) throw new Error("RSVP panel missing from response")

    const scrollPosition = {left: window.scrollX, top: window.scrollY}
    currentPanel.replaceWith(nextPanel)
    syncPartySizeField()

    const focusTarget = nextPanel.querySelector(
      '#rsvp-success, [aria-invalid="true"]'
    )
    if (focusTarget) {
      if (!focusTarget.matches("input, select, button, a")) focusTarget.tabIndex = -1
      focusTarget.focus({preventScroll: true})
    }
    window.scrollTo({...scrollPosition, behavior: "instant"})
  } catch (_error) {
    HTMLFormElement.prototype.submit.call(form)
  }
})

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

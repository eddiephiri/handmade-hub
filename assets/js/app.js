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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import "preline/preline"
import Alpine from "alpinejs"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const Hooks = {}

Hooks.AutoHideFlash = {
  mounted() {
    const delayMs = parseInt(this.el.getAttribute("data-autohide-ms") || "4000", 10)
    this._timer = setTimeout(() => {
      // Trigger the same action as clicking to clear the flash and hide
      this.pushEvent("lv:clear-flash", {key: this.el.id?.includes("error") ? "error" : "info"})
      this.el.dispatchEvent(new Event("click", {bubbles: true}))
    }, delayMs)
  },
  destroyed() {
    if (this._timer) clearTimeout(this._timer)
  }
}

Hooks.StarRating = {
  mounted() {
    this.stars = Array.from(this.el.querySelectorAll('[data-star]'))
    this.inputs = Array.from(this.el.querySelectorAll('input[type="radio"][name]'))
    this.value = 0
    this.stars.forEach((star, idx) => {
      star.addEventListener('mouseenter', () => this.paint(idx + 1))
      star.addEventListener('mouseleave', () => this.paint(this.value))
      star.addEventListener('click', (e) => {
        e.preventDefault()
        this.value = idx + 1
        const input = this.inputs.find(i => i.value == String(this.value))
        if (input) input.checked = true
        this.paint(this.value)
      })
    })
    this.paint(0)
  },
  paint(n) {
    this.stars.forEach((star, i) => {
      star.classList.toggle('text-yellow-400', i < n)
      star.classList.toggle('text-gray-300', i >= n)
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
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

HSStaticMethods.autoInit();

document.addEventListener("phx:page-loading-stop", () => {
  if (window.HSStaticMethods) {
    window.HSStaticMethods.autoInit();
  }
});

window.Alpine = Alpine;
Alpine.start();


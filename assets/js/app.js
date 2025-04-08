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
import Alpine from "alpinejs"
import collapse from '@alpinejs/collapse'

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { themeChange } from 'theme-change'
import topbar from "../vendor/topbar"
import Sortable from "../vendor/sortable"
import NoSleep from "nosleep.js"
import { GridSelection, InfiniteScroll } from "../../lib/safarimanager_web/components/grid.hooks"
import { Lightbox } from "../vendor/lightbox"

window.Alpine = Alpine

Alpine.plugin(collapse)
Alpine.start()

themeChange()


let sortable = {
  mounted() {
    let group = this.el.dataset.group
    let sorter = new Sortable(this.el, {
      group: group ? { name: group, pull: true, put: true } : undefined,
      animation: 150,
      delay: 100,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      forceFallback: true,
      onEnd: e => {
        let params = { old: e.oldIndex, new: e.newIndex, to: e.to.dataset, ...e.item.dataset }
        this.pushEventTo(this.el, "reposition", params)
      }
    })
  }
}

let sortableInputsFor = {
  mounted() {
    let group = this.el.dataset.group
    let sorter = new Sortable(this.el, {
      group: group ? { name: group, pull: true, put: true } : undefined,
      animation: 150,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      handle: "[data-handle]",
      forceFallback: true,
      fallbackOnBody: true,
      onEnd: e => {
        this.el.closest("form").querySelector("input").dispatchEvent(new Event("input", { bubbles: true }))
      }
    })
  }
}

let noSleep = {
  mounted() {
    var noSleep = new NoSleep();
    var wakeLockEnabled = false;
    window.addEventListener('click', function () {
      if (!wakeLockEnabled) {
        noSleep.enable(); // keep the screen on!
        wakeLockEnabled = true;
      }
    }, false);
  }
}

let autoClearFlash = {
  mounted() {
    let ignoredIDs = ["client-error", "server-error"];
    if (ignoredIDs.includes(this.el.id)) return;

    let hideElementAfter = 5000; // ms
    let clearFlashAfter = hideElementAfter + 500; // ms

    // first hide the element
    setTimeout(() => {
      this.el.style.opacity = 0;
    }, hideElementAfter);

    // then clear the flash
    setTimeout(() => {
      this.pushEvent("lv:clear-flash");
    }, clearFlashAfter);
  },
}

const hooks = {
  GridSelection: GridSelection,
  InfiniteScroll: InfiniteScroll,
  Lightbox: Lightbox,
  AutoClearFlash: autoClearFlash,
  Sortable: sortable,
  SortableInputsFor: sortableInputsFor,
  NoSleep: noSleep
}

console.log("hooks", hooks)

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  dom: {
    // make LiveView work nicely with alpinejs
    onBeforeElUpdated(from, to) {
      // if (from.__x) {
      //   window.Alpine.clone(from.__x, to);
      // }
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
      }
    },
  },
  params: { _csrf_token: csrfToken },
  hooks: hooks
})


// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())
window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
  // Enable server log streaming to client.
  // Disable with reloader.disableServerLogs()
  reloader.enableServerLogs()
  window.liveReloader = reloader
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// liveSocket.enableDebug()
// liveSocket.disableDebug()
// liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Mutation observer to highlight changed elements
new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    if (mutation.type === 'childList') {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          node.style.transition = 'outline 0.3s ease-in-out';
          node.style.outline = '2px solid red';
          setTimeout(() => {
            node.style.outline = 'none';
            node.style.transition = '';
          }, 1000);
        }
      });
    }
  });
}).observe(document.body, {
  childList: true,
  subtree: true,
});

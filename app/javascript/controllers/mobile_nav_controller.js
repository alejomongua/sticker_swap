import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["button", "menu"]

    connect() {
        this.expanded = false
        this.handleResize = this.handleResize.bind(this)

        window.addEventListener("resize", this.handleResize)
        this.sync()
    }

    disconnect() {
        window.removeEventListener("resize", this.handleResize)
    }

    toggle() {
        if (this.desktop()) {
            return
        }

        this.expanded = !this.expanded
        this.sync()
    }

    handleResize() {
        if (this.desktop()) {
            this.expanded = false
        }

        this.sync()
    }

    sync() {
        this.menuTarget.classList.toggle("hidden", !this.desktop() && !this.expanded)
        this.buttonTarget.setAttribute("aria-expanded", this.desktop() ? "true" : this.expanded.toString())
    }

    desktop() {
        return window.innerWidth >= 640
    }
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = null
  }

  disconnect() {
    this.clearPendingSubmit()
  }

  submitImmediately() {
    this.queueSubmit(0)
  }

  submitWhenSearchReady(event) {
    const value = event.target.value.trim().toUpperCase()

    if (value === "" || value === "00" || value.length >= 4) {
      this.queueSubmit(250)
      return
    }

    this.clearPendingSubmit()
  }

  queueSubmit(delay) {
    this.clearPendingSubmit()
    this.timeout = window.setTimeout(() => this.element.requestSubmit(), delay)
  }

  clearPendingSubmit() {
    if (this.timeout === null) {
      return
    }

    window.clearTimeout(this.timeout)
    this.timeout = null
  }
}

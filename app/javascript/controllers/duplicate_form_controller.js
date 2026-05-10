import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bulkPanel", "bulkQuantity", "bulkCodes", "mode", "singleCode", "singlePanel", "singleQuantity"]

  connect() {
    this.sync()
  }

  sync() {
    const bulkMode = this.modeTarget.value === "bulk"

    this.bulkPanelTarget.classList.toggle("hidden", !bulkMode)
    this.singlePanelTarget.classList.toggle("hidden", bulkMode)

    this.singleCodeTarget.disabled = bulkMode
    this.singleQuantityTarget.disabled = bulkMode
    this.bulkCodesTarget.disabled = !bulkMode
    this.bulkQuantityTarget.disabled = !bulkMode
  }
}

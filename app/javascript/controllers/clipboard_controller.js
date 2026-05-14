import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = {
    text: String,
    successLabel: { type: String, default: "Copiado" },
    errorLabel: { type: String, default: "No se pudo copiar" }
  }

  connect() {
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : ""
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  async copy(event) {
    event.preventDefault()
    if (!this.textValue) return

    const copied = await this.writeText(this.textValue)
    this.updateLabel(copied ? this.successLabelValue : this.errorLabelValue)
  }

  async writeText(text) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        return true
      } catch (_error) {
      }
    }

    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.style.position = "absolute"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.select()

    const copied = document.execCommand("copy")
    textarea.remove()
    return copied
  }

  updateLabel(label) {
    if (!this.hasLabelTarget) return

    this.labelTarget.textContent = label
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.labelTarget.textContent = this.defaultLabel
    }, 2000)
  }
}
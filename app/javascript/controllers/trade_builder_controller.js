import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["badge", "offeredTextarea", "requestedTextarea", "submit"]

    connect() {
        this.sync()
    }

    toggle(event) {
        const badge = event.currentTarget
        const listName = badge.dataset.tradeBuilderList
        const code = badge.dataset.tradeBuilderCode
        const currentCodes = this.codesFor(listName)
        const nextCodes = currentCodes.includes(code)
            ? currentCodes.filter((value) => value !== code)
            : [...currentCodes, code]

        this.writeCodes(listName, nextCodes)
        this.sync()
    }

    sync() {
        const offeredCodes = this.codesFor("offered")
        const requestedCodes = this.codesFor("requested")

        this.badgeTargets.forEach((badge) => {
            const listName = badge.dataset.tradeBuilderList
            const code = badge.dataset.tradeBuilderCode
            const selected = (listName === "offered" ? offeredCodes : requestedCodes).includes(code)

            badge.classList.toggle("border-emerald-500", selected)
            badge.classList.toggle("bg-emerald-100", selected)
            badge.classList.toggle("text-emerald-900", selected)
            badge.classList.toggle("border-slate-200", !selected)
            badge.classList.toggle("bg-white", !selected)
            badge.classList.toggle("text-slate-700", !selected)
            badge.setAttribute("aria-pressed", selected.toString())
        })

        if (this.hasSubmitTarget) {
            const ready = offeredCodes.length > 0 && requestedCodes.length > 0

            this.submitTarget.disabled = !ready
        }
    }

    codesFor(listName) {
        return this.parseCodes(this.textareaFor(listName).value)
    }

    writeCodes(listName, codes) {
        this.textareaFor(listName).value = codes.join(", ")
    }

    textareaFor(listName) {
        return listName === "offered" ? this.offeredTextareaTarget : this.requestedTextareaTarget
    }

    parseCodes(value) {
        const seen = new Set()

        return value
            .toUpperCase()
            .split(/[^A-Z0-9]+/)
            .filter((token) => {
                if (token.length === 0 || seen.has(token)) {
                    return false
                }

                seen.add(token)
                return true
            })
    }
}
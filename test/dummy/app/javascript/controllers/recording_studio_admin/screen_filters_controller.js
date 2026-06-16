import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundDocumentClick = this.queueDateRangeSubmit.bind(this)
    document.addEventListener("click", this.boundDocumentClick, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundDocumentClick, true)
  }

  queueDateRangeSubmit(event) {
    const applyButton = event.target.closest("[data-flat-pack-date-picker-command='apply']")
    if (!applyButton) {
      return
    }

    const panel = applyButton.closest("[role='dialog']")
    const panelId = panel ? panel.id : ""
    if (!panelId) {
      return
    }

    const triggerSelector = `[aria-controls='${CSS.escape(panelId)}']`
    if (!this.element.querySelector(triggerSelector)) {
      return
    }

    const autoSubmit = this.application.getControllerForElementAndIdentifier(
      this.element,
      "flat-pack--auto-submit"
    )

    if (autoSubmit && typeof autoSubmit.queueSubmit === "function") {
      autoSubmit.queueSubmit()
      return
    }

    if (this.element.requestSubmit) {
      this.element.requestSubmit()
      return
    }

    this.element.submit()
  }
}

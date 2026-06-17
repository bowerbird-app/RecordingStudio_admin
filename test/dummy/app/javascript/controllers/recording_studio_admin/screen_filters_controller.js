import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundDocumentClick = this.queueDateRangeSubmit.bind(this)
    document.addEventListener("click", this.boundDocumentClick, true)

    // Ensure the visible trigger reflects the explicit preset key when one is present.
    // This prevents overlap cases (for example this_week vs last_3_days) from
    // showing the wrong preset label after navigation.
    requestAnimationFrame(() => this.syncPresetLabelsFromHiddenFields())
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

  syncPresetLabelsFromHiddenFields() {
    const presetLabels = {
      today: "Today",
      yesterday: "Yesterday",
      last_3_days: "Last 3 days",
      this_week: "This week",
      last_week: "Last week",
      this_month: "This month",
      last_month: "Last month",
      this_year: "This year",
      last_year: "Last year"
    }

    const presetInputs = this.element.querySelectorAll("input[type='hidden'][name$='date_range_preset']")
    presetInputs.forEach((presetInput) => {
      const presetKey = (presetInput.value || "").trim()
      const presetLabel = presetLabels[presetKey]
      if (!presetLabel) {
        return
      }

      const container = presetInput.parentElement
      if (!container) {
        return
      }

      const pickerRoot = container.querySelector("[data-controller~='flat-pack--flatpack-date-picker']")
      const trigger = container.querySelector("[data-flat-pack--flatpack-date-picker-target='trigger']")
      if (!trigger) {
        return
      }

      trigger.value = presetLabel
      if (pickerRoot) {
        pickerRoot.dataset.flatPackFlatpackDatePickerPresetKeyValue = presetKey
      }
    })
  }
}

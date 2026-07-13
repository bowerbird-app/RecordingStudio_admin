import { Controller } from "@hotwired/stimulus"

const SCREEN_FRAME_IDS = new Set(["screen-chart", "screen-table"])

export default class extends Controller {
  static values = { modalFilters: Boolean }

  connect() {
    this.boundDocumentClick = this.queueDateRangeSubmit.bind(this)
    this.boundTurboFrameLoad = this.handleTurboFrameLoad.bind(this)
    this.boundTurboFetchError = this.handleTurboFetchError.bind(this)
    document.addEventListener("click", this.boundDocumentClick, true)
    document.addEventListener("turbo:frame-load", this.boundTurboFrameLoad)
    document.addEventListener("turbo:fetch-request-error", this.boundTurboFetchError)

    this.scheduleViewportCleanup()

    requestAnimationFrame(() => this.syncPresetLabelsFromHiddenFields())
  }

  disconnect() {
    document.removeEventListener("click", this.boundDocumentClick, true)
    document.removeEventListener("turbo:frame-load", this.boundTurboFrameLoad)
    document.removeEventListener("turbo:fetch-request-error", this.boundTurboFetchError)
  }

  handleTurboFrameLoad(event) {
    if (!SCREEN_FRAME_IDS.has(event.target?.id)) {
      return
    }

    this.scheduleViewportCleanup()
  }

  handleTurboFetchError() {
    this.hideTableSkeletons()
  }

  showTableSkeletons() {
    const tableFrame = document.getElementById("screen-table")
    if (!tableFrame) {
      return
    }

    tableFrame.setAttribute("aria-busy", "true")

    tableFrame.querySelectorAll("[data-recording-studio-admin-table-cell-content]").forEach((content) => {
      content.style.visibility = "hidden"
    })

    tableFrame.querySelectorAll("[data-recording-studio-admin-table-cell-skeleton]").forEach((skeleton) => {
      skeleton.classList.remove("hidden")
      skeleton.classList.add("flex")
    })
  }

  hideTableSkeletons() {
    const tableFrame = document.getElementById("screen-table")
    if (!tableFrame) {
      return
    }

    tableFrame.removeAttribute("aria-busy")

    tableFrame.querySelectorAll("[data-recording-studio-admin-table-cell-content]").forEach((content) => {
      content.style.removeProperty("visibility")
    })

    tableFrame.querySelectorAll("[data-recording-studio-admin-table-cell-skeleton]").forEach((skeleton) => {
      skeleton.classList.add("hidden")
      skeleton.classList.remove("flex")
    })
  }

  refreshTableFrame() {
    const tableFrame = document.getElementById("screen-table")
    const tableSrc = tableFrame?.getAttribute("src")
    if (!tableFrame || !tableSrc) {
      return
    }

    const url = new URL(tableSrc, window.location.href)
    url.search = new URLSearchParams(new FormData(this.element)).toString()
    tableFrame.src = url.toString()
  }

  queueDateRangeSubmit(event) {
    if (this.modalFiltersValue) {
      return
    }

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

    this.showTableSkeletons()

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

    if (this.element instanceof HTMLFormElement) {
      this.refreshTableFrame()
    }
  }

  scheduleViewportCleanup() {
    requestAnimationFrame(() => {
      this.restoreOrphanedBodyScrollLock()
      this.removeDetachedDatePickerPanels()
    })
  }

  restoreOrphanedBodyScrollLock() {
    const lockCount = Number(document.body.dataset.flatPackModalLockCount || "0")
    if (lockCount <= 0) {
      return
    }

    const visibleModal = document.querySelector("[data-controller~='flat-pack--modal']:not(.hidden)")
    if (visibleModal) {
      return
    }

    document.body.style.removeProperty("overflow")
    document.body.style.removeProperty("padding-right")
    delete document.body.dataset.flatPackModalLockCount
  }

  removeDetachedDatePickerPanels() {
    const panels = document.body.querySelectorAll(".flat-pack-date-picker-panel")

    panels.forEach((panel) => {
      const trigger = panel.id ? document.querySelector(`[aria-controls='${CSS.escape(panel.id)}']`) : null
      const isOpen = panel.getAttribute("aria-hidden") === "false"

      if (isOpen || trigger) {
        return
      }

      panel.remove()
    })
  }
}
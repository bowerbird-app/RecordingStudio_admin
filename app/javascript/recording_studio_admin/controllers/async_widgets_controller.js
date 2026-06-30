import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["widget"]
  static values = {
    maxConcurrent: { type: Number, default: 4 },
    retryCount: { type: Number, default: 1 }
  }

  connect() {
    this.queue = []
    this.inFlight = 0
    this.boundFrameLoad = this.handleFrameLoad.bind(this)
    this.boundFrameError = this.handleFrameError.bind(this)
    document.addEventListener("turbo:frame-load", this.boundFrameLoad)
    document.addEventListener("turbo:fetch-request-error", this.boundFrameError)
    this.observeWidgets()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundFrameLoad)
    document.removeEventListener("turbo:fetch-request-error", this.boundFrameError)
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  observeWidgets() {
    if (!("IntersectionObserver" in window)) {
      this.widgetTargets.forEach((widget) => this.enqueue(widget))
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) {
          return
        }

        this.observer.unobserve(entry.target)
        this.enqueue(entry.target)
      })
    }, { rootMargin: "240px" })

    this.widgetTargets.forEach((widget) => this.observer.observe(widget))
  }

  enqueue(widget) {
    if (widget.hasAttribute("src")) {
      return
    }

    if (widget.dataset.recordingStudioAdminAsyncWidgetsStatus) {
      return
    }

    widget.dataset.recordingStudioAdminAsyncWidgetsStatus = "queued"
    this.queue.push(widget)
    this.pump()
  }

  pump() {
    while (this.inFlight < this.maxConcurrentValue && this.queue.length > 0) {
      const widget = this.queue.shift()
      const src = widget.dataset.recordingStudioAdminAsyncWidgetsSrcValue
      if (!src) {
        continue
      }

      widget.dataset.recordingStudioAdminAsyncWidgetsStatus = "loading"
      this.inFlight += 1
      widget.src = src
    }
  }

  handleFrameLoad(event) {
    const widget = event.target
    if (!this.widgetTargets.includes(widget)) {
      return
    }

    if (widget.dataset.recordingStudioAdminAsyncWidgetsStatus !== "loading") {
      return
    }

    widget.dataset.recordingStudioAdminAsyncWidgetsStatus = "loaded"
    this.inFlight = Math.max(this.inFlight - 1, 0)
    this.pump()
  }

  handleFrameError(event) {
    const widget = event.target
    if (!this.widgetTargets.includes(widget)) {
      return
    }

    if (widget.dataset.recordingStudioAdminAsyncWidgetsStatus !== "loading") {
      return
    }

    this.inFlight = Math.max(this.inFlight - 1, 0)
    const attempts = Number(widget.dataset.recordingStudioAdminAsyncWidgetsAttempts || "0")

    if (attempts < this.retryCountValue) {
      widget.dataset.recordingStudioAdminAsyncWidgetsAttempts = String(attempts + 1)
      delete widget.dataset.recordingStudioAdminAsyncWidgetsStatus
      window.setTimeout(() => this.enqueue(widget), this.retryDelay(attempts))
    } else {
      widget.dataset.recordingStudioAdminAsyncWidgetsStatus = "failed"
    }

    this.pump()
  }

  retryDelay(attempts) {
    return 250 + attempts * 500 + Math.floor(Math.random() * 250)
  }
}
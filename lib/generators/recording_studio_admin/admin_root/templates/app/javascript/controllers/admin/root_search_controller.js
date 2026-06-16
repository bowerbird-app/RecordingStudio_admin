import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "emptyState", "item"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.hasInputTarget ? this.inputTarget.value.trim().toLowerCase() : ""
    let visibleCount = 0

    this.itemTargets.forEach((item) => {
      const searchText = item.dataset.searchText || ""
      const matches = query.length > 0 && searchText.includes(query)

      item.hidden = !matches

      if (matches) {
        visibleCount += 1
      }
    })

    if (this.hasResultsTarget) {
      this.resultsTarget.hidden = query.length === 0 || visibleCount === 0
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.hidden = query.length === 0 || visibleCount > 0
    }
  }
}
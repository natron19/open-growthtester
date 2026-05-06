import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "input"]

  connect() {
    this.refresh()
  }

  select(event) {
    this.inputTarget.value = event.currentTarget.dataset.value
    this.refresh()
  }

  refresh() {
    const selected = this.inputTarget.value
    this.buttonTargets.forEach(btn => {
      btn.classList.toggle("active", btn.dataset.value === selected)
    })
  }
}

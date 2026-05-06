import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "full"]

  connect() {
    this.fullTarget.hidden = true
  }

  toggle() {
    const expanded = !this.fullTarget.hidden
    this.fullTarget.hidden = expanded
    this.previewTarget.hidden = !expanded
  }
}

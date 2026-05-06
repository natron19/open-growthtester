import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitBtn", "loadingState"]
  static values  = { cancelUrl: String }

  start() {
    this.submitBtnTarget.hidden = true
    this.loadingStateTarget.hidden = false
  }

  cancel() {
    window.location.href = this.cancelUrlValue
  }
}

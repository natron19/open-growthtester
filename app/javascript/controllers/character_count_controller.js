import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter"]
  static values  = { max: Number }

  connect() {
    this.update()
  }

  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.counterTarget.textContent = `${remaining} characters remaining`
    this.counterTarget.classList.toggle("text-danger", remaining < 0)
  }
}

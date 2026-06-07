import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password"
export default class extends Controller {
  static targets = [
    "input",
    "eyeIcon",
    "eyeOffIcon",
  ]

  connect() {
  }

  toggle(){
    if(this.inputTarget.type === "text"){
      this.inputTarget.type = "password"
      this.eyeIconTarget.classList.remove("hidden");
      this.eyeOffIconTarget.classList.add("hidden");
    } else if (this.inputTarget.type === "password") {
      this.inputTarget.type = "text"
      this.eyeIconTarget.classList.add("hidden");
      this.eyeOffIconTarget.classList.remove("hidden");
    }
  }
}

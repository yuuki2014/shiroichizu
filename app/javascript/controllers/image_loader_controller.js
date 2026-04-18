import { Controller } from "@hotwired/stimulus"
import * as Sentry from "@sentry/browser"

// Connects to data-controller="image-loader"
export default class extends Controller {
  static targets = [
    "image",
    "placeholder"
  ]

  connect() {
    this.retried = false; // 画像再読み込みフラグをオフでセット
  }

  // 画像ロード完了後
  loaded() {
    this.imageTarget.classList.remove("opacity-0")
    this.placeholderTarget.classList.add("hidden")
  }

  // 画像ロード失敗時
  error() {
    const originalSrc = this.imageTarget.getAttribute("src") || null // 画像へのリダイレクトリンクを取得

    if (!this.retried) {
      this.retried = true
      this.imageTarget.setAttribute("src", "")

      requestAnimationFrame(() => {
        this.imageTarget.setAttribute("src", originalSrc) // URLを再セットして画像を再読み込み
      })
      return
    }


    Sentry.withScope((scope) => {
      scope.setLevel("warning")
      scope.setTag("feature", "image_loader")
      scope.setTag("event_type", "image_load_error")
      scope.setTag("retried", "true")

      scope.setContext("image_loader", {
        src: originalSrc,
        currentSrc: this.imageTarget.currentSrc || null,
        alt: this.imageTarget.getAttribute("alt") || null,
        complete: this.imageTarget.complete,
        naturalWidth: this.imageTarget.naturalWidth || 0,
        naturalHeight: this.imageTarget.naturalHeight || 0
      })

      Sentry.captureMessage("画像読み込みに失敗しました")
    })

    this.placeholderTarget.classList.remove("opacity-0")
    this.placeholderTarget.innerHTML = `
      <span
        class="block text-center leading-tight text-gray-500 font-medium px-2 break-words"
        style="font-size: clamp(10px, 9cqw, 14px);"
      >
        画像を表示できませんでした
      </span>
    `
  }
}

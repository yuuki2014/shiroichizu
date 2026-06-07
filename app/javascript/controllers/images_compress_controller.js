import { Controller } from "@hotwired/stimulus"
import Compressor from 'compressorjs'
import * as Sentry from "@sentry/browser"

const QUALITY    = 0.85; // 画質 0-1
const MAX_WIDTH  = 1600; // 最大幅
const MAX_HEIGHT = 1600; // 最大高さ
const MAX_IMAGES_COUNT = 6;

// Connects to data-controller="images-compress"
export default class extends Controller {
  static targets = ["input", "preview", "defaultIcon"]

  connect() {
    this.currentFiles = [];
    this.isWebpSupported = this.checkWebpSupport(); // ブラウザがWebPエンコードに対応しているかチェック
  }

  // WebP書き出しに対応しているか判定
  checkWebpSupport() {
    const canvas = document.createElement('canvas');
    if (canvas.getContext && canvas.getContext('2d')) {
      // 実際にWebPを指定してデータURLを生成し、WebPとして生成されたか確認
      return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
    }
    return false;
  }

  async compress(event) {
    const files = Array.from(event.target.files);
    const dataTransfer = new DataTransfer();

    // 添付画像がないときは、既存のファイルを保持してreturn
    if (files.length === 0) {
      if(this.currentFiles.length > 0){
        this.currentFiles.forEach(file => {
          dataTransfer.items.add(file);
        })
        this.inputTarget.files = dataTransfer.files;
      }
      return;
    }

    // 画像以外の時ははじく
    for (const file of files){
      if (!file.type.startsWith('image/')){
        alert('画像ファイルを選択してください')
        event.target.value = '';
        if(this.currentFiles.length > 0){
          this.currentFiles.forEach(file => {
            dataTransfer.items.add(file);
          })
          this.inputTarget.files = dataTransfer.files;
        }
        return;
      }
    }

    // 画像枚数制限
    if (files.length + this.currentFiles.length > MAX_IMAGES_COUNT){
      alert(`画像の添付は${MAX_IMAGES_COUNT}枚までとなっています`);
      event.target.value = '';
      if(this.currentFiles.length > 0){
        this.currentFiles.forEach(file => {
          dataTransfer.items.add(file);
        })
        this.inputTarget.files = dataTransfer.files;
      }
      return;
    }

    // 画像を圧縮
    const results = await Promise.allSettled(
      files.map(file => this.compressImages(file))
    )

    const successItems = results.filter(r => r.status === "fulfilled").map(r => r.value); // 圧縮が成功した画像で新たな配列を作成
    const failedItems = results.filter(r => r.status === "rejected").map(r => r.reason); // 圧縮が失敗した画像で新たな配列を作成

    // 圧縮成功画像をcurrentFilesに追加
    successItems.forEach(file => {
      this.currentFiles.push(file);
    })

    // currentFilesで送信用データを作成
    this.currentFiles.forEach(file => {
      dataTransfer.items.add(file);
    })

    this.inputTarget.files = dataTransfer.files; // inputに送信用データをセット
    this.renderPreview(successItems); // 追加した画像を画面に表示

    if (failedItems.length > 0) {
      alert("一部の画像の圧縮に失敗しました")
    }
  }

  compressImages(file){
    const targetMimeType = this.isWebpSupported ? 'image/webp' : 'image/jpeg';
    const targetExtension = this.isWebpSupported ? '.webp' : '.jpeg';

    return new Promise((resolve, reject) => {
      new Compressor(file, {
        quality: QUALITY,
        maxWidth: MAX_WIDTH,
        maxHeight: MAX_HEIGHT,
        mimeType: targetMimeType,
        success: (result) => {
          const uniqueId = Date.now().toString(36) + Math.random().toString(36).slice(2, 7); // ランダムなIDを生成
          const newFileName = `${uniqueId}${targetExtension}`;
          const newFile = new File([result], newFileName, { type: targetMimeType });
          newFile.uniqueId = uniqueId; // IDを付与

          resolve(newFile);

          console.log(`圧縮成功(${targetMimeType}): ${(result.size / 1024).toFixed(2)} KB`);
        },
        error: (err) => {
          console.log("画像圧縮エラー:", err.message);

          Sentry.withScope((scope) => {
            scope.setLevel("warning")
            scope.setTag("feature", "image_compress")
            scope.setTag("event_type", "image_compress_error")

            scope.setContext("compress", {
              original_name: file.name,
              original_type: file.type,
              original_size: file.size,
              target_mime_type: targetMimeType,
              webp_supported: this.isWebpSupported
            })
            Sentry.captureException(err)
          })

          reject(err);
        }
      })
    })
  }

  renderPreview(successItems){
    if(successItems.length === 0) return;

    // デフォルトアイコンを非表示
    if (this.hasDefaultIconTarget) {
      this.defaultIconTarget.classList.add('hidden');
    }

    if (this.hasPreviewTarget) {
      successItems.forEach(file => {
        // 画像を画面に表示
        const url = URL.createObjectURL(file);

        const div = document.createElement("div");
        div.className = "aspect-square w-full rounded-lg flex items-center justify-center relative overflow-hidden";

        const img = document.createElement("img");
        img.src = url;
        img.className = "w-full h-full object-cover rounded-lg";

        const button = document.createElement("button");
        button.type = "button";
        button.className = "absolute -top-0 -right-0 rounded-full text-white hover:text-gray-400 shadow border border-gray-200 p-2 z-10 w-8 h-8 flex items-center justify-center opacity-80 bg-gray-600";

        button.setAttribute("data-action", "click->images-compress#removePreview");
        button.setAttribute("data-file-id", file.uniqueId);

        button.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4">
            <path d="M18 6 6 18"></path>
            <path d="m6 6 12 12"></path>
          </svg>
        `;

        div.appendChild(img);
        div.appendChild(button);
        this.previewTarget.appendChild(div);
      });
    }
  }

  // 削除ボタンを押した時の処理
  removePreview(event){
    event.preventDefault();
    const button = event.currentTarget;
    const targetId = button.getAttribute("data-file-id"); // ターゲットのidを取得
    const img = button.parentElement.querySelector("img");

    button.parentElement.remove(); // ターゲットの画像要素を削除
    URL.revokeObjectURL(img.src) // メモリ上のBlobデータへの参照を切る

    // targetId以外のものだけ残す
    this.currentFiles = this.currentFiles.filter(file => file.uniqueId !== targetId);

    // 残った画像を送信用に再びセットし直す
    const dataTransfer = new DataTransfer();
    this.currentFiles.forEach(file => dataTransfer.items.add(file));
    this.inputTarget.files = dataTransfer.files

    // デフォルトアイコンを表示
    if (this.hasDefaultIconTarget && (this.currentFiles.length === 0)) {
      this.defaultIconTarget.classList.remove('hidden');
    }
  }

  countCheck(event){
    if(this.currentFiles.length >= 6){
      event.preventDefault();
      alert("画像添付は6枚までとなっています")
      return
    }
  }
}

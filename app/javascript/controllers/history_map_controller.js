import BaseMapController from "./base_map_controller.js"
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import ngeohash from 'ngeohash'

// Connects to data-controller="history-map"
export default class extends BaseMapController {
  static values = { ...BaseMapController.values,
                    visitedGeohashes: Array,
                  }

  async connect(_element) {
    super.connect(); // base mapのconnectを実行

    await this.initVisitedGeohashes();

    // 中央位置設定
    if(this.longitudeValue && this.latitudeValue){
      this.center = [ this.longitudeValue, this.latitudeValue ]
    } else {
      this.center = [ 139.745, 35.658 ];
    }

    // 地図初期化
    await this.initializeMap(this.center)

    if (!this.map) return;

    this.fitToVisitedArea();

    // アトリビューション表記
    this.map.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-right");

    // 非表示にする地図上の情報
    const toHide = [
    ];

    // 地図の読み込みが終わった後に実行
    this.map.on('load', () => {
      // 霧を初期化
      this.fogInit();
      this.setupCustomFogLayerEvents();

      this.updateCustomFogLayer();

      this.addMarkers();

      this.mapInitEnd = true;
      this.maybeClearOverlay();
    })
  }

  async initVisitedGeohashes(){
    this.visitedGeohashes = new Set();
    console.log(window.location.pathname.slice(1))
    if (String(window.location.pathname.slice(1)) === "my_map"){
      await this.setCumulativeGeohashesAndFeature(this.visitedGeohashes);
    } else {
      this.generateFeatureFromGeohashes(this.visitedGeohashesValue, this.visitedGeohashes);
    }
  }

  getFogConfig() {
    return {
      opacity: 0.6,
      color: [26/255, 38/255, 52/255]
    };
  }

  clearMapOverlay(){
    if (!this.hasMapOverlayTarget) return;

    const el = this.mapOverlayTarget

    const removeOverlay = () => {
      if (el.isConnected) el.remove();
    };

    const fallbackTimer = setTimeout(removeOverlay, 5000);

    el.addEventListener("transitionend", () => {
      clearTimeout(fallbackTimer);
      removeOverlay();
    }, { once: true })

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        el.classList.add("-translate-y-full");
      });
    });
  }

  maybeClearOverlay(){
    if (!this.mapInitEnd)          return; // まだ地図が初期化されてない
    if (!this.hasMapOverlayTarget) return; // まだ overlay target がない
    if (this.clearMapOverlayEnd)   return; // すでにoverlay削除済み

    this.clearMapOverlay();
    this.clearMapOverlayEnd = true;
  }

  // mapOverlayが接続された時に自動実行
  mapOverlayTargetConnected(_element) {
    this.maybeClearOverlay();
  }

  setupCustomFogLayerEvents() {
    // moveendとzoomendの両方で実行
    const updateEvents = ["moveend", "zoomend"];

    updateEvents.forEach(eventType => {
      this.map.on(eventType, () => {
        // カスタムレイヤーが存在し、かつ表示中であれば更新する
        if (this.fogCustomLayer && this.visitedGeohashes?.size > 0) {
          this.updateCustomFogLayer();
        }
      });
    });
  }

  // 地図の全体が映るようにカメラを設定
  fitToVisitedArea() {
    if (!this.visitedGeohashes || this.visitedGeohashes.size === 0) return;

    let minLat = Infinity, minLng = Infinity;
    let maxLat = -Infinity, maxLng = -Infinity;

    // すべてのGeohashを走査して外郭を探す
    this.visitedGeohashes.forEach(hash => {
      const bbox = ngeohash.decode_bbox(hash); // [s, w, n, e]

      if (bbox[0] < minLat) minLat = bbox[0];
      if (bbox[1] < minLng) minLng = bbox[1];
      if (bbox[2] > maxLat) maxLat = bbox[2];
      if (bbox[3] > maxLng) maxLng = bbox[3];
    });

    // MapLibreのfitBoundsに渡す
    this.map.fitBounds(
      [[minLng, minLat], [maxLng, maxLat]],
      {
        padding: 50,
        duration: 0,
        bearing: 0,
        pitch: 0,
        essential: true
      }
    );
  }
}

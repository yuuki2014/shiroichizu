import { Controller } from "@hotwired/stimulus"
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import ngeohash from 'ngeohash';
import { get, post } from "@rails/request.js"
import { Protocol } from "pmtiles";
import * as Sentry from "@sentry/browser";
import { STATUS } from "../constants/status";

// 定数定義
const INITIAL_ZOOM_LEVEL = 17;    // 初期のズームレベル

// Connects to data-controller="base-map"
export default class extends Controller {
  static styleJsonCache = null;
  static outlets = [ "ui", "posts" ]
  static targets = [ "mapOverlay", "appendMarker", "iconReady" ]
  static values = { longitude: Number,
                    latitude: Number,
                    posts: Array,
                    postsUrl: String,
                  }

  connect(_element) {
    console.log("base mapのconnect実行")
    // 初期化
    this.mapInitEnd = false; // 初期化終了フラグ
    this.clearMapOverlayEnd = false; // 初期のマップオーバーレイクリアフラグ
    this.isPostModeActive = false; // 投稿モードの状態管理変数を定義
    this.mapLoadedOnce = false; // 地図読み込み完了フラグ
    this.markers = {}; // マーカーを保存するオブジェクト

    // 前のが残っていた時に備えて最初に消してからアボートコントローラーをセット
    this.ac?.abort();
    const abortController = new AbortController();
    this.ac = abortController;

    // 累計地図をセット
    this.cumulativeGeohashes = new Set();
    this.cumulativeFeature = null;
  }

  disconnect(_element){
    console.log("base map disconnect")

    // アボートでフェッチやイベントリスナーを止める
    this.ac?.abort();
    this.ac = null;
    console.log("アボート:this.ac=",this.ac)

    if (this.map) {
      this.map.remove(); // 地図機能の停止、削除
      this.map = null; // 参照も切る
      console.log("map 消去:", this.map)
    }
  }

  // 地図の初期化
  async initializeMap(center){
    if (!this.ac) return;

    // プロトコル登録
    const protocol = new Protocol();
    maplibregl.addProtocol("pmtiles", protocol.tile);

    const signal = this.ac.signal;

    try {
      // 地図のstyleを取得
      const styleJson = await this.loadStyleJson(signal);

      if (signal.aborted || !this.element.isConnected) return; // もし connect 中に遷移してたらreturn

      this.styleJson = styleJson;
    } catch (error) {
      if (error.name === "AbortError") {
        console.debug("ページ遷移によるエラー", error);
        return;
      }
      console.error("style読み込み時の想定外エラー", error);
      this.styleJson = this.getFallbackStyle();
    }

     // 地図の初期化
    this.map = new maplibregl.Map({
      container: this.element,
      style: this.styleJson,
      center: center,
      zoom: INITIAL_ZOOM_LEVEL,
      maxZoom: 24,
      attributionControl: false,
    });

    // 地図のスタイル、初期ソースのロード完了
    this.map.once("load", async () => {
      this.mapLoadedOnce = true;
      await this.loadIcon(); // アイコン,source,layerの初期設定
      this.loadPosts(); // 投稿データを取得して反映
      this.setuplazyLoadImagesEvent();
      this.setPostsEvents();
    });
    this.map.on("webglcontextrestored", this.handleWebGLContextRestored); // webglコンテキスト消失時にカスタムレイヤーを再設定
    this.map.on("error", this.handleMapError); // 地図読み込み失敗時に、リロードモーダルを表示
  }

  // webglコンテキスト消失時に実行するメソッド
  handleWebGLContextRestored = () => {
    console.warn("WebGL restored! PMTilesの描画完了を待ってから霧を再構築します...");

    this.restoreFogLayerSafely();
  }

  // webglのカスタムレイヤーを再構築
  restoreFogLayerSafely = () => {
    if (!this.map || !this.element.isConnected) return;

    // カスタムレイヤーを追加するためのチェック関数
    const addLayerSafely = () => {
      if (!this.map || !this.element.isConnected) return;

      // 地図の準備が完全に終わっていなければ、完了後に再度実行
      // map.isStyleLoaded(),map.once('styledata', ...)では霧が表示されないので注意
      if (!this.map.loaded()) {
        this.map.once("idle", addLayerSafely);
        return;
      }

      const layerId = "geohash-fog-custom-layer";

      // もしレイヤーが残っていたら削除
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId);
      }

      this.fogInit(); // 霧を再び初期化
      this.updateCustomFogLayer(); // 現在の霧の状態を反映
    };

    addLayerSafely();
  }

  // maplibreのエラー時に実行するメソッド
  handleMapError = (event) => {
    const error = event.error;
    const message = error?.message || "";

    this.mapInitEnd = true;

    console.warn("[map:error]", error);

    const isPmtilesByteServingError =
      message.includes("Server returned no content-length header") ||
      message.includes("content-length") ||
      message.includes("HTTP Byte Serving");

    if (!isPmtilesByteServingError) return;

    // 地図がロード済みなら、一部タイル取得失敗として扱いモーダルは出さない
    if (this.mapLoadedOnce) {
      console.warn("[map:pmtiles-range-error-after-load]", {
        message,
        mapLoaded: this.map?.loaded?.(),
        styleLoaded: this.map?.isStyleLoaded?.()
      })

      return
    }

    this.showMapLoadErrorModal(); // pmtilesをうまく読み込めなかったときだけエラーを表示

    // sentryにエラーを送る
    if (Sentry) {
      Sentry.captureException(error || new Error(message), {
        tags: {
          area: "map",
          source: "maplibre",
          kind: "pmtiles-byte-serving",
        },
        extra: {
          message,
          url: location.href,
          userAgent: navigator.userAgent,
        },
      });
    }
  }

  // stylejsonを読み込む
  async loadStyleJson(signal){
    if(this.constructor.styleJsonCache) {
      console.log("前回のを使用")
      return structuredClone(this.constructor.styleJsonCache); // 前回読み込んだキャッシュが残っていたらそれを返す
    }

    const styleUrl = this.element.dataset.styleUrl;

    try {
      const res = await fetch(styleUrl, { signal: signal });
      if(!res.ok) throw new Error(`fetch失敗: ${res.status}`);

      const styleJson = await res.json();
      this.constructor.styleJsonCache = structuredClone(styleJson);

      return structuredClone(styleJson);
    } catch (error) {
      if (error.name === "AbortError") {
        throw error;
      }
      console.log("style.json の取得失敗", error);
      return this.getFallbackStyle();
    }
  }

  getFallbackStyle() {
    return {
      version: 8,
      sources: {
      },
      layers: [
        {
          id: "background",
          type: "background",
          paint: {
            "background-color": "#1955A6"
          }
        },
      ]
    };
  }

  // 渡されたgeohash配列から、周囲の解放済み部分を計算してセット
  generateFeatureFromGeohashes(visitedGeohashes = [], targetGeohashesSet) {
    if (visitedGeohashes.length === 0) return null;

    // 訪問済みgeohashから周囲の開放するgeohashを重複抜きで取得する
    visitedGeohashes.forEach((geohash) => {
      this.addGeohashesAndGetNew(geohash, targetGeohashesSet)
    });

    return;
  }

  addGeohashesAndGetNew(currentGeohash, visitedGeohashes) {
    if(!currentGeohash) return [];

    const newGeohashes = [];
    const candidates = this.getClearingAreaGeohashes(currentGeohash); // 追加するgeohashの候補を取得

    // 保持していないものを追加
    for (const hash of candidates) {
      if (visitedGeohashes.has(hash)) continue // すでに保持していた場合はスキップ
      visitedGeohashes.add(hash);
      newGeohashes.push(hash);
    }

    return newGeohashes;
  }

  getClearingAreaGeohashes(geohash){
    const candidates = new Set();

    // 現在地自身を追加
    candidates.add(geohash);

    // 現在地の周囲8つのgeohashを取得
    const neighbors = ngeohash.neighbors(geohash);
    neighbors.forEach(hash => candidates.add(hash));

    // 周囲8つのさらに周りのgeohashを取得
    for (const hash of neighbors) {
      const aroundNeighbors = ngeohash.neighbors(hash);
      aroundNeighbors.forEach(hash => candidates.add(hash));
    }

    return candidates;
  }

  // 投稿モードアクティブ
  enablePostPositionMode(){
    if(this.isPostModeActive) return

    if(this.hasPostsOutlet) {
      this.postsOutlet.lngValue = null;
      this.postsOutlet.latValue = null;
    }
    this.currentMarker = null;

    this.map.on('click', this.handlePostMapClick);
    this.isPostModeActive = true;
  }

  // 投稿モード非アクティブ
  disablePostPositionMode(){
    if(!this.isPostModeActive) return;

    if(this.currentMarker) {
      this.currentMarker.remove()
      this.currentMarker = null;
    }
    this.map.off('click', this.handlePostMapClick);
    this.isPostModeActive = false;
  }

  // 投稿モード時にクリックで呼ばれるコールバック関数
  handlePostMapClick = (e) => {
    const{ lng, lat } = e.lngLat;

    if (this.currentMarker) {
      // マーカーがある場合はマーカーの場所を更新
      this.currentMarker.setLngLat([lng, lat]);
    } else {
      // マーカーがない場合は新たにマーカーを作成して地図に追加
      this.currentMarker = new maplibregl.Marker({color: "#00CCFF"})
        .setLngLat([lng, lat])
        .addTo(this.map)
    }
    if(this.hasPostsOutlet) {
      this.postsOutlet.lngValue = lng
      this.postsOutlet.latValue = lat
    }
  }

  clearMapIcon(){
    this.initPostsData();
    this.refreshPostsLayer();
  }

  // デフォルトアイコンの読み込みと初期設定
  async loadIcon() {
    try {
      const image = await this.map.loadImage("/images/default-pin.png");

      if (!this.map.hasImage("default-pin")) {
        this.map.addImage("default-pin", image.data);
      }

      this.addPostsLayer();
    } catch (error) {
      console.error("画像の読み込み、または追加でエラーが発生しました:", error);
    }
  }

  // レイヤーの追加
  addPostsLayer() {
    // ソースの追加
    this.map.addSource('posts', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] }, // 最初は空
      cluster: true,
      clusterMaxZoom: 21, // クラスターを解除するレベル
      clusterRadius: 23,   // クラスターにまとめるピクセル半径
      maxzoom: 24
    });

    // クラスターレイヤー
    this.map.addLayer({
      id: 'clusters',
      type: 'circle',
      source: 'posts',
      filter: ['has', 'point_count'], // クラスターデータのみ対象
      paint: {
        'circle-color': '#F7DAA0', // 円の色
        'circle-radius': 20,       // 円の大きさ
        'circle-stroke-width': 2,
        'circle-stroke-color': '#fff'
      }
    });

    // クラスター内の数字を表示するレイヤー
    this.map.addLayer({
      id: 'cluster-count',
      type: 'symbol',
      source: 'posts',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': '{point_count}', // 件数を表示
        'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
        'text-size': 12
      }
    });

    // 単体の投稿を表示するレイヤー
    this.map.addLayer({
      id: 'unclustered-point',
      type: 'symbol',
      source: 'posts',
      filter: ['!', ['has', 'point_count']], // クラスターではないもの
      layout: {
        'icon-image': [
          'case',
          ['boolean', ['get', 'is_icon_loaded'], false],
          ['get', 'public_uid'], // 画像読み込み完了後はpublic_uid
          'default-pin'          // 読み込み前や画像なしはデフォルト画像
        ],
        'icon-anchor': 'center',  // ピンの位置
        'icon-size': 0.5,
        'icon-allow-overlap': true
      }
    });

    this.initPostsData();
  }

  initPostsData(){
    // postsDataの初期化
    this.postsData = {
      type: "FeatureCollection",
      features: []
    }
  }

  // postsのデータの読み込みと追加
  async loadPosts(){
    const postsJson = await this.getPostsJson();
    if(postsJson) this.addPosts(postsJson);
  }

  // postsデータの取得
  async getPostsJson(){
    const postsUrl = this.postsUrlValue;
    if (!postsUrl) return false;

    try {
      const response = await fetch(postsUrl);

      if (!response.ok) throw new Error(`posts取得エラー: ${response.status}`);

      const result = await response.json();

      return result;
    } catch (error) {
      console.error(error.message)
      return false
    }
  }

  // postsをthis.mapに追加
  addPosts(postsJson){
    this.postsData = postsJson; // インスタンスプロパティに格納
    this.refreshPostsLayer();
  }

  // postsの反映と画像の読み込み
  refreshPostsLayer() {
    if (!this.map) return;

    const source = this.map.getSource('posts');
    if (source) {
      source.setData(this.postsData); // 最新のデータを反映させる

      if (this.lazyLoadImagesScheduled) return;
      this.lazyLoadImagesScheduled = true;
      this.map.once("idle", () => {
        this.lazyLoadImagesScheduled = false;
        this.lazyLoadImages();
      });
    }
  }

  // 画面内の投稿を検知して画像を読み込む
  async lazyLoadImages() {
    if (!this.map || !this.postsData) return;

    // 現在画面内に実際に見えているunclustered-pointのデータをすべて取得
    const features = this.map.queryRenderedFeatures({ layers: ['unclustered-point'] });
    let isDataUpdated = false;

    for (const feature of features) {
      const props = feature.properties;
      const uid = props.public_uid;
      const url = props.icon_url;

      if (!uid || !url) continue;

      // 該当するデータを検索
      let targetFeature = this.postsData.features.find(f => f.properties.public_uid === uid);
      if (!targetFeature) continue;

      // すでにマップに画像自体は登録されているのに、データ側がロード完了になっていない場合
      if (this.map.hasImage(uid)) {
        if (!targetFeature.properties.is_icon_loaded) {
          targetFeature.properties.is_icon_loaded = true;
          isDataUpdated = true; // 再描画するフラグを立てる
        }
        continue;
      }

      // マップに画像が登録されていない場合
      try {
        // 画像を円形に加工して格納
        const imageData = await this.createRoundIcon(url, { size: 100, borderWidth: 2 });

        // 処理中にデータが更新されている可能性があるので、targetFeatureを更新する
        targetFeature = this.postsData.features.find(f => f.properties.public_uid === uid);
        if (!targetFeature) continue;

        // 処理中に、他の処理で既に登録されていないかチェック
        if (!this.map.hasImage(uid)) {
          this.map.addImage(uid, imageData);

          targetFeature.properties.is_icon_loaded = true;
          isDataUpdated = true;
        }
      } catch (error) {
        console.error(`画像の読み込みに失敗、${uid}:`, error);
      }
    }

    // 変更があった場合のみまとめて最新データを反映
    if (isDataUpdated) {
      const source = this.map.getSource('posts');
      if (source) {
        source.setData(this.postsData);
      }
    }
  }

  // 画像を取得
  async loadImageWithCredentials(url) {
    const res = await fetch(url, {
      credentials: "include", // 認可のためのcookieを渡す必要があるので
    });

    if (!res.ok) {
      throw new Error(`画像取得失敗: ${res.status} ${res.statusText}`);
    }

    const blob = await res.blob();

    return await createImageBitmap(blob); // 生データに変換して返す
  }

  // 画像を取得して円形に変換
  async createRoundIcon(url, { size = 64, borderWidth = 4, shadow = true } = {}) {
    const img = await this.loadImageWithCredentials(url);

    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');

    const center = size / 2;
    const shadowPadding = 6;                    // 影がはみ出さないための余白
    const outerRadius = center - shadowPadding; // 白枠の外側の半径
    const bWidth = borderWidth;                 // 白枠の太さ
    const innerRadius = outerRadius - bWidth;   // 画像が収まる内側の半径

    // ドロップシャドウの設定
    if (shadow) {
      ctx.shadowColor = "rgba(0, 0, 0, 0.3)";
      ctx.shadowBlur = shadowPadding;
      ctx.shadowOffsetX = 0;
      ctx.shadowOffsetY = 3;
    }

    // 土台の白い円を塗りつぶし
    ctx.beginPath();
    ctx.arc(center, center, outerRadius, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();

    // これ以降の画像描画に影が乗らないように影の設定をリセット
    ctx.shadowColor = 'transparent';
    ctx.shadowBlur = 0;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 0;

    // 画像を丸型にくり抜くためのクリップ領域を作成
    ctx.save();
    ctx.beginPath();
    ctx.arc(center, center, innerRadius, 0, Math.PI * 2);
    ctx.clip();

    // アスペクト比を維持したセンタークロップの計算
    const imgWidth = img.width;
    const imgHeight = img.height;
    let sx = 0, sy = 0, sw = imgWidth, sh = imgHeight;

    if (imgWidth > imgHeight) {
      // 横長は左右を削る
      sw = imgHeight;
      sx = (imgWidth - imgHeight) / 2;
    } else {
      // 縦長は上下を削る
      sh = imgWidth;
      sy = (imgHeight - imgWidth) / 2;
    }

    // クリップされた円の中に画像を描画
    const x = center - innerRadius;
    const y = center - innerRadius;
    const dSize = innerRadius * 2;
    ctx.drawImage(img, sx, sy, sw, sh, x, y, dSize, dSize);

    // クリップ状態を解除
    ctx.restore();

    return ctx.getImageData(0, 0, size, size);
  }

  // 発火時に画面内の画像を表示するようセット
  setuplazyLoadImagesEvent() {
    const events = ["moveend", "idle"];

    events.forEach(eventType => {
      this.map.on(eventType, () => {
        this.lazyLoadImages();
      });
    });
  }

  // postsのfeatureクリック時のイベントをセット
  setPostsEvents() {
    // 単体の投稿をクリックしたとき
    this.map.on('click', 'unclustered-point', (e) => {
      const coordinates = e.features[0].geometry.coordinates.slice();
      const lng = coordinates[0];
      const lat = coordinates[1];
      const uid = e.features[0].properties.public_uid

      this.openPostPreview({lng, lat, uid});
    });

    // クラスターでまとまった投稿をクリックした時
    this.map.on('click', 'clusters', async (e) => {
      if (!e.features.length) return;

      const [lng, lat] = e.features[0].geometry.coordinates.slice();
      const clusterProperties = e.features[0].properties;
      const clusterId = clusterProperties.cluster_id;   // クラスターのID
      const pointCount = clusterProperties.point_count; // 件数


      // postsからクラスターに属する全ての個別データを引っ張る
      const source = this.map.getSource('posts');
      if (!source) return;

      try {
        // ID,取得件数,オフセット
        const leaves = await source.getClusterLeaves(clusterId, pointCount, 0);
        const uids = leaves.map(leaf => leaf.properties.public_uid);
        this.openPostClusterPreview({lng, lat, uids});
      } catch(error) {
        console.log("クラスター取得エラー:", error)
      }
    });
  }

  // 画面上の投稿を削除
  removePost(uid){
    if(!this.postsData.features) return;

    this.postsData.features = this.postsData.features.filter(f => f.properties.public_uid !== uid);
    this.refreshPostsLayer();
  }

  // postsUrlValueが変更された時に発火
  postsUrlValueChanged(newUrl){
    if(newUrl){
      this.loadPosts();
    }
  }

  // appendMarkerTargetが接続されたときにマップにマーカーを追加
  appendMarkerTargetConnected(element){
    const post = JSON.parse(element.dataset.post)

    this.addSinglePost(post);

    element.remove() // 使い終わったら消す
  }

  // 投稿時に一つだけ追加
  addSinglePost(newPost) {
    if (this.postsData && this.postsData.features) {

      const newFeature = {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [newPost.longitude, newPost.latitude]
        },
        properties: {
          public_uid: newPost.public_uid,
          icon_url: "",
          is_icon_loaded: false
        }
      }

      this.postsData.features.push(newFeature);

      this.refreshPostsLayer();
    }
  }

  // iconReadyTarget追加時に発火
  iconReadyTargetConnected(element) {
    const uid = element.dataset.uid;
    const iconUrl = element.dataset.iconUrl;

    this.updatePostIconUrl(uid, iconUrl);

    element.remove();
  }

  // 対象のpostsDataのicon urlを更新
  updatePostIconUrl(uid, iconUrl) {
    if (!this.postsData?.features) return;

    const feature = this.postsData.features.find(
      f => f.properties.public_uid === uid
    );

    if (!feature) return;

    feature.properties.icon_url = iconUrl;
    feature.properties.is_icon_loaded = false;

    this.refreshPostsLayer();
  }

  // postのプレビューを開く
  openPostPreview({lng = null, lat = null, uid = null} = {}) {
    if (!lng || !lat || !uid) return;

    const moveHeight = window.innerHeight / 4;

    const point = this.map.project([lng, lat]); // マーカーの緯度経度を画面上のピクセル座標に変換
    point.y += moveHeight; // yを移動
    const newCenter = this.map.unproject(point); // ずらしたピクセル座標を緯度軽度に変換

    this.map.easeTo({
      center: newCenter,
      duration: 500,
    });

    get(`/posts/${uid}/preview`, { responseKind: "turbo-stream" });
  }

  openPostClusterPreview({lng = null, lat = null, uids = null} = {}){
    if (!lng || !lat || !uids) return;

    const moveHeight = window.innerHeight / 2.5;

    const point = this.map.project([lng, lat]); // マーカーの緯度経度を画面上のピクセル座標に変換
    point.y += moveHeight; // yを移動
    const newCenter = this.map.unproject(point); // ずらしたピクセル座標を緯度軽度に変換

    this.map.easeTo({
      center: newCenter,
      duration: 500,
    });

    post(`/posts/cluster_preview`, { body: { uids }, responseKind: "turbo-stream" });
  }

  // 霧の初期値データ
  getFogConfig() {
    return {
      opacity: 0.9,
      color: [1.0, 1.0, 1.0]
    };
  }

  // 霧の初期化
  fogInit(){
    const config = this.getFogConfig();

    this.fogCustomLayer = new GeohashFogCustomLayer({
      id: "geohash-fog-custom-layer",
      opacity: config.opacity,
      color: config.color
    });

    if (!this.map.getLayer('geohash-fog-custom-layer')) {
      this.map.addLayer(this.fogCustomLayer);
    }
  }

  // 霧の更新
  updateFog(geojsonData){
    if(!this.map.getSource('fog')){
      this.fogInit();
    }

    const source = this.map.getSource(`fog`);
    source.setData(geojsonData);
  }

  updateCustomFogLayer() {
    if (!this.fogCustomLayer) return

    let visibleHashes = this.getVisibleClearedGeohashes(); // 解放済みのgeohashを取得

    // 停止モードの時はvisibleHashesを現在地周辺のみにする
    // webglコンテキストロスト時に、visitedGeohashが存在しないため、currentGeohashから再計算
    if (this.currentGeohash && this.status === STATUS.STOPPED) {
      const currentGeohashes = Array.from(this.getClearingAreaGeohashes(this.currentGeohash));
      visibleHashes = currentGeohashes;
    }

    this.fogCustomLayer.setHashes(visibleHashes); // カスタムレイヤーにgeohashをセット
    this.map.triggerRepaint(); // 地図を再描画
  }

  setFogOpacity(opacity){
    if (this.fogCustomLayer) {
      this.fogCustomLayer.opacity = opacity;
      this.map.triggerRepaint(); // 再描画
    }
  }

  // 累計地図セット
  setCumulativeGeohashesAndFeature(cumulativeGeohashes){
    if(this.cumulativeModeStatus === "loading" || this.cumulativeModeStatus === "isReady") return;
    this.cumulativeModeStatus = "loading"

    return fetch("/api/v1/my_map", { signal: this.ac.signal })
      .then(res => {
        if(!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => {
        if (this.ac.signal.aborted || !this.element.isConnected) return;

        this.generateFeatureFromGeohashes(data.geohashes, cumulativeGeohashes);

        this.cumulativeModeStatus = "isReady"
      })
      .catch((e) => {
        this.cumulativeModeStatus = "notReady"
        this.uiOutlet.disableCumulative();
        if (e.name == "AbortError") {
          console.debug("ページ遷移によるエラー", e);
          return;
        }
        console.error(e);
      });
  }

  // 解放ずみgeohashを取得
  getVisibleClearedGeohashes() {
    if (!this.map) return []

    const merged = new Set()

    if (this.cumulativeMode && this.cumulativeGeohashes) {
      this.cumulativeGeohashes.forEach(hash => merged.add(hash))
    }

    if (this.visitedGeohashes) {
      this.visitedGeohashes.forEach(hash => merged.add(hash))
    }

    return Array.from(merged)
  }

  // 現在の描画範囲内のgeohashを返す（現在未使用）
  filterVisibleGeohashes(geohashes) {
    const bounds = this.map.getBounds() // 現在の表示範囲を取得

    const west = bounds.getWest()
    const east = bounds.getEast()
    const south = bounds.getSouth()
    const north = bounds.getNorth()

    return Array.from(geohashes).filter(hash => {
      const bbox = ngeohash.decode_bbox(hash)

      const minLat = bbox[0]
      const minLng = bbox[1]
      const maxLat = bbox[2]
      const maxLng = bbox[3]

      return !(
        maxLng < west ||
        minLng > east ||
        maxLat < south ||
        minLat > north
      )
    })
  }

  setFogColor(r, g, b) {
    if (this.fogCustomLayer) {
      this.fogCustomLayer.color = [r / 255, g / 255, b / 255];
      this.map.triggerRepaint();
    }
  }

  // マップ読み込みエラー時のモーダル表示
  showMapLoadErrorModal() {
    const container = document.getElementById("modal-container");
    if (!container) return;

    const modal = document.createElement("div");
    modal.className = "fixed inset-0 h-full pointer-events-none w-full z-40 flex justify-center items-center opacity-0 transition-all duration-300 p-10";
    modal.dataset.controller = "modal";

    modal.innerHTML = `
      <div
        class="modal-backdrop absolute inset-0 bg-black/50 z-0 pointer-events-auto"
        data-action="click->modal#close"
      ></div>

      <div
        class="relative max-w-sm pointer-events-auto modal-box max-h-[90vh] w-full bg-[#fff9d6] p-4 gap-3 flex flex-col items-center rounded-[20px] z-10 transition-all duration-500 ease-out shadow-xl translate-y-40 opacity-0"
        data-modal-target="modalBox"
      >
        <button
          type="button"
          class="absolute right-2 top-2 h-6 w-6 flex items-center justify-center leading-none bg-gray-500/50 rounded-full z-30"
          data-action="click->modal#close"
          aria-label="閉じる"
        >
          ×
        </button>
        <div class="modal-header shrink-0 z-20">
          <div class="text-lg font-bold">
            地図の読み込みに失敗しました
          </div>
        </div>

        <div class="modal-body w-full flex-1 min-h-0 px-4 z-20 overflow-y-auto overscroll-contain text-sm leading-relaxed">
          <p>
            地図データの読み込みに失敗しました。通信状況を確認して、ページを再読み込みしてください。
          </p>

          <div class="mt-4 flex justify-center">
            <button
              type="button"
              class="map-error-reload-button rounded-full bg-orange-400 px-4 py-2 text-white font-bold shadow"
            >
              再読み込み
            </button>
          </div>
        </div>
      </div>
    `;

    container.appendChild(modal);

    const reloadButton = modal.querySelector(".map-error-reload-button");
    reloadButton?.addEventListener("click", () => {
      window.location.reload();
    });
  }
}

// WebGLを使ったカスタムレイヤー用のクラス
class GeohashFogCustomLayer {
  constructor({ id = "geohash-fog-custom-layer", opacity = 0.65, color = [1.0, 1.0, 1.0] } = {}) {
    this.id = id;
    this.type = "custom";
    this.renderingMode = "2d";

    this.visible = true;
    this.opacity = opacity;
    this.color = color;
    this.hashes = [];
    this.vertexData = new Float32Array([]);

    // アンカー座標（メルカトル座標系）
    this.anchor = { x: 0, y: 0 };

    // WebGLリソース
    this.gl = null;
    this.cellProgram = null;
    this.fogProgram = null;
    this.cellBuffer = null;
    this.fullscreenBuffer = null;
  }

  // 表示するGeohashを更新し、頂点バッファを再構築する
  setHashes(hashes) {
    this.hashes = hashes || [];

    // アンカーの設定
    // 描画対象がある場合、最初のGeohashの中心付近を基準点にする。高ズーム時でも頂点座標の有効桁数が保たれる
    if (this.hashes.length > 0) {
      const firstBbox = ngeohash.decode_bbox(this.hashes[0]);
      const center = maplibregl.MercatorCoordinate.fromLngLat({
        lng: (firstBbox[1] + firstBbox[3]) / 2,
        lat: (firstBbox[0] + firstBbox[2]) / 2
      });
      this.anchor.x = center.x;
      this.anchor.y = center.y;
    }

    // 頂点データの構築
    this.vertexData = this.buildVertexData(this.hashes);

    // GPUバッファの更新
    this.uploadCellBuffer();
  }

  // Geohashの配列を三角形ポリゴンの頂点配列に変換。座標は this.anchor からの相対値として計算
  buildVertexData(hashes) {
    const vertices = [];

    for (const hash of hashes) {
      const bbox = ngeohash.decode_bbox(hash);

      // メルカトル座標を取得
      const p1 = maplibregl.MercatorCoordinate.fromLngLat({ lng: bbox[1], lat: bbox[0] });
      const p2 = maplibregl.MercatorCoordinate.fromLngLat({ lng: bbox[3], lat: bbox[0] });
      const p3 = maplibregl.MercatorCoordinate.fromLngLat({ lng: bbox[3], lat: bbox[2] });
      const p4 = maplibregl.MercatorCoordinate.fromLngLat({ lng: bbox[1], lat: bbox[2] });

      // アンカーからの差分を計算
      const x1 = p1.x - this.anchor.x, y1 = p1.y - this.anchor.y;
      const x2 = p2.x - this.anchor.x, y2 = p2.y - this.anchor.y;
      const x3 = p3.x - this.anchor.x, y3 = p3.y - this.anchor.y;
      const x4 = p4.x - this.anchor.x, y4 = p4.y - this.anchor.y;

      // 1つのGeohash(四角形)を2つの三角形に分割
      vertices.push(
        x1, y1,
        x2, y2,
        x3, y3,

        x1, y1,
        x3, y3,
        x4, y4,
      );
    }

    return new Float32Array(vertices);
  }

  // レイヤーがマップに追加された時の初期化処理
  onAdd(map, gl) {
    this.map = map;
    this.gl = gl;

    // セル描画用プログラム（stencil用）
    this.cellProgram = this.createProgram(
      gl,
      `
        precision highp float;
        attribute vec2 a_pos;
        uniform mat4 u_matrix;
        void main() {
          gl_Position = u_matrix * vec4(a_pos, 0.0, 1.0);
        }
      `,
      `
        precision highp float;
        void main() {
          gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
        }
      `
    );

    // 画面全体を覆う霧用プログラム
    this.fogProgram = this.createProgram(
      gl,
      `
        precision highp float;
        attribute vec2 a_pos;
        void main() {
          gl_Position = vec4(a_pos, 0.0, 1.0);
        }
      `,
      `
        precision highp float;
        uniform float u_opacity;
        uniform vec3 u_color;

        void main() {
          gl_FragColor = vec4(u_color * u_opacity, u_opacity);
        }
      `
    );

    this.cellBuffer = gl.createBuffer();

    // フルスクリーン描画用の四角形バッファ
    this.fullscreenBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.fullscreenBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([
        -1, -1,  1, -1,  1,  1,
        -1, -1,  1,  1, -1,  1,
      ]),
      gl.STATIC_DRAW
    );
  }

  uploadCellBuffer() {
    if (!this.gl || !this.cellBuffer) return;

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.cellBuffer);
    this.gl.bufferData(this.gl.ARRAY_BUFFER, this.vertexData, this.gl.DYNAMIC_DRAW);
  }

  // 毎フレームの描画処理
  render(gl, args) {
    if (!this.cellProgram || !this.fogProgram || !this.visible) return;

    // MapLibreの行列(4x4)をコピーして修正を加える
    const matrix = [...args.defaultProjectionData.mainMatrix];

    // 行列に対して、アンカー分の移動を適用。相対座標で計算された頂点が正しい位置にレンダリングされる
    this.translateMatrix(matrix, this.anchor.x, this.anchor.y);

    // ステンシルマスクを「書き込み許可」にする.gl.clear(gl.STENCIL_BUFFER_BIT) が効かない場合があるから
    gl.stencilMask(0xff);

    // 深度テストとブレンドの設定
    gl.disable(gl.DEPTH_TEST); // 霧が地図の下に隠れないようにする
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // ステンシルバッファを完全にクリア
    gl.enable(gl.STENCIL_TEST);
    gl.clearStencil(0);
    gl.clear(gl.STENCIL_BUFFER_BIT);

    // 晴れている場所をステンシルに記録
    gl.colorMask(false, false, false, false);
    gl.stencilFunc(gl.ALWAYS, 1, 0xff);
    gl.stencilOp(gl.KEEP, gl.KEEP, gl.REPLACE);

    gl.useProgram(this.cellProgram);
    const matrixLocation = gl.getUniformLocation(this.cellProgram, "u_matrix");
    gl.uniformMatrix4fv(matrixLocation, false, matrix);

    gl.bindBuffer(gl.ARRAY_BUFFER, this.cellBuffer);
    const cellPosLocation = gl.getAttribLocation(this.cellProgram, "a_pos");
    gl.enableVertexAttribArray(cellPosLocation);
    gl.vertexAttribPointer(cellPosLocation, 2, gl.FLOAT, false, 0, 0);

    const cellVertexCount = this.vertexData.length / 2;
    if (cellVertexCount > 0) {
      gl.drawArrays(gl.TRIANGLES, 0, cellVertexCount);
    }

    // ステンシルが1以外の場所に霧を塗る
    gl.colorMask(true, true, true, true);
    gl.stencilFunc(gl.NOTEQUAL, 1, 0xff);
    gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP);

    gl.useProgram(this.fogProgram);

    const opacityLocation = gl.getUniformLocation(this.fogProgram, "u_opacity");
    gl.uniform1f(opacityLocation, this.opacity);

    const colorLocation = gl.getUniformLocation(this.fogProgram, "u_color")
    gl.uniform3f(colorLocation, this.color[0], this.color[1], this.color[2])

    gl.bindBuffer(gl.ARRAY_BUFFER, this.fullscreenBuffer);
    const fogPosLocation = gl.getAttribLocation(this.fogProgram, "a_pos");
    gl.enableVertexAttribArray(fogPosLocation);
    gl.vertexAttribPointer(fogPosLocation, 2, gl.FLOAT, false, 0, 0);

    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // 後片付けMapLibreの次のレイヤー描画に影響を与えないため
    gl.disable(gl.STENCIL_TEST);
    gl.stencilMask(0x00); // ステンシル書き込みを禁止に戻す
  }

  // 4x4 行列（列優先配列）に平行移動を適用するヘルパー
  translateMatrix(m, tx, ty) {
    // 列優先(column-major)行列の移動成分(m12, m13, m14, m15)を更新
    m[12] = m[0] * tx + m[4] * ty + m[12];
    m[13] = m[1] * tx + m[5] * ty + m[13];
    m[14] = m[2] * tx + m[6] * ty + m[14];
    m[15] = m[3] * tx + m[7] * ty + m[15];
  }

  createShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const error = gl.getShaderInfoLog(shader);
      gl.deleteShader(shader);
      throw new Error(error);
    }
    return shader;
  }

  createProgram(gl, vertexSource, fragmentSource) {
    const vertexShader = this.createShader(gl, gl.VERTEX_SHADER, vertexSource);
    const fragmentShader = this.createShader(gl, gl.FRAGMENT_SHADER, fragmentSource);
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      const error = gl.getProgramInfoLog(program);
      gl.deleteProgram(program);
      throw new Error(error);
    }
    return program;
  }

  // 削除時の動作
  onRemove(map, gl) {
    if (!gl.isContextLost?.()) {
      if (this.cellBuffer) gl.deleteBuffer(this.cellBuffer);
      if (this.fullscreenBuffer) gl.deleteBuffer(this.fullscreenBuffer);
      if (this.cellProgram) gl.deleteProgram(this.cellProgram);
      if (this.fogProgram) gl.deleteProgram(this.fogProgram);
    }

    this.cellBuffer = null;
    this.fullscreenBuffer = null;
    this.cellProgram = null;
    this.fogProgram = null;
    this.gl = null;
    this.map = null;
  }
}

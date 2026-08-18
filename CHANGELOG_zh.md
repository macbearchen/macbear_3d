[English](CHANGELOG.md) | [繁體中文](CHANGELOG_zh.md)

## 0.10.0
#### 2026-08-18
* 新增功能 (Add):
  * **聚光燈支援 (Spotlight)**：新增 `M3SpotLight`，支援錐體角度（內外切角範圍）、方向性衰減計算以及與 GLSL 著色器集成（`LightFS.es3.glsl`）。
  * **地形 LOD 與邊界縫合**：實作地形瓦片細節層級 (LOD 32x32 -> 16x16 -> 8x8 -> 4x4) 支援，並提供邊界縫合處理以防止相鄰不同解析度瓦片之間的裂縫。

* 優化與重構 (Optimize / Refactor):
  * **Flutter 升級**：升級相容至 Flutter 3.47.0。

## 0.9.4
#### 2026-08-01
* 新增功能 (Add):
  * **瓦片地形系統 (Tiled Terrain)**：新增 `M3TerrainTileGeom` 與 `M3TiledTerrain` 支援分區瓦片地形渲染與管理。
  * **高度場與線條幾何**：新增 `M3HeightField.fromHeightmap` 建構式與自訂線條繪製類別 `M3LineGeom`。
  * **渲染統計數據更新**：更新 `M3RenderStats` 結構，移除 `culls` 欄位並新增 `submeshes` 欄位以精確追蹤繪製的子網格數量。

* 優化與重構 (Optimize / Refactor):
  * **M3View 卸載與重新掛載 (Unmount/Remount)**：解耦視圖與引擎單例生命週期，新增 `unmount()` 與 `remount()` 方法，支援視圖安全切換而不破壞 ANGLE/GL 上下文。
  * **幾何形狀建構式優化**：改進 `M3CylinderGeom` 與 `M3CapsuleGeom` 的建構式參數配置。
  * **子網格世界包圍盒**：新增 `subMeshes.worldBounding` 世界坐標包圍盒計算。
  * **地形系統重組**：使用 `package:image` 重構高度圖載入機制，將地形幾何相關檔案重組至 `lib/src/geom/terrain/`。
  * **Android KGP 修復**：修復 Android 建構時 Kotlin Gradle Plugin (KGP) 的相容性警告。

## 0.9.3
#### 2026-07-15
* 新增功能 (Add):
  * **控制台日誌工具 (M3Log)**：在 `lib/src/util/log.dart` 中新增 `M3Log` 工具類別，支援結構化且具 ANSI 顏色的 debug、info、warning、error、system 與 highlight 日誌輸出。

* 優化與重構 (Optimize / Refactor):
  * **著色器與光照衰減優化**：在著色器中直接使用距離與半徑的平方進行衰減計算（採用 UE4 的 windowed inverse-square 衰減公式），避免昂貴的平方根計算。
  * **點光源數據封裝**：點光源的影響範圍（range）現在會先在 Dart 端進行平方運算，然後作為光源位置向量的 `w` 分量傳送給 GPU。
  * **陰影渲染增強**：改進 `TexturedLighting` 片段著色器中的陰影混合邏輯，基於 `ComputeShadowLitFactor` 線性混合有陰影（unlit）與無陰影（lit）狀態，取代原先的二值切換。
  * **光源輔助線重構**：在視覺化輔助工具中，將點光源燈泡渲染（`drawBulb`）與範圍球渲染（`drawHelper`）進行分離。
  * **點光源計算更新**：更新 `LightFS` 中的點光源計算，使其接收明確的位置與法向量，並處理物體空間的縮放調整（`uInvObjScale`）。

## 0.9.2
#### 2026-07-04
* 新增功能 (Add):
  * **Swift Package Manager (SPM) 支援**：為 iOS 和 macOS 建置新增了 SPM 整合支援。
  * **Framebuffer DEPTH24_STENCIL8 支援**：配置了 renderbuffer 和 depth 紋理的建立，以使用正確的 `DEPTH_STENCIL_ATTACHMENT` 支援深度與模板格式。

* 更新與重構 (Update / Refactor):
  * **光源系統重構**：重構 `M3Light` 和 `M3DirectionalLight`，使用內部的 `viewer`（`M3Camera`）委派，而非直接繼承自 `M3Camera`。
  * **程式碼結構重組**：將渲染相關的檔案（`framebuffer.dart`, `render_engine.dart`, `render_options.dart`, `shadow_map.dart`）統一移至 `lib/src/renderer/` 目錄下。
  * **物理與剛體更新**：新增了 `removeRigidBody` 方法，並更新了 `rapier_physics` 依賴套件的版本。
  * **範例與 UI 優化**：將光源旋轉更新集中到 `DemoScene.update` 中，使用互動式 UI 更新了 3D 文字範例，並使用 `SafeArea` 優化了 UI 版面配置。
  * **WebGL 紋理回退方案**：新增了 ASTC 紋理壓縮支援檢查，並在不支援的網頁環境下自動回退至棋盤格紋理。

## 0.9.1
#### 2026-06-19
* 新增功能 (Add):
  * **模組化著色器系統**：重構著色器管線，使用 `.glsl` 副檔名（例如 `PixelFS.es3.glsl`, `SkinningVS.es3.glsl`）。新增著色器原始檔 `FogFS.es3.glsl`, `ShadowFS.es3.glsl` 與 `ShadowVS.es3.glsl`。
  * **著色器程式封裝**：引入專用且型別安全的 Dart 包裝器（位於 `lib/src/program/shader/` 下的 `M3FogShader`, `M3LightingShader`, `M3ShadowShader` 與 `M3WaterShader`），用以封裝 WebGL uniform 變數綁定與初始化邏輯。
  * **程序化紋理**：使用脊狀柏林雜訊與定義域扭曲，新增在執行期建立高品質無縫拼接水面法線貼圖的功能（`M3Texture.createWaterNormalMap`）。
  * **地形高度圖支援**：為 `M3TerrainGeom` 新增了 `fromHeightmapImage` 和 `fromHeightmapAsset` 工廠方法。支援載入 16 位元灰階 PNG 高度圖（包含自定義 IHDR 解析）以進行精確的地形生成，同時也支援標準的 8 位元 RGBA 高度圖。使用雙線性插值實現平滑的高度過渡。
  * **霧化效果**：引入 `M3Fog`，支援面向相機的深度霧、可配置的霧氣顏色，以及自定義的裁剪平面計算（例如用於水下渲染）（`lib/src/scene/fog.dart`）。
  * **網頁版 Rapier 物理**：將 `rapier.js` 和 `rapier_ffi.wasm` 新增至範例網頁目錄，以修復物理範例的網頁建置問題。
  * **範例更新**：新增了展示高解析度 16 位元高度圖與程序化生成的全新地形高度圖範例 `06_terrain.dart`。更新了 `main_all.dart` 和其他範例以整合與清理新功能。

* 更新功能 (Update):
  * **著色器編譯連結**：更新了 `shader_builder.dart` 並為新的 `.glsl` 著色器重新生成了 Dart 綁定程式碼（`.g.dart`）。
  * **GPU 程式重構**：將 GLSL 編譯和 uniform 設置邏輯委派給新的著色器程式包裝器，從而精簡了 `ProgramLighting`, `ProgramShadowMap` 和 `ProgramWater`。
  * **水面效果**：透過 Alpha 混合、自定義切線空間 TBN 矩陣計算（`setTBN`）以及改進的水下霧氣深度著色（使用自定義裁剪平面）增強了水面渲染。
  * **平面反射**：為反射和折射通道新增了可自定義的渲染縮放比（`setRenderScale`）以優化效能，並統一了斜向裁剪平面的計算。
  * **UML 生成工具**：更新了 `gen_uml.sh`，暫時註解掉會導致舊版分析器工具在生成類別圖時當機的註解。

## 0.9.0 <small>(2026-05-24)</small>

* 新增功能 (Add):
  * **水面效果**：引入了 `M3Water`，支援動畫雙層法線貼圖流動、平面反射與折射、霧氣深度水下著色以及可配置的波紋扭曲（`lib/src/scene/water.dart`）。
  * **水面著色器**：新增 ES3 著色器 `Water.es3.frag` / `Water.es3.vert` 並生成 Dart 綁定（`Water.es3.frag.g.dart`, `Water.es3.vert.g.dart`）。
  * **ProgramWater**：用於水面渲染的專用 GPU 程式（`lib/src/program/program_water.dart`）。
  * **RenderContext**：新增 `M3RenderContext` 抽象層，將每訊框的 GPU 狀態（視口、矩陣、光源、陰影貼圖、反射/水面目標）打包在一起，以提供更簡潔的渲染通道寫作（`lib/src/renderer/render_context.dart`）。

* 更新功能 (Update):
  * **物理引擎**：改用 **Rapier** 物理引擎取代 Oimo。引入了全新的 `Collider` 和 `RigidBody` 抽象，以便更好地管理物理系統。
  * **渲染器結構重組**：將 `render_pipeline.dart` 移至 `lib/src/renderer/render_queue.dart` (`M3RenderQueue`)；引擎、場景、陰影貼圖和反射程式碼也做相應更新。
  * **渲染系統**：
    * 透過 `M3PlanarReflection` 和專用的 Mirror 著色器新增了 **平面反射** 支援。
    * 更新了 `M3RenderEngine`, `M3ShadowMap`, `M3PlanarReflection`, `M3ReflectionProbe`, `M3Skybox` 與像素著色器，以整合 `RenderContext` 和水面渲染通道。
    * 增強了 `M3Texture`，提供對外部紋理和文字紋理的更好支援。
    * 改進了相機和投影系統以支援反射矩陣。
  * **場景系統**：更新了 `M3Camera`, `M3Entity`, `M3Node`, `M3Projection`, `M3SampleScene` 和 `M3Scene`，以適應全新的渲染佇列介面。
  * **幾何體**：對 `M3PlaneGeom`, `M3Material` 和基本幾何體進行了重大更新，以支援新的渲染特性。
  * **範例項目**：所有範例皆已更新以使用新版 API；重構了 `main.dart` 和 `main_all.dart`。

## 0.8.1
#### 2026-05-02
* 更新功能 (Update):
  * **專案結構**：將範例檔案整理到 `demos/` 子目錄下，以提高可維護性。
  * **場景圖 (Scene Graph)**：引入 `M3Node` 以改善階層式變換與場景管理；重構了 `M3Entity` 和 `M3Transform`。
  * **渲染系統**：
    * 新增 **PCF (百分比漸進過濾)** 支援，以實現更平滑的陰影邊緣 (`PCF.es3.frag`)。
    * 改進了 `M3RenderPipeline` 和 `M3FrameBuffer` 以提升效能與靈活性。
  * **核心引擎**：移除了舊有的 `physics_engine.dart`，改用更精簡的物理引擎整合方案。
  * **著色器**：更新了支援 PCF 陰影的 ES3 著色器。

## 0.8.0
#### 2026-04-17
* 更新功能 (Update):
  * **物理引擎**：切換至 `M3OimoPhysics`，實現更健全的 Oimo 物理整合與更簡單的幾何體管理。
  * **幾何體**：新增用於儲存高度資料的 `M3HeightField`、用於除錯定位點與骨骼的 `M3OctahedralGeom`，並改進了 `M3PlaneGeom` 的高度圖轉換邏輯。
  * **資源管理**：在 `M3Resources` 中集中管理除錯幾何體，包括 `axisGizmoMesh` 與更新後的除錯形狀。
  * **渲染系統**：改進了 `RenderPipeline`，加強了對不透明和透明材質的支援；在 `M3Scene` 中新增了 `bOnlyOpaque` 渲染通道支援。
  * **材質**：新增了 `M3Material.setMatte()` 用以快速配置無反射材質。
  * **穩定性**：實作了在 Vulkan 和 OpenGLES 之間自動選取的功能，以獲得最佳的 Android 穩定性與效能。
  * **核心引擎**：重構了內部架構並優化了場景圖管理。
  * **平台相容**：移成了對 `dart:io` 的直接依賴，以提升網頁和跨平台的相容性。

## 0.7.2
#### 2026-04-12
* 更新功能 (Update):
  * **幾何體**：為 Torus, Capsule, Cylinder 和 Plane 幾何體新增了 `M3Axis axis` 支援，以實現靈活的基礎朝向設定。
  * **輸入控制**：在 `M3CameraOrbitController` 中新增了鍵盤縮放支援 (+, -)。
  * **渲染系統**：將 `renderShadowMap` 整合至 `M3RenderEngine` 中，並精簡了陰影貼圖的 API。
  * **程式碼清理**：自 `M3Entity` 中移除了 `physicsUpAxis`（幾何體朝向現在改由網格/頂點緩衝層級處理）。
  * **場景系統**：新增了用於引擎壓力測試的 `MassiveScene`。
  * **視訊紋理**：將 `m3_video_bridge` 子套件合併至主引擎中。
  * **外掛轉換**：將 `macbear_3d` 轉換為 Flutter 插件，以支援 Android, iOS 和 macOS 上的原生視訊紋理。
  * **發布準備**：解決了發布至 pub.dev 的路徑依賴問題。

## 0.7.1
#### 2026-03-20
* 更新功能 (Update):
  * **資源路徑**：將字型移至套件資產中 (`assets/fonts`)。
  * **BVH 載入器**：新增對 Biovision Hierarchy (BVH) 檔案的支援。
  * **骨骼網格**：新增用於骨骼視覺化的 `M3OctahedralGeom`。

## 0.7.0
#### 2026-03-04
* 更新功能 (Update):
  * **OpenGL ES 3.0 支援**：將統一著色器從 ES2 升級至 ES3 (GLSL 3.00 ES)。
  * **ES2 清理**：將舊版 ES2 著色器移至 `shaders_discard` 目錄。
  * **渲染增強**：在主範例中預設啟用 PBR 與 IBL，以呈現卓越的視覺品質。
  * **平台與顯示資訊**：新增了 `PlatformInfo` 和 `GraphicsInfo`，用以取得跨平台的 GPU 中繼資料（廠商、渲染器、GLSL 版本）並進行 GL 擴充功能檢查。
  * **動態反射探針**：新增了 `M3ReflectionProbe` 以支援即時環境捕捉與動態反射。
  * **內部優化**：改進了引擎釋放邏輯與微小的紋理釋放清理。

## 0.6.1
#### 2026-02-21
* 新增功能 (Add):
  * **網頁建置支援**：針對 WebGL 與 Flutter Web 進行了優化整合。
  * **線上展示**：建立了自動部署至 [GitHub Pages](https://macbearchen.github.io/macbear_3d/) 的工作流。

## 0.6.0
#### 2026-02-11
* 新增功能 (Add):
  * **地形系統**：支援使用柏林雜訊程序化生成地形 (`M3TerrainGeom`, `M3PerlinNoise`)。
  * **PBR 著色**：在 `M3Material` 中新增了對物理基礎渲染（金屬度、粗糙度）的支援。
  * **IBL (環境光照)**：支援使用環境 Cubemap 貼圖實現擬真的環境光照。
  * **著色器重構**：使用統一的片段著色器 (`Pixel.es2.frag`) 來模組化著色器架構。
  * **網頁支援**：修正了網頁端的文字渲染對齊方式與 WebGL 的特定平台限制。
  * **平台抽象**：將原生平台與網頁平台的邏輯進行分離 (`PlatformInfo`)。
  * **GUI 系統**：改用 Flutter Widget 來構建 UI。

## 0.5.0
#### 2026-01-29
* 新增功能 (Add):
  * **鏡面反射**：新增了基於 Cubemap 的反射渲染 (`renderReflection`)。

## 0.4.0
#### 2026-01-24

* 新增功能 (Add):
  * **核心引擎**：重構了 `updateRender` 以使用 `delta` 持續時間，從而進行精確的物理與動畫計時。
  * **骨骼皮膚網格**：修正了世界空間包圍盒的計算，並提升了動畫的穩定性。
  * **資源管理**：改善了字型資產的處理，並新增了載入狀態的支援。

## 0.3.0
#### 2026-01-17
* 新增功能 (Add):
  * **級聯陰影貼圖 (CSM)**：支援多達 4 個陰影級聯，以在大範圍距離內呈現高品質陰影。
  * **陰影穩定性**：實作了基於包圍球的級聯計算與紋素對齊（texel snapping），以消除陰影閃爍。
  * **陰影品質**：改進了陰影通道，改用正面裁剪（CCW）渲染，以防止邊緣漏光。
  * **動態陰影模式切換**：支援在執行期於標準陰影貼圖與 CSM 之間進行動態切換。
  * **效能優化**：高效的陰影圖集（shadow atlas）管理並減少了陰影繪製呼叫。

## 0.2.0
#### 2026-01-12
* 新增功能 (Add):
  * **包圍體**：為所有幾何體實作了自動計算 AABB 與包圍球。
  * **資源管理器**：提供用於載入與快取資產（幾何體、網格、紋理、字型）的集中式系統。
  * **字型支援**：支援 TrueType (.ttf) 與 OpenType (.otf) 字型解析。
  * **3D 文字**：新增 `M3TextGeom` 以便從文字字串生成 3D 幾何體。
  * **渲染統計**：即時監測引擎效能指標（FPS、頂點數、三角形數、繪製呼叫次數）。

## 0.1.1
#### 2026-01-03
* 新增功能 (Add):
  * UML 類別圖支援。
  * 專案螢幕截圖。

## 0.1.0
#### 2026-01-02
* Macbear 3D 引擎首個版本發布。
* 主要特性：
  * 透過 flutter_angle 支援 OpenGL ES。
  * 場景圖與實體組件系統 (ECS)。
  * 3D 模型格式支援：glTF、OBJ。
  * 整合物理引擎 (Oimo)。
  * 支援光照、陰影與紋理貼圖。
  * 基本幾何體與幾何體構建器。
[English](CHANGELOG.md) | [繁體中文](CHANGELOG_zh.md)

## 0.10.1
#### 2026-09-05
* Documentation & Dependencies:
  * **Sponsorship**: Added Ko-fi sponsorship link and badges.
  * **Dependencies**: Updated `material_ui` to `^1.1.1` and `build` to `^4.0.11`.
  * **Docs & Assets**: Updated documentation and demonstration screenshots.

## 0.10.0
#### 2026-09-04
* Add:
  * **Spotlight & Spot Shadow Mapping**: Added `M3SpotLight` with cone angles (inner/outer cutoffs), directional falloff attenuation, and spot light shadow mapping with shared PCF filtering (`LightFS.es3.glsl`, `ShadowFS.es3.glsl`, `ShadowVS.es3.glsl`).
  * **Terrain LOD & Stitching**: Implemented Level of Detail (LOD) support for terrain tiles (Level 32x32 -> 16x16 -> 8x8 -> 4x4) with edge stitching to prevent gaps between adjacent resolution tiles.
  * **Rapier Physics Integration & Demo Scenes**: Added comprehensive Rapier physics demonstrations including `PhysicsScene`, `DoublePendulumScene`, `NewtonCradleScene`, `CompoundScene`, and `SceneQueryScene`.

* Optimize / Refactor:
  * **glTF Parser Refactoring**: Modularized glTF loading architecture into `M3GltfDocument`, `M3GltfNode`, `M3GltfMesh`, `M3GltfMaterial`, and `M3GltfAnimation`.
  * **Physics Engine Architecture**: Refactored Rapier physics scenes and wall setup into `BaseScene`.
  * **Point & Spot Light Optimization**: Optimized lighting shaders and uniform buffer structures for point and spot lights.
  * **Flutter Upgrade**: Upgraded Flutter compatibility to 3.47.0.

## 0.9.4
#### 2026-08-01
* Add:
  * **Tiled Terrain System**: Introduced `M3TerrainTileGeom` and `M3TiledTerrain` for chunked/tiled terrain rendering and management.
  * **Heightfield & Line Geometry**: Added `M3HeightField.fromHeightmap` constructor and `M3LineGeom` for custom 3D line primitives.
  * **Render Statistics Update**: Updated `M3RenderStats` structure by replacing `culls` with `submeshes` to accurately track total rendered submesh count.

* Optimize / Refactor:
  * **M3View Unmount & Remount**: Decoupled view lifecycle from engine singleton via `unmount()` and `remount()` methods, enabling safe view transitions without tearing down ANGLE/GL context.
  * **Geometry Parameters**: Improved constructor parameter ergonomics for `M3CylinderGeom` and `M3CapsuleGeom`.
  * **Submesh World Bounding**: Added `subMeshes.worldBounding` calculation.
  * **Terrain System Organization**: Refactored `M3TerrainGeom.fromHeightmapImage` using `package:image` and moved heightfield/terrain components to `lib/src/geom/terrain/`.
  * **Android KGP Compatibility**: Fixed Kotlin Gradle Plugin build issues for modern Flutter/Android project configurations.

## 0.9.3
#### 2026-07-15
* Add:
  * **Console Logger (M3Log)**: Added `M3Log` class in `lib/src/util/log.dart` for structured, ANSI-colored debug, info, warning, error, system, and highlight console logging.

* Optimize / Refactor:
  * **Shader & Attenuation Optimization**: Replaced distance-based calculation with squared distance and radius directly in shaders (using UE4's windowed inverse-square attenuation) to avoid expensive square root operations.
  * **Point Light Data Packing**: Point light ranges are now squared on the Dart side before being sent to the GPU as part of the light's position vector `w` component.
  * **Shadow Rendering Enhancement**: Improved shadow blending in `TexturedLighting` fragment shader by linear mixing unlit and lit states based on `ComputeShadowLitFactor` instead of binary states.
  * **Light Helpers Refactoring**: Separated point light bulb rendering (`drawBulb`) from range rendering (`drawHelper`) in visualization tools.
  * **Point Light Calculation Update**: Updated point light calculations in `LightFS` to accept explicit positions and normal vectors and handle object-space scale adjustments (`uInvObjScale`).

## 0.9.2
#### 2026-07-04
* Add:
  * **Swift Package Manager (SPM) Support**: Added SPM integration for iOS and macOS builds.
  * **Framebuffer DEPTH24_STENCIL8 Support**: Configured renderbuffer and depth texture creation to support depth-stencil formats with the correct `DEPTH_STENCIL_ATTACHMENT`.

* Update / Refactor:
  * **Light System Refactoring**: Restructured `M3Light` and `M3DirectionalLight` to use an internal `viewer` (`M3Camera`) delegate instead of inheriting directly from `M3Camera`.
  * **Code Reorganization**: Grouped renderer-related files (`framebuffer.dart`, `render_engine.dart`, `render_options.dart`, `shadow_map.dart`) under the `lib/src/renderer/` directory.
  * **Physics & Rigidbody Updates**: Added `removeRigidBody` method and updated `rapier_physics` dependency version.
  * **Demos & UI Refinement**: Centralized light rotation updates in `DemoScene.update`, updated 3D text demo with an interactive UI, and optimized UI layouts with proper SafeAreas.
  * **WebGL Texture Fallbacks**: Added ASTC texture compression check and automatic fallback to checkerboard on unsupported web environments.

## 0.9.1
#### 2026-06-19
* Add:
  * **Modular Shader System**: Refactored shader pipeline to use `.glsl` extensions (e.g., `PixelFS.es3.glsl`, `SkinningVS.es3.glsl`). Added new shader source files `FogFS.es3.glsl`, `ShadowFS.es3.glsl`, and `ShadowVS.es3.glsl`.
  * **Shader Program Wrappers**: Introduced dedicated, type-safe Dart wrappers (`M3FogShader`, `M3LightingShader`, `M3ShadowShader`, and `M3WaterShader` under `lib/src/program/shader/`) to encapsulate WebGL uniform bindings and initialization.
  * **Procedural Textures**: Added runtime creation of high-quality tileable water normal maps (`M3Texture.createWaterNormalMap`) using ridged Perlin noise and domain warping.
  * **Terrain Heightmap support**: Added `fromHeightmapImage` and `fromHeightmapAsset` factory methods to `M3TerrainGeom`. Supports loading 16-bit grayscale PNG heightmaps (with custom IHDR parsing) for precise terrain generation, alongside standard 8-bit RGBA heightmaps. Uses bilinear interpolation for smooth elevations.
  * **Fog Effect**: Introduced `M3Fog` with support for camera-facing depth fog, configurable fog colors, and custom plane clip calculations (e.g., for underwater shading) (`lib/src/scene/fog.dart`).
  * **Web Build Rapier physics**: Added `rapier.js` and `rapier_ffi.wasm` to the example web directory to fix Web builds of the physics demo.
  * **Example/Demo updates**: Added a new terrain heightmap demo `06_terrain.dart` showing high-resolution 16-bit heightmaps and procedural generation. Updated `main_all.dart` and other examples to clean up and integrate features.

* Update:
  * **Shader Bindings**: Updated `shader_builder.dart` and regenerated Dart bindings (`.g.dart`) for the new `.glsl` shaders.
  * **GPU Program Refactoring**: Streamlined `ProgramLighting`, `ProgramShadowMap`, and `ProgramWater` by delegating GLSL compile and uniform set logic to the new shader program wrappers.
  * **Water Effect**: Enhanced water rendering with alpha blending, custom tangent-space TBN matrix computations (`setTBN`), and improved fog depth underwater tinting using customized clip planes.
  * **Planar Reflections**: Added customizable render scaling (`setRenderScale`) for reflection and refraction passes to optimize performance, and unified oblique clipping plane calculations.
  * **UML Generation Tool**: Updated `gen_uml.sh` to temporarily comment out annotations causing older analyzer tool crashes during class diagram generation.

## 0.9.0
#### 2026-05-24
* Add:
  * **Water Effect**: Introduced `M3Water` with animated dual-layer normal-map flow, planar reflection & refraction, fog-depth underwater tinting, and configurable wave distortion (`lib/src/scene/water.dart`).
  * **Water Shader**: New ES3 `Water.es3.frag` / `Water.es3.vert` with generated Dart bindings (`Water.es3.frag.g.dart`, `Water.es3.vert.g.dart`).
  * **ProgramWater**: Dedicated GPU program for water rendering (`lib/src/program/program_water.dart`).
  * **RenderContext**: New `M3RenderContext` abstraction that bundles per-frame GPU state (viewport, matrices, lights, shadow map, reflection/water targets) for cleaner render-pass authoring (`lib/src/renderer/render_context.dart`).

* Update:
  * **Physics**: Switched to **Rapier** physics engine, replacing Oimo. Introduced new `Collider` and `RigidBody` abstractions for better physics management.
  * **Renderer Reorganisation**: Moved `render_pipeline.dart` → `lib/src/renderer/render_queue.dart` (`M3RenderQueue`); engine, scene, shadow map and reflection code updated accordingly.
  * **Rendering**:
    * Added **Planar Reflections** support with `M3PlanarReflection` and dedicated `Mirror` shaders.
    * Updated `M3RenderEngine`, `M3ShadowMap`, `M3PlanarReflection`, `M3ReflectionProbe`, `M3Skybox`, and pixel shader to integrate `RenderContext` and water pass.
    * Enhanced `M3Texture` with better support for external textures and text-based textures.
    * Improved camera and projection systems to support reflection matrices.
  * **Scene**: Updated `M3Camera`, `M3Entity`, `M3Node`, `M3Projection`, `M3SampleScene`, and `M3Scene` for the new render pipeline interface.
  * **Geometries**: Significant updates to `M3PlaneGeom`, `M3Material`, and primitives to support new rendering features.
  * **Examples**: All demos updated to use the new API; `main.dart` and `main_all.dart` refreshed.

## 0.8.1
#### 2026-05-02
* Update:
  * **Project Structure**: Reorganized example files into a `demos/` subdirectory for better maintainability.
  * **Scene Graph**: Introduced `M3Node` to improve hierarchical transformations and scene management; refactored `M3Entity` and `M3Transform`.
  * **Rendering**:
    * Added **PCF (Percentage Closer Filtering)** for smoother shadow edges (`PCF.es3.frag`).
    * Improved `M3RenderPipeline` and `M3FrameBuffer` for better performance and flexibility.
  * **Core Engine**: Removed legacy `physics_engine.dart` in favor of streamlined physics integration.
  * **Shaders**: Updated ES3 shaders with PCF shadow support.

## 0.8.0
#### 2026-04-17
* Update:
  * **Physics**: Switched to `M3OimoPhysics` for more robust Oimo physics integration and easier primitive management.
  * **Geometry**: Added `M3HeightField` for storing height data, `M3OctahedralGeom` for debug dots/bones, and improved `M3PlaneGeom` height field conversion.
  * **Resource**: Centralized debug geometries in `M3Resources`, including `axisGizmoMesh` and updated debug shapes.
  * **Rendering**: Improved `RenderPipeline` with enhanced support for opaque and transparency materials; added `bOnlyOpaque` render pass support in `M3Scene`.
  * **Material**: Added `M3Material.setMatte()` for quick non-reflective material configuration.
  * **Stability**: Implemented automated selection between Vulkan and OpenGLES for optimal Android stability and performance.
  * **Core Engine**: Refactored internal architecture and optimized scene graph management.
  * **Platform**: Removed direct `dart:io` dependencies to improve web and cross-platform compatibility.

## 0.7.2
#### 2026-04-12
* Update:
  * **Geometry**: Added `M3Axis axis` support for Torus, Capsule, Cylinder, and Plane geometries for flexible base orientation.
  * **Input**: Added keyboard zoom support (+, -) in `M3CameraOrbitController`.
  * **Rendering**: Integrated `renderShadowMap` into `M3RenderEngine` and refined shadow map API.
  * **Cleanup**: Removed `physicsUpAxis` from `M3Entity` (geometry orientation now handled at the mesh/buffer level).
  * **Scene**: Added `MassiveScene` for engine stress testing.
  * **Video Texture**: Merged `m3_video_bridge` sub-package into the main engine.
  * **Plugin Conversion**: `macbear_3d` is now a Flutter plugin to support native video textures on Android, iOS, and macOS.
  * **Publishing**: Resolved path dependency issues for pub.dev publication.

## 0.7.1
#### 2026-03-20
* Update:
  * **Assets**: Moved fonts into the package assets (`assets/fonts`).
  * **BVH Loader**: Added support for Biovision Hierarchy (BVH) files.
  * **Bone Mesh**: Added `M3OctahedralGeom` for bone visualization.

## 0.7.0
#### 2026-03-04
* Update:
  * **OpenGL ES 3.0 Support**: Upgraded unified shaders from ES2 to ES3 (GLSL 3.00 ES).
  * **ES2 Cleanup**: Moved legacy ES2 shaders to `shaders_discard` directory.
  * **Enhanced Rendering**: Enabled PBR and IBL by default in main examples for superior visual quality.
  * **Platform & Graphics info**: Added `PlatformInfo` and `GraphicsInfo` for cross-platform GPU metadata (Vendor, Renderer, GLSL version) and GL extension checking.
  * **Dynamic Reflection Probe**: Added `M3ReflectionProbe` for real-time cubemap capture and dynamic reflections.
  * **Internal**: Improved engine disposal and minor texture unbind cleanup.

## 0.6.1
#### 2026-02-21
* Add:
  * **Support Web build**: Optimized for WebGL and Flutter Web integration.
  * **Live Demo**: Created automatic deployment to [GitHub Pages](https://macbearchen.github.io/macbear_3d/).

## 0.6.0
#### 2026-02-11
* Add:
  * **Terrain System**: Procedural terrain generation using Perlin Noise (`M3TerrainGeom`, `M3PerlinNoise`).
  * **PBR Shading**: Support for Physically Based Rendering (metallic, roughness) in `M3Material`.
  * **IBL (Image-Based Lighting)**: Environment-based realistic lighting using cubemaps.
  * **Shader Refactoring**: Modular shader architecture with unified pixel shader (`Pixel.es2.frag`).
  * **Web Support**: Fixed text rendering alignment and platform-specific WebGL constraints.
  * **Platform Abstraction**: Separated logic for Native and Web (`PlatformInfo`).
  * **GUI System**: Adopted Flutter Widgets for UI.

## 0.5.0
#### 2026-01-29
* Add:
  * **Reflection**: Added cubemap-based reflection (`renderReflection`).

## 0.4.0
#### 2026-01-24

* Add:
  * **Core Engine**: Refactored `updateRender` to use `delta` duration for precise physics and animation timing.
  * **Skinned Meshes**: Fixed world-space bounding box calculations and improved animation stability.
  * **Resource Management**: Improved handling of font assets and added loading state support.

## 0.3.0
#### 2026-01-17
* Add:
  * **Cascaded Shadow Maps (CSM)**: Support for multiple shadow cascades (up to 4) for high-quality shadows over large distances.
  * **Shadow Stability**: Implemented bounding sphere-based cascade calculation and texel snapping to eliminate shadow shimmering.
  * **Shadow Quality**: Improved shadow pass to use front-face (CCW) rendering to prevent edge light leakage.
  * **Dynamic Shadow Mode Switching**: Ability to switch between standard shadow mapping and CSM at runtime.
  * **Performance Optimizations**: Efficient shadow atlas management and reduced draw calls for shadows.

## 0.2.0
#### 2026-01-12
* Add: 
  * **Bounding Volumes**: Automatic AABB and Bounding Sphere calculation for all geometries.
  * **Resource Manager**: Centralized system for loading and caching assets (geometries, meshes, textures, fonts).
  * **Font Support**: TrueType (.ttf) and OpenType (.otf) font parsing.
  * **3D Text**: New `M3TextGeom` for generating 3D geometry from text strings.
  * **Render Stats**: Real-time monitoring of engine performance (FPS, vertices, triangles, draw calls).

## 0.1.1
#### 2026-01-03
* Add: 
  * UML diagram. https://open-vsx.org/vscode/item?itemName=jebbs.plantuml
  * screenshot images.

## 0.1.0 
#### 2026-01-02
* Initial release of Macbear 3D engine.
* Features:
  * OpenGL ES support via flutter_angle.
  * Scene graph and entity component system.
  * 3D format support: glTF, OBJ.
  * Physics engine integration (Oimo).
  * Lighting, shadows, and texturing support.
  * Basic primitives and geometry builders.
## 0.2.0

* Add: 
  * **Bounding Volumes**: Automatic AABB and Bounding Sphere calculation for all geometries.
  * **Resource Manager**: Centralized system for loading and caching assets (geometries, meshes, textures, fonts).
  * **Font Support**: TrueType (.ttf) and OpenType (.otf) font parsing.
  * **3D Text**: New `M3TextGeom` for generating 3D geometry from text strings.
  * **Render Stats**: Real-time monitoring of engine performance (FPS, vertices, triangles, draw calls).

## 0.1.1

* Add: 
  * UML diagram. https://open-vsx.org/vscode/item?itemName=jebbs.plantuml
  * screenshot images.

## 0.1.0

* Initial release of Macbear 3D engine.
* Features:
  * OpenGL ES support via flutter_angle.
  * Scene graph and entity component system.
  * 3D format support: glTF, OBJ.
  * Physics engine integration (Oimo).
  * Lighting, shadows, and texturing support.
  * Basic primitives and geometry builders.

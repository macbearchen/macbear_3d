import '../m3_internal.dart';

/// A tiled plane mesh consisting of a grid of [M3SubMesh]es.
///
/// Each tile is an individual [M3SubMesh] referencing a shared (or per-tile) [M3PlaneGeom].
/// This architecture offers:
/// 1. **Frustum Culling**: Individual tiles can be culled by the camera.
/// 2. **Multi-Material Support**: Different tiles can have distinct [M3Material]s (e.g. map textures, terrain patches).
/// 3. **VBO Sharing**: All tiles share a single [M3PlaneGeom] instance if heights are flat, saving GPU memory.
class M3TiledPlaneMesh extends M3Mesh {
  /// Number of tile columns (along X axis).
  final int tilesX;

  /// Number of tile rows (along Y axis).
  final int tilesY;

  /// Width of each individual tile.
  final double tileWidth;

  /// Height of each individual tile.
  final double tileHeight;

  /// Total width of the combined plane.
  double get totalWidth => tilesX * tileWidth;

  /// Total height of the combined plane.
  double get totalHeight => tilesY * tileHeight;

  /// Creates a tiled plane mesh subdivided into [tilesX] x [tilesY] submeshes.
  ///
  /// - [tileWidth] and [tileHeight] define each tile's dimensions.
  /// - [segmentsPerTileX] and [segmentsPerTileY] specify internal subdivisions per tile.
  /// - [axis] specifies plane normal direction (defaults to [M3Axis.z]).
  /// - [materialBuilder] callback to supply a custom [M3Material] for tile `(tileX, tileY)`.
  /// - [onVertex] height mapping function `(worldX, worldY)` if deformation is needed.
  /// - [flipFace] whether to invert face normals.
  /// - [shading] smooth or flat shading mode.
  M3TiledPlaneMesh({
    required this.tilesX,
    required this.tilesY,
    required this.tileWidth,
    required this.tileHeight,
    int segmentsPerTileX = 1,
    int segmentsPerTileY = 1,
    M3Axis axis = M3Axis.z,
    M3Material Function(int tileX, int tileY)? materialBuilder,
    Function(double x, double y)? onVertex,
    bool flipFace = false,
    M3ShadingMode shading = M3ShadingMode.smooth,
  }) : super(null) {
    assert(tilesX > 0 && tilesY > 0, 'tilesX and tilesY must be > 0');
    name = "TiledPlane";

    final totalW = totalWidth;
    final totalH = totalHeight;
    final startX = -totalW * 0.5 + tileWidth * 0.5;
    final startY = totalH * 0.5 - tileHeight * 0.5;

    // If onVertex callback is provided, each tile has distinct vertex heights,
    // so we cannot share geometry across tiles. Otherwise, share a single M3PlaneGeom.
    final M3PlaneGeom? sharedGeom = (onVertex == null)
        ? M3PlaneGeom(
            tileWidth,
            tileHeight,
            widthSegments: segmentsPerTileX,
            heightSegments: segmentsPerTileY,
            axis: axis,
            flipFace: flipFace,
            shading: shading,
          )
        : null;

    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final posX = startX + tx * tileWidth;
        final posY = startY - ty * tileHeight;

        final M3PlaneGeom tileGeom;
        if (sharedGeom != null) {
          tileGeom = sharedGeom;
        } else {
          // Custom height per tile based on global (worldX, worldY)
          tileGeom = M3PlaneGeom(
            tileWidth,
            tileHeight,
            widthSegments: segmentsPerTileX,
            heightSegments: segmentsPerTileY,
            axis: axis,
            flipFace: flipFace,
            shading: shading,
            onVertex: (localX, localY) {
              final wx = posX + localX;
              final wy = posY + localY;
              return onVertex!(wx, wy);
            },
          );
        }

        final mtr = materialBuilder?.call(tx, ty) ?? M3Material();
        final subMesh = M3SubMesh(tileGeom, material: mtr);

        // Apply local translation based on plane axis
        final Vector3 offset;
        switch (axis) {
          case M3Axis.z: // XY plane
            offset = Vector3(posX, posY, 0.0);
            break;
          case M3Axis.y: // XZ plane
            offset = Vector3(posX, 0.0, -posY);
            break;
          case M3Axis.x: // YZ plane
            offset = Vector3(0.0, posY, posX);
            break;
        }

        subMesh.localMatrix.translateByVector3(offset);
        subMeshes.add(subMesh);
      }
    }
  }

  /// Convenience constructor specifying total width and total height.
  M3TiledPlaneMesh.fromTotalSize({
    required double totalWidth,
    required double totalHeight,
    required int tilesX,
    required int tilesY,
    int segmentsPerTileX = 4,
    int segmentsPerTileY = 4,
    M3Axis axis = M3Axis.z,
    M3Material Function(int tileX, int tileY)? materialBuilder,
    Function(double x, double y)? onVertex,
    bool flipFace = false,
    M3ShadingMode shading = M3ShadingMode.smooth,
  }) : this(
          tilesX: tilesX,
          tilesY: tilesY,
          tileWidth: totalWidth / tilesX,
          tileHeight: totalHeight / tilesY,
          segmentsPerTileX: segmentsPerTileX,
          segmentsPerTileY: segmentsPerTileY,
          axis: axis,
          materialBuilder: materialBuilder,
          onVertex: onVertex,
          flipFace: flipFace,
          shading: shading,
        );

  /// Helper to get the submesh at tile coordinate ([tileX], [tileY]).
  M3SubMesh? getTileSubMesh(int tileX, int tileY) {
    if (tileX < 0 || tileX >= tilesX || tileY < 0 || tileY >= tilesY) return null;
    final index = tyIndex(tileX, tileY);
    return subMeshes[index];
  }

  /// Calculates the flat index in [subMeshes] for ([tileX], [tileY]).
  int tyIndex(int tileX, int tileY) => tileY * tilesX + tileX;
}

part of '../geom.dart';

// ---------------------------------------------------------------------------
// M3TerrainTileGeom
// ---------------------------------------------------------------------------

/// A terrain tile whose vertex/normal/UV buffers (VBO) are owned **per-tile**.
/// The index buffers (IBO for faces and edges) are **shared** across all tiles.
///
/// Never construct this directly; use [M3TiledTerrain.build] or
/// [M3TiledTerrain.fromHeightField].
class M3TerrainTileGeom extends M3Geom {
  /// Grid row of this tile (Y axis, 0 = top).
  final int tileRow;

  /// Grid column of this tile (X axis, 0 = left).
  final int tileCol;

  /// Current LOD level (0..3).
  int _lodLevel = 0;

  /// Returns current LOD level (0..3).
  int get lodLevel => _lodLevel;

  /// Current stitch mask for (N, E, S, W) neighbors (0..15).
  int _stitchMask = 0;

  /// Returns current stitch mask (0..15).
  int get stitchMask => _stitchMask;

  /// Sets current LOD level (0..3) and optional [stitchMask]. Updates active face/edge indices.
  void setLodAndStitch(int level, int mask) {
    assert(level >= 0 && level < _lodFaceIndices.length, 'LOD level out of bounds: $level');
    assert(mask >= 0 && mask <= 15, 'Stitch mask out of bounds: $mask');
    if (_lodLevel == level && _stitchMask == mask) return;
    _lodLevel = level;
    _stitchMask = mask;
    final indexKey = (level << 4) | mask;
    _faceIndices[0] = _lodFaceIndices[indexKey] ?? _lodFaceIndices[level << 4]!;
    _edgeIndices[0] = _lodEdgeIndices[indexKey] ?? _lodEdgeIndices[level << 4]!;
  }

  /// Sets current LOD level (0..3). Updates active face/edge indices for rendering.
  set lodLevel(int level) {
    setLodAndStitch(level, _stitchMask);
  }

  final Map<int, _M3Indices> _lodFaceIndices;
  final Map<int, _M3Indices> _lodEdgeIndices;

  M3TerrainTileGeom._({
    required this.tileRow,
    required this.tileCol,
    required int vertexCount,
    required Buffer vertexBuffer,
    required Buffer normalBuffer,
    required Buffer uvBuffer,
    required Map<int, _M3Indices> lodFaceIndices,
    required Map<int, _M3Indices> lodEdgeIndices,
    int initialLod = 0,
    int initialStitchMask = 0,
  }) : _lodFaceIndices = lodFaceIndices,
       _lodEdgeIndices = lodEdgeIndices {
    _vertexCount = vertexCount;
    _vertexBuffer = vertexBuffer;
    _normalBuffer = normalBuffer;
    _uvBuffer = uvBuffer;
    _lodLevel = initialLod.clamp(0, M3TerrainLodConfig.lodCount - 1);
    _stitchMask = initialStitchMask;
    final key = (_lodLevel << 4) | _stitchMask;
    _faceIndices.add(lodFaceIndices[key] ?? lodFaceIndices[_lodLevel << 4]!);
    _edgeIndices.add(lodEdgeIndices[key] ?? lodEdgeIndices[_lodLevel << 4]!);
    name = 'TerrainTile_${tileRow}_$tileCol';
  }

  /// Squared distance from the eye to the closest point on the AABB.
  /// Using the closest point instead of the tile center avoids large tiles
  /// being misjudged as "far" when the eye is near their edge.
  double distanceSquaredTo(Vector3 eye) {
    final aabbMin = localBounding.aabb.min;
    final aabbMax = localBounding.aabb.max;

    final closestX = eye.x.clamp(aabbMin.x, aabbMax.x);
    final closestY = eye.y.clamp(aabbMin.y, aabbMax.y);
    final closestZ = eye.z.clamp(aabbMin.z, aabbMax.z);

    final dx = eye.x - closestX;
    final dy = eye.y - closestY;
    final dz = eye.z - closestZ;

    return dx * dx + dy * dy + dz * dz;
  }

  @override
  void draw(M3Program prog, {M3FillMode fillMode = .solid}) {
    if (fillMode == .wireframe) {
      final lodColors = [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.magenta, Colors.cyan];
      M3Material mtr = M3Material();
      final level = _lodLevel % lodColors.length;
      prog.setMaterial(mtr, lodColors[level]);
    }
    super.draw(prog, fillMode: fillMode);
  }

  /// Releases this tile's **own** VBO buffers.
  ///
  /// The shared IBO index buffers are owned by [M3TiledTerrain]; they are not
  /// disposed here. Call [M3TiledTerrain.dispose] to handle full teardown.
  @override
  void dispose() {
    _faceIndices.clear();
    _edgeIndices.clear();
    super.dispose();
  }
}

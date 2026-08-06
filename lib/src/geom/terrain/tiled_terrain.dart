part of '../geom.dart';

// ---------------------------------------------------------------------------
// M3TiledTerrain
// ---------------------------------------------------------------------------

/// Result of [M3TiledTerrain.build] / [M3TiledTerrain.fromHeightField].
///
/// Contains the renderable [mesh] (one [M3SubMesh] per tile) and the internal
/// shared IBO index buffers shared across all tiles.
///
/// Always call [dispose] instead of disposing sub-meshes manually, to ensure
/// the shared IBO is released after all tile VBO buffers.
class M3TiledTerrain {
  /// The renderable mesh. Contains [tilesX] × [tilesY] sub-meshes.
  final M3Mesh mesh;

  /// Tile columns (X axis).
  final int tilesX;

  /// Tile rows (Y axis).
  final int tilesY;

  /// Whether LOD (Level of Detail) calculations and updates are enabled.
  /// When disabled, all tiles reset to LOD 0 (full detail).
  bool enableLod = true;

  final Map<int, _M3Indices> _sharedFaceIndices;
  final Map<int, _M3Indices> _sharedEdgeIndices;

  /// Total tile count = [tilesX] × [tilesY].
  int get tileCount => tilesX * tilesY;

  M3TiledTerrain._(this.mesh, this.tilesX, this.tilesY, this._sharedFaceIndices, this._sharedEdgeIndices);

  /// Releases all tile VBO buffers then the shared IBO buffers.
  void dispose() {
    for (final sub in mesh.subMeshes) {
      sub.geom.dispose(); // tile: own VBOs only
    }
    for (final indices in _sharedFaceIndices.values) {
      indices.dispose();
    }
    for (final indices in _sharedEdgeIndices.values) {
      indices.dispose();
    }
    mesh.subMeshes.clear();
  }

  /// Helper to fetch tile geom by 2D grid position [row, col].
  M3TerrainTileGeom _getTileGeom(int row, int col) {
    final index = row * tilesX + col;
    return mesh.subMeshes[index].geom as M3TerrainTileGeom;
  }

  /// Call once per frame. Updates tile LOD levels and boundary seam stitching.
  void updateLod(Vector3 eyePosition, {Matrix4? worldMatrix}) {
    if (!enableLod) {
      for (final sub in mesh.subMeshes) {
        final tile = sub.geom as M3TerrainTileGeom;
        tile.setLodAndStitch(0, 0);
      }
      return;
    }
    final Vector3 localEye = Vector3.copy(eyePosition);
    if (worldMatrix != null) {
      final invMat = Matrix4.copy(worldMatrix)..invert();
      invMat.transform3(localEye);
    }

    // 1. Resolve raw LOD level for each tile
    for (final sub in mesh.subMeshes) {
      final tile = sub.geom as M3TerrainTileGeom;
      final distanceSquared = tile.distanceSquaredTo(localEye);
      final resolvedLod = M3TerrainLodResolver.resolveLod(currentLod: tile.lodLevel, distanceSquared: distanceSquared);
      if (resolvedLod != tile.lodLevel) {
        tile.lodLevel = resolvedLod;
      }
    }

    // 2. Resolve 4-bit neighbor stitch mask for each tile (N, E, S, W)
    // Stitching responsibility belongs to the LOWER-precision side:
    // a direction edge needs stitching when selfLod > neighborLod
    // (self has fewer segments = lower precision than the neighbor).
    // LOD0 is always the highest-precision level — it never stitches.
    for (int r = 0; r < tilesY; r++) {
      for (int c = 0; c < tilesX; c++) {
        final tile = _getTileGeom(r, c);
        final selfLod = tile.lodLevel;

        // LOD0 is the highest precision — never needs to stitch.
        if (selfLod == 0) {
          tile.setLodAndStitch(0, 0);
          continue;
        }

        int mask = 0;

        // North neighbor (r - 1)
        if (r > 0) {
          final nLod = _getTileGeom(r - 1, c).lodLevel;
          if (nLod < selfLod) mask |= M3TerrainStitchBuilder.maskNorth;
        }
        // East neighbor (c + 1)
        if (c < tilesX - 1) {
          final eLod = _getTileGeom(r, c + 1).lodLevel;
          if (eLod < selfLod) mask |= M3TerrainStitchBuilder.maskEast;
        }
        // South neighbor (r + 1)
        if (r < tilesY - 1) {
          final sLod = _getTileGeom(r + 1, c).lodLevel;
          if (sLod < selfLod) mask |= M3TerrainStitchBuilder.maskSouth;
        }
        // West neighbor (c - 1)
        if (c > 0) {
          final wLod = _getTileGeom(r, c - 1).lodLevel;
          if (wLod < selfLod) mask |= M3TerrainStitchBuilder.maskWest;
        }

        tile.setLodAndStitch(selfLod, mask);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Factory constructors
  // -------------------------------------------------------------------------

  /// Builds a tiled terrain using Perlin noise where each tile has its own VBO
  /// and shares a single IBO.
  ///
  /// The terrain is divided into [tilesX] × [tilesY] tiles where:
  /// - `tilesX = widthSegments / tileWidthSegments`
  /// - `tilesY = heightSegments / tileHeightSegments`
  ///
  /// Both [widthSegments] and [heightSegments] must be exactly divisible by
  /// their respective tile segment counts.
  ///
  /// Example — 1024×1024 terrain, 32×32 tiles:
  /// ```dart
  /// final terrain = M3TiledTerrain.build(
  ///   200.0, 200.0,
  ///   widthSegments: 1024, heightSegments: 1024,
  ///   tileWidthSegments: 32, tileHeightSegments: 32,
  ///   maxHeight: 16.0, noiseScale: 0.08,
  ///   material: terrainMtr,
  /// );
  /// addMesh(terrain.mesh, Vector3(0, 0, -13));
  /// ```
  static M3TiledTerrain build(
    double width,
    double height, {
    int widthSegments = 1024,
    int heightSegments = 1024,
    int tileWidthSegments = 32,
    int tileHeightSegments = 32,
    double maxHeight = 5.0,
    double noiseScale = 0.05,
    int octaves = 4,
    Vector2? uvScale,
    M3Material? material,
  }) {
    return _buildImpl(
      width,
      height,
      (ratioX, ratioY, px, py) {
        return M3Noise.fBm(px * noiseScale, py * noiseScale, octaves: octaves) * maxHeight;
      },
      widthSegments: widthSegments,
      heightSegments: heightSegments,
      tileWidthSegments: tileWidthSegments,
      tileHeightSegments: tileHeightSegments,
      maxHeight: maxHeight,
      uvScale: uvScale,
      material: material,
    );
  }

  /// Builds a tiled terrain from a pre-sampled [M3HeightField].
  ///
  /// The height field's [M3HeightField.widthSegments] and
  /// [M3HeightField.heightSegments] define the grid resolution.
  /// Both must be divisible by the respective tile segment counts.
  ///
  /// Example:
  /// ```dart
  /// final hf = M3HeightField.fromHeightmap(image, 200.0, 200.0,
  ///     widthSegments: 1024, heightSegments: 1024, maxHeight: 400.0);
  /// final terrain = M3TiledTerrain.fromHeightField(
  ///   hf, 200.0, 200.0,
  ///   tileWidthSegments: 32, tileHeightSegments: 32,
  ///   material: terrainMtr,
  /// );
  /// ```
  static M3TiledTerrain fromHeightField(
    M3HeightField hf,
    double width,
    double height, {
    int tileWidthSegments = 32,
    int tileHeightSegments = 32,
    double maxHeight = 5.0,
    Vector2? uvScale,
    M3Material? material,
  }) {
    return _buildImpl(
      width,
      height,
      (ratioX, ratioY, px, py) {
        final int j = (ratioX * hf.widthSegments).round().clamp(0, hf.widthSegments);
        final int i = (ratioY * hf.heightSegments).round().clamp(0, hf.heightSegments);
        return hf.data[i * (hf.widthSegments + 1) + j] * hf.heightScale;
      },
      widthSegments: hf.widthSegments,
      heightSegments: hf.heightSegments,
      tileWidthSegments: tileWidthSegments,
      tileHeightSegments: tileHeightSegments,
      maxHeight: maxHeight,
      uvScale: uvScale,
      material: material,
    );
  }

  // -------------------------------------------------------------------------
  // Private implementation helpers
  // -------------------------------------------------------------------------

  /// Shared core for [build] and [fromHeightField].
  static M3TiledTerrain _buildImpl(
    double width,
    double height,
    double Function(double ratioX, double ratioY, double px, double py) heightFunc, {
    required int widthSegments,
    required int heightSegments,
    required int tileWidthSegments,
    required int tileHeightSegments,
    required double maxHeight,
    Vector2? uvScale,
    M3Material? material,
  }) {
    assert(
      widthSegments % tileWidthSegments == 0,
      'widthSegments ($widthSegments) must be divisible by tileWidthSegments ($tileWidthSegments)',
    );
    assert(
      heightSegments % tileHeightSegments == 0,
      'heightSegments ($heightSegments) must be divisible by tileHeightSegments ($tileHeightSegments)',
    );
    assert(
      tileWidthSegments == 32 && tileHeightSegments == 32,
      'Tile segment size must be 32x32 to support 4 LOD levels (32x32 down to 4x4).',
    );

    final tileVertCount = (tileWidthSegments + 1) * (tileHeightSegments + 1);
    assert(tileVertCount <= 65536, 'Tile vertex count ($tileVertCount) exceeds 65,536 limit for uint16 index buffers.');

    final tilesX = widthSegments ~/ tileWidthSegments;
    final tilesY = heightSegments ~/ tileHeightSegments;
    final int numVert = (widthSegments + 1) * (heightSegments + 1);

    uvScale ??= Vector2(1, 1);
    final hx = width * 0.5, hy = height * 0.5;

    // 1. Generate all global vertices on CPU ---------------------------------
    final vertices = Vector3List(numVert);
    final normals = Vector3List(numVert);
    final uvs = Vector2List(numVert);

    int index = 0;
    for (int i = 0; i <= heightSegments; i++) {
      final double ratioY = i.toDouble() / heightSegments;
      final double py = hy - height * ratioY;
      for (int j = 0; j <= widthSegments; j++) {
        final double ratioX = j.toDouble() / widthSegments;
        final double px = width * ratioX - hx;
        final double pz = heightFunc(ratioX, ratioY, px, py);
        vertices[index] = Vector3(px, py, pz);
        uvs[index] = Vector2(ratioX * uvScale.x, ratioY * uvScale.y);
        index++;
      }
    }

    // 2. Calculate normals for the entire terrain ---------------------------
    for (int i = 0; i <= heightSegments; i++) {
      for (int j = 0; j <= widthSegments; j++) {
        final int idx = i * (widthSegments + 1) + j;
        final Vector3 v = vertices[idx];
        Vector3 vn = Vector3(0, 0, 1);
        if (i < heightSegments && j < widthSegments) {
          final Vector3 vRight = vertices[idx + 1];
          final Vector3 vDown = vertices[idx + (widthSegments + 1)];
          vn = (vDown - v).cross(vRight - v).normalized();
        } else if (i > 0 && j > 0) {
          vn = normals[idx - (widthSegments + 1) - 1];
        } else if (i > 0) {
          vn = normals[idx - (widthSegments + 1)];
        } else if (j > 0) {
          vn = normals[idx - 1];
        }
        normals[idx] = vn;
      }
    }

    // 3. Build shared LOD IBOs (Uint16List) for all tiles ------------------
    // Key: (lod << 4) | stitchMask (0..15)
    // LOD0 never stitches (it is always the highest-precision level),
    // so only mask=0 is needed for LOD0. LOD1..3 need all 16 mask variants.
    final sharedFaceIndices = <int, _M3Indices>{};
    final sharedEdgeIndices = <int, _M3Indices>{};

    for (int lod = 0; lod < M3TerrainLodConfig.lodCount; lod++) {
      final maxMask = (lod == 0) ? 1 : 16; // LOD0: only mask 0; LOD1-3: all 16
      for (int mask = 0; mask < maxMask; mask++) {
        final key = (lod << 4) | mask;
        final faceIndices = M3TerrainStitchBuilder.buildStitchedFaceIndices(lod, mask);
        final wireIndices = M3TerrainStitchBuilder.buildStitchedWireIndices(lod, mask);

        sharedFaceIndices[key] = _M3Indices(WebGL.TRIANGLES, faceIndices);
        sharedEdgeIndices[key] = _M3Indices(WebGL.LINES, wireIndices);
      }
    }

    // 4. Create tile geoms + VBO per tile -----------------------------------
    final mesh = M3Mesh(null);
    mesh.name = 'TiledTerrain_${tilesX}x$tilesY';

    final vTemp = Vector3.zero();
    final nTemp = Vector3.zero();
    final uvTemp = Vector2.zero();

    for (int tr = 0; tr < tilesY; tr++) {
      for (int tc = 0; tc < tilesX; tc++) {
        final tileVertices = Vector3List(tileVertCount);
        final tileNormals = Vector3List(tileVertCount);
        final tileUVs = Vector2List(tileVertCount);

        final int r0 = tr * tileHeightSegments;
        final int c0 = tc * tileWidthSegments;

        int localIdx = 0;
        for (int i = 0; i <= tileHeightSegments; i++) {
          final int globalRow = r0 + i;
          final int globalRowOffset = globalRow * (widthSegments + 1);
          for (int j = 0; j <= tileWidthSegments; j++) {
            final int globalIdx = globalRowOffset + c0 + j;
            vertices.load(globalIdx, vTemp);
            normals.load(globalIdx, nTemp);
            uvs.load(globalIdx, uvTemp);

            tileVertices[localIdx] = vTemp;
            tileNormals[localIdx] = nTemp;
            tileUVs[localIdx] = uvTemp;
            localIdx++;
          }
        }

        // Bounding for tile
        final tb = M3Bounding();
        tileVertices.load(0, vTemp);
        tb.aabb.min.setFrom(vTemp);
        tb.aabb.max.setFrom(vTemp);
        for (int k = 1; k < tileVertCount; k++) {
          tileVertices.load(k, vTemp);
          tb.aabb.hullPoint(vTemp);
        }
        tb.aabb.copyCenter(tb.sphere.center);
        tb.sphere.radius = tb.aabb.min.distanceTo(tb.aabb.max) * 0.5;

        // Create per-tile VBO buffers
        final gl = M3AppEngine.instance.renderEngine.gl;

        final vertexBuffer = gl.createBuffer();
        gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
        gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(tileVertices.buffer), WebGL.STATIC_DRAW);

        final normalBuffer = gl.createBuffer();
        gl.bindBuffer(WebGL.ARRAY_BUFFER, normalBuffer);
        gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(tileNormals.buffer), WebGL.STATIC_DRAW);

        final uvBuffer = gl.createBuffer();
        gl.bindBuffer(WebGL.ARRAY_BUFFER, uvBuffer);
        gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(tileUVs.buffer), WebGL.STATIC_DRAW);

        final tile = M3TerrainTileGeom._(
          tileRow: tr,
          tileCol: tc,
          vertexCount: tileVertCount,
          vertexBuffer: vertexBuffer,
          normalBuffer: normalBuffer,
          uvBuffer: uvBuffer,
          lodFaceIndices: sharedFaceIndices,
          lodEdgeIndices: sharedEdgeIndices,
        );
        tile.localBounding = tb;

        mesh.subMeshes.add(M3SubMesh(tile, material: material ?? M3Material()));
      }
    }

    return M3TiledTerrain._(mesh, tilesX, tilesY, sharedFaceIndices, sharedEdgeIndices);
  }

  /// Builds triangle-strip indices for a single tile of size [tileWidthSegs] × [tileHeightSegs].
  ///
  /// Uses tile-local vertex indices (0 to (tileWidthSegs + 1) * (tileHeightSegs + 1) - 1).
  /// [step] specifies the vertex stride for downsampled LODs (1 for LOD0 32x32, 2 for LOD1 16x16, up to 32 for LOD5 1x1).
  /// Returns [Uint16List] since vertex count per tile fits in uint16.
  static Uint16List buildSharedTileStripIndices(int tileWidthSegs, int tileHeightSegs, {int step = 1}) {
    final int rowStride = tileWidthSegs + 1;
    final int rows = tileHeightSegs ~/ step;
    final int cols = tileWidthSegs ~/ step;

    final int numIndex = (cols + 1) * 2 * rows + 2 * (rows - 1);
    final indices = Uint16List(numIndex);
    int idx = 0;

    for (int r = 0; r < rows; r++) {
      final int i = r * step;
      final int nextI = (r + 1) * step;

      if (r > 0) {
        indices[idx] = indices[idx - 1]; // degenerate: repeat last
        indices[idx + 1] = i * rowStride; // repeat first of next row
        idx += 2;
      }
      for (int c = 0; c <= cols; c++) {
        final int j = c * step;
        indices[idx++] = i * rowStride + j;
        indices[idx++] = nextI * rowStride + j;
      }
    }
    return indices;
  }

  /// Builds wireframe (GL_LINES) indices for a single tile of size [tileWidthSegs] × [tileHeightSegs].
  ///
  /// Uses tile-local vertex indices.
  /// [step] specifies the vertex stride for downsampled LODs.
  static Uint16List buildSharedTileWireIndices(int tileWidthSegs, int tileHeightSegs, {int step = 1}) {
    final int rowStride = tileWidthSegs + 1;
    final int rows = tileHeightSegs ~/ step;
    final int cols = tileWidthSegs ~/ step;

    final int numWire = (cols * (rows + 1) + (cols + 1) * rows) * 2;
    final lines = Uint16List(numWire);
    int idx = 0;

    // Horizontal edges
    for (int r = 0; r <= rows; r++) {
      final int i = r * step;
      for (int c = 0; c < cols; c++) {
        final int j = c * step;
        lines[idx++] = i * rowStride + j;
        lines[idx++] = i * rowStride + (j + step);
      }
    }
    // Vertical edges
    for (int r = 0; r < rows; r++) {
      final int i = r * step;
      for (int c = 0; c <= cols; c++) {
        final int j = c * step;
        lines[idx++] = i * rowStride + j;
        lines[idx++] = (i + step) * rowStride + j;
      }
    }
    return lines;
  }
}

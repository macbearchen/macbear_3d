part of '../geom.dart';

// ---------------------------------------------------------------------------
// M3TerrainTileGeom
// ---------------------------------------------------------------------------

/// A terrain tile whose vertex/normal/UV buffers are **shared** with a parent
/// [M3TerrainGeom] (the "host"). Only the index buffers are owned per-tile.
///
/// Never construct this directly; use [M3TiledTerrain.build] or
/// [M3TiledTerrain.fromHeightField].
class M3TerrainTileGeom extends M3Geom {
  /// Grid row of this tile (Y axis, 0 = top).
  final int tileRow;

  /// Grid column of this tile (X axis, 0 = left).
  final int tileCol;

  M3TerrainTileGeom._({
    required this.tileRow,
    required this.tileCol,
    required int vertexCount,
    required Buffer vertexBuffer,
    required Buffer normalBuffer,
    required Buffer uvBuffer,
  }) {
    _vertexCount = vertexCount;
    _vertexBuffer = vertexBuffer;
    _normalBuffer = normalBuffer;
    _uvBuffer = uvBuffer;
    name = 'TerrainTile_${tileRow}_$tileCol';
  }

  /// Releases only this tile's **own** index buffers.
  ///
  /// The shared VBO buffers are owned by the host [M3TerrainGeom]; they must
  /// not be deleted here. Call [M3TiledTerrain.dispose] to handle full teardown
  /// in the correct order.
  @override
  void dispose() {
    for (final s in _faceIndices) {
      s.dispose();
    }
    for (final s in _edgeIndices) {
      s.dispose();
    }
    _faceIndices.clear();
    _edgeIndices.clear();
    // Null out VBO refs without deleting — host owns them
    _vertexBuffer = null;
    _normalBuffer = null;
    _uvBuffer = null;
  }
}

// ---------------------------------------------------------------------------
// M3TiledTerrain
// ---------------------------------------------------------------------------

/// Result of [M3TiledTerrain.build] / [M3TiledTerrain.fromHeightField].
///
/// Contains the renderable [mesh] (one [M3SubMesh] per tile) and the internal
/// host geometry that owns the shared GPU VBO buffers.
///
/// Always call [dispose] instead of disposing sub-meshes manually, to ensure
/// the shared VBO is released after all tile index buffers.
class M3TiledTerrain {
  final M3TerrainGeom _hostGeom;

  /// The renderable mesh. Contains [tilesX] × [tilesY] sub-meshes.
  final M3Mesh mesh;

  /// Tile columns (X axis).
  final int tilesX;

  /// Tile rows (Y axis).
  final int tilesY;

  /// Total tile count = [tilesX] × [tilesY].
  int get tileCount => tilesX * tilesY;

  M3TiledTerrain._(this._hostGeom, this.mesh, this.tilesX, this.tilesY);

  /// Releases all tile index buffers then the shared VBO.
  void dispose() {
    for (final sub in mesh.subMeshes) {
      sub.geom.dispose(); // tile: own indices only
    }
    _hostGeom.dispose(); // host: shared VBOs
    mesh.subMeshes.clear();
  }

  // -------------------------------------------------------------------------
  // Factory constructors
  // -------------------------------------------------------------------------

  /// Builds a tiled terrain using Perlin noise where all tiles share one VBO.
  ///
  /// The terrain is divided into [tilesX] × [tilesY] tiles where:
  /// - `tilesX = widthSegments / tileWidthSegments`
  /// - `tilesY = heightSegments / tileHeightSegments`
  ///
  /// Both [widthSegments] and [heightSegments] must be exactly divisible by
  /// their respective tile segment counts.
  ///
  /// Example — 1024×1024 terrain, 64×64 tiles → 256 tiles:
  /// ```dart
  /// final terrain = M3TiledTerrain.build(
  ///   200.0, 200.0,
  ///   widthSegments: 1024, heightSegments: 1024,
  ///   tileWidthSegments: 64, tileHeightSegments: 64,
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
  ///   tileWidthSegments: 64, tileHeightSegments: 64,
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

    final tilesX = widthSegments ~/ tileWidthSegments;
    final tilesY = heightSegments ~/ tileHeightSegments;
    final int numVert = (widthSegments + 1) * (heightSegments + 1);

    uvScale ??= Vector2(1, 1);
    final hx = width * 0.5, hy = height * 0.5;

    // 1. Generate all vertices on CPU ----------------------------------------
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

    // 2. Calculate normals ---------------------------------------------------
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

    // 3. Compute global bounding + exact per-tile bounding from CPU vertices --
    final globalBounding = M3Bounding();
    {
      final v0 = Vector3.zero();
      vertices.load(0, v0);
      globalBounding.aabb.min.setFrom(v0);
      globalBounding.aabb.max.setFrom(v0);
      final v = Vector3.zero();
      for (int i = 1; i < numVert; i++) {
        vertices.load(i, v);
        globalBounding.aabb.hullPoint(v);
      }
      globalBounding.aabb.copyCenter(globalBounding.sphere.center);
      globalBounding.sphere.radius = Vector3(hx, hy, maxHeight).length;
    }

    final List<M3Bounding> tileBoundings = [];
    for (int tr = 0; tr < tilesY; tr++) {
      for (int tc = 0; tc < tilesX; tc++) {
        final tb = M3Bounding();
        final int r0 = tr * tileHeightSegments;
        final int r1 = (tr + 1) * tileHeightSegments;
        final int c0 = tc * tileWidthSegments;
        final int c1 = (tc + 1) * tileWidthSegments;

        final v0 = Vector3.zero();
        vertices.load(r0 * (widthSegments + 1) + c0, v0);
        tb.aabb.min.setFrom(v0);
        tb.aabb.max.setFrom(v0);

        final v = Vector3.zero();
        for (int i = r0; i <= r1; i++) {
          for (int j = c0; j <= c1; j++) {
            vertices.load(i * (widthSegments + 1) + j, v);
            tb.aabb.hullPoint(v);
          }
        }
        tb.aabb.copyCenter(tb.sphere.center);
        tb.sphere.radius = tb.aabb.min.distanceTo(tb.aabb.max) * 0.5;
        tileBoundings.add(tb);
      }
    }

    // 4. Upload shared VBO to GPU -------------------------------------------
    final gl = M3AppEngine.instance.renderEngine.gl;

    final vertexBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(vertices.buffer), WebGL.STATIC_DRAW);

    final normalBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, normalBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(normals.buffer), WebGL.STATIC_DRAW);

    final uvBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, uvBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(uvs.buffer), WebGL.STATIC_DRAW);

    // 5. Create host geom (holds VBO, no indices, won't render) -------------
    final hostGeom = M3TerrainGeom._hostOnly(
      vertexCount: numVert,
      vertexBuffer: vertexBuffer,
      normalBuffer: normalBuffer,
      uvBuffer: uvBuffer,
      bounding: globalBounding,
    );

    // 6. Create tile geoms + mesh -------------------------------------------
    final mesh = M3Mesh(null);
    mesh.name = 'TiledTerrain_${tilesX}x$tilesY';
    final mtr = material ?? M3Material();

    for (int tr = 0; tr < tilesY; tr++) {
      for (int tc = 0; tc < tilesX; tc++) {
        final tile = M3TerrainTileGeom._(
          tileRow: tr,
          tileCol: tc,
          vertexCount: numVert,
          vertexBuffer: vertexBuffer,
          normalBuffer: normalBuffer,
          uvBuffer: uvBuffer,
        );
        tile.localBounding = tileBoundings[tr * tilesX + tc];

        // Face indices (triangle strip for this tile, into global vertex space)
        tile._faceIndices.add(
          _M3Indices(
            WebGL.TRIANGLE_STRIP,
            _buildTileStripIndices(tr, tc, tileWidthSegments, tileHeightSegments, widthSegments),
          ),
        );

        // Wireframe indices
        tile._edgeIndices.add(
          _M3Indices(WebGL.LINES, _buildTileWireIndices(tr, tc, tileWidthSegments, tileHeightSegments, widthSegments)),
        );

        mesh.subMeshes.add(M3SubMesh(tile, material: mtr));
      }
    }

    return M3TiledTerrain._(hostGeom, mesh, tilesX, tilesY);
  }

  /// Builds triangle-strip indices for a single tile referencing global vertex indices.
  ///
  /// Uses degenerate triangles to join tile rows within a single draw call.
  /// Always returns [Uint32List] since total vertex count exceeds 65 535 for
  /// large terrains.
  static Uint32List _buildTileStripIndices(
    int tileRow,
    int tileCol,
    int tileWidthSegs,
    int tileHeightSegs,
    int fullWidthSegs,
  ) {
    final int rowStride = fullWidthSegs + 1;
    final int rowStart = tileRow * tileHeightSegs;
    final int colStart = tileCol * tileWidthSegs;

    // (tileWidthSegs+1)*2 per strip row + 2 degenerate joins between rows
    final int numIndex = (tileWidthSegs + 1) * 2 * tileHeightSegs + 2 * (tileHeightSegs - 1);
    final indices = Uint32List(numIndex);
    int idx = 0;

    for (int i = 0; i < tileHeightSegs; i++) {
      if (i > 0) {
        indices[idx] = indices[idx - 1]; // degenerate: repeat last
        indices[idx + 1] = (rowStart + i) * rowStride + colStart; // repeat first of next row
        idx += 2;
      }
      for (int j = 0; j <= tileWidthSegs; j++) {
        indices[idx++] = (rowStart + i) * rowStride + (colStart + j);
        indices[idx++] = (rowStart + i + 1) * rowStride + (colStart + j);
      }
    }
    return indices;
  }

  /// Builds wireframe (GL_LINES) indices for a single tile.
  ///
  /// Generates horizontal edges (along X) and vertical edges (along Y).
  static Uint32List _buildTileWireIndices(
    int tileRow,
    int tileCol,
    int tileWidthSegs,
    int tileHeightSegs,
    int fullWidthSegs,
  ) {
    final int rowStride = fullWidthSegs + 1;
    final int rowStart = tileRow * tileHeightSegs;
    final int colStart = tileCol * tileWidthSegs;

    // horizontal: (tileHeightSegs+1) rows × tileWidthSegs segments
    // vertical:   tileHeightSegs rows × (tileWidthSegs+1) columns
    final int numWire = (tileWidthSegs * (tileHeightSegs + 1) + (tileWidthSegs + 1) * tileHeightSegs) * 2;
    final lines = Uint32List(numWire);
    int idx = 0;

    // Horizontal edges
    for (int i = 0; i <= tileHeightSegs; i++) {
      for (int j = 0; j < tileWidthSegs; j++) {
        lines[idx++] = (rowStart + i) * rowStride + (colStart + j);
        lines[idx++] = (rowStart + i) * rowStride + (colStart + j + 1);
      }
    }
    // Vertical edges
    for (int i = 0; i < tileHeightSegs; i++) {
      for (int j = 0; j <= tileWidthSegs; j++) {
        lines[idx++] = (rowStart + i) * rowStride + (colStart + j);
        lines[idx++] = (rowStart + i + 1) * rowStride + (colStart + j);
      }
    }
    return lines;
  }
}

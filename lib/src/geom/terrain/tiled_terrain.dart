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

  M3TerrainTileGeom._({
    required this.tileRow,
    required this.tileCol,
    required int vertexCount,
    required Buffer vertexBuffer,
    required Buffer normalBuffer,
    required Buffer uvBuffer,
    required _M3Indices sharedFaceIndices,
    required _M3Indices sharedEdgeIndices,
  }) {
    _vertexCount = vertexCount;
    _vertexBuffer = vertexBuffer;
    _normalBuffer = normalBuffer;
    _uvBuffer = uvBuffer;
    _faceIndices.add(sharedFaceIndices);
    _edgeIndices.add(sharedEdgeIndices);
    name = 'TerrainTile_${tileRow}_$tileCol';
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

  final _M3Indices _sharedFaceIndices;
  final _M3Indices _sharedEdgeIndices;

  /// Total tile count = [tilesX] × [tilesY].
  int get tileCount => tilesX * tilesY;

  M3TiledTerrain._(
    this.mesh,
    this.tilesX,
    this.tilesY,
    this._sharedFaceIndices,
    this._sharedEdgeIndices,
  );

  /// Releases all tile VBO buffers then the shared IBO buffers.
  void dispose() {
    for (final sub in mesh.subMeshes) {
      sub.geom.dispose(); // tile: own VBOs only
    }
    _sharedFaceIndices.dispose(); // shared IBO
    _sharedEdgeIndices.dispose();
    mesh.subMeshes.clear();
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

    final tileVertCount = (tileWidthSegments + 1) * (tileHeightSegments + 1);
    assert(
      tileVertCount <= 65536,
      'Tile vertex count ($tileVertCount) exceeds 65,536 limit for uint16 index buffers.',
    );

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

    // 3. Build single shared IBO (Uint16List) for all tiles ------------------
    final sharedFaceIndices = _M3Indices(
      WebGL.TRIANGLE_STRIP,
      _buildSharedTileStripIndices(tileWidthSegments, tileHeightSegments),
    );
    final sharedEdgeIndices = _M3Indices(
      WebGL.LINES,
      _buildSharedTileWireIndices(tileWidthSegments, tileHeightSegments),
    );

    // 4. Create tile geoms + VBO per tile -----------------------------------
    final gl = M3AppEngine.instance.renderEngine.gl;
    final mesh = M3Mesh(null);
    mesh.name = 'TiledTerrain_${tilesX}x$tilesY';
    final mtr = material ?? M3Material();

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
          sharedFaceIndices: sharedFaceIndices,
          sharedEdgeIndices: sharedEdgeIndices,
        );
        tile.localBounding = tb;

        mesh.subMeshes.add(M3SubMesh(tile, material: mtr));
      }
    }

    return M3TiledTerrain._(mesh, tilesX, tilesY, sharedFaceIndices, sharedEdgeIndices);
  }

  /// Builds triangle-strip indices for a single tile of size [tileWidthSegs] × [tileHeightSegs].
  ///
  /// Uses tile-local vertex indices (0 to (tileWidthSegs + 1) * (tileHeightSegs + 1) - 1).
  /// Returns [Uint16List] since vertex count per tile fits in uint16.
  static Uint16List _buildSharedTileStripIndices(
    int tileWidthSegs,
    int tileHeightSegs,
  ) {
    final int rowStride = tileWidthSegs + 1;
    final int numIndex = (tileWidthSegs + 1) * 2 * tileHeightSegs + 2 * (tileHeightSegs - 1);
    final indices = Uint16List(numIndex);
    int idx = 0;

    for (int i = 0; i < tileHeightSegs; i++) {
      if (i > 0) {
        indices[idx] = indices[idx - 1]; // degenerate: repeat last
        indices[idx + 1] = i * rowStride; // repeat first of next row
        idx += 2;
      }
      for (int j = 0; j <= tileWidthSegs; j++) {
        indices[idx++] = i * rowStride + j;
        indices[idx++] = (i + 1) * rowStride + j;
      }
    }
    return indices;
  }

  /// Builds wireframe (GL_LINES) indices for a single tile of size [tileWidthSegs] × [tileHeightSegs].
  ///
  /// Uses tile-local vertex indices.
  static Uint16List _buildSharedTileWireIndices(
    int tileWidthSegs,
    int tileHeightSegs,
  ) {
    final int rowStride = tileWidthSegs + 1;
    final int numWire = (tileWidthSegs * (tileHeightSegs + 1) + (tileWidthSegs + 1) * tileHeightSegs) * 2;
    final lines = Uint16List(numWire);
    int idx = 0;

    // Horizontal edges
    for (int i = 0; i <= tileHeightSegs; i++) {
      for (int j = 0; j < tileWidthSegs; j++) {
        lines[idx++] = i * rowStride + j;
        lines[idx++] = i * rowStride + (j + 1);
      }
    }
    // Vertical edges
    for (int i = 0; i < tileHeightSegs; i++) {
      for (int j = 0; j <= tileWidthSegs; j++) {
        lines[idx++] = i * rowStride + j;
        lines[idx++] = (i + 1) * rowStride + j;
      }
    }
    return lines;
  }
}

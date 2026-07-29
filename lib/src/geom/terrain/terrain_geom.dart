part of '../geom.dart';

/// Procedural terrain geometry.
///
/// Constructors:
/// - Default: Perlin noise-based procedural terrain.
/// - [fromHeightField]: build from a pre-sampled [M3HeightField].
/// - [fromHeightmap] / [fromHeightmapAsset]: convenience wrappers that
///   create a [M3HeightField] then delegate to [fromHeightField].
///
/// For large terrains, prefer [M3TiledTerrain.build] / [M3TiledTerrain.fromHeightField]
/// which produce a shared-VBO tiled mesh suitable for per-tile frustum culling.
class M3TerrainGeom extends M3Geom {
  M3TerrainGeom(
    double width,
    double height, {
    int widthSegments = 64,
    int heightSegments = 64,
    double maxHeight = 5.0,
    double noiseScale = 0.05,
    int octaves = 4,
    Vector2? uvScale,
  }) : this._internal(
         width,
         height,
         (ratioX, ratioY, px, py) {
           double noiseVal = M3Noise.fBm(px * noiseScale, py * noiseScale, octaves: octaves);
           return noiseVal * maxHeight;
         },
         widthSegments: widthSegments,
         heightSegments: heightSegments,
         maxHeight: maxHeight,
         uvScale: uvScale,
       );

  M3TerrainGeom._internal(
    double width,
    double height,
    double Function(double ratioX, double ratioY, double px, double py) heightFunc, {
    int widthSegments = 64,
    int heightSegments = 64,
    double maxHeight = 5.0,
    Vector2? uvScale,
  }) {
    int numVert = (widthSegments + 1) * (heightSegments + 1);
    _init(vertexCount: numVert, withNormals: true, withUV: true);
    name = "Terrain";

    final vertices = _vertices!;
    final uvs = _uvs!;
    final normals = _normals!;
    uvScale = uvScale ?? Vector2(1, 1);

    int index = 0;
    final hx = width * 0.5, hy = height * 0.5;

    // 1. Generate vertices with heights
    for (int i = 0; i <= heightSegments; i++) {
      double ratioY = i.toDouble() / heightSegments;
      double py = hy - height * ratioY;
      for (int j = 0; j <= widthSegments; j++) {
        double ratioX = j.toDouble() / widthSegments;
        double px = width * ratioX - hx;

        double pz = heightFunc(ratioX, ratioY, px, py);

        vertices[index] = Vector3(px, py, pz);
        uvs[index] = Vector2(ratioX * uvScale.x, ratioY * uvScale.y);
        index++;
      }
    }

    // 2. Calculate normals for lighting
    for (int i = 0; i <= heightSegments; i++) {
      for (int j = 0; j <= widthSegments; j++) {
        int idx = i * (widthSegments + 1) + j;

        // simple normal estimation using adjacent vertices
        Vector3 v = vertices[idx];
        Vector3 vn = Vector3(0, 0, 1);

        if (i < heightSegments && j < widthSegments) {
          Vector3 vRight = vertices[idx + 1];
          Vector3 vDown = vertices[idx + (widthSegments + 1)];
          Vector3 dX = vRight - v;
          Vector3 dY = vDown - v;
          vn = dY.cross(dX).normalized();
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

    // 3. Generate indices (Triangle Strip)
    int numIndex = (widthSegments + 1) * 2 * (heightSegments) + 2 * (heightSegments - 1);
    final indices = (_vertexCount > 65535) ? Uint32List(numIndex) : Uint16List(numIndex);
    index = 0;
    for (int i = 0; i < heightSegments; i++) {
      if (i > 0) {
        indices[index] = indices[index - 1]; // repeat prev-index
        indices[index + 1] = i * (widthSegments + 1); // repeat next-index
        index += 2;
      }
      for (int j = 0; j <= widthSegments; j++) {
        indices[index++] = i * (widthSegments + 1) + j;
        indices[index++] = (i + 1) * (widthSegments + 1) + j;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    // 4. Generate wireframe edges (LINES)
    int numWireIndex = ((widthSegments + 1) * heightSegments + widthSegments * (heightSegments + 1)) * 2;
    final lines = (_vertexCount > 65535) ? Uint32List(numWireIndex) : Uint16List(numWireIndex);
    index = 0;
    for (int i = 0; i <= heightSegments; i++) {
      for (int j = 0; j < widthSegments; j++) {
        // horizontal line
        lines[index++] = i * (widthSegments + 1) + j;
        lines[index++] = i * (widthSegments + 1) + j + 1;
      }
    }
    for (int i = 0; i < heightSegments; i++) {
      for (int j = 0; j <= widthSegments; j++) {
        // vertical line
        lines[index++] = i * (widthSegments + 1) + j;
        lines[index++] = (i + 1) * (widthSegments + 1) + j;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINES, lines));

    _createVBO();
    localBounding.sphere.radius = Vector3(hx, hy, maxHeight).length;
  }

  /// Private constructor used by [M3TiledTerrain.build] / [M3TiledTerrain.buildFromHeightField].
  ///
  /// Holds pre-created GPU buffers without owning CPU-side vertex data.
  /// This "host" geom's only purpose is to keep the shared VBO alive.
  M3TerrainGeom._hostOnly({
    required int vertexCount,
    required Buffer vertexBuffer,
    required Buffer normalBuffer,
    required Buffer uvBuffer,
    required M3Bounding bounding,
  }) {
    _vertexCount = vertexCount;
    _vertexBuffer = vertexBuffer;
    _normalBuffer = normalBuffer;
    _uvBuffer = uvBuffer;
    localBounding = bounding;
    name = 'TerrainHost';
  }

  // -------------------------------------------------------------------------
  // fromHeightField / fromHeightmap / fromHeightmapAsset
  // -------------------------------------------------------------------------

  /// Create terrain geometry from a pre-built [M3HeightField].
  ///
  /// The height field's [M3HeightField.widthSegments] and
  /// [M3HeightField.heightSegments] drive the mesh grid resolution.
  /// Heights are read directly from [M3HeightField.data] (already scaled by
  /// the field's own [M3HeightField.heightScale]).
  static M3TerrainGeom fromHeightField(
    M3HeightField hf,
    double width,
    double height, {
    double maxHeight = 5.0,
    Vector2? uvScale,
  }) {
    final geom = M3TerrainGeom._internal(
      width,
      height,
      (ratioX, ratioY, px, py) {
        final int j = (ratioX * hf.widthSegments).round().clamp(0, hf.widthSegments);
        final int i = (ratioY * hf.heightSegments).round().clamp(0, hf.heightSegments);
        return hf.data[i * (hf.widthSegments + 1) + j] * hf.heightScale;
      },
      widthSegments: hf.widthSegments,
      heightSegments: hf.heightSegments,
      maxHeight: maxHeight,
      uvScale: uvScale,
    );
    geom.name = "TerrainFromHeightField";
    return geom;
  }

  /// Create terrain geometry from an [img.Image] heightmap.
  ///
  /// Internally builds a [M3HeightField.fromHeightmap] then calls
  /// [fromHeightField]. Works for both 8-bit and 16-bit source images.
  static M3TerrainGeom fromHeightmap(
    img.Image image,
    double width,
    double height, {
    int widthSegments = 64,
    int heightSegments = 64,
    double maxHeight = 5.0,
    Vector2? uvScale,
  }) {
    final hf = M3HeightField.fromHeightmap(
      image,
      width,
      height,
      widthSegments: widthSegments,
      heightSegments: heightSegments,
      maxHeight: maxHeight,
    );
    final geom = fromHeightField(hf, width, height, maxHeight: maxHeight, uvScale: uvScale);
    geom.name = "TerrainFromHeightmap";
    return geom;
  }

  /// Create terrain geometry from an asset path to a heightmap image.
  static Future<M3TerrainGeom> fromHeightmapAsset(
    String assetPath,
    double width,
    double height, {
    int widthSegments = 64,
    int heightSegments = 64,
    double maxHeight = 5.0,
    Vector2? uvScale,
  }) async {
    final buffer = await M3ResourceManager.loadBuffer(assetPath);
    final decoded = img.decodeImage(buffer.asUint8List());
    if (decoded == null) {
      throw Exception("Failed to decode heightmap image: $assetPath");
    }
    return fromHeightmap(
      decoded,
      width,
      height,
      widthSegments: widthSegments,
      heightSegments: heightSegments,
      maxHeight: maxHeight,
      uvScale: uvScale,
    );
  }
}

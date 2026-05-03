part of '../geom.dart';

/// Procedural terrain geometry using Perlin noise.
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

        // noise generation
        double noiseVal = M3Noise.fBm(px * noiseScale, py * noiseScale, octaves: octaves);
        double pz = noiseVal * maxHeight;

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
    final indices = Uint16List(numIndex);
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
    final lines = Uint16List(numWireIndex);
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
}

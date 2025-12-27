part of 'geom.dart';

/// glTF 模型幾何資料
/// 從 GltfPrimitive 建構 GPU-ready VBO/IBO
class M3GltfGeom extends M3Geom {
  M3GltfGeom.fromPrimitive(GltfPrimitive primitive) {
    final positions = primitive.getPositions();
    if (positions == null || positions.isEmpty) {
      throw Exception('glTF primitive has no POSITION attribute');
    }

    final normals = primitive.getNormals();
    final uvs = primitive.getTexCoords();
    final indices = primitive.getIndices();

    final vertexCount = primitive.vertexCount;

    _init(vertexCount: vertexCount, withNormals: normals != null, withUV: uvs != null);

    // Copy positions
    for (int i = 0; i < positions.length; i++) {
      _vertices!.buffer[i] = positions[i];
    }

    // Copy normals
    if (normals != null && _normals != null) {
      for (int i = 0; i < normals.length; i++) {
        _normals!.buffer[i] = normals[i];
      }
    }

    // Copy UVs
    if (uvs != null && _uvs != null) {
      for (int i = 0; i < uvs.length; i++) {
        _uvs!.buffer[i] = uvs[i];
      }
    }

    // Copy Joints
    final joints = primitive.getJoints();
    if (joints != null && _joints != null) {
      for (int i = 0; i < joints.length; i++) {
        _joints![i] = joints[i];
      }
    }

    // Copy Weights
    final weights = primitive.getWeights();
    if (weights != null && _weights != null) {
      for (int i = 0; i < weights.length; i++) {
        _weights![i] = weights[i];
      }
    }

    _createVBO();

    // Create face indices
    if (indices != null && indices.isNotEmpty) {
      // glTF indices
      final indicesArray = Uint16Array.fromList(indices.map((e) => e.clamp(0, 65535)).toList());
      _faceIndices.add(_M3Indices(_glMode(primitive.mode), indicesArray));
    } else {
      // Non-indexed geometry: generate sequential indices
      final sequentialIndices = List<int>.generate(vertexCount, (i) => i);
      final indicesArray = Uint16Array.fromList(sequentialIndices);
      _faceIndices.add(_M3Indices(_glMode(primitive.mode), indicesArray));
    }

    // Create wireframe indices for debugging
    if (indices != null && indices.isNotEmpty && primitive.mode == 4) {
      List<int> lineIndices = [];
      for (int i = 0; i < indices.length - 2; i += 3) {
        lineIndices.add(indices[i]);
        lineIndices.add(indices[i + 1]);
        lineIndices.add(indices[i + 1]);
        lineIndices.add(indices[i + 2]);
        lineIndices.add(indices[i + 2]);
        lineIndices.add(indices[i]);
      }
      _edgeIndices.add(_M3Indices(WebGL.LINES, Uint16Array.fromList(lineIndices)));
    }

    // Apply material logic moved to M3Mesh construction
  }

  /// 從 glTF mode 轉換為 WebGL primitive type
  static int _glMode(int gltfMode) {
    switch (gltfMode) {
      case 0:
        return WebGL.POINTS;
      case 1:
        return WebGL.LINES;
      case 2:
        return WebGL.LINE_LOOP;
      case 3:
        return WebGL.LINE_STRIP;
      case 4:
        return WebGL.TRIANGLES;
      case 5:
        return WebGL.TRIANGLE_STRIP;
      case 6:
        return WebGL.TRIANGLE_FAN;
      default:
        return WebGL.TRIANGLES;
    }
  }
}

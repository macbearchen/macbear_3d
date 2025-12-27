part of 'geom.dart';

class M3PlaneGeom extends M3Geom {
  // sample callback to Z value
  static double formulaZ(double x, double y) {
    return 0.0;
  }

  // vertex order: row-major align by X-axis (-sx/2 ~ sx/2), column from (sy/2 ~ -sy/2)
  // default face-flip(false) means face-up; face-flip(true) means face-down
  M3PlaneGeom(
    double sx,
    double sy,
    int segmentX,
    int segmentY,
    Vector2 mapping, {
    Function(double, double)? callback,
    bool bFaceFlip = false,
  }) {
    int numVert = (segmentX + 1) * (segmentY + 1);
    // initialize
    _init(vertexCount: numVert, withNormals: true, withUV: true);
    name = "Plane";

    // vertices
    final vertices = _vertices!;
    final uvs = _uvs!;
    final normals = _normals!;

    Vector3 vn = Vector3(0, 0, (bFaceFlip) ? -1 : 1);
    double x, y, z = 0;
    int i, j, index = 0;
    final hx = sx * 0.5, hy = sy * 0.5;

    // vertices: position, texUV
    for (i = 0; i <= segmentY; i++) {
      double ratioY = i.toDouble() / segmentY;
      y = hy - sy * ratioY;
      for (j = 0; j <= segmentX; j++) {
        double ratioX = j.toDouble() / segmentX;
        x = sx * ratioX - hx;
        if (callback != null) {
          z = callback(x, y);
        }
        vertices[index] = Vector3(x, y, z);
        uvs[index] = Vector2(ratioX * mapping.x, ratioY * mapping.y);

        index++;
      }
    }
    // normals
    index = 0;
    for (i = 0; i < segmentY; i++) {
      for (j = 0; j <= segmentX; j++) {
        if (j != segmentX) {
          Vector3 dirX = vertices[index] - vertices[index + 1];
          Vector3 dirY = vertices[index] - vertices[index + segmentX + 1];
          vn = dirY.cross(dirX).normalized();
        } else {
          vn = normals[index - 1]; // end-dot same as previous
        }
        normals[index] = vn;

        index++;
      }
    }
    // normals end-line same as previous
    for (j = 0; j <= segmentX; j++) {
      vn = normals[index - segmentX - 1];
      normals[index] = vn;

      index++;
    }

    // vertex buffer object
    _createVBO();

    // solid: triangle-strip
    int numIndex = (segmentX + 1) * 2 * (segmentY) + 2 * (segmentY - 1);
    if (bFaceFlip) {
      // face-flip
      numIndex++;
    }

    final indices = Uint16Array(numIndex);
    index = 0;
    if (bFaceFlip) {
      // face-flip
      indices[index] = 0;
      index++;
    }

    for (i = 0; i < segmentY; i++) {
      if (i > 0) {
        indices[index] = indices[index - 1]; // repeat prev-index
        indices[index + 1] = i * (segmentX + 1); // repeat next-index
        index += 2;
      }
      for (j = 0; j <= segmentX; j++) {
        indices[index] = i * (segmentX + 1) + j;
        indices[index + 1] = indices[index] + (segmentX + 1);
        index += 2;
      }
    }

    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    // wireframe edges
    numIndex = ((segmentX + 1) * segmentY + segmentX * (segmentY + 1)) * 2;
    final lines = Uint16Array(numIndex);
    index = 0;
    for (i = 0; i <= segmentY; i++) {
      for (j = 0; j < segmentX; j++) {
        // horizontal line align by Y-axis
        lines[index] = i * (segmentX + 1) + j;
        lines[index + 1] = lines[index] + 1;
        index += 2;
      }
    }
    for (i = 0; i < segmentY; i++) {
      for (j = 0; j <= segmentX; j++) {
        // vertical line align by X-axis
        lines[index] = i * (segmentX + 1) + j;
        lines[index + 1] = lines[index] + (segmentX + 1);
        index += 2;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINES, lines));
  }
}

part of 'geom.dart';

/// A subdivided plane geometry with configurable segments and optional height mapping.
///
/// Supports UV scaling, face flipping, and custom vertex callbacks for terrain generation.
class M3PlaneGeom extends M3Geom {
  // sample callback to Z value
  static double formulaZ(double x, double y) {
    return 0.0;
  }

  // vertex order: row-major align by X-axis (-sx/2 ~ sx/2), column from (sy/2 ~ -sy/2)
  // default face-flip(false) means face-up; face-flip(true) means face-down
  M3PlaneGeom(
    double width,
    double height, {
    int widthSegments = 6,
    int heightSegments = 6,
    Vector2? uvScale,
    Function(double x, double y)? onVertex,
    bool flipFace = false,
  }) {
    int numVert = (widthSegments + 1) * (heightSegments + 1);
    // initialize
    _init(vertexCount: numVert, withNormals: true, withUV: true);
    name = "Plane";
    cullingRadius = Vector2(width, height).length / 2;

    // vertices
    final vertices = _vertices!;
    final uvs = _uvs!;
    final normals = _normals!;
    uvScale = uvScale ?? Vector2(1, 1);

    Vector3 vn = Vector3(0, 0, (flipFace) ? -1 : 1);
    double x, y, z = 0;
    int i, j, index = 0;
    final hx = width * 0.5, hy = height * 0.5;

    // vertices: position, texUV
    for (i = 0; i <= heightSegments; i++) {
      double ratioY = i.toDouble() / heightSegments;
      y = hy - height * ratioY;
      for (j = 0; j <= widthSegments; j++) {
        double ratioX = j.toDouble() / widthSegments;
        x = width * ratioX - hx;
        if (onVertex != null) {
          z = onVertex(x, y);
        }
        vertices[index] = Vector3(x, y, z);
        uvs[index] = Vector2(ratioX * uvScale.x, ratioY * uvScale.y);

        index++;
      }
    }
    // normals
    index = 0;
    for (i = 0; i < heightSegments; i++) {
      for (j = 0; j <= widthSegments; j++) {
        if (j != widthSegments) {
          Vector3 dirX = vertices[index] - vertices[index + 1];
          Vector3 dirY = vertices[index] - vertices[index + widthSegments + 1];
          vn = dirY.cross(dirX).normalized();
        } else {
          vn = normals[index - 1]; // end-dot same as previous
        }
        normals[index] = vn;

        index++;
      }
    }
    // normals end-line same as previous
    for (j = 0; j <= widthSegments; j++) {
      vn = normals[index - widthSegments - 1];
      normals[index] = vn;

      index++;
    }

    // vertex buffer object
    _createVBO();

    // solid: triangle-strip
    int numIndex = (widthSegments + 1) * 2 * (heightSegments) + 2 * (heightSegments - 1);
    if (flipFace) {
      // face-flip
      numIndex++;
    }

    final indices = Uint16Array(numIndex);
    index = 0;
    if (flipFace) {
      // face-flip
      indices[index] = 0;
      index++;
    }

    for (i = 0; i < heightSegments; i++) {
      if (i > 0) {
        indices[index] = indices[index - 1]; // repeat prev-index
        indices[index + 1] = i * (widthSegments + 1); // repeat next-index
        index += 2;
      }
      for (j = 0; j <= widthSegments; j++) {
        indices[index] = i * (widthSegments + 1) + j;
        indices[index + 1] = indices[index] + (widthSegments + 1);
        index += 2;
      }
    }

    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    // wireframe edges
    numIndex = ((widthSegments + 1) * heightSegments + widthSegments * (heightSegments + 1)) * 2;
    final lines = Uint16Array(numIndex);
    index = 0;
    for (i = 0; i <= heightSegments; i++) {
      for (j = 0; j < widthSegments; j++) {
        // horizontal line align by Y-axis
        lines[index] = i * (widthSegments + 1) + j;
        lines[index + 1] = lines[index] + 1;
        index += 2;
      }
    }
    for (i = 0; i < heightSegments; i++) {
      for (j = 0; j <= widthSegments; j++) {
        // vertical line align by X-axis
        lines[index] = i * (widthSegments + 1) + j;
        lines[index + 1] = lines[index] + (widthSegments + 1);
        index += 2;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINES, lines));
  }
}

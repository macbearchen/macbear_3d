part of 'geom.dart';

// segmentRow divide as pie on XY-plane; segmentZ divide by Z-axis
// vertex order: from top to bottom, CCW by each row
class M3SphereGeom extends M3Geom {
  M3SphereGeom(double rw, double rh, int segmentRow, int segmentZ) {
    segmentRow = max(segmentRow, 3);
    segmentZ = max(segmentRow, 2);
    int numVert = (segmentRow + 1) * (segmentZ + 1);

    // initialize
    _init(vertexCount: numVert, withNormals: true, withUV: true);
    name = "Sphere";

    // vertices
    final vertices = _vertices!;
    final normals = _normals!;
    final uvs = _uvs!;
    Vector3 vn = Vector3.zero();

    double x, y, z;
    int i, j, index = 0;
    final cotan = (rw * rw) / (rh * rh);
    // vertices: position, normal, texUV
    for (i = 0; i <= segmentZ; i++) {
      final ratioB = i / segmentZ;
      final angleB = pi * ratioB;
      final radius = rw * sin(angleB);
      if (0 == i) {
        z = rh;
      } else if (segmentZ == i) {
        z = -rh;
      } else {
        z = rh * cos(angleB);
      }

      for (j = 0; j <= segmentRow; j++) {
        final ratioA = j / segmentRow;
        if (0 == j || segmentRow == j) {
          x = radius;
          y = 0;
        } else {
          final angleA = pi * 2 * ratioA;
          x = radius * cos(angleA);
          y = radius * sin(angleA);
        }
        vn = Vector3(x, y, z * cotan).normalized();

        vertices[index] = Vector3(x, y, z);
        normals[index] = vn;
        uvs[index] = Vector2(ratioA, 1.0 - ratioB);

        index++;
      }
    }
    // vertex buffer object
    _createVBO();

    // solid: triangle-strip
    int numIndex = (segmentRow + 1) * 2 * segmentZ;
    Uint16Array indices = Uint16Array(numIndex);
    index = 0;

    int startVert;
    for (i = 0; i < segmentZ; i++) {
      startVert = (segmentRow + 1) * i;
      for (j = 0; j <= segmentRow; j++) {
        indices[index] = startVert + j;
        indices[index + 1] = indices[index] + (segmentRow + 1);
        index += 2;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    // wireframe edges
    numIndex = ((segmentRow + 1) * (segmentZ - 1) + 2) + ((segmentRow - 1) * (segmentZ + 1));
    final lines = Uint16Array(numIndex);
    index = 0;
    lines[0] = 0;
    for (i = 1; i < segmentZ; i++) // skip top and bottom, because only single dot there
    {
      for (j = 0; j <= segmentRow; j++) {
        index++;
        lines[index] = (segmentRow + 1) * i + j;
      }
    }
    startVert = lines[index] + 1;
    index++;
    lines[index] = startVert;
    for (j = 1; j < segmentRow; j++) // skip first and last of vertical slice
    {
      for (i = 0; i <= segmentZ; i++) {
        if (j % 2 != 0) {
          startVert = (segmentRow + 1) * (segmentZ - i) + j; // reverse order
        } else {
          startVert = (segmentRow + 1) * i + j; // common order
        }

        index++;
        lines[index] = startVert;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINE_STRIP, lines));
  }
}

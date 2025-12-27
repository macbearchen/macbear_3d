part of 'geom.dart';

// segmentRow divide as pie on XY-plane; segmentZ divide by Z-axis
// vertex order: from top to bottom, CCW by each row
class M3CylinderGeom extends M3Geom {
  M3CylinderGeom(double rtop, double rbottom, double h, int segmentCircle, int segmentZ) {
    segmentCircle = max(segmentCircle, 3);
    int numVert = (segmentCircle + 1) * (segmentZ + 1) + segmentCircle * 2;

    // initialize
    _init(vertexCount: numVert, withNormals: true, withUV: true);
    name = "Cylinder";

    // vertices: position, normal, texture coordinate(u,v)
    final vertices = _vertices!;
    final normals = _normals!;
    final uvs = _uvs!;
    Vector3 vn = Vector3.zero();
    double x, y, z;
    int i, j, index = 0;
    double cotan = (rbottom - rtop) / h;
    for (i = 0; i <= segmentZ; i++) {
      final ratio = i / segmentZ;
      final radius = rtop * (1.0 - ratio) + rbottom * ratio;
      z = h * (0.5 - ratio);
      for (j = 0; j <= segmentCircle; j++) {
        double ratioA = j / segmentCircle;
        double angleA = pi * 2 * ratioA;
        x = cos(angleA);
        y = sin(angleA);
        vn = Vector3(x, y, cotan).normalized();

        x = radius * x;
        y = radius * y;
        vertices[index] = Vector3(x, y, z);
        normals[index] = vn;
        uvs[index] = Vector2(ratioA, (1 - ratio) * 0.5);

        index++;
      }
    }
    // capped top and bottom
    for (i = 0; i < 2; i++) {
      final fDir = (i != 0) ? -1.0 : 1.0;
      final radius = (i != 0) ? rbottom : rtop;
      final uvZero = Vector2(0.25 + i * 0.5, 0.75);
      for (j = 0; j < segmentCircle; j++) {
        final angleA = pi * 2 * j / segmentCircle;
        x = cos(angleA);
        y = sin(angleA);

        vertices[index] = Vector3(x * radius, y * radius, h * 0.5 * fDir);
        normals[index] = Vector3(0, 0, fDir);
        uvs[index] = Vector2(x, y) * 0.25 + uvZero;

        index++;
      }
    }
    // vertex buffer object
    _createVBO();

    // solid: triangle-strip for round-side
    int numIndex = (segmentCircle + 1) * 2 * segmentZ;
    Uint16Array indices = Uint16Array(numIndex);
    index = 0;

    int startVert;
    for (i = 0; i < segmentZ; i++) {
      startVert = (segmentCircle + 1) * i;
      for (j = 0; j <= segmentCircle; j++) {
        indices[index] = startVert + j;
        indices[index + 1] = indices[index] + (segmentCircle + 1);
        index += 2;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    index = 0;
    numIndex = segmentCircle * 3 * 2;
    indices = Uint16Array(numIndex);
    for (i = 0; i < 2; i++) {
      startVert = (segmentCircle + 1) * (segmentZ + 1) + i * segmentCircle;

      // solid: triangle for capped-top/bottom
      for (j = 0; j < segmentCircle - 2; j++) {
        int next1 = 1, next2 = 2;
        if (0 != i) {
          next1 = 2;
          next2 = 1;
        }
        indices[index] = startVert;
        indices[index + next1] = startVert + j + 1;
        indices[index + next2] = startVert + j + 2;
        index += 3;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLES, indices));

    // wireframe edges
    numIndex = ((segmentCircle + 1) * (segmentZ + 1));
    final lines = Uint16Array(numIndex);
    index = 0;

    for (i = 0; i <= segmentZ; i++) // circle for top to bottom
    {
      for (j = 0; j <= segmentCircle; j++) {
        lines[index] = (segmentCircle + 1) * i + j;
        index++;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINE_STRIP, lines));

    for (j = 1; j < segmentCircle; j++) // vertical slice
    {
      final lines = Uint16Array(segmentZ + 1);
      index = 0;

      for (i = 0; i <= segmentZ; i++) {
        startVert = (segmentCircle + 1) * i + j;
        lines[index] = startVert;
        index++;
      }
      _edgeIndices.add(_M3Indices(WebGL.LINE_STRIP, lines));
    }
  }
}

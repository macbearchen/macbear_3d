part of 'geom.dart';

// radiusSegments divide as pie on XY-plane; heightSegments divide by Z-axis
// vertex order: from top to bottom, CCW by each row
class M3CylinderGeom extends M3Geom {
  M3CylinderGeom(
    double topRadius,
    double bottomRadius,
    double height, {
    int radiusSegments = M3Geom.radialSegments,
    int heightSegments = 1,
  }) {
    radiusSegments = max(radiusSegments, 3);
    int numVert = (radiusSegments + 1) * (heightSegments + 1) + radiusSegments * 2;

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
    double cotan = (bottomRadius - topRadius) / height;
    for (i = 0; i <= heightSegments; i++) {
      final ratio = i / heightSegments;
      final radius = topRadius * (1.0 - ratio) + bottomRadius * ratio;
      z = height * (0.5 - ratio);
      for (j = 0; j <= radiusSegments; j++) {
        double ratioA = j / radiusSegments;
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
      final radius = (i != 0) ? bottomRadius : topRadius;
      final uvZero = Vector2(0.25 + i * 0.5, 0.75);
      for (j = 0; j < radiusSegments; j++) {
        final angleA = pi * 2 * j / radiusSegments;
        x = cos(angleA);
        y = sin(angleA);

        vertices[index] = Vector3(x * radius, y * radius, height * 0.5 * fDir);
        normals[index] = Vector3(0, 0, fDir);
        uvs[index] = Vector2(x, y) * 0.25 + uvZero;

        index++;
      }
    }
    // vertex buffer object
    _createVBO();

    // solid: triangle-strip for round-side
    int numIndex = (radiusSegments + 1) * 2 * heightSegments;
    Uint16Array indices = Uint16Array(numIndex);
    index = 0;

    int startVert;
    for (i = 0; i < heightSegments; i++) {
      startVert = (radiusSegments + 1) * i;
      for (j = 0; j <= radiusSegments; j++) {
        indices[index] = startVert + j;
        indices[index + 1] = indices[index] + (radiusSegments + 1);
        index += 2;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLE_STRIP, indices));

    index = 0;
    numIndex = radiusSegments * 3 * 2;
    indices = Uint16Array(numIndex);
    for (i = 0; i < 2; i++) {
      startVert = (radiusSegments + 1) * (heightSegments + 1) + i * radiusSegments;

      // solid: triangle for capped-top/bottom
      for (j = 0; j < radiusSegments - 2; j++) {
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
    numIndex = ((radiusSegments + 1) * (heightSegments + 1));
    final lines = Uint16Array(numIndex);
    index = 0;

    for (i = 0; i <= heightSegments; i++) // circle for top to bottom
    {
      for (j = 0; j <= radiusSegments; j++) {
        lines[index] = (radiusSegments + 1) * i + j;
        index++;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINE_STRIP, lines));

    for (j = 1; j < radiusSegments; j++) // vertical slice
    {
      final lines = Uint16Array(heightSegments + 1);
      index = 0;

      for (i = 0; i <= heightSegments; i++) {
        startVert = (radiusSegments + 1) * i + j;
        lines[index] = startVert;
        index++;
      }
      _edgeIndices.add(_M3Indices(WebGL.LINE_STRIP, lines));
    }
  }
}

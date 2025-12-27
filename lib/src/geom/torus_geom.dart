part of 'geom.dart';

class M3TorusGeom extends M3Geom {
  M3TorusGeom({
    double radius = 1.0, // R
    double tube = 0.4, // r
    int radialSegments = 32,
    int tubularSegments = 16,
  }) {
    final vetrexCount = (radialSegments + 1) * (tubularSegments + 1);
    _vertices = Vector3List(vetrexCount);
    _normals = Vector3List(vetrexCount);
    _uvs = Vector2List(vetrexCount);

    final vertices = _vertices!;
    final normals = _normals!;
    final uvs = _uvs!;
    int index = 0;

    // vertices: position, normal, texture coordinate(u,v)
    for (int i = 0; i <= radialSegments; i++) {
      final u = i / radialSegments * pi * 2;

      for (int j = 0; j <= tubularSegments; j++) {
        final v = j / tubularSegments * pi * 2;

        final x = (radius + tube * cos(v)) * cos(u);
        final y = (radius + tube * cos(v)) * sin(u);
        final z = tube * sin(v);

        vertices[index] = Vector3(x, y, z);

        final nx = cos(v) * cos(u);
        final ny = cos(v) * sin(u);
        final nz = sin(v);
        normals[index] = Vector3(nx, ny, nz);

        uvs[index] = Vector2(i / radialSegments, j / tubularSegments);

        index++;
      }
    }
    // vertex buffer object
    _createVBO();

    // solid: triangle-strip for round-side
    final numIndex = radialSegments * tubularSegments * 3 * 2;
    final indices = Uint16Array(numIndex);
    index = 0;

    final row = tubularSegments + 1;
    for (int i = 0; i < radialSegments; i++) {
      for (int j = 0; j < tubularSegments; j++) {
        final a = i * row + j;
        final b = (i + 1) * row + j;
        final c = a + 1;
        final d = b + 1;

        indices[index] = a;
        indices[index + 1] = b;
        indices[index + 2] = d;
        indices[index + 3] = a;
        indices[index + 4] = d;
        indices[index + 5] = c;
        index += 6;
      }
    }
    _faceIndices.add(_M3Indices(WebGL.TRIANGLES, indices));

    // wireframe edges
    final numLineIndex = radialSegments * tubularSegments * 2 * 2;
    final lineIndices = Uint16Array(numLineIndex);
    index = 0;

    for (int i = 0; i < radialSegments; i++) {
      for (int j = 0; j < tubularSegments; j++) {
        final a = i * row + j;
        final b = (i + 1) * row + j;
        final c = a + 1;

        lineIndices[index] = a;
        lineIndices[index + 1] = b;
        lineIndices[index + 2] = a;
        lineIndices[index + 3] = c;

        index += 4;
      }
    }
    _edgeIndices.add(_M3Indices(WebGL.LINES, lineIndices));
  }
}

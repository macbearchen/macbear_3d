part of '../geom.dart';

/// A torus (donut) geometry with configurable major and minor radii.
///
/// The torus lies in the XY plane with the tube wrapped around the Z axis.
class M3TorusGeom extends M3Geom {
  M3TorusGeom(
    double radius, // R
    double tube, { // r
    int radialSegments = M3Geom.radialSegments,
    int tubularSegments = M3Geom.radialSegments,
  }) {
    radialSegments = max(radialSegments, 3);
    tubularSegments = max(tubularSegments, 3);
    final vetrexCount = (radialSegments + 1) * (tubularSegments + 1);

    // initialize
    _init(vertexCount: vetrexCount, withNormals: true, withUV: true);
    name = "Torus";

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
    localBounding.sphere.radius = radius + tube;

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

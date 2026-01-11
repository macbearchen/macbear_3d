part of '../geom.dart';

/// A four-sided pyramid geometry with a rectangular base and apex.
///
/// The base is centered at Z=-depth/2 and the apex is at Z=+depth/2.
class M3PyramidGeom extends M3Geom {
  M3PyramidGeom(double width, double height, double depth) {
    // initialize
    _init(vertexCount: 16, withNormals: true, withUV: true);
    name = "Pyramid";
    double hx = width / 2;
    double hy = height / 2;
    double hz = depth / 2;

    // vertices
    final vertices = _vertices!;
    vertices[0] = Vector3(-hx, -hy, -hz);
    vertices[1] = Vector3(hx, -hy, -hz);
    vertices[2] = Vector3(-hx, hy, -hz);
    vertices[3] = Vector3(hx, hy, -hz);

    vertices[4] = Vector3(0, 0, hz);
    vertices[5] = vertices[0];
    vertices[6] = vertices[1];

    vertices[7] = vertices[4];
    vertices[8] = vertices[1];
    vertices[9] = vertices[3];

    vertices[10] = vertices[4];
    vertices[11] = vertices[3];
    vertices[12] = vertices[2];

    vertices[13] = vertices[4];
    vertices[14] = vertices[2];
    vertices[15] = vertices[0];

    // normals
    if (_normals != null) {
      final normals = _normals!;
      Vector3 negativeZ = Vector3(0, 0, -1);

      normals[0] = negativeZ;
      normals[1] = negativeZ;
      normals[2] = negativeZ;
      normals[3] = negativeZ;

      final dir0 = vertices[0] - vertices[4];
      final dir1 = vertices[1] - vertices[4];
      final dir2 = vertices[2] - vertices[4];
      final dir3 = vertices[3] - vertices[4];

      normals[4] = dir0.cross(dir1).normalized();
      normals[5] = normals[4];
      normals[6] = normals[4];

      normals[7] = dir1.cross(dir3).normalized();
      normals[8] = normals[7];
      normals[9] = normals[7];

      normals[10] = dir3.cross(dir2).normalized();
      normals[11] = normals[10];
      normals[12] = normals[10];

      normals[13] = dir2.cross(dir0).normalized();
      normals[14] = normals[13];
      normals[15] = normals[13];
    }

    // texture coordinate(u,v)
    if (_uvs != null) {
      final uvs = _uvs!;

      uvs[0] = Vector2(0.5, 0);
      uvs[1] = Vector2(0, 0.5);
      uvs[2] = Vector2(1, 0.5);
      uvs[3] = Vector2(0.5, 1);

      uvs[4] = Vector2(0, 0);
      uvs[5] = uvs[0];
      uvs[6] = uvs[1];

      uvs[7] = Vector2(0, 1);
      uvs[8] = uvs[1];
      uvs[9] = uvs[3];

      uvs[10] = Vector2(1, 1);
      uvs[11] = uvs[3];
      uvs[12] = uvs[2];

      uvs[13] = Vector2(1, 0);
      uvs[14] = uvs[2];
      uvs[15] = uvs[0];
    }
    // vertex buffer object
    _createVBO();
    localBounding.sphere.radius = Vector3(hx, hy, hz).length;

    // solid faces
    _faceIndices.add(
      _M3Indices(
        WebGL.TRIANGLES,
        Uint16Array.fromList([
          0, 2, 1, 1, 2, 3, // buttom face
          4, 5, 6, // back face
          7, 8, 9, // right face
          10, 11, 12, // front face
          13, 14, 15, // left face
        ]),
      ),
    );

    // wireframe edges
    _edgeIndices.add(
      _M3Indices(
        WebGL.LINES,
        Uint16Array.fromList([
          0, 1, 1, 3, 3, 2, 2, 0, // bottom part
          4, 0, 4, 1, 4, 2, 4, 3, // side parts
        ]),
      ),
    );
  }
}

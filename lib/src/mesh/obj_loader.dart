import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math.dart';
import '../geom/geom.dart';

class M3ObjLoader {
  static Future<M3Geom> load(String path) async {
    final data = await rootBundle.loadString('assets/$path');
    return parse(data, path);
  }

  static M3Geom parse(String data, String name) {
    List<Vector3> vertices = [];
    List<Vector3> normals = [];
    List<Vector2> uvs = [];

    List<int> indices = [];
    List<double> finalVertices = [];
    List<double> finalNormals = [];
    List<double> finalUvs = [];

    // Temporary lists to store unique vertex combinations
    Map<String, int> uniqueVertices = {};

    final lines = data.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split(RegExp(r'\s+'));
      final type = parts[0];

      if (type == 'v') {
        vertices.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      } else if (type == 'vn') {
        normals.add(Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3])));
      } else if (type == 'vt') {
        uvs.add(Vector2(double.parse(parts[1]), double.parse(parts[2])));
      } else if (type == 'f') {
        // Triangulate faces (fan)
        for (int i = 1; i < parts.length - 1; i++) {
          _processVertex(
            parts[1],
            vertices,
            normals,
            uvs,
            uniqueVertices,
            indices,
            finalVertices,
            finalNormals,
            finalUvs,
          );
          _processVertex(
            parts[i],
            vertices,
            normals,
            uvs,
            uniqueVertices,
            indices,
            finalVertices,
            finalNormals,
            finalUvs,
          );
          _processVertex(
            parts[i + 1],
            vertices,
            normals,
            uvs,
            uniqueVertices,
            indices,
            finalVertices,
            finalNormals,
            finalUvs,
          );
        }
      }
    }

    final geom = M3ObjGeom(finalVertices, finalNormals, finalUvs, indices);
    geom.name = name;
    return geom;
  }

  static void _processVertex(
    String vertexData,
    List<Vector3> vertices,
    List<Vector3> normals,
    List<Vector2> uvs,
    Map<String, int> uniqueVertices,
    List<int> indices,
    List<double> finalVertices,
    List<double> finalNormals,
    List<double> finalUvs,
  ) {
    if (uniqueVertices.containsKey(vertexData)) {
      indices.add(uniqueVertices[vertexData]!);
      return;
    }

    final parts = vertexData.split('/');
    final vIndex = int.parse(parts[0]) - 1;
    final vtIndex = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) - 1 : -1;
    final vnIndex = parts.length > 2 && parts[2].isNotEmpty ? int.parse(parts[2]) - 1 : -1;

    final v = vertices[vIndex];
    finalVertices.addAll([v.x, v.y, v.z]);

    if (vnIndex >= 0) {
      final vn = normals[vnIndex];
      finalNormals.addAll([vn.x, vn.y, vn.z]);
    } else {
      finalNormals.addAll([0, 0, 1]); // Default normal
    }

    if (vtIndex >= 0) {
      final vt = uvs[vtIndex];
      finalUvs.addAll([vt.x, vt.y]);
    } else {
      finalUvs.addAll([0, 0]); // Default UV
    }

    int newIndex = uniqueVertices.length;
    uniqueVertices[vertexData] = newIndex;
    indices.add(newIndex);
  }
}

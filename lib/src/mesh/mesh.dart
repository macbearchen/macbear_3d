import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math.dart';

import '../geom/geom.dart';
import '../gltf/gltf_loader.dart';
import '../texture/material.dart';
import 'obj_loader.dart';

class M3Skin {
  final List<Matrix4> boneMatrices;
  final List<Matrix4>? inverseBindMatrices;

  M3Skin(int boneCount, {this.inverseBindMatrices})
    : boneMatrices = List.generate(boneCount, (_) => Matrix4.identity());

  int get boneCount => boneMatrices.length;
}

class M3Mesh {
  // related geometry
  M3Material mtr;
  M3Geom geom;

  M3Skin? skin;

  M3Mesh(this.geom, {M3Material? material, this.skin}) : mtr = material ?? M3Material();

  /// Load model from file (supports .obj, .gltf, .glb)
  static Future<M3Mesh> load(String filename) async {
    final ext = filename.split('.').last.toLowerCase();

    if (ext == 'obj') {
      final geom = await M3ObjLoader.load(filename);
      return M3Mesh(geom);
    } else if (ext == 'gltf' || ext == 'glb') {
      final doc = await M3GltfLoader.load(filename);
      return _meshFromGltfDoc(doc);
    } else {
      throw UnsupportedError('Unsupported file format: $ext');
    }
  }

  /// Load model from URL (supports .gltf, .glb)
  static Future<M3Mesh> loadFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load model from URL: ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    final ext = url.split('.').last.toLowerCase().split('?').first;

    if (ext == 'glb' || ext == 'gltf') {
      final doc = await M3GltfLoader.loadFromBytes(Uint8List.fromList(bytes), url);
      return _meshFromGltfDoc(doc);
    } else {
      throw UnsupportedError('loadFromUrl only supports glTF/GLB format');
    }
  }

  /// Helper to create M3Mesh from GltfDocument
  static M3Mesh _meshFromGltfDoc(dynamic doc) {
    final primitive = doc.meshes[0].primitives[0];
    final geom = M3GltfGeom.fromPrimitive(primitive);

    M3Material? mtr;
    if (primitive.materialIndex != null && primitive.materialIndex! < doc.materials.length) {
      mtr = M3Material.fromGltf(doc.materials[primitive.materialIndex!], doc);
    }

    M3Skin? skin;
    if (primitive.skinIndex != null && primitive.skinIndex! < doc.skins.length) {
      final gltfSkin = doc.skins[primitive.skinIndex!];
      final ibm = gltfSkin.getInverseBindMatrices();
      final List<Matrix4>? inverseMatrices = ibm != null
          ? List.generate(gltfSkin.joints.length, (i) {
              return Matrix4.fromFloat32List(ibm.sublist(i * 16, i * 16 + 16));
            })
          : null;
      skin = M3Skin(gltfSkin.joints.length, inverseBindMatrices: inverseMatrices);
    }

    return M3Mesh(geom, material: mtr, skin: skin);
  }
}

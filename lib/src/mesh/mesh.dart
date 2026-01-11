import 'dart:convert';

import 'package:vector_math/vector_math.dart';

import '../engine/app_engine.dart';
import '../geom/geom.dart';
import '../gltf/gltf_loader.dart';
import '../texture/material.dart';
import 'obj_loader.dart';

/// Skeletal animation skin data containing bone matrices and inverse bind matrices.
///
/// Bone matrices represent the current pose of the character, while
/// inverse bind matrices transform vertices from model space to bone space.
class M3Skin {
  /// The current transformation matrices for each joint/bone.
  final List<Matrix4> boneMatrices;

  /// The inverse bind matrices for each joint, used in vertex skinning.
  final List<Matrix4>? inverseBindMatrices;

  /// Creates a skin for a specified number of bones.
  M3Skin(int boneCount, {this.inverseBindMatrices})
    : boneMatrices = List.generate(boneCount, (_) => Matrix4.identity());

  /// Returns the total number of bones in this skin.
  int get boneCount => boneMatrices.length;
}

/// A 3D mesh object that combines geometry, material properties, and optional skin for animation.
///
/// This class acts as the primary container for a renderable 3D object and supports
/// loading from various file formats (.obj, .gltf, .glb).
class M3Mesh {
  /// The material properties (textures, colors, etc.) for this mesh.
  M3Material mtr;

  /// The geometric data (vertices, indices, etc.) for this mesh.
  M3Geom geom;

  /// Optional skin data for skeletal animation.
  M3Skin? skin;

  /// Creates a mesh from the given geometry and optional material/skin.
  M3Mesh(this.geom, {M3Material? material, this.skin}) : mtr = material ?? M3Material();

  /// Loads a model from a file path or URL.
  ///
  /// Automatically detects the file format by extension (.obj, .gltf, .glb)
  /// and the source (asset or remote URL).
  static Future<M3Mesh> load(String path) async {
    // Centrally fetch raw bytes via ResourceManager
    final buffer = await M3AppEngine.instance.resourceManager.loadBuffer(path);

    // Normalize extension for detection (ignoring URL query params)
    final ext = path.split('.').last.toLowerCase().split('?').first;

    if (ext == 'obj') {
      // OBJ is a text-based format, decode as UTF-8
      final bytes = buffer.asUint8List();
      final geom = M3ObjLoader.parse(utf8.decode(bytes), path);
      return M3Mesh(geom);
    } else if (ext == 'gltf' || ext == 'glb') {
      // glTF/GLB are parsed as JSON or binary documents
      final doc = await M3GltfLoader.loadFromBytes(buffer.asUint8List(), path);
      return _meshFromGltfDoc(doc);
    } else {
      throw UnsupportedError('Unsupported format: $ext');
    }
  }

  /// Internal helper to construct an [M3Mesh] from a parsed [GltfDocument].
  ///
  /// Currently only processes the first primitive of the first mesh in the document.
  static M3Mesh _meshFromGltfDoc(dynamic doc) {
    // 1. Extract basic geometry
    final primitive = doc.meshes[0].primitives[0];
    final geom = M3GltfGeom.fromPrimitive(primitive);

    // 2. Process Material if available
    M3Material? mtr;
    if (primitive.materialIndex != null && primitive.materialIndex! < doc.materials.length) {
      mtr = M3Material.fromGltf(doc.materials[primitive.materialIndex!], doc);
    }

    // 3. Process Skeletal Animation Skin if available
    M3Skin? skin;
    int? skinIndex = primitive.skinIndex;

    if (skinIndex == null) {
      // Search for a node that references this mesh to find the associated skin
      for (final node in doc.nodes) {
        if (node.meshIndex == 0 && node.skinIndex != null) {
          skinIndex = node.skinIndex;
          break;
        }
      }
    }

    if (skinIndex != null && skinIndex < doc.skins.length) {
      final gltfSkin = doc.skins[skinIndex];
      final ibm = gltfSkin.getInverseBindMatrices();

      // Convert flat float list to Matrix4 instances
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

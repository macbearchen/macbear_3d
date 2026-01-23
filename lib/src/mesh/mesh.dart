import 'dart:convert';

// Macbear3D engine
import '../../macbear_3d.dart';
import '../gltf/gltf_loader.dart';
import '../gltf/gltf_parser.dart';
import 'obj_loader.dart';
import 'animator.dart';

/// Skeletal animation skin data containing bone matrices and inverse bind matrices.
///
/// Bone matrices represent the current pose of the character, while
/// inverse bind matrices transform vertices from model space to bone space.
class M3Skin {
  /// The current transformation matrices for each joint/bone.
  final List<Matrix4> boneMatrices;

  /// The inverse bind matrices for each joint, used in vertex skinning.
  final List<Matrix4>? inverseBindMatrices;

  /// The nodes associated with each joint (for tracking hierarchical transforms).
  final List<GltfNode>? jointNodes;

  /// Creates a skin for a specified number of bones.
  M3Skin(int boneCount, {this.inverseBindMatrices, this.jointNodes})
    : boneMatrices = List.generate(boneCount, (_) => Matrix4.identity());

  /// Returns the total number of bones in this skin.
  int get boneCount => boneMatrices.length;

  /// Updates the bone matrices based on the current transforms of the joint nodes.
  ///
  /// The [meshWorldMatrix] is the world-space transform of the mesh node itself.
  /// We need its inverse to transform the calculated joint world matrices back into
  /// the mesh's local space. This is essential because the vertex shader will
  /// apply the model's world transform (via the MVP matrix).
  ///
  /// Transformation flow for a vertex:
  /// Vertex (Mesh Local) -> [IBM] -> Joint Bind Space -> [Joint World] -> World Space -> [Mesh World Inv] -> Mesh Local (deformed)
  void update(Matrix4? meshWorldMatrix) {
    if (jointNodes == null) return;

    // By default, we assume the mesh matches the entity's local origin (Identity).
    // The inverse is used to "cancel out" the world matrix that the shader will re-apply.
    final meshWorldInv = meshWorldMatrix != null ? Matrix4.inverted(meshWorldMatrix) : Matrix4.identity();

    for (int i = 0; i < boneCount; i++) {
      final jointNode = jointNodes![i];
      final ibm = inverseBindMatrices != null ? inverseBindMatrices![i] : Matrix4.identity();

      // BoneMatrix = MeshWorldInverse * JointWorldMatrix * InverseBindMatrix
      // This transforms vertices from MeshLocal -> JointLocal(Bind) -> JointWorld -> MeshLocal
      boneMatrices[i].setFrom(meshWorldInv * jointNode.worldMatrix * ibm);
    }

    if (_debugCount < 1) {
      debugPrint('M3Skin: first bone matrix storage: ${boneMatrices[0].storage}');
      _debugCount++;
    }
  }

  int _debugCount = 0;
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

  /// Optional initial transform from glTF mesh node.
  Matrix4 initMatrix = Matrix4.identity();

  /// Optional skin data for skeletal animation.
  M3Skin? skin;

  /// Optional animator for playing back animations.
  M3Animator? animator;

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

    Matrix4 matNode = Matrix4.identity();
    // Search for a node that references this mesh
    for (final node in doc.nodes) {
      if (node.meshIndex == 0) {
        if (node.skinIndex != null) {
          skinIndex = node.skinIndex;
        }
        // Capture mesh node transform
        if (node.matrix != null) {
          matNode.setFrom(node.matrix!);
        } else {
          matNode.setFrom(Matrix4.compose(node.translation, node.rotation, node.scale));
        }
        break;
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

      skin = M3Skin(
        gltfSkin.joints.length,
        inverseBindMatrices: inverseMatrices,
        jointNodes: (gltfSkin.joints as List<int>).map<GltfNode>((index) => doc.nodes[index] as GltfNode).toList(),
      );
    }

    final mesh = M3Mesh(geom, material: mtr, skin: skin);
    mesh.initMatrix.setFrom(matNode);

    // 4. Initialize Animator
    if (doc.animations.isNotEmpty) {
      final nodeMap = {for (int i = 0; i < doc.nodes.length; i++) i: doc.nodes[i]};
      mesh.animator = M3Animator((doc.animations as List).cast<GltfAnimation>(), nodeMap.cast<int, GltfNode>());
    }

    return mesh;
  }
}

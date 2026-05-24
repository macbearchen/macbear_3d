import 'dart:convert';

// Macbear3D engine
import '../m3_internal.dart';
import '../gltf/gltf_loader.dart';
import '../gltf/gltf_parser.dart';
import 'obj_loader.dart';
import 'animator.dart';

class M3SubMesh {
  /// The material properties (textures, colors, etc.)
  M3Material mtr;

  /// The geometric data (vertices, indices, etc.)
  M3Geom geom;

  Matrix4 localMatrix = Matrix4.identity();

  M3SubMesh(this.geom, {M3Material? material}) : mtr = material ?? M3Material();
}

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

  /// Creates a copy of this skin pointing to a new set of joint nodes.
  M3Skin clone(List<GltfNode> newNodes) {
    return M3Skin(
      boneCount,
      inverseBindMatrices: inverseBindMatrices?.map((m) => m.clone()).toList(),
      jointNodes: newNodes,
    );
  }

  int _debugCount = 0;
}

/// A 3D mesh object that combines geometry, material properties, and optional skin for animation.
///
/// This class acts as the primary container for a renderable 3D object and supports
/// loading from various file formats (.obj, .gltf, .glb).
class M3Mesh {
  List<M3SubMesh> subMeshes = [];

  /// Optional initial transform from glTF mesh node.
  Matrix4 initMatrix = Matrix4.identity();

  /// Optional skin data for skeletal animation.
  M3Skin? skin;

  /// Optional animator for playing back animations.
  M3Animator? animator;

  /// The skeletal hierarchy nodes for this mesh instance.
  List<GltfNode>? nodes;

  /// Creates a mesh from the given geometry and optional material/skin.
  M3Mesh(M3Geom? geom, {M3Material? material, this.skin}) {
    if (geom != null) {
      subMeshes.add(M3SubMesh(geom, material: material));
    }
  }

  /// Loads a model from a file path or URL.
  ///
  /// Automatically detects the file format by extension (.obj, .gltf, .glb)
  /// and the source (asset or remote URL).
  static Future<M3Mesh> load(String path) async {
    // Centrally fetch raw bytes via ResourceManager
    final buffer = await M3ResourceManager.loadBuffer(path);

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
    // 1. Process all primitives of the first mesh (primary use case)
    final List<M3SubMesh> primitives = [];
    if (doc.meshes.isNotEmpty) {
      final gltfMesh = doc.meshes[0];
      for (final primitive in gltfMesh.primitives) {
        final geom = M3GltfGeom.fromPrimitive(primitive);
        M3Material? mtr;
        if (primitive.materialIndex != null && primitive.materialIndex! < doc.materials.length) {
          mtr = M3Material.fromGltf(doc.materials[primitive.materialIndex!], doc);
        }
        primitives.add(M3SubMesh(geom, material: mtr));
      }
    }

    // 2. Process Skeletal Animation Skin if available
    M3Skin? skin;
    int? skinIndex;

    Matrix4 matNode = Matrix4.identity();
    // Search for a node that references the first mesh
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

    final mesh = M3Mesh(null, skin: skin);
    mesh.subMeshes = primitives;
    mesh.initMatrix.setFrom(matNode);
    mesh.nodes = doc.nodes;

    // 3. Initialize Animator
    if (doc.animations.isNotEmpty) {
      final nodeMap = {for (int i = 0; i < doc.nodes.length; i++) i: doc.nodes[i]};
      mesh.animator = M3Animator((doc.animations as List).cast<GltfAnimation>(), nodeMap.cast<int, GltfNode>());
    }

    return mesh;
  }

  /// Copies state from another mesh.
  /// Heavy resources like [subMeshes] are referenced, while transform and animator state are copied.
  void setFrom(M3Mesh other) {
    initMatrix.setFrom(other.initMatrix);
    // subMeshes are usually shared or setup during construction
    if (animator != null && other.animator != null) {
      animator!.playRate = other.animator!.playRate;
    }
  }

  /// Creates a deep copy of this mesh instance suitable for independent animation.
  /// Heavy resources like [geom] and [mtr] are shared, while [skin], [animator],
  /// and skeletal [nodes] are duplicated.
  M3Mesh clone() {
    final Map<GltfNode, GltfNode> nodeCloneMap = {};
    final List<GltfNode>? clonedNodes = nodes?.map((n) {
      final cn = n.clone();
      nodeCloneMap[n] = cn;
      return cn;
    }).toList();

    final clonedSkin = skin != null && clonedNodes != null
        ? skin!.clone((skin!.jointNodes as List<GltfNode>).map((n) => nodeCloneMap[n]!).toList())
        : null;

    final clonedMesh = M3Mesh(null, skin: clonedSkin);
    for (final sub in subMeshes) {
      clonedMesh.subMeshes.add(M3SubMesh(sub.geom, material: sub.mtr)..localMatrix.setFrom(sub.localMatrix));
    }
    clonedMesh.nodes = clonedNodes;
    clonedMesh.setFrom(this);

    if (animator != null && clonedNodes != null) {
      final clonedNodeMap = {for (int i = 0; i < clonedNodes.length; i++) i: clonedNodes[i]};
      clonedMesh.animator = M3Animator(animator!.animations, clonedNodeMap, allNodes: clonedNodes);
      clonedMesh.animator!.playRate = animator!.playRate;
    }

    return clonedMesh;
  }
}

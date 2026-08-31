import 'package:vector_math/vector_math.dart';
import '../gltf_document.dart';

/// glTF Node
class GltfNode {
  final GltfDocument document;
  final String name;
  final int? meshIndex;
  final int? skinIndex;
  final List<int> children;

  // Transform (mutable for animation)
  Vector3 translation;
  Quaternion rotation;
  Vector3 scale;
  final Matrix4? matrix;

  /// Computed world matrix for this node.
  Matrix4 worldMatrix = Matrix4.identity();

  GltfNode({
    required this.document,
    required this.name,
    this.meshIndex,
    this.skinIndex,
    this.children = const [],
    required this.translation,
    required this.rotation,
    required this.scale,
    this.matrix,
  });

  static GltfNode parse(GltfDocument doc, Map<String, dynamic> json) {
    Vector3? t;
    if (json.containsKey('translation')) {
      final l = (json['translation'] as List).cast<num>();
      t = Vector3(l[0].toDouble(), l[1].toDouble(), l[2].toDouble());
    }

    Quaternion? r;
    if (json.containsKey('rotation')) {
      final l = (json['rotation'] as List).cast<num>();
      r = Quaternion(l[0].toDouble(), l[1].toDouble(), l[2].toDouble(), l[3].toDouble());
    }

    Vector3? s;
    if (json.containsKey('scale')) {
      final l = (json['scale'] as List).cast<num>();
      s = Vector3(l[0].toDouble(), l[1].toDouble(), l[2].toDouble());
    }

    Matrix4? m;
    if (json.containsKey('matrix')) {
      final l = (json['matrix'] as List).cast<num>();
      m = Matrix4.fromList(l.map((e) => e.toDouble()).toList());
    }

    return GltfNode(
      document: doc,
      name: json['name'] as String? ?? 'Node',
      meshIndex: json['mesh'] as int?,
      skinIndex: json['skin'] as int?,
      children: (json['children'] as List?)?.cast<int>() ?? [],
      translation: t ?? Vector3.zero(),
      rotation: r ?? Quaternion.identity(),
      scale: s ?? Vector3.all(1.0),
      matrix: m,
    );
  }

  /// Computes the world matrix for this node and its children.
  void computeWorldMatrix(Matrix4 parentMatrix, [List<GltfNode>? nodes]) {
    final nodeList = nodes ?? document.nodes;
    if (matrix != null) {
      worldMatrix.setFrom(parentMatrix * matrix!);
    } else {
      worldMatrix.setFrom(parentMatrix * Matrix4.compose(translation, rotation, scale));
    }

    for (final childIndex in children) {
      nodeList[childIndex].computeWorldMatrix(worldMatrix, nodeList);
    }
  }

  /// Copies all properties from another node.
  void setFrom(GltfNode other) {
    translation.setFrom(other.translation);
    rotation.setFrom(other.rotation);
    scale.setFrom(other.scale);
    if (matrix != null && other.matrix != null) {
      matrix!.setFrom(other.matrix!);
    }
    worldMatrix.setFrom(other.worldMatrix);
  }

  /// Creates a copy of this node for instance-sharing.
  /// Note: This does not recursively clone children since nodes are often
  /// referenced by index in the document. Hierarchy cloning is handled higher up.
  GltfNode clone() {
    return GltfNode(
      document: document,
      name: name,
      meshIndex: meshIndex,
      skinIndex: skinIndex,
      children: List.from(children),
      translation: translation.clone(),
      rotation: rotation.clone(),
      scale: scale.clone(),
      matrix: matrix?.clone(),
    )..setFrom(this);
  }
}

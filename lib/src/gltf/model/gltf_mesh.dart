import 'dart:typed_data';
import '../gltf_accessor.dart';
import '../gltf_document.dart';

/// glTF Skin
class GltfSkin {
  final GltfDocument document;
  final String name;
  final int? inverseBindMatricesAccessor;
  final List<int> joints;

  GltfSkin({
    required this.document,
    required this.name,
    this.inverseBindMatricesAccessor,
    required this.joints,
  });

  static GltfSkin parse(GltfDocument doc, Map<String, dynamic> json) {
    return GltfSkin(
      document: doc,
      name: json['name'] as String? ?? 'Skin',
      inverseBindMatricesAccessor: json['inverseBindMatrices'] as int?,
      joints: (json['joints'] as List<dynamic>).map((e) => e as int).toList(),
    );
  }

  Float32List? getInverseBindMatrices() {
    if (inverseBindMatricesAccessor == null) return null;
    return document.getFloatAccessor(inverseBindMatricesAccessor!);
  }
}

/// glTF Mesh
class GltfMesh {
  final GltfDocument document;
  final int index;
  final String name;
  final List<GltfPrimitive> primitives;

  GltfMesh._(this.document, this.index, this.name, this.primitives);

  static GltfMesh parse(GltfDocument doc, int index, Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Mesh_$index';
    final primList = json['primitives'] as List<dynamic>? ?? [];
    final primitives = primList.asMap().entries.map((entry) {
      return GltfPrimitive.parse(doc, entry.value as Map<String, dynamic>);
    }).toList();
    return GltfMesh._(doc, index, name, primitives);
  }
}

/// glTF Primitive (一個 Mesh 可能有多個 Primitive)
class GltfPrimitive {
  final GltfDocument document;

  // Accessor indices
  final int? positionAccessor;
  final int? normalAccessor;
  final int? texCoordAccessor;
  final int? jointAccessor;
  final int? weightAccessor;
  final int? indicesAccessor;

  // Primitive mode (4 = TRIANGLES)
  final int mode;

  // Material index
  final int? materialIndex;

  // Skin index
  final int? skinIndex;

  GltfPrimitive._({
    required this.document,
    this.positionAccessor,
    this.normalAccessor,
    this.texCoordAccessor,
    this.jointAccessor,
    this.weightAccessor,
    this.indicesAccessor,
    this.mode = 4,
    this.materialIndex,
    this.skinIndex,
  });

  static GltfPrimitive parse(GltfDocument doc, Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};

    return GltfPrimitive._(
      document: doc,
      positionAccessor: attributes['POSITION'] as int?,
      normalAccessor: attributes['NORMAL'] as int?,
      texCoordAccessor: attributes['TEXCOORD_0'] as int?,
      jointAccessor: attributes['JOINTS_0'] as int?,
      weightAccessor: attributes['WEIGHTS_0'] as int?,
      indicesAccessor: json['indices'] as int?,
      mode: json['mode'] as int? ?? 4,
      materialIndex: json['material'] as int?, // index into doc.materials
      skinIndex: json['skin'] as int?, // optional skin index
    );
  }

  /// 取得頂點位置資料
  Float32List? getPositions() {
    if (positionAccessor == null) return null;
    return document.getFloatAccessor(positionAccessor!);
  }

  /// 取得法向量資料
  Float32List? getNormals() {
    if (normalAccessor == null) return null;
    return document.getFloatAccessor(normalAccessor!);
  }

  /// 取得 UV 座標資料
  Float32List? getTexCoords() {
    if (texCoordAccessor == null) return null;
    return document.getFloatAccessor(texCoordAccessor!);
  }

  /// 取得骨骼索引資料
  Uint16List? getJoints() {
    if (jointAccessor == null) return null;
    return document.getUint16Accessor(jointAccessor!);
  }

  /// 取得骨骼權重資料
  Float32List? getWeights() {
    if (weightAccessor == null) return null;
    return document.getFloatAccessor(weightAccessor!);
  }

  /// 取得索引資料 (自動處理 UNSIGNED_SHORT/UNSIGNED_INT)
  List<int>? getIndices() {
    if (indicesAccessor == null) return null;
    final componentType = document.getAccessorComponentType(indicesAccessor!);
    if (componentType == GltfAccessor.UNSIGNED_SHORT) {
      return document.getUint16Accessor(indicesAccessor!).toList();
    } else if (componentType == GltfAccessor.UNSIGNED_INT) {
      return document.getUint32Accessor(indicesAccessor!).toList();
    }
    return null;
  }

  /// 取得頂點數量
  int get vertexCount {
    if (positionAccessor == null) return 0;
    return document.getAccessorCount(positionAccessor!);
  }
}

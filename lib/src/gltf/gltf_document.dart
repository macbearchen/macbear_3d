import 'dart:typed_data';
import '../util/log.dart';
import 'gltf_accessor.dart';
import 'model/gltf_animation.dart';
import 'model/gltf_material.dart';
import 'model/gltf_mesh.dart';
import 'model/gltf_node.dart';

export 'model/gltf_animation.dart';
export 'model/gltf_material.dart';
export 'model/gltf_mesh.dart';
export 'model/gltf_node.dart';

/// glTF 文件解析結果
class GltfDocument {
  final String name;
  final Map<String, dynamic> json;
  final Uint8List? embeddedBin;

  late final List<GltfMesh> meshes;
  late final List<GltfMaterial> materials;
  late final List<GltfTexture> textures;
  late final List<GltfImage> images;
  late final List<GltfSkin> skins;
  late final List<GltfNode> nodes;
  late final List<GltfAnimation> animations;
  late final List<int> rootNodes;

  // Runtime loaded assets
  // Use dynamic to avoid circular dependency (should be List<M3Texture>)
  List<dynamic> runtimeTextures = [];

  GltfDocument._(this.json, this.name, this.embeddedBin);

  /// 從 JSON 解析 glTF 文件
  static GltfDocument parse(Map<String, dynamic> json, String name, Uint8List? embeddedBin) {
    final doc = GltfDocument._(json, name, embeddedBin);
    doc._parseAll();
    return doc;
  }

  void _parseAll() {
    // 1. Parse Images
    final imageList = json['images'] as List<dynamic>? ?? [];
    images = imageList.map((e) => GltfImage.parse(e as Map<String, dynamic>)).toList();

    // 2. Parse Textures
    final textureList = json['textures'] as List<dynamic>? ?? [];
    textures = textureList.map((e) => GltfTexture.parse(e as Map<String, dynamic>)).toList();

    // 3. Parse Materials
    final materialList = json['materials'] as List<dynamic>? ?? [];
    materials = materialList.map((e) => GltfMaterial.parse(e as Map<String, dynamic>)).toList();

    // 4. Parse Skins
    final skinList = json['skins'] as List<dynamic>? ?? [];
    skins = skinList.map((e) => GltfSkin.parse(this, e as Map<String, dynamic>)).toList();

    // 5. Parse Nodes
    final nodeList = json['nodes'] as List<dynamic>? ?? [];
    nodes = nodeList.map((e) => GltfNode.parse(this, e as Map<String, dynamic>)).toList();

    // 6. Parse Meshes
    final meshList = json['meshes'] as List<dynamic>? ?? [];
    meshes = meshList.asMap().entries.map((entry) {
      return GltfMesh.parse(this, entry.key, entry.value as Map<String, dynamic>);
    }).toList();

    // 7. Parse Animations
    final animationList = json['animations'] as List<dynamic>? ?? [];
    animations = animationList.map((e) => GltfAnimation.parse(this, e as Map<String, dynamic>)).toList();

    // 8. Find Root Nodes
    final childSet = <int>{};
    for (final node in nodes) {
      for (final child in node.children) {
        childSet.add(child);
      }
    }
    rootNodes = [];
    for (int i = 0; i < nodes.length; i++) {
      if (!childSet.contains(i)) {
        rootNodes.add(i);
      }
    }
    M3Log.i('GltfDocument', 'Found ${rootNodes.length} root nodes: $rootNodes');
  }

  /// 取得 Accessor 資料
  Float32List getFloatAccessor(int accessorIndex) {
    return GltfAccessor.getFloatList(json, embeddedBin!, accessorIndex);
  }

  Uint16List getUint16Accessor(int accessorIndex) {
    return GltfAccessor.getUint16List(json, embeddedBin!, accessorIndex);
  }

  Uint32List getUint32Accessor(int accessorIndex) {
    return GltfAccessor.getUint32List(json, embeddedBin!, accessorIndex);
  }

  int getAccessorCount(int accessorIndex) {
    final accessor = json['accessors'][accessorIndex] as Map<String, dynamic>;
    return accessor['count'] as int;
  }

  int getAccessorComponentType(int accessorIndex) {
    final accessor = json['accessors'][accessorIndex] as Map<String, dynamic>;
    return accessor['componentType'] as int;
  }

  /// 取得 BufferView 資料 (用於圖片讀取)
  Uint8List getBufferViewData(int bufferViewIndex) {
    final bufferView = json['bufferViews'][bufferViewIndex] as Map<String, dynamic>;
    final byteOffset = bufferView['byteOffset'] as int? ?? 0;
    final byteLength = bufferView['byteLength'] as int;

    // 假設只有一個 binary buffer (GLB 標準情況)
    // 如果是 glTF 且有 external bin，需要額外處理 (這裡簡化只支援 GLB embedded bin)
    if (embeddedBin == null) {
      throw UnimplementedError('Only GLB embedded buffers are supported for now');
    }

    return embeddedBin!.sublist(byteOffset, byteOffset + byteLength);
  }
}

import 'dart:typed_data';

/// glTF Accessor 工具類別
/// 用於從 BufferView 中讀取特定類型的資料
class GltfAccessor {
  // Component types
  static const int BYTE = 5120;
  static const int UNSIGNED_BYTE = 5121;
  static const int SHORT = 5122;
  static const int UNSIGNED_SHORT = 5123;
  static const int UNSIGNED_INT = 5125;
  static const int FLOAT = 5126;

  /// 取得 Float32List (用於 POSITION, NORMAL, TEXCOORD 等)
  static Float32List getFloatList(Map<String, dynamic> gltf, Uint8List bufferData, int accessorIndex) {
    final accessor = gltf['accessors'][accessorIndex] as Map<String, dynamic>;
    final bufferViewIndex = accessor['bufferView'] as int;
    final bufferView = gltf['bufferViews'][bufferViewIndex] as Map<String, dynamic>;

    final byteOffset = (bufferView['byteOffset'] as int? ?? 0) + (accessor['byteOffset'] as int? ?? 0);
    final count = accessor['count'] as int;
    final componentCount = _getComponentCount(accessor['type'] as String);

    return bufferData.buffer.asFloat32List(byteOffset, count * componentCount);
  }

  /// 取得 Uint16List (用於 indices, UNSIGNED_SHORT)
  static Uint16List getUint16List(Map<String, dynamic> gltf, Uint8List bufferData, int accessorIndex) {
    final accessor = gltf['accessors'][accessorIndex] as Map<String, dynamic>;
    final bufferViewIndex = accessor['bufferView'] as int;
    final bufferView = gltf['bufferViews'][bufferViewIndex] as Map<String, dynamic>;

    final byteOffset = (bufferView['byteOffset'] as int? ?? 0) + (accessor['byteOffset'] as int? ?? 0);
    final count = accessor['count'] as int;

    return bufferData.buffer.asUint16List(byteOffset, count);
  }

  /// 取得 Uint32List (用於 indices, UNSIGNED_INT)
  static Uint32List getUint32List(Map<String, dynamic> gltf, Uint8List bufferData, int accessorIndex) {
    final accessor = gltf['accessors'][accessorIndex] as Map<String, dynamic>;
    final bufferViewIndex = accessor['bufferView'] as int;
    final bufferView = gltf['bufferViews'][bufferViewIndex] as Map<String, dynamic>;

    final byteOffset = (bufferView['byteOffset'] as int? ?? 0) + (accessor['byteOffset'] as int? ?? 0);
    final count = accessor['count'] as int;

    return bufferData.buffer.asUint32List(byteOffset, count);
  }

  /// 根據 glTF type 取得元件數量
  static int _getComponentCount(String type) {
    switch (type) {
      case 'SCALAR':
        return 1;
      case 'VEC2':
        return 2;
      case 'VEC3':
        return 3;
      case 'VEC4':
        return 4;
      case 'MAT2':
        return 4;
      case 'MAT3':
        return 9;
      case 'MAT4':
        return 16;
      default:
        return 1;
    }
  }
}

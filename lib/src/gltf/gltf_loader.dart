import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../texture/texture.dart';
import 'gltf_parser.dart';

/// glTF/GLB 模型載入器
class M3GltfLoader {
  /// 從 assets 載入 glTF 或 GLB 檔案
  static Future<GltfDocument> load(String path) async {
    final bytes = await rootBundle.load('assets/$path');
    return loadFromBytes(bytes.buffer.asUint8List(), path);
  }

  /// 從二進位資料載入
  static Future<GltfDocument> loadFromBytes(Uint8List bytes, String name) async {
    if (_isGlb(bytes)) {
      return _parseGlb(bytes, name);
    } else {
      final jsonStr = utf8.decode(bytes);
      return _parseGltf(jsonStr, name, null);
    }
  }

  /// 檢查是否為 GLB 格式 (Magic: 0x46546C67 = "glTF")
  static bool _isGlb(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final magic = bytes.buffer.asByteData().getUint32(0, Endian.little);
    return magic == 0x46546C67; // "glTF"
  }

  /// 解析 GLB 二進位格式
  static Future<GltfDocument> _parseGlb(Uint8List bytes, String name) async {
    final byteData = bytes.buffer.asByteData();

    // GLB Header (12 bytes)
    // final magic = byteData.getUint32(0, Endian.little);
    // final version = byteData.getUint32(4, Endian.little);
    // final length = byteData.getUint32(8, Endian.little);

    // Chunk 0: JSON
    final jsonChunkLength = byteData.getUint32(12, Endian.little);
    // final jsonChunkType = byteData.getUint32(16, Endian.little); // 0x4E4F534A = "JSON"
    final jsonBytes = bytes.sublist(20, 20 + jsonChunkLength);
    final jsonStr = utf8.decode(jsonBytes);

    // Chunk 1: BIN (optional)
    Uint8List? binData;
    final binChunkOffset = 20 + jsonChunkLength;
    if (binChunkOffset + 8 <= bytes.length) {
      final binChunkLength = byteData.getUint32(binChunkOffset, Endian.little);
      // final binChunkType = byteData.getUint32(binChunkOffset + 4, Endian.little); // 0x004E4942 = "BIN\0"
      binData = bytes.sublist(binChunkOffset + 8, binChunkOffset + 8 + binChunkLength);
    }

    return _parseGltf(jsonStr, name, binData);
  }

  /// 解析 glTF JSON
  static Future<GltfDocument> _parseGltf(String jsonStr, String name, Uint8List? embeddedBin) async {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final doc = GltfDocument.parse(json, name, embeddedBin);

    // Load textures
    final dir = name.contains('/') ? name.substring(0, name.lastIndexOf('/') + 1) : '';

    for (final texDef in doc.textures) {
      dynamic tex; // M3Texture?
      try {
        if (texDef.source != null && texDef.source! < doc.images.length) {
          final imgDef = doc.images[texDef.source!];
          if (imgDef.bufferView != null) {
            // Load from bufferView (GLB)
            final bytes = doc.getBufferViewData(imgDef.bufferView!);
            final texName = imgDef.name ?? '${name}_tex_${texDef.source}';
            tex = await M3Texture.createFromBytes(bytes, texName);
          } else if (imgDef.uri != null) {
            // Load from URI
            var uri = imgDef.uri!;
            if (!uri.startsWith('data:')) {
              final path = '$dir$uri';
              tex = await M3Texture.loadTexture(path);
            }
          }
        }
      } catch (e) {
        // debugPrint('Failed to load texture: $e');
      }
      doc.runtimeTextures.add(tex);
    }

    return doc;
  }
}

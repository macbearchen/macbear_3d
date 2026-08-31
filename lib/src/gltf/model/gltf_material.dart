import 'package:vector_math/vector_math.dart';

/// glTF Image
class GltfImage {
  final String? uri;
  final int? bufferView;
  final String? mimeType;
  final String? name;

  GltfImage({this.uri, this.bufferView, this.mimeType, this.name});

  static GltfImage parse(Map<String, dynamic> json) {
    return GltfImage(
      uri: json['uri'] as String?,
      bufferView: json['bufferView'] as int?,
      mimeType: json['mimeType'] as String?,
      name: json['name'] as String?,
    );
  }
}

/// glTF Texture
class GltfTexture {
  final int? sampler;
  final int? source; // index of images
  final String? name;

  GltfTexture({this.sampler, this.source, this.name});

  static GltfTexture parse(Map<String, dynamic> json) {
    return GltfTexture(
      sampler: json['sampler'] as int?,
      source: json['source'] as int?,
      name: json['name'] as String?,
    );
  }
}

/// glTF Material
class GltfMaterial {
  final String name;
  final Vector4 baseColorFactor;
  final int? baseColorTextureIndex; // index of textures
  final double metallicFactor;
  final double roughnessFactor;
  final String alphaMode; // "OPAQUE", "MASK", "BLEND"
  final double alphaCutoff;

  GltfMaterial({
    required this.name,
    required this.baseColorFactor,
    this.baseColorTextureIndex,
    this.metallicFactor = 1.0,
    this.roughnessFactor = 1.0,
    this.alphaMode = 'OPAQUE',
    this.alphaCutoff = 0.5,
  });

  static GltfMaterial parse(Map<String, dynamic> json) {
    final pbr = json['pbrMetallicRoughness'] as Map<String, dynamic>? ?? {};

    // Base Color Factor
    Vector4 color = Vector4(1.0, 1.0, 1.0, 1.0);
    if (pbr.containsKey('baseColorFactor')) {
      final list = (pbr['baseColorFactor'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      if (list.length == 4) {
        color = Vector4(list[0], list[1], list[2], list[3]);
      }
    }

    // Base Color Texture
    int? texIndex;
    if (pbr.containsKey('baseColorTexture')) {
      final tex = pbr['baseColorTexture'] as Map<String, dynamic>;
      texIndex = tex['index'] as int?;
    }

    // Metallic/Roughness
    double metallic = 1.0;
    double roughness = 1.0;
    if (pbr.containsKey('metallicFactor')) {
      metallic = (pbr['metallicFactor'] as num).toDouble();
    }
    if (pbr.containsKey('roughnessFactor')) {
      roughness = (pbr['roughnessFactor'] as num).toDouble();
    }

    return GltfMaterial(
      name: json['name'] as String? ?? 'Material',
      baseColorFactor: color,
      baseColorTextureIndex: texIndex,
      metallicFactor: metallic,
      roughnessFactor: roughness,
      alphaMode: json['alphaMode'] as String? ?? 'OPAQUE',
      alphaCutoff: (json['alphaCutoff'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

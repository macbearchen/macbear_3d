import 'package:vector_math/vector_math.dart';

import '../gltf/gltf_parser.dart';
import 'texture.dart';

/// Material properties for rendering (diffuse color, specular, shininess, textures).
class M3Material {
  Vector4 diffuse = Vector4(1.0, 1.0, 1.0, 1.0);
  Vector3 specular = Vector3(1.0, 1.0, 1.0);
  double shininess = 16; // glossiness [0 ~ 128]

  // textures
  M3Texture texDiffuse = M3Texture.texWhite;
  Matrix3 texMatrix = Matrix3.identity();

  M3Material();

  factory M3Material.fromGltf(GltfMaterial gltfMat, GltfDocument doc) {
    final mtr = M3Material();
    // Base Color
    mtr.diffuse = gltfMat.baseColorFactor;

    // Base Color Texture
    if (gltfMat.baseColorTextureIndex != null) {
      final texIndex = gltfMat.baseColorTextureIndex!;
      if (texIndex < doc.runtimeTextures.length) {
        final tex = doc.runtimeTextures[texIndex];
        if (tex is M3Texture) {
          mtr.texDiffuse = tex;
        }
      }
    }
    return mtr;
  }
}

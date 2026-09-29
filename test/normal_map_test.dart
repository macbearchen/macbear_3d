import 'package:flutter_test/flutter_test.dart';
import 'package:macbear_3d/macbear_3d.dart';

void main() {
  group('Normal Map Support', () {
    test('M3Material normal texture and scale properties', () {
      final mat1 = M3Material();
      expect(mat1.normalTexture, isNull);
      expect(mat1.normalScale, 1.0);

      final dummyTex = M3Texture();
      mat1.normalTexture = dummyTex;
      mat1.normalScale = 1.5;

      // Clone
      final mat2 = mat1.clone();
      expect(mat2.normalTexture, dummyTex);
      expect(mat2.normalScale, 1.5);

      // setFrom
      final mat3 = M3Material();
      mat3.setFrom(mat1);
      expect(mat3.normalTexture, dummyTex);
      expect(mat3.normalScale, 1.5);
    });

    test('GltfMaterial parses normalTexture and scale', () {
      final jsonWithNormal = {
        'name': 'PBRMat',
        'pbrMetallicRoughness': {
          'baseColorFactor': [1.0, 0.5, 0.2, 1.0],
        },
        'normalTexture': {'index': 3, 'scale': 0.8},
      };

      final gltfMat = GltfMaterial.parse(jsonWithNormal);
      expect(gltfMat.name, 'PBRMat');
      expect(gltfMat.normalTextureIndex, 3);
      expect(gltfMat.normalTextureScale, 0.8);

      final jsonWithoutNormal = {'name': 'BasicMat'};
      final gltfMatBasic = GltfMaterial.parse(jsonWithoutNormal);
      expect(gltfMatBasic.normalTextureIndex, isNull);
      expect(gltfMatBasic.normalTextureScale, 1.0);
    });
  });
}

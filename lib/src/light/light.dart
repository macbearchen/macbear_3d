// Macbear3D engine
import '../m3_internal.dart';
import '../renderer/shadow_map.dart';

part 'directional_light.dart';
part 'point_light.dart';
part 'spot_light.dart';

/// A directional or positional light source for scene illumination.
///
/// Extends [M3Camera] for shadow map rendering. Provides ambient and diffuse color blending.
abstract class M3Light {
  static Vector3 ambient = Vector3(0.2, 0.2, 0.2);
  Vector3 position = Vector3(0, 0, 6);
  Vector3 color = Colors.white.rgb - ambient;

  // shadow map
  bool castShadow = true;
  M3ShadowMap? shadowMap;

  /// set shadow map
  void setShadowMap(M3ShadowMap? sm) {
    shadowMap = sm;
    castShadow = sm != null;
  }

  static Vector4 blendRGBA(Vector4 a, Vector4 b) {
    return Vector4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
  }

  static Vector3 blendRGB(Vector3 a, Vector3 b) {
    return Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
  }

  void drawHelper(M3Program prog, M3Camera viewer) {
    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(position);
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugDot.draw(prog);
  }
}

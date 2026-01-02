import 'package:vector_math/vector_math.dart';

import 'camera.dart';

/// A directional or positional light source for scene illumination.
///
/// Extends [M3Camera] for shadow map rendering. Provides ambient and diffuse color blending.
class M3Light extends M3Camera {
  static Vector3 ambient = Vector3(0.2, 0.2, 0.2);
  Vector3 color = Colors.white.rgb - ambient;

  bool bPositional = false; // positional or directional

  M3Light() {
    setLookat(Vector3(2, 0, 8), Vector3.zero(), Vector3(0, 0, 1));
  }

  Vector4 getDirection() {
    Vector4 dirZ = viewMatrix.getRow(2);
    dirZ.w = 0.0; // direction vector

    return dirZ;
  }

  static Vector4 blendRGBA(Vector4 a, Vector4 b) {
    return Vector4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
  }

  static Vector3 blendRGB(Vector3 a, Vector3 b) {
    return Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
  }
}

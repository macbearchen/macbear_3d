import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'camera.dart';

/// A directional or positional light source for scene illumination.
///
/// Extends [M3Camera] for shadow map rendering. Provides ambient and diffuse color blending.
class M3Light extends M3Camera {
  static Vector3 ambient = Vector3(0.2, 0.2, 0.2);
  Vector3 color = Colors.white.rgb - ambient;

  bool bPositional = false; // positional or directional
  bool bAlignCamera = true; // align camera to light

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

  List<Matrix4> csmMatrices = [];

  void splitCascadedShadowmap(M3Camera cam) {
    if (cam.csmDepthSplits.isEmpty) return;

    final splits = cam.csmDepthSplits;
    final int count = splits.length - 1;
    if (csmMatrices.length != count) {
      csmMatrices = List.generate(count, (_) => Matrix4.identity());
    }

    final double aspect = cam.viewportW / cam.viewportH;
    final double tanHalfFov = tan(radians(cam.degreeFovY) / 2.0);
    final Matrix4 camToWorld = cam.cameraToWorldMatrix;
    final Matrix4 worldToLight = viewMatrix;

    for (int i = 0; i < count; i++) {
      final double near = splits[i];
      final double far = splits[i + 1];

      // 8 corners in camera space
      final List<Vector3> corners = [];
      for (double z in [-near, -far]) {
        double h = z.abs() * tanHalfFov;
        double w = h * aspect;
        corners.add(Vector3(w, h, z));
        corners.add(Vector3(-w, h, z));
        corners.add(Vector3(w, -h, z));
        corners.add(Vector3(-w, -h, z));
      }

      // Transform corners to light space and calculate AABB
      final Aabb3 lightSpaceAabb = Aabb3();
      for (int j = 0; j < corners.length; j++) {
        final v = corners[j];
        v.applyMatrix4(camToWorld); // camera to world
        v.applyMatrix4(worldToLight); // world to light
        if (j == 0) {
          lightSpaceAabb.min.setFrom(v);
          lightSpaceAabb.max.setFrom(v);
        } else {
          lightSpaceAabb.hullPoint(v);
        }
      }

      // Build tight orthographic projection Matrix
      // note: near/far in makeOrthographicMatrix are usually positive distances from eye
      final cascadeProj = makeOrthographicMatrix(
        lightSpaceAabb.min.x,
        lightSpaceAabb.max.x,
        lightSpaceAabb.min.y,
        lightSpaceAabb.max.y,
        -lightSpaceAabb.max.z,
        -lightSpaceAabb.min.z,
      );

      csmMatrices[i] = cascadeProj * worldToLight;
    }
  }
}

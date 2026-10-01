part of 'light.dart';

class M3ShadowCascade {
  Matrix4 projectionMatrix = Matrix4.identity();
  double atlasBiasV = 0.0; // texture bias-V (CSM shader use 1 shadowmap, 1 pass)
  double atlasScaleV = 1.0; // texture scale-V (CSM shader use 1 shadowmap, 1 pass)

  @override
  String toString() {
    return 'atlas: bias=$atlasBiasV, scale=$atlasScaleV';
  }
}

/// directional light
class M3DirectionalLight extends M3Light {
  bool isCameraAligned = true; // align camera to light
  double shadowNormalBias = 0.05;
  double csmPaddingNear = 2.0;
  double csmPaddingFar = 2.0;

  List<M3ShadowCascade> cascades = [];
  M3Camera lightViewer = M3Camera();

  M3DirectionalLight() {
    lightViewer.setLookat(Vector3(2, 0, 8), Vector3.zero(), Vector3(0, 0, 1));

    // isCameraAligned = false;
  }

  /// get light direction
  Vector3 getDirection() {
    return lightViewer.viewMatrix.getRow(2).xyz; // Z axis
  }

  void updateShadowCascades(M3Camera cam) {
    if (cam.csmCount == 0) {
      cascades.clear();
      return;
    }

    final splits = cam.csmSplitDistances;
    final int count = splits.length - 1;

    if (isCameraAligned) {
      _alignLightWithCamera(cam, splits);
    }

    if (cascades.length != count) {
      cascades = List.generate(count, (_) => M3ShadowCascade());
    }

    final double aspect = cam.viewportW / cam.viewportH;
    final double tanHalfFov = tan(radians(cam.degreeFovY) / 2.0);
    final Matrix4 camToWorld = cam.cameraToWorldMatrix;
    final Matrix4 worldToLight = lightViewer.viewMatrix;

    // 1. Calculate overall Z-range for consistent near/far clipping across all cascades
    final (depthNear, depthFar) = _computeGlobalDepthRange(
      cam,
      aspect: aspect,
      tanHalfFov: tanHalfFov,
      camToWorld: camToWorld,
      worldToLight: worldToLight,
    );

    // 2. Compute stable projection matrix for each cascade
    for (int i = 0; i < count; i++) {
      _updateCascadeProjection(
        i,
        splits[i],
        splits[i + 1],
        aspect: aspect,
        tanHalfFov: tanHalfFov,
        camToWorld: camToWorld,
        worldToLight: worldToLight,
        depthNear: depthNear,
        depthFar: depthFar,
      );
    }
    _updateCascadeAtlasV();
  }

  /// Align light eye and target with camera frustum centroid while maintaining light direction
  void _alignLightWithCamera(M3Camera cam, List<double> splits) {
    final double near = splits.first;
    final double far = splits.last;
    final double midZ = (near + far) / 2.0;

    // Centroid in camera space (negative Z is forward)
    final Vector3 centroidCam = Vector3(0, 0, -midZ);
    final Vector3 centroidWorld = cam.cameraToWorldMatrix.transform3(centroidCam);

    // Maintain light direction (Z-axis of viewMatrix is backward direction)
    final Vector3 dirLightBackward = lightViewer.viewMatrix.getRow(2).xyz;
    final double dist = lightViewer.distanceToTarget;
    lightViewer.target.setFrom(centroidWorld);
    lightViewer.position.setFrom(lightViewer.target + dirLightBackward * dist);

    // Check for gimbal lock (singularity when light direction is parallel to up vector)
    Vector3 safeUp = -cam.viewMatrix.getRow(2).xyz;
    if (dirLightBackward.dot(safeUp).abs() > 0.99) {
      safeUp = cam.viewMatrix.getRow(1).xyz; // camera backward
      if (dirLightBackward.dot(safeUp).abs() > 0.99) {
        safeUp = cam.viewMatrix.getRow(0).xyz; // camera right
      }
    }
    lightViewer.setLookat(lightViewer.position, lightViewer.target, safeUp);
  }

  /// Calculate the overall Z-range for the full camera frustum transformed to light space
  (double depthNear, double depthFar) _computeGlobalDepthRange(
    M3Camera cam, {
    required double aspect,
    required double tanHalfFov,
    required Matrix4 camToWorld,
    required Matrix4 worldToLight,
  }) {
    double overallMinZ = double.infinity;
    double overallMaxZ = -double.infinity;

    final corner = Vector3.zero();
    for (final double z in [-cam.nearClip, -cam.farClip]) {
      final double h = z.abs() * tanHalfFov;
      final double w = h * aspect;

      // 4 corners at this slice
      for (final double sx in [1.0, -1.0]) {
        for (final double sy in [1.0, -1.0]) {
          corner
            ..setValues(w * sx, h * sy, z)
            ..applyMatrix4(camToWorld)
            ..applyMatrix4(worldToLight);

          overallMinZ = min(overallMinZ, corner.z);
          overallMaxZ = max(overallMaxZ, corner.z);
        }
      }
    }

    final double depthNear = -overallMaxZ - csmPaddingNear;
    final double depthFar = -overallMinZ + csmPaddingFar;
    return (depthNear, depthFar);
  }

  /// Compute stable orthographic projection matrix using bounding-sphere and texel snapping
  void _updateCascadeProjection(
    int index,
    double near,
    double far, {
    required double aspect,
    required double tanHalfFov,
    required Matrix4 camToWorld,
    required Matrix4 worldToLight,
    required double depthNear,
    required double depthFar,
  }) {
    // 1. Calculate center and radius of bounding sphere in camera space
    final double midZ = (near + far) / 2.0;
    final Vector3 splitCenterCam = Vector3(0, 0, -midZ);

    final double hFar = far * tanHalfFov;
    final double wFar = hFar * aspect;
    final Vector3 farCornerCam = Vector3(wFar, hFar, -far);
    final double radius = (farCornerCam - splitCenterCam).length;

    // Transform split center to light space
    final Vector3 splitCenterLight = splitCenterCam
      ..applyMatrix4(camToWorld)
      ..applyMatrix4(worldToLight);

    // Initial AABB from bounding sphere
    double minX = splitCenterLight.x - radius;
    double maxX = splitCenterLight.x + radius;
    double minY = splitCenterLight.y - radius;
    double maxY = splitCenterLight.y + radius;

    // 2. Texel Snapping to prevent shimmering
    final double shadowResolutionX = shadowMap!.mapW.toDouble();
    final double atlasScaleV = cascades[index].atlasScaleV;
    final double shadowResolutionY = shadowMap!.mapH.toDouble() * atlasScaleV;

    final double worldUnitsPerTexelX = (maxX - minX) / shadowResolutionX;
    final double worldUnitsPerTexelY = (maxY - minY) / shadowResolutionY;

    minX = (minX / worldUnitsPerTexelX).floorToDouble() * worldUnitsPerTexelX;
    maxX = minX + (radius * 2.0 / worldUnitsPerTexelX).ceilToDouble() * worldUnitsPerTexelX;

    minY = (minY / worldUnitsPerTexelY).floorToDouble() * worldUnitsPerTexelY;
    maxY = minY + (radius * 2.0 / worldUnitsPerTexelY).ceilToDouble() * worldUnitsPerTexelY;

    // 3. Build orthographic projection Matrix
    cascades[index].projectionMatrix = makeOrthographicMatrix(minX, maxX, minY, maxY, depthNear, depthFar);
  }

  void _updateCascadeAtlasV() {
    final int atlasCount = cascades.length;
    if (atlasCount <= 1) {
      return;
    }

    double biasV = 0;
    int maxPow2 = 1;
    // max-pow2 must power of 2 and (maxPow2 <= numSplit)
    while (maxPow2 < atlasCount) {
      maxPow2 *= 2;
    }

    // split-1: (1)
    // split-2: (1/2, 1/2)
    // split-3: (2/4, 1/4, 1/4)
    // split-4: (1/4, 1/4, 1/4, 1/4)
    for (int i = 0; i < atlasCount; i++) {
      cascades[i].atlasScaleV = (i < maxPow2 - atlasCount) ? 2.0 / maxPow2 : 1.0 / maxPow2;
      cascades[i].atlasBiasV = biasV;
      biasV += cascades[i].atlasScaleV;
    }
  }

  @override
  void drawHelper(M3Program prog, M3Camera viewer) {
    super.drawHelper(prog, viewer);

    if (cascades.isNotEmpty) {
      M3Material mtrHelper = M3Material();
      final colors = [Colors.red, Colors.green, Colors.blue, Colors.white];
      for (int i = cascades.length - 1; i >= 0; i--) {
        final color = colors[i % colors.length];
        color.a = 0.33;
        final crop = cascades[i];
        // camera frustum split
        final frustumMatrix = Matrix4.inverted(crop.projectionMatrix * lightViewer.viewMatrix);
        prog.setMaterial(mtrHelper, color);
        prog.setMatrices(viewer, frustumMatrix);
        M3Resources.debugFrustum.draw(prog, fillMode: .wireframe);

        // far-clip plane
        final clipMatrix = Matrix4.identity()
          ..rotateX(pi / 2)
          ..setTranslation(Vector3(0, 0, -1));
        final farMatrix = Matrix4.inverted(clipMatrix * crop.projectionMatrix * lightViewer.viewMatrix);
        prog.setMatrices(viewer, farMatrix);
        M3Resources.debugView.draw(prog, fillMode: .solid);
      }
    }
  }
}

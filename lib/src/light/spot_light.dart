part of 'light.dart';

/// Spot light — a cone-shaped positional light with inner and outer angles.
///
/// Packing layout per spotlight (1 mat4 = 4 × vec4):
///   `m[0]` xyz: object-space position,  w: range²
///   `m[1]` rgb: color,                  a: intensity
///   `m[2]` xyz: object-space direction, w: 0
///   `m[3]` x:   cos(innerAngle),        y: cos(outerAngle), zw: 0
///
/// [innerAngle] — full brightness inside this half-angle (degrees)
/// [outerAngle] — light falls to zero at this half-angle (degrees)
///
/// Direction is derived directly from the negative Z-axis of [worldMatrix] (inherited from [M3Node]).
class M3SpotLight extends M3PointLight {
  /// Inner cone half-angle in degrees (full brightness inside).
  double innerAngle = 15.0;

  /// Outer cone half-angle in degrees (zero brightness beyond this).
  double outerAngle = 30.0;

  double shadowNormalBias = 0.02;

  /// World-space pointing direction derived from -Z axis of [worldMatrix].
  Vector3 get direction => forward;
  M3Camera lightViewer = M3Camera();

  M3SpotLight() {
    updateLightViewer();
  }

  /// Sets light orientation to point toward [dir].
  set direction(Vector3 dir) {
    setDirection(dir);
  }

  /// Orient the spotlight along [dir].
  void setDirection(Vector3 dir, [Vector3? up]) {
    final fwd = dir.normalized();
    final target = position + fwd;
    final worldUp = up ?? (fwd.dot(Vector3(0, 1, 0)).abs() > 0.99 ? Vector3(0, 0, 1) : Vector3(0, 1, 0));

    lookAt(target, worldUp);
    updateLightViewer(target, worldUp);
  }

  /// Updates spotlight viewer projection and view matrices.
  void updateLightViewer([Vector3? target, Vector3? worldUp]) {
    final worldPos = worldMatrix.getTranslation();
    final fwd = direction.normalized();
    final spotTarget = target ?? (worldPos + fwd);
    final up = worldUp ?? (fwd.dot(Vector3(0, 1, 0)).abs() > 0.99 ? Vector3(0, 0, 1) : Vector3(0, 1, 0));

    lightViewer.setLookat(worldPos, spotTarget, up);
    lightViewer.setViewport(-1, -1, 2, 2, fovy: outerAngle * 2.0, near: 0.05, far: range);
  }

  @override
  void setShadowMap(M3ShadowMap? sm) {
    super.setShadowMap(sm);
    updateLightViewer();
  }

  /// Pack into a single mat4 (16 floats) for the shader.
  ///
  /// [mMatrixInv] — inverse model matrix (world → object space).
  @override
  Float32List packBuffer(Matrix4 mMatrixInv) {
    final worldPos = worldMatrix.getTranslation();
    final worldDir = direction;

    // ----- position in object space -----
    final Vector4 localPos = mMatrixInv * Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);

    // ----- direction in object space (w=0 → no translation) -----
    final Vector4 localDir = mMatrixInv * Vector4(worldDir.x, worldDir.y, worldDir.z, 0.0);
    final Vector3 d = localDir.xyz..normalize();

    // ----- cone cosines -----
    final double cosInner = cos(radians(innerAngle));
    final double cosOuter = cos(radians(outerAngle));

    final buffer = Float32List(16); // 4 vec4

    // m[0] — positionRange
    buffer[0] = localPos.x;
    buffer[1] = localPos.y;
    buffer[2] = localPos.z;
    buffer[3] = range * range;

    // m[1] — colorIntensity
    buffer[4] = color.x;
    buffer[5] = color.y;
    buffer[6] = color.z;
    buffer[7] = intensity;

    // m[2] — direction (object space)
    buffer[8] = d.x;
    buffer[9] = d.y;
    buffer[10] = d.z;
    buffer[11] = 0.0;

    // m[3] — cone angles
    buffer[12] = cosInner;
    buffer[13] = cosOuter;
    buffer[14] = 0.0;
    buffer[15] = 0.0;

    return buffer;
  }

  @override
  void drawBulb(M3Program prog, M3Camera viewer) {
    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setFrom(worldMatrix);
    targetMatrix.scaleByVector3(Vector3.all(0.2));
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugSpotLight.draw(prog, fillMode: .wireframe);
  }

  @override
  void drawHelper(M3Program prog, M3Camera viewer) {
    // Reuse lightViewer which already holds the correct view + projection
    // (kept up-to-date by updateLightViewer / setDirection / setShadowMap).
    // Frustum model matrix: inverse of (projection × view), same as M3Camera.drawHelper.
    final Matrix4 frustumMatrix = Matrix4.inverted(lightViewer.projectionMatrix * lightViewer.viewMatrix);
    prog.setMatrices(viewer, frustumMatrix);
    M3Resources.debugFrustum.draw(prog, fillMode: .wireframe);
  }
}

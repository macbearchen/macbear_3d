// Macbear3D engine
import '../m3_internal.dart';
import '../util/euler.dart';

part 'projection.dart';

/// A 3D camera with view transformation, frustum culling, and orbit controls.
///
/// Supports look-at and Euler angle orientation. Used for both scene cameras and light shadow maps.
class M3Camera extends M3Projection {
  Vector3 position = Vector3(0.0, 0.0, 0.0);
  Quaternion rotation = Quaternion.identity();

  final Frustum _frustum = Frustum();

  /// Euler
  M3Euler euler = M3Euler();

  /// View matrix, inverse matrix (camera to world for frustum debug)
  Matrix4 viewMatrix = Matrix4.identity();
  Matrix4 _invViewMatrix = Matrix4.identity();
  Matrix4 get cameraToWorldMatrix => _invViewMatrix;

  /// camera look at target, up vector
  Vector3 target = Vector3(0.0, 0.0, 0.0);
  Vector3 up = Vector3(0.0, 0.0, 1.0);
  double distanceToTarget = 20.0;

  /// split distance for CSM
  List<double> csmSplitDistances = [];
  int _csmCount = 4;
  int get csmCount => _csmCount;
  set csmCount(int val) {
    if (_csmCount != val) {
      _csmCount = val;
      _updateSplitDistances();
    }
  }

  double csmLambda = 0.6;

  @override
  void copyFrom(covariant M3Camera other) {
    super.copyFrom(other);
    position = other.position.clone();
    rotation = other.rotation.clone();
    euler.copyFrom(other.euler);
    viewMatrix = other.viewMatrix.clone();
    _invViewMatrix = other._invViewMatrix.clone();
    target = other.target.clone();
    up = other.up.clone();
    distanceToTarget = other.distanceToTarget;
    _csmCount = other._csmCount;
    csmLambda = other.csmLambda;
    csmSplitDistances = List.from(other.csmSplitDistances);
    updateFrustum(projectionMatrix * viewMatrix);
  }

  /// Clone of this.
  @override
  M3Camera clone() => M3Camera()..copyFrom(this);

  /// visibility checking (frustum culling)
  bool isVisible(M3Bounding bounds) {
    if (!_frustum.intersectsWithSphere(bounds.sphere)) {
      return false;
    }
    return _frustum.intersectsWithAabb3(bounds.aabb);
  }

  /// Update frustum matrix from view and projection matrices.
  void updateFrustum(Matrix4 matrix) {
    _frustum.setFromMatrix(matrix);
  }

  /// Set viewport and update frustum matrix.
  @override
  void setViewport(int x, int y, int w, int h, {double fovy = 50.0, double near = 1.0, double far = 100.0}) {
    super.setViewport(x, y, w, h, fovy: fovy, near: near, far: far);
    _updateSplitDistances();
    // frustum matrix for culling
    updateFrustum(projectionMatrix * viewMatrix);
  }

  void _updateSplitDistances() {
    if (csmCount > 0) {
      csmSplitDistances = buildCSMSplits(csmCount, csmLambda);
      // debugPrint("csmSplitDistances: $csmSplitDistances");
    } else {
      csmSplitDistances = [];
    }
  }

  /// CSM Cascaded-Shadowmap split (near, far)
  /// lambda(0~1): 0 split by average, 1 split as smaller near, larger far
  List<double> buildCSMSplits(int count, double lambda) {
    List<double> splits = List.filled(count + 1, 0.0);
    splits[0] = nearClip;
    splits[count] = farClip;

    for (int i = 1; i < count; i++) {
      double fraction = i / count;
      double zLog = nearClip * pow(farClip / nearClip, fraction);
      double zLin = nearClip + fraction * (farClip - nearClip);
      splits[i] = lambda * zLog + (1.0 - lambda) * zLin;
    }
    return splits;
  }

  /// Set camera look-at target and compute view matrix.
  void setLookat(Vector3 eye, Vector3 target, Vector3 up) {
    position = eye;
    this.target = target;
    this.up = up;
    distanceToTarget = (target - position).length;

    viewMatrix = makeViewMatrix(eye, target, up);
    _invViewMatrix = viewMatrix.orthoInverse(); // ortho inverse matrix
    // frustum matrix for culling
    updateFrustum(projectionMatrix * viewMatrix);
  }

  /// Move camera (both eye and target) by world-space delta.
  void move(Vector3 delta) {
    setLookat(position + delta, target + delta, up);
  }

  /// yaw by Z-axis, pitch by Y-axis, roll by X-axis
  void setEuler(double yaw, double pitch, double roll, {double? distance}) {
    euler.setEuler(yaw, pitch, roll);
    // rotate matrix: camera-axis(x,y,z) by euler-axis(-y, z, -x), eulerYPR order by axisZYX
    // _setRotationMatrix3(euler.getMatrix3(), distance: distance);

    // rotation = Quaternion.euler(roll, pitch, yaw);
    rotation = Quaternion.euler(yaw, pitch, roll);
    _setRotationMatrix3(rotation.asRotationMatrix(), distance: distance);
  }

  void _setRotationMatrix3(Matrix3 rotMat3, {double? distance}) {
    rotMat3 = M3Constants.rotXPos90 * rotMat3;

    Vector3 zAxis = rotMat3.getColumn(2); // view lookat toward to -z
    if (distance != null) {
      // target-position is fixed, move eye
      distanceToTarget = distance;
      position = target + zAxis * distanceToTarget; // eye to +Z-axis (backward from viewport)
    } else {
      // eye-position is fixed, move target
      target = position - zAxis * distanceToTarget; // target to -Z-axis (forward to viewport)
    }

    _invViewMatrix.setRotation(rotMat3);
    _invViewMatrix.setTranslation(position);
    viewMatrix = _invViewMatrix.orthoInverse(); // compute model-view-matrix
    // frustum matrix for culling
    updateFrustum(projectionMatrix * viewMatrix);
  }

  /// set camera rotation by quaternion and distance to target.
  void setRotationQuaternion(Quaternion rotQuat, {double? distance}) {
    rotation = rotQuat;
    _setRotationMatrix3(rotQuat.asRotationMatrix(), distance: distance);
  }

  /// reflect view matrix by clip plane (reflection)
  void reflectViewMatrix(Vector4 clipPlane) {
    Matrix4 mirrorMat = Matrix4.identity();
    mirrorMat.setRow(
      0,
      Vector4(
        1 - 2 * clipPlane.x * clipPlane.x,
        -2 * clipPlane.y * clipPlane.x,
        -2 * clipPlane.z * clipPlane.x,
        -2 * clipPlane.w * clipPlane.x,
      ),
    );
    mirrorMat.setRow(
      1,
      Vector4(
        -2 * clipPlane.x * clipPlane.y,
        1 - 2 * clipPlane.y * clipPlane.y,
        -2 * clipPlane.z * clipPlane.y,
        -2 * clipPlane.w * clipPlane.y,
      ),
    );
    mirrorMat.setRow(
      2,
      Vector4(
        -2 * clipPlane.x * clipPlane.z,
        -2 * clipPlane.y * clipPlane.z,
        1 - 2 * clipPlane.z * clipPlane.z,
        -2 * clipPlane.w * clipPlane.z,
      ),
    );
    mirrorMat.setRow(3, Vector4(0, 0, 0, 1));

    _invViewMatrix = mirrorMat * _invViewMatrix;
    viewMatrix = _invViewMatrix.orthoInverse();

    // update position, target, up
    position = _invViewMatrix.getTranslation();
    target = (mirrorMat * Vector4(target.x, target.y, target.z, 1.0)).xyz;
    up = (mirrorMat * Vector4(up.x, up.y, up.z, 0.0)).xyz;

    // frustum matrix for culling
    updateFrustum(projectionMatrix * viewMatrix);
  }

  /// modify projection matrix by clip plane (oblique frustum)
  void setObliqueClipPlane(Vector4 clipPlane) {
    // 1. Transform plane from world space to view space
    final clipPlaneInView = planeToViewSpace(clipPlane, viewMatrix, _invViewMatrix);

    // 2. Calculate the clip-space corner point opposite the clipping plane
    // using the sign of the plane's normal and the projection matrix.
    // This is Lengyel's formula for the 'q' vector in camera space.
    final Vector4 q = Vector4(
      (clipPlaneInView.x.sign + projectionMatrix.entry(0, 2)) / projectionMatrix.entry(0, 0),
      (clipPlaneInView.y.sign + projectionMatrix.entry(1, 2)) / projectionMatrix.entry(1, 1),
      -1.0,
      (1.0 + projectionMatrix.entry(2, 2)) / projectionMatrix.entry(2, 3),
    );

    // 3. Calculate the scaled plane vector 'c'
    final Vector4 c = clipPlaneInView * (2.0 / clipPlaneInView.dot(q));

    // 4. Replace the third row (index 2) of the projection matrix with 'c'
    projectionMatrix.setRow(2, c);

    // 5. Update frustum matrix for culling
    updateFrustum(projectionMatrix * viewMatrix);
  }

  /// transform plane from world space to view space
  static Vector4 planeToViewSpace(Vector4 planeWorld, Matrix4 viewMatrix, Matrix4 viewInverseMatrix) {
    // inverse transpose of view matrix
    final Matrix4 invTrans = viewInverseMatrix.clone()..transpose();

    // transform plane = (A, B, C, D)
    final Vector4 planeView = invTrans.transform(planeWorld);

    return planeView;
  }

  @override
  String toString() {
    return '''
${super.toString()}
Camera($distanceToTarget): $position -> $target
$euler
''';
  }

  /// Draw camera frustum and helper lines.
  void drawHelper(M3Program prog, M3Camera viewer) {
    if (viewer == this) {
      return;
    }
    prog.setMatrices(viewer, cameraToWorldMatrix);
    M3Resources.debugAxis.draw(prog, bSolid: false);

    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(target);
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugDot.draw(prog, bSolid: false);

    Matrix4 frustumMatrix = Matrix4.inverted(projectionMatrix * viewMatrix);
    prog.setMatrices(viewer, frustumMatrix);
    M3Resources.debugFrustum.draw(prog, bSolid: false);

    // near clip
    Matrix4 matNear = frustumMatrix.clone()..translateByVector3(Vector3(0, -0.2, -0.995));
    prog.setMatrices(viewer, matNear);
    M3Resources.debugView.draw(prog, bSolid: false);

    // draw split distance
    if (csmCount > 0) {
      M3Material mtrHelper = M3Material();
      prog.setMaterial(mtrHelper, Colors.blue);
      M3Projection proj = M3Projection();
      for (int i = 0; i < csmSplitDistances.length - 1; i++) {
        proj.setViewport(
          viewportX,
          viewportY,
          viewportW,
          viewportH,
          fovy: degreeFovY,
          near: csmSplitDistances[i],
          far: csmSplitDistances[i + 1],
        );

        Matrix4 splitMatrix = Matrix4.inverted(proj.projectionMatrix * viewMatrix);
        splitMatrix.translateByVector3(Vector3(0, -0.2, 1));
        prog.setMatrices(viewer, splitMatrix);
        M3Resources.debugView.draw(prog, bSolid: false);
      }
    }
  }
}

/// Matrix4 extension for orthographic inverse
extension Matrix4Extension on Matrix4 {
  Matrix4 orthoInverse() {
    // (1/3): inverse rotation by transposed
    Matrix3 rotInv = getRotation().transposed();

    // (2/3): inverse translation by negative
    Vector3 tInv = -(rotInv * getTranslation());

    // (3/3): inverse matrix only for ortho
    Matrix4 retMat = Matrix4.identity();
    retMat.setRotation(rotInv);
    retMat.setTranslation(tInv);
    return retMat;
  }
}

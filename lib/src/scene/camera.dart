// Macbear3D engine
import '../../macbear_3d.dart';
import '../util/euler.dart';

class M3Projection {
  static const int halfW = 8, halfH = 6;
  // matrix
  Matrix4 projectionMatrix = Matrix4.identity();
  // viewport: x,y,w,h
  int viewportX = -halfW, viewportY = -halfH;
  int viewportW = halfW * 2, viewportH = halfH * 2;
  // clip z-plane: near/far
  double nearClip = 1, farClip = 100.0;
  // Vertical Focus Of View by degree, zero means orthographic projection (parallel)
  double degreeFovY = 50.0;

  M3Projection() {
    refreshProjectionMatrix();
  }
  // set viewport and projection matrix
  void setViewport(int x, int y, int w, int h, {double fovy = 50.0, double near = 1.0, double far = 100.0}) {
    viewportX = x;
    viewportY = y;
    viewportW = w;
    viewportH = h;

    degreeFovY = fovy;
    nearClip = near;
    farClip = far;
    refreshProjectionMatrix();
  }

  void enableInfinite() {
    if (degreeFovY > 0.0) {
      // perspective projection by infinitite far-clip
      double fovy = radians(degreeFovY);
      double aspect = (viewportW / viewportH).abs();
      projectionMatrix = makeInfiniteMatrix(fovy, aspect, nearClip);
    }
  }

  // refresh projection matrix
  void refreshProjectionMatrix() {
    if (degreeFovY > 0.0) {
      // perspective projection
      double fovy = radians(degreeFovY);
      double aspect = (viewportW / viewportH).abs();
      projectionMatrix = makePerspectiveMatrix(fovy, aspect, nearClip, farClip);
    } else {
      // orthographic projection (parallel)
      double viewW = viewportW.toDouble(); // default view width
      double viewH = viewportH.toDouble(); // default view height

      final left = viewportX.toDouble();
      final right = left + viewW;
      final bottom = viewportY.toDouble();
      final top = bottom + viewH;
      projectionMatrix = makeOrthographicMatrix(left, right, bottom, top, nearClip, farClip);
    }

    // Flip Y only for Metal/iOS
    // if (Platform.isIOS || Platform.isMacOS) {
    //   projectionMatrix.scaleByVector3(Vector3(1, -1, 1));
    // }
  }

  @override
  String toString() {
    return '''
Viewport: ($viewportX,$viewportY) - $viewportW x $viewportH
FovY: $degreeFovY, Clip Z: near=$nearClip, far=$farClip
''';
  }
}

class M3Camera extends M3Projection {
  Vector3 position = Vector3(0.0, 0.0, 0.0);
  Quaternion rotation = Quaternion.identity();

  Frustum frustum = Frustum();
  // Euler
  M3Euler euler = M3Euler();

  // visibility checking
  bool checkVisible(M3Entity entity) {
    return frustum.intersectsWithSphere(Sphere.centerRadius(entity.position, entity.radius));
  }

  // View matrix, inverse matrix (camera to world for frustum debug)
  Matrix4 viewMatrix = Matrix4.identity();
  Matrix4 _invViewMatrix = Matrix4.identity();
  Matrix4 get cameraToWorldMatrix => _invViewMatrix;

  // camera look at target, up vector
  Vector3 target = Vector3(0.0, 0.0, 0.0);
  Vector3 up = Vector3(0.0, 0.0, 1.0);
  double distanceToTarget = 20.0;

  void setLookat(Vector3 eye, Vector3 target, Vector3 up) {
    this.position = eye;
    this.target = target;
    this.up = up;
    distanceToTarget = (target - position).length;

    viewMatrix = makeViewMatrix(eye, target, up);
    _invViewMatrix = viewMatrix.orthoInverse(); // ortho inverse matrix
    // frustum matrix for culling
    frustum.setFromMatrix(projectionMatrix * viewMatrix);
  }

  // yaw by Z-axis, pitch by Y-axis, roll by X-axis
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
    frustum.setFromMatrix(projectionMatrix * viewMatrix);
  }

  void setRotationQuaternion(Quaternion rotQuat, {double? distance}) {
    rotation = rotQuat;
    _setRotationMatrix3(rotQuat.asRotationMatrix(), distance: distance);
  }

  @override
  String toString() {
    return '''
${super.toString()}
Camera($distanceToTarget): $position -> $target
$euler
''';
  }

  void drawHelper(M3Program prog, M3Camera viewer) {
    if (viewer == this) {
      return;
    }
    prog.setMatrices(viewer, cameraToWorldMatrix);
    M3Constants.geomAxis.draw(prog, bSolid: false);

    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(target);
    prog.setMatrices(viewer, targetMatrix);
    M3Constants.geomDot.draw(prog, bSolid: false);

    Matrix4 frustumMatrix = Matrix4.inverted(projectionMatrix * viewMatrix);
    prog.setMatrices(viewer, frustumMatrix);
    M3Constants.geomFrustum.draw(prog, bSolid: false);

    Matrix4 matNear = Matrix4.identity();
    matNear.translateByVector3(Vector3(0, -0.2, -0.99));
    matNear = frustumMatrix * matNear;
    prog.setMatrices(viewer, matNear);
    M3Constants.geomGridPlane.draw(prog, bSolid: false);
  }
}

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

// Macbear3D engine
import '../../macbear_3d.dart';

class M3Constants {
  // helper geom
  static final geomAxis = M3AxisGeom(size: 0.5);
  static final geomSphereBounds = M3SphereBoundsGeom(radius: 1.0);
  static final geomFrustum = M3BoxGeom(2.0, 2.0, 2.0);
  static final geomDot = M3SphereGeom(0.1, widthSegments: 4, heightSegments: 2);
  static final geomGridPlane = M3PlaneGeom(1.6, 1.6, widthSegments: 5, heightSegments: 4);

  // POD should rotate axisX 90 degree: up from axisY(POD) to axisZ(3dsmax); POD(x,y,z) to 3dsmax(x,-z,y)
  // matrix rotate by X-axis: rotationX(-PI_HALF)
  static final Matrix3 rotXNeg90 = Matrix3.columns(
    Vector3(1, 0, 0), // X
    Vector3(0, 0, -1), // -Z
    Vector3(0, 1, 0), // Y
  );

  // matrix rotate by X-axis: rotationX(PI_HALF)
  static final Matrix3 rotXPos90 = Matrix3.columns(
    Vector3(1, 0, 0), // X
    Vector3(0, 0, 1), // Z
    Vector3(0, -1, 0), // Y
  );

  static final biasMatrix = Matrix4.columns(
    Vector4(0.5, 0, 0, 0),
    Vector4(0, 0.5, 0, 0),
    Vector4(0, 0, 0.5, 0),
    Vector4(0.5, 0.5, 0.5, 1),
  );
}

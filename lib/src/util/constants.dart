// Macbear3D engine
import '../../macbear_3d.dart';

enum M3Axis { x, y, z }

class M3Constants {
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

part of 'light.dart';

// ignore: constant_identifier_names
const int NO_SHADOW_INDEX = 255;

/// point light
class M3PointLight extends M3Light {
  double range = 6.0; // packed in position(w: range^2)
  double intensity = 1.0; // multiply in color
  // point shadowIndex: 0~2: use shadow, >2: no shadow
  // spot shadowIndex: 0~7: use shadow, >7: no shadow
  int shadowIndex = NO_SHADOW_INDEX;

  // 封裝函數：直接回傳一個 Float32List
  Float32List packBuffer(Matrix4 mMatrixInv) {
    // world space -> object space
    final worldPos = worldMatrix.getTranslation();
    Vector4 localPos = Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    localPos = mMatrixInv * localPos;

    // 預分配 8 個 float (32 bytes)，剛好填滿兩個 vec4
    final buffer = Float32List(8);

    // positionRange: xyz, range^2
    buffer[0] = localPos.x;
    buffer[1] = localPos.y;
    buffer[2] = localPos.z;
    buffer[3] = range * range;

    // rgb: colorIntensity, a: shadowIndex
    buffer[4] = color.x * intensity;
    buffer[5] = color.y * intensity;
    buffer[6] = color.z * intensity;
    buffer[7] = shadowIndex.toDouble();

    return buffer;
  }

  void drawBulb(M3Program prog, M3Camera viewer) {
    super.drawHelper(prog, viewer);
  }

  @override
  void drawHelper(M3Program prog, M3Camera viewer) {
    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(worldMatrix.getTranslation());
    targetMatrix.scaleByVector3(Vector3.all(range));
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugPointLight.draw(prog, fillMode: .wireframe);
  }
}

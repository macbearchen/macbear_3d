part of 'light.dart';

/// point light
class M3PointLight extends M3Light {
  double range = 5.0; // packed in position(w)
  double intensity = 1.0; // packed in color(alpha)

  // 封裝函數：直接回傳一個 Float32List
  Float32List packUBO() {
    // 預分配 8 個 float (32 bytes)，剛好填滿兩個 vec4
    final buffer = Float32List(8);

    buffer[0] = position.x;
    buffer[1] = position.y;
    buffer[2] = position.z;
    buffer[3] = range;

    buffer[4] = color.x;
    buffer[5] = color.y;
    buffer[6] = color.z;
    buffer[7] = intensity;

    return buffer;
  }

  @override
  void drawHelper(M3Program prog, M3Camera viewer) {
    super.drawHelper(prog, viewer);

    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(position);
    targetMatrix.scaleByVector3(Vector3.all(range));
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugPointLight.draw(prog, fillMode: .wireframe);
  }
}

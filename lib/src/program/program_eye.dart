part of 'program.dart';

// add reflection by skybox-cubemap
class M3ProgramEye extends M3Program {
  late UniformLocation uniformEyePosition; // eye position as camera origin
  late UniformLocation uniformObjectScale; // object scale

  M3ProgramEye(super.strVert, super.strFrag, {super.reflectionType});

  @override
  void initLocation() {
    super.initLocation();

    uniformEyePosition = gl.getUniformLocation(program, "uEyePos");
    uniformObjectScale = gl.getUniformLocation(program, "uObjectScale");
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    if (M3Program.isLocationValid(uniformEyePosition)) {
      // ModelView matrix
      Matrix4 mvMatrix = cam.viewMatrix * mMatrix;

      // object-space position
      Matrix4 matInv = Matrix4.identity();
      double det = matInv.copyInverse(mvMatrix);

      if (det != 0.0) {
        // eye position in object-space (model-space)
        if (M3Program.isLocationValid(uniformEyePosition)) {
          Vector3 eyePosition = matInv.getTranslation();
          gl.uniform3fv(uniformEyePosition, eyePosition.storage);
        }
        // object scale
        if (M3Program.isLocationValid(uniformObjectScale)) {
          Vector3 objScale = matInv.decomposeScale();
          gl.uniform3fv(uniformObjectScale, objScale.storage);
        }
      } else {
        debugPrint('M3ProgramEye.setMatrices: det = 0.0');
      }
    }
  }
}

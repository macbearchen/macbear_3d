part of 'program.dart';

// add reflection by skybox-cubemap
class M3ProgramEye extends M3Program {
  late UniformLocation uniformEyePosition; // eye position as camera origin

  M3ProgramEye(super.strVert, super.strFrag, {super.reflectionType});

  @override
  void initLocation() {
    super.initLocation();

    uniformEyePosition = gl.getUniformLocation(program, "EyePosition");
  }

  // eye position in object-space (model-space)
  void setEye(Vector3 eye) {
    gl.uniform3fv(uniformEyePosition, eye.storage);
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
        Vector3 posEye = matInv.getTranslation();
        setEye(posEye);
      }
    }
  }
}

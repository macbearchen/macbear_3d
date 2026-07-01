part of 'program.dart';

/// lighting program: lighting + fog
class M3ProgramLighting extends M3ProgramEye with M3LightingShader, M3FogShader {
  M3ProgramLighting(super.strVert, super.strFrag, {super.reflectionType});

  @override
  void initLocation() {
    super.initLocation();

    initLightingLocation(program);
    initFogLocation(program);
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    setLightDirection(mMatrix);
    setFogPlane(cam, mMatrix);
  }

  @override
  void setMaterial(M3Material mtr, Vector4 color) {
    super.setMaterial(mtr, color);

    Vector4 outDiffuse = M3Light.blendRGBA(mtr.diffuse, color);

    // ambient: RGB
    if (M3Program.isLocationValid(uniformAmbient)) {
      Vector3 outAmbient = M3Light.blendRGB(M3Light.ambient, outDiffuse.rgb);
      gl.uniform3fv(uniformAmbient, outAmbient.storage);
    }

    // diffuse: RGBA
    if (M3Program.isLocationValid(uniformDiffuse)) {
      outDiffuse.xyz = M3Light.blendRGB(_light!.color, outDiffuse.rgb);
      gl.uniform4fv(uniformDiffuse, outDiffuse.storage);
    }

    // specular: RGB
    if (M3Program.isLocationValid(uniformSpecular)) {
      Vector3 outSpecular = M3Light.blendRGB(mtr.specular, color.rgb);
      outSpecular = M3Light.blendRGB(_light!.color, outSpecular);

      // Pass as vec4: RGB, w = Shininess
      gl.uniform4f(uniformSpecular, outSpecular.x, outSpecular.y, outSpecular.z, mtr.shininess);
    }
  }
}
